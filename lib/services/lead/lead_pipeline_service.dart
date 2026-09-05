import '../../models/lead.dart';
import 'ai_client_service.dart';
import 'lead_store.dart';

/// 群聊商机抓取流水线：分段 → 分类 → 提取 → 阈值 → 去重 → 落库
class LeadPipelineService {
  LeadPipelineService({
    required this.aiClient,
    required this.store,
  });

  final AiClientService aiClient;
  final LeadStore store;

  static const int maxCharsPerSegment = 2200;
  static const int maxMessagesPerSegment = 25;
  static const int maxTimeGapMs = 45 * 60 * 1000;

  Future<List<Lead>> generateFromChat(
    List<LeadChatMessage> messages,
    String chatName, {
    double? confidenceThreshold,
  }) async {
    if (messages.isEmpty) return [];

    final normalized = normalizeBusinessMessages(messages);
    if (normalized.isEmpty) return [];

    final segments = buildBusinessSegments(normalized);
    final extracted = <Map<String, dynamic>>[];
    Object? firstBatchError;
    var previousSummary = '';

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final ruleTodos = fallbackExtractImportantMessages(segment.messages)
          .map((todo) => {
                ...todo,
                'sourceMessage': segment.chatContent,
                'segmentIndex': i,
                'segmentSummary': segment.segmentSummary,
              })
          .toList();

      var classification = BusinessClassification(
        label: segment.primaryLabel ?? 'irrelevant',
        confidence: segment.ruleScore,
        shouldExtract: segment.ruleScore >= 0.45,
        summary: segment.segmentSummary,
      );

      try {
        final aiClassification = await aiClient.classifyBusinessSegment(
          segment.chatContent,
          previousSummary: previousSummary,
        );
        classification = BusinessClassification(
          label: aiClassification.label.isNotEmpty
              ? aiClassification.label
              : classification.label,
          confidence: aiClassification.confidence > classification.confidence
              ? aiClassification.confidence
              : classification.confidence,
          shouldExtract: aiClassification.shouldExtract ||
              classification.shouldExtract ||
              ruleTodos.isNotEmpty,
          summary: aiClassification.summary.isNotEmpty
              ? aiClassification.summary
              : classification.summary,
        );
      } catch (e) {
        firstBatchError ??= e;
      }

      final shouldExtract = ruleTodos.isNotEmpty ||
          (classification.label != 'irrelevant' &&
              classification.confidence >= 0.45);

      var aiItems = <Map<String, dynamic>>[];
      if (shouldExtract) {
        try {
          final result = await aiClient.extractBusinessLeads(
            segment.chatContent,
            previousSummary: previousSummary,
            segmentLabel: classification.label,
          );
          aiItems = result.items
              .map((todo) => {
                    ...todo,
                    'sourceMessage': segment.chatContent,
                    'segmentIndex': i,
                    'segmentSummary':
                        result.summary.isNotEmpty ? result.summary : classification.summary,
                  })
              .toList();
          if (result.summary.isNotEmpty) {
            previousSummary =
                mergeRollingSummary(previousSummary, result.summary);
          } else if (classification.summary.isNotEmpty) {
            previousSummary =
                mergeRollingSummary(previousSummary, classification.summary);
          }
        } catch (e) {
          firstBatchError ??= e;
        }
      }

      if (aiItems.isEmpty && classification.summary.isNotEmpty) {
        previousSummary =
            mergeRollingSummary(previousSummary, classification.summary);
      }

      final merged = mergeLeadCandidates([...aiItems, ...ruleTodos]);
      extracted.addAll(merged);
    }

    final threshold = (confidenceThreshold != null &&
            confidenceThreshold >= 0.5 &&
            confidenceThreshold <= 0.95)
        ? confidenceThreshold
        : 0.75;

    final filtered = extracted.where((todo) {
      final confidence = todo['confidence'] is num
          ? (todo['confidence'] as num).toDouble()
          : 0.8;
      return confidence >= threshold;
    }).toList();

