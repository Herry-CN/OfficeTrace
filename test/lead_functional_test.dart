import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:leadtrace/models/lead.dart';
import 'package:leadtrace/models/message.dart';
import 'package:leadtrace/services/database_service.dart';
import 'package:leadtrace/services/lead/ai_client_service.dart';
import 'package:leadtrace/services/lead/lead_pipeline_service.dart';
import 'package:leadtrace/services/lead/lead_store.dart';

/// 真实数据 + LM Studio 功能测试。
/// 运行：
/// `$env:LEADTRACE_FUNC_TEST=1; flutter test test/lead_functional_test.dart --reporter expanded`
void main() {
  final enabled = Platform.environment['LEADTRACE_FUNC_TEST'] == '1';
  final docs = Platform.environment['USERPROFILE'] != null
      ? '${Platform.environment['USERPROFILE']}\\Documents\\EchoTrace\\LyraHerry'
      : r'C:\Users\hearl\Documents\EchoTrace\LyraHerry';
  final sessionDb = '$docs\\session.db';

  group('LeadTrace functional', () {
    late DatabaseService db;
    late AiClientService ai;

    setUpAll(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = DatabaseService();
      await db.initialize(factory: databaseFactoryFfi);
      db.setManualWxid('LyraHerry');
      ai = AiClientService();
      ai.openaiUrl = 'http://localhost:1234/v1';
      ai.openaiKey = 'lm-studio';
      ai.provider = 'openai';
      ai.model = 'qwen2.5-7b-instruct';
      ai.isReady = true;
    });

    tearDown(() async {
      await db.close();
    });

    test(
      'connect decrypted LyraHerry session.db',
      () async {
        expect(File(sessionDb).existsSync(), isTrue,
            reason: 'expected decrypted DB at $sessionDb');
        await db.connectDecryptedDatabase(
          sessionDb,
          factory: databaseFactoryFfi,
        );
        expect(db.isConnected, isTrue);
        expect(db.mode, DatabaseMode.decrypted);
      },
      skip: enabled ? false : 'Set LEADTRACE_FUNC_TEST=1',
    );

    test(
      'list group sessions from real DB',
      () async {
        await db.connectDecryptedDatabase(
          sessionDb,
          factory: databaseFactoryFfi,
        );
        final sessions = await db.getSessions();
        expect(sessions, isNotEmpty);
        final groups = sessions.where((s) => s.isGroup).toList();
        // ignore: avoid_print
        print('sessions=${sessions.length} groups=${groups.length}');
        if (groups.isNotEmpty) {
          expect(groups.first.username.contains('@chatroom'), isTrue);
        }
      },
      skip: enabled ? false : 'Set LEADTRACE_FUNC_TEST=1',
    );

    test(
      'LM Studio reachable',
      () async {
        expect(await ai.checkOpenAiCompatible(), isTrue);
        final models = await ai.getOpenAiModels();
        expect(models.any((m) => m.contains('qwen')), isTrue);
      },
      skip: enabled ? false : 'Set LEADTRACE_FUNC_TEST=1',
    );

    test(
      'extract leads from a real group chat window',
      () async {
        await db.connectDecryptedDatabase(
          sessionDb,
          factory: databaseFactoryFfi,
        );
        final sessions = await db.getSessions();
        final groups = sessions.where((s) => s.isGroup).toList();
        expect(groups, isNotEmpty, reason: 'need at least one group chat');

        String? username;
        String? displayName;
        List<Message>? messages;
        for (final g in groups.take(30)) {
          final msgs = await db.getMessages(g.username, limit: 80, offset: 0);
          final textMsgs = msgs
              .where((m) => m.displayContent.trim().isNotEmpty)
              .toList();
          if (textMsgs.length >= 3) {
            username = g.username;
            displayName = g.displayName;
            messages = textMsgs;
            break;
          }
        }
        expect(messages, isNotNull,
            reason: 'no group with enough text messages');

        final chatName = (displayName != null && displayName.isNotEmpty)
            ? displayName
            : username!;
        // ignore: avoid_print
        print('testing group=$chatName messages=${messages!.length}');

        final tempDir = await Directory.systemTemp.createTemp('lead_func_');
        addTearDown(() async {
          if (await tempDir.exists()) await tempDir.delete(recursive: true);
        });
        final store = LeadStore(filePathOverride: '${tempDir.path}/leads.json');
        final pipeline = LeadPipelineService(aiClient: ai, store: store);

        final input = messages
            .map(
              (m) => LeadChatMessage(
                id: m.localId.toString(),
                sender: m.senderUsername,
                content: m.displayContent,
                timestampMs: m.createTime * 1000,
              ),
            )
            .toList();

        final normalized = pipeline.normalizeBusinessMessages(input);
        expect(normalized, isNotEmpty);

        final leads = await pipeline.generateFromChat(
          input,
          chatName,
          confidenceThreshold: 0.6,
        );
        // ignore: avoid_print
        print('extracted leads=${leads.length}');
        for (final lead in leads.take(5)) {
          // ignore: avoid_print
          print('- [${lead.category}] ${lead.title} conf=${lead.confidence}');
        }

        final all = await store.getAll();
        expect(all.length, leads.length);
      },
      skip: enabled ? false : 'Set LEADTRACE_FUNC_TEST=1',
      timeout: const Timeout(Duration(minutes: 8)),
    );

    test(
      'fixture recruitment still extracts',
      () async {
        final tempDir = await Directory.systemTemp.createTemp('lead_fix_');
        addTearDown(() async {
          if (await tempDir.exists()) await tempDir.delete(recursive: true);
        });
        final store = LeadStore(filePathOverride: '${tempDir.path}/leads.json');
        final pipeline = LeadPipelineService(aiClient: ai, store: store);
        final now = DateTime.now().millisecondsSinceEpoch;
        final leads = await pipeline.generateFromChat(
          [
            LeadChatMessage(
              sender: '李老师',
              content:
                  '诚聘质量驻厂顾问，要求汽车零部件质量经验，地点浙江，电话13800000000。',
              timestampMs: now,
            ),
          ],
          '功能测试群',
          confidenceThreshold: 0.6,
        );
        expect(leads, isNotEmpty);
        expect(
          leads.any(
            (l) => l.category == 'recruitment' || l.title.contains('聘'),
          ),
          isTrue,
        );
      },
      skip: enabled ? false : 'Set LEADTRACE_FUNC_TEST=1',
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });
}
