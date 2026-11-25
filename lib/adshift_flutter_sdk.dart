/// AdShift SDK for Flutter: attribution, in-app events, deep links, SKAdNetwork
/// and consent.
///
/// ```dart
/// Adshift.instance.initialize(const AdshiftConfig(apiKey: 'YOUR_API_KEY'));
/// Adshift.instance.onDeepLink.listen((link) {
///   if (link.status == AdshiftDeepLinkStatus.found) {
///     // Navigate on link.deepLinkValue.
///   }
/// });
/// Adshift.instance.start();
///
/// await Adshift.instance.trackEvent(
///   AdshiftEventType.purchase,
///   values: {AdshiftEventParam.revenue: 9.99, AdshiftEventParam.currency: 'USD'},
/// );
/// ```
///
/// For your own tests, `package:adshift_flutter_sdk/testing.dart` has a fake.
library;

export 'src/adshift.dart' show Adshift;
export 'src/models/adshift_config.dart'
    show AdshiftConfig, AdshiftDeferredDeepLinkClipboard;
export 'src/models/adshift_consent.dart' show AdshiftConsent;
export 'src/models/adshift_consent_snapshot.dart'
    show AdshiftConsentSnapshot, AdshiftConsentSource;
export 'src/models/adshift_deep_link.dart'
    show AdshiftDeepLink, AdshiftDeepLinkSource, AdshiftDeepLinkStatus;
export 'src/models/adshift_error.dart' show AdshiftError, AdshiftErrorCode;
export 'src/models/adshift_event_param.dart' show AdshiftEventParam;
export 'src/models/adshift_event_type.dart' show AdshiftEventType;
export 'src/models/adshift_info.dart' show AdshiftInfo;
export 'src/models/adshift_mediation_network.dart' show AdshiftMediationNetwork;
export 'src/models/adshift_result.dart'
    show AdshiftApiKeyValidationStatus, AdshiftResult, AdshiftStartResult;
export 'src/models/adshift_third_party_sharing.dart'
    show AdshiftThirdPartySharing;
export 'src/version.dart' show adshiftPluginVersion;
