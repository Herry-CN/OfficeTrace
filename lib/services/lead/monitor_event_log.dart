import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../app_path_service.dart';

/// 群监控事件日志：写在文档目录，重启后仍可恢复。
class MonitorEventLog {
  MonitorEventLog({String? filePathOverride})
      : _filePathOverride = filePathOverride;

  static const int maxEvents = 200;

  final String? _filePathOverride;
  Future<void> _writeChain = Future<void>.value();

  Future<String> resolveFilePath() async {
    if (_filePathOverride != null) return _filePathOverride!;
    final docs = await AppPathService.getDocumentsPath();
    final dir = Directory(p.join(docs, 'LeadTrace'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return p.join(dir.path, 'monitor_events.json');
  }

  Future<List<String>> load() async {
    try {
      final file = File(await resolveFilePath());
      if (!await file.exists()) return const [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .take(maxEvents)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// 覆盖写入当前事件（最新在前）。多次调用会按顺序落盘，避免互相覆盖。
  Future<void> save(List<String> events) {
    final snapshot = events.take(maxEvents).toList();
    final next = _writeChain.then((_) => _writeSnapshot(snapshot));
    _writeChain = next.catchError((_) {});
    return next;
  }

  Future<void> flush() => _writeChain;

  Future<void> _writeSnapshot(List<String> events) async {
    final file = File(await resolveFilePath());
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }
    await file.writeAsString(jsonEncode(events), flush: true);
  }
}
