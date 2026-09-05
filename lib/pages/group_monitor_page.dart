import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/chat_session.dart';
import '../models/lead.dart';
import '../models/message.dart';
import '../providers/app_state.dart';
import '../services/config_service.dart';
import '../services/lead/ai_client_service.dart';
import '../services/lead/lead_pipeline_service.dart';
import '../services/lead/lead_store.dart';
import '../services/lead/monitor_poll_delta.dart';
import '../widgets/decrypt_required_gate.dart';

/// 群监控：多选群、轮询、可选自动抓取
class GroupMonitorPage extends StatefulWidget {
  const GroupMonitorPage({super.key});

  @override
  State<GroupMonitorPage> createState() => _GroupMonitorPageState();
}

class _GroupMonitorPageState extends State<GroupMonitorPage> {
  final _config = ConfigService();
  final _store = LeadStore();
  final _ai = AiClientService();

  List<ChatSession> _groups = [];
  final Set<String> _selected = {};
  final List<String> _events = [];
  final Map<String, int> _lastSeenCreateTime = {};

  bool _loading = true;
  bool _monitoring = false;
  bool _autoCapture = false;
  int _intervalSeconds = 60;
  Timer? _timer;
  String? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final appState = context.read<AppState>();
    _intervalSeconds = await _config.getMonitorIntervalSeconds();
    _autoCapture = await _config.getMonitorAutoCapture();
    await _ai.loadFromConfig();
    if (appState.databaseService.isConnected) {
      try {
        final sessions = await appState.databaseService.getSessions();
        _groups = sessions.where((s) => s.isGroup).toList();
      } catch (e) {
        _status = '加载群列表失败: $e';
      }
    }
    if (mounted) setState(() => _loading = false);
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

        ChatSession? group;
        for (final g in _groups) {
          if (g.username == username) {
            group = g;
            break;
          }
        }
        final name = group?.displayName?.isNotEmpty == true
            ? group!.displayName!
            : username;

        if (!mounted) return;
        setState(() {
          _events.insert(
            0,
            '${DateTime.now().toString().substring(0, 19)} · $name · 新消息 ${fresh.length} 条',
          );
          if (_events.length > 100) {
            _events.removeRange(100, _events.length);
          }
        });

        if (_autoCapture && fresh.isNotEmpty) {
          await _captureMessages(name, fresh);
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _events.insert(0, '监控失败 $username: $e');
        });
      }
    }
  }

  Future<void> _captureMessages(String chatName, List<Message> messages) async {
    try {
      await _ai.loadFromConfig();
      final threshold = await _config.getConfidenceThreshold();
      final pipeline = LeadPipelineService(aiClient: _ai, store: _store);
      final input = messages
          .where((m) => m.displayContent.trim().isNotEmpty)
          .map(
            (m) => LeadChatMessage(
              id: m.localId.toString(),
              sender: m.senderUsername,
              content: m.displayContent,
              timestampMs: m.createTime * 1000,
            ),
          )
          .toList();
      if (input.isEmpty) return;
      final created = await pipeline.generateFromChat(
        input,
        chatName,
        confidenceThreshold: threshold,
      );
      if (!mounted) return;
      setState(() {
        _events.insert(
          0,
          '${DateTime.now().toString().substring(0, 19)} · 自动抓取 $chatName · +${created.length}',
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _events.insert(0, '自动抓取失败: $e');
      });
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

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '群监控',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '选择要监控的群，定时拉取新消息；可开启自动商机抓取。',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
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
                width: 200,
                child: Row(
                  children: [
                    const Text('间隔(秒)'),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: '$_intervalSeconds',
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
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
                  ],
                ),
              ),
              if (_status != null) Text(_status!),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Card(
                    child: ListView.builder(
                      itemCount: _groups.length,
                      itemBuilder: (context, index) {
                        final g = _groups[index];
                        final name = g.displayName?.isNotEmpty == true
                            ? g.displayName!
                            : g.username;
                        final checked = _selected.contains(g.username);
                        return CheckboxListTile(
                          value: checked,
                          title: Text(name, overflow: TextOverflow.ellipsis),
                          subtitle: Text(
                            g.username,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selected.add(g.username);
                              } else {
                                _selected.remove(g.username);
                              }
                            });
                          },
                        );
                      },
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
                            style: Theme.of(context).textTheme.titleMedium,
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
