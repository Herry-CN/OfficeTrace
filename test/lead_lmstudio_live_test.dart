import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leadtrace/models/lead.dart';
import 'package:leadtrace/services/lead/ai_client_service.dart';
import 'package:leadtrace/services/lead/lead_pipeline_service.dart';
import 'package:leadtrace/services/lead/lead_store.dart';

/// 对接本地 LM Studio 的端到端商机抓取验证。
/// 运行：`$env:LEADTRACE_LIVE_AI=1; flutter test test/lead_lmstudio_live_test.dart`
///
/// 注意：不使用 TestWidgetsFlutterBinding，否则 HTTP 会被拦截返回 400。
void main() {
  final live = Platform.environment['LEADTRACE_LIVE_AI'] == '1';

  group('LM Studio live lead pipeline', () {
    test(
      'classify and extract Chinese recruitment lead',
      () async {
        final ai = AiClientService();
        ai.openaiUrl = 'http://localhost:1234/v1';
        ai.openaiKey = 'lm-studio';
        ai.provider = 'openai';
        ai.model = 'qwen2.5-7b-instruct';
        ai.isReady = true;

        expect(await ai.checkOpenAiCompatible(), isTrue);

        final classification = await ai.classifyBusinessSegment(
          '[2026/4/4 18:58:37] [李老师]: 浙江精益企管集团招聘质量驻厂顾问，'
          '要求有汽车零部件行业质量主管经验，工作地点浙江，联系电话13800000000。',
        );
        expect(classification.label, 'recruitment');
        expect(classification.shouldExtract, isTrue);

        final tempDir = await Directory.systemTemp.createTemp('leadtrace_live_');
        addTearDown(() async {
          if (await tempDir.exists()) {
            await tempDir.delete(recursive: true);
          }
        });

        final store = LeadStore(
          filePathOverride: '${tempDir.path}/leads.json',
        );
        final pipeline = LeadPipelineService(aiClient: ai, store: store);
        final now = DateTime.now().millisecondsSinceEpoch;
        final messages = [
          LeadChatMessage(
            sender: '李老师',
            content:
                '浙江精益企管集团招聘质量驻厂顾问，要求有汽车零部件行业质量主管经验，工作地点浙江，联系电话13800000000。',
            timestampMs: now,
          ),
          LeadChatMessage(
            sender: '王工',
            content: '收到，我转给同事看看。',
            timestampMs: now + 60000,
          ),
        ];

        final leads = await pipeline.generateFromChat(
          messages,
          '测试商务群',
          confidenceThreshold: 0.6,
        );

        expect(leads, isNotEmpty, reason: 'should extract at least one lead');
        expect(
          leads.any(
            (l) =>
                l.category == 'recruitment' ||
                l.title.contains('招聘') ||
                l.description.contains('顾问'),
          ),
          isTrue,
        );
      },
      skip: live ? false : 'Set LEADTRACE_LIVE_AI=1 to run against LM Studio',
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
