import 'package:flutter_test/flutter_test.dart';

import 'package:leadtrace/services/lead/lead_category.dart';
import 'package:leadtrace/services/lead/lead_pipeline_service.dart';
import 'package:leadtrace/services/lead/ai_client_service.dart';
import 'package:leadtrace/services/lead/lead_store.dart';

void main() {
  group('LeadCategory', () {
    test('resolve always returns exactly one category', () {
      expect(
        LeadCategory.resolve(
          itemCategory: 'recruitment',
          segmentLabel: 'procurement',
        ),
        'recruitment',
      );
      expect(
        LeadCategory.resolve(
          itemCategory: null,
          segmentLabel: 'resource',
        ),
        'resource',
      );
      expect(
        LeadCategory.resolve(
          itemCategory: 'irrelevant',
          title: '诚聘质量顾问',
        ),
        'recruitment',
      );
      expect(
        LeadCategory.resolve(itemCategory: '', title: '随便聊聊'),
        LeadCategory.other,
      );
    });

    test('inferFromText picks only the highest-priority class', () {
      expect(
        LeadCategory.inferFromText('诚聘顾问，也可找资源合作', null),
        'recruitment',
      );
      expect(
        LeadCategory.inferFromText('求购传感器并找渠道', null),
        'procurement',
      );
    });

    test('preferWhenMerging keeps one category and prefers segment match', () {
      expect(
        LeadCategory.preferWhenMerging(
          existing: 'resource',
          incoming: null,
          existingConfidence: 0.7,
          incomingConfidence: 0.95,
          segmentLabel: 'resource',
        ),
        'resource',
      );
      expect(
        LeadCategory.preferWhenMerging(
          existing: 'resource',
          incoming: 'recruitment',
          existingConfidence: 0.7,
          incomingConfidence: 0.9,
          segmentLabel: 'recruitment',
        ),
        'recruitment',
      );
      expect(
        LeadCategory.preferWhenMerging(
          existing: 'resource',
          incoming: 'recruitment',
          existingConfidence: 0.9,
          incomingConfidence: 0.8,
          segmentLabel: null,
        ),
        'resource',
      );
    });
  });

  group('LeadPipelineService category merge', () {
    late LeadPipelineService pipeline;

    setUp(() {
      pipeline = LeadPipelineService(
        aiClient: AiClientService(),
        store: LeadStore(filePathOverride: ''),
      );
    });

    test('merge keeps a single candidate with one category', () {
      final merged = pipeline.mergeLeadCandidates([
        {
          'title': '诚聘质量顾问',
          'description': '汽车零部件经验',
          'confidence': 0.7,
          'category': 'recruitment',
          'segmentLabel': 'recruitment',
          'sender': 'A',
          'messageTime': '2026/4/4 18:00:00',
        },
        {
          'title': '诚聘质量顾问',
          'description': '汽车零部件经验，电话私聊',
          'confidence': 0.95,
          'category': null,
          'segmentLabel': 'recruitment',
          'sender': 'A',
          'messageTime': '2026/4/4 18:00:00',
        },
      ]);
      expect(merged, hasLength(1));
      expect(merged.single['category'], 'recruitment');
    });

    test('merge fills missing category from the other duplicate', () {
      final merged = pipeline.mergeLeadCandidates([
        {
          'title': '求购传感器',
          'description': '预算五万',
          'confidence': 0.95,
          'category': null,
          'segmentLabel': 'procurement',
        },
        {
          'title': '求购传感器',
          'description': '预算五万',
          'confidence': 0.7,
          'category': 'procurement',
          'segmentLabel': 'procurement',
        },
      ]);
      expect(merged, hasLength(1));
      expect(merged.single['category'], 'procurement');
    });
  });
}
