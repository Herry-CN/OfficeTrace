import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/chat_session.dart';
import '../config_service.dart';
import '../database_service.dart';
import '../incremental_decrypt_service.dart';
import 'ai_client_service.dart';
import 'auto_sync_pipeline_logic.dart';
import 'lead_capture_service.dart';
import 'lead_store.dart';
import 'monitor_group_selection.dart';

/// 全局群监控 + 自动同步管线：切页不销毁。
///
/// 循环：增量解密 →（有变更则抓取已选群）→ 冷却 → 重复。
/// 无库变更时跳过抓取，直接进入冷却。
class GroupMonitorController extends ChangeNotifier {
  GroupMonitorController({
    required this.databaseService,
    ConfigService? configService,
    AiClientService? aiClient,
    LeadStore? store,
    LeadCaptureService? captureService,
    IncrementalDecryptRunner? decryptService,
    Future<void> Function()? reconnectDatabase,
  })  : config = configService ?? ConfigService(),
        _ai = aiClient ?? AiClientService(),
        _store = store ?? LeadStore(),
        _decrypt = decryptService ?? IncrementalDecryptService(),
        _reconnectDatabase = reconnectDatabase {
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
  final IncrementalDecryptRunner _decrypt;
  final Future<void> Function()? _reconnectDatabase;
  late final LeadCaptureService _capture;

  List<ChatSession> _groups = [];
  final Set<String> _selected = {};
  final Set<String> _missingImported = {};
  final List<String> _events = [];

  bool _bootstrapped = false;
  bool _loadingGroups = false;
  bool _syncEnabled = false;
  bool _cancelRound = false;
  bool _loopActive = false;
  bool _capturing = false;
  bool _cancelCapture = false;
  SyncPhase _phase = SyncPhase.idle;
  int _cooldownSeconds = 60;
  int _analysisHours = 24;
  double _confidenceThreshold = 0.75;
  int _captureDone = 0;
  int _captureTotal = 0;
  String? _captureCurrentName;
  String? _status;
  DateTime? _cooldownEndsAt;
  Duration? _lastRoundDuration;
  Duration? _estimatedRoundDuration;
  bool _lastSkippedCapture = false;
  int _lastUpdatedFiles = 0;
  Timer? _persistDebounce;
  Timer? _cooldownTick;

  List<ChatSession> get groups => List.unmodifiable(_groups);
  Set<String> get selected => Set.unmodifiable(_selected);
  Set<String> get missingImported => Set.unmodifiable(_missingImported);
  List<String> get events => List.unmodifiable(_events);
  bool get bootstrapped => _bootstrapped;
  bool get loadingGroups => _loadingGroups;
  bool get syncEnabled => _syncEnabled;
  /// 兼容旧测试/命名：同步循环总开关。
  bool get monitoring => _syncEnabled;
  SyncPhase get phase => _phase;
  bool get capturing => _capturing;
  int get cooldownSeconds => _cooldownSeconds;
  int get intervalSeconds => _cooldownSeconds;
  int get analysisHours => _analysisHours;
  double get confidenceThreshold => _confidenceThreshold;
  int get captureDone => _captureDone;
  int get captureTotal => _captureTotal;
  String? get captureCurrentName => _captureCurrentName;
  String? get status => _status;
  DateTime? get cooldownEndsAt => _cooldownEndsAt;
  Duration? get lastRoundDuration => _lastRoundDuration;
  Duration? get estimatedRoundDuration => _estimatedRoundDuration;
  bool get lastSkippedCapture => _lastSkippedCapture;
  int get lastUpdatedFiles => _lastUpdatedFiles;

  int get cooldownRemainingSeconds {
    final ends = _cooldownEndsAt;
    if (ends == null) return 0;
    final left = ends.difference(DateTime.now()).inSeconds;
    return left < 0 ? 0 : left;
  }

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
      _cooldownSeconds = await config.getMonitorIntervalSeconds();
      _analysisHours = await config.getAiAnalysisHours();
      _confidenceThreshold = await config.getConfidenceThreshold();
      final saved = await config.getMonitorSelectedGroups();
      unawaited(_ai.loadFromConfig().catchError((_) {}));

      if (databaseService.isConnected) {
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
    } catch (_) {}
  }

