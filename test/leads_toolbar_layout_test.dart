import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:leadtrace/pages/leads_page.dart';
import 'package:leadtrace/providers/app_state.dart';

void main() {
  testWidgets('LeadsPage shows decrypt gate when disconnected', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(home: Scaffold(body: LeadsPage())),
      ),
    );
    await tester.pump();
    expect(find.textContaining('需要先'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
