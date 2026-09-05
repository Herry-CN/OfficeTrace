import 'package:flutter_test/flutter_test.dart';
import 'package:leadtrace/models/lead.dart';
import 'package:leadtrace/services/lead/lead_pipeline_service.dart';
import 'package:leadtrace/services/lead/lead_store.dart';
import 'package:leadtrace/services/lead/ai_client_service.dart';

void main() {
  group('LeadPipelineService segmentation', () {
    late LeadPipelineService pipeline;

    setUp(() {
      pipeline = LeadPipelineService(
        aiClient: AiClientService(),
        store: LeadStore(filePathOverride: ''),
      );
    });

    test('detectBusinessSignals finds recruitment', () {
      final signals = pipeline.detectBusinessSignals('急招质量工程师，薪资面议，请私聊');
      expect(signals.labels, contains('recruitment'));
      expect(signals.isRelevant, isTrue);
      expect(signals.score, greaterThan(0.5));
    });

    test('buildBusinessSegments splits on large time gap', () {
      final now = DateTime(2026, 4, 4, 10).millisecondsSinceEpoch;
      final msgs = pipeline.normalizeBusinessMessages([
        LeadChatMessage(
          sender: 'A',
          content: '招聘质量顾问，电话13800000000',
          timestampMs: now,
        ),
        LeadChatMessage(
          sender: 'B',
          content: '求购一批传感器，预算5万',
          timestampMs: now + 2 * 60 * 60 * 1000,
        ),
      ]);
      final segments = pipeline.buildBusinessSegments(msgs);
      expect(segments.length, greaterThanOrEqualTo(2));
    });

    test('fallbackExtractImportantMessages extracts recruitment', () {
      final msgs = pipeline.normalizeBusinessMessages([
        LeadChatMessage(
          sender: '李老师',
          content: '诚聘质量驻厂顾问，要求汽车零部件经验',
          timestampMs: DateTime(2026, 4, 4, 18, 58, 37).millisecondsSinceEpoch,
        ),
      ]);
      final items = pipeline.fallbackExtractImportantMessages(msgs);
      expect(items, isNotEmpty);
      expect(items.first['category'], 'recruitment');
      expect(items.first['confidence'], greaterThanOrEqualTo(0.9));
    });

    test('isDuplicateLeadCandidate by title', () {
      final a = {'title': '招聘顾问', 'description': 'abc'};
      final b = {'title': '招聘顾问', 'description': 'xyz'};
      expect(pipeline.isDuplicateLeadCandidate(a, b), isTrue);
    });

    test('jaccardSimilarity high for similar strings', () {
      final sim = LeadStore.jaccardSimilarity('招聘质量顾问电话联系', '招聘质量顾问请电话联系');
      expect(sim, greaterThan(0.7));
    });
  });
}
