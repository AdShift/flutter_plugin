import 'dart:async';

import 'adshift_sdk_platform_interface.dart';
import 'models/adshift_config.dart';
import 'models/adshift_consent.dart';
import 'models/adshift_deeplink.dart';

/// Main AdShift SDK interface for Flutter.
///
/// Use the singleton [instance] to access SDK functionality.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
///
/// // 1. Initialize SDK
/// await AdshiftFlutterSdk.instance.initialize(
///   AdshiftConfig(
///     apiKey: 'your-api-key',
///     isDebug: true,
///   ),
/// );
///
/// // 2. Start tracking
/// await AdshiftFlutterSdk.instance.start();
///
/// // 3. Track events
/// await AdshiftFlutterSdk.instance.trackEvent(
///   AdshiftEventType.addToCart,
///   values: {'product_id': 'SKU123', 'price': 29.99},
/// );
///
/// // 4. Track purchases
/// await AdshiftFlutterSdk.instance.trackPurchase(
///   productId: 'SKU123',
///   revenue: 29.99,
///   currency: 'USD',
///   transactionId: 'TXN123',
/// );
/// ```
///
/// ## Deep Linking
///
/// ```dart
/// // Handle incoming deep links
/// final deepLink = await AdshiftFlutterSdk.instance.handleDeepLink(uri);
///
/// // Listen for deep link events
/// AdshiftFlutterSdk.instance.onDeepLinkReceived.listen((deepLink) {
///   if (deepLink.status == AdshiftDeepLinkStatus.found) {
///     // Handle deep link
///   }
/// });
/// ```
///
/// ## Consent (GDPR/DMA)
///
/// ```dart
/// // For GDPR users
/// await AdshiftFlutterSdk.instance.setConsentData(
///   AdshiftConsent.forGDPRUser(
///     hasConsentForDataUsage: true,
///     hasConsentForAdsPersonalization: true,
///     hasConsentForAdStorage: true,
///   ),
/// );
///
/// // For non-GDPR users
/// await AdshiftFlutterSdk.instance.setConsentData(
///   AdshiftConsent.forNonGDPRUser(),
/// );
/// ```
class AdshiftFlutterSdk {
  // Private constructor for singleton
  AdshiftFlutterSdk._();

  /// Singleton instance of the SDK.
  static final AdshiftFlutterSdk instance = AdshiftFlutterSdk._();

  /// Platform-specific implementation.
  AdshiftSdkPlatform get _platform => AdshiftSdkPlatform.instance;

  /// Whether SDK has been initialized.
  bool _isInitialized = false;

  // ============ Lifecycle ============

  /// Initializes the SDK with the given configuration.
  ///
  /// Must be called before any other SDK methods.
  ///
  /// Example:
  /// ```dart
  /// await AdshiftFlutterSdk.instance.initialize(
  ///   AdshiftConfig(
  ///     apiKey: 'your-api-key',
  ///     isDebug: true,
  ///   ),
  /// );
  /// ```
  ///
  /// Throws [Exception] if initialization fails.
  Future<void> initialize(AdshiftConfig config) async {
    await _platform.initialize(config);
    _isInitialized = true;
  }

  /// Starts the SDK.
  ///
  /// Call this after [initialize] to begin tracking.
  /// Typically called in your app's main initialization.
  ///
  /// Example:
  /// ```dart
  /// await AdshiftFlutterSdk.instance.start();
  /// ```
  Future<void> start() async {
    _checkInitialized();
    await _platform.start();
  }

  /// Stops the SDK.
  ///
  /// Pauses all tracking. Can be restarted with [start].
  Future<void> stop() async {
    _checkInitialized();
    await _platform.stop();
  }

  /// Returns whether the SDK is currently started.
  Future<bool> isStarted() async {
    _checkInitialized();
    return _platform.isStarted();
  }

  // ============ Configuration ============

  /// Enables or disables debug logging.
  ///
  /// When enabled, SDK outputs verbose logs for debugging.
  ///
  /// Example:
  /// ```dart
  /// await AdshiftFlutterSdk.instance.setDebugEnabled(true);
  /// ```
  Future<void> setDebugEnabled(bool enabled) async {
    _checkInitialized();
    await _platform.setDebugEnabled(enabled);
  }

  /// Sets the customer user ID.
  ///
  /// Associate events with your own user identifier.
  ///
  /// Example:
  /// ```dart
  /// await AdshiftFlutterSdk.instance.setCustomerUserId('user_123');
  /// ```
  Future<void> setCustomerUserId(String userId) async {
    _checkInitialized();
    await _platform.setCustomerUserId(userId);
  }

  /// Sets the app open debounce interval in milliseconds.
  ///
  /// Controls how often APP_OPEN events are sent when app returns from background.
  /// Default is 10000 (10 seconds).
  ///
  /// Example:
  /// ```dart
  /// await AdshiftFlutterSdk.instance.setAppOpenDebounceMs(30000); // 30 seconds
  /// ```
  Future<void> setAppOpenDebounceMs(int ms) async {
    _checkInitialized();
    await _platform.setAppOpenDebounceMs(ms);
  }

  // ============ Events ============

