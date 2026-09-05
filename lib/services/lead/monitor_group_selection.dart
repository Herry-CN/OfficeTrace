import 'dart:convert';

import '../../models/chat_session.dart';

/// 群监控选群：过滤、全选可见、导入导出 JSON
class MonitorGroupSelection {
  static const int exportVersion = 1;

  static List<ChatSession> filterGroups(
    List<ChatSession> groups,
    String query,
  ) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return List<ChatSession>.from(groups);
    return groups.where((g) {
      final name = (g.displayName ?? '').toLowerCase();
      final user = g.username.toLowerCase();
      return name.contains(q) || user.contains(q);
    }).toList();
  }

  /// 全选当前过滤结果（合并进已有选择）
  static Set<String> selectAllVisible(
    Set<String> current,
    List<ChatSession> visible,
  ) {
    return {...current, ...visible.map((g) => g.username)};
  }

  static Set<String> clearAll() => <String>{};

  static String encodeExport(Iterable<String> usernames) {
    final groups = usernames.where((u) => u.trim().isNotEmpty).toList();
    return const JsonEncoder.withIndent('  ').convert({
      'version': exportVersion,
      'groups': groups,
    });
  }

  /// 解析导入 JSON；非法内容抛出 [FormatException]。
  static List<String> parseImport(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('导入文件格式无效：根节点应为对象');
    }
    final groups = decoded['groups'];
    if (groups is! List) {
      throw const FormatException('导入文件格式无效：缺少 groups 数组');
    }
    return groups
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();
  }

  /// 应用导入：替换选择；返回 (已选集合, 未找到的 username)
  static ({Set<String> selected, List<String> missing}) applyImport({
    required List<String> imported,
    required Set<String> knownUsernames,
  }) {
    final selected = <String>{};
    final missing = <String>[];
    for (final id in imported) {
      selected.add(id);
      if (!knownUsernames.contains(id)) {
        missing.add(id);
      }
    }
    return (selected: selected, missing: missing);
  }
}
