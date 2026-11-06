/// 商机分类：每条商机必须且只能落在固定枚举之一。
///
/// 固定值：recruitment / procurement / resource / expert / other
/// （分类阶段另用 irrelevant 表示无关，不入库。）
class LeadCategory {
  LeadCategory._();

  static const String other = 'other';
  static const String irrelevant = 'irrelevant';

  static const List<String> defaults = [
    'recruitment',
    'procurement',
    'resource',
    'expert',
  ];

  /// 下拉与筛选用的完整固定列表（含「其他」）。
  static const List<String> filterValues = [
    ...defaults,
    other,
  ];

  static const Map<String, String> labels = {
    'recruitment': '招聘',
    'procurement': '求购',
    'resource': '资源',
    'expert': '专家',
    other: '其他',
  };

  /// 中英文别名 → 固定枚举（含历史脏数据）。
  static const Map<String, String> aliases = {
    // recruitment
    'recruitment': 'recruitment',
    '招聘': 'recruitment',
    '招聘信息': 'recruitment',
    '诚聘': 'recruitment',
    '急招': 'recruitment',
    '猎头': 'recruitment',
    '岗位': 'recruitment',
    // procurement
    'procurement': 'procurement',
    '求购': 'procurement',
    '采购': 'procurement',
    '寻购': 'procurement',
    '询价': 'procurement',
    '报价': 'procurement',
    // resource
    'resource': 'resource',
    '资源': 'resource',
    '供应': 'resource',
    'supply': 'resource',
    '寻找资源': 'resource',
    '寻找渠道': 'resource',
    '找渠道': 'resource',
    '寻找合作': 'resource',
    '寻找合作伙伴': 'resource',
    '寻找合作资源': 'resource',
    '寻求合作资源': 'resource',
    '找资源': 'resource',
    '找合作': 'resource',
    '渠道': 'resource',
    // expert
    'expert': 'expert',
    '专家': 'expert',
    '顾问': 'expert',
    '咨询': 'expert',
    '咨询课程': 'expert',
    '寻找顾问': 'expert',
    '寻找专家': 'expert',
    '寻找老师': 'expert',
    '寻找咨询老师或专家': 'expert',
    '寻找顾问、老师、专家': 'expert',
    '找顾问': 'expert',
    '找专家': 'expert',
    '找老师': 'expert',
    // other / noise
    'other': other,
    '其他': other,
    'event': other,
    '政策变化': other,
    '政策影响': other,
    '商机': other,
    '商机 / 资源类重要信息': other,
  };

  /// 清洗并映射到固定枚举；空 / irrelevant → null（交给后续推断）。
  static String? normalize(String? raw) {
    final mapped = mapAlias(raw);
    if (mapped == null) return null;
    if (mapped == irrelevant) return null;
    return mapped;
  }

  /// 将任意原始分类映射为固定枚举（含 other）；无法识别且非空时返回 null。
  static String? mapAlias(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    if (text == irrelevant) return irrelevant;

    // 复合类如 procurement|expert、招聘/求购：按优先级取第一个可识别项
    final parts = text
        .split(RegExp(r'[|/,，、+]+'))
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.length > 1) {
      for (final key in defaults) {
        for (final part in parts) {
          final hit = _mapSingle(part);
          if (hit == key) return key;
        }
      }
      for (final part in parts) {
        final hit = _mapSingle(part);
        if (hit != null && hit != irrelevant) return hit;
      }
    }

    return _mapSingle(text);
  }

  static String? _mapSingle(String text) {
    final direct = aliases[text];
    if (direct != null) return direct;
    final lower = text.toLowerCase();
    final lowerHit = aliases[lower];
    if (lowerHit != null) return lowerHit;

    // 英文枚举直接命中
    if (defaults.contains(lower) || lower == other) return lower;

    // 子串启发（覆盖「寻找xxx」等长尾）
    if (_matchesAny(text, const [
      '诚聘',
      '急招',
      '招聘',
      '猎头',
      '岗位',
      'recruitment',
    ])) {
      return 'recruitment';
    }
    if (_matchesAny(text, const [
      '求购',
      '采购',
      '寻购',
      '询价',
      'procurement',
    ])) {
      return 'procurement';
    }
    if (_matchesAny(text, const [
      '找资源',
      '寻找资源',
      '找渠道',
      '寻找渠道',
      '找合作',
      '寻找合作',
      '寻求合作',
      '供应商',
      '场地',
      '仓储',
      '物流',
      'resource',
      'supply',
      '供应',
    ])) {
      return 'resource';
    }
    if (_matchesAny(text, const [
      '找顾问',
      '找专家',
      '找老师',
      '寻找顾问',
      '寻找专家',
      '寻找老师',
      '咨询老师',
      '咨询专家',
      '咨询服务',
      'expert',
      '顾问',
      '专家',
    ])) {
      return 'expert';
    }
    return null;
  }

  static bool _matchesAny(String text, List<String> needles) {
    final lower = text.toLowerCase();
    for (final n in needles) {
      if (lower.contains(n.toLowerCase())) return true;
    }
    return false;
  }

  static String displayLabel(String? category) {
    final normalized = normalize(category) ?? mapAlias(category);
    if (normalized == null || normalized == irrelevant) return '未分类';
    return labels[normalized] ?? labels[other]!;
  }

  /// 从标题/描述推断唯一分类（按优先级只取一类）。
  static String? inferFromText(String? title, String? description) {
    final blob = '${title ?? ''}\n${description ?? ''}';
    if (RegExp(r'(招聘|诚聘|急招|猎头|岗位|任职要求|JD|薪资|简历)', caseSensitive: false)
        .hasMatch(blob)) {
      return 'recruitment';
    }
    if (RegExp(r'(求购|采购|寻购|找供应商|询价|报价|预算)', caseSensitive: false)
        .hasMatch(blob)) {
      return 'procurement';
    }
    if (RegExp(
      r'(找资源|寻找资源|找渠道|寻找渠道|找合作|寻找合作|寻求合作|找服务商|找仓储|找物流|找场地)',
      caseSensitive: false,
    ).hasMatch(blob)) {
      return 'resource';
    }
    if (RegExp(
      r'(找老师|找专家|找顾问|需要顾问|咨询老师|咨询专家|咨询服务)',
      caseSensitive: false,
    ).hasMatch(blob)) {
      return 'expert';
    }
    return null;
  }

  /// 为候选商机确定唯一固定分类。
  static String resolve({
    String? itemCategory,
    String? segmentLabel,
    String? title,
    String? description,
  }) {
    return normalize(itemCategory) ??
        normalize(segmentLabel) ??
        inferFromText(title, description) ??
        other;
  }

  /// 合并重复候选时保留一个分类，不叠多个类。
  static String preferWhenMerging({
    String? existing,
    String? incoming,
    required double existingConfidence,
    required double incomingConfidence,
    String? segmentLabel,
  }) {
    final left = normalize(existing);
    final right = normalize(incoming);
    final segment = normalize(segmentLabel);

    if (left != null && right != null) {
      if (segment != null) {
        if (left == segment && right != segment) return left;
        if (right == segment && left != segment) return right;
      }
      return incomingConfidence > existingConfidence ? right : left;
    }
    return left ?? right ?? segment ?? other;
  }

  static bool isCanonical(String? category) {
    final n = normalize(category);
    return n != null && filterValues.contains(n);
  }
}
