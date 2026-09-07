import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leadtrace/models/chat_session.dart';
import 'package:leadtrace/models/lead.dart';
import 'package:leadtrace/models/message.dart';
import 'package:leadtrace/services/database_service.dart';
import 'package:leadtrace/services/lead/ai_client_service.dart';
import 'package:leadtrace/services/lead/group_monitor_controller.dart';
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
    await Future<void>.delayed(const Duration(milliseconds: 5));
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
          'title': '诚聘顾问',
          'description': '测试',
          'category': 'recruitment',
          'confidence': 0.9,
        },
      ],
    );
  }
}

class _FakeDb extends DatabaseService {
  _FakeDb(this.sessions);

  final List<ChatSession> sessions;

  @override
  bool get isConnected => true;

  @override
  Future<List<ChatSession>> getSessions({
    int? limit,
    bool groupsOnly = false,
    bool enrichNames = true,
  }) async {
    return sessions;
  }

  @override
  Future<Map<String, String>> getDisplayNames(
    List<String> usernames, {
    bool fast = false,
  }) async {
    return {for (final u in usernames) u: 'Name'};
  }

  @override
  Future<List<Message>> getMessages(
    String sessionId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return [
      Message(
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
        messageContent: '诚聘质量顾问电话13800000000',
        compressContent: '',
        packedInfoData: const [],
        senderUsername: 'a',
        parsedContent: '诚聘质量顾问电话13800000000',
      ),
    ];
  }
}

ChatSession _g(String id) => ChatSession(
      username: id,
      type: 0,
      unreadCount: 0,
      unreadFirstMsgSrvId: 0,
      isHidden: 0,
      summary: '',
      draft: '',
      status: 0,
      lastTimestamp: 0,
      sortTimestamp: 0,
      lastClearUnreadTimestamp: 0,
      lastMsgLocalId: 0,
      lastMsgType: 0,
      lastMsgSubType: 0,
      lastMsgSender: '',
      lastSenderDisplayName: '',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('monitoring flag is independent of page lifecycle', () {
    final c = GroupMonitorController(
      databaseService: DatabaseService(),
    );
    expect(c.monitoring, isFalse);
    c.setMonitoring(true);
    expect(c.monitoring, isTrue);
    c.setMonitoring(false);
    expect(c.monitoring, isFalse);
  });

  test('selection persists via config', () async {
    final c = GroupMonitorController(
      databaseService: DatabaseService(),
    );
    c.setSelected({'a@chatroom', 'b@chatroom'});
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('monitor_selected_groups'),
      containsAll(['a@chatroom', 'b@chatroom']),
    );
  });

  test('immediate capture can be cancelled and reports progress', () async {
    final temp = await Directory.systemTemp.createTemp('gm_cap_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final store = LeadStore(filePathOverride: '${temp.path}/leads.json');
    final ai = _FakeAi();
    final db = _FakeDb([
      _g('1@chatroom'),
      _g('2@chatroom'),
      _g('3@chatroom'),
      _g('4@chatroom'),
    ]);
    final capture = LeadCaptureService(aiClient: ai, store: store);
    final c = GroupMonitorController(
      databaseService: db,
      aiClient: ai,
      store: store,
      captureService: capture,
    );

    await c.ensureBootstrapped();
    c.setSelected({
      '1@chatroom',
      '2@chatroom',
      '3@chatroom',
      '4@chatroom',
    });

    final future = c.captureSelectedNow();
    // 等开始后再取消
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(c.capturing, isTrue);
    c.cancelCapture();
    await future;
    expect(c.capturing, isFalse);
    expect(c.captureDone, lessThan(4));
    expect(c.status, contains('取消'));
  });

  test('captureGroups shouldCancel stops early', () async {
    final temp = await Directory.systemTemp.createTemp('cap_cancel_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final store = LeadStore(filePathOverride: '${temp.path}/leads.json');
    final capture = LeadCaptureService(aiClient: _FakeAi(), store: store);
    final db = _FakeDb([_g('1@chatroom'), _g('2@chatroom'), _g('3@chatroom')]);
    var progressed = 0;
    await capture.captureGroups(
      database: db,
      groups: db.sessions,
      confidenceThreshold: 0.5,
      shouldCancel: () => progressed >= 1,
      onProgress: (done, total, name) {
        if (done > progressed) progressed = done;
      },
    );
    expect(progressed, lessThan(3));
  });
}
