import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'models/adshift_config.dart';
import 'models/adshift_consent.dart';
import 'models/adshift_deeplink.dart';
import 'adshift_sdk_method_channel.dart';

/// Platform interface for AdShift SDK.
///
/// This abstract class defines the contract that platform implementations must follow.
/// Platform-specific implementations (iOS, Android) provide the actual functionality.
abstract class AdshiftSdkPlatform extends PlatformInterface {
  /// Constructs a AdshiftSdkPlatform.
  AdshiftSdkPlatform() : super(token: _token);

  static final Object _token = Object();

  static AdshiftSdkPlatform _instance = MethodChannelAdshiftSdk();

  /// The default instance of [AdshiftSdkPlatform] to use.
  ///
  /// Defaults to [MethodChannelAdshiftSdk].
  static AdshiftSdkPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [AdshiftSdkPlatform] when
  /// they register themselves.
  static set instance(AdshiftSdkPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // ============ Lifecycle ============

  /// Initializes the SDK with the given configuration.
  Future<void> initialize(AdshiftConfig config) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Starts the SDK.
  Future<void> start() {
    throw UnimplementedError('start() has not been implemented.');
  }

  /// Stops the SDK.
  Future<void> stop() {
    throw UnimplementedError('stop() has not been implemented.');
  }

  /// Returns whether the SDK is currently started.
  Future<bool> isStarted() {
    throw UnimplementedError('isStarted() has not been implemented.');
  }

  // ============ Configuration ============

  /// Enables or disables debug logging.
  Future<void> setDebugEnabled(bool enabled) {
    throw UnimplementedError('setDebugEnabled() has not been implemented.');
  }

  /// Sets the customer user ID.
  Future<void> setCustomerUserId(String userId) {
    throw UnimplementedError('setCustomerUserId() has not been implemented.');
  }

  /// Sets the app open debounce interval in milliseconds.
  Future<void> setAppOpenDebounceMs(int ms) {
    throw UnimplementedError('setAppOpenDebounceMs() has not been implemented.');
  }

  // ============ Events ============

  /// Tracks an event with optional values.
  Future<void> trackEvent(String eventName, Map<String, dynamic>? values) {
    throw UnimplementedError('trackEvent() has not been implemented.');
  }

  /// Tracks a purchase event.
  Future<void> trackPurchase({
    required String productId,
    required double revenue,
    required String currency,
    required String transactionId,
  }) {
    throw UnimplementedError('trackPurchase() has not been implemented.');
  }

  // ============ Consent ============

  /// Sets user consent data.
  Future<void> setConsentData(AdshiftConsent consent) {
    throw UnimplementedError('setConsentData() has not been implemented.');
  }

  /// Enables or disables TCF data collection.
  Future<void> enableTCFDataCollection(bool enabled) {
    throw UnimplementedError('enableTCFDataCollection() has not been implemented.');
  }

  /// Refreshes consent state from CMP.
  Future<void> refreshConsent() {
    throw UnimplementedError('refreshConsent() has not been implemented.');
  }

  // ============ Deep Links ============

  /// Handles a deep link URL.
  Future<AdshiftDeepLink> handleDeepLink(String url) {
    throw UnimplementedError('handleDeepLink() has not been implemented.');
  }

  /// Sets a listener for deep link events.
  /// Returns a stream of deep link events.
  Stream<AdshiftDeepLink> get onDeepLinkReceived {
    throw UnimplementedError('onDeepLinkReceived has not been implemented.');
  }
}

