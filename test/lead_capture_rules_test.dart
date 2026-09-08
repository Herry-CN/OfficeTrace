import 'package:flutter_test/flutter_test.dart';

import 'package:leadtrace/services/lead/lead_capture_rules.dart';

void main() {
  group('isCapturableText', () {
    test('rejects placeholders and empty', () {
      expect(LeadCaptureRules.isCapturableText('[图片]'), isFalse);
      expect(LeadCaptureRules.isCapturableText('[语音]'), isFalse);
      expect(LeadCaptureRules.isCapturableText('  '), isFalse);
    });

    test('accepts real text', () {
      expect(LeadCaptureRules.isCapturableText('诚聘质量顾问'), isTrue);
    });
  });

  group('gateRuleAgainstAi', () {
    test('AI irrelevant suppresses weak rule hits', () {
      final gated = LeadCaptureRules.gateRuleAgainstAi(
        aiItems: const [],
        ruleTodos: [
          {
            'title': '找顾问聊聊',
            'description': '周末找顾问吃饭',
            'category': 'expert',
            'confidence': 0.76,
          },
        ],
        aiLabel: 'irrelevant',
        aiConfidence: 0.8,
      );
      expect(gated, isEmpty);
    });

    test('AI irrelevant keeps strong recruitment rule', () {
      final gated = LeadCaptureRules.gateRuleAgainstAi(
        aiItems: const [],
        ruleTodos: [
          {
            'title': '诚聘质量工程师',
            'description': '诚聘质量工程师，薪资面议',
            'category': 'recruitment',
            'confidence': 0.9,
          },
        ],
        aiLabel: 'irrelevant',
        aiConfidence: 0.8,
      );
      expect(gated.length, 1);
    });
  });

  group('dedup', () {
    test('same fingerprint is duplicate', () {
      final fp = LeadCaptureRules.contentFingerprint(
        title: '招聘顾问',
        description: '浙江驻厂',
        sender: 'A',
        messageTime: '2026/4/4 18:58:37',
      );
      expect(
        LeadCaptureRules.isNearDuplicateCandidate(
          leftTitle: '招聘顾问',
          leftDescription: '浙江驻厂',
          leftSender: 'A',
          leftMessageTime: '2026/4/4 18:58:37',
          leftFingerprint: fp,
          rightTitle: '招聘顾问',
          rightDescription: '浙江驻厂',
          rightSender: 'A',
          rightMessageTime: '2026/4/4 18:58:37',
          rightFingerprint: fp,
        ),
        isTrue,
      );
    });

    test('normalized title equality catches punctuation variants', () {
      expect(
        LeadCaptureRules.isNearDuplicateCandidate(
          leftTitle: '招聘质量顾问！',
          leftDescription: '短',
          leftSender: 'A',
          leftMessageTime: 't1',
          rightTitle: '招聘质量顾问',
          rightDescription: '另',
          rightSender: 'B',
          rightMessageTime: 't2',
        ),
        isTrue,
      );
    });
  });

  group('shouldExtractSegment', () {
    test('honors aiShouldExtract with decent confidence', () {
      expect(
        LeadCaptureRules.shouldExtractSegment(
          hasRuleTodos: false,
          label: 'irrelevant',
          confidence: 0.6,
          aiShouldExtract: true,
        ),
        isTrue,
      );
    });
  });
}
