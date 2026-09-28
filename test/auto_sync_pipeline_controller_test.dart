import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leadtrace/models/chat_session.dart';
import 'package:leadtrace/models/lead.dart';
import 'package:leadtrace/models/message.dart';
import 'package:leadtrace/services/database_service.dart';
import 'package:leadtrace/services/incremental_decrypt_service.dart';
import 'package:leadtrace/services/lead/ai_client_service.dart';
import 'package:leadtrace/services/lead/auto_sync_pipeline_logic.dart';
import 'package:leadtrace/services/lead/group_monitor_controller.dart';
import 'package:leadtrace/services/lead/lead_capture_service.dart';
import 'package:leadtrace/services/lead/lead_store.dart';

class _ScriptedDecrypt implements IncrementalDecryptRunner {
  _ScriptedDecrypt(this.results);

  final List<IncrementalDecryptResult> results;
  int calls = 0;

  @override
  Future<IncrementalDecryptResult> runIncrementalUpdate({
    required DatabaseService databaseService,
    required Future<void> Function() reconnectDatabase,
    void Function(String status)? onStatus,
    void Function(int done, int total, String fileName)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    final idx = calls < results.length ? calls : results.length - 1;
    calls++;
    onStatus?.call('fake decrypt');
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return results[idx];
  }
}

class _ThrowingDecrypt implements IncrementalDecryptRunner {
  @override
  Future<IncrementalDecryptResult> runIncrementalUpdate({
    required DatabaseService databaseService,
    required Future<void> Function() reconnectDatabase,
    void Function(String status)? onStatus,
    void Function(int done, int total, String fileName)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    throw Exception('磁盘被占用');
  }
}

class _ThrowingCapture extends LeadCaptureService {
  _ThrowingCapture({required super.aiClient, required super.store});

  @override
  Future<CaptureGroupsResult> captureGroups({
    required DatabaseService database,
    required List<ChatSession> groups,
    int? analysisHours,
    double? confidenceThreshold,
    int messageLimit = 80,
    bool forceAll = false,
    void Function(int done, int total, String currentName)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    throw Exception('模型无响应');
  }
}
class _CountingCapture extends LeadCaptureService {
  _CountingCapture({required super.aiClient, required super.store});

  int captureGroupsCalls = 0;

  @override
  Future<CaptureGroupsResult> captureGroups({
    required DatabaseService database,
    required List<ChatSession> groups,
    int? analysisHours,
    double? confidenceThreshold,
    int messageLimit = 80,
    bool forceAll = false,
    void Function(int done, int total, String currentName)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    captureGroupsCalls++;
    onProgress?.call(groups.length, groups.length, 'done');
    return CaptureGroupsResult(
      createdCount: 0,
      processedGroups: groups.length,
      skippedUnchanged: 0,
    );
  }
}

class _FakeAi extends AiClientService {
  @override
  Future<void> loadFromConfig() async {
    isReady = true;
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
    );
  }

  @override
  Future<LeadExtractionResult> extractBusinessLeads(
    String chatContent, {
    required String label,
    String previousSummary = '',
  }) async {
    return const LeadExtractionResult(items: []);
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
  }) async =>
      sessions;

  @override
  Future<Map<String, String>> getDisplayNames(
    List<String> usernames, {
    bool fast = false,
  }) async =>
      {for (final u in usernames) u: u};

  @override
  Future<List<Message>> getMessages(
    String sessionId, {
    int limit = 50,
    int offset = 0,
  }) async =>
      const [];
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

  test('no db changes skips capture then enters cooldown', () async {
    final decrypt = _ScriptedDecrypt([
      const IncrementalDecryptResult(
        scannedCount: 3,
        needsUpdateCount: 0,
        updatedCount: 0,
        failedCount: 0,
      ),
    ]);
    final ai = _FakeAi();
    final store = LeadStore(filePathOverride: 'unused-pipeline.json');
    final capture = _CountingCapture(aiClient: ai, store: store);
    final c = GroupMonitorController(
      databaseService: _FakeDb([_g('1@chatroom')]),
      aiClient: ai,
      store: store,
      captureService: capture,
      decryptService: decrypt,
    );

    await c.ensureBootstrapped();
    c.setSelected({'1@chatroom'});
    await c.setCooldownSeconds(15);

    c.setSyncEnabled(true);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(decrypt.calls, greaterThanOrEqualTo(1));
    expect(capture.captureGroupsCalls, 0);
    expect(c.lastSkippedCapture, isTrue);
    expect(c.phase, SyncPhase.cooldown);
    expect(
      c.events.any((e) => e.contains('无库变更')),
      isTrue,
    );
    expect(c.syncFailureAlert, isNull);

    c.setSyncEnabled(false);
  });

  test('db changes with selection triggers capture', () async {
    final decrypt = _ScriptedDecrypt([
      const IncrementalDecryptResult(
        scannedCount: 3,
        needsUpdateCount: 1,
        updatedCount: 1,
        failedCount: 0,
      ),
    ]);
    final ai = _FakeAi();
    final store = LeadStore(filePathOverride: 'unused-pipeline2.json');
    final capture = _CountingCapture(aiClient: ai, store: store);
    final c = GroupMonitorController(
      databaseService: _FakeDb([_g('1@chatroom')]),
      aiClient: ai,
      store: store,
      captureService: capture,
      decryptService: decrypt,
    );

    await c.ensureBootstrapped();
    c.setSelected({'1@chatroom'});
    await c.setCooldownSeconds(15);

    c.setSyncEnabled(true);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(capture.captureGroupsCalls, greaterThanOrEqualTo(1));
    expect(c.lastSkippedCapture, isFalse);

    c.setSyncEnabled(false);
  });

