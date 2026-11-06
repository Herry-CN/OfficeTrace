import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/lead.dart';
import '../config_service.dart';
import 'lead_category.dart';
import 'lead_prompt_pack.dart';

/// AI 服务不可用（LM Studio / Ollama / OpenAI 均未就绪）。
class AiNotConfiguredException implements Exception {
  AiNotConfiguredException([
    this.message =
        'AI 未就绪：请先启动 LM Studio（加载模型，默认 http://localhost:1234）或 Ollama，'
            '也可在「设置 → 商机 AI 配置」填写 OpenAI 兼容地址并测试连接。',
  ]);

  final String message;

  @override
  String toString() => message;
}

/// Ollama / OpenAI 兼容客户端（含 LM Studio）：商机分类与结构化提取
class AiClientService {
  AiClientService({ConfigService? configService, http.Client? httpClient})
      : _config = configService ?? ConfigService(),
        _http = httpClient ?? http.Client();

  final ConfigService _config;
  final http.Client _http;

  String? provider;
  String ollamaUrl = 'http://localhost:11434';
  String openaiUrl = 'http://localhost:1234/v1';
  String? openaiKey;
  String? model;
  bool isReady = false;
  String todoPromptCategories = LeadPromptPack.defaultCategories;
  String classificationPrompt = LeadPromptPack.defaultClassificationPrompt;
  String extractionPrompt = LeadPromptPack.defaultExtractionPrompt;

  static const String defaultTodoPromptCategories = LeadPromptPack.defaultCategories;

  String get _openaiBase {
    var base = openaiUrl.trim();
    if (base.endsWith('/')) base = base.substring(0, base.length - 1);
    if (!base.endsWith('/v1')) {
      // LM Studio 常用根地址 http://localhost:1234
      if (base.contains('1234') && !base.contains('/v1')) {
        base = '$base/v1';
      }
    }
    return base;
  }

  Future<void> loadFromConfig() async {
    ollamaUrl = await _config.getOllamaBaseUrl();
    openaiUrl = await _config.getOpenaiBaseUrl();
    openaiKey = await _config.getOpenaiApiKey();
    final preferred = await _config.getAiProvider();
    model = await _config.getAiModel();
    final prompts = await LeadPromptPack.load(_config);
    todoPromptCategories = prompts.categories;
    classificationPrompt = prompts.classificationPrompt;
    extractionPrompt = prompts.extractionPrompt;
    if (preferred == 'openai') {
      provider = 'openai';
      // 已有模型时不再阻塞等待 LM Studio 枚举
      if (model == null || model!.isEmpty) {
        final models = await getOpenAiModels();
        if (models.isNotEmpty) {
          model = pickPreferredOllamaModel(models) ?? models.first;
        }
      }
      model ??= 'local-model';
      isReady = true;
      return;
    }
    await autoDetectProvider();
  }

  Future<Map<String, dynamic>> getStatus() async {
    try {
      await autoDetectProvider();
    } catch (_) {}
    final ollamaAvailable = await checkOllama();
    final openAiAvailable = await checkOpenAiCompatible();
    return {
      'provider': provider,
      'model': model,
      'isReady': isReady,
      'ollamaAvailable': ollamaAvailable,
      'openaiAvailable': openAiAvailable,
      'openaiConfigured': openAiAvailable || (openaiKey?.isNotEmpty ?? false),
      'openaiBaseUrl': _openaiBase,
      'ollamaModels': ollamaAvailable ? await getOllamaModels() : <String>[],
      'openaiModels': openAiAvailable ? await getOpenAiModels() : <String>[],
      'todoPromptCategories': todoPromptCategories,
    };
  }

  Future<void> configure({
    String? openaiKey,
    String? openaiBaseUrl,
    String? ollamaUrl,
    String? model,
    String? provider,
    String? todoPromptCategories,
    String? classificationPrompt,
    String? extractionPrompt,
  }) async {
    if (openaiKey != null) {
      this.openaiKey = openaiKey.trim().isEmpty ? null : openaiKey.trim();
      await _config.saveOpenaiApiKey(this.openaiKey ?? '');
    }
    if (openaiBaseUrl != null) {
      this.openaiUrl = openaiBaseUrl.trim().isEmpty
          ? 'http://localhost:1234/v1'
          : openaiBaseUrl.trim();
      await _config.saveOpenaiBaseUrl(this.openaiUrl);
    }
    if (ollamaUrl != null) {
      this.ollamaUrl =
          ollamaUrl.trim().isEmpty ? 'http://localhost:11434' : ollamaUrl.trim();
      await _config.saveOllamaBaseUrl(this.ollamaUrl);
    }
    if (model != null) {
      this.model = model.trim().isEmpty ? null : model.trim();
      await _config.saveAiModel(this.model ?? '');
    }
    if (provider != null && provider.isNotEmpty) {
      await _config.saveAiProvider(provider);
    }
    if (todoPromptCategories != null ||
        classificationPrompt != null ||
        extractionPrompt != null) {
      final pack = LeadPromptPack(
        categories: todoPromptCategories ?? this.todoPromptCategories,
        classificationPrompt:
            classificationPrompt ?? this.classificationPrompt,
        extractionPrompt: extractionPrompt ?? this.extractionPrompt,
      ).normalized();
      this.todoPromptCategories = pack.categories;
      this.classificationPrompt = pack.classificationPrompt;
      this.extractionPrompt = pack.extractionPrompt;
      await pack.persist(_config);
    }
    await autoDetectProvider();
  }

