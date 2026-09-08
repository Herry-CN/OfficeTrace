import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 商机抓取共享规则：可抓文本判定、信号强度、去重指纹。
class LeadCaptureRules {
  LeadCaptureRules._();

  /// 占位符 / 非文本消息，进入 AI 易错抓且无商机价值。
  static final RegExp placeholderContent = RegExp(
    r'^\[(图片|语音|视频|动画表情|表情|文件|位置|链接|名片|系统消息|未知消息类型.*|聊天记录|小程序|音乐|礼物)\]$',
  );

  static bool isCapturableText(String content) {
    final text = content.trim();
    if (text.isEmpty) return false;
    if (placeholderContent.hasMatch(text)) return false;
    if (text.length < 2) return false;
    return true;
  }

  /// 强商机意图（规则通道可直接过 AI 否决）。
  static final RegExp strongBusinessIntent = RegExp(
    r'(诚聘|急招|招聘|猎头|求购|采购|寻购|找供应商|询价|报价)',
  );

  /// 归一化标题/描述，供精确去重。
  static String normalizeKey(String? raw) {
    if (raw == null) return '';
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll(RegExp(r'[^\w\u4e00-\u9fff]+'), '');
  }

  /// 中文友好：双字符 bigram Jaccard（优于单字集合）。
  static double bigramJaccard(String a, String b) {
    final na = normalizeKey(a);
    final nb = normalizeKey(b);
    if (na.isEmpty || nb.isEmpty) return 0;
    if (na == nb) return 1;
    final sa = _bigrams(na);
    final sb = _bigrams(nb);
    if (sa.isEmpty || sb.isEmpty) {
      // 极短串退回字符集合
      final ca = na.split('').toSet();
      final cb = nb.split('').toSet();
      final inter = ca.intersection(cb).length;
      final union = ca.union(cb).length;
      return union == 0 ? 0 : inter / union;
    }
    final inter = sa.intersection(sb).length;
    final union = sa.union(sb).length;
    return union == 0 ? 0 : inter / union;
  }

  static Set<String> _bigrams(String s) {
    if (s.length < 2) return {s};
    final out = <String>{};
    for (var i = 0; i < s.length - 1; i++) {
      out.add(s.substring(i, i + 2));
    }
    return out;
  }

  /// 稳定内容指纹：同群重复抓时即使 AI 改写轻微措辞也能对上。
  static String contentFingerprint({
    String? title,
    String? description,
    String? sender,
    String? messageTime,
    String? messageId,
  }) {
    if (messageId != null && messageId.trim().isNotEmpty) {
      return 'mid:${messageId.trim()}';
    }
    final payload = [
      normalizeKey(title),
      normalizeKey(description).length > 80
          ? normalizeKey(description).substring(0, 80)
          : normalizeKey(description),
      (sender ?? '').trim(),
      (messageTime ?? '').trim(),
    ].join('|');
    return sha1.convert(utf8.encode(payload)).toString();
  }

  /// 候选是否与已有商机重复。
  static bool isNearDuplicateCandidate({
    required String? leftTitle,
    required String? leftDescription,
    required String? leftSender,
    required String? leftMessageTime,
    String? leftFingerprint,
    String? leftMessageId,
    required String? rightTitle,
    required String? rightDescription,
    required String? rightSender,
    required String? rightMessageTime,
    String? rightFingerprint,
    String? rightMessageId,
  }) {
    final lf = leftFingerprint ??
        contentFingerprint(
          title: leftTitle,
          description: leftDescription,
          sender: leftSender,
          messageTime: leftMessageTime,
          messageId: leftMessageId,
        );
    final rf = rightFingerprint ??
        contentFingerprint(
          title: rightTitle,
          description: rightDescription,
          sender: rightSender,
          messageTime: rightMessageTime,
          messageId: rightMessageId,
        );
    if (lf.isNotEmpty && lf == rf) return true;

    if (leftMessageId != null &&
        rightMessageId != null &&
        leftMessageId.isNotEmpty &&
        leftMessageId == rightMessageId) {
      return true;
    }

    if (leftMessageTime != null &&
        rightMessageTime != null &&
        leftSender != null &&
        rightSender != null &&
        leftMessageTime == rightMessageTime &&
        leftSender == rightSender) {
      return true;
    }

    final nt = normalizeKey(leftTitle);
    final rt = normalizeKey(rightTitle);
    if (nt.isNotEmpty && nt == rt) return true;
    if (nt.length >= 6 && rt.length >= 6 && bigramJaccard(nt, rt) >= 0.9) {
      return true;
    }

    final ld = leftDescription ?? '';
    final rd = rightDescription ?? '';
    if (ld.length > 12 && rd.length > 12 && bigramJaccard(ld, rd) > 0.78) {
      return true;
    }
    return false;
  }

  /// AI 判 irrelevant 时，仅保留强规则命中，避免闲聊关键词错抓。
  static bool isStrongRuleCandidate(Map<String, dynamic> todo) {
    final category = todo['category']?.toString() ?? '';
    final title = todo['title']?.toString() ?? '';
    final description = todo['description']?.toString() ?? '';
    final conf = todo['confidence'] is num
        ? (todo['confidence'] as num).toDouble()
        : 0.0;
    final blob = '$title\n$description';
    if (strongBusinessIntent.hasMatch(blob)) return true;
    if ((category == 'recruitment' || category == 'procurement') &&
        conf >= 0.85) {
      return true;
    }
    return false;
  }

  /// 是否应对该段调用提取。
  static bool shouldExtractSegment({
    required bool hasRuleTodos,
    required String label,
    required double confidence,
    required bool aiShouldExtract,
  }) {
    if (hasRuleTodos) return true;
    if (aiShouldExtract && label != 'irrelevant') return true;
    if (label != 'irrelevant' && confidence >= 0.45) return true;
    // AI 明确要求提取且置信度尚可（label 偶发写错）
    if (aiShouldExtract && confidence >= 0.55) return true;
    return false;
  }

  /// 合并规则与 AI：AI 高置信 irrelevant 时压制弱规则。
  static List<Map<String, dynamic>> gateRuleAgainstAi({
    required List<Map<String, dynamic>> aiItems,
    required List<Map<String, dynamic>> ruleTodos,
    required String aiLabel,
    required double aiConfidence,
  }) {
    if (ruleTodos.isEmpty) return [...aiItems];
    final aiRejects = aiLabel == 'irrelevant' &&
        aiConfidence >= 0.55 &&
        aiItems.isEmpty;
    if (!aiRejects) return [...aiItems, ...ruleTodos];
    return [
      ...aiItems,
      ...ruleTodos.where(isStrongRuleCandidate),
    ];
  }
}
