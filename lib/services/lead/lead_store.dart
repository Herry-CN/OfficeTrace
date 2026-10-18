import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;

import '../../models/lead.dart';
import '../app_path_service.dart';
import 'lead_capture_rules.dart';
import 'lead_category.dart';

/// 商机持久化：应用文档目录下 LeadTrace/leads.json
class LeadStore {
  LeadStore({String? filePathOverride}) : _filePathOverride = filePathOverride;

  final String? _filePathOverride;
  final List<Lead> _leads = [];
  bool _loaded = false;

  List<Lead> get leads => List.unmodifiable(_leads);

  Future<String> resolveFilePath() async {
    if (_filePathOverride != null) return _filePathOverride!;
    final docs = await AppPathService.getDocumentsPath();
    final dir = Directory(p.join(docs, 'LeadTrace'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return p.join(dir.path, 'leads.json');
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    await loadFromDisk();
    _loaded = true;
  }

  Future<List<Lead>> getAll() async {
    await ensureLoaded();
    final sorted = [..._leads];
    sorted.sort((a, b) {
      if (a.completed != b.completed) {
        return a.completed ? 1 : -1;
      }
      const priorityOrder = {'high': 0, 'medium': 1, 'low': 2};
      final pa = priorityOrder[a.priority] ?? 1;
      final pb = priorityOrder[b.priority] ?? 1;
      if (pa != pb) return pa.compareTo(pb);
      return b.createdAt.compareTo(a.createdAt);
    });
    return sorted;
  }

  Future<Lead?> getById(String id) async {
    await ensureLoaded();
    try {
      return _leads.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<Lead> create(Map<String, dynamic> data) async {
    await ensureLoaded();
    final now = DateTime.now();
    final title = data['title']?.toString() ?? '';
    final description = data['description']?.toString() ?? '';
    final sender = data['sender']?.toString();
    final messageTime = data['messageTime']?.toString();
    final messageId = data['messageId']?.toString();
    final fingerprint = data['fingerprint']?.toString() ??
        LeadCaptureRules.contentFingerprint(
          title: title,
          description: description,
          sender: sender,
          messageTime: messageTime,
          messageId: messageId,
        );
    final lead = Lead(
      id: _newId(),
      title: title,
      description: description,
      priority: data['priority']?.toString() ?? 'medium',
      dueDate: data['dueDate']?.toString(),
      completed: false,
      source: data['source']?.toString() ?? 'manual',
      sourceMessage: data['sourceMessage']?.toString(),
      groupName: data['groupName']?.toString(),
      sender: sender,
      messageTime: messageTime,
      category: LeadCategory.resolve(
        itemCategory: data['category']?.toString(),
        title: title,
        description: description,
      ),
      confidence: data['confidence'] is num
          ? (data['confidence'] as num).toDouble()
          : double.tryParse(data['confidence']?.toString() ?? ''),
      fingerprint: fingerprint,
      messageId: messageId,
      createdAt: now,
      updatedAt: now,
    );
    _leads.add(lead);
    await saveToDisk();
    return lead;
  }

  Future<Lead> update(String id, Map<String, dynamic> updates) async {
    await ensureLoaded();
    final index = _leads.indexWhere((l) => l.id == id);
    if (index < 0) throw Exception('商机不存在');
    final current = _leads[index];
    final updated = current.copyWith(
      title: updates.containsKey('title')
          ? updates['title']?.toString()
          : current.title,
      description: updates.containsKey('description')
          ? updates['description']?.toString()
          : current.description,
      priority: updates.containsKey('priority')
          ? updates['priority']?.toString()
          : current.priority,
      dueDate: updates.containsKey('dueDate')
          ? updates['dueDate']?.toString()
          : current.dueDate,
      completed: updates.containsKey('completed')
          ? updates['completed'] == true
          : current.completed,
      category: updates.containsKey('category')
          ? updates['category']?.toString()
          : current.category,
      updatedAt: DateTime.now(),
    );
    _leads[index] = updated;
    await saveToDisk();
    return updated;
  }

  Future<void> delete(String id) async {
    await ensureLoaded();
    _leads.removeWhere((l) => l.id == id);
    await saveToDisk();
  }

  Future<int> deleteAll() async {
    await ensureLoaded();
    final count = _leads.length;
    _leads.clear();
    await saveToDisk();
    return count;
  }

  Future<Lead> toggleComplete(String id) async {
    await ensureLoaded();
    final index = _leads.indexWhere((l) => l.id == id);
    if (index < 0) throw Exception('商机不存在');
    final current = _leads[index];
    final updated = current.copyWith(
      completed: !current.completed,
      updatedAt: DateTime.now(),
    );
    _leads[index] = updated;
    await saveToDisk();
    return updated;
  }

  bool isDuplicateOfExisting(Map<String, dynamic> candidate, String? chatName) {
    final cTitle = candidate['title']?.toString();
    final cDesc = candidate['description']?.toString();
    final cSender = candidate['sender']?.toString();
    final cTime = candidate['messageTime']?.toString();
    final cFp = candidate['fingerprint']?.toString();
    final cMid = candidate['messageId']?.toString();

    for (final existing in _leads) {
      if (existing.groupName != chatName) continue;
      if (LeadCaptureRules.isNearDuplicateCandidate(
        leftTitle: existing.title,
        leftDescription: existing.description,
        leftSender: existing.sender,
        leftMessageTime: existing.messageTime,
        leftFingerprint: existing.fingerprint,
        leftMessageId: existing.messageId,
        rightTitle: cTitle,
        rightDescription: cDesc,
        rightSender: cSender,
        rightMessageTime: cTime,
        rightFingerprint: cFp,
        rightMessageId: cMid,
      )) {
        return true;
      }
    }
    return false;
  }

  Future<void> loadFromDisk() async {
    try {
      final path = await resolveFilePath();
      final file = File(path);
      if (!await file.exists()) {
        _leads.clear();
        return;
      }
      final content = await file.readAsString();
      final parsed = jsonDecode(content);
      if (parsed is List) {
        _leads
          ..clear()
          ..addAll(
            parsed
                .whereType<Map>()
                .map((e) => Lead.fromJson(Map<String, dynamic>.from(e))),
          );
      } else {
        _leads.clear();
      }
    } catch (_) {
      _leads.clear();
    }
  }

  Future<void> saveToDisk() async {
    final path = await resolveFilePath();
    final file = File(path);
    await file.parent.create(recursive: true);
    final payload = _leads.map((l) => l.toJson()).toList();
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
  }

  String _newId() {
    final rand = Random();
    final millis = DateTime.now().millisecondsSinceEpoch;
    return '${millis.toRadixString(16)}-${rand.nextInt(1 << 32).toRadixString(16)}';
  }

  /// 字符级 Jaccard（兼容旧测试）；新去重请用 [LeadCaptureRules.bigramJaccard]。
  static double jaccardSimilarity(String str1, String str2) {
    return LeadCaptureRules.bigramJaccard(str1, str2);
  }
}
