import 'package:flutter_test/flutter_test.dart';

import 'package:leadtrace/pages/leads_page.dart';

void main() {
  test('LeadsPage skips decrypt gate and enables quiet auto-refresh by default', () {
    const page = LeadsPage();
    expect(page.autoRefresh, isTrue);
    expect(page.store, isNull);
  });

  test('LeadsPage can disable auto-refresh for tests', () {
    const page = LeadsPage(autoRefresh: false);
    expect(page.autoRefresh, isFalse);
  });
}
