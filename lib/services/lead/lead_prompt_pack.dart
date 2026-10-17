import 'dart:convert';

import '../config_service.dart';

/// 商机抓取用的分类说明与提示词。设置页和群监控共用这一份。
class LeadPromptPack {
  const LeadPromptPack({
    required this.categories,
    required this.classificationPrompt,
    required this.extractionPrompt,
  });

  static const int exportVersion = 1;

  static const String defaultCategories = '''- 招聘信息（岗位、要求、联系方式等）
- 求购信息（需求物品或服务、预算、时间要求等）
- 寻找资源（寻找合作伙伴、渠道、供应商、场地等）
- 寻找咨询老师或专家（咨询方向、领域、联系方式等）''';

  static const String defaultClassificationPrompt = '''可选标签只有：
- recruitment
- procurement
- resource
- expert
- irrelevant

判定原则：
- 招聘、诚聘、急招、猎头岗位 -> recruitment
- 求购、采购、寻供应商、明确预算/采购需求 -> procurement
- 找渠道、找合作方、找资源、找场地、找服务商 -> resource
- 找顾问、找老师、找专家、找咨询服务 -> expert
- 普通聊天、寒暄、会议安排、无明确需求 -> irrelevant

精度优先（减少错抓）：
- 仅提到「老师/顾问/资源/合作」但无明确需求或求助意图 -> irrelevant
- 单纯分享文章、表情、图片说明、无实质岗位/采购内容 -> irrelevant
- 必须有较明确的岗位、采购标的、资源诉求、咨询诉求之一，才判为商机类

召回保底（减少漏抓）：
- 出现「诚聘/急招/求购/找供应商/找渠道/找顾问」等明确动词短语时，不要判 irrelevant
- 同时带联系方式或预算/薪资时，优先判为对应商机类''';

  static const String defaultExtractionPrompt = '''以下情况只要出现，就应优先提取：
- 明确招聘、诚聘、急招、猎头岗位、招聘顾问、招聘专家
- 明确求购、采购、寻找供应商、寻找渠道、寻找合作资源
- 明确寻找顾问、老师、专家、咨询服务

以下内容通常不要提取：
- 普通寒暄、确认收到、表情回复
- 一般性见面安排、接送沟通、时间确认
- 没有明确需求、资源、岗位、联系方式、预算、合作意向的信息
- 仅口头提到「老师/顾问/资源」但无求助或供需意图
- 重复复述同一岗位/需求（同一发送者同一时间点只保留一条）

提取要求：
- title 尽量保留原文关键句，避免过度改写（便于去重）
- sender / messageTime 必须与原文行一致
- confidence：证据充分 ≥0.85；略含糊 0.6–0.8；拿不准则不要输出该条''';

  static const LeadPromptPack defaults = LeadPromptPack(
    categories: defaultCategories,
    classificationPrompt: defaultClassificationPrompt,
    extractionPrompt: defaultExtractionPrompt,
  );

  final String categories;
  final String classificationPrompt;
  final String extractionPrompt;

  /// 空白字段回落到内置默认，避免保存后提示词变空。
  LeadPromptPack normalized() {
    return LeadPromptPack(
      categories: _orDefault(categories, defaultCategories),
      classificationPrompt:
          _orDefault(classificationPrompt, defaultClassificationPrompt),
      extractionPrompt: _orDefault(extractionPrompt, defaultExtractionPrompt),
    );
  }

  static String _orDefault(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  static Future<LeadPromptPack> load(ConfigService config) async {
    return LeadPromptPack(
      categories: await config.getLeadPromptCategories(),
      classificationPrompt: await config.getLeadClassificationPrompt(),
      extractionPrompt: await config.getLeadExtractionPrompt(),
    ).normalized();
  }

  Future<void> persist(ConfigService config) async {
    final pack = normalized();
    await config.saveLeadPromptCategories(pack.categories);
    await config.saveLeadClassificationPrompt(pack.classificationPrompt);
    await config.saveLeadExtractionPrompt(pack.extractionPrompt);
  }

  String encodeExport() {
    return const JsonEncoder.withIndent('  ').convert({
      'version': exportVersion,
      'categories': categories,
      'classificationPrompt': classificationPrompt,
      'extractionPrompt': extractionPrompt,
    });
  }

  /// 解析导入 JSON。缺少任一项文本时抛出 [FormatException]。
  static LeadPromptPack parseImport(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('导入文件格式无效：根节点应为对象');
    }
    return LeadPromptPack(
      categories: _requireText(decoded, 'categories'),
      classificationPrompt: _requireText(decoded, 'classificationPrompt'),
      extractionPrompt: _requireText(decoded, 'extractionPrompt'),
    );
  }

  static String _requireText(Map<dynamic, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) {
      throw FormatException('导入文件格式无效：缺少 $key 文本');
    }
    return value;
  }

  /// 从分类提示词里识别英文标签。只有 irrelevant 时表示提示词未声明标签。
  static Set<String> declaredLabels(String prompt) {
    final labels = <String>{'irrelevant'};
    final arrow = RegExp(r'->\s*([A-Za-z][\w-]{0,63})');
    final bullet = RegExp(r'^\s*-\s*([A-Za-z][\w-]{0,63})\s*$', multiLine: true);
    for (final match in arrow.allMatches(prompt)) {
      labels.add(match.group(1)!);
    }
    for (final match in bullet.allMatches(prompt)) {
      labels.add(match.group(1)!);
    }
    return labels;
  }

  /// 提示词声明了标签时，只接受这些标签；否则保留模型返回的自定义类别。
  static String normalizeClassificationLabel(String? raw, String prompt) {
    final label = (raw ?? '').trim();
    if (label.isEmpty) return 'irrelevant';
    final clipped = label.length > 64 ? label.substring(0, 64) : label;
    final allowed = declaredLabels(prompt);
    if (allowed.length <= 1) return clipped;
    return allowed.contains(clipped) ? clipped : 'irrelevant';
  }

  @override
  bool operator ==(Object other) {
    return other is LeadPromptPack &&
        other.categories == categories &&
        other.classificationPrompt == classificationPrompt &&
        other.extractionPrompt == extractionPrompt;
  }

  @override
  int get hashCode => Object.hash(
        categories,
        classificationPrompt,
        extractionPrompt,
      );
}
