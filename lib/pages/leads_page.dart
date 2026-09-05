import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lead.dart';
import '../providers/app_state.dart';
import '../services/lead/lead_store.dart';
import '../widgets/decrypt_required_gate.dart';

/// 商机中心：列表、筛选、跟进（抓取在「群监控」）
class LeadsPage extends StatefulWidget {
  const LeadsPage({super.key});

  @override
  State<LeadsPage> createState() => _LeadsPageState();
}

class _LeadsPageState extends State<LeadsPage> {
  final _store = LeadStore();

  List<Lead> _leads = [];
  String _categoryFilter = 'all';
  String _statusFilter = 'pending'; // pending | completed | all
  bool _loading = true;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await _refreshLeads();
    } catch (e) {
      if (mounted) {
        setState(() => _statusMessage = '加载失败: $e');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshLeads() async {
    final all = await _store.getAll();
    if (!mounted) return;
    setState(() => _leads = all);
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
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '商机中心',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: '刷新',
                onPressed: _refreshLeads,
                icon: const Icon(Icons.refresh),
              ),
              if (_statusMessage != null)
                Flexible(
                  child: Text(
                    _statusMessage!,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '请在「群监控」选择群并抓取；此处查看与跟进商机。',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
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
              Text(
                '共 ${filtered.length} 条',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      '暂无商机。请到「群监控」选择群后点击「立即抓取已选群」。',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                                : theme.colorScheme.primary,
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