    if (filtered.isEmpty && firstBatchError != null) {
      throw firstBatchError!;
    }

    await store.ensureLoaded();
    final created = <Lead>[];
    for (final todoData in filtered) {
      if (store.isDuplicateOfExisting(todoData, chatName)) {
        continue;
      }
      final lead = await store.create({
        ...todoData,
        'groupName': chatName,
        'source': 'ai-generated',
        'sourceMessage': todoData['sourceMessage'],
      });
      created.add(lead);
    }
    return created;
  }

  List<_NormalizedMessage> normalizeBusinessMessages(
    List<LeadChatMessage> messages,
  ) {
    final result = <_NormalizedMessage>[];
    for (final m in messages) {
      var ts = m.timestampMs;
      if (ts < 1000000000000) ts *= 1000;
      final timeStr = _formatZhTime(DateTime.fromMillisecondsSinceEpoch(ts));
      final sender = m.sender ?? '';
      final content = m.content;
      final messageLine = '[$timeStr] [$sender]: $content';
      final signals = detectBusinessSignals(content);
      result.add(_NormalizedMessage(
        sender: sender.isEmpty ? null : sender,
        content: content,
        timestamp: ts,
        timeStr: timeStr,
        messageLine: messageLine,
        signals: signals,
      ));
    }
    result.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return result.where((m) => m.messageLine.trim().isNotEmpty).toList();
  }

  BusinessSignals detectBusinessSignals(String content) {
    final text = content;
    final labelPatterns = <({String label, RegExp regex, double score})>[
      (
        label: 'recruitment',
        regex: RegExp(r'(招聘|诚聘|急招|猎头|岗位|任职要求|JD|薪资|简历)', caseSensitive: false),
        score: 1,
      ),
      (
        label: 'procurement',
        regex: RegExp(r'(求购|采购|寻购|供应商|报价|预算|询价)', caseSensitive: false),
        score: 1,
      ),
      (
        label: 'resource',
        regex: RegExp(
          r'(资源|渠道|合作方|合作伙伴|服务商|仓储|物流|财务|法务|保险|场地)',
          caseSensitive: false,
        ),
        score: 0.9,
      ),
      (
        label: 'expert',
        regex: RegExp(r'(老师|专家|顾问|咨询服务|咨询老师|咨询专家)', caseSensitive: false),
        score: 0.8,
      ),
    ];

    final labels = <String>[];
    var score = 0.0;
    for (final pattern in labelPatterns) {
      if (pattern.regex.hasMatch(text)) {
        labels.add(pattern.label);
        score += pattern.score;
      }
    }
    if (RegExp(r'(微信|电话|联系|私聊|vx|V:|☎|手机)', caseSensitive: false)
        .hasMatch(text)) {
      score += 0.2;
    }
    if (RegExp(r'(地点|城市|坐标|薪资|待遇|预算|截止|本周|本月|尽快)', caseSensitive: false)
        .hasMatch(text)) {
      score += 0.2;
    }

    return BusinessSignals(
      labels: labels,
      score: score.clamp(0.0, 1.0),
      isRelevant: labels.isNotEmpty || score >= 0.7,
    );
  }

  List<BusinessSegment> buildBusinessSegments(
    List<_NormalizedMessage> messages,
  ) {
    final segments = <BusinessSegment>[];
    BusinessSegment? current;

    void finalize() {
      if (current == null || current!.messages.isEmpty) return;
      current!.chatContent =
          current!.messages.map((m) => m.messageLine).join('\n');
      current!.primaryLabel = pickPrimaryLabel(current!.labelCounts);
      current!.ruleScore = (current!.ruleScore /
              (current!.messages.isEmpty ? 1 : current!.messages.length))
          .clamp(0.0, 1.0);
      current!.segmentSummary =
          buildSegmentSummary(current!.messages, current!.primaryLabel);
      segments.add(current!);
      current = null;
    }

    for (final message in messages) {
      final lastMessage =
          current != null && current!.messages.isNotEmpty
              ? current!.messages.last
              : null;
      final gap =
          lastMessage != null ? message.timestamp - lastMessage.timestamp : 0;
      final nextLength =
          (current?.charCount ?? 0) + message.messageLine.length + 1;
      final nextPrimaryLabel =
          message.signals.labels.isNotEmpty ? message.signals.labels.first : null;
      final shouldSplit = current != null &&
          (gap > maxTimeGapMs ||
              nextLength > maxCharsPerSegment ||
              current!.messages.length >= maxMessagesPerSegment ||
              (nextPrimaryLabel != null &&
                  current!.primaryLabel != null &&
                  nextPrimaryLabel != current!.primaryLabel &&
                  gap > 10 * 60 * 1000));

      if (current == null || shouldSplit) {
        finalize();
        current = BusinessSegment(
          messages: [],
          charCount: 0,
          labelCounts: {},
          primaryLabel: nextPrimaryLabel,
          ruleScore: 0,
        );
      }

      current!.messages.add(message);
      current!.charCount += message.messageLine.length + 1;
      current!.ruleScore += message.signals.score;
      for (final label in message.signals.labels) {
        current!.labelCounts[label] = (current!.labelCounts[label] ?? 0) + 1;
      }
      if (current!.primaryLabel == null && nextPrimaryLabel != null) {
        current!.primaryLabel = nextPrimaryLabel;
      }
    }
    finalize();
    return segments;
  }

  String pickPrimaryLabel(Map<String, int> labelCounts) {
    if (labelCounts.isEmpty) return 'irrelevant';
    final entries = labelCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  String buildSegmentSummary(
    List<_NormalizedMessage> messages,
    String? primaryLabel,
  ) {
    if (messages.isEmpty) return '';
    _NormalizedMessage lastRelevant = messages.last;
    for (var i = messages.length - 1; i >= 0; i--) {
      if (messages[i].signals.isRelevant) {
        lastRelevant = messages[i];
        break;
      }
    }
    final base =
        lastRelevant.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (base.isEmpty) return '';
    final clipped = base.length > 80 ? base.substring(0, 80) : base;
    return '${primaryLabel ?? 'segment'}:$clipped';
  }

  String mergeRollingSummary(String previousSummary, String nextSummary) {
    final parts = [previousSummary, nextSummary]
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final merged = parts.length <= 2
        ? parts.join('；')
        : parts.sublist(parts.length - 2).join('；');
    if (merged.length <= 240) return merged;
    return merged.substring(merged.length - 240);
  }

  List<Map<String, dynamic>> mergeLeadCandidates(
    List<Map<String, dynamic>> items,
  ) {
    final merged = <Map<String, dynamic>>[];
    for (final item in items) {
      if (item['title'] == null) continue;
      final currentConfidence = item['confidence'] is num
          ? (item['confidence'] as num).toDouble()
          : 0.8;
      final existingIndex =
          merged.indexWhere((c) => isDuplicateLeadCandidate(c, item));
      if (existingIndex < 0) {
        merged.add(Map<String, dynamic>.from(item));
        continue;
      }
      final existing = merged[existingIndex];
      final existingConfidence = existing['confidence'] is num
          ? (existing['confidence'] as num).toDouble()
          : 0.8;
      if (currentConfidence > existingConfidence) {
        merged[existingIndex] = Map<String, dynamic>.from(item);
      }
    }
    return merged;
  }

  bool isDuplicateLeadCandidate(
    Map<String, dynamic> left,
    Map<String, dynamic> right,
  ) {
    if (left['messageTime'] != null &&
        right['messageTime'] != null &&
        left['sender'] != null &&
        right['sender'] != null &&
        left['messageTime'] == right['messageTime'] &&
        left['sender'] == right['sender']) {
      return true;
    }
    if (left['title'] != null &&
        right['title'] != null &&
        left['title'] == right['title']) {
      return true;
    }
    final ld = left['description']?.toString();
    final rd = right['description']?.toString();
    if (ld != null && rd != null) {
      return LeadStore.jaccardSimilarity(ld, rd) > 0.82;
    }
    return false;
  }

  List<Map<String, dynamic>> fallbackExtractImportantMessages(
    List<_NormalizedMessage> messages,
  ) {
    final results = <Map<String, dynamic>>[];
    final seen = <String>{};

    for (final m in messages) {
      final content = m.content.trim();
      if (content.isEmpty) continue;
      String? title;
      var priority = 'medium';
      String? category;
      var confidence = 0.8;

      if (RegExp(r'(招聘|诚聘|急招|猎头)').hasMatch(content)) {
        title = extractTitleFromContent(content, RegExp(r'(招聘|诚聘|急招|猎头)'));
        priority = 'high';
        category = 'recruitment';
        confidence = 0.9;
      } else if (RegExp(r'(求购|采购|寻购|找供应商)').hasMatch(content)) {
        title =
            extractTitleFromContent(content, RegExp(r'(求购|采购|寻购|找供应商)'));
        priority = 'high';
        category = 'procurement';
        confidence = 0.88;
      } else if (RegExp(r'(找资源|寻找资源|找渠道|找合作|找场地)').hasMatch(content)) {
        title = extractTitleFromContent(
          content,
          RegExp(r'(找资源|寻找资源|找渠道|找合作|找场地)'),
        );
        category = 'resource';
        confidence = 0.82;
      } else if (RegExp(r'(找老师|找专家|咨询老师|咨询专家|顾问)').hasMatch(content)) {
        title = extractTitleFromContent(
          content,
          RegExp(r'(找老师|找专家|咨询老师|咨询专家|顾问)'),
        );
        category = 'expert';
        confidence = 0.8;
      }

      if (title == null) continue;
      final key = '${m.sender ?? ''}||${m.timeStr}||$title';
      if (seen.contains(key)) continue;
      seen.add(key);

      results.add({
        'title': title,
        'description':
            content.length > 500 ? content.substring(0, 500) : content,
        'priority': priority,
        'dueDate': null,
        'sender': m.sender,
        'messageTime': m.timeStr,
        'category': category,
        'confidence': confidence,
      });
    }
    return results;
  }

  String extractTitleFromContent(String content, RegExp keywordRegex) {
    final lines = content
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    String matched = lines.isNotEmpty ? lines.first : '';
    for (final line in lines) {
      if (keywordRegex.hasMatch(line)) {
        matched = line;
        break;
      }
    }
    return matched.length > 60 ? matched.substring(0, 60) : matched;
  }

  String _formatZhTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${dt.month}/${dt.day} ${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }
}

class BusinessSignals {
  final List<String> labels;
  final double score;
  final bool isRelevant;

  const BusinessSignals({
    required this.labels,
    required this.score,
    required this.isRelevant,
  });
}

class _NormalizedMessage {
  final String? sender;
  final String content;
  final int timestamp;
  final String timeStr;
  final String messageLine;
  final BusinessSignals signals;

  _NormalizedMessage({
    required this.sender,
    required this.content,
    required this.timestamp,
    required this.timeStr,
    required this.messageLine,
    required this.signals,
  });
}

class BusinessSegment {
  final List<_NormalizedMessage> messages;
  int charCount;
  final Map<String, int> labelCounts;
  String? primaryLabel;
  double ruleScore;
  String chatContent;
  String segmentSummary;

  BusinessSegment({
    required this.messages,
    required this.charCount,
    required this.labelCounts,
    required this.primaryLabel,
    required this.ruleScore,
    this.chatContent = '',
    this.segmentSummary = '',
  });
}
