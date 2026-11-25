import 'adshift_impl.dart';
import 'models/adshift_config.dart';
import 'models/adshift_consent.dart';
import 'models/adshift_consent_snapshot.dart';
import 'models/adshift_deep_link.dart';
import 'models/adshift_info.dart';
import 'models/adshift_mediation_network.dart';
import 'models/adshift_result.dart';
import 'models/adshift_third_party_sharing.dart';

/// The AdShift SDK. Use it through [Adshift.instance].
///
/// No member throws and no returned future completes with an error. A call
/// the SDK declines answers with an error in its result, or with an empty
/// answer and a report to [AdshiftConfig.onError].
///
/// Settings made before [initialize] are kept and applied by it.
///
/// The SDK belongs to the Flutter engine that shows the app. In any other
/// engine, such as a background message handler, [initialize] is refused and
/// [start] answers `NOT_INITIALIZED`.
abstract interface class Adshift {
  static Adshift? _instance;

  /// The SDK of this app.
  static Adshift get instance => _instance ??= createAdshift();

  /// Replaces the SDK, for a test: `Adshift.instance = AdshiftFake()`.
  static set instance(Adshift value) => _instance = value;

  /// Sets the SDK up. Call it once, as early as possible; the first config is
  /// kept and later calls are ignored. An unusable config is reported through
  /// [AdshiftConfig.onError] and returned by [start].
  void initialize(AdshiftConfig config);

  /// Starts measurement; call it on every launch. Tracking calls made earlier
  /// wait for it. On Android the answer can take up to 5 seconds, so do not
  /// await it before the first frame.
  Future<AdshiftStartResult> start();

  /// Stops measurement until the next [start]. Tracking calls made meanwhile
  /// answer `NOT_STARTED`.
  void stop();

  /// Whether [start] has succeeded and [stop] has not been called since.
  bool get isStarted;

  /// The versions of this plugin and of the native SDKs it is built on.
  AdshiftInfo getInfo();

  /// Sets your own user id; may be called at any time, also before
  /// [initialize]. Set it on every launch.
  void setCustomerUserId(String userId);

  /// Turns verbose SDK logging on or off.
  void setDebugEnabled(bool enabled);

  /// Sets the debounce interval for automatic `app_open` events, in
  /// milliseconds.
  void setAppOpenDebounceMs(int ms);

  /// Sets your own link domains. Call it before [initialize], or use
  /// [AdshiftConfig.brandedDomains]: the link that opened the app is read
  /// during [initialize].
  void setBrandedDomains(List<String> domains);

  /// Sets the Meta app id used to parse Meta App Links. Does nothing on iOS.
  void setMetaAppId(String appId);

  /// Passes an OAID the app obtained itself, for Android devices without
  /// Google Play services; set [AdshiftConfig.collectOaid] to false as well.
  /// Does nothing on iOS.
  void setOaidData(String oaid);

  /// Passes consent collected by your own UI. Call it on every launch, before
  /// [start].
  void setConsentData(AdshiftConsent consent);

  /// Reads IAB TCF v2.2 consent from the consent platform on the device. Call
  /// it before [start].
  void enableTCFDataCollection(bool enabled);

  /// Reads an IAB GPP string written by the consent platform, for US state
  /// privacy signals. Call it before [start].
  void enableGPPDataCollection(bool enabled);

  /// Passes the user's answer on sharing their data with advertising partners.
  /// Call it only once the user was asked: events already sent are not
  /// recalled.
  void setThirdPartySharing(AdshiftThirdPartySharing sharing);

  /// Withdraws [setThirdPartySharing]: later events say nothing about sharing,
  /// which is not the same as [AdshiftThirdPartySharing.allowed].
  void clearThirdPartySharing();

  /// Reads consent again and returns it as the SDK applies it; call it after
  /// the consent dialog closes. Null before [initialize].
  Future<AdshiftConsentSnapshot?> refreshConsent();

  /// Tracks an event. [values] may hold strings, numbers and booleans; use
  /// `AdshiftEventParam` names for values reports should count. The names
  /// `app_install` and `app_open` are reserved.
  Future<AdshiftResult> trackEvent(
    String eventName, {
    Map<String, Object>? values,
  });

  /// Tracks a purchase of [revenue] in [currency] (an ISO 4217 code).
  /// [transactionId] is the transaction id or purchase token.
  Future<AdshiftResult> trackPurchase({
    required String productId,
    required double revenue,
    required String currency,
    required String transactionId,
  });

  /// Tracks the revenue of a single ad impression, not an aggregate.
  /// [monetizationNetwork] is the ad network that served it, e.g. `admob`;
  /// [currency] an ISO 4217 code; [precision] what the network reported, e.g.
  /// `exact`. On iOS the keys `revenue`, `value` and `currency` in
  /// [additionalParameters] are ignored. A successful answer means the record
  /// was handed to the SDK, which gives no verdict on ad revenue.
  Future<AdshiftResult> logAdRevenue({
    required String monetizationNetwork,
    required AdshiftMediationNetwork mediationNetwork,
    required String currency,
    required double revenue,
    String? adUnitId,
    String? precision,
    Map<String, Object>? additionalParameters,
  });

  /// The AdShift id of this device, for connecting other tools to AdShift.
  /// Null before [initialize].
  Future<String?> getAdShiftDeviceId();

  /// Passes a link to the SDK; not needed while
  /// [AdshiftConfig.autoHandleDeepLinks] is on. Completes at once; the result
  /// arrives through [onDeepLink]. A link the plugin already passed to the SDK
  /// when it arrived from the system is not counted again.
  Future<void> handleDeepLink(Uri url);

  /// With [AdshiftDeferredDeepLinkClipboard.pasteControl], passes what the
  /// user pasted, or null when they skipped it. Call it on every way out of
  /// onboarding: the deferred deep link of the first launch waits for it.
  /// Does nothing on Android.
  void handlePastedDeepLink(Uri? url);

  /// Adds a key path inside push payloads that carries an AdShift deep link.
  /// Call it before [initialize], or use [AdshiftConfig.pushDeepLinkPaths]: a
  /// notification that opened the app is read during [initialize]. The first
  /// path replaces the top-level `as_push_link` the SDK reads by default, so
  /// add that one too if you still use it. A path that leads through a JSON
  /// string works on Android only.
  void addPushNotificationDeepLinkPath(List<String> path);

  /// Passes the payload of a push notification the user tapped. Answers true
  /// when it carried an AdShift deep link; the result then arrives through
  /// [onDeepLink]. A notification the plugin already passed to the SDK when it
  /// arrived from the system is not counted again.
  Future<bool> handlePushNotification(Map<String, Object?> payload);

  /// Every deep link that reaches the SDK (direct, deferred, push), delivered
  /// once. Listen before or after [initialize]; results that arrive while
  /// nobody listens wait for the first listener.
  Stream<AdshiftDeepLink> get onDeepLink;
}
