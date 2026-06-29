import 'package:flutter_test/flutter_test.dart';
import 'package:axus_mobile/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AxusApp());

    // Verify that our app bar text exists
    expect(find.text('AXUS'), findsOneWidget);
  });
}
