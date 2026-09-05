import 'package:flutter_test/flutter_test.dart';
import 'package:leadtrace/services/lead/ai_client_service.dart';

void main() {
  group('AiClientService JSON helpers', () {
    test('parseJsonResponse handles fenced json', () {
      const raw = '''```json
{"label":"recruitment","confidence":0.9,"shouldExtract":true,"summary":"招聘"}
```''';
      final parsed = AiClientService.parseJsonResponse(raw);
      expect(parsed, isA<Map>());
      expect(parsed['label'], 'recruitment');
    });

    test('parseJsonResponse extracts embedded object', () {
      const raw = '结果如下：{"items":[{"title":"求购电脑","confidence":0.85}]} 完';
      final parsed = AiClientService.parseJsonResponse(raw);
      expect(parsed['items'], isA<List>());
    });

    test('normalizeLeadItems clamps confidence and filters empty titles', () {
      final items = AiClientService.normalizeLeadItems({
        'items': [
          {'title': '招聘顾问', 'confidence': 92, 'priority': 'urgent'},
          {'title': '  ', 'confidence': 0.5},
          {'title': '找专家', 'confidence': 0.8, 'priority': 'high'},
        ],
      });
      expect(items.length, 2);
      expect(items.first['confidence'], closeTo(0.92, 0.001));
      expect(items.first['priority'], 'medium');
      expect(items.last['priority'], 'high');
    });
  });
}
