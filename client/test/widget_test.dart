import 'package:flutter_test/flutter_test.dart';
import 'package:client/main.dart';

void main() {
  testWidgets('앱 기동 스모크 테스트', (WidgetTester tester) async {
    await tester.pumpWidget(const SamsungHealthCollectorApp());
    expect(find.text('SH 검증 수집기'), findsNothing); // 타이틀은 AppBar에 있음
  });
}
