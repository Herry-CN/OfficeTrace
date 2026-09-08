import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leadtrace/models/chat_session.dart';
import 'package:leadtrace/models/lead.dart';
import 'package:leadtrace/models/message.dart';
import 'package:leadtrace/services/database_service.dart';
import 'package:leadtrace/services/lead/ai_client_service.dart';
import 'package:leadtrace/services/lead/lead_capture_service.dart';
import 'package:leadtrace/services/lead/lead_store.dart';

class _FakeAi extends AiClientService {
  int classifyCalls = 0;

  @override
  Future<void> loadFromConfig() async {
    isReady = true;
  }

  @override
  Future<BusinessClassification> classifyBusinessSegment(
    String chatContent, {
    String previousSummary = '',
  }) async {
    classifyCalls++;
    return const BusinessClassification(
      label: 'recruitment',
      confidence: 0.9,
      shouldExtract: true,
    );
  }

  @override
  Future<LeadExtractionResult> extractBusinessLeads(
    String chatContent, {
    required String label,
    String previousSummary = '',
  }) async {
    return const LeadExtractionResult(
      items: [
        {
          'title': '诚聘',
          'description': '测试',
          'category': 'recruitment',
          'confidence': 0.9,
        },
      ],
    );
  }
}

class _FakeDb extends DatabaseService {
  _FakeDb(this.bySession);

  final Map<String, List<Message>> bySession;

  @override
  bool get isConnected => true;

  @override
  Future<List<Message>> getMessages(
    String sessionId, {
    int limit = 50,
    int offset = 0,
  }) async {
    return bySession[sessionId] ?? const [];
  }
}

ChatSession _g(String id, {int lastTimestamp = 0}) => ChatSession(
      username: id,
      type: 0,
      unreadCount: 0,
      unreadFirstMsgSrvId: 0,
      isHidden: 0,
      summary: '',
      draft: '',
      status: 0,
      lastTimestamp: lastTimestamp,
      sortTimestamp: lastTimestamp,
      lastClearUnreadTimestamp: 0,
      lastMsgLocalId: 0,
      lastMsgType: 0,
      lastMsgSubType: 0,
      lastMsgSender: '',
      lastSenderDisplayName: '',
    );

Message _m(int createTime, String text) => Message(
      localId: createTime,
      serverId: createTime,
      localType: 1,
      sortSeq: createTime,
      realSenderId: 1,
      createTime: createTime,
      status: 0,
      uploadStatus: 0,
      downloadStatus: 0,
      serverSeq: 0,
      originSource: 0,
      source: '',
      messageContent: text,
      compressContent: '',
      packedInfoData: const [],
      senderUsername: 'a',
      parsedContent: text,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('skips unchanged groups and only AI-processes new ones', () async {
    final ai = _FakeAi();
    final temp = await Directory.systemTemp.createTemp('cap_skip_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final store = LeadStore(filePathOverride: '${temp.path}/leads.json');
    final capture = LeadCaptureService(aiClient: ai, store: store);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'lead_capture_watermarks',
      '{"old@chatroom":100}',
    );

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final db = _FakeDb({
      'old@chatroom': [_m(100, '诚聘旧消息电话13800000001')],
      'new@chatroom': [_m(now, '诚聘新消息电话13800000002')],
    });

    final result = await capture.captureGroups(
      database: db,
      groups: [
        _g('old@chatroom', lastTimestamp: 100),
        _g('new@chatroom', lastTimestamp: now),
      ],
      confidenceThreshold: 0.5,
      analysisHours: 24,
    );

    expect(result.skippedUnchanged, 1);
    expect(result.processedGroups, 1);
    expect(ai.classifyCalls, greaterThan(0));
    expect(result.createdCount, greaterThanOrEqualTo(0));

    final saved = prefs.getString('lead_capture_watermarks')!;
    expect(saved.contains('new@chatroom'), isTrue);
  });

  test('forceAll ignores watermarks', () async {
    final ai = _FakeAi();
    final temp = await Directory.systemTemp.createTemp('cap_force_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final store = LeadStore(filePathOverride: '${temp.path}/leads.json');
    final capture = LeadCaptureService(aiClient: ai, store: store);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'lead_capture_watermarks',
      '{"a@chatroom":999999999}',
    );

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final db = _FakeDb({
      'a@chatroom': [_m(now, '诚聘顾问电话13800000003')],
    });

    final result = await capture.captureGroups(
      database: db,
      groups: [_g('a@chatroom', lastTimestamp: now)],
      confidenceThreshold: 0.5,
      forceAll: true,
    );

    expect(result.skippedUnchanged, 0);
    expect(result.processedGroups, 1);
  });
}
