import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:leadtrace/models/lead.dart';
import 'package:leadtrace/models/message.dart';
import 'package:leadtrace/services/lead/ai_client_service.dart';
import 'package:leadtrace/services/lead/lead_capture_service.dart';
import 'package:leadtrace/services/lead/lead_store.dart';

class _FakeAi extends AiClientService {
  @override
  Future<void> loadFromConfig() async {
    isReady = true;
    provider = 'openai';
    model = 'test';
  }

  @override
  Future<BusinessClassification> classifyBusinessSegment(
    String chatContent, {
    String previousSummary = '',
  }) async {
    return const BusinessClassification(
      label: 'recruitment',
      confidence: 0.9,
      shouldExtract: true,
      summary: '招聘',
    );
  }

  @override
  Future<LeadExtractionResult> extractBusinessLeads(
    String chatContent, {
    required String label,
    String previousSummary = '',
  }) async {
    return const LeadExtractionResult(
      summary: '招聘顾问',
      items: [
        {
          'title': '诚聘质量顾问',
          'description': '汽车零部件经验',
          'category': 'recruitment',
          'confidence': 0.9,
        },
      ],
    );
  }
}

Message _msg(String content, {int createTime = 0}) {
  final now = createTime == 0
      ? DateTime.now().millisecondsSinceEpoch ~/ 1000
      : createTime;
  return Message(
    localId: 1,
    serverId: 1,
    localType: 1,
    sortSeq: now,
    realSenderId: 1,
    createTime: now,
    status: 0,
    uploadStatus: 0,
    downloadStatus: 0,
    serverSeq: 0,
    originSource: 0,
    source: '',
    messageContent: content,
    compressContent: '',
    packedInfoData: const [],
    senderUsername: '李老师',
    parsedContent: content,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('LeadCaptureService.captureFromMessages creates leads', () async {
    final temp = await Directory.systemTemp.createTemp('capture_svc_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final store = LeadStore(filePathOverride: '${temp.path}/leads.json');
    final capture = LeadCaptureService(
      aiClient: _FakeAi(),
      store: store,
    );

    final created = await capture.captureFromMessages(
      [
        _msg('诚聘质量驻厂顾问，要求汽车零部件质量经验，地点浙江，电话13800000000。'),
      ],
      '功能测试群',
      confidenceThreshold: 0.6,
    );

    expect(created, isNotEmpty);
    expect(created.first.title, contains('聘'));
    final all = await store.getAll();
    expect(all.length, created.length);
  });

  test('LeadCaptureService.messageToLeadChat maps fields', () {
    final capture = LeadCaptureService(
      aiClient: _FakeAi(),
      store: LeadStore(filePathOverride: ''),
    );
    final m = _msg('hello', createTime: 1700000000);
    final mapped = capture.messageToLeadChat(m);
    expect(mapped.content, 'hello');
    expect(mapped.sender, '李老师');
    expect(mapped.timestampMs, 1700000000 * 1000);
  });
}
