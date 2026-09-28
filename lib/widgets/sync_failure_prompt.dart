import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/lead/group_monitor_controller.dart';

/// 自动同步失败时弹出对话框。可挂在任意页面之上。
class SyncFailurePrompt extends StatefulWidget {
  const SyncFailurePrompt({super.key, this.monitor, this.child});

  /// 测试可注入；为空时从 [AppState.groupMonitor] 读取。
  final GroupMonitorController? monitor;
  final Widget? child;

  @override
  State<SyncFailurePrompt> createState() => _SyncFailurePromptState();
}

class _SyncFailurePromptState extends State<SyncFailurePrompt> {
  GroupMonitorController? _monitor;
  bool _dialogOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = widget.monitor ?? context.read<AppState>().groupMonitor;
    if (!identical(next, _monitor)) {
      _monitor?.removeListener(_onMonitor);
      _monitor = next;
      _monitor!.addListener(_onMonitor);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onMonitor();
      });
    }
  }

  @override
  void dispose() {
    _monitor?.removeListener(_onMonitor);
    super.dispose();
  }

  void _onMonitor() {
    final message = _monitor?.syncFailureAlert;
    if (message == null || _dialogOpen || !mounted) return;
    _dialogOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _dialogOpen = false;
        return;
      }
      unawaited(_show(message));
    });
  }

  Future<void> _show(String message) async {
    final monitor = _monitor;
    if (monitor == null || !mounted) {
      _dialogOpen = false;
      return;
    }
    final latest = monitor.syncFailureAlert ?? message;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('自动同步失败'),
          content: Text('$latest\n\n自动同步将在冷却后继续。'),
          actions: [
            TextButton(
              onPressed: () {
                monitor.setSyncEnabled(false);
                Navigator.of(dialogContext).pop();
              },
              child: const Text('停止自动同步'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('知道了'),
            ),
          ],
        );
      },
    );
    if (!mounted) return;
    monitor.acknowledgeSyncFailure();
    _dialogOpen = false;
    if (monitor.syncFailureAlert != null) {
      _onMonitor();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child ?? const SizedBox.shrink();
  }
}