  /// Tracks an in-app event.
  ///
  /// Use [AdshiftEventType] constants for predefined event names,
  /// or use custom string names.
  ///
  /// Example:
  /// ```dart
  /// // Predefined event
  /// await AdshiftFlutterSdk.instance.trackEvent(
  ///   AdshiftEventType.addToCart,
  ///   values: {'product_id': 'SKU123', 'price': 29.99},
  /// );
  ///
  /// // Custom event
  /// await AdshiftFlutterSdk.instance.trackEvent(
  ///   'custom_event',
  ///   values: {'key': 'value'},
  /// );
  /// ```
  Future<void> trackEvent(
    String eventName, {
    Map<String, dynamic>? values,
  }) async {
    _checkInitialized();
    await _platform.trackEvent(eventName, values);
  }

  /// Tracks a purchase event.
  ///
  /// Use this for revenue tracking and attribution.
  ///
  /// **Important:** The [revenue] parameter is the actual purchase amount.
  /// This is used for SKAdNetwork conversion value calculation on iOS.
  ///
  /// Example:
  /// ```dart
  /// await AdshiftFlutterSdk.instance.trackPurchase(
  ///   productId: 'premium_subscription',
  ///   revenue: 9.99,
  ///   currency: 'USD',
  ///   transactionId: 'TXN_123456',
  /// );
  /// ```
  Future<void> trackPurchase({
    required String productId,
    required double revenue,
    required String currency,
    required String transactionId,
  }) async {
    _checkInitialized();
    await _platform.trackPurchase(
      productId: productId,
      revenue: revenue,
      currency: currency,
      transactionId: transactionId,
    );
  }

  // ============ Consent ============

  /// Sets user consent data for GDPR/DMA compliance.
  ///
  /// Use factory methods on [AdshiftConsent] to create consent objects.
  ///
  /// Example:
  /// ```dart
  /// // For GDPR users who accepted all
  /// await AdshiftFlutterSdk.instance.setConsentData(
  ///   AdshiftConsent.forGDPRUser(
  ///     hasConsentForDataUsage: true,
  ///     hasConsentForAdsPersonalization: true,
  ///     hasConsentForAdStorage: true,
  ///   ),
  /// );
  ///
  /// // For non-GDPR users
  /// await AdshiftFlutterSdk.instance.setConsentData(
  ///   AdshiftConsent.forNonGDPRUser(),
  /// );
  /// ```
  Future<void> setConsentData(AdshiftConsent consent) async {
    _checkInitialized();
    await _platform.setConsentData(consent);
  }

  /// Enables or disables automatic TCF data collection.
  ///
  /// When enabled, SDK reads IAB TCF v2.2 consent strings from
  /// SharedPreferences/NSUserDefaults (set by CMPs like Google Funding Choices).
  ///
  /// Call this BEFORE [start].
  ///
  /// Example:
  /// ```dart
  /// await AdshiftFlutterSdk.instance.enableTCFDataCollection(true);
  /// await AdshiftFlutterSdk.instance.start();
  /// ```
  Future<void> enableTCFDataCollection(bool enabled) async {
    _checkInitialized();
    await _platform.enableTCFDataCollection(enabled);
  }

  /// Refreshes consent state from CMP.
  ///
  /// Call this after CMP dialog closes to pick up updated consent.
  ///
  /// Example:
  /// ```dart
  /// // After CMP dialog closes
  /// await AdshiftFlutterSdk.instance.refreshConsent();
  /// ```
  Future<void> refreshConsent() async {
    _checkInitialized();
    await _platform.refreshConsent();
  }

  // ============ Deep Links ============

  /// Handles a deep link URL.
  ///
  /// Call this when your app receives a deep link.
  /// Returns the resolved deep link with parameters.
  ///
  /// Example:
  /// ```dart
  /// final deepLink = await AdshiftFlutterSdk.instance.handleDeepLink(
  ///   Uri.parse('https://rightlink.me/app?pid=facebook&c=summer_sale'),
  /// );
  ///
  /// if (deepLink.status == AdshiftDeepLinkStatus.found) {
  ///   final campaign = deepLink.params?['c'];
  ///   // Route user based on deep link
  /// }
  /// ```
  Future<AdshiftDeepLink> handleDeepLink(Uri url) async {
    _checkInitialized();
    return _platform.handleDeepLink(url.toString());
  }

  /// Stream of deep link events.
  ///
  /// Listen to this stream to receive deferred deep links
  /// and app link events.
  ///
  /// Example:
  /// ```dart
  /// AdshiftFlutterSdk.instance.onDeepLinkReceived.listen((deepLink) {
  ///   if (deepLink.status == AdshiftDeepLinkStatus.found) {
  ///     print('Deep link received: ${deepLink.deepLink}');
  ///     // Handle deep link
  ///   }
  /// });
  /// ```
  Stream<AdshiftDeepLink> get onDeepLinkReceived => _platform.onDeepLinkReceived;

  // ============ Private Helpers ============

  void _checkInitialized() {
    if (!_isInitialized) {
      throw StateError(
        'AdshiftFlutterSdk not initialized. '
        'Call AdshiftFlutterSdk.instance.initialize(config) first.',
      );
    }
  }
}

