import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

/// 未解密 / 未连接数据库时的引导卡片
class DecryptRequiredGate extends StatelessWidget {
  const DecryptRequiredGate({
    super.key,
    this.title = '需要先完成解密',
    this.message = '商机抓取依赖本地微信数据库。请先在「数据管理」配置密钥并完成解密（或连接实时数据库）。',
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    context.read<AppState>().setCurrentPage('data_management');
                  },
                  icon: const Icon(Icons.folder_outlined),
                  label: const Text('前往数据管理'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    context.read<AppState>().setCurrentPage('settings');
                  },
                  child: const Text('打开设置'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
