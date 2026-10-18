/// 商机分类：每条商机必须且只能有一个有效分类。
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

  static const Map<String, String> labels = {
    'recruitment': '招聘',
    'procurement': '求购',
    'resource': '资源',
    'expert': '专家',
    other: '其他',
  };

  /// 清洗分类值；空或 irrelevant 视为未归类。
  static String? normalize(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty || text == irrelevant) return null;
    return text.length > 64 ? text.substring(0, 64) : text;
  }

  static String displayLabel(String? category) {
    final normalized = normalize(category);
    if (normalized == null) return '未分类';
    return labels[normalized] ?? normalized;
  }

  /// 从标题/描述推断唯一分类（按优先级只取一类，避免重复归类）。
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
      r'(找资源|寻找资源|找渠道|寻找渠道|找合作|寻找合作|找服务商|找仓储|找物流|找场地)',
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

  /// 为候选商机确定唯一分类：条目自身 > 片段标签 > 文本推断 > other。
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
}
