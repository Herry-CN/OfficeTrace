import '../../models/chat_session.dart';
import '../../models/lead.dart';
import '../../models/message.dart';
import '../config_service.dart';
import '../database_service.dart';
import 'ai_client_service.dart';
import 'auto_sync_pipeline_logic.dart';
import 'lead_capture_rules.dart';
import 'lead_pipeline_service.dart';
import 'lead_store.dart';

/// 批量抓取结果：含跳过无变化群的统计。
class CaptureGroupsResult {
  const CaptureGroupsResult({
    required this.createdCount,
    required this.processedGroups,
    required this.skippedUnchanged,
  });

  final int createdCount;
  final int processedGroups;
  final int skippedUnchanged;

  int get consideredGroups => processedGroups + skippedUnchanged;
}

/// 商机抓取入口：立即抓取 / 自动抓取共用
class LeadCaptureService {
  LeadCaptureService({
    required this.aiClient,
    required this.store,
    ConfigService? configService,
  }) : _config = configService ?? ConfigService();

  final AiClientService aiClient;
  final LeadStore store;
  final ConfigService _config;

  /// 默认可抓文本消息；排除系统/媒体占位，降低错抓。
  static bool isCapturableMessage(Message m) {
    if (m.isSystemLike) return false;
    if (m.isImageMessage || m.isVoiceMessage || m.isVideoMessage) {
      return false;
    }
    return LeadCaptureRules.isCapturableText(m.displayContent);
  }

  LeadChatMessage messageToLeadChat(Message m) {
    return LeadChatMessage(
      id: m.localId.toString(),
      sender: m.senderUsername,
      content: m.displayContent,
      timestampMs: m.createTime * 1000,
    );
  }

  Future<List<Lead>> captureFromMessages(
    List<Message> messages,
    String chatName, {
    double? confidenceThreshold,
  }) async {
    await aiClient.loadFromConfig();
    final threshold =
        confidenceThreshold ?? await _config.getConfidenceThreshold();
    final pipeline = LeadPipelineService(aiClient: aiClient, store: store);
    final input = messages
        .where(isCapturableMessage)
        .map(messageToLeadChat)
        .toList();
    if (input.isEmpty) return [];
    return pipeline.generateFromChat(
      input,
      chatName,
      confidenceThreshold: threshold,
    );
  }

  /// 对多个群按分析时窗抓取近期消息中的商机。
  ///
  /// 默认跳过相对上次抓取水位无新消息的群；[forceAll]=true 时强制全抓。
  Future<CaptureGroupsResult> captureGroups({
    required DatabaseService database,
    required List<ChatSession> groups,
    int? analysisHours,
    double? confidenceThreshold,
    int messageLimit = 120,
    bool forceAll = false,
    void Function(int done, int total, String currentName)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    if (groups.isEmpty) {
      return CaptureGroupsResult(
        createdCount: 0,
        processedGroups: 0,
        skippedUnchanged: 0,
      );
    }
    await aiClient.loadFromConfig();
    final hours = analysisHours ?? await _config.getAiAnalysisHours();
    final threshold =
        confidenceThreshold ?? await _config.getConfidenceThreshold();
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    final cutoffSec = cutoff.millisecondsSinceEpoch ~/ 1000;
    final pipeline = LeadPipelineService(aiClient: aiClient, store: store);
    final watermarks = forceAll
        ? <String, int>{}
        : Map<String, int>.from(await _config.getCaptureWatermarks());
    var watermarksDirty = false;

    var createdTotal = 0;
    var processed = 0;
    var skipped = 0;

    for (var i = 0; i < groups.length; i++) {
      if (shouldCancel?.call() == true) break;
      final group = groups[i];
      final chatName = group.displayName?.isNotEmpty == true
          ? group.displayName!
          : group.username;
      onProgress?.call(i, groups.length, chatName);

      final lastWm = forceAll ? null : watermarks[group.username];
      if (!forceAll &&
          shouldSkipBySessionTimestamp(
            lastCapturedMaxCreateTime: lastWm,
            sessionLastTimestamp: group.lastTimestamp,
          )) {
        skipped++;
        onProgress?.call(i + 1, groups.length, '$chatName（无新消息，跳过）');
        await Future<void>.delayed(Duration.zero);
        continue;
      }

      final messages = await database.getMessages(
        group.username,
        limit: messageLimit,
        offset: 0,
      );
      final maxCreateTime = messages.isEmpty
          ? null
          : messages.map((m) => m.createTime).reduce((a, b) => a > b ? a : b);

      if (!forceAll &&
          shouldSkipUnchangedGroupCapture(
            lastCapturedMaxCreateTime: lastWm,
            currentMaxCreateTime: maxCreateTime,
          )) {
        skipped++;
        onProgress?.call(i + 1, groups.length, '$chatName（无新消息，跳过）');
        await Future<void>.delayed(Duration.zero);
        continue;
      }

      final input = selectMessagesForPipeline(
        messages: messages,
        cutoffSec: cutoffSec,
        lastWatermark: lastWm,
      );

      if (input.isNotEmpty) {
        final created = await pipeline.generateFromChat(
          input,
          chatName,
          confidenceThreshold: threshold,
        );
        createdTotal += created.length;
      }

      // 仅在本群处理完成后推进水位，避免中途失败导致漏抓
      if (maxCreateTime != null) {
        watermarks[group.username] = maxCreateTime;
        watermarksDirty = true;
      }
      processed++;
      onProgress?.call(i + 1, groups.length, chatName);
      await Future<void>.delayed(Duration.zero);
    }

    if (watermarksDirty) {
      await _config.saveCaptureWatermarks(watermarks);
    }

    return CaptureGroupsResult(
      createdCount: createdTotal,
      processedGroups: processed,
      skippedUnchanged: skipped,
    );
  }

  /// 时窗内可抓文本；有水位时以新消息为主，并带少量旧消息作上下文，降低漏抓。
  static List<LeadChatMessage> selectMessagesForPipeline({
    required List<Message> messages,
    required int cutoffSec,
    int? lastWatermark,
    int contextLimit = 15,
  }) {
    final inWindow = messages
        .where((m) => m.createTime >= cutoffSec)
        .where(isCapturableMessage)
        .toList()
      ..sort((a, b) => a.createTime.compareTo(b.createTime));

    if (inWindow.isEmpty) return const [];

    if (lastWatermark == null) {
      return inWindow.map(_toLeadChat).toList();
    }

    final newer =
        inWindow.where((m) => m.createTime > lastWatermark).toList();
    if (newer.isEmpty) {
      // 水位未跳过时可能因 session 时间不准走到这里：仍扫全窗，靠去重防重复
      return inWindow.map(_toLeadChat).toList();
    }

    final older =
        inWindow.where((m) => m.createTime <= lastWatermark).toList();
    final context = older.length <= contextLimit
        ? older
        : older.sublist(older.length - contextLimit);
    return [...context, ...newer].map(_toLeadChat).toList();
  }

  static LeadChatMessage _toLeadChat(Message m) => LeadChatMessage(
        id: m.localId.toString(),
        sender: m.senderUsername,
        content: m.displayContent,
        timestampMs: m.createTime * 1000,
      );
}