  Future<void> autoDetectProvider() async {
    final preferred = await _config.getAiProvider();
    openaiUrl = await _config.getOpenaiBaseUrl();
    openaiKey = await _config.getOpenaiApiKey();

    if (preferred == 'openai') {
      provider = 'openai';
      final models = await getOpenAiModels();
      if ((model == null || model!.isEmpty) && models.isNotEmpty) {
        model = pickPreferredOllamaModel(models) ?? models.first;
      }
      model ??= 'local-model';
      isReady = true;
      return;
    }

    // auto：优先 LM Studio / OpenAI 兼容本地服务，再 Ollama
    if (preferred == 'auto' || preferred == 'ollama') {
      final openAiAvailable = await checkOpenAiCompatible();
      if (openAiAvailable && preferred != 'ollama') {
        provider = 'openai';
        final models = await getOpenAiModels();
        if ((model == null || model!.isEmpty) && models.isNotEmpty) {
          model = pickPreferredOllamaModel(models) ?? models.first;
        }
        model ??= 'local-model';
        isReady = true;
        return;
      }

      final ollamaAvailable = await checkOllama();
      if (ollamaAvailable) {
        provider = 'ollama';
        if (model == null || model!.isEmpty) {
          final models = await getOllamaModels();
          if (models.isNotEmpty) {
            model = pickPreferredOllamaModel(models) ?? models.first;
          }
        }
        isReady = model != null && model!.isNotEmpty;
        return;
      }

      if (openAiAvailable) {
        provider = 'openai';
        final models = await getOpenAiModels();
        if ((model == null || model!.isEmpty) && models.isNotEmpty) {
          model = pickPreferredOllamaModel(models) ?? models.first;
        }
        model ??= 'local-model';
        isReady = true;
        return;
      }
    }

    if (openaiKey != null && openaiKey!.isNotEmpty) {
      provider = 'openai';
      model ??= 'gpt-3.5-turbo';
      isReady = true;
      return;
    }

    isReady = false;
  }

