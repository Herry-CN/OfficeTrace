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
}
