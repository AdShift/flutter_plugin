# AdShift Flutter Plugin

[![pub package](https://img.shields.io/pub/v/adshift_flutter_sdk.svg)](https://pub.dev/packages/adshift_flutter_sdk)
[![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20Android-blue.svg)](https://pub.dev/packages/adshift_flutter_sdk)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)

Official AdShift SDK for Flutter. One Dart API over the native [iOS SDK](https://github.com/AdShift/ios-sdk) and [Android SDK](https://github.com/AdShift/android-sdk-releases): install attribution, in-app events, ad revenue, SKAdNetwork, deep linking (direct, deferred and push) and consent (manual, TCF 2.2, GPP).

---

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Results Instead of Exceptions](#results-instead-of-exceptions)
- [Lifecycle](#lifecycle)
- [Event Tracking](#event-tracking)
- [Ad Revenue](#ad-revenue)
- [Deep Linking](#deep-linking)
- [Push Notifications](#push-notifications)
- [Consent](#consent)
- [Configuration](#configuration)
- [Identity](#identity)
- [Platform Setup](#platform-setup)
- [Store Privacy Declarations](#store-privacy-declarations)
- [Testing](#testing)
- [Upgrading from 1.x](#upgrading-from-1x)
- [Example App](#example-app)
- [Troubleshooting](#troubleshooting)
- [Support](#support)

---

## Requirements

| | Minimum |
|---|---|
| **Flutter** | 3.44 |
| **Dart** | 3.12 |
| **iOS** | 15.0, Xcode 16.1+ |
| **Android** | API 24 (Android 7.0), `compileSdk` 35+ |

The plugin supports Android and iOS. A Flutter module embedded in a native app (add-to-app) is not supported.

### Native SDK versions

Each plugin release pins exact native SDK versions and brings them with it. Do not add either SDK to your app yourself.

| Plugin | Android SDK | iOS SDK |
|---|---|---|
| 2.0.x | `com.adshift:android-sdk:4.2.0` | `AdshiftSDK 3.1.0` |

---

## Installation

```sh
flutter pub add adshift_flutter_sdk
```

**iOS**

- **Deployment target 15.0.** An app created with Flutter older than 3.50 targets iOS 13 and does not build with the plugin until you raise it: in Xcode, **Runner** target → **General** → **Minimum Deployments** → 15.0. If `ios/Podfile` has a `platform :ios` line, raise it there too.
- **Do not add `AdshiftSDK` to the app yourself**, neither with CocoaPods nor with Swift Package Manager. The plugin carries the AdShift iOS SDK, and a second copy stops the build. Your app's own native code can still `import AdshiftSDK`.
- Swift Package Manager and CocoaPods, Flutter's two iOS dependency managers, both work with nothing extra.

**Android** — nothing to add. See [Platform Setup → Android](#android) for what the SDK merges into your app: permissions and backup rules.

Links, App Tracking Transparency and postbacks need a few entries in your project files, none of them code: see [Platform Setup](#platform-setup).

---

## Quick Start

```dart
import 'dart:async';

import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

void main() {
  final adshift = Adshift.instance;

  // 1. Listen for deep links first. Results that arrive while nobody
  //    listens wait for the first listener.
  adshift.onDeepLink.listen((link) {
    if (link.status == AdshiftDeepLinkStatus.found) {
      // Route on link.deepLinkValue.
    }
  });

  // 2. Initialize once, as early as possible. iOS and Android are separate
  //    apps in the AdShift dashboard, each with its own API key.
  adshift.initialize(
    AdshiftConfig(
      apiKey: defaultTargetPlatform == TargetPlatform.iOS
          ? 'YOUR_IOS_API_KEY'
          : 'YOUR_ANDROID_API_KEY',
      isDebug: kDebugMode,
      onError: (error) => debugPrint('AdShift: $error'),
    ),
  );

  // 3. Consent, on every launch, before start().
  adshift.setConsentData(const AdshiftConsent.forNonGDPRUser());

  // 4. Start. Not awaited: on Android the answer can take up to 5 seconds,
  //    and the first frame must not wait for it.
  unawaited(startAdshift());

  runApp(const MyApp());
}

Future<void> startAdshift() async {
  final result = await Adshift.instance.start();
  if (!result.success) debugPrint('AdShift did not start: ${result.error}');
}
```

Track from anywhere in the app. Calls made before `start()` has answered wait for it and are sent in order:

```dart
final result = await Adshift.instance.trackEvent(
  AdshiftEventType.purchase,
  values: {
    AdshiftEventParam.revenue: 9.99,
    AdshiftEventParam.currency: 'USD',
  },
);
if (!result.success) debugPrint('Not tracked: ${result.error}');
```

---

## Results Instead of Exceptions

No call throws, and no returned `Future` completes with an error. You need no `try`/`catch` around the plugin, and a call you do not await cannot end up in your crash reports.

| Call | How a problem reaches you |
|---|---|
| `start()` | `AdshiftStartResult`: `success`, `error` |
| `trackEvent()`, `trackPurchase()`, `logAdRevenue()` | `AdshiftResult`: `success`, `error` |
| Everything else | The call is skipped and reported to `AdshiftConfig.onError`; where it returns a value, that is `null` or `false` |

`onError` also receives a `start()` the SDK answered with a failure, such as a rejected key or a device with tracking turned off. A failed `start()` is always in its result, so read it there. In debug builds every report is also printed with the prefix `[AdShift]`; in release builds `onError` is the only place it shows, so register it. Before `initialize()` there is no `onError` yet: a refused call is only printed, in debug builds.

```dart
Adshift.instance.initialize(
  AdshiftConfig(
    apiKey: apiKey,
    onError: (error) {
      report('AdShift ${error.code.wireName}: ${error.message}');
    },
  ),
);
```

Every problem is an `AdshiftError`: `code`, a `message` for your logs, and `nativeCode` (plus `nativeDomain` on iOS) when the platform reported one.

| Code (`AdshiftErrorCode`) | When | What to do |
|---|---|---|
| `NOT_INITIALIZED` (`notInitialized`) | `initialize()` has not been called, was refused, or the call came from [another Flutter engine](#one-engine) | Call `initialize()` first, with a valid config, from the app's main isolate |
| `NOT_STARTED` (`notStarted`) | `stop()` was called | Call `start()`. The declined call is not sent later |
| `INVALID_API_KEY` (`invalidApiKey`) | The API key was rejected. Android answers `start()` with it; on iOS a rejected key is usually not reported to the app | Use the key of this platform's app from the dashboard. Nothing is reported until then |
| `OPTED_OUT` (`optedOut`) | Tracking is turned off for this device | Nothing. It is not a mistake in your code and retrying does not change it |
| `QUEUE_FULL` (`queueFull`) | More than 100 tracking calls are waiting for `start()` | Call `start()` on every launch. The declined call is dropped |
| `INVALID_ARGUMENT` (`invalidArgument`) | An argument failed validation | Fix the call; `message` names the argument |
| `UNKNOWN` (`unknown`) | Anything else | Send us `nativeCode` and `nativeDomain` |

---

## Lifecycle

### `initialize(config)`

Sets the SDK up. Call it once, as early as possible; the first config is kept and later calls are ignored. See [`AdshiftConfig`](#adshiftconfig) for every option.

A config the plugin cannot use (a blank `apiKey`, a negative `appOpenDebounceMs` or `attTimeoutMs`, a blank entry in `brandedDomains` or `pushDeepLinkPaths`) is reported to `onError` as `INVALID_ARGUMENT` and leaves the SDK uninitialized; `start()` then answers with the same error.

### `start()` → `Future<AdshiftStartResult>`

Starts measurement. Call it on every launch.

```dart
final result = await Adshift.instance.start();
result.success; // whether the SDK started
result.error; // AdshiftError when it did not
result.apiKeyValidationStatus; // pending, valid, invalid, or null
```

- **Do not await it before the first frame.** On Android the answer can take up to 5 seconds.
- **A rejected API key shows differently on each platform.** On Android `start()` fails with `INVALID_API_KEY` within about 5 seconds. On iOS `start()` usually answers `pending`, so a rejected key is usually not reported to the app: turn on `isDebug` and check the SDK's log while integrating. When it is reported, `apiKeyValidationStatus` is `invalid` and `onError` receives `INVALID_API_KEY`. `pending` needs no action.
- A device with tracking turned off answers `OPTED_OUT`.
- Before `initialize()` it answers `NOT_INITIALIZED`. Called again while started, it answers success at once.
- On iOS `start()` does not wait for the App Tracking Transparency answer. With `waitForATTBeforeStart` the first events are held until the answer, at most `attTimeoutMs`.
- **Tracking calls made between `initialize()` and a successful `start()` wait, up to 100, and are sent in order.** Their futures complete once a `start()` has finished, which is why `start()` belongs on every launch path. If the start failed for a reason a retry cannot fix (`INVALID_API_KEY`, `OPTED_OUT`, `NOT_INITIALIZED`), they answer with that error. After any other failure they wait for the next `start()`.

### `stop()`

Stops measurement until the next `start()`. Tracking calls made meanwhile, and calls still waiting for a start, answer `NOT_STARTED`. This is not an opt-out.

Links keep reaching `onDeepLink` after `stop()`, so your app can still route, but their clicks are not counted, and a short link arrives without `deepLinkValue`. Settings and `refreshConsent()` keep working.

### `isStarted`

`true` between a successful `start()` and `stop()`. Safe before `initialize()`.

### `getInfo()`

```dart
final info = Adshift.instance.getInfo();
info.platform; // 'android' or 'ios'
info.version; // version of this plugin
info.androidSdkVersion; // AdShift Android SDK this plugin is built on
info.iosSdkVersion; // AdShift iOS SDK this plugin is built on
```

Works before `initialize()`. Include it in support requests. The plugin version is also the constant `adshiftPluginVersion`.

### One engine

The SDK belongs to the Flutter engine that shows your app's UI. In any other engine, such as the background isolate of a push message handler or of a background task, calls do nothing: `initialize()` is refused, `start()` and the tracking calls answer `NOT_INITIALIZED`, and no deep links arrive. Track from the app's main isolate.

---

## Event Tracking

### `trackEvent(eventName, {values})` → `Future<AdshiftResult>`

```dart
await Adshift.instance.trackEvent(
  AdshiftEventType.addToCart,
  values: {
    AdshiftEventParam.contentId: 'SKU123',
    AdshiftEventParam.price: 29.99,
    'in_stock': true, // your own keys are fine next to the standard ones
  },
);
await Adshift.instance.trackEvent('custom_event');
```

- `values` may hold strings, numbers and booleans.
- Success means the SDK accepted the event, not that it was delivered yet.
- `app_install` and `app_open` are reserved: the SDK sends them itself, and passing them answers `INVALID_ARGUMENT`.

### `trackPurchase(...)` → `Future<AdshiftResult>`

```dart
await Adshift.instance.trackPurchase(
  productId: 'premium_monthly',
  revenue: 9.99,
  currency: 'USD', // ISO 4217
  transactionId: 'GPA.1234-5678-9012-34567', // transaction id or purchase token
);
```

All four arguments are required. A blank one, or a negative revenue, answers `INVALID_ARGUMENT`.

### Standard event names

`AdshiftEventType` holds the 30 standard names; `AdshiftEventType.all` lists them. Any other name is tracked as a custom event.

| Category | Constants |
|---|---|
| E-commerce | `addToCart`, `addToWishList`, `addPaymentInfo`, `initiatedCheckout`, `purchase`, `contentView`, `listView`, `search` |
| User lifecycle | `completeRegistration`, `login`, `tutorialCompletion`, `subscribe`, `startTrial` |
| Gaming | `levelAchieved`, `achievementUnlocked`, `spentCredit` |
| Engagement | `rate`, `share`, `invite`, `reEngage`, `update`, `openedFromPushNotification` |
| Travel | `travelBooking` |
| Ads | `adClick`, `adView`, `adRevenue` |
| Location | `locationChanged`, `locationCoordinates` |
| Other | `orderId`, `customerSegment` |

### Standard parameter names

`AdshiftEventParam` holds the 81 parameter names reports add up; `AdshiftEventParam.all` lists them. Use them for anything that has to be counted, revenue above all:

```dart
await Adshift.instance.trackEvent(
  AdshiftEventType.purchase,
  values: {
    AdshiftEventParam.revenue: 9.99,
    AdshiftEventParam.currency: 'USD',
    AdshiftEventParam.quantity: 1,
    'gift_wrapped': true,
  },
);
```

Any other key is kept with the event as a custom parameter, so `'revenue': 9.99` arrives intact but is not counted as revenue. Nothing is rewritten for you: in debug builds the plugin warns once per name when a key is the plain spelling of a standard name (`price`, `contentId`, `content_id`) and names the constant to use.

`trackPurchase()` and `logAdRevenue()` need none of this: they fill the revenue and currency names from their own arguments.

---

## Ad Revenue

### `logAdRevenue(...)` → `Future<AdshiftResult>`

```dart
await Adshift.instance.logAdRevenue(
  monetizationNetwork: 'admob',
  mediationNetwork: AdshiftMediationNetwork.googleAdMob,
  currency: 'USD',
  revenue: 0.0125,
  adUnitId: 'ca-app-pub-1234/5678', // optional
  precision: 'estimated', // optional
  additionalParameters: {AdshiftEventParam.adRevenuePlacementId: 'home_banner'}, // optional
);
```

- `mediationNetwork` is an `AdshiftMediationNetwork`: `appLovinMax`, `googleAdMob`, `ironSource`, `chartboost`, `topOn`, `tradPlus`, `adMost`, `appodeal`, `fyber`, `unity`, `yandex`, `customMediation`, `directMonetization`, `other`.
- `revenue` is the revenue of one impression, not an aggregate, and must be positive. `currency` is a three-letter ISO 4217 code.
- An impression above 10 USD is not recorded; on Android the limit is 10 in whatever currency you pass. In debug builds the plugin prints a warning.
- An impression above the limit also answers success.
- The four required arguments and `adUnitId` and `precision` have parameter names of their own. Do not repeat them in `additionalParameters`. On iOS the keys `revenue`, `value` and `currency` in `additionalParameters` are ignored.

---

## Deep Linking

### The contract

- Every link that opens the app and reaches the SDK (direct, deferred, push) produces one `onDeepLink` result, and each result is delivered once.
- **Navigate only on `AdshiftDeepLinkStatus.found`.** `found` means an AdShift link, a RightLink: your `*.rightlink.me` host, a domain in `brandedDomains`, your app's scheme wrapping one (`yourapp://rightlink?as_rl=<the link, percent-encoded>`), or a deferred deep link with a value. Validate `deepLinkValue` before you use it: anyone can write a link.
- Any other URL, your app's own links included, comes back `notFound` with the URL in `deepLink` and no `params`. Route your own links from there.
- `error` means "not yet": a short link that could not be resolved, for example without a network. `found` follows once it resolves.
- Results arrive only through `onDeepLink`. `handleDeepLink()` completes at once, and `handlePushNotification()` only answers whether the payload carried an AdShift link.

### `onDeepLink` → `Stream<AdshiftDeepLink>`

```dart
final subscription = Adshift.instance.onDeepLink.listen((link) {
  switch (link.status) {
    case AdshiftDeepLinkStatus.found:
      if (link.deepLinkValue == 'product') {
        openProduct(link.params?['product_id']);
      }
    case AdshiftDeepLinkStatus.notFound:
      // One of your own links, if any: the URL is in link.deepLink.
      break;
    case AdshiftDeepLinkStatus.error:
      // Carry on without a deep link; found can still follow.
      break;
  }
});
```

- Listen once, early, in something that lives as long as the app. Listening before `initialize()` is fine.
- Results that arrive while nobody listens wait for the next listener. A listener added later gets no replay of what was already delivered.

| Field | Type | Meaning |
|---|---|---|
| `status` | `AdshiftDeepLinkStatus` | `found`, `notFound` or `error` |
| `deepLink` | `String?` | The link as opened, a short link expanded |
| `deepLinkValue` | `String?` | `deep_link_value`, for routing |
| `params` | `Map<String, String>?` | Query of a RightLink link, your own keys included |
| `isDeferred` | `bool` | The result of the deferred lookup on the first launch |
| `isFirstSession` | `bool?` | Whether this is the first session after install |
| `errorMessage` | `String?` | With `error`; the wording differs per platform |
| `source` | `AdshiftDeepLinkSource?` | How the link reached the app |
| `clickId` | `String?` | The click this open was attributed to |
| `matchGuaranteed` | `bool?` | iOS, see [Deferred deep links](#deferred-deep-links) |
| `deepLinkSub1` … `deepLinkSub5` | `String?` | `deep_link_sub1` … `deep_link_sub5` |

`source` is `universalLink` on iOS and `appLink` on Android for a Universal Link or App Link (or a link you passed in yourself), `scheme`, `cta` (the open-in-app button of a RightLink page), `push`, `deferred` or `foreign` (a web link that is not a RightLink link); iOS adds `adAttributionKit` (an AdAttributionKit re-engagement open) and Android `metaAppLink`.

### Automatic forwarding (default)

With `autoHandleDeepLinks` on, which is the default, you write no linking code and no native code:

- **Android** — the plugin reads the Intent that started the Activity and every Intent it receives later: App Links, your URL scheme, and taps on notifications whose Intent carries the link.
- **iOS** — the plugin receives Universal Links and URL scheme opens, at launch and while the app runs.

Put your link domains in the config, or call `setBrandedDomains()` before `initialize()`. Set later, a domain does not apply to the link that opened the app.

### Next to Flutter's deep linking and other link plugins

The plugin reads a link and reports it as not handled, so your app's own routing and other plugins still receive it. Flutter's own deep linking, which is on by default, receives it too. Set your app up in one of two ways.

**Your app routes from `onDeepLink` and does not use Flutter's deep linking** — turn Flutter's deep linking off:

```xml
<!-- ios/Runner/Info.plist -->
<key>FlutterDeepLinkingEnabled</key>
<false/>
```

```xml
<!-- android/app/src/main/AndroidManifest.xml, inside the MainActivity <activity> -->
<meta-data android:name="flutter_deeplinking_enabled" android:value="false" />
```

Links are then delivered once, to `onDeepLink`, and never reopened in the browser. Do not skip this in an app without a `Navigator` or `Router` that takes the route: with Flutter's deep linking left on, nothing handles a Universal Link on iOS, Flutter hands it back to the system, and iOS opens it in the browser after your app already received its result.

**Your app uses Flutter's deep linking with a `Router` or `Navigator`** — leave it on, and make your router ignore AdShift links (your `*.rightlink.me` host and your branded domains) or send them to the screen `onDeepLink` will choose. The link is then not reopened in the browser.

**Another link plugin** changes nothing on Android. On iOS, plugins are offered a link one after another until one reports it as handled. If such a plugin stands before AdShift, the link never arrives at `onDeepLink`: pass the links that plugin gives you to AdShift yourself, as below.

### Manual forwarding

Set `autoHandleDeepLinks: false` and pass every URL your app receives:

```dart
Adshift.instance.initialize(
  AdshiftConfig(apiKey: apiKey, autoHandleDeepLinks: false),
);

// For example with the app_links package:
AppLinks().uriLinkStream.listen((uri) {
  Adshift.instance.handleDeepLink(uri);
});
```

Use one way or the other, not both. The same tap handed over twice counts once. The URL must be absolute; anything else is reported as `INVALID_ARGUMENT`. With manual forwarding the plugin reads nothing from the Android Intent, a tapped notification included: hand its payload over with [`handlePushNotification()`](#push-notifications).

### Deferred deep links

On the first launch after install the SDK looks up the link the user tapped before installing and answers through `onDeepLink` with `isDeferred: true` within 5 seconds of `start()`: the link, `notFound` or `error`. With `waitForATTBeforeStart` on iOS the 5 seconds count from the ATT answer. Nothing to configure.

- **Route on `deepLinkValue` and `deepLinkSub1` … `deepLinkSub5`**, which `params` also holds as `deep_link_sub1` … `deep_link_sub5`. On iOS a deferred result has no `deepLink`.
- **`matchGuaranteed: false` (iOS)** means the result is not certain to belong to this user: route them, but do not sign them in or grant a reward because of it.
- `isFirstSession` says whether this is the first session after install. `isDeferred` alone does not mean a new user.
- There is no deferred deep link when the user denied ad storage or ad user data in your consent.

**Clipboard (iOS)** — for RightLink templates with the clipboard option, set `deferredDeepLinkClipboard` in `initialize()`:

- `AdshiftDeferredDeepLinkClipboard.prompt` — the SDK reads the clipboard once per install; iOS asks the user to allow the paste.
- `AdshiftDeferredDeepLinkClipboard.pasteControl` — your onboarding shows Apple's paste button (`UIPasteControl`), which pastes without asking, and you pass on what was pasted:

```dart
Adshift.instance.handlePastedDeepLink(pastedUrl); // null when the user skipped
```

Call it on every way out of onboarding: the deferred deep link of the first launch waits for it. `UIPasteControl` is a native view; the plugin ships none, so your app adds its own, for example as a platform view.

---

## Push Notifications

The SDK reads an AdShift link from a push payload under the top-level key `as_push_link`. Name your own key paths with `pushDeepLinkPaths` in the config, or with `addPushNotificationDeepLinkPath()` before `initialize()`. Set later, a path does not apply to the notification that opened the app. The paths are searched in the order you add them. A path that leads through a JSON string, a value that holds JSON as text, works on Android only.

Your own paths take over from `as_push_link`. If your payloads use both, list it too:

```dart
Adshift.instance.initialize(
  AdshiftConfig(
    apiKey: apiKey,
    pushDeepLinkPaths: [
      ['data', 'link'],
      ['as_push_link'],
    ],
  ),
);
```

- **Android** — with `autoHandleDeepLinks` on, the plugin handles a tapped notification itself when its Intent carries the payload, as the notifications Android shows for a Firebase message do. Your app does not need to call `handlePushNotification()` for it. If it does, the tap is still counted once.
- **iOS** — hand the payload of the tapped notification over. Do the same on Android when your app builds its notifications itself, or with `autoHandleDeepLinks` off:

```dart
// firebase_messaging
FirebaseMessaging.onMessageOpenedApp.listen((message) {
  Adshift.instance.handlePushNotification(message.data);
});

final initial = await FirebaseMessaging.instance.getInitialMessage();
if (initial != null) {
  await Adshift.instance.handlePushNotification(initial.data);
}
```

`handlePushNotification()` answers `true` when the payload carried an AdShift link; the result then arrives through `onDeepLink` with the source `push`. The link must be a RightLink link with `pid` and `c` (or `campaign`), or a RightLink short link. A payload handed over twice counts once.

- **Hand over taps only, not deliveries.** The call records a tap.
- A background message handler runs in [another engine](#one-engine), where the call does nothing.
- When the payload is known at launch, hand it over before `start()`, so the launch is attributed to the push.

---

## Consent

Set consent on every launch, before `start()`, and again whenever the user changes it. With a consent dialog, call `start()` after the user has answered, so the link that opened the app is recorded under that consent.

### Manual consent

```dart
// A user the GDPR applies to. An omitted flag counts as not decided.
Adshift.instance.setConsentData(
  const AdshiftConsent.forGDPRUser(
    hasConsentForDataUsage: true,
    hasConsentForAdsPersonalization: false,
    hasConsentForAdStorage: true,
  ),
);

// A user the GDPR does not apply to: all processing counts as permitted.
Adshift.instance.setConsentData(const AdshiftConsent.forNonGDPRUser());
```

Each flag is `true` (granted), `false` (denied) or `null` (not decided). `consent.isConsentGranted()` applies the SDK's rule: always for a non-GDPR user; a GDPR user must have granted both data usage and ad storage.

### TCF 2.2 with a consent platform

```dart
Adshift.instance.enableTCFDataCollection(true); // before start()
await showConsentDialog(); // your consent platform
await Adshift.instance.start();

// Whenever the consent dialog closes again later:
final snapshot = await Adshift.instance.refreshConsent();
```

### GPP (US state privacy)

`enableGPPDataCollection(true)`, before `start()`, reads the IAB GPP string your consent platform wrote, in addition to the GDPR consent. It does not decide whether the advertising id is used.

### Third-party sharing

Unlike consent, no answer means sharing is allowed. So state it only once the user was actually asked: an `allowed()` set at startup as a default records an answer the user never gave, and events already sent are not recalled when a real answer arrives.

```dart
// The user asked not to have their data passed on to advertising partners.
Adshift.instance.setThirdPartySharing(const AdshiftThirdPartySharing.optedOut());

// The user was asked and did not opt out.
Adshift.instance.setThirdPartySharing(const AdshiftThirdPartySharing.allowed());

// Back to no answer on record, which is not the same as allowed().
Adshift.instance.clearThirdPartySharing();
```

### The snapshot

`refreshConsent()` reads consent again and returns it as the SDK applies it, or `null` before `initialize()`.

| Field | Type | Meaning |
|---|---|---|
| `source` | `AdshiftConsentSource` | `manual`, `tcf`, `gpp` or `none`: what decided the GDPR consent. Manual consent outranks TCF |
| `gdprApplies` | `int?` | The IAB `gdprApplies` value, 0 or 1, when known |
| `tcStringPresent` | `bool` | Whether a TCF consent string is on the device |
| `gppPresent` | `bool?` | Whether a GPP string is on the device, when known |
| `cmpDetected` | `bool` | Whether a consent platform has run on this device |
| `adUserDataEnabled`, `adPersonalizationEnabled`, `adStorageEnabled` | `bool?` | The three flags. They read differently on each platform |
| `appliedAtMillis` | `int` | When the snapshot was applied, in milliseconds since the epoch |
| `adIdentifiersAllowed` | `bool` | Whether consent lets the SDK use the advertising id |

- **Read `adIdentifiersAllowed`, not the flags.** It answers for GAID or OAID on Android and IDFA on iOS, and the platforms judge the flags by different rules. The AdShift device id is never affected.
- **`cmpDetected`** tells a consent platform the user has not answered yet from no consent platform at all: `false` while you expect one means it never ran or is not wired up; `true` with a `source` of `none` means it ran and the user has not answered.

---

## Configuration

### `AdshiftConfig`

| Option | Type | Platform | Default | Notes |
|---|---|---|---|---|
| `apiKey` | `String` | both | required | API key of this platform's app |
| `isDebug` | `bool` | both | off | Verbose SDK logging. On Android an explicit `false` also silences the SDK's informational logs and warnings |
| `appOpenDebounceMs` | `int` | both | `10000` | Debounce for automatic `app_open` events, in milliseconds; not negative |
| `brandedDomains` | `List<String>` | both | none | Your own link domains; without it their links are `notFound` and not counted as clicks |
| `testMode` | `bool` | both | off | Marks every click and event as test traffic, kept out of your reports. A debug build does not turn it on |
| `metaAppId` | `String` | Android | none | Meta app id, for attributing installs from Meta ads |
| `pushDeepLinkPaths` | `List<List<String>>` | both | `[['as_push_link']]` | Key paths in push payloads that carry an AdShift link |
| `autoHandleDeepLinks` | `bool` | both | on | Passes every link that opens the app to the SDK |
| `disableSKAN` | `bool` | iOS | off | Turns the SKAdNetwork integration off |
| `waitForATTBeforeStart` | `bool` | iOS | off | Only when **your app** shows the ATT prompt |
| `attTimeoutMs` | `int` | iOS | `30000` | Longest wait for the ATT answer, in milliseconds; not negative, clamped to 5000–120000 |
| `deferredDeepLinkClipboard` | `AdshiftDeferredDeepLinkClipboard` | iOS | `disabled` | See [Deferred deep links](#deferred-deep-links) |
| `collectOaid` | `bool` | Android | on | OAID on devices without Google Play services |
| `onError` | `void Function(AdshiftError)` | both | none | See [Results Instead of Exceptions](#results-instead-of-exceptions) |

### Settings

These calls return nothing. A value that fails validation (a blank string, a negative interval) is skipped and reported to `onError`. A call made before `initialize()` is kept and applied by it; where the config sets the same option, the config wins.

| Call | What it does |
|---|---|
| `setCustomerUserId(String userId)` | Sets your own user id; see [Identity](#identity) |
| `setDebugEnabled(bool enabled)` | Turns verbose SDK logging on or off |
| `setAppOpenDebounceMs(int ms)` | Sets the debounce for automatic `app_open` events, in milliseconds |
| `setBrandedDomains(List<String> domains)` | Sets your own link domains. Call it before `initialize()`, or use `brandedDomains` in the config: set later, they do not apply to the link that opened the app |
| `setMetaAppId(String appId)` | Sets the Meta app id, for attributing installs from Meta ads; call it before `start()`. Android; does nothing on iOS |
| `setOaidData(String oaid)` | Passes an OAID your app obtained itself; set `collectOaid: false` as well. Android; does nothing on iOS |
| `addPushNotificationDeepLinkPath(List<String> path)` | Adds a key path in push payloads that carries an AdShift link. Call it before `initialize()`, or use `pushDeepLinkPaths` in the config; see [Push Notifications](#push-notifications) |

---

## Identity

- **`setCustomerUserId(userId)`** — your own user id. May be called at any time; call it before `start()` to have it on the install. Set it on every launch.
- **`getAdShiftDeviceId()`** → `Future<String?>` — the AdShift id of this device, for connecting other tools to AdShift. `null` before `initialize()`. Consent does not affect it.

---

## Platform Setup

`MainActivity`, `AppDelegate` and `SceneDelegate` stay as Flutter created them: the plugin needs no native code.

### iOS

**1. Deployment target** — 15.0, see [Installation](#installation).

**2. Universal Links and URL scheme** — add the Associated Domains capability to the Runner target with `applinks:yourbrand.rightlink.me`, and one entry per branded domain. Then choose your set-up [next to Flutter's deep linking](#next-to-flutters-deep-linking-and-other-link-plugins): with the defaults and no router, iOS reopens a Universal Link in the browser. A URL scheme goes in `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>yourapp</string>
    </array>
  </dict>
</array>
```

**3. App Tracking Transparency** — the plugin does not show the ATT prompt. If your app shows it, add `NSUserTrackingUsageDescription` to `Info.plist` and set `waitForATTBeforeStart: true`; the first events then wait for the answer, at most `attTimeoutMs`. If your app does not prompt, leave the option off, or it only delays your first events.

**4. SKAdNetwork and AdAttributionKit postbacks** — add to `Info.plist`:

```xml
<key>NSAdvertisingAttributionReportEndpoint</key>
<string>https://adshift.com</string>
<key>AttributionCopyEndpoint</key>
<string>https://adshift.com</string>
<key>EligibleForAdAttributionKitReengagementPostbackCopies</key>
<true/>
```

`NSAdvertisingAttributionReportEndpoint` sends AdShift copies of the SKAdNetwork postbacks, `AttributionCopyEndpoint` copies of the AdAttributionKit install postbacks (iOS 17.4 and later), and the boolean adds the re-engagement copies.

**5. Privacy manifest** — the SDK's privacy manifest comes with the plugin and is part of your app's privacy report in Xcode. There is nothing to add. For App Store Connect, see [Store Privacy Declarations](#store-privacy-declarations).

**6. Paste button** — `AdshiftDeferredDeepLinkClipboard.pasteControl` needs your app's own native `UIPasteControl`; see [Deferred deep links](#deferred-deep-links).

### Android

**1. Requirements** — `minSdk` 24, `compileSdk` 35 or higher.

**2. App Links and URL scheme** — add the intent filters to `MainActivity` in `android/app/src/main/AndroidManifest.xml`:

```xml
<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="yourbrand.rightlink.me" />
</intent-filter>

<intent-filter>
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="yourapp" />
</intent-filter>
```

**3. Permissions** — the SDK's manifest declares `INTERNET`, `ACCESS_NETWORK_STATE` and `com.google.android.gms.permission.AD_ID`, plus two permissions and a set of `<queries>` entries used to read the OAID on devices without Google Play services. All of them merge into your app. Apps in the Families program, and any app directed to children, must remove `AD_ID`:

```xml
<uses-permission android:name="com.google.android.gms.permission.AD_ID" tools:node="remove" />
```

The line needs `xmlns:tools="http://schemas.android.com/tools"` on `<manifest>`. Without the permission the advertising id is not read. The OAID permissions and queries can be removed the same way; see [OAID](https://dev.adshift.com/docs/android-sdk/oaid).

**4. Backup rules** — the SDK's manifest sets `android:fullBackupContent` and `android:dataExtractionRules` on `<application>`, so its identifiers are never restored on a new install. An app created by Flutter declares neither and merges cleanly. If your app declares its own rules, the build fails with a manifest merger conflict. Then do both:

- add `tools:replace="android:fullBackupContent,android:dataExtractionRules"` to `<application>`;
- copy the SDK's exclusions into your own rules files, because `tools:replace` discards the SDK's: the shared preferences file `adshift_prefs.xml` and the files `adshift_event_buffer.json`, `adshift_event_buffer.json.tmp`, `adshift_click_buffer.json` and `adshift_click_buffer.json.tmp`. The rules to copy are on [Backup rules](https://dev.adshift.com/docs/android-sdk/backup).

**5. Dependencies the SDK brings** — `okhttp 4.12`, `retrofit 2.9`, `gson 2.10`, `installreferrer 2.2`, `play-services-ads-identifier 18.0.1`, `androidx.lifecycle:lifecycle-process`, `androidx.startup:startup-runtime`. Gradle resolves a conflict to the highest version; if your app pins `okhttp` below 4.12, raise it.

**6. Code shrinking** — the SDK ships its own R8 rules, so a release build needs no keep rules from you. Do not add `-keep class com.adshift.sdk.** { *; }`: it is not needed and keeps the whole SDK in your app unshrunk. SDK frames in crash reports arrive obfuscated; upload your release `mapping.txt`.

**7. Devices without Google Play services** — the SDK reads the OAID itself while `collectOaid` is on, the default. If your app already obtains it, pass it with `setOaidData(oaid)` and set `collectOaid: false`.

---

## Store Privacy Declarations

Both stores ask the publisher to declare what the app collects, and that includes what the SDK sends on your behalf. The plugin itself collects nothing: it passes your calls to the native SDK. The tables say which declarations follow from installing the SDK and which apply only if your app makes a particular call. The wording of your forms is yours to decide; this is the input, not the answer.

**Always sent, once the SDK starts**

| What | Apple App Privacy | Google Play Data safety |
| --- | --- | --- |
| The SDK's install identifier, the vendor identifier on iOS, and the advertising id when consent and platform settings allow it | Identifiers → Device ID | Device or other IDs |
| Installs, app opens and foreground time | Usage Data → Product Interaction | App activity → App interactions |
| Device model, OS version, language, carrier, connection type | Usage Data | App info and performance |
| The opening URL when the app is launched from a link | Usage Data → Other Usage Data | App activity → Other actions |
| The consent state you reported, including the IAB TC string when one is present, and the ATT status on iOS | Usage Data → Other Usage Data | App info and performance |

**Only if your app calls it**

| Your call | Apple App Privacy | Google Play Data safety |
| --- | --- | --- |
| `setCustomerUserId` | Identifiers → User ID | Personal info → User IDs |
| `trackPurchase` | Purchases → Purchase History | Financial info → Purchase history |
| `logAdRevenue` | Usage Data → Advertising Data | App activity → Other actions |
| `trackEvent` with your own parameters | depends on what you put in them | depends on what you put in them |

Notes that decide several rows for you:

- **The advertising id is optional in practice.** On Android it is read only while the `AD_ID` permission is present (see [Platform Setup → Android](#android)); on iOS only after the user allows tracking through ATT. Removing the permission, or never showing the ATT prompt, keeps the identifier out of your declaration. Attribution continues on the SDK's own install identifier, which is still collected.
- **Consent gates it too.** When you report a refusal through the consent API, the advertising id is withheld; `refreshConsent()` returns `adIdentifiersAllowed` so you can see the current answer.
- **No location permission or API is used.** The iOS SDK's privacy manifest declares Coarse Location; check your App Privacy answers against the privacy report Xcode generates.
- **Custom event parameters are yours.** Whatever you pass to `trackEvent` is sent as you wrote it, so anything personal in there belongs in your declaration.
- **Only a RightLink link is sent, and only its attribution parameters.** Any other key of its query stays on the device, in `params`. A URL that is not a RightLink link is not sent at all.
- **Everything travels over HTTPS.**

Whether your app's data counts as "shared" under Google Play's definition, and whether the identifiers are used for tracking under Apple's definition, depends on your agreement with AdShift rather than on the SDK. Settle those two with us before you submit.

---

## Testing

`package:adshift_flutter_sdk/testing.dart` has `AdshiftFake`, a stand-in for the SDK in your own tests. It calls no native code, records every call, answers with the values you set on it, and delivers the deep links your test emits.

```dart
import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:adshift_flutter_sdk/testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AdshiftFake adshift;

  setUp(() {
    adshift = AdshiftFake();
    Adshift.instance = adshift;
  });

  test('routes on a found link', () {
    final opened = <String?>[];
    Adshift.instance.onDeepLink.listen((link) {
      if (link.status == AdshiftDeepLinkStatus.found) {
        opened.add(link.deepLinkValue);
      }
    });

    adshift.emitDeepLink(
      const AdshiftDeepLink.found(
        deepLink: 'https://yourbrand.rightlink.me/promo',
        deepLinkValue: 'promo',
      ),
    );

    expect(opened, ['promo']);
  });

  test('tracks a purchase', () async {
    adshift.trackingResult = const AdshiftResult.failure(
      AdshiftError(AdshiftErrorCode.notStarted, 'stopped'),
    );

    final result = await Adshift.instance.trackPurchase(
      productId: 'premium_monthly',
      revenue: 9.99,
      currency: 'USD',
      transactionId: 'txn-1',
    );

    expect(result.success, isFalse);
    expect(adshift.calls.single.method, 'trackPurchase');
    expect(adshift.calls.single.arguments['revenue'], 9.99);
  });
}
```

- `calls` lists every call in order, each with its `method` name and its `arguments` by parameter name.
- `startResult`, `trackingResult`, `consentSnapshot`, `deviceId` and `pushNotificationResult` set what the fake answers.
- `emitDeepLink(link)` delivers to the current `onDeepLink` listeners before it returns; `reset()` returns the fake to its state at creation.
- The fake checks no arguments and holds no calls back until `start()`.

---

## Upgrading from 1.x

2.0.0 is built on Android SDK 4.2.0 and iOS SDK 3.1.0 and is not source-compatible with 1.x. The changes that matter:

- **New names.** `AdshiftFlutterSdk.instance` is now `Adshift.instance`, `onDeepLinkReceived` is `onDeepLink`, and `isStarted` is a getter.
- **Results instead of exceptions.** Nothing throws. `start()` and the tracking calls return a result, the other calls return nothing (drop their `await`), and every other problem goes to `onError`. Do not await `start()` before the first frame. See [Results Instead of Exceptions](#results-instead-of-exceptions).
- **`handleDeepLink()` answers through the stream.** It returns nothing; the result arrives at `onDeepLink`.
- **Navigate only on `found`.** Only a RightLink link is `found`. Any other URL, your app's own links included, comes back `notFound` with the URL in `deepLink`. Declare your own link domains in `brandedDomains`.
- **Links are forwarded automatically.** Remove the code that passed incoming URLs to `handleDeepLink()`, or keep it and set `autoHandleDeepLinks: false`.
- **New minimum versions.** Flutter 3.44, Dart 3.12, Android API 24 with `compileSdk` 35, iOS 15.0 with Xcode 16.1. The plugin now carries the iOS SDK: remove `pod 'AdshiftSDK'` from your `Podfile`.

Then go through [Platform Setup](#platform-setup). The [changelog](CHANGELOG.md) lists every change.

---

## Example App

```sh
cd example
flutter run --dart-define=ADSHIFT_API_KEY=<your key>
```

The example calls the main parts of the plugin and prints what comes back. It runs in test mode, so its traffic stays out of your reports. It routes from `onDeepLink` with Flutter's own deep linking turned off, the first set-up in [Next to Flutter's deep linking](#next-to-flutters-deep-linking-and-other-link-plugins).

---

## Troubleshooting

**The iOS build says the plugin requires a higher minimum deployment version, or that `adshift-flutter-sdk` requires minimum platform version 15.0** — raise the app's iOS deployment target to 15.0 ([Installation](#installation)).

**`pod install` stops with `The 'Pods-Runner' target has frameworks with conflicting names: adshiftsdk.xcframework`, or Swift Package Manager reports targets with the conflicting name `AdshiftSDK`** — your app adds the AdShift iOS SDK next to the copy inside the plugin. Remove `pod 'AdshiftSDK'` from the `Podfile`, or the `ios-sdk` package from the Xcode project.

**Manifest merger conflict on `fullBackupContent` or `dataExtractionRules`** — your app declares its own backup rules; see [Backup rules](#android).

**My own links arrive as `notFound`** — that is the contract: only RightLink links are `found`. Route your own links from `deepLink`.

**A link on my own domain arrives as `notFound`** — add the domain to `brandedDomains` in `initialize()`.

**iOS: a Universal Link opens the app and then the browser** — Flutter's own deep linking is on and the app has no `Navigator` or `Router` to take the route. Turn it off; see [Next to Flutter's deep linking](#next-to-flutters-deep-linking-and-other-link-plugins).

**A link ends on an unknown route, or navigates twice** — Flutter's own deep linking hands the same URL to your router. Make the router ignore AdShift links, or turn Flutter's deep linking off; see the same section.

**iOS: links do not reach `onDeepLink`** — something handles the link before the plugin sees it: another link plugin, or an `AppDelegate` that overrides `application(_:open:options:)` or `application(_:continue:restorationHandler:)` without calling `super`. Call `super`, or pass the link in yourself with `handleDeepLink()`.

**Nothing happens in a background message handler** — it runs in another Flutter engine, where the plugin does nothing; see [One engine](#one-engine).

**`await trackEvent(...)` never completes** — the call is waiting for `start()`. Call `start()` on every launch path, and do not await a tracking call before it.

**The first events on iOS arrive late** — `waitForATTBeforeStart: true` without an ATT prompt holds them for `attTimeoutMs`. Set the option only when your app shows the prompt.

**Events are not sent** — check that `start()` answered `success: true`, register `onError`, and turn on `isDebug` to read the SDK's logs (Logcat tags `AdShiftSDK` and `AdShiftFlutter` on Android, the Xcode console on iOS). On Android a rejected API key fails `start()` with `INVALID_API_KEY`; on iOS it is usually not reported to the app and shows only in the SDK's log. iOS and Android have separate keys.

---

## Support

- Documentation: https://dev.adshift.com/docs/flutter-plugin
- Issues: https://github.com/AdShift/flutter_plugin/issues
- Email: support@adshift.com

---

## License

This SDK is proprietary software. See [LICENSE](LICENSE) for details.

© 2024-2026 AdShift. All rights reserved.
