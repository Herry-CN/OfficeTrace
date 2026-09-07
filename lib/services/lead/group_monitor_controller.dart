import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/chat_session.dart';
import '../../models/message.dart';
import '../config_service.dart';
import '../database_service.dart';
import 'ai_client_service.dart';
import 'lead_capture_service.dart';
import 'lead_store.dart';
import 'monitor_group_selection.dart';
import 'monitor_poll_delta.dart';

/// 全局群监控控制器：切页不销毁，监控/立即抓取在后台继续。
class GroupMonitorController extends ChangeNotifier {
  GroupMonitorController({
    required this.databaseService,
    ConfigService? configService,
    AiClientService? aiClient,
    LeadStore? store,
    LeadCaptureService? captureService,
  })  : config = configService ?? ConfigService(),
        _ai = aiClient ?? AiClientService(),
        _store = store ?? LeadStore() {
    _capture = captureService ??
        LeadCaptureService(
          aiClient: _ai,
          store: _store,
          configService: config,
        );
  }

  final DatabaseService databaseService;
  final ConfigService config;
  final AiClientService _ai;
  final LeadStore _store;
  late final LeadCaptureService _capture;

  List<ChatSession> _groups = [];
  final Set<String> _selected = {};
  final Set<String> _missingImported = {};
  final List<String> _events = [];
  final Map<String, int> _lastSeenCreateTime = {};

  bool _bootstrapped = false;
  bool _loadingGroups = false;
  bool _monitoring = false;
  bool _autoCapture = false;
  bool _capturing = false;
  bool _cancelCapture = false;
  int _intervalSeconds = 60;
  int _analysisHours = 24;
  double _confidenceThreshold = 0.75;
  int _captureDone = 0;
  int _captureTotal = 0;
  String? _captureCurrentName;
  String? _status;
  Timer? _timer;
  Timer? _persistDebounce;

  List<ChatSession> get groups => List.unmodifiable(_groups);
  Set<String> get selected => Set.unmodifiable(_selected);
  Set<String> get missingImported => Set.unmodifiable(_missingImported);
  List<String> get events => List.unmodifiable(_events);
  bool get bootstrapped => _bootstrapped;
  bool get loadingGroups => _loadingGroups;
  bool get monitoring => _monitoring;
  bool get autoCapture => _autoCapture;
  bool get capturing => _capturing;
  int get intervalSeconds => _intervalSeconds;
  int get analysisHours => _analysisHours;
  double get confidenceThreshold => _confidenceThreshold;
  int get captureDone => _captureDone;
  int get captureTotal => _captureTotal;
  String? get captureCurrentName => _captureCurrentName;
  String? get status => _status;

  List<ChatSession> visibleGroups(String query) =>
      MonitorGroupSelection.filterGroups(_groups, query);

  List<ChatSession> get selectedSessions =>
      _groups.where((g) => _selected.contains(g.username)).toList();

  /// 首次进入或数据库就绪后加载群列表与配置（幂等）。
  Future<void> ensureBootstrapped() async {
    if (_bootstrapped && !_loadingGroups) return;
    if (_loadingGroups) return;
    _loadingGroups = true;
    notifyListeners();
    try {
      _intervalSeconds = await config.getMonitorIntervalSeconds();
      _autoCapture = await config.getMonitorAutoCapture();
      _analysisHours = await config.getAiAnalysisHours();
      _confidenceThreshold = await config.getConfidenceThreshold();
      final saved = await config.getMonitorSelectedGroups();
      unawaited(_ai.loadFromConfig().catchError((_) {}));

      if (databaseService.isConnected) {
        // 700+ 群：跳过慢速补名，先出列表；显示名后台补齐
        _groups = await databaseService.getSessions(
          groupsOnly: true,
          enrichNames: false,
        );
        final known = _groups.map((g) => g.username).toSet();
        _selected
          ..clear()
          ..addAll(saved.where(known.contains));
        _missingImported
          ..clear()
          ..addAll(saved.where((id) => !known.contains(id)));
        _status = '已加载 ${_groups.length} 个群';
        unawaited(_enrichNamesInBackground());
      } else {
        _status = '数据库未连接';
      }
      _bootstrapped = true;
    } catch (e) {
      _status = '加载群列表失败: $e';
    } finally {
      _loadingGroups = false;
      notifyListeners();
    }
  }