  test('db changes without selection skips capture', () async {
    final decrypt = _ScriptedDecrypt([
      const IncrementalDecryptResult(
        scannedCount: 2,
        needsUpdateCount: 1,
        updatedCount: 1,
        failedCount: 0,
      ),
    ]);
    final ai = _FakeAi();
    final store = LeadStore(filePathOverride: 'unused-pipeline3.json');
    final capture = _CountingCapture(aiClient: ai, store: store);
    final c = GroupMonitorController(
      databaseService: _FakeDb([_g('1@chatroom')]),
      aiClient: ai,
      store: store,
      captureService: capture,
      decryptService: decrypt,
    );

    await c.ensureBootstrapped();
    // leave selection empty
    await c.setCooldownSeconds(15);

    c.setSyncEnabled(true);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(capture.captureGroupsCalls, 0);
    expect(
      c.events.any((e) => e.contains('未选监控群')),
      isTrue,
    );

    c.setSyncEnabled(false);
  });

  test('decrypt exception queues a failure alert and keeps the log', () async {
    final ai = _FakeAi();
    final store = LeadStore(filePathOverride: 'unused-pipeline-fail.json');
    final c = GroupMonitorController(
      databaseService: _FakeDb([_g('1@chatroom')]),
      aiClient: ai,
      store: store,
      captureService: _CountingCapture(aiClient: ai, store: store),
      decryptService: _ThrowingDecrypt(),
    );

    await c.ensureBootstrapped();
    c.setSelected({'1@chatroom'});
    await c.setCooldownSeconds(15);

    c.setSyncEnabled(true);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(c.syncFailureAlert, contains('增量解密失败'));
    expect(c.syncFailureAlert, contains('磁盘被占用'));
    expect(c.events.any((e) => e.contains('增量解密失败')), isTrue);
    expect(c.pendingSyncFailureCount, 1);

    c.acknowledgeSyncFailure();
    expect(c.syncFailureAlert, isNull);

    c.setSyncEnabled(false);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });

  test('decrypt error message queues a failure alert', () async {
    final decrypt = _ScriptedDecrypt([
      const IncrementalDecryptResult(
        scannedCount: 2,
        needsUpdateCount: 1,
        updatedCount: 0,
        failedCount: 1,
        errorMessage: '重新连接数据库失败: locked',
      ),
    ]);
    final ai = _FakeAi();
    final store = LeadStore(filePathOverride: 'unused-pipeline-errmsg.json');
    final c = GroupMonitorController(
      databaseService: _FakeDb([_g('1@chatroom')]),
      aiClient: ai,
      store: store,
      captureService: _CountingCapture(aiClient: ai, store: store),
      decryptService: decrypt,
    );

    await c.ensureBootstrapped();
    await c.setCooldownSeconds(15);
    c.setSyncEnabled(true);
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(c.syncFailureAlert, '重新连接数据库失败: locked');
    expect(c.events.any((e) => e.contains('重新连接数据库失败')), isTrue);

    c.setSyncEnabled(false);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });

  test('partial decrypt failures queue an alert', () async {
    final decrypt = _ScriptedDecrypt([
      const IncrementalDecryptResult(
        scannedCount: 4,
        needsUpdateCount: 2,
        updatedCount: 1,
        failedCount: 1,
      ),
    ]);
    final ai = _FakeAi();
    final store = LeadStore(filePathOverride: 'unused-pipeline-partial.json');
    final c = GroupMonitorController(
      databaseService: _FakeDb([_g('1@chatroom')]),
      aiClient: ai,
      store: store,
      captureService: _CountingCapture(aiClient: ai, store: store),
      decryptService: decrypt,
    );

    await c.ensureBootstrapped();
    c.setSelected({'1@chatroom'});
    await c.setCooldownSeconds(15);
    c.setSyncEnabled(true);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(c.syncFailureAlert, contains('1 个文件失败'));
    expect(c.events.any((e) => e.contains('失败 1')), isTrue);

    c.setSyncEnabled(false);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });

  test('capture exception during auto sync queues a failure alert', () async {
    final decrypt = _ScriptedDecrypt([
      const IncrementalDecryptResult(
        scannedCount: 2,
        needsUpdateCount: 1,
        updatedCount: 1,
        failedCount: 0,
      ),
    ]);
    final ai = _FakeAi();
    final store = LeadStore(filePathOverride: 'unused-pipeline-capture.json');
    final c = GroupMonitorController(
      databaseService: _FakeDb([_g('1@chatroom')]),
      aiClient: ai,
      store: store,
      captureService: _ThrowingCapture(aiClient: ai, store: store),
      decryptService: decrypt,
    );

    await c.ensureBootstrapped();
    c.setSelected({'1@chatroom'});
    await c.setCooldownSeconds(15);
    c.setSyncEnabled(true);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(c.syncFailureAlert, contains('抓取失败'));
    expect(c.syncFailureAlert, contains('模型无响应'));
    expect(c.events.any((e) => e.contains('抓取失败')), isTrue);

    c.setSyncEnabled(false);
    await Future<void>.delayed(const Duration(milliseconds: 400));
  });
}
