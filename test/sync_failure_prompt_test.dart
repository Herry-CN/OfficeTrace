import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leadtrace/models/chat_session.dart';
import 'package:leadtrace/services/database_service.dart';
import 'package:leadtrace/services/incremental_decrypt_service.dart';
import 'package:leadtrace/services/lead/group_monitor_controller.dart';
import 'package:leadtrace/widgets/sync_failure_prompt.dart';

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

class _IdleDb extends DatabaseService {
  @override
  bool get isConnected => false;
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

Future<void> _stop(WidgetTester tester, GroupMonitorController c) async {
  c.setSyncEnabled(false);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('auto sync failure opens a dialog', (tester) async {
    final c = GroupMonitorController(
      databaseService: _IdleDb(),
      decryptService: _ThrowingDecrypt(),
    );
    addTearDown(() {
      c.setSyncEnabled(false);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncFailurePrompt(monitor: c),
        ),
      ),
    );
    await c.ensureBootstrapped();
    c.setSelected({_g('1@chatroom').username});
    await c.setCooldownSeconds(15);

    c.setSyncEnabled(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(find.text('自动同步失败'), findsOneWidget);
    expect(find.textContaining('磁盘被占用'), findsOneWidget);
    expect(find.textContaining('冷却后继续'), findsOneWidget);

    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.text('自动同步失败'), findsNothing);
    expect(c.syncFailureAlert, isNull);

    await _stop(tester, c);
  });

  testWidgets('stop button turns auto sync off', (tester) async {
    final c = GroupMonitorController(
      databaseService: _IdleDb(),
      decryptService: _ThrowingDecrypt(),
    );
    addTearDown(() {
      c.setSyncEnabled(false);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SyncFailurePrompt(monitor: c),
        ),
      ),
    );
    await c.ensureBootstrapped();
    await c.setCooldownSeconds(15);

    c.setSyncEnabled(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();

    expect(c.syncEnabled, isTrue);
    await tester.tap(find.text('停止自动同步'));
    await tester.pumpAndSettle();

    expect(c.syncEnabled, isFalse);
    expect(find.text('自动同步失败'), findsNothing);
    expect(c.syncFailureAlert, isNull);

    await _stop(tester, c);
  });
}