  Future<void> _enrichNamesInBackground() async {
    if (_groups.isEmpty) return;
    try {
      // 复用 DatabaseService 批量 fast 路径：临时再拉一次带名字的列表会重复查询；
      // 这里直接用 getDisplayNames 更合适，但 API 在 DatabaseService 上。
      // 分批通知，避免一次 setState 卡死。
      final names = await databaseService.getDisplayNames(
        _groups.map((g) => g.username).toList(),
        fast: true,
      );
      var updated = 0;
      for (final g in _groups) {
        final n = names[g.username];
        if (n != null && n.isNotEmpty) {
          g.displayName = n;
          updated++;
        }
        if (updated % 50 == 0) {
          notifyListeners();
          await Future<void>.delayed(Duration.zero);
        }
      }
      notifyListeners();
    } catch (_) {
      // 补名失败不影响监控
    }
  }

  Future<void> refreshGroups() async {
    _bootstrapped = false;
    await ensureBootstrapped();
  }

  void setSelected(Set<String> next, {Iterable<String> missing = const []}) {
    _selected
      ..clear()
      ..addAll(next);
    _missingImported
      ..clear()
      ..addAll(missing);
    _schedulePersistSelection();
    notifyListeners();
  }

  void toggleGroup(String username, bool selected) {
    if (selected) {
      _selected.add(username);
      _missingImported.remove(username);
    } else {
      _selected.remove(username);
    }
    _schedulePersistSelection();
    notifyListeners();
  }

  void selectAllVisible(String query) {
    final visible = visibleGroups(query);
    setSelected(
      MonitorGroupSelection.selectAllVisible(_selected, visible),
      missing: _missingImported,
    );
  }

  void clearSelection() {
    setSelected(MonitorGroupSelection.clearAll());
  }

  void removeMissing(String id) {
    final next = Set<String>.from(_selected)..remove(id);
    final missing = Set<String>.from(_missingImported)..remove(id);
    setSelected(next, missing: missing);
  }