  Future<bool> checkOllama() async {
    try {
      final response = await _http
          .get(Uri.parse('$ollamaUrl/api/tags'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> checkOpenAiCompatible() async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      final key = (openaiKey == null || openaiKey!.isEmpty)
          ? 'lm-studio'
          : openaiKey!;
      headers['Authorization'] = 'Bearer $key';
      final response = await _http
          .get(Uri.parse('$_openaiBase/models'), headers: headers)
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getOllamaModels() async {
    try {
      final response = await _http
          .get(Uri.parse('$ollamaUrl/api/tags'))
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      final models = data['models'];
      if (models is! List) return [];
      return models
          .map((m) => m is Map ? m['name']?.toString() : null)
          .whereType<String>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getOpenAiModels() async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json'};
      final key = (openaiKey == null || openaiKey!.isEmpty)
          ? 'lm-studio'
          : openaiKey!;
      headers['Authorization'] = 'Bearer $key';
      final response = await _http
          .get(
            Uri.parse('$_openaiBase/models'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 2));
      if (response.statusCode != 200) return [];
      final data = jsonDecode(response.body);
      final models = data['data'];
      if (models is! List) return [];
      return models
          .map((m) => m is Map ? m['id']?.toString() : null)
          .whereType<String>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  String? pickPreferredOllamaModel(
    List<String> models, {
    Iterable<String> exclude = const [],
  }) {
    final excluded = exclude.where((e) => e.isNotEmpty).toSet();
    final ordered = [
      ...models.where((m) => RegExp(r'qwen2\.5', caseSensitive: false).hasMatch(m)),
      ...models.where((m) => RegExp(r'qwen', caseSensitive: false).hasMatch(m)),
      ...models.where((m) => RegExp(r'llama', caseSensitive: false).hasMatch(m)),
      ...models.where((m) => RegExp(r'mistral', caseSensitive: false).hasMatch(m)),
      ...models,
    ];
    for (final m in ordered) {
      if (!excluded.contains(m)) return m;
    }
    return null;
  }

  Future<String> chat(String message, {List<Map<String, String>> context = const []}) async {
    if (!isReady) {
      await loadFromConfig();
      if (!isReady) {
        throw AiNotConfiguredException();
      }
    }
    if (provider == 'ollama') {
      return chatWithOllama(message, context: context);
    }
    if (provider == 'openai') {
      return chatWithOpenAI(message, context: context);
    }
    throw Exception('未知的AI提供者');
  }

  Future<String> chatWithOllama(
    String message, {
    List<Map<String, String>> context = const [],
  }) async {
    final messages = [
      ...context.map((c) => {'role': c['role'] ?? 'user', 'content': c['content'] ?? ''}),
      {'role': 'user', 'content': message},
    ];
    final tried = <String>{};
    var currentModel = model;

    while (currentModel != null && !tried.contains(currentModel)) {
      tried.add(currentModel);
      try {
        final response = await _http.post(
          Uri.parse('$ollamaUrl/api/chat'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'model': currentModel,
            'messages': messages,
            'stream': false,
            'format': 'json',
            'options': {'temperature': 0.2},
          }),
        );
        if (response.statusCode >= 400) {
          throw Exception('HTTP ${response.statusCode}: ${response.body}');
        }
        final data = jsonDecode(response.body);
        model = currentModel;
        return data['message']?['content']?.toString() ?? '';
      } catch (_) {
        final models = await getOllamaModels();
        final fallback = pickPreferredOllamaModel(models, exclude: tried);
        if (fallback == null) {
          rethrow;
        }
        currentModel = fallback;
      }
    }
    throw Exception('Ollama请求失败: 未找到可用模型');
  }

  Future<String> chatWithOpenAI(
    String message, {
    List<Map<String, String>> context = const [],
  }) async {
    final messages = [
      {
        'role': 'system',
        'content':
            '你是一个智能助手，帮助用户从微信群聊中抓取商务商机。请只返回合法 JSON，不要附加解释。',
      },
      ...context.map((c) => {'role': c['role'] ?? 'user', 'content': c['content'] ?? ''}),
      {'role': 'user', 'content': message},
    ];
    final key =
        (openaiKey == null || openaiKey!.isEmpty) ? 'lm-studio' : openaiKey!;
    final response = await _http.post(
      Uri.parse('$_openaiBase/chat/completions'),
      headers: {
        'Authorization': 'Bearer $key',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': model ?? 'local-model',
        'messages': messages,
        'temperature': 0.2,
      }),
    );
    if (response.statusCode >= 400) {
      throw Exception(
        'OpenAI兼容请求失败: HTTP ${response.statusCode} ${response.body}',
      );
    }
    final data = jsonDecode(response.body);
    final choices = data['choices'];
    if (choices is List && choices.isNotEmpty) {
      return choices.first['message']?['content']?.toString() ?? '';
    }
    return '';
  }

  static dynamic parseJsonResponse(String? response) {
    if (response == null || response.trim().isEmpty) return null;
    try {
      return jsonDecode(response);
    } catch (_) {}

    final fenced = RegExp(r'```json\s*([\s\S]*?)```', caseSensitive: false)
        .firstMatch(response);
    if (fenced != null) {
      try {
        return jsonDecode(fenced.group(1)!);
      } catch (_) {}
    }

    final objectMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
    if (objectMatch != null) {
      try {
        return jsonDecode(objectMatch.group(0)!);
      } catch (_) {}
    }

    final arrayMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
    if (arrayMatch != null) {
      try {
        return jsonDecode(arrayMatch.group(0)!);
      } catch (_) {}
    }
    return null;
  }

  static List<Map<String, dynamic>> normalizeLeadItems(dynamic parsed) {
    List<dynamic> items;
    if (parsed is List) {
      items = parsed;
    } else if (parsed is Map) {
      if (parsed['items'] is List) {
        items = parsed['items'] as List;
      } else if (parsed['results'] is List) {
        items = parsed['results'] as List;
      } else if (parsed['data'] is List) {
        items = parsed['data'] as List;
      } else if (parsed['title'] is String) {
        items = [parsed];
      } else {
        items = const [];
      }
    } else {
      items = const [];
    }

    return items
        .whereType<Map>()
        .where((item) =>
            item['title'] is String &&
            (item['title'] as String).trim().isNotEmpty)
        .map((item) {
          final raw = item['confidence'];
          var confidence = raw is num
              ? raw.toDouble()
              : double.tryParse(raw?.toString() ?? '') ?? 0.8;
          if (confidence > 1) confidence = confidence / 100;
          final priority = item['priority']?.toString() ?? 'medium';
          return <String, dynamic>{
            'title': item['title'].toString().substring(
                  0,
                  item['title'].toString().length.clamp(0, 200),
                ),
            'description': item['description'] == null
                ? ''
                : item['description'].toString().substring(
                      0,
                      item['description'].toString().length.clamp(0, 1000),
                    ),
            'priority':
                ['high', 'medium', 'low'].contains(priority) ? priority : 'medium',
            'dueDate': item['dueDate'],
            'sender': item['sender'],
            'messageTime': item['messageTime'],
            'category': LeadCategory.resolve(
              itemCategory: item['category']?.toString(),
              title: item['title']?.toString(),
              description: item['description']?.toString(),
            ),
            'confidence': confidence.clamp(0.0, 1.0),
          };
        })
        .toList();
  }

  String effectiveClassificationPrompt() {
    final text = classificationPrompt.trim();
    return text.isEmpty ? LeadPromptPack.defaultClassificationPrompt : text;
  }

  String effectiveExtractionPrompt() {
    final text = extractionPrompt.trim();
    return text.isEmpty ? LeadPromptPack.defaultExtractionPrompt : text;
  }

  String effectiveCategories() {
    final text = todoPromptCategories.trim();
    return text.isEmpty ? LeadPromptPack.defaultCategories : text;
  }

  /// 拼出分类请求。规则来自可配置提示词，输出格式保持固定。
  String buildClassificationPrompt(
    String chatContent, {
    String previousSummary = '',
  }) {
    final rules = effectiveClassificationPrompt();
    return '''你是群聊商机筛选器。请判断下面聊天片段是否包含“值得抓取的商机信息”。

$rules

如果有上一段摘要，可作为上下文参考：
${previousSummary.isEmpty ? '无' : previousSummary}

请只返回 JSON 对象：
{
  "label": "使用上面声明的标签；无关内容用 irrelevant",
  "confidence": 0.0,
  "shouldExtract": true,
  "summary": "一句话概括片段内容"
}

聊天片段：
$chatContent''';
  }

  String buildExtractionPrompt(
    String chatContent, {
    String previousSummary = '',
    String segmentLabel = '',
  }) {
    final categoriesText = effectiveCategories();
    final rules = effectiveExtractionPrompt();
    return '''请分析以下聊天内容，提取其中的“商机 / 资源类重要信息”。

这里的目标信息主要包括但不限于：
$categoriesText

$rules
上一段摘要（用于补足上下文）：
${previousSummary.isEmpty ? '无' : previousSummary}

当前片段预判标签：
${segmentLabel.isEmpty ? '未提供' : segmentLabel}

聊天内容中，每一行的格式为：
[时间] [发送者]: 消息内容

请将识别出的每条重要信息整理为 JSON 对象，格式如下：
{
  "summary": "该片段的一句话摘要",
  "items": [
    {
      "title": "标题",
      "description": "详细描述",
      "priority": "high|medium|low",
      "dueDate": null,
      "sender": "发送者",
      "messageTime": "2026/4/4 18:58:37",
      "category": "recruitment|procurement|resource|expert|other",
      "confidence": 0.0
    }
  ]
}

请只返回 JSON 对象。如果没有符合类型的重要信息，请返回 {"summary":"","items":[]}。

聊天内容：
$chatContent''';
  }

  Future<BusinessClassification> classifyBusinessSegment(
    String chatContent, {
    String previousSummary = '',
  }) async {
    final rules = effectiveClassificationPrompt();
    final prompt = buildClassificationPrompt(
      chatContent,
      previousSummary: previousSummary,
    );

    final response = await chat(prompt);
    final parsed = parseJsonResponse(response);
    final map = parsed is Map ? parsed : <String, dynamic>{};
    final raw = map['confidence'];
    var confidence = raw is num
        ? raw.toDouble()
        : double.tryParse(raw?.toString() ?? '') ?? 0.0;
    if (confidence > 1) confidence = confidence / 100;
    final label = LeadPromptPack.normalizeClassificationLabel(
      map['label']?.toString(),
      rules,
    );

    return BusinessClassification(
      label: label,
      confidence: confidence.clamp(0.0, 1.0),
      shouldExtract: map['shouldExtract'] == true || label != 'irrelevant',
      summary: map['summary']?.toString().substring(
            0,
            (map['summary']?.toString().length ?? 0).clamp(0, 200),
          ) ??
          '',
    );
  }

  Future<LeadExtractionResult> extractBusinessLeads(
    String chatContent, {
    String previousSummary = '',
    String segmentLabel = '',
  }) async {
    final prompt = buildExtractionPrompt(
      chatContent,
      previousSummary: previousSummary,
      segmentLabel: segmentLabel,
    );

    final response = await chat(prompt);
    try {
      final parsed = parseJsonResponse(response);
      final summary = parsed is Map && parsed['summary'] is String
          ? (parsed['summary'] as String).substring(
              0,
              (parsed['summary'] as String).length.clamp(0, 200),
            )
          : '';
      return LeadExtractionResult(
        summary: summary,
        items: normalizeLeadItems(parsed),
      );
    } catch (_) {
      return const LeadExtractionResult();
    }
  }
}
