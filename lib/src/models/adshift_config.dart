/// Configuration for initializing the AdShift SDK.
///
/// Example:
/// ```dart
/// final config = AdshiftConfig(
///   apiKey: 'your-api-key',
///   isDebug: true,
/// );
/// await AdshiftFlutterSdk.instance.initialize(config);
/// ```
class AdshiftConfig {
  /// API key for authenticating with AdShift backend.
  /// 
  /// Required. Get your API key from the AdShift dashboard.
  final String apiKey;

  /// Enable debug logging.
  /// 
  /// When true, SDK will output verbose logs for debugging.
  /// Default: false
  final bool isDebug;

  /// Debounce interval for automatic APP_OPEN events (in milliseconds).
  /// 
  /// Controls how often APP_OPEN events are sent when app returns from background.
  /// Default: 10000 (10 seconds)
  final int appOpenDebounceMs;

  // ============ iOS-only options ============

  /// Disable SKAdNetwork integration (iOS only).
  /// 
  /// Set to true to completely disable SKAN functionality.
  /// Default: false (SKAN enabled)
  final bool? disableSKAN;

  /// Wait for ATT authorization before sending install event (iOS only).
  /// 
  /// When enabled, SDK will wait for App Tracking Transparency authorization
  /// before sending the install event to include IDFA if user grants permission.
  /// Default: false
  final bool? waitForATTBeforeStart;

  /// Timeout for ATT authorization wait in milliseconds (iOS only).
  /// 
  /// Maximum time to wait for ATT response when [waitForATTBeforeStart] is enabled.
  /// Range: 5000 - 120000 (5s - 2 minutes)
  /// Default: 30000 (30 seconds)
  final int? attTimeoutMs;

  // ============ Android-only options ============

  /// Enable OAID collection (Android only).
  /// 
  /// OAID is an alternative to Google Advertising ID used on Chinese Android devices.
  /// Default: true
  final bool? collectOaid;

  /// Creates an AdShift SDK configuration.
  /// 
  /// [apiKey] is required. All other parameters have sensible defaults.
  const AdshiftConfig({
    required this.apiKey,
    this.isDebug = false,
    this.appOpenDebounceMs = 10000,
    // iOS only
    this.disableSKAN,
    this.waitForATTBeforeStart,
    this.attTimeoutMs,
    // Android only
    this.collectOaid,
  });

  /// Converts config to a Map for platform channel communication.
  Map<String, dynamic> toMap() {
    return {
      'apiKey': apiKey,
      'isDebug': isDebug,
      'appOpenDebounceMs': appOpenDebounceMs,
      // iOS only
      if (disableSKAN != null) 'disableSKAN': disableSKAN,
      if (waitForATTBeforeStart != null) 'waitForATTBeforeStart': waitForATTBeforeStart,
      if (attTimeoutMs != null) 'attTimeoutMs': attTimeoutMs,
      // Android only
      if (collectOaid != null) 'collectOaid': collectOaid,
    };
  }

  @override
  String toString() {
    return 'AdshiftConfig(apiKey: ${apiKey.substring(0, 4)}..., isDebug: $isDebug)';
  }
}

