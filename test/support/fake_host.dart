import 'package:adshift_flutter_sdk/src/messages.g.dart';

/// The platform side of the bridge, for tests: records every call and answers
/// with what the test set.
class FakeHost extends AdshiftHostApi {
  /// Every call in order, each as `[method, ...arguments]`.
  final List<List<Object?>> calls = [];

  /// When set, every call fails with it.
  Object? failure;

  /// Whether [failure] is thrown by the call itself instead of its future.
  bool failSynchronously = false;

  Future<ErrorMessage?> Function() onInitialize = () async => null;
  Future<StartMessage> Function() onStart = () async =>
      StartMessage(success: true, keyStatus: KeyStatusMessage.pending);
  Future<ErrorMessage?> Function() onTrack = () async => null;
  Future<ErrorMessage?> Function() onHandleDeepLink = () async => null;
  ConsentSnapshotMessage? consentSnapshot = ConsentSnapshotMessage(
    source: ConsentSourceMessage.manual,
    tcStringPresent: false,
    cmpDetected: false,
    appliedAtMillis: 1,
    adIdentifiersAllowed: true,
    adStorageEnabled: true,
  );
  String? deviceId = 'device-1';
  bool pushNotificationResult = true;

  List<Object?> get methods => [for (final call in calls) call.first];

  /// The argument lists of every call to [method].
  List<List<Object?>> argumentsOf(String method) => [
    for (final call in calls)
      if (call.first == method) call.sublist(1),
  ];

  int count(String method) => argumentsOf(method).length;

  Future<T> _answer<T>(
    String method,
    List<Object?> arguments,
    Future<T> Function() answer,
  ) {
    calls.add([method, ...arguments]);
    final failure = this.failure;
    if (failure == null) return answer();
    if (failSynchronously) throw failure;
    return Future<T>.error(failure);
  }

  Future<void> _done(String method, [List<Object?> arguments = const []]) =>
      _answer(method, arguments, () async {});

  @override
  Future<ErrorMessage?> initialize(InitializeMessage options) =>
      _answer('initialize', [options], onInitialize);

  @override
  Future<StartMessage> start() => _answer('start', const [], onStart);

  @override
  Future<void> stop() => _done('stop');

  @override
  Future<void> setCustomerUserId(String userId) =>
      _done('setCustomerUserId', [userId]);

  @override
  Future<void> setDebugEnabled(bool enabled) =>
      _done('setDebugEnabled', [enabled]);

  @override
  Future<void> setAppOpenDebounceMs(int ms) =>
      _done('setAppOpenDebounceMs', [ms]);

  @override
  Future<void> setBrandedDomains(List<String> domains) =>
      _done('setBrandedDomains', [domains]);

  @override
  Future<void> setMetaAppId(String appId) => _done('setMetaAppId', [appId]);

  @override
  Future<void> setOaidData(String oaid) => _done('setOaidData', [oaid]);

  @override
  Future<void> setConsentData(ConsentMessage consent) =>
      _done('setConsentData', [consent]);

  @override
  Future<void> enableTcfDataCollection(bool enabled) =>
      _done('enableTcfDataCollection', [enabled]);

  @override
  Future<void> enableGppDataCollection(bool enabled) =>
      _done('enableGppDataCollection', [enabled]);

  @override
  Future<void> setThirdPartySharing(bool optOut) =>
      _done('setThirdPartySharing', [optOut]);

  @override
  Future<void> clearThirdPartySharing() => _done('clearThirdPartySharing');

  @override
  Future<ConsentSnapshotMessage?> refreshConsent() =>
      _answer('refreshConsent', const [], () async => consentSnapshot);

  @override
  Future<ErrorMessage?> trackEvent(String name, Map<String, Object?> values) =>
      _answer('trackEvent', [name, values], onTrack);

  @override
  Future<ErrorMessage?> trackPurchase(
    String productId,
    double price,
    String currency,
    String token,
  ) => _answer('trackPurchase', [productId, price, currency, token], onTrack);

  @override
  Future<ErrorMessage?> logAdRevenue(AdRevenueMessage data) =>
      _answer('logAdRevenue', [data], onTrack);

  @override
  Future<String?> getAdShiftDeviceId() =>
      _answer('getAdShiftDeviceId', const [], () async => deviceId);

  @override
  Future<ErrorMessage?> handleDeepLink(String url) =>
      _answer('handleDeepLink', [url], onHandleDeepLink);

  @override
  Future<void> handlePastedDeepLink(String? url) =>
      _done('handlePastedDeepLink', [url]);

  @override
  Future<void> addPushNotificationDeepLinkPath(List<String> path) =>
      _done('addPushNotificationDeepLinkPath', [path]);

  @override
  Future<bool> handlePushNotification(Map<String, Object?> payload) => _answer(
    'handlePushNotification',
    [payload],
    () async => pushNotificationResult,
  );

  @override
  Future<void> deepLinkListenerReady() => _done('deepLinkListenerReady');
}
