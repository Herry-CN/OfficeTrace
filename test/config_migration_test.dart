import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leadtrace/services/config_migration.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ConfigMigration', () {
    late Directory tempDir;
    late File legacyFile;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = await Directory.systemTemp.createTemp('cfg_mig_');
      legacyFile = File('${tempDir.path}/shared_preferences.json');
      await legacyFile.writeAsString(
        jsonEncode({
          'flutter.database_path': r'C:\Users\hearl\xwechat_files',
          'flutter.manual_wxid': 'LyraHerry_2079',
          'flutter.is_configured': true,
          'flutter.decrypt_key': 'abc123',
          'flutter.privacy_accepted': true,
        }),
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('imports missing keys from echotrace prefs', () async {
      SharedPreferences.setMockInitialValues({
        'privacy_accepted': true,
      });
      final prefs = await SharedPreferences.getInstance();

      final written = await ConfigMigration.migrateFromEchoTraceIfNeeded(
        prefs: prefs,
        legacyFileOverrides: [legacyFile.path],
      );

      expect(written, greaterThan(0));
      expect(prefs.getString('database_path'), r'C:\Users\hearl\xwechat_files');
      expect(prefs.getString('manual_wxid'), 'LyraHerry_2079');
      expect(prefs.getBool('is_configured'), isTrue);
      expect(prefs.getString('decrypt_key'), 'abc123');
      // 已有值不覆盖
      expect(prefs.getBool('privacy_accepted'), isTrue);
    });

    test('skips when database_path already present', () async {
      SharedPreferences.setMockInitialValues({
        'database_path': r'D:\already\set',
      });
      final prefs = await SharedPreferences.getInstance();

      final written = await ConfigMigration.migrateFromEchoTraceIfNeeded(
        prefs: prefs,
        legacyFileOverrides: [legacyFile.path],
      );

      expect(written, 0);
      expect(prefs.getString('database_path'), r'D:\already\set');
    });
  });
}
