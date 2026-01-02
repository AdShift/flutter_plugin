import 'package:flutter_test/flutter_test.dart';

import 'package:adshift_flutter_sdk_example/main.dart';

void main() {
  testWidgets('App renders correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AdShiftExampleApp());

    // Verify that the app title is displayed
    expect(find.text('AdShift SDK Demo'), findsOneWidget);

    // Verify SDK status card is displayed
    expect(find.text('SDK Not Initialized'), findsOneWidget);
  });
}
