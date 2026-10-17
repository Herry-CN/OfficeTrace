import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:leadtrace/services/database_service.dart';
import 'package:leadtrace/services/lead/ai_client_service.dart';
import 'package:leadtrace/services/lead/group_monitor_controller.dart';
import 'package:leadtrace/services/lead/lead_prompt_pack.dart';
import 'package:leadtrace/widgets/lead_prompt_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('empty prompt fields fall back to defaults', () {
    final pack = const LeadPromptPack(
      categories: '  ',
      classificationPrompt: '',
      extractionPrompt: '',
    ).normalized();
    expect(pack.categories, LeadPromptPack.defaultCategories);
    expect(
      pack.classificationPrompt,
      LeadPromptPack.defaultClassificationPrompt,
    );
    expect(pack.extractionPrompt, LeadPromptPack.defaultExtractionPrompt);
  });

  test('prompt export round-trips and rejects invalid files', () {
    const pack = LeadPromptPack(
      categories: '- 合伙',
      classificationPrompt: '- partnership',
      extractionPrompt: '只提取合伙信息',
    );
    final imported = LeadPromptPack.parseImport(pack.encodeExport());
    expect(imported, pack);

    expect(
      () => LeadPromptPack.parseImport('{"categories": 1}'),
      throwsFormatException,
    );
    expect(() => LeadPromptPack.parseImport('[]'), throwsFormatException);
  });

  test('declared labels accept custom tags and keep unknown ones out', () {
    const prompt = '''
- recruitment
- partnership
- irrelevant
- 找合伙 -> partnership
''';
    expect(
      LeadPromptPack.normalizeClassificationLabel('partnership', prompt),
      'partnership',
    );
    expect(
      LeadPromptPack.normalizeClassificationLabel('unknown', prompt),
      'irrelevant',
    );
    expect(
      LeadPromptPack.normalizeClassificationLabel('自定义', '只写中文规则'),
      '自定义',
    );
  });

  test('classification prompt includes the configured rules', () {
    final ai = AiClientService();
    ai.classificationPrompt = '- partnership\n找合伙 -> partnership';
    ai.todoPromptCategories = '- 合伙信息';
    ai.extractionPrompt = '只提取合伙';
    final classify = ai.buildClassificationPrompt('诚聘顾问');
    final extract = ai.buildExtractionPrompt('诚聘顾问', segmentLabel: 'partnership');
    expect(classify, contains('partnership'));
    expect(classify, contains('诚聘顾问'));
    expect(extract, contains('- 合伙信息'));
    expect(extract, contains('只提取合伙'));
    expect(extract, contains('partnership'));
  });

  test('saved prompts are shared by a new controller', () async {
    final first = GroupMonitorController(databaseService: DatabaseService());
    final saved = await first.saveLeadPrompts(
      const LeadPromptPack(
        categories: '- 合伙',
        classificationPrompt: '- partnership',
        extractionPrompt: '只提取合伙信息',
      ),
    );
    expect(saved.categories, '- 合伙');
    expect(first.leadPrompts.classificationPrompt, '- partnership');

    final second = GroupMonitorController(databaseService: DatabaseService());
    await second.reloadLeadPrompts();
    expect(second.leadPrompts, saved);
    expect(second.leadPrompts.extractionPrompt, '只提取合伙信息');
  });

  testWidgets('editor save sends the edited category text', (tester) async {
    LeadPromptPack? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LeadPromptEditor(
              pack: LeadPromptPack.defaults,
              onSave: (pack) async {
                saved = pack;
              },
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const ValueKey('lead-prompt-categories')),
      '- 合伙信息',
    );
    await tester.ensureVisible(find.text('保存提示词'));
    await tester.tap(find.text('保存提示词'));
    await tester.pump();

    expect(saved, isNotNull);
    expect(saved!.categories, '- 合伙信息');
    expect(saved!.classificationPrompt, LeadPromptPack.defaultClassificationPrompt);
    expect(find.text('提示词已保存'), findsOneWidget);
  });
}
