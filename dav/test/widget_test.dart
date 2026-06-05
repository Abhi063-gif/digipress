import 'package:flutter_test/flutter_test.dart';
import 'package:digipress/main.dart';

void main() {
  testWidgets('DigiPress app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const DigiPressApp());
    // Verify the app renders (login or main shell depending on session)
    await tester.pumpAndSettle();
  });
}
