# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Native SDK matrix

| Plugin | Android SDK | iOS SDK |
|---|---|---|
| 2.0.0 | 4.2.0 | 3.1.0 |
| 1.0.1 | 2.0.3 | 1.x |
| 1.0.0 | 2.0.3 | 1.x |

## [2.0.0-rc.1]

Breaking release on Android SDK 4.2.0 and iOS SDK 3.1.0, not source-compatible with 1.x. See "Upgrading from 1.x" in the README.

### Added
- `Adshift.instance.logAdRevenue()` with `AdshiftMediationNetwork`, and `AdshiftEventType.adRevenue`.
- `AdshiftEventParam` with the 81 standard parameter names reports add up, and `AdshiftEventParam.all`. In debug builds `trackEvent()` and the extra parameters of `logAdRevenue()` warn once per name when a key is the plain spelling of a standard name (`price`, `contentId`). Values are always sent as given.
- Results with error codes: `AdshiftStartResult` from `start()`, `AdshiftResult` from `trackEvent()`, `trackPurchase()` and `logAdRevenue()`, `AdshiftError` with `AdshiftErrorCode` (`NOT_INITIALIZED`, `NOT_STARTED`, `INVALID_API_KEY`, `OPTED_OUT`, `QUEUE_FULL`, `INVALID_ARGUMENT`, `UNKNOWN`), and `AdshiftConfig.onError` for everything that has no result.
- Automatic deep link forwarding, on by default (`AdshiftConfig.autoHandleDeepLinks`): the plugin passes every link that opens the app to the SDK on both platforms, with no native code in the app.
- RightLink deep linking: `AdshiftConfig.brandedDomains` and `setBrandedDomains()`; `AdshiftDeepLink.deepLinkValue`, `deepLinkSub1` … `deepLinkSub5`, `source` (`AdshiftDeepLinkSource`), `clickId`, `isFirstSession` and, on iOS, `matchGuaranteed`.
- iOS: the deferred deep link from the clipboard, for RightLink templates with the clipboard option: `AdshiftConfig.deferredDeepLinkClipboard` and `handlePastedDeepLink()`.
- Push notification links: `handlePushNotification()`, `addPushNotificationDeepLinkPath()` and `AdshiftConfig.pushDeepLinkPaths`.
- Consent: `enableGPPDataCollection()`, `setThirdPartySharing()` and `clearThirdPartySharing()` with `AdshiftThirdPartySharing`, and `AdshiftConsentSnapshot` returned by `refreshConsent()`, with `adIdentifiersAllowed` and `cmpDetected`.
- `AdshiftConfig.testMode`: marks every click and event as test traffic, kept out of your reports.
- `getAdShiftDeviceId()`, `getInfo()` and the constant `adshiftPluginVersion`.
- Android: `AdshiftConfig.metaAppId` and `setMetaAppId()`; `setOaidData()` for an OAID the app obtained itself.
- `package:adshift_flutter_sdk/testing.dart` with `AdshiftFake`, a stand-in for the SDK in your own tests.
- iOS: Swift Package Manager. The plugin builds with it and with CocoaPods.
- Tracking calls made between `initialize()` and a successful `start()` wait, up to 100, and are sent in order.
- Settings made before `initialize()` are kept and applied by it.

