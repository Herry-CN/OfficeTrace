import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:leadtrace/pages/leads_page.dart';
import 'package:leadtrace/providers/app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LeadsPage shows inbox without decrypt gate', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppState(),
        child: const MaterialApp(home: Scaffold(body: LeadsPage())),
      ),
    );
    // 首帧 bootstrap
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('商机中心'), findsOneWidget);
    expect(find.textContaining('需要先完成解密'), findsNothing);
    expect(find.textContaining('前往数据管理'), findsNothing);

    // 取消页面上的周期性 Timer，避免测试结束时泄漏
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
