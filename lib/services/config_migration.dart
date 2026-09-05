import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// 从旧版 EchoTrace 的 SharedPreferences 迁移到 LeadTrace。
///
/// Windows 上 SharedPreferences 目录为 `%APPDATA%\<CompanyName>\<ProductName>`，
/// 产品名从 echotrace 改为 LeadTrace 后会变成全新空配置，导致找不到数据库。
class ConfigMigration {
  static const _legacyRelativePaths = <String>[
    'com.example\\echotrace\\shared_preferences.json',
    'com.example\\EchoTrace\\shared_preferences.json',
  ];

  /// 若当前缺少 database_path，则从旧 EchoTrace 配置导入关键项。
  /// 返回迁移写入的键数量；0 表示未迁移。
  static Future<int> migrateFromEchoTraceIfNeeded({
    SharedPreferences? prefs,
    String? appDataRoamingOverride,
    List<String>? legacyFileOverrides,
  }) async {
    final store = prefs ?? await SharedPreferences.getInstance();
    final currentPath = store.getString('database_path');
    if (currentPath != null && currentPath.trim().isNotEmpty) {
      return 0;
    }

    final legacy = await _loadLegacyMap(
      appDataRoamingOverride: appDataRoamingOverride,
      legacyFileOverrides: legacyFileOverrides,
    );
    if (legacy == null || legacy.isEmpty) {
      return 0;
    }

    var written = 0;
    for (final entry in legacy.entries) {
      final key = _stripFlutterPrefix(entry.key);
      if (key.isEmpty) continue;
      // 已有值（例如新同意的隐私协议）不覆盖
      if (store.containsKey(key)) continue;
      final value = entry.value;
      if (value is bool) {
        await store.setBool(key, value);
        written++;
      } else if (value is int) {
        await store.setInt(key, value);
        written++;
      } else if (value is double) {
        await store.setDouble(key, value);
        written++;
      } else if (value is String) {
        await store.setString(key, value);
        written++;
      } else if (value is List) {
        await store.setStringList(
          key,
          value.map((e) => e.toString()).toList(),
        );
        written++;
      }
    }
    return written;
  }

  static String _stripFlutterPrefix(String key) {
    const prefix = 'flutter.';
    if (key.startsWith(prefix)) {
      return key.substring(prefix.length);
    }
    return key;
  }

  static Future<Map<String, dynamic>?> _loadLegacyMap({
    String? appDataRoamingOverride,
    List<String>? legacyFileOverrides,
  }) async {
    final files = <String>[
      ...?legacyFileOverrides,
    ];
    if (files.isEmpty && Platform.isWindows) {
      final roaming = appDataRoamingOverride ??
          Platform.environment['APPDATA'] ??
          '';
      if (roaming.isNotEmpty) {
        for (final rel in _legacyRelativePaths) {
          files.add('$roaming${Platform.pathSeparator}$rel');
        }
      }
    }

    for (final path in files) {
      final file = File(path);
      if (!await file.exists()) continue;
      try {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {
        // try next candidate
      }
    }
    return null;
  }
}
