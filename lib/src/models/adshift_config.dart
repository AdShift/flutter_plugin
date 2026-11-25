import 'adshift_error.dart';

/// Whether the first launch on iOS reads the deferred deep link a RightLink
/// page copied to the clipboard.
enum AdshiftDeferredDeepLinkClipboard {
  /// The clipboard is not read.
  disabled,

  /// The SDK reads the clipboard; iOS asks the user to allow the paste, once
  /// per install.
  prompt,

  /// Your onboarding shows `UIPasteControl` and passes the result to
  /// `Adshift.instance.handlePastedDeepLink()`.
  pasteControl,
}

/// Options for `Adshift.instance.initialize()`. An omitted option keeps the
/// native SDK default.
final class AdshiftConfig {
  /// Creates the options; only [apiKey] is required.
  const AdshiftConfig({
    required this.apiKey,
    this.isDebug,
    this.appOpenDebounceMs,
    this.brandedDomains,
    this.testMode,
    this.metaAppId,
    this.pushDeepLinkPaths,
    this.autoHandleDeepLinks,
    this.disableSKAN,
    this.waitForATTBeforeStart,
    this.attTimeoutMs,
    this.deferredDeepLinkClipboard,
    this.collectOaid,
    this.onError,
  });

  /// API key from the AdShift dashboard.
  final String apiKey;

  /// Verbose SDK logging. Default: off.
  final bool? isDebug;

  /// Debounce interval for automatic `app_open` events, in milliseconds; not
  /// negative. Default: 10000.
  final int? appOpenDebounceMs;

  /// Your own link domains, e.g. `links.example.com`. Without this a link on
  /// such a domain comes back `notFound` and is not counted as a click.
  final List<String>? brandedDomains;

  /// Marks every click and event as test traffic, which is kept out of
  /// reports, postbacks and billing. A debug build does not turn it on.
  /// Default: off.
  final bool? testMode;

  /// Meta app id used to parse Meta App Links. Android only.
  final String? metaAppId;

  /// Key paths inside a push notification payload that carry an AdShift deep
  /// link, e.g. `[['data', 'as_push_link']]`. Your own paths take over from
  /// the top-level `as_push_link` the SDK reads by default, so list that key
  /// too if your payloads also use it.
  final List<List<String>>? pushDeepLinkPaths;

  /// Passes every link that opens the app to the SDK. Set to false to call
  /// `Adshift.instance.handleDeepLink()` yourself. Default: on.
  final bool? autoHandleDeepLinks;

  /// Turns the SKAdNetwork integration off. iOS only. Default: off.
  final bool? disableSKAN;

  /// Waits for the App Tracking Transparency answer before the first install
  /// or open event is sent. Only useful when the app requests ATT itself.
  /// iOS only. Default: off.
  final bool? waitForATTBeforeStart;

  /// Longest wait for the ATT answer, in milliseconds; not negative, and
  /// values outside 5000–120000 are clamped. iOS only. Default: 30000.
  final int? attTimeoutMs;

  /// Reads the deferred deep link from the clipboard on the first launch, for
  /// RightLink templates with the clipboard option. iOS only. Default:
  /// [AdshiftDeferredDeepLinkClipboard.disabled].
  final AdshiftDeferredDeepLinkClipboard? deferredDeepLinkClipboard;

  /// Collects the OAID on devices without Google Play services. Android only.
  /// Default: on.
  final bool? collectOaid;

  /// Called when the SDK declines a call: an invalid argument, an unusable
  /// config, a failed `start()`. On Android a rejected API key fails `start()`;
  /// on iOS a rejected key is not reported. No call throws; methods without a
  /// result report their problems only here.
  final void Function(AdshiftError error)? onError;

  /// The options that were set, with the API key masked.
  @override
  String toString() {
    final options = <String, Object?>{
      'apiKey': apiKey.length > 4 ? '${apiKey.substring(0, 4)}***' : '***',
      'isDebug': isDebug,
      'appOpenDebounceMs': appOpenDebounceMs,
      'brandedDomains': brandedDomains,
      'testMode': testMode,
      'metaAppId': metaAppId,
      'pushDeepLinkPaths': pushDeepLinkPaths,
      'autoHandleDeepLinks': autoHandleDeepLinks,
      'disableSKAN': disableSKAN,
      'waitForATTBeforeStart': waitForATTBeforeStart,
      'attTimeoutMs': attTimeoutMs,
      'deferredDeepLinkClipboard': deferredDeepLinkClipboard?.name,
      'collectOaid': collectOaid,
    }..removeWhere((_, value) => value == null);
    final described = options.entries.map((e) => '${e.key}: ${e.value}');
    return 'AdshiftConfig(${described.join(', ')})';
  }
}
