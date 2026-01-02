# AdShift Flutter SDK

[![pub package](https://img.shields.io/pub/v/adshift_flutter_sdk.svg)](https://pub.dev/packages/adshift_flutter_sdk)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-blue.svg)](https://pub.dev/packages/adshift_flutter_sdk)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)

Official AdShift SDK for Flutter. Enable mobile attribution, in-app event tracking, SKAdNetwork 4.0+ integration, deep linking, and GDPR/TCF 2.2 compliance in your Flutter apps.

---

## 📚 Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [API Reference](#api-reference)
  - [SDK Lifecycle](#sdk-lifecycle)
  - [Event Tracking](#event-tracking)
  - [Consent Management](#consent-management)
  - [Deep Linking](#deep-linking)
  - [Configuration](#configuration)
- [Platform-Specific Setup](#platform-specific-setup)
  - [iOS Setup](#ios-setup)
  - [Android Setup](#android-setup)
- [Example App](#example-app)
- [Support](#support)

---

## Features

- ✅ **Install Attribution** — Accurate install tracking across platforms
- ✅ **In-App Event Tracking** — Track user actions and conversions
- ✅ **SKAdNetwork 4.0+** — Full support for iOS privacy-preserving attribution
- ✅ **Deep Linking** — Direct and deferred deep link support
- ✅ **GDPR/DMA Compliance** — Manual consent and TCF 2.2 support
- ✅ **Offline Mode** — Events are cached and sent when connectivity returns
- ✅ **Cross-Platform** — Single API for iOS and Android

---

## Requirements

| Platform | Minimum Version |
|----------|-----------------|
| **iOS** | 15.0+ |
| **Android** | API 21+ (Android 5.0) |
| **Flutter** | 3.3.0+ |
| **Dart** | 3.0.0+ |

---

## Installation

Add `adshift_flutter_sdk` to your `pubspec.yaml`:

```yaml
dependencies:
  adshift_flutter_sdk: ^1.0.0
```

Then run:

```bash
flutter pub get
```

---

## Quick Start

### 1. Initialize and Start the SDK

```dart
import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize SDK with your API key
  await AdshiftFlutterSdk.instance.initialize(
    AdshiftConfig(
      apiKey: 'YOUR_API_KEY',
      isDebug: true, // Set to false in production
    ),
  );
  
  // Start tracking
  await AdshiftFlutterSdk.instance.start();
  
  runApp(MyApp());
}
```

### 2. Track Events

```dart
// Track a simple event
await AdshiftFlutterSdk.instance.trackEvent(AdshiftEventType.login);

// Track event with parameters
await AdshiftFlutterSdk.instance.trackEvent(
  AdshiftEventType.addToCart,
  values: {
    'product_id': 'SKU123',
    'price': 29.99,
    'quantity': 1,
  },
);

// Track purchase
await AdshiftFlutterSdk.instance.trackPurchase(
  productId: 'premium_subscription',
  revenue: 9.99,
  currency: 'USD',
  transactionId: 'TXN_12345',
);
```

### 3. Handle Deep Links

```dart
// Listen for deep links
AdshiftFlutterSdk.instance.onDeepLinkReceived.listen((deepLink) {
  if (deepLink.status == AdshiftDeepLinkStatus.found) {
    print('Deep link: ${deepLink.deepLink}');
    print('Params: ${deepLink.params}');
    // Navigate to appropriate screen
  }
});

// Handle incoming URL (e.g., from uni_links package)
final result = await AdshiftFlutterSdk.instance.handleDeepLink(
  Uri.parse('https://yourapp.rightlink.me/abc123'),
);
```

---

## API Reference

### SDK Lifecycle

#### Initialize

Configure the SDK before calling `start()`:

```dart
await AdshiftFlutterSdk.instance.initialize(
  AdshiftConfig(
    apiKey: 'YOUR_API_KEY',
    isDebug: true,                    // Enable debug logs
    appOpenDebounceMs: 10000,         // Debounce for app open events (default: 10s)
    disableSKAN: false,               // iOS only: disable SKAdNetwork
    waitForATTBeforeStart: false,     // iOS only: wait for ATT prompt
    attTimeoutMs: 30000,              // iOS only: ATT timeout
    collectOaid: false,               // Android only: collect OAID
  ),
);
```

#### Start / Stop / Check Status

```dart
// Start SDK tracking
await AdshiftFlutterSdk.instance.start();

// Stop SDK tracking
await AdshiftFlutterSdk.instance.stop();

// Check if SDK is running
final isRunning = await AdshiftFlutterSdk.instance.isStarted();
```

---

### Event Tracking

#### Predefined Event Types

```dart
// Available event types
AdshiftEventType.login
AdshiftEventType.purchase
AdshiftEventType.addToCart
AdshiftEventType.addToWishList
AdshiftEventType.completeRegistration
AdshiftEventType.initiatedCheckout
AdshiftEventType.subscribe
AdshiftEventType.startTrial
AdshiftEventType.levelAchieved
AdshiftEventType.achievementUnlocked
AdshiftEventType.tutorialCompletion
AdshiftEventType.contentView
AdshiftEventType.search
AdshiftEventType.rate
AdshiftEventType.share
AdshiftEventType.invite
// ... and more
```

#### Track Custom Events

```dart
// Use any string for custom events
await AdshiftFlutterSdk.instance.trackEvent(
  'custom_event_name',
  values: {'key': 'value'},
);
```

#### Track Purchase

```dart
await AdshiftFlutterSdk.instance.trackPurchase(
  productId: 'product_123',
  revenue: 19.99,           // IMPORTANT: Use revenue, not price
  currency: 'USD',
  transactionId: 'TXN_ABC',
);
```

> ⚠️ **Note:** Use `revenue` parameter for proper SKAdNetwork conversion value calculation.

---

### Consent Management

#### Manual Consent (GDPR/DMA)

```dart
// For GDPR users - grant all consent
await AdshiftFlutterSdk.instance.setConsentData(
  AdshiftConsent.forGDPRUser(
    hasConsentForDataUsage: true,
    hasConsentForAdsPersonalization: true,
    hasConsentForAdStorage: true,
  ),
);

// For GDPR users - deny consent
await AdshiftFlutterSdk.instance.setConsentData(
  AdshiftConsent.forGDPRUser(
    hasConsentForDataUsage: false,
    hasConsentForAdsPersonalization: false,
    hasConsentForAdStorage: false,
  ),
);

// For non-GDPR users
await AdshiftFlutterSdk.instance.setConsentData(
  AdshiftConsent.forNonGDPRUser(),
);
```

#### TCF 2.2 Automatic Collection

If you use a CMP (Consent Management Platform) that stores IAB TCF data:

```dart
// Enable TCF collection BEFORE calling start()
await AdshiftFlutterSdk.instance.enableTCFDataCollection(true);
await AdshiftFlutterSdk.instance.start();

// Refresh consent after CMP dialog closes
await AdshiftFlutterSdk.instance.refreshConsent();
```

---

### Deep Linking

#### Listen for Deep Links

```dart
// Subscribe to deep link stream
AdshiftFlutterSdk.instance.onDeepLinkReceived.listen((deepLink) {
  switch (deepLink.status) {
    case AdshiftDeepLinkStatus.found:
      final url = deepLink.deepLink;
      final params = deepLink.params;
      final isDeferred = deepLink.isDeferred;
      // Navigate based on deep link data
      break;
    case AdshiftDeepLinkStatus.notFound:
      // No deep link available
      break;
    case AdshiftDeepLinkStatus.error:
      // Handle error
      break;
  }
});
```

#### Handle Incoming URLs

```dart
// When your app receives a URL (e.g., via uni_links)
final result = await AdshiftFlutterSdk.instance.handleDeepLink(uri);
```

---

### Configuration

#### Set Customer User ID

Associate events with your own user identifier:

```dart
await AdshiftFlutterSdk.instance.setCustomerUserId('user_12345');
```

> 💡 **Tip:** Set CUID before `start()` to associate it with the install event.

#### Debug Mode

```dart
await AdshiftFlutterSdk.instance.setDebugEnabled(true);
```

#### App Open Debounce

Control how often app_open events are sent:

```dart
await AdshiftFlutterSdk.instance.setAppOpenDebounceMs(5000); // 5 seconds
```

---

## Platform-Specific Setup

### iOS Setup

#### 1. Update Podfile

Ensure your iOS deployment target is 15.0+:

```ruby
# ios/Podfile
platform :ios, '15.0'
```

#### 2. Add App Tracking Transparency (Optional)

To request IDFA permission, add to `Info.plist`:

```xml
<key>NSUserTrackingUsageDescription</key>
<string>Your tracking description here</string>
```

Then configure SDK to wait for ATT:

```dart
AdshiftConfig(
  apiKey: 'YOUR_API_KEY',
  waitForATTBeforeStart: true,
  attTimeoutMs: 30000,
);
```

#### 3. Configure Universal Links

Add Associated Domains capability and configure `apple-app-site-association` for deep linking.

---

### Android Setup

#### 1. Update build.gradle

Ensure minimum SDK is 21+:

```kotlin
// android/app/build.gradle
android {
    defaultConfig {
        minSdkVersion 21
    }
}
```

#### 2. Add Permissions

These are already included in the SDK manifest, but ensure your app allows them:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

#### 3. Configure App Links

Add intent filter to `AndroidManifest.xml` for deep linking:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data
        android:scheme="https"
        android:host="your_subdomain.rightlink.me" />
</intent-filter>
```

---

## Example App

See the [example](example/) directory for a complete demo app showing:

- SDK initialization and lifecycle
- Event tracking with all event types
- Purchase tracking
- Consent management (GDPR/TCF)
- Deep link handling
- Customer ID management

Run the example:

```bash
cd example
flutter run
```

---

## Support

- 📧 **Email:** support@adshift.com
- 📖 **Documentation:** https://dev.adshift.com/docs/flutter-sdk
- 🐛 **Issues:** https://github.com/AdShift/adshift-flutter-sdk/issues

---

## License

This SDK is proprietary software. See [LICENSE](LICENSE) for details.

© 2024-2026 AdShift. All rights reserved.
