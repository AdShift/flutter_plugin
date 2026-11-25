/// Outcome of a deep link the SDK looked at.
enum AdshiftDeepLinkStatus {
  /// A RightLink link, or a deferred deep link with a value. Navigate on this.
  found,

  /// Not a RightLink link, a deleted one, or no deferred deep link.
  notFound,

  /// Not resolved yet; the same link can still arrive as [found].
  error,
}

/// How a deep link reached the app.
enum AdshiftDeepLinkSource {
  /// A Universal Link, or a link the app passed in itself. iOS.
  universalLink('ul'),

  /// An App Link, or a link the app passed in itself. Android.
  appLink('app_link'),

  /// The app's own scheme; `found` only when it wraps a RightLink link in
  /// `as_rl`.
  scheme('scheme'),

  /// The open-in-app button of a RightLink page.
  cta('cta'),

  /// A push notification.
  push('push'),

  /// An AdAttributionKit re-engagement open. iOS.
  adAttributionKit('aak'),

  /// A link opened by a Meta app that is not a RightLink link. Android.
  metaAppLink('meta_applink'),

  /// The lookup on the first launch after install.
  deferred('deferred'),

  /// A web link that is not a RightLink link.
  foreign('foreign');

  const AdshiftDeepLinkSource(this.wireName);

  /// The value as written in the documentation and in reports.
  final String wireName;
}

/// A deep link result from `Adshift.instance.onDeepLink`.
///
/// Navigate only on a [status] of [AdshiftDeepLinkStatus.found], and validate
/// [deepLinkValue] first: anyone can write a link. Any other URL comes back
/// `notFound` with the URL in [deepLink]. Treat `error` as "not yet".
final class AdshiftDeepLink {
  /// Creates a result with any combination of fields, for example for a test.
  const AdshiftDeepLink({
    required this.status,
    this.isDeferred = false,
    this.deepLink,
    this.deepLinkValue,
    this.params,
    this.errorMessage,
    this.source,
    this.clickId,
    this.matchGuaranteed,
    this.isFirstSession,
    this.deepLinkSub1,
    this.deepLinkSub2,
    this.deepLinkSub3,
    this.deepLinkSub4,
    this.deepLinkSub5,
  });

  /// A link the app should navigate on.
  const AdshiftDeepLink.found({
    required String this.deepLink,
    this.deepLinkValue,
    this.params,
    this.isDeferred = false,
    this.isFirstSession,
    this.source,
    this.clickId,
    this.matchGuaranteed,
    this.deepLinkSub1,
    this.deepLinkSub2,
    this.deepLinkSub3,
    this.deepLinkSub4,
    this.deepLinkSub5,
  }) : status = AdshiftDeepLinkStatus.found,
       errorMessage = null;

  /// A result that carries no link.
  const AdshiftDeepLink.notFound()
    : this(status: AdshiftDeepLinkStatus.notFound);

  /// A link that could not be resolved yet.
  const AdshiftDeepLink.error(String message)
    : this(status: AdshiftDeepLinkStatus.error, errorMessage: message);

  /// The link as opened, a short link expanded. On iOS a deferred result has
  /// none: route on [deepLinkValue].
  final String? deepLink;

  /// Routing value, `deep_link_value`.
  final String? deepLinkValue;

  /// Query parameters of a RightLink link, your own keys included. Null for
  /// any other URL.
  final Map<String, String>? params;

  /// Whether this result comes from deferred deep linking (first launch).
  final bool isDeferred;

  /// Whether to navigate, see [AdshiftDeepLinkStatus].
  final AdshiftDeepLinkStatus status;

  /// Set when [status] is `error`; the wording differs per platform.
  final String? errorMessage;

  /// How the link reached the app.
  final AdshiftDeepLinkSource? source;

  /// Id of the click this open was attributed to. Null for a deferred result
  /// and when no click was recorded.
  final String? clickId;

  /// False when a deferred result is not certain to belong to this user: route
  /// them, but do not sign them in or grant a reward because of it. iOS only.
  final bool? matchGuaranteed;

  /// Whether the result came in the first session after install. [isDeferred]
  /// alone does not mean a new user.
  final bool? isFirstSession;

  /// Custom sub-parameter 1, `deep_link_sub1`.
  final String? deepLinkSub1;

  /// Custom sub-parameter 2, `deep_link_sub2`.
  final String? deepLinkSub2;

  /// Custom sub-parameter 3, `deep_link_sub3`.
  final String? deepLinkSub3;

  /// Custom sub-parameter 4, `deep_link_sub4`.
  final String? deepLinkSub4;

  /// Custom sub-parameter 5, `deep_link_sub5`.
  final String? deepLinkSub5;

  @override
  String toString() =>
      'AdshiftDeepLink(status: ${status.name}, isDeferred: $isDeferred, '
      'deepLink: $deepLink, deepLinkValue: $deepLinkValue, '
      'source: ${source?.wireName})';
}