### Changed
- `AdshiftFlutterSdk` is now `Adshift`, and `onDeepLinkReceived` is `onDeepLink`.
- **No call throws, and no returned `Future` completes with an error.** `start()` and the tracking calls answer with a result; every other problem is reported to `AdshiftConfig.onError`.
- `initialize()`, `stop()`, `setCustomerUserId()`, `setDebugEnabled()`, `setAppOpenDebounceMs()`, `setConsentData()` and `enableTCFDataCollection()` return nothing instead of a `Future`. `isStarted` is a getter.
- `start()` returns `AdshiftStartResult`. On Android it waits up to 5 seconds for the check of the API key, so do not await it before the first frame, and a rejected key fails it with `INVALID_API_KEY`. On iOS it answers before the key is checked, usually with `pending`, so a rejected key is usually not reported to the app. A device with tracking turned off answers `OPTED_OUT`.
- `trackEvent()` and `trackPurchase()` return `AdshiftResult`. Success means the SDK accepted the event into its queue. `values` is a `Map<String, Object>` of strings, numbers and booleans. The names `app_install` and `app_open` are refused.
- `handleDeepLink()` completes at once and carries no result; every result arrives through `onDeepLink`, each one once. Results that arrive while nobody listens wait for the next listener.
- **Navigate only on `found`.** `found` now means a RightLink link (your `*.rightlink.me` host or a domain in `brandedDomains`) or a deferred deep link with a value. Any other URL, your app's own scheme included, comes back `notFound` with the URL in `deepLink` and no `params`.
- A short link that cannot be resolved yet comes as `error`, and `found` follows once it resolves.
- The deferred deep link answers within 5 seconds of `start()`: the link, `notFound` or `error`. On iOS a deferred result has no `deepLink`; route on `deepLinkValue`.
- `AdshiftDeepLink.params` is a `Map<String, String>`.
- Consent flags have three states: `true`, `false` and not decided. `AdshiftConsent.forGDPRUser()` takes each flag optionally, `isConsentGranted()` needs an explicit `true` for data usage and ad storage, and `AdshiftConsent.forNonGDPRUser()` no longer reports the flags as granted.
- `refreshConsent()` returns the consent snapshot.
- An option left out of `AdshiftConfig` keeps the native SDK's default; `isDebug` and `appOpenDebounceMs` no longer have defaults of their own.
- `initialize()` keeps the first config; later calls are ignored.
- Only the Flutter engine that shows the app's UI can use the plugin. In another engine, such as a background message handler, calls do nothing and `start()` answers `NOT_INITIALIZED`.
- Minimum Flutter 3.44 and Dart 3.12; Android API 24 with `compileSdk` 35; iOS 15.0 with Xcode 16.1.
- iOS: the AdShift iOS SDK comes inside the plugin. Do not add `AdshiftSDK` yourself, neither with CocoaPods nor with Swift Package Manager; if your `Podfile` has `pod 'AdshiftSDK'`, remove the line. Your own native code can still `import AdshiftSDK`.
- iOS: your app carries the SDK's privacy manifest, which declares Device ID, User ID, Product Interaction, Advertising Data, Coarse Location, Purchase History and Other Diagnostic Data. Review your App Privacy answers.
- iOS: add the three postback keys to `Info.plist`: `NSAdvertisingAttributionReportEndpoint`, `AttributionCopyEndpoint` and `EligibleForAdAttributionKitReengagementPostbackCopies`.
- Android: the SDK's manifest sets backup rules. An app that declares its own `fullBackupContent` or `dataExtractionRules` must merge them with the SDK's.
- Android: a release build needs no keep rules of your own. Remove a hand-written `-keep class com.adshift.sdk.** { *; }`.
- Android: the SDK no longer brings AppCompat and Material into your app.

### Removed
- The unnamed `AdshiftConsent(...)` constructor; use `forGDPRUser()` or `forNonGDPRUser()`.
- `toMap()` and `fromMap()` on `AdshiftConfig`, `AdshiftConsent` and `AdshiftDeepLink`.

## [1.0.1] - 2026-01-05

### Fixed
- Android: a crash when a deep link result arrived on a background thread.

## [1.0.0] - 2026-01-01

### Added
- Lifecycle: `initialize()`, `start()`, `stop()`, `isStarted()`.
- `trackEvent()` with 29 standard event names (`AdshiftEventType`), and `trackPurchase()`.
- Consent: `setConsentData()` with `AdshiftConsent`, `enableTCFDataCollection()` for TCF 2.2, `refreshConsent()`.
- Deep links: the `onDeepLinkReceived` stream and `handleDeepLink()`.
- `setCustomerUserId()`, `setDebugEnabled()`, `setAppOpenDebounceMs()`.
- iOS: SKAdNetwork, with `disableSKAN`, `waitForATTBeforeStart` and `attTimeoutMs`. Android: `collectOaid`.
