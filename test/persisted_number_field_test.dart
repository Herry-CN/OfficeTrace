import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leadtrace/services/config_service.dart';
import 'package:leadtrace/services/database_service.dart';
import 'package:leadtrace/services/lead/group_monitor_controller.dart';
import 'package:leadtrace/widgets/persisted_number_field.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('commits a typed number without pressing enter', (tester) async {
    var saved = 24;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return PersistedNumberField(
                value: saved,
                min: 1,
                max: 168,
                onCommit: (v) => setState(() => saved = v),
              );
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextFormField), '7');
    await tester.pump();
    expect(saved, 7);
    expect(find.text('7'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), '72');
    await tester.pump();
    expect(saved, 72);
    expect(find.text('72'), findsOneWidget);
  });

  testWidgets('shows the saved value after a reload', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PersistedNumberField(
            value: 72,
            onCommit: _noop,
          ),
        ),
      ),
    );
    expect(find.text('72'), findsOneWidget);
  });

  test('analysis hours survive a new controller', () async {
    SharedPreferences.setMockInitialValues({});
    final first = GroupMonitorController(databaseService: DatabaseService());
    await first.setAnalysisHours(72);

    final second = GroupMonitorController(databaseService: DatabaseService());
    await second.ensureBootstrapped();
    expect(second.analysisHours, 72);
    expect(await ConfigService().getAiAnalysisHours(), 72);
  });
}

void _noop(int _) {}
