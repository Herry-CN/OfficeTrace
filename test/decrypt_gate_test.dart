import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:leadtrace/providers/app_state.dart';
import 'package:leadtrace/widgets/decrypt_required_gate.dart';

void main() {
  testWidgets('DecryptRequiredGate shows guidance and navigates', (
    WidgetTester tester,
  ) async {
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: appState,
        child: const MaterialApp(
          home: Scaffold(body: DecryptRequiredGate()),
        ),
      ),
    );

    expect(find.text('需要先完成解密'), findsOneWidget);
    expect(find.text('前往数据管理'), findsOneWidget);
    expect(find.text('打开设置'), findsOneWidget);

    await tester.tap(find.text('前往数据管理'));
    await tester.pump();
    expect(appState.currentPage, 'data_management');

    await tester.tap(find.text('打开设置'));
    await tester.pump();
    expect(appState.currentPage, 'settings');
  });

  testWidgets('DecryptRequiredGate accepts custom copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(
          home: Scaffold(
            body: DecryptRequiredGate(
              title: '需要先连接数据库',
              message: '群监控需要读取本地微信消息。',
            ),
          ),
        ),
      ),
    );

    expect(find.text('需要先连接数据库'), findsOneWidget);
    expect(find.textContaining('群监控'), findsOneWidget);
  });
}