  void _schedulePersistSelection() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 400), () async {
      await config.saveMonitorSelectedGroups(_selected.toList());
    });
  }

  Future<void> setAutoCapture(bool value) async {
    _autoCapture = value;
    await config.saveMonitorAutoCapture(value);
    notifyListeners();
  }

  Future<void> setIntervalSeconds(int seconds) async {
    _intervalSeconds = seconds.clamp(15, 3600);
    await config.saveMonitorIntervalSeconds(_intervalSeconds);
    if (_monitoring) {
      setMonitoring(true); // restart timer
    } else {
      notifyListeners();
    }
  }

  Future<void> setAnalysisHours(int hours) async {
    _analysisHours = hours.clamp(1, 168);
    await config.saveAiAnalysisHours(_analysisHours);
    notifyListeners();
  }

  Future<void> setConfidenceThreshold(double value) async {
    _confidenceThreshold = value.clamp(0.5, 0.95);
    await config.saveConfidenceThreshold(_confidenceThreshold);
    notifyListeners();
  }

  /// 拖动滑块时只更新内存，松手后再 [setConfidenceThreshold] 落盘。
  void previewConfidenceThreshold(double value) {
    _confidenceThreshold = value.clamp(0.5, 0.95);
    notifyListeners();
  }

  void setMonitoring(bool enabled) {
    _timer?.cancel();
    _timer = null;
    _monitoring = enabled;
    notifyListeners();
    if (!enabled) return;
    unawaited(_pollOnce());
    _timer = Timer.periodic(
      Duration(seconds: _intervalSeconds),
      (_) => unawaited(_pollOnce()),
    );
  }

  void pushEvent(String text) {
    _events.insert(0, text);
    if (_events.length > 200) {
      _events.removeRange(200, _events.length);
    }
    notifyListeners();
  }

  Future<void> _pollOnce() async {
    if (!databaseService.isConnected || _selected.isEmpty) return;
    // 只扫已选群；分批让出 UI，避免一次扫几百个假死
    final usernames = _selected.toList();
    const batchSize = 8;
    for (var i = 0; i < usernames.length; i += batchSize) {
      if (!_monitoring) return;
      final end = (i + batchSize < usernames.length)
          ? i + batchSize
          : usernames.length;
      final chunk = usernames.sublist(i, end);
      for (final username in chunk) {
        await _pollOneGroup(username);
      }
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> _pollOneGroup(String username) async {
    try {
      final messages = await databaseService.getMessages(
        username,
        limit: 20,
        offset: 0,
      );
      if (messages.isEmpty) return;
      final delta = computeMonitorPollDelta(
        lastSeenCreateTime: _lastSeenCreateTime[username],
        messageCreateTimes: messages.map((m) => m.createTime).toList(),
      );
      if (delta.newestCreateTime == null) return;
      if (delta.baselineOnly) {
        _lastSeenCreateTime[username] = delta.newestCreateTime!;
        return;
      }
      if (delta.freshCreateTimes.isEmpty) return;

      final fresh = messages
          .where((m) => delta.freshCreateTimes.contains(m.createTime))
          .toList();
      _lastSeenCreateTime[username] = delta.newestCreateTime!;
      final name = _displayNameFor(username);
      pushEvent(
        '${DateTime.now().toString().substring(0, 19)} · $name · 新消息 ${fresh.length} 条',
      );

      if (_autoCapture && fresh.isNotEmpty) {
        await _autoCaptureMessages(name, fresh);
      }
    } catch (e) {
      pushEvent('监控失败 $username: $e');
    }
  }

  String _displayNameFor(String username) {
    for (final g in _groups) {
      if (g.username == username) {
        return g.displayName?.isNotEmpty == true ? g.displayName! : username;
      }
    }
    return username;
  }

  Future<void> _autoCaptureMessages(
    String chatName,
    List<Message> messages,
  ) async {
    try {
      final created = await _capture.captureFromMessages(
        messages,
        chatName,
        confidenceThreshold: _confidenceThreshold,
      );
      pushEvent(
        '${DateTime.now().toString().substring(0, 19)} · 自动抓取 $chatName · +${created.length}',
      );
    } catch (e) {
      pushEvent('自动抓取失败: $e');
    }
  }

  Future<void> captureSelectedNow() async {
    if (_capturing) return;
    if (!databaseService.isConnected) {
      _status = '数据库未连接';
      notifyListeners();
      return;
    }
    final targets = selectedSessions;
    if (targets.isEmpty) {
      _status = '请先选择要抓取的群';
      notifyListeners();
      return;
    }

    _capturing = true;
    _cancelCapture = false;
    _captureDone = 0;
    _captureTotal = targets.length;
    _captureCurrentName = null;
    _status = '正在立即抓取 ${targets.length} 个群…';
    notifyListeners();

    try {
      final total = await _capture.captureGroups(
        database: databaseService,
        groups: targets,
        analysisHours: _analysisHours,
        confidenceThreshold: _confidenceThreshold,
        messageLimit: 80,
        shouldCancel: () => _cancelCapture,
        onProgress: (done, totalCount, name) {
          _captureDone = done;
          _captureTotal = totalCount;
          _captureCurrentName = name;
          _status = '立即抓取 $done/$totalCount · $name';
          notifyListeners();
        },
      );
      if (_cancelCapture) {
        _status = '已取消立即抓取（已完成 $_captureDone/$_captureTotal，新增 $total 条）';
        pushEvent(
          '${DateTime.now().toString().substring(0, 19)} · 立即抓取已取消 · 新增 $total 条',
        );
      } else {
        _status = total > 0
            ? '立即抓取完成，新增 $total 条商机'
            : '未发现新商机（可能已去重或低于置信度）';
        pushEvent(
          '${DateTime.now().toString().substring(0, 19)} · 立即抓取完成 · 新增 $total 条',
        );
      }
    } catch (e) {
      _status = '立即抓取失败: $e';
      pushEvent('立即抓取失败: $e');
    } finally {
      _capturing = false;
      _cancelCapture = false;
      _captureCurrentName = null;
      notifyListeners();
    }
  }

  void cancelCapture() {
    if (!_capturing) return;
    _cancelCapture = true;
    _status = '正在取消…';
    notifyListeners();
  }

  void applyImportResult({
    required Set<String> selected,
    required List<String> missing,
  }) {
    setSelected(selected, missing: missing);
    _status = missing.isEmpty
        ? '已导入 ${selected.length} 个群'
        : '已导入 ${selected.length} 个群（${missing.length} 个未找到）';
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _persistDebounce?.cancel();
    super.dispose();
  }
}
