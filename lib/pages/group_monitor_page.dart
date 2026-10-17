import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/lead/auto_sync_pipeline_logic.dart';
import '../services/lead/group_monitor_controller.dart';
import '../services/lead/monitor_group_selection.dart';
import '../widgets/decrypt_required_gate.dart';
import '../widgets/lead_prompt_editor.dart';
import '../widgets/persisted_number_field.dart';

/// 群监控 UI：状态由 [GroupMonitorController] 持有，切页不中断。
class GroupMonitorPage extends StatefulWidget {
  const GroupMonitorPage({super.key});

  @override
  State<GroupMonitorPage> createState() => _GroupMonitorPageState();
}

class _GroupMonitorPageState extends State<GroupMonitorPage> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().groupMonitor.ensureBootstrapped();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _exportSelection(GroupMonitorController c) async {
    if (c.selected.isEmpty) {
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
      MonitorGroupSelection.encodeExport(c.selected),
      encoding: utf8,
    );
  }

  Future<void> _importSelection(GroupMonitorController c) async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '导入监控群列表',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final String raw;
    if (file.bytes != null) {
      raw = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      raw = await File(file.path!).readAsString();
    } else {
      return;
    }
    try {
      final imported = MonitorGroupSelection.parseImport(raw);
      final known = c.groups.map((g) => g.username).toSet();
      final applied = MonitorGroupSelection.applyImport(
        imported: imported,
        knownUsernames: known,
      );
      c.applyImportResult(
        selected: applied.selected,
        missing: applied.missing,
      );
    } catch (e) {
      c.pushEvent('导入失败: $e');
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

    return ListenableBuilder(
      listenable: appState.groupMonitor,
      builder: (context, _) {
        final c = appState.groupMonitor;
        if (c.loadingGroups && !c.bootstrapped) {
          return const Center(child: CircularProgressIndicator());
        }

        final theme = Theme.of(context);
        final visible = c.visibleGroups(_searchController.text);

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
                '自动同步：增量解密 → 仅抓取已选群（无库变更则跳过）→ 冷却。切页不中断。',
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
                      const Text('自动同步'),
                      Switch(
                        value: c.syncEnabled,
                        onChanged: c.setSyncEnabled,
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 140,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: '冷却(秒)',
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: PersistedNumberField(
                        value: c.cooldownSeconds,
                        min: 15,
                        max: 3600,
                        onCommit: c.setCooldownSeconds,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 150,
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
                      child: PersistedNumberField(
                        value: c.analysisHours,
                        min: 1,
                        max: 168,
                        onCommit: c.setAnalysisHours,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '置信度 ${(c.confidenceThreshold * 100).round()}%',
                          style: theme.textTheme.bodySmall,
                        ),
                        Slider(
                          value: c.confidenceThreshold,
                          min: 0.5,
                          max: 0.95,
                          divisions: 9,
                          label:
                              '${(c.confidenceThreshold * 100).round()}%',
                          onChanged: c.previewConfidenceThreshold,
                          onChangeEnd: (v) => c.setConfidenceThreshold(v),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed:
                        c.capturing ? null : () => c.captureSelectedNow(),
                    icon: c.capturing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      c.capturing
                          ? '抓取中 ${c.captureDone}/${c.captureTotal}'
                          : '立即抓取已选群',
                    ),
                  ),
                  if (c.capturing ||
                      (c.syncEnabled &&
                          c.phase != SyncPhase.idle &&
                          c.phase != SyncPhase.cooldown))
                    OutlinedButton.icon(
                      onPressed: () {
                        if (c.capturing) c.cancelCapture();
                        if (c.syncEnabled) c.cancelCurrentRound();
                      },
                      icon: const Icon(Icons.stop),
                      label: Text(c.syncEnabled ? '取消本轮' : '取消抓取'),
                    ),
                  if (c.syncEnabled)
                    Chip(
                      label: Text(
                        [
                          syncPhaseLabel(c.phase),
                          if (c.phase == SyncPhase.cooldown &&
                              c.cooldownRemainingSeconds > 0)
                            '${c.cooldownRemainingSeconds}s',
                          if (c.estimatedRoundDuration != null)
                            '预估≈${c.estimatedRoundDuration!.inSeconds + c.cooldownSeconds}s/轮',
                        ].join(' · '),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  if (c.status != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Text(
                        c.status!,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                child: ExpansionTile(
                  title: const Text('分类与提示词'),
                  subtitle: const Text('与设置中的商机 AI 配置同步，可导入导出'),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  children: [
                    LeadPromptEditor(
                      pack: c.leadPrompts,
                      onSave: (pack) async {
                        await c.saveLeadPrompts(pack);
                      },
                    ),
                  ],
                ),
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
                              padding:
                                  const EdgeInsets.fromLTRB(12, 12, 12, 8),
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  TextButton(
                                    onPressed: () => c.selectAllVisible(
                                      _searchController.text,
                                    ),
                                    child: const Text('全选'),
                                  ),
                                  TextButton(
                                    onPressed: c.clearSelection,
                                    child: const Text('全清'),
                                  ),
                                  TextButton(
                                    onPressed: () => _importSelection(c),
                                    child: const Text('导入'),
                                  ),
                                  TextButton(
                                    onPressed: () => _exportSelection(c),
                                    child: const Text('导出'),
                                  ),
                                  IconButton(
                                    tooltip: '刷新群列表',
                                    onPressed: c.loadingGroups
                                        ? null
                                        : c.refreshGroups,
                                    icon: const Icon(Icons.refresh),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      '共 ${c.groups.length} · 已选 ${c.selected.length}'
                                      '${c.missingImported.isEmpty ? '' : ' · 未找到 ${c.missingImported.length}'}'
                                      '${visible.length != c.groups.length ? ' · 显示 ${visible.length}' : ''}',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1),
                            Expanded(
                              child: visible.isEmpty &&
                                      c.missingImported.isEmpty
                                  ? const Center(child: Text('没有匹配的群'))
                                  : ListView.builder(
                                      itemCount: visible.length +
                                          (c.missingImported.isEmpty
                                              ? 0
                                              : 1 + c.missingImported.length),
                                      itemBuilder: (context, index) {
                                        if (index < visible.length) {
                                          final g = visible[index];
                                          final name =
                                              g.displayName?.isNotEmpty ==
                                                      true
                                                  ? g.displayName!
                                                  : g.username;
                                          final checked =
                                              c.selected.contains(g.username);
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
                                            onChanged: (v) => c.toggleGroup(
                                              g.username,
                                              v == true,
                                            ),
                                          );
                                        }
                                        final missingIndex =
                                            index - visible.length;
                                        if (missingIndex == 0) {
                                          return Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Text(
                                              '导入但未找到的群',
                                              style: theme.textTheme.titleSmall,
                                            ),
                                          );
                                        }
                                        final id = c.missingImported
                                            .elementAt(missingIndex - 1);
                                        return ListTile(
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
                                            onPressed: () =>
                                                c.removeMissing(id),
                                          ),
                                        );
                                      },
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
                              Row(
                                children: [
                                  Text(
                                    '事件日志',
                                    style: theme.textTheme.titleMedium,
                                  ),
                                  const Spacer(),
                                  if (c.syncEnabled)
                                    Chip(
                                      avatar: Icon(
                                        Icons.sync,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                      label: Text(
                                        '同步中 · ${syncPhaseLabel(c.phase)} · '
                                        '${c.selected.length} 群',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                  if (c.capturing) ...[
                                    const SizedBox(width: 8),
                                    Chip(
                                      avatar: const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      label: Text(
                                        '${c.captureDone}/${c.captureTotal}',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const Divider(),
                              Expanded(
                                child: c.events.isEmpty
                                    ? const Center(child: Text('暂无事件'))
                                    : ListView.builder(
                                        itemCount: c.events.length,
                                        itemBuilder: (context, index) {
                                          return Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            child: Text(c.events[index]),
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
      },
    );
  }
}