  Future<void> refreshGroups() async {
    _bootstrapped = false;
    await ensureBootstrapped();
  }

  /// 刷新群列表元数据（含 lastTimestamp），保留内存中的已选集合。
  Future<void> refreshGroupMetadata() async {
    if (!databaseService.isConnected) return;
    try {
      final fresh = await databaseService.getSessions(
        groupsOnly: true,
        enrichNames: false,
      );
      final keepSelected = Set<String>.from(_selected);
      final keepMissing = Set<String>.from(_missingImported);
      _groups = fresh;
      final known = _groups.map((g) => g.username).toSet();
      _selected
        ..clear()
        ..addAll(keepSelected.where(known.contains));
      _missingImported
        ..clear()
        ..addAll({
          ...keepMissing,
          ...keepSelected.where((id) => !known.contains(id)),
        });
      unawaited(_enrichNamesInBackground());
      notifyListeners();
    } catch (_) {}
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

  Future<void> setCooldownSeconds(int seconds) async {
    _cooldownSeconds = seconds.clamp(15, 3600);
    await config.saveMonitorIntervalSeconds(_cooldownSeconds);
    notifyListeners();
  }

  /// 兼容旧 API：间隔即冷却秒数。
  Future<void> setIntervalSeconds(int seconds) => setCooldownSeconds(seconds);

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

  void previewConfidenceThreshold(double value) {
    _confidenceThreshold = value.clamp(0.5, 0.95);
    notifyListeners();
  }

  /// 开启/关闭自动同步循环（解密 → 可选抓取 → 冷却）。
  void setSyncEnabled(bool enabled) {
    if (enabled == _syncEnabled) return;
    _syncEnabled = enabled;
    _cancelRound = !enabled;
    if (!enabled) {
      _cooldownTick?.cancel();
      _cooldownTick = null;
      _cooldownEndsAt = null;
      if (_phase == SyncPhase.cooldown || _phase == SyncPhase.idle) {
        _phase = SyncPhase.idle;
      }
      _status = '已停止自动同步';
      pushEvent('${_ts()} · 已停止自动同步循环');
      notifyListeners();
      return;
    }
    _cancelRound = false;
    _status = '自动同步已开启';
    pushEvent('${_ts()} · 已开启自动同步循环');
    notifyListeners();
    if (!_loopActive) {
      unawaited(_runLoop());
    }
  }

  /// 兼容旧 API。
  void setMonitoring(bool enabled) => setSyncEnabled(enabled);

  void cancelCurrentRound() {
    _cancelRound = true;
    if (_capturing) {
      _cancelCapture = true;
    }
    _status = '正在取消本轮…';
    notifyListeners();
  }

  void pushEvent(String text) {
    _events.insert(0, text);
    if (_events.length > 200) {
      _events.removeRange(200, _events.length);
    }
    notifyListeners();
  }

  String _ts() => DateTime.now().toString().substring(0, 19);

  Future<void> _runLoop() async {
    if (_loopActive) return;
    _loopActive = true;
    try {
      while (_syncEnabled) {
        _cancelRound = false;
        final roundStart = DateTime.now();
        var didCapture = false;

        _phase = SyncPhase.decrypting;
        _status = '增量解密中…';
        notifyListeners();
        pushEvent('${_ts()} · 开始增量解密');

        IncrementalDecryptResult decryptResult;
        try {
          decryptResult = await _decrypt.runIncrementalUpdate(
            databaseService: databaseService,
            reconnectDatabase: () async {
              final reconnect = _reconnectDatabase;
              if (reconnect != null) {
                await reconnect();
              }
            },
            onStatus: (s) {
              if (!_syncEnabled) return;
              _status = s;
              notifyListeners();
            },
            shouldCancel: () => !_syncEnabled || _cancelRound,
          );
        } catch (e) {
          _phase = SyncPhase.error;
          _status = '增量解密失败: $e';
          pushEvent('${_ts()} · 增量解密失败: $e');
          notifyListeners();
          if (!_syncEnabled) break;
          await _waitCooldown();
          continue;
        }

        if (!_syncEnabled) break;

        if (_cancelRound) {
          pushEvent('${_ts()} · 本轮已取消');
          await _waitCooldown();
          continue;
        }

        if (!decryptResult.ok && decryptResult.errorMessage != null) {
          _phase = SyncPhase.error;
          _status = decryptResult.errorMessage;
          pushEvent('${_ts()} · ${decryptResult.errorMessage}');
          notifyListeners();
          await _waitCooldown();
          continue;
        }

        _lastUpdatedFiles = decryptResult.updatedCount;
        pushEvent(
          '${_ts()} · 解密完成 · 扫描 ${decryptResult.scannedCount} · '
          '需更新 ${decryptResult.needsUpdateCount} · '
          '成功 ${decryptResult.updatedCount} · 失败 ${decryptResult.failedCount}',
        );

        final decision = decideCaptureAfterDecrypt(
          hadDbChanges: decryptResult.hadChanges,
          hasSelectedGroups: selectedSessions.isNotEmpty,
        );

        switch (decision) {
          case CaptureDecision.skipNoDbChange:
            _lastSkippedCapture = true;
            _status = '无库变更，跳过抓取';
            pushEvent('${_ts()} · 无库变更，跳过抓取 → 冷却');
            notifyListeners();
          case CaptureDecision.skipNoSelection:
            _lastSkippedCapture = true;
            _status = '库有变更但未选监控群，跳过抓取';
            pushEvent('${_ts()} · 未选监控群，跳过抓取 → 冷却');
            notifyListeners();
          case CaptureDecision.captureSelected:
            _lastSkippedCapture = false;
            didCapture = true;
            await _captureSelectedInPipeline();
        }

        if (!_syncEnabled) break;

        _lastRoundDuration = DateTime.now().difference(roundStart);
        _estimatedRoundDuration = _blendEstimate(
          _estimatedRoundDuration,
          _lastRoundDuration!,
          includeCapture: didCapture,
        );

        await _waitCooldown();
      }
    } finally {
      _loopActive = false;
      _cooldownTick?.cancel();
      _cooldownTick = null;
      _cooldownEndsAt = null;
      if (_phase != SyncPhase.error || !_syncEnabled) {
        _phase = SyncPhase.idle;
      }
      notifyListeners();
    }
  }

  Duration _blendEstimate(
    Duration? prev,
    Duration sample, {
    required bool includeCapture,
  }) {
    // 无抓取的轮次偏短，单独样本对预估加权更低
    final weight = includeCapture ? 0.4 : 0.2;
    if (prev == null) return sample;
    final mixedMs =
        (prev.inMilliseconds * (1 - weight) + sample.inMilliseconds * weight)
            .round();
    return Duration(milliseconds: mixedMs);
  }

  Future<void> _waitCooldown() async {
    if (!_syncEnabled) return;
    _phase = SyncPhase.cooldown;
    final ends = DateTime.now().add(Duration(seconds: _cooldownSeconds));
    _cooldownEndsAt = ends;
    final estimate = _estimatedRoundDuration;
    final estimateText = estimate == null
        ? ''
        : ' · 预估单轮约 ${_formatDuration(estimate + Duration(seconds: _cooldownSeconds))}';
    _status =
        '冷却中 ${_cooldownSeconds}s$estimateText';
    notifyListeners();
    pushEvent('${_ts()} · 进入冷却 ${_cooldownSeconds}s');

    _cooldownTick?.cancel();
    _cooldownTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_syncEnabled) return;
      final left = cooldownRemainingSeconds;
      _status = left > 0 ? '冷却中 ${left}s' : '冷却结束';
      notifyListeners();
    });

    while (_syncEnabled && DateTime.now().isBefore(ends)) {
      if (_cancelRound) break;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }

    _cooldownTick?.cancel();
    _cooldownTick = null;
    _cooldownEndsAt = null;
  }

  String _formatDuration(Duration d) {
    final s = d.inSeconds;
    if (s < 60) return '${s}s';
    final m = s ~/ 60;
    final r = s % 60;
    return r == 0 ? '${m}m' : '${m}m${r}s';
  }

  Future<void> _captureSelectedInPipeline() async {
    // 解密后刷新会话时间戳，便于按 lastTimestamp 廉价跳过无变化群
    await refreshGroupMetadata();
    final targets = selectedSessions;
    if (targets.isEmpty) return;
    if (!databaseService.isConnected) {
      _status = '数据库未连接，跳过抓取';
      pushEvent('${_ts()} · 数据库未连接，跳过抓取');
      notifyListeners();
      return;
    }

    _phase = SyncPhase.capturing;
    _capturing = true;
    _cancelCapture = false;
    _captureDone = 0;
    _captureTotal = targets.length;
    _captureCurrentName = null;
    _status = '抓取已选群 0/${targets.length}…';
    notifyListeners();
    pushEvent('${_ts()} · 开始抓取已选 ${targets.length} 个群（仅有新消息的群）');

    try {
      final result = await _capture.captureGroups(
        database: databaseService,
        groups: targets,
        analysisHours: _analysisHours,
        confidenceThreshold: _confidenceThreshold,
        messageLimit: 120,
        shouldCancel: () => _cancelCapture || !_syncEnabled || _cancelRound,
        onProgress: (done, totalCount, name) {
          _captureDone = done;
          _captureTotal = totalCount;
          _captureCurrentName = name;
          _status = '抓取已选群 $done/$totalCount · $name';
          notifyListeners();
        },
      );
      if (_cancelCapture || _cancelRound || !_syncEnabled) {
        _status =
            '本轮抓取已取消（新增 ${result.createdCount} 条，跳过 ${result.skippedUnchanged} 群）';
        pushEvent(
          '${_ts()} · 抓取已取消 · 新增 ${result.createdCount} · '
          '处理 ${result.processedGroups} · 跳过 ${result.skippedUnchanged}',
        );
      } else if (result.processedGroups == 0 && result.skippedUnchanged > 0) {
        _status = '已选群均无新消息，已跳过抓取';
        pushEvent(
          '${_ts()} · 已选群均无新消息，跳过 AI 抓取 '
          '（${result.skippedUnchanged} 群）',
        );
      } else {
        _status = result.createdCount > 0
            ? '抓取完成，新增 ${result.createdCount} 条商机'
                '（处理 ${result.processedGroups}，跳过 ${result.skippedUnchanged}）'
            : '未发现新商机（处理 ${result.processedGroups}，'
                '跳过 ${result.skippedUnchanged}）';
        pushEvent(
          '${_ts()} · 抓取完成 · 新增 ${result.createdCount} · '
          '处理 ${result.processedGroups} · 跳过 ${result.skippedUnchanged}',
        );
      }
    } catch (e) {
      _phase = SyncPhase.error;
      _status = '抓取失败: $e';
      pushEvent('${_ts()} · 抓取失败: $e');
    } finally {
      _capturing = false;
      _cancelCapture = false;
      _captureCurrentName = null;
      notifyListeners();
    }
  }

  Future<void> captureSelectedNow() async {
    if (_capturing) return;
    if (_syncEnabled &&
        (_phase == SyncPhase.decrypting || _phase == SyncPhase.capturing)) {
      _status = '自动同步忙于${syncPhaseLabel(_phase)}，请稍后再手动抓取';
      notifyListeners();
      return;
    }
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
      final result = await _capture.captureGroups(
        database: databaseService,
        groups: targets,
        analysisHours: _analysisHours,
        confidenceThreshold: _confidenceThreshold,
        messageLimit: 120,
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
        _status =
            '已取消立即抓取（已完成 $_captureDone/$_captureTotal，'
            '新增 ${result.createdCount} 条）';
        pushEvent(
          '${_ts()} · 立即抓取已取消 · 新增 ${result.createdCount} 条',
        );
      } else if (result.processedGroups == 0 && result.skippedUnchanged > 0) {
        _status = '已选群均无新消息，已跳过抓取';
        pushEvent(
          '${_ts()} · 立即抓取 · 均无新消息，跳过 '
          '（${result.skippedUnchanged} 群）',
        );
      } else {
        _status = result.createdCount > 0
            ? '立即抓取完成，新增 ${result.createdCount} 条商机'
                '（跳过无变化 ${result.skippedUnchanged}）'
            : '未发现新商机（跳过无变化 ${result.skippedUnchanged}）';
        pushEvent(
          '${_ts()} · 立即抓取完成 · 新增 ${result.createdCount} · '
          '跳过 ${result.skippedUnchanged}',
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
    _syncEnabled = false;
    _cancelRound = true;
    _cooldownTick?.cancel();
    _persistDebounce?.cancel();
    super.dispose();
  }
}
