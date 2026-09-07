import '../../models/chat_session.dart';
import '../../models/lead.dart';
import '../../models/message.dart';
import '../config_service.dart';
import '../database_service.dart';
import 'ai_client_service.dart';
import 'lead_pipeline_service.dart';
import 'lead_store.dart';

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
        .where((m) => m.displayContent.trim().isNotEmpty)
        .map(messageToLeadChat)
        .toList();
    if (input.isEmpty) return [];
    return pipeline.generateFromChat(
      input,
      chatName,
      confidenceThreshold: threshold,
    );
  }

  /// 对多个群按分析时窗抓取近期消息中的商机，返回新增条数。
  ///
  /// [onProgress] 每完成一个群回调；[shouldCancel] 返回 true 时提前结束。
  /// 每群处理后让出事件循环，避免大批量时 UI 假死。
  Future<int> captureGroups({
    required DatabaseService database,
    required List<ChatSession> groups,
    int? analysisHours,
    double? confidenceThreshold,
    int messageLimit = 80,
    void Function(int done, int total, String currentName)? onProgress,
    bool Function()? shouldCancel,
  }) async {
    if (groups.isEmpty) return 0;
    await aiClient.loadFromConfig();
    final hours = analysisHours ?? await _config.getAiAnalysisHours();
    final threshold =
        confidenceThreshold ?? await _config.getConfidenceThreshold();
    final cutoff = DateTime.now().subtract(Duration(hours: hours));
    final cutoffSec = cutoff.millisecondsSinceEpoch ~/ 1000;
    final pipeline = LeadPipelineService(aiClient: aiClient, store: store);

    var total = 0;
    for (var i = 0; i < groups.length; i++) {
      if (shouldCancel?.call() == true) break;
      final group = groups[i];
      final chatName = group.displayName?.isNotEmpty == true
          ? group.displayName!
          : group.username;
      onProgress?.call(i, groups.length, chatName);

      final messages = await database.getMessages(
        group.username,
        limit: messageLimit,
        offset: 0,
      );
      final input = messages
          .where((m) => m.createTime >= cutoffSec)
          .where((m) => m.displayContent.trim().isNotEmpty)
          .map(messageToLeadChat)
          .toList();
      if (input.isNotEmpty) {
        final created = await pipeline.generateFromChat(
          input,
          chatName,
          confidenceThreshold: threshold,
        );
        total += created.length;
      }
      onProgress?.call(i + 1, groups.length, chatName);
      // 让出 UI 线程，避免连续同步/密集 await 造成假死感
      await Future<void>.delayed(Duration.zero);
    }
    return total;
  }
}
