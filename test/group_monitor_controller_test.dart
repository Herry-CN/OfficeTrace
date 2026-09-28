import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leadtrace/models/chat_session.dart';
import 'package:leadtrace/models/lead.dart';
import 'package:leadtrace/models/message.dart';
import 'package:leadtrace/services/database_service.dart';
import 'package:leadtrace/services/incremental_decrypt_service.dart';
import 'package:leadtrace/services/lead/ai_client_service.dart';
import 'package:leadtrace/services/lead/group_monitor_controller.dart';
import 'package:leadtrace/services/lead/lead_capture_service.dart';
import 'package:leadtrace/services/lead/lead_store.dart';
import 'package:leadtrace/services/lead/monitor_event_log.dart';

class _NoopDecrypt implements IncrementalDecryptRunner {
  @override
  Future<IncrementalDecryptResult> runIncrementalUpdate({
    required DatabaseService databaseService,
    required Future<void> Function() reconnectDatabase,
    void Function(String status)? onStatus,
    void Function(int done, int total, String fileName)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    return const IncrementalDecryptResult(
      scannedCount: 0,
      needsUpdateCount: 0,
      updatedCount: 0,
      failedCount: 0,
    );
  }
}

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

  test('sync loop flag is independent of page lifecycle', () {
    final c = GroupMonitorController(
      databaseService: DatabaseService(),
      decryptService: _NoopDecrypt(),
    );
    expect(c.syncEnabled, isFalse);
    expect(c.monitoring, isFalse);
    c.setSyncEnabled(true);
    expect(c.syncEnabled, isTrue);
    expect(c.monitoring, isTrue);
    c.setSyncEnabled(false);
    expect(c.syncEnabled, isFalse);
  });

  test('selection persists via config', () async {
    final c = GroupMonitorController(
      databaseService: DatabaseService(),
      decryptService: _NoopDecrypt(),
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
      decryptService: _NoopDecrypt(),
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

  test('event log survives a new controller', () async {
    final temp = await Directory.systemTemp.createTemp('gm_events_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final path = '${temp.path}${Platform.pathSeparator}monitor_events.json';
    final log = MonitorEventLog(filePathOverride: path);
    final first = GroupMonitorController(
      databaseService: DatabaseService(),
      decryptService: _NoopDecrypt(),
      eventLog: log,
    );
    first.pushEvent('旧会话 · 增量解密完成');
    first.pushEvent('旧会话 · 已开启自动同步循环');
    await log.flush();

    final second = GroupMonitorController(
      databaseService: DatabaseService(),
      decryptService: _NoopDecrypt(),
      eventLog: MonitorEventLog(filePathOverride: path),
    );
    await second.ensureBootstrapped();
    expect(second.events, [
      '旧会话 · 已开启自动同步循环',
      '旧会话 · 增量解密完成',
    ]);
  });

  test('event log keeps the newest 200 lines', () async {
    final temp = await Directory.systemTemp.createTemp('gm_events_cap_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final path = '${temp.path}${Platform.pathSeparator}monitor_events.json';
    final log = MonitorEventLog(filePathOverride: path);
    final c = GroupMonitorController(
      databaseService: DatabaseService(),
      decryptService: _NoopDecrypt(),
      eventLog: log,
    );
    for (var i = 0; i < 205; i++) {
      c.pushEvent('event-$i');
    }
    await log.flush();
    expect(c.events, hasLength(200));
    expect(c.events.first, 'event-204');
    expect(c.events.last, 'event-5');

    final restored = MonitorEventLog(filePathOverride: path);
    final loaded = await restored.load();
    expect(loaded, hasLength(200));
    expect(loaded.first, 'event-204');
  });

  test('corrupt event log file loads as empty', () async {
    final temp = await Directory.systemTemp.createTemp('gm_events_bad_');
    addTearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });
    final path = '${temp.path}${Platform.pathSeparator}monitor_events.json';
    await File(path).writeAsString('{not-json');
    final loaded = await MonitorEventLog(filePathOverride: path).load();
    expect(loaded, isEmpty);
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
