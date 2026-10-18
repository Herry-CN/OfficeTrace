/// 商务商机 / 待办模型
class Lead {
  final String id;
  final String title;
  final String description;
  final String priority; // high | medium | low
  final String? dueDate;
  final bool completed;
  final String source; // manual | ai-generated
  final String? sourceMessage;
  final String? groupName;
  final String? sender;
  final String? messageTime;
  final String? category; // recruitment | procurement | resource | expert
  final double? confidence;
  /// 稳定去重指纹（可选，旧数据可为空）。
  final String? fingerprint;
  /// 源消息 localId（可选）。
  final String? messageId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Lead({
    required this.id,
    required this.title,
    this.description = '',
    this.priority = 'medium',
    this.dueDate,
    this.completed = false,
    this.source = 'manual',
    this.sourceMessage,
    this.groupName,
    this.sender,
    this.messageTime,
    this.category,
    this.confidence,
    this.fingerprint,
    this.messageId,
    required this.createdAt,
    required this.updatedAt,
  });

  Lead copyWith({
    String? id,
    String? title,
    String? description,
    String? priority,
    String? dueDate,
    bool? completed,
    String? source,
    String? sourceMessage,
    String? groupName,
    String? sender,
    String? messageTime,
    String? category,
    double? confidence,
    String? fingerprint,
    String? messageId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Lead(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      completed: completed ?? this.completed,
      source: source ?? this.source,
      sourceMessage: sourceMessage ?? this.sourceMessage,
      groupName: groupName ?? this.groupName,
      sender: sender ?? this.sender,
      messageTime: messageTime ?? this.messageTime,
      category: category ?? this.category,
      confidence: confidence ?? this.confidence,
      fingerprint: fingerprint ?? this.fingerprint,
      messageId: messageId ?? this.messageId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'priority': priority,
        'dueDate': dueDate,
        'completed': completed,
        'source': source,
        'sourceMessage': sourceMessage,
        'groupName': groupName,
        'sender': sender,
        'messageTime': messageTime,
        'category': category,
        'confidence': confidence,
        'fingerprint': fingerprint,
        'messageId': messageId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Lead.fromJson(Map<String, dynamic> json) {
    DateTime parseTime(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      return DateTime.now();
    }

    double? parseConfidence(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    return Lead(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'medium',
      dueDate: json['dueDate']?.toString(),
      completed: json['completed'] == true,
      source: json['source']?.toString() ?? 'manual',
      sourceMessage: json['sourceMessage']?.toString(),
      groupName: json['groupName']?.toString(),
      sender: json['sender']?.toString(),
      messageTime: json['messageTime']?.toString(),
      category: json['category']?.toString(),
      confidence: parseConfidence(json['confidence']),
      fingerprint: json['fingerprint']?.toString(),
      messageId: json['messageId']?.toString(),
      createdAt: parseTime(json['createdAt']),
      updatedAt: parseTime(json['updatedAt']),
    );
  }

  static String categoryLabel(String? category) {
    // 具体规则见 LeadCategory.displayLabel；此处保留薄封装避免循环依赖。
    if (category == null || category.trim().isEmpty || category == 'irrelevant') {
      return '未分类';
    }
    switch (category) {
      case 'recruitment':
        return '招聘';
      case 'procurement':
        return '求购';
      case 'resource':
        return '资源';
      case 'expert':
        return '专家';
      case 'other':
        return '其他';
      default:
        return category;
    }
  }
}

/// Pipeline 输入用的轻量消息
class LeadChatMessage {
  final String? id;
  final String? sender;
  final String content;
  final int timestampMs;

  const LeadChatMessage({
    this.id,
    this.sender,
    required this.content,
    required this.timestampMs,
  });
}

/// AI 分类结果
class BusinessClassification {
  final String label;
  final double confidence;
  final bool shouldExtract;
  final String summary;

  const BusinessClassification({
    required this.label,
    required this.confidence,
    required this.shouldExtract,
    this.summary = '',
  });
}

/// AI 提取结果
class LeadExtractionResult {
  final String summary;
  final List<Map<String, dynamic>> items;

  const LeadExtractionResult({
    this.summary = '',
    this.items = const [],
  });
}
