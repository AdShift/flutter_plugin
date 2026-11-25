/// Mediation platform that reported an ad impression, for
/// `Adshift.instance.logAdRevenue()`.
enum AdshiftMediationNetwork {
  /// AppLovin MAX.
  appLovinMax('applovin_max'),

  /// Google AdMob.
  googleAdMob('google_admob'),

  /// ironSource.
  ironSource('ironsource'),

  /// Chartboost.
  chartboost('chartboost'),

  /// TopOn.
  topOn('topon'),

  /// TradPlus.
  tradPlus('tradplus'),

  /// AdMost.
  adMost('admost'),

  /// Appodeal.
  appodeal('appodeal'),

  /// Fyber.
  fyber('fyber'),

  /// Unity.
  unity('unity'),

  /// Yandex.
  yandex('yandex'),

  /// Your own mediation.
  customMediation('custom_mediation'),

  /// A network integrated directly, without mediation.
  directMonetization('direct_monetization_network'),

  /// Any other platform.
  other('other');

  const AdshiftMediationNetwork(this.wireName);

  /// The value as it appears in reports.
  final String wireName;
}
