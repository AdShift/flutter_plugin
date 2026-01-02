import 'package:flutter_test/flutter_test.dart';
import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:adshift_flutter_sdk/src/adshift_sdk_platform_interface.dart';
import 'package:adshift_flutter_sdk/src/adshift_sdk_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockAdshiftSdkPlatform
    with MockPlatformInterfaceMixin
    implements AdshiftSdkPlatform {
  
  bool _initialized = false;
  bool _started = false;

  @override
  Future<void> initialize(AdshiftConfig config) async {
    _initialized = true;
  }

  @override
  Future<void> start() async {
    _started = true;
  }

  @override
  Future<void> stop() async {
    _started = false;
  }

  @override
  Future<bool> isStarted() async => _started;

  @override
  Future<void> setDebugEnabled(bool enabled) async {}

  @override
  Future<void> setCustomerUserId(String userId) async {}

  @override
  Future<void> setAppOpenDebounceMs(int ms) async {}

  @override
  Future<void> trackEvent(String eventName, Map<String, dynamic>? values) async {}

  @override
  Future<void> trackPurchase({
    required String productId,
    required double revenue,
    required String currency,
    required String transactionId,
  }) async {}

  @override
  Future<void> setConsentData(AdshiftConsent consent) async {}

  @override
  Future<void> enableTCFDataCollection(bool enabled) async {}

  @override
  Future<void> refreshConsent() async {}

  @override
  Future<AdshiftDeepLink> handleDeepLink(String url) async {
    return AdshiftDeepLink.notFound();
  }

  @override
  Stream<AdshiftDeepLink> get onDeepLinkReceived => const Stream.empty();
}

void main() {
  final AdshiftSdkPlatform initialPlatform = AdshiftSdkPlatform.instance;

  test('$MethodChannelAdshiftSdk is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelAdshiftSdk>());
  });

  group('AdshiftFlutterSdk', () {
    late MockAdshiftSdkPlatform mockPlatform;

    setUp(() {
      mockPlatform = MockAdshiftSdkPlatform();
      AdshiftSdkPlatform.instance = mockPlatform;
    });

    test('initialize sets up SDK', () async {
      await AdshiftFlutterSdk.instance.initialize(
        const AdshiftConfig(apiKey: 'test-key'),
      );
      expect(mockPlatform._initialized, true);
    });

    test('start begins tracking', () async {
      await AdshiftFlutterSdk.instance.initialize(
        const AdshiftConfig(apiKey: 'test-key'),
      );
      await AdshiftFlutterSdk.instance.start();
      expect(await AdshiftFlutterSdk.instance.isStarted(), true);
    });

    test('stop pauses tracking', () async {
      await AdshiftFlutterSdk.instance.initialize(
        const AdshiftConfig(apiKey: 'test-key'),
      );
      await AdshiftFlutterSdk.instance.start();
      await AdshiftFlutterSdk.instance.stop();
      expect(await AdshiftFlutterSdk.instance.isStarted(), false);
    });
  });

  group('AdshiftConsent', () {
    test('forGDPRUser creates correct consent', () {
      final consent = AdshiftConsent.forGDPRUser(
        hasConsentForDataUsage: true,
        hasConsentForAdsPersonalization: true,
        hasConsentForAdStorage: true,
      );
      expect(consent.isUserSubjectToGDPR, true);
      expect(consent.isConsentGranted(), true);
    });

    test('forNonGDPRUser creates correct consent', () {
      final consent = AdshiftConsent.forNonGDPRUser();
      expect(consent.isUserSubjectToGDPR, false);
      expect(consent.isConsentGranted(), true);
    });

    test('GDPR user without consent is not granted', () {
      final consent = AdshiftConsent.forGDPRUser(
        hasConsentForDataUsage: false,
        hasConsentForAdsPersonalization: true,
        hasConsentForAdStorage: true,
      );
      expect(consent.isConsentGranted(), false);
    });
  });

  group('AdshiftDeepLink', () {
    test('fromMap parses correctly', () {
      final map = {
        'deepLink': 'https://example.com/product/123',
        'params': {'product_id': '123'},
        'isDeferred': true,
        'status': 'found',
      };
      final deepLink = AdshiftDeepLink.fromMap(map);
      expect(deepLink.deepLink, 'https://example.com/product/123');
      expect(deepLink.params?['product_id'], '123');
      expect(deepLink.isDeferred, true);
      expect(deepLink.status, AdshiftDeepLinkStatus.found);
    });

    test('notFound factory works', () {
      final deepLink = AdshiftDeepLink.notFound();
      expect(deepLink.status, AdshiftDeepLinkStatus.notFound);
      expect(deepLink.deepLink, null);
    });
  });

  group('AdshiftConfig', () {
    test('toMap includes all fields', () {
      const config = AdshiftConfig(
        apiKey: 'test-key',
        isDebug: true,
        appOpenDebounceMs: 5000,
        disableSKAN: true,
        collectOaid: false,
      );
      final map = config.toMap();
      expect(map['apiKey'], 'test-key');
      expect(map['isDebug'], true);
      expect(map['appOpenDebounceMs'], 5000);
      expect(map['disableSKAN'], true);
      expect(map['collectOaid'], false);
    });

    test('toMap excludes null optional fields', () {
      const config = AdshiftConfig(apiKey: 'test-key');
      final map = config.toMap();
      expect(map.containsKey('disableSKAN'), false);
      expect(map.containsKey('collectOaid'), false);
    });
  });
}
