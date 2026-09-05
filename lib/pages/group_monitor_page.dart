import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_session.dart';
import '../models/message.dart';
import '../providers/app_state.dart';
import '../services/config_service.dart';
import '../services/lead/ai_client_service.dart';
import '../services/lead/lead_capture_service.dart';
import '../services/lead/lead_store.dart';
import '../services/lead/monitor_group_selection.dart';
import '../services/lead/monitor_poll_delta.dart';
import '../widgets/decrypt_required_gate.dart';

/// 群监控：选群、持久化、轮询、自动/立即抓取
class GroupMonitorPage extends StatefulWidget {
  const GroupMonitorPage({super.key});

  @override
  State<GroupMonitorPage> createState() => _GroupMonitorPageState();
}

class _GroupMonitorPageState extends State<GroupMonitorPage> {
  final _config = ConfigService();
  final _store = LeadStore();
  final _ai = AiClientService();
  late final LeadCaptureService _capture;

  final _searchController = TextEditingController();
  Timer? _persistDebounce;

  List<ChatSession> _groups = [];
  final Set<String> _selected = {};
  final Set<String> _missingImported = {};
  final List<String> _events = [];
  final Map<String, int> _lastSeenCreateTime = {};

  bool _loading = true;
  bool _monitoring = false;
  bool _autoCapture = false;
  bool _capturing = false;
  int _intervalSeconds = 60;
  int _analysisHours = 24;
  double _confidenceThreshold = 0.75;
  Timer? _timer;
  String? _status;

