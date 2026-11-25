/// Where the consent the SDK applies came from.
enum AdshiftConsentSource {
  /// `Adshift.instance.setConsentData()`.
  manual,

  /// An IAB TCF v2.2 consent platform.
  tcf,

  /// An IAB GPP string written by the consent platform.
  gpp,

  /// No consent information.
  none,
}

/// Consent as the SDK applies it, returned by
/// `Adshift.instance.refreshConsent()`.
final class AdshiftConsentSnapshot {
  /// Creates a snapshot, for example for a test.
  const AdshiftConsentSnapshot({
    required this.source,
    this.gdprApplies,
    required this.tcStringPresent,
    this.gppPresent,
    required this.cmpDetected,
    this.adUserDataEnabled,
    this.adPersonalizationEnabled,
    this.adStorageEnabled,
    required this.appliedAtMillis,
    required this.adIdentifiersAllowed,
  });

  /// Where the consent came from.
  final AdshiftConsentSource source;

  /// The IAB `gdprApplies` value (0 or 1), when known.
  final int? gdprApplies;

  /// Whether a TCF consent string is present on the device.
  final bool tcStringPresent;

  /// Whether a GPP string is present on the device, when known.
  final bool? gppPresent;

  /// Whether a consent platform has run on this device. False while you
  /// expect one: it never ran or is not wired up. True with a [source] of
  /// [AdshiftConsentSource.none]: it ran and the user has not answered yet.
  final bool cmpDetected;

  /// The ad user data flag. Android leaves an undecided flag null; iOS always
  /// gives a boolean, an undecided flag reading false under GDPR and true
  /// outside it. For a decision read [adIdentifiersAllowed].
  final bool? adUserDataEnabled;

  /// The ad personalisation flag; undecided as for [adUserDataEnabled].
  final bool? adPersonalizationEnabled;

  /// The ad storage flag; undecided as for [adUserDataEnabled].
  final bool? adStorageEnabled;

  /// When the snapshot was applied, in milliseconds since the epoch.
  final int appliedAtMillis;

  /// Whether consent lets the SDK attach the advertising id (GAID or OAID on
  /// Android, IDFA on iOS). The platforms judge the flags by different rules,
  /// so read this, not the flags.
  final bool adIdentifiersAllowed;

  @override
  String toString() =>
      'AdshiftConsentSnapshot(source: ${source.name}, '
      'gdprApplies: $gdprApplies, tcStringPresent: $tcStringPresent, '
      'gppPresent: $gppPresent, cmpDetected: $cmpDetected, '
      'adUserDataEnabled: $adUserDataEnabled, '
      'adPersonalizationEnabled: $adPersonalizationEnabled, '
      'adStorageEnabled: $adStorageEnabled, '
      'appliedAtMillis: $appliedAtMillis, '
      'adIdentifiersAllowed: $adIdentifiersAllowed)';
}
