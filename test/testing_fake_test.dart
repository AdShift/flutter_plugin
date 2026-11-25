import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:adshift_flutter_sdk/src/native_sdk_versions.dart';
import 'package:adshift_flutter_sdk/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AdshiftFake fake;

  setUp(() => fake = AdshiftFake());

  test('takes the place of the SDK', () {
    final real = Adshift.instance;
    addTearDown(() => Adshift.instance = real);

    Adshift.instance = fake;

    expect(Adshift.instance, same(fake));
  });

  test('follows start and stop', () async {
    expect(fake.isStarted, isFalse);

    final result = await fake.start();
    expect(result.success, isTrue);
    expect(
      result.apiKeyValidationStatus,
      AdshiftApiKeyValidationStatus.pending,
    );
    expect(fake.isStarted, isTrue);

    fake.stop();
    expect(fake.isStarted, isFalse);
  });

  test('delivers an emitted deep link to the listeners of that moment', () {
    final seen = <AdshiftDeepLink>[];
    final subscription = fake.onDeepLink.listen(seen.add);

    const link = AdshiftDeepLink.found(deepLink: 'https://x');
    fake.emitDeepLink(link);
    expect(seen, [same(link)]);

    subscription.cancel();
    fake.emitDeepLink(const AdshiftDeepLink.notFound());
    expect(seen, hasLength(1));
  });

  test('answers the rest of the API with usable defaults', () async {
    expect((await fake.trackEvent('e')).success, isTrue);
    expect(
      (await fake.trackPurchase(
        productId: 'p',
        revenue: 1,
        currency: 'USD',
        transactionId: 't',
      )).success,
      isTrue,
    );
    expect(
      (await fake.logAdRevenue(
        monetizationNetwork: 'admob',
        mediationNetwork: AdshiftMediationNetwork.googleAdMob,
        currency: 'USD',
        revenue: 0.01,
      )).success,
      isTrue,
    );
    expect(await fake.getAdShiftDeviceId(), 'fake-device-id');
    expect(await fake.handlePushNotification({}), isFalse);
    await fake.handleDeepLink(Uri.parse('https://x'));

    final snapshot = (await fake.refreshConsent())!;
    expect(snapshot.source, AdshiftConsentSource.none);
    expect(snapshot.adIdentifiersAllowed, isTrue);

    final info = fake.getInfo();
    expect(info.version, adshiftPluginVersion);
    expect(info.androidSdkVersion, androidSdkVersion);
    expect(info.iosSdkVersion, iosSdkVersion);
  });

  test('answers with what the test sets', () async {
    const error = AdshiftError(AdshiftErrorCode.optedOut, 'off');
    fake
      ..startResult = const AdshiftStartResult.failure(error)
      ..trackingResult = const AdshiftResult.failure(error)
      ..consentSnapshot = null
      ..deviceId = null
      ..pushNotificationResult = true;

    expect((await fake.start()).error, same(error));
    expect(fake.isStarted, isFalse);
    expect((await fake.trackEvent('e')).error, same(error));
    expect(await fake.refreshConsent(), isNull);
    expect(await fake.getAdShiftDeviceId(), isNull);
    expect(await fake.handlePushNotification({}), isTrue);
  });

  test('records every call with its arguments, in order', () async {
    const config = AdshiftConfig(apiKey: 'k');
    const consent = AdshiftConsent.forNonGDPRUser();
    const sharing = AdshiftThirdPartySharing.optedOut();
    final url = Uri.parse('https://x');

    fake
      ..initialize(config)
      ..setCustomerUserId('user-1')
      ..setDebugEnabled(true)
      ..setAppOpenDebounceMs(5000)
      ..setBrandedDomains(['links.example.com'])
      ..setMetaAppId('meta-1')
      ..setOaidData('oaid-1')
      ..setConsentData(consent)
      ..enableTCFDataCollection(true)
      ..enableGPPDataCollection(false)
      ..setThirdPartySharing(sharing)
      ..clearThirdPartySharing()
      ..addPushNotificationDeepLinkPath(['data', 'link'])
      ..handlePastedDeepLink(null)
      ..getInfo();
    await fake.start();
    await fake.refreshConsent();
    await fake.trackEvent('e', values: {'a': 1});
    await fake.trackPurchase(
      productId: 'p',
      revenue: 1,
      currency: 'USD',
      transactionId: 't',
    );
    await fake.logAdRevenue(
      monetizationNetwork: 'admob',
      mediationNetwork: AdshiftMediationNetwork.unity,
      currency: 'USD',
      revenue: 0.01,
      adUnitId: 'unit',
    );
    await fake.getAdShiftDeviceId();
    await fake.handleDeepLink(url);
    await fake.handlePushNotification({'as_push_link': 'x'});
    fake.stop();

    expect(
      {for (final call in fake.calls) call.method: call.arguments},
      {
        'initialize': {'config': config},
        'setCustomerUserId': {'userId': 'user-1'},
        'setDebugEnabled': {'enabled': true},
        'setAppOpenDebounceMs': {'ms': 5000},
        'setBrandedDomains': {
          'domains': ['links.example.com'],
        },
        'setMetaAppId': {'appId': 'meta-1'},
        'setOaidData': {'oaid': 'oaid-1'},
        'setConsentData': {'consent': consent},
        'enableTCFDataCollection': {'enabled': true},
        'enableGPPDataCollection': {'enabled': false},
        'setThirdPartySharing': {'sharing': sharing},
        'clearThirdPartySharing': <String, Object?>{},
        'addPushNotificationDeepLinkPath': {
          'path': ['data', 'link'],
        },
        'handlePastedDeepLink': {'url': null},
        'getInfo': <String, Object?>{},
        'start': <String, Object?>{},
        'refreshConsent': <String, Object?>{},
        'trackEvent': {
          'eventName': 'e',
          'values': {'a': 1},
        },
        'trackPurchase': {
          'productId': 'p',
          'revenue': 1.0,
          'currency': 'USD',
          'transactionId': 't',
        },
        'logAdRevenue': {
          'monetizationNetwork': 'admob',
          'mediationNetwork': AdshiftMediationNetwork.unity,
          'currency': 'USD',
          'revenue': 0.01,
          'adUnitId': 'unit',
          'precision': null,
          'additionalParameters': null,
        },
        'getAdShiftDeviceId': <String, Object?>{},
        'handleDeepLink': {'url': url},
        'handlePushNotification': {
          'payload': {'as_push_link': 'x'},
        },
        'stop': <String, Object?>{},
      },
    );
    expect(fake.calls.map((call) => call.method).take(3), [
      'initialize',
      'setCustomerUserId',
      'setDebugEnabled',
    ]);
    expect(fake.calls, hasLength(24));
    expect('${fake.calls.last}', 'AdshiftFakeCall(stop, {})');
  });

  test('reset returns it to its state at creation', () async {
    var done = false;
    final seen = <AdshiftDeepLink>[];
    fake.onDeepLink.listen(seen.add, onDone: () => done = true);
    fake
      ..startResult = const AdshiftStartResult.success()
      ..trackingResult = const AdshiftResult.failure(
        AdshiftError(AdshiftErrorCode.unknown, 'nope'),
      )
      ..consentSnapshot = null
      ..deviceId = 'other'
      ..pushNotificationResult = true;
    await fake.start();

    fake.reset();
    await pumpEventQueue();

    expect(done, isTrue);
    expect(fake.calls, isEmpty);
    expect(fake.isStarted, isFalse);
    expect((await fake.trackEvent('e')).success, isTrue);
    expect(
      (await fake.start()).apiKeyValidationStatus,
      AdshiftApiKeyValidationStatus.pending,
    );
    expect(await fake.refreshConsent(), isNotNull);
    expect(await fake.getAdShiftDeviceId(), 'fake-device-id');
    expect(await fake.handlePushNotification({}), isFalse);

    fake.emitDeepLink(const AdshiftDeepLink.notFound());
    expect(seen, isEmpty);
    fake.onDeepLink.listen(seen.add);
    fake.emitDeepLink(const AdshiftDeepLink.notFound());
    expect(seen, hasLength(1));
  });
}
