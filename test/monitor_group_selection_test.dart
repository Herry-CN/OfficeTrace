import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leadtrace/models/chat_session.dart';
import 'package:leadtrace/services/config_service.dart';
import 'package:leadtrace/services/lead/monitor_group_selection.dart';

ChatSession _session(String username, {String? displayName}) {
  return ChatSession(
    username: username,
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
  )..displayName = displayName;
}

void main() {
  group('MonitorGroupSelection', () {
    final groups = [
      _session('111@chatroom', displayName: '愿石数字化'),
      _session('222@chatroom', displayName: '测试群'),
      _session('333@chatroom', displayName: '商务合作'),
    ];

    test('filterGroups matches name and username', () {
      expect(
        MonitorGroupSelection.filterGroups(groups, '愿石').map((g) => g.username),
        ['111@chatroom'],
      );
      expect(
        MonitorGroupSelection.filterGroups(groups, '222').map((g) => g.username),
        ['222@chatroom'],
      );
      expect(MonitorGroupSelection.filterGroups(groups, '').length, 3);
    });

    test('selectAllVisible only adds filtered items', () {
      final visible = MonitorGroupSelection.filterGroups(groups, '测试');
      final selected = MonitorGroupSelection.selectAllVisible(
        {'111@chatroom'},
        visible,
      );
      expect(selected, {'111@chatroom', '222@chatroom'});
    });

    test('clearAll empties selection', () {
      expect(MonitorGroupSelection.clearAll(), isEmpty);
    });

    test('encodeExport and parseImport roundtrip', () {
      final json = MonitorGroupSelection.encodeExport([
        '111@chatroom',
        '222@chatroom',
      ]);
      expect(json, contains('"version": 1'));
      final parsed = MonitorGroupSelection.parseImport(json);
      expect(parsed, ['111@chatroom', '222@chatroom']);
    });

    test('parseImport rejects invalid payload', () {
      expect(
        () => MonitorGroupSelection.parseImport('[]'),
        throwsFormatException,
      );
      expect(
        () => MonitorGroupSelection.parseImport('{"version":1}'),
        throwsFormatException,
      );
    });

    test('applyImport replaces and reports missing', () {
      final applied = MonitorGroupSelection.applyImport(
        imported: ['111@chatroom', 'missing@chatroom'],
        knownUsernames: {'111@chatroom', '222@chatroom'},
      );
      expect(applied.selected, {'111@chatroom', 'missing@chatroom'});
      expect(applied.missing, ['missing@chatroom']);
    });
  });

  group('ConfigService monitor selected groups', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('save and load selected groups', () async {
      final config = ConfigService();
      await config.saveMonitorSelectedGroups([
        'a@chatroom',
        'b@chatroom',
      ]);
      final loaded = await config.getMonitorSelectedGroups();
      expect(loaded, ['a@chatroom', 'b@chatroom']);
    });
  });
}
