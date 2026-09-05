import 'package:flutter_test/flutter_test.dart';

import 'package:leadtrace/main.dart';

void main() {
  testWidgets('LeadTrace app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LeadTraceApp());
    expect(find.text('LeadTrace'), findsWidgets);
  });
}
