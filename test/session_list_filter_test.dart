import 'package:flutter_test/flutter_test.dart';

import 'package:leadtrace/models/chat_session.dart';

void main() {
  group('session list filtering helpers', () {
    ChatSession session(String username) {
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
      );
    }

    test('groupsOnly keeps chatroom usernames', () {
      final all = [
        session('wxid_friend'),
        session('123456@chatroom'),
        session('gh_official'),
      ];
      final groups = all.where((s) => s.isGroup).toList();
      expect(groups.map((s) => s.username), ['123456@chatroom']);
    });

    test('ChatSession.shouldKeep drops official accounts', () {
      expect(ChatSession.shouldKeep('gh_official'), isFalse);
      expect(ChatSession.shouldKeep('123456@chatroom'), isTrue);
    });
  });
}
