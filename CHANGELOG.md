# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-01-01

### Added

- **Initial release** of AdShift Flutter SDK
- Full iOS and Android platform support
- SDK lifecycle management (`initialize`, `start`, `stop`, `isStarted`)
- In-app event tracking with 25+ predefined event types
- Purchase tracking with revenue attribution
- GDPR/DMA consent management
  - Manual consent via `AdshiftConsent`
  - TCF 2.2 automatic collection
  - `refreshConsent()` for runtime updates
- Deep linking support
  - Direct deep links
  - Deferred deep links
  - Event stream for real-time deep link notifications
- Customer User ID support
- Debug mode for development
- App open debounce configuration
- SKAdNetwork 4.0+ support (iOS)
- OAID collection support (Android, optional)

### Platform Requirements

- iOS 15.0+
- Android API 21+
- Flutter 3.3.0+
- Dart 3.0.0+

### Dependencies

- iOS: AdshiftSDK (via CocoaPods)
- Android: com.adshift:android-sdk:2.0.2 (via Maven Central)
