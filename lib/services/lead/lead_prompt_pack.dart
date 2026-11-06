import 'dart:convert';

import '../config_service.dart';
import 'lead_category.dart';

/// 商机抓取用的分类说明与提示词。设置页和群监控共用这一份。
class LeadPromptPack {
  const LeadPromptPack({
    required this.categories,
    required this.classificationPrompt,
    required this.extractionPrompt,
  });

  static const int exportVersion = 1;

  /// 分类说明：强制英文枚举，禁止模型自造中文类名。
  static const String defaultCategories = '''category 字段必须且只能取下列英文值之一（禁止中文类名、禁止用 | / 、拼接多个类）：
- recruitment：招聘、诚聘、急招、猎头岗位、任职要求
- procurement：求购、采购、寻购、询价、明确预算的采购需求
- resource：找资源、找渠道、找合作伙伴、找场地、找服务商、供应对接
- expert：找顾问、找老师、找专家、咨询服务
- other：能提取为商机但不属于以上四类时使用''';

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
- 同时带联系方式或预算/薪资时，优先判为对应商机类

硬性约束：
- label 只能是上述 5 个英文词之一，禁止输出中文，禁止拼接多个标签''';

  static const String defaultExtractionPrompt = '''以下情况只要出现，就应优先提取：
- 明确招聘、诚聘、急招、猎头岗位
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
- category 只能是 recruitment / procurement / resource / expert / other 之一
- 禁止把分类写成中文（如「招聘」「寻找资源」），禁止写成复合值（如 procurement|expert）
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

  /// 提示词方案版本：升级时一次性覆盖旧自由类名方案。
  static const int schemeVersion = 2;

  static Future<LeadPromptPack> load(ConfigService config) async {
    final version = await config.getLeadPromptSchemeVersion();
    if (version < schemeVersion) {
      await defaults.persist(config);
      return defaults;
    }
    return LeadPromptPack(
      categories: await config.getLeadPromptCategories(),
      classificationPrompt: await config.getLeadClassificationPrompt(),
      extractionPrompt: await config.getLeadExtractionPrompt(),
    ).normalized();
  }

  /// 是否仍缺少英文枚举硬约束（用于识别旧文案；迁移靠 [schemeVersion]）。
  static bool needsSchemeUpgrade(LeadPromptPack pack) {
    final categories = pack.categories;
    final classification = pack.classificationPrompt;
    final extraction = pack.extractionPrompt;
    final hasCategoryConstraint = categories.contains('禁止中文类名');
    final hasClassifyConstraint = classification.contains('禁止输出中文') ||
        classification.contains('label 只能是上述');
    final hasExtractConstraint = extraction.contains('禁止把分类写成中文');
    return !hasCategoryConstraint ||
        !hasClassifyConstraint ||
        !hasExtractConstraint;
  }

  Future<void> persist(ConfigService config) async {
    final pack = normalized();
    await config.saveLeadPromptCategories(pack.categories);
    await config.saveLeadClassificationPrompt(pack.classificationPrompt);
    await config.saveLeadExtractionPrompt(pack.extractionPrompt);
    await config.saveLeadPromptSchemeVersion(schemeVersion);
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
    final bullet =
        RegExp(r'^\s*-\s*([A-Za-z][\w-]{0,63})\s*$', multiLine: true);
    for (final match in arrow.allMatches(prompt)) {
      labels.add(match.group(1)!);
    }
    for (final match in bullet.allMatches(prompt)) {
      labels.add(match.group(1)!);
    }
    // 始终允许固定业务枚举，避免用户改提示词后丢标签
    labels.addAll(LeadCategory.defaults);
    return labels;
  }

  /// 提示词声明了标签时，只接受这些标签；否则映射到固定枚举。
  static String normalizeClassificationLabel(String? raw, String prompt) {
    final mapped = LeadCategory.mapAlias(raw);
    if (mapped == LeadCategory.irrelevant) return 'irrelevant';
    if (mapped != null && LeadCategory.defaults.contains(mapped)) {
      return mapped;
    }
    final label = (raw ?? '').trim();
    if (label.isEmpty) return 'irrelevant';
    final allowed = declaredLabels(prompt);
    if (allowed.contains(label)) return label;
    return 'irrelevant';
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
