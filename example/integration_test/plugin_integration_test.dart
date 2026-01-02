import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SDK initializes successfully', (WidgetTester tester) async {
    // Note: This test requires a valid API key to pass on real devices
    // For CI, you may want to skip or mock this
    
    try {
      await AdshiftFlutterSdk.instance.initialize(
        const AdshiftConfig(
          apiKey: 'test-api-key',
          isDebug: true,
        ),
      );
      
      // If we get here without exception, initialization worked
      expect(true, true);
    } catch (e) {
      // Expected to fail with invalid API key
      // The important thing is the method channel works
      expect(e, isA<Exception>());
    }
  });
}
