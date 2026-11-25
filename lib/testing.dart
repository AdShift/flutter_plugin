/// A stand-in for the AdShift SDK in your own tests.
///
/// ```dart
/// final adshift = AdshiftFake();
/// Adshift.instance = adshift;
///
/// // Drive your deep link handling.
/// adshift.emitDeepLink(
///   const AdshiftDeepLink.found(deepLink: 'https://example.com/promo'),
/// );
///
/// // Check what your code sent.
/// expect(adshift.calls.map((call) => call.method), contains('trackEvent'));
/// ```
library;

import 'dart:async';

import 'adshift_flutter_sdk.dart';
import 'src/info.dart';

/// One call made on an [AdshiftFake].
final class AdshiftFakeCall {
  /// Creates the record of a call.
  const AdshiftFakeCall(this.method, [this.arguments = const {}]);

  /// Name of the method, e.g. `trackEvent`.
  final String method;

  /// The arguments by parameter name.
  final Map<String, Object?> arguments;

  @override
  String toString() => 'AdshiftFakeCall($method, $arguments)';
}

/// An [Adshift] that calls no native code. It records every call, answers
/// with the values set on it, and delivers the deep links a test emits. It
/// checks no arguments and holds no calls back until [start].
final class AdshiftFake implements Adshift {
  static const _defaultStartResult = AdshiftStartResult.success(
    apiKeyValidationStatus: AdshiftApiKeyValidationStatus.pending,
  );
  static const _defaultConsentSnapshot = AdshiftConsentSnapshot(
    source: AdshiftConsentSource.none,
    tcStringPresent: false,
    cmpDetected: false,
    appliedAtMillis: 0,
    adIdentifiersAllowed: true,
  );
  static const _defaultDeviceId = 'fake-device-id';

  /// What [start] answers.
  AdshiftStartResult startResult = _defaultStartResult;

  /// What [trackEvent], [trackPurchase] and [logAdRevenue] answer.
  AdshiftResult trackingResult = const AdshiftResult.success();

  /// What [refreshConsent] answers.
  AdshiftConsentSnapshot? consentSnapshot = _defaultConsentSnapshot;

  /// What [getAdShiftDeviceId] answers.
  String? deviceId = _defaultDeviceId;

  /// What [handlePushNotification] answers.
  bool pushNotificationResult = false;

  /// Every method call made on this fake, in order.
  final List<AdshiftFakeCall> calls = [];

  StreamController<AdshiftDeepLink> _deepLinks = _newDeepLinks();
  bool _started = false;

  static StreamController<AdshiftDeepLink> _newDeepLinks() =>
      StreamController<AdshiftDeepLink>.broadcast(sync: true);

  /// Delivers [link] to the current [onDeepLink] listeners, before returning.
  void emitDeepLink(AdshiftDeepLink link) => _deepLinks.add(link);

  /// Returns the fake to its state at creation: no listeners, not started, no
  /// recorded calls, the default answers.
  void reset() {
    unawaited(_deepLinks.close());
    _deepLinks = _newDeepLinks();
    _started = false;
    calls.clear();
    startResult = _defaultStartResult;
    trackingResult = const AdshiftResult.success();
    consentSnapshot = _defaultConsentSnapshot;
    deviceId = _defaultDeviceId;
    pushNotificationResult = false;
  }

  void _record(String method, [Map<String, Object?> arguments = const {}]) =>
      calls.add(AdshiftFakeCall(method, arguments));

  @override
  void initialize(AdshiftConfig config) =>
      _record('initialize', {'config': config});

  @override
  Future<AdshiftStartResult> start() async {
    _record('start');
    _started = startResult.success;
    return startResult;
  }

  @override
  void stop() {
    _record('stop');
    _started = false;
  }

  @override
  bool get isStarted => _started;

  @override
  AdshiftInfo getInfo() {
    _record('getInfo');
    return readInfo();
  }

  @override
  void setCustomerUserId(String userId) =>
      _record('setCustomerUserId', {'userId': userId});

  @override
  void setDebugEnabled(bool enabled) =>
      _record('setDebugEnabled', {'enabled': enabled});

  @override
  void setAppOpenDebounceMs(int ms) =>
      _record('setAppOpenDebounceMs', {'ms': ms});

  @override
  void setBrandedDomains(List<String> domains) =>
      _record('setBrandedDomains', {'domains': domains});

  @override
  void setMetaAppId(String appId) => _record('setMetaAppId', {'appId': appId});

  @override
  void setOaidData(String oaid) => _record('setOaidData', {'oaid': oaid});

  @override
  void setConsentData(AdshiftConsent consent) =>
      _record('setConsentData', {'consent': consent});

  @override
  void enableTCFDataCollection(bool enabled) =>
      _record('enableTCFDataCollection', {'enabled': enabled});

  @override
  void enableGPPDataCollection(bool enabled) =>
      _record('enableGPPDataCollection', {'enabled': enabled});

  @override
  void setThirdPartySharing(AdshiftThirdPartySharing sharing) =>
      _record('setThirdPartySharing', {'sharing': sharing});

  @override
  void clearThirdPartySharing() => _record('clearThirdPartySharing');

  @override
  Future<AdshiftConsentSnapshot?> refreshConsent() async {
    _record('refreshConsent');
    return consentSnapshot;
  }

  @override
  Future<AdshiftResult> trackEvent(
    String eventName, {
    Map<String, Object>? values,
  }) async {
    _record('trackEvent', {'eventName': eventName, 'values': values});
    return trackingResult;
  }

  @override
  Future<AdshiftResult> trackPurchase({
    required String productId,
    required double revenue,
    required String currency,
    required String transactionId,
  }) async {
    _record('trackPurchase', {
      'productId': productId,
      'revenue': revenue,
      'currency': currency,
      'transactionId': transactionId,
    });
    return trackingResult;
  }

  @override
  Future<AdshiftResult> logAdRevenue({
    required String monetizationNetwork,
    required AdshiftMediationNetwork mediationNetwork,
    required String currency,
    required double revenue,
    String? adUnitId,
    String? precision,
    Map<String, Object>? additionalParameters,
  }) async {
    _record('logAdRevenue', {
      'monetizationNetwork': monetizationNetwork,
      'mediationNetwork': mediationNetwork,
      'currency': currency,
      'revenue': revenue,
      'adUnitId': adUnitId,
      'precision': precision,
      'additionalParameters': additionalParameters,
    });
    return trackingResult;
  }

  @override
  Future<String?> getAdShiftDeviceId() async {
    _record('getAdShiftDeviceId');
    return deviceId;
  }

  @override
  Future<void> handleDeepLink(Uri url) async =>
      _record('handleDeepLink', {'url': url});

  @override
  void handlePastedDeepLink(Uri? url) =>
      _record('handlePastedDeepLink', {'url': url});

  @override
  void addPushNotificationDeepLinkPath(List<String> path) =>
      _record('addPushNotificationDeepLinkPath', {'path': path});

  @override
  Future<bool> handlePushNotification(Map<String, Object?> payload) async {
    _record('handlePushNotification', {'payload': payload});
    return pushNotificationResult;
  }

  @override
  Stream<AdshiftDeepLink> get onDeepLink => _deepLinks.stream;
}
