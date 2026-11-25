import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Runs on a device or simulator: `flutter test integration_test`.
/// The SDK is never started here, so nothing is sent.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the plugin answers through the platform bridge', (tester) async {
    final adshift = Adshift.instance;
    final errors = <AdshiftError>[];
    final links = <AdshiftDeepLink>[];
    final subscription = adshift.onDeepLink.listen(links.add);
    addTearDown(subscription.cancel);

    adshift.initialize(
      AdshiftConfig(
        apiKey: 'integration-test',
        testMode: true,
        autoHandleDeepLinks: false,
        onError: errors.add,
      ),
    );
    adshift.setCustomerUserId('user-1');
    adshift.setConsentData(
      const AdshiftConsent.forGDPRUser(
        hasConsentForDataUsage: true,
        hasConsentForAdStorage: true,
      ),
    );

    final snapshot = await adshift.refreshConsent();
    expect(snapshot?.source, AdshiftConsentSource.manual);
    expect(snapshot?.adStorageEnabled, isTrue);
    // A flag the app left undecided: Android reports it as such, iOS as denied.
    expect(
      snapshot?.adPersonalizationEnabled,
      defaultTargetPlatform == TargetPlatform.iOS ? isFalse : isNull,
    );
    expect(snapshot?.adIdentifiersAllowed, isTrue);

    expect(await adshift.getAdShiftDeviceId(), isNotEmpty);

    final ownLink = Uri.parse('https://example.org/not-an-adshift-link');
    await adshift.handleDeepLink(ownLink);
    for (var i = 0; i < 50 && links.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(links, hasLength(1));
    expect(links.single.status, AdshiftDeepLinkStatus.notFound);
    expect(links.single.deepLink, '$ownLink');

    expect(
      await adshift.handlePushNotification({'title': 'no link here'}),
      isFalse,
    );
    expect(adshift.isStarted, isFalse);
    expect(errors, isEmpty);
  });
}