  @override
  void initState() {
    super.initState();
    _capture = LeadCaptureService(
      aiClient: _ai,
      store: _store,
      configService: _config,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _persistDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<ChatSession> get _visibleGroups =>
      MonitorGroupSelection.filterGroups(_groups, _searchController.text);

  Future<void> _bootstrap() async {
    final appState = context.read<AppState>();
    try {
      _intervalSeconds = await _config.getMonitorIntervalSeconds();
      _autoCapture = await _config.getMonitorAutoCapture();
      _analysisHours = await _config.getAiAnalysisHours();
      _confidenceThreshold = await _config.getConfidenceThreshold();
      final saved = await _config.getMonitorSelectedGroups();
      unawaited(_ai.loadFromConfig().catchError((_) {}));
      if (appState.databaseService.isConnected) {
        try {
          _groups = await appState.databaseService.getSessions(
            groupsOnly: true,
          );
          final known = _groups.map((g) => g.username).toSet();
          _selected
            ..clear()
            ..addAll(saved.where(known.contains));
          _missingImported
            ..clear()
            ..addAll(saved.where((id) => !known.contains(id)));
        } catch (e) {
          _status = '加载群列表失败: $e';
        }
      }
    } catch (e) {
      _status = '初始化失败: $e';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _schedulePersistSelection() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 400), () async {
      await _config.saveMonitorSelectedGroups(_selected.toList());
    });
  }

  void _setSelected(Set<String> next, {Iterable<String> missing = const []}) {
    setState(() {
      _selected
        ..clear()
        ..addAll(next);
      _missingImported
        ..clear()
        ..addAll(missing);
    });
    _schedulePersistSelection();
  }

  void _toggleMonitor(bool enabled) {
    _timer?.cancel();
    setState(() => _monitoring = enabled);
    if (!enabled) return;
    _pollOnce();
    _timer = Timer.periodic(
      Duration(seconds: _intervalSeconds),
      (_) => _pollOnce(),
    );
  }

  void _pushEvent(String text) {
    if (!mounted) return;
    setState(() {
      _events.insert(0, text);
      if (_events.length > 100) {
        _events.removeRange(100, _events.length);
      }
    });
  }

  Future<void> _pollOnce() async {
    final appState = context.read<AppState>();
    if (!appState.databaseService.isConnected || _selected.isEmpty) return;

    for (final username in _selected.toList()) {
      try {
        final messages = await appState.databaseService.getMessages(
          username,
          limit: 30,
          offset: 0,
        );
        if (messages.isEmpty) continue;
        final delta = computeMonitorPollDelta(
          lastSeenCreateTime: _lastSeenCreateTime[username],
          messageCreateTimes: messages.map((m) => m.createTime).toList(),
        );
        if (delta.newestCreateTime == null) continue;
        if (delta.baselineOnly) {
          _lastSeenCreateTime[username] = delta.newestCreateTime!;
          continue;
        }
        if (delta.freshCreateTimes.isEmpty) continue;

        final fresh = messages
            .where((m) => delta.freshCreateTimes.contains(m.createTime))
            .toList();
        _lastSeenCreateTime[username] = delta.newestCreateTime!;

        final name = _displayNameFor(username);
        _pushEvent(
          '${DateTime.now().toString().substring(0, 19)} · $name · 新消息 ${fresh.length} 条',
        );

        if (_autoCapture && fresh.isNotEmpty) {
          await _autoCaptureMessages(name, fresh);
        }
      } catch (e) {
        _pushEvent('监控失败 $username: $e');
      }
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
      _pushEvent(
        '${DateTime.now().toString().substring(0, 19)} · 自动抓取 $chatName · +${created.length}',
      );
    } catch (e) {
      _pushEvent('自动抓取失败: $e');
    }
  }

  Future<void> _captureSelectedNow() async {
    if (_capturing) return;
    final appState = context.read<AppState>();
    if (!appState.databaseService.isConnected) return;

    final targets = _groups
        .where((g) => _selected.contains(g.username))
        .toList();
    if (targets.isEmpty) {
      setState(() => _status = '请先选择要抓取的群');
      return;
    }

    setState(() {
      _capturing = true;
      _status = '正在立即抓取 ${targets.length} 个群…';
    });
    try {
      final total = await _capture.captureGroups(
        database: appState.databaseService,
        groups: targets,
        analysisHours: _analysisHours,
        confidenceThreshold: _confidenceThreshold,
      );
      _pushEvent(
        '${DateTime.now().toString().substring(0, 19)} · 立即抓取 · 新增 $total 条',
      );
      if (!mounted) return;
      setState(() {
        _status = total > 0
            ? '立即抓取完成，新增 $total 条商机'
            : '未发现新商机（可能已去重或低于置信度）';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = '立即抓取失败: $e');
      _pushEvent('立即抓取失败: $e');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _exportSelection() async {
    if (_selected.isEmpty) {
      setState(() => _status = '没有可导出的已选群');
      return;
    }
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '导出监控群列表',
      fileName: 'leadtrace-monitor-groups.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (path == null) return;
    final file = File(path.endsWith('.json') ? path : '$path.json');
    await file.writeAsString(
      MonitorGroupSelection.encodeExport(_selected),
      encoding: utf8,
    );
    if (!mounted) return;
    setState(() => _status = '已导出 ${_selected.length} 个群');
  }

  Future<void> _importSelection() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '导入监控群列表',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    String raw;
    if (file.bytes != null) {
      raw = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      raw = await File(file.path!).readAsString();
    } else {
      setState(() => _status = '无法读取导入文件');
      return;
    }
    try {
      final imported = MonitorGroupSelection.parseImport(raw);
      final known = _groups.map((g) => g.username).toSet();
      final applied = MonitorGroupSelection.applyImport(
        imported: imported,
        knownUsernames: known,
      );
      _setSelected(applied.selected, missing: applied.missing);
      setState(() {
        _status = applied.missing.isEmpty
            ? '已导入 ${applied.selected.length} 个群'
            : '已导入 ${applied.selected.length} 个群（${applied.missing.length} 个未找到）';
      });
    } catch (e) {
      setState(() => _status = '导入失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (!appState.databaseService.isConnected) {
      return const DecryptRequiredGate(
        title: '需要先连接数据库',
        message: '群监控需要读取本地微信消息。请先完成解密或实时连接。',
      );
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final visible = _visibleGroups;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '群监控',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '搜索并选择监控群；监控新消息，或对已选群立即抓取商机。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('监控开关'),
                  Switch(
                    value: _monitoring,
                    onChanged: (v) => _toggleMonitor(v),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('自动抓取'),
                  Switch(
                    value: _autoCapture,
                    onChanged: (v) async {
                      setState(() => _autoCapture = v);
                      await _config.saveMonitorAutoCapture(v);
                    },
                  ),
                ],
              ),
              SizedBox(
                width: 160,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '间隔(秒)',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: TextFormField(
                    initialValue: '$_intervalSeconds',
                    decoration: const InputDecoration.collapsed(hintText: ''),
                    keyboardType: TextInputType.number,
                    onFieldSubmitted: (v) async {
                      final n = int.tryParse(v) ?? 60;
                      setState(() => _intervalSeconds = n.clamp(15, 3600));
                      await _config
                          .saveMonitorIntervalSeconds(_intervalSeconds);
                      if (_monitoring) _toggleMonitor(true);
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 160,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: '分析时窗(小时)',
                    isDense: true,
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  child: TextFormField(
                    initialValue: '$_analysisHours',
                    decoration: const InputDecoration.collapsed(hintText: ''),
                    keyboardType: TextInputType.number,
                    onFieldSubmitted: (v) async {
                      final n = int.tryParse(v) ?? 24;
                      setState(() => _analysisHours = n.clamp(1, 168));
                      await _config.saveAiAnalysisHours(_analysisHours);
                    },
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '置信度 ${(_confidenceThreshold * 100).round()}%',
                      style: theme.textTheme.bodySmall,
                    ),
                    Slider(
                      value: _confidenceThreshold,
                      min: 0.5,
                      max: 0.95,
                      divisions: 9,
                      label: '${(_confidenceThreshold * 100).round()}%',
                      onChanged: (v) {
                        setState(() => _confidenceThreshold = v);
                      },
                      onChangeEnd: (v) async {
                        await _config.saveConfidenceThreshold(v);
                      },
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: _capturing ? null : _captureSelectedNow,
                icon: _capturing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text('立即抓取已选群'),
              ),
              if (_status != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: Text(
                    _status!,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Card(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                          child: TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: '搜索群名或 ID',
                              prefixIcon: Icon(Icons.search),
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              TextButton(
                                onPressed: () {
                                  _setSelected(
                                    MonitorGroupSelection.selectAllVisible(
                                      _selected,
                                      visible,
                                    ),
                                    missing: _missingImported,
                                  );
                                },
                                child: const Text('全选'),
                              ),
                              TextButton(
                                onPressed: () {
                                  _setSelected(MonitorGroupSelection.clearAll());
                                },
                                child: const Text('全清'),
                              ),
                              TextButton(
                                onPressed: _importSelection,
                                child: const Text('导入'),
                              ),
                              TextButton(
                                onPressed: _exportSelection,
                                child: const Text('导出'),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 10,
                                ),
                                child: Text(
                                  '已选 ${_selected.length}'
                                  '${_missingImported.isEmpty ? '' : ' · 未找到 ${_missingImported.length}'}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: visible.isEmpty && _missingImported.isEmpty
                              ? const Center(child: Text('没有匹配的群'))
                              : ListView(
                                  children: [
                                    ...visible.map((g) {
                                      final name =
                                          g.displayName?.isNotEmpty == true
                                              ? g.displayName!
                                              : g.username;
                                      final checked =
                                          _selected.contains(g.username);
                                      return CheckboxListTile(
                                        value: checked,
                                        title: Text(
                                          name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          g.username,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall,
                                        ),
                                        onChanged: (v) {
                                          final next = Set<String>.from(
                                            _selected,
                                          );
                                          if (v == true) {
                                            next.add(g.username);
                                          } else {
                                            next.remove(g.username);
                                          }
                                          _setSelected(
                                            next,
                                            missing: _missingImported,
                                          );
                                        },
                                      );
                                    }),
                                    if (_missingImported.isNotEmpty) ...[
                                      const Divider(),
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Text(
                                          '导入但未找到的群',
                                          style: theme.textTheme.titleSmall,
                                        ),
                                      ),
                                      ..._missingImported.map(
                                        (id) => ListTile(
                                          dense: true,
                                          leading: const Icon(
                                            Icons.warning_amber_outlined,
                                            color: Colors.orange,
                                          ),
                                          title: Text(
                                            id,
                                            style: theme.textTheme.bodyMedium
                                                ?.copyWith(
                                              color: theme.colorScheme
                                                  .onSurface
                                                  .withValues(alpha: 0.5),
                                            ),
                                          ),
                                          subtitle: const Text('未找到'),
                                          trailing: IconButton(
                                            tooltip: '从选择中移除',
                                            icon: const Icon(Icons.close),
                                            onPressed: () {
                                              final next = Set<String>.from(
                                                _selected,
                                              )..remove(id);
                                              final missing =
                                                  Set<String>.from(
                                                _missingImported,
                                              )..remove(id);
                                              _setSelected(
                                                next,
                                                missing: missing,
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '事件日志',
                            style: theme.textTheme.titleMedium,
                          ),
                          const Divider(),
                          Expanded(
                            child: _events.isEmpty
                                ? const Center(child: Text('暂无事件'))
                                : ListView.builder(
                                    itemCount: _events.length,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Text(_events[index]),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
