import 'package:flutter_test/flutter_test.dart';

import 'package:leadtrace/services/lead/lead_category.dart';
import 'package:leadtrace/services/lead/lead_pipeline_service.dart';
import 'package:leadtrace/services/lead/lead_prompt_pack.dart';
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

    test('maps Chinese and compound dirty labels to fixed enum', () {
      expect(LeadCategory.normalize('招聘信息'), 'recruitment');
      expect(LeadCategory.normalize('寻找资源'), 'resource');
      expect(LeadCategory.normalize('寻找顾问、老师、专家'), 'expert');
      expect(LeadCategory.normalize('procurement|expert'), 'procurement');
      expect(LeadCategory.normalize('resource|expert'), 'resource');
      expect(LeadCategory.normalize('supply'), 'resource');
      expect(LeadCategory.normalize('供应'), 'resource');
      expect(LeadCategory.normalize('政策变化'), 'other');
      expect(LeadCategory.normalize('商机 / 资源类重要信息'), 'other');
      expect(LeadCategory.filterValues, hasLength(5));
      expect(
        LeadCategory.filterValues,
        containsAll(['recruitment', 'procurement', 'resource', 'expert', 'other']),
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

  group('LeadPromptPack', () {
    test('defaults force English category enum', () {
      expect(LeadPromptPack.defaultCategories, contains('禁止中文类名'));
      expect(LeadPromptPack.defaultCategories, contains('recruitment：'));
      expect(LeadPromptPack.defaultExtractionPrompt, contains('禁止把分类写成中文'));
      expect(
        LeadPromptPack.normalizeClassificationLabel('寻找资源', ''),
        'resource',
      );
      expect(
        LeadPromptPack.normalizeClassificationLabel('procurement|expert', ''),
        'procurement',
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

    test('normalizeLeadItems remaps Chinese category to enum', () {
      final items = AiClientService.normalizeLeadItems([
        {
          'title': '找渠道合作',
          'description': '需要华南经销渠道',
          'category': '寻找渠道',
          'confidence': 0.9,
        },
      ]);
      expect(items.single['category'], 'resource');
    });
  });
}
