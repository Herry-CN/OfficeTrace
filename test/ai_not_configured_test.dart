import 'package:flutter_test/flutter_test.dart';

import 'package:leadtrace/services/lead/ai_client_service.dart';

void main() {
  test('AiNotConfiguredException toString has no Exception prefix', () {
    final e = AiNotConfiguredException();
    expect(e.toString(), contains('AI 未就绪'));
    expect(e.toString(), isNot(contains('Exception:')));
  });
}
