import 'package:flutter_test/flutter_test.dart';
import 'package:leadtrace/services/lead/monitor_poll_delta.dart';

void main() {
  group('computeMonitorPollDelta', () {
    test('first sighting only establishes baseline', () {
      final result = computeMonitorPollDelta(
        lastSeenCreateTime: null,
        messageCreateTimes: [100, 200, 300],
      );
      expect(result.baselineOnly, isTrue);
      expect(result.freshCreateTimes, isEmpty);
      expect(result.newestCreateTime, 300);
    });

    test('subsequent poll returns only newer messages', () {
      final result = computeMonitorPollDelta(
        lastSeenCreateTime: 200,
        messageCreateTimes: [100, 200, 250, 300],
      );
      expect(result.baselineOnly, isFalse);
      expect(result.freshCreateTimes, [250, 300]);
      expect(result.newestCreateTime, 300);
    });

    test('no newer messages yields empty fresh list', () {
      final result = computeMonitorPollDelta(
        lastSeenCreateTime: 300,
        messageCreateTimes: [100, 200, 300],
      );
      expect(result.baselineOnly, isFalse);
      expect(result.freshCreateTimes, isEmpty);
    });

    test('empty messages are a no-op', () {
      final result = computeMonitorPollDelta(
        lastSeenCreateTime: null,
        messageCreateTimes: const [],
      );
      expect(result.newestCreateTime, isNull);
      expect(result.freshCreateTimes, isEmpty);
    });
  });
}
