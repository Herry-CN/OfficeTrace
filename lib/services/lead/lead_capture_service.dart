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
  Future<int> captureGroups({
    required DatabaseService database,
    required List<ChatSession> groups,
    int? analysisHours,
    double? confidenceThreshold,
    int messageLimit = 120,
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
    for (final group in groups) {
      final chatName = group.displayName?.isNotEmpty == true
          ? group.displayName!
          : group.username;
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
      if (input.isEmpty) continue;
      final created = await pipeline.generateFromChat(
        input,
        chatName,
        confidenceThreshold: threshold,
      );
      total += created.length;
    }
    return total;
  }
}
