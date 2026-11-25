// The bridge contract. Run `dart run pigeon --input pigeon/messages.dart`
// after any change; the three generated files are committed.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartPackageName: 'adshift_flutter_sdk',
    dartOut: 'lib/src/messages.g.dart',
    kotlinOut:
        'android/src/main/kotlin/com/adshift/adshift_flutter_sdk/Messages.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.adshift.adshift_flutter_sdk'),
    swiftOut: [
      'ios/adshift_flutter_sdk/Sources/adshift_flutter_sdk/Messages.g.swift',
    ],
  ),
)
enum ErrorCodeMessage {
  notInitialized,
  notStarted,
  invalidApiKey,
  optedOut,
  queueFull,
  invalidArgument,
  unknown,
}

enum KeyStatusMessage { pending, valid, invalid }

enum ClipboardModeMessage { disabled, prompt, pasteControl }

enum DeepLinkStatusMessage { found, notFound, error }

enum DeepLinkSourceMessage {
  universalLink,
  appLink,
  scheme,
  cta,
  push,
  adAttributionKit,
  metaAppLink,
  deferred,
  foreign,
}

enum ConsentSourceMessage { manual, tcf, gpp, none }

/// Options of `initialize`. A null field keeps the native SDK default.
class InitializeMessage {
  InitializeMessage({required this.apiKey});

  String apiKey;
  bool? isDebug;
  int? appOpenDebounceMs;
  List<String>? brandedDomains;
  bool? testMode;
  String? metaAppId;
  List<List<String>>? pushDeepLinkPaths;
  bool? autoHandleDeepLinks;
  bool? disableSkan;
  bool? waitForAttBeforeStart;
  int? attTimeoutMs;
  ClipboardModeMessage? deferredDeepLinkClipboard;
  bool? collectOaid;
}

/// Why a call did not go through. `nativeCode` and `nativeDomain` carry what
/// the platform reported, when it reported anything.
class ErrorMessage {
  ErrorMessage({required this.code, required this.message});

  ErrorCodeMessage code;
  String message;
  String? nativeCode;
  String? nativeDomain;
}

class StartMessage {
  StartMessage({required this.success});

  bool success;
  KeyStatusMessage? keyStatus;
  ErrorMessage? error;
}

class ConsentMessage {
  ConsentMessage({required this.isUserSubjectToGdpr});

  bool isUserSubjectToGdpr;
  bool? hasConsentForDataUsage;
  bool? hasConsentForAdsPersonalization;
  bool? hasConsentForAdStorage;
}

class ConsentSnapshotMessage {
  ConsentSnapshotMessage({
    required this.source,
    required this.tcStringPresent,
    required this.cmpDetected,
    required this.appliedAtMillis,
    required this.adIdentifiersAllowed,
  });

  ConsentSourceMessage source;
  int? gdprApplies;
  bool tcStringPresent;
  bool? gppPresent;
  bool cmpDetected;
  bool? adUserDataEnabled;
  bool? adPersonalizationEnabled;
  bool? adStorageEnabled;
  int appliedAtMillis;
  bool adIdentifiersAllowed;
}

class AdRevenueMessage {
  AdRevenueMessage({
    required this.monetizationNetwork,
    required this.mediationNetwork,
    required this.currency,
    required this.revenue,
  });

  String monetizationNetwork;
  String mediationNetwork;
  String currency;
  double revenue;
  String? adUnitId;
  String? precision;
  Map<String, Object?>? additionalParameters;
}

class DeepLinkMessage {
  DeepLinkMessage({required this.status, required this.isDeferred});

  DeepLinkStatusMessage status;
  bool isDeferred;
  String? deepLink;
  String? deepLinkValue;
  Map<String, String>? params;
  String? errorMessage;
  DeepLinkSourceMessage? source;
  String? clickId;
  bool? matchGuaranteed;
  bool? isFirstSession;
  String? sub1;
  String? sub2;
  String? sub3;
  String? sub4;
  String? sub5;
}

/// Dart to native. A returned [ErrorMessage] of null means the call went
/// through; no method reports a failure by throwing.
@HostApi()
abstract class AdshiftHostApi {
  ErrorMessage? initialize(InitializeMessage options);

  @async
  StartMessage start();

  void stop();

  void setCustomerUserId(String userId);
  void setDebugEnabled(bool enabled);
  void setAppOpenDebounceMs(int ms);
  void setBrandedDomains(List<String> domains);
  void setMetaAppId(String appId);
  void setOaidData(String oaid);

  void setConsentData(ConsentMessage consent);
  void enableTcfDataCollection(bool enabled);
  void enableGppDataCollection(bool enabled);
  void setThirdPartySharing(bool optOut);
  void clearThirdPartySharing();

  @async
  ConsentSnapshotMessage? refreshConsent();

  @async
  ErrorMessage? trackEvent(String name, Map<String, Object?> values);

  @async
  ErrorMessage? trackPurchase(
    String productId,
    double price,
    String currency,
    String token,
  );

  @async
  ErrorMessage? logAdRevenue(AdRevenueMessage data);

  String? getAdShiftDeviceId();

  @async
  ErrorMessage? handleDeepLink(String url);

  void handlePastedDeepLink(String? url);
  void addPushNotificationDeepLinkPath(List<String> path);

  @async
  bool handlePushNotification(Map<String, Object?> payload);

  /// Dart listens from now on: results held on the native side are sent.
  void deepLinkListenerReady();
}

/// Native to Dart.
@FlutterApi()
abstract class AdshiftFlutterApi {
  void onDeepLink(DeepLinkMessage link);
}
