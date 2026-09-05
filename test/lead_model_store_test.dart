import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leadtrace/models/lead.dart';
import 'package:leadtrace/services/lead/lead_store.dart';

void main() {
  group('Lead model', () {
    test('toJson/fromJson roundtrip', () {
      final now = DateTime.parse('2026-04-04T18:58:37.000');
      final lead = Lead(
        id: 'abc',
        title: '招聘质量顾问',
        description: '浙江地区',
        priority: 'high',
        category: 'recruitment',
        confidence: 0.92,
        groupName: '测试群',
        sender: '李老师',
        messageTime: '2026/4/4 18:58:37',
        source: 'ai-generated',
        createdAt: now,
        updatedAt: now,
      );
      final restored = Lead.fromJson(lead.toJson());
      expect(restored.id, 'abc');
      expect(restored.title, '招聘质量顾问');
      expect(restored.confidence, closeTo(0.92, 0.001));
      expect(restored.category, 'recruitment');
      expect(Lead.categoryLabel(restored.category), '招聘');
    });
  });

  group('LeadStore', () {
    late Directory tempDir;
    late LeadStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('leadtrace_leads_');
      store = LeadStore(filePathOverride: '${tempDir.path}/leads.json');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('create persist and reload', () async {
      final created = await store.create({
        'title': '求购传感器',
        'description': '预算5万',
        'category': 'procurement',
        'confidence': 0.88,
        'groupName': '采购群',
        'source': 'ai-generated',
      });
      expect(created.id, isNotEmpty);

      final reloaded = LeadStore(filePathOverride: '${tempDir.path}/leads.json');
      final all = await reloaded.getAll();
      expect(all.length, 1);
      expect(all.first.title, '求购传感器');
      expect(all.first.confidence, closeTo(0.88, 0.001));
    });

    test('toggleComplete and delete', () async {
      final lead = await store.create({'title': '找渠道', 'category': 'resource'});
      final toggled = await store.toggleComplete(lead.id);
      expect(toggled.completed, isTrue);
      await store.delete(lead.id);
      final all = await store.getAll();
      expect(all, isEmpty);
    });

    test('isDuplicateOfExisting', () async {
      await store.create({
        'title': '招聘顾问',
        'groupName': '群A',
        'messageTime': '2026/4/4 18:58:37',
        'sender': '李老师',
      });
      expect(
        store.isDuplicateOfExisting({
          'title': '其他标题',
          'messageTime': '2026/4/4 18:58:37',
          'sender': '李老师',
        }, '群A'),
        isTrue,
      );
    });
  });
}
