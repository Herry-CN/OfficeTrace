import 'package:flutter_test/flutter_test.dart';

import 'package:leadtrace/services/lead/auto_sync_pipeline_logic.dart';

void main() {
  group('decideCaptureAfterDecrypt', () {
    test('no db changes → skip capture and cool down', () {
      expect(
        decideCaptureAfterDecrypt(
          hadDbChanges: false,
          hasSelectedGroups: true,
        ),
        CaptureDecision.skipNoDbChange,
      );
    });

    test('db changes + selected groups → capture selected only', () {
      expect(
        decideCaptureAfterDecrypt(
          hadDbChanges: true,
          hasSelectedGroups: true,
        ),
        CaptureDecision.captureSelected,
      );
    });

    test('db changes but empty selection → skip capture', () {
      expect(
        decideCaptureAfterDecrypt(
          hadDbChanges: true,
          hasSelectedGroups: false,
        ),
        CaptureDecision.skipNoSelection,
      );
    });
  });

  test('syncPhaseLabel covers all phases', () {
    for (final phase in SyncPhase.values) {
      expect(syncPhaseLabel(phase), isNotEmpty);
    }
  });

  group('shouldSkipUnchangedGroupCapture', () {
    test('first capture never skips when messages exist', () {
      expect(
        shouldSkipUnchangedGroupCapture(
          lastCapturedMaxCreateTime: null,
          currentMaxCreateTime: 100,
        ),
        isFalse,
      );
    });

    test('no messages → skip', () {
      expect(
        shouldSkipUnchangedGroupCapture(
          lastCapturedMaxCreateTime: 50,
          currentMaxCreateTime: null,
        ),
        isTrue,
      );
    });

    test('unchanged or older → skip', () {
      expect(
        shouldSkipUnchangedGroupCapture(
          lastCapturedMaxCreateTime: 100,
          currentMaxCreateTime: 100,
        ),
        isTrue,
      );
      expect(
        shouldSkipUnchangedGroupCapture(
          lastCapturedMaxCreateTime: 100,
          currentMaxCreateTime: 99,
        ),
        isTrue,
      );
    });

    test('newer messages → capture', () {
      expect(
        shouldSkipUnchangedGroupCapture(
          lastCapturedMaxCreateTime: 100,
          currentMaxCreateTime: 101,
        ),
        isFalse,
      );
    });
  });

  group('shouldSkipBySessionTimestamp', () {
    test('session not advanced → skip', () {
      expect(
        shouldSkipBySessionTimestamp(
          lastCapturedMaxCreateTime: 200,
          sessionLastTimestamp: 200,
        ),
        isTrue,
      );
    });

    test('session advanced → do not skip', () {
      expect(
        shouldSkipBySessionTimestamp(
          lastCapturedMaxCreateTime: 200,
          sessionLastTimestamp: 201,
        ),
        isFalse,
      );
    });
  });
}
