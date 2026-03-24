import 'package:flutter_test/flutter_test.dart';
import 'package:sample_app/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const CardioScanApp());
    expect(find.text('CardioScan'), findsOneWidget);
  });
}
