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
import '../widgets/decrypt_required_gate.dart';

/// 商机中心：列表、过滤、单群/批量抓取
class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final _store = LeadStore();
  final _config = ConfigService();
  final _ai = AiClientService();

  List<Lead> _leads = [];
  List<ChatSession> _groups = [];
  String? _selectedGroupUsername;
  String _categoryFilter = 'all';
  String _statusFilter = 'pending'; // pending | completed | all
  bool _loading = true;
  bool _capturing = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final appState = context.read<AppState>();
    await _ai.loadFromConfig();
    await _refreshLeads();
    if (appState.databaseService.isConnected) {
      await _loadGroups(appState);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _refreshLeads() async {
    final all = await _store.getAll();
    if (!mounted) return;
    setState(() => _leads = all);
  }

  Future<void> _loadGroups(AppState appState) async {
    try {
      final sessions = await appState.databaseService.getSessions();
      final groups = sessions.where((s) => s.isGroup).toList();
      if (!mounted) return;
      setState(() {
        _groups = groups;
        if (_selectedGroupUsername == null && groups.isNotEmpty) {
          _selectedGroupUsername = groups.first.username;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = '加载群列表失败: $e');
    }
  }

  List<Lead> get _filtered {
    return _leads.where((lead) {
      if (_statusFilter == 'pending' && lead.completed) return false;
      if (_statusFilter == 'completed' && !lead.completed) return false;
      if (_categoryFilter != 'all' && lead.category != _categoryFilter) {
        return false;
      }
      return true;
    }).toList();
  }

  Future<List<LeadChatMessage>> _loadRecentMessages(
    AppState appState,
    String sessionId,
  ) async {
    final hours = await _config.getAiAnalysisHours();
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    final cutoffSec = cutoff.millisecondsSinceEpoch ~/ 1000;
    final messages = await appState.databaseService.getMessages(
      sessionId,
      limit: 800,
      offset: 0,
    );
    return messages
        .where((m) => m.createTime >= cutoffSec)
        .where((m) => m.displayContent.trim().isNotEmpty)
        .map(_messageToLeadChat)
        .toList();
  }

  LeadChatMessage _messageToLeadChat(Message m) {
    return LeadChatMessage(
      id: m.localId.toString(),
      sender: m.senderUsername,
      content: m.displayContent,
      timestampMs: m.createTime * 1000,
    );
  }

  Future<void> _captureSelected({bool batch = false}) async {
    final appState = context.read<AppState>();
    if (!appState.databaseService.isConnected) return;

    final targets = <ChatSession>[];
    if (batch) {
      targets.addAll(_groups);
    } else {
      ChatSession? selected;
      for (final g in _groups) {
        if (g.username == _selectedGroupUsername) {
          selected = g;
          break;
        }
      }
      if (selected != null) targets.add(selected);
    }
    if (targets.isEmpty) {
      setState(() => _statusMessage = '请先选择群聊');
      return;
    }

    setState(() {
      _capturing = true;
      _statusMessage = '正在抓取商机…';
    });

    try {
      await _ai.loadFromConfig();
      final threshold = await _config.getConfidenceThreshold();
      final pipeline = LeadPipelineService(aiClient: _ai, store: _store);
      var total = 0;
      for (final group in targets) {
        final chatName = group.displayName?.isNotEmpty == true
            ? group.displayName!
            : group.username;
        final msgs = await _loadRecentMessages(appState, group.username);
        if (msgs.isEmpty) continue;
        final created = await pipeline.generateFromChat(
          msgs,
          chatName,
          confidenceThreshold: threshold,
        );
        total += created.length;
      }
      await _refreshLeads();
      if (!mounted) return;
      setState(() {
        _statusMessage = total > 0 ? '新增 $total 条商机' : '未发现新的商机（可能已去重或低于置信度）';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _statusMessage = '抓取失败: $e');
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  Future<void> _showDetail(Lead lead) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(lead.title),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lead.description),
                  const SizedBox(height: 12),
                  Text('分类: ${Lead.categoryLabel(lead.category)}'),
                  Text(
                    '置信度: ${lead.confidence == null ? '-' : (lead.confidence! * 100).toStringAsFixed(0)}%',
                  ),
                  Text('群: ${lead.groupName ?? '-'}'),
                  Text('发送者: ${lead.sender ?? '-'}'),
                  Text('时间: ${lead.messageTime ?? '-'}'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('关闭'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (!appState.databaseService.isConnected) {
      return const DecryptRequiredGate();
    }

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final filtered = _filtered;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '商机中心',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const Spacer(),
              if (_statusMessage != null)
                Flexible(
                  child: Text(
                    _statusMessage!,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 280,
                child: DropdownButtonFormField<String>(
                  value: _groups.any((g) => g.username == _selectedGroupUsername)
                      ? _selectedGroupUsername
                      : null,
                  decoration: const InputDecoration(
                    labelText: '目标群聊',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _groups
                      .map(
                        (g) => DropdownMenuItem(
                          value: g.username,
                          child: Text(
                            g.displayName?.isNotEmpty == true
                                ? g.displayName!
                                : g.username,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedGroupUsername = v),
                ),
              ),
              FilledButton.icon(
                onPressed: _capturing ? null : () => _captureSelected(),
                icon: _capturing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome),
                label: const Text('智能抓取'),
              ),
              OutlinedButton.icon(
                onPressed:
                    _capturing ? null : () => _captureSelected(batch: true),
                icon: const Icon(Icons.playlist_add_check),
                label: const Text('批量抓取全部群'),
              ),
              IconButton(
                tooltip: '刷新',
                onPressed: _refreshLeads,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'pending', label: Text('待跟进')),
                  ButtonSegment(value: 'completed', label: Text('已完成')),
                  ButtonSegment(value: 'all', label: Text('全部')),
                ],
                selected: {_statusFilter},
                onSelectionChanged: (s) =>
                    setState(() => _statusFilter = s.first),
              ),
              const SizedBox(width: 16),
              DropdownButton<String>(
                value: _categoryFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('全部分类')),
                  DropdownMenuItem(value: 'recruitment', child: Text('招聘')),
                  DropdownMenuItem(value: 'procurement', child: Text('求购')),
                  DropdownMenuItem(value: 'resource', child: Text('资源')),
                  DropdownMenuItem(value: 'expert', child: Text('专家')),
                ],
                onChanged: (v) =>
                    setState(() => _categoryFilter = v ?? 'all'),
              ),
              const Spacer(),
              Text(
                '共 ${filtered.length} 条',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      '暂无商机。选择群聊后点击「智能抓取」。',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final lead = filtered[index];
                      final conf = lead.confidence;
                      return Card(
                        child: ListTile(
                          title: Text(lead.title),
                          subtitle: Text(
                            [
                              Lead.categoryLabel(lead.category),
                              if (conf != null)
                                '${(conf * 100).toStringAsFixed(0)}%',
                              if (lead.groupName != null) lead.groupName!,
                              if (lead.sender != null) lead.sender!,
                            ].join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: Icon(
                            lead.completed
                                ? Icons.check_circle
                                : Icons.fiber_new,
                            color: lead.completed
                                ? Colors.green
                                : Theme.of(context).colorScheme.primary,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: lead.completed ? '标为未完成' : '标为完成',
                                onPressed: () async {
                                  await _store.toggleComplete(lead.id);
                                  await _refreshLeads();
                                },
                                icon: Icon(
                                  lead.completed
                                      ? Icons.undo
                                      : Icons.done_all,
                                ),
                              ),
                              IconButton(
                                tooltip: '删除',
                                onPressed: () async {
                                  await _store.delete(lead.id);
                                  await _refreshLeads();
                                },
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                          onTap: () => _showDetail(lead),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
