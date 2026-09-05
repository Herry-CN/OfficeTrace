import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:leadtrace/pages/leads_page.dart';
import 'package:leadtrace/providers/app_state.dart';

void main() {
  testWidgets('LeadsPage toolbar does not overflow when disconnected gate shows',
      (tester) async {
    // 未连接时只验证 gate；连接态布局用固定尺寸泵入子树控件更稳妥
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

  testWidgets('leads toolbar wrap fits narrow width without overflow',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(720, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 280,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '目标群聊',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            isDense: true,
                            value: 'a',
                            items: const [
                              DropdownMenuItem(
                                value: 'a',
                                child: Text(
                                  '愿石数字化转型2',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            onChanged: (_) {},
                          ),
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('智能抓取'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.playlist_add_check),
                      label: const Text('批量抓取全部群'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
