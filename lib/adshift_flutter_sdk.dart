/// AdShift SDK for Flutter - Mobile Attribution, Event Tracking & Deep Linking.
///
/// ## Quick Start
///
/// ```dart
/// import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
///
/// // Initialize
/// await AdshiftFlutterSdk.instance.initialize(
///   AdshiftConfig(apiKey: 'your-api-key'),
/// );
///
/// // Start tracking
/// await AdshiftFlutterSdk.instance.start();
///
/// // Track events
/// await AdshiftFlutterSdk.instance.trackEvent(AdshiftEventType.login);
/// ```
///
/// See [AdshiftFlutterSdk] for full API documentation.
library;

// Main SDK class
export 'src/adshift_sdk.dart';

// Models
export 'src/models/adshift_config.dart';
export 'src/models/adshift_consent.dart';
export 'src/models/adshift_deeplink.dart';
export 'src/models/adshift_event_type.dart';
