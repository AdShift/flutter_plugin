import 'package:flutter/foundation.dart';

/// Consent collected by your own UI, for `Adshift.instance.setConsentData()`.
///
/// Each flag is `true` (granted), `false` (denied) or null (not decided yet).
@immutable
final class AdshiftConsent {
  /// Consent of a user the GDPR applies to. An omitted flag counts as not
  /// decided.
  const AdshiftConsent.forGDPRUser({
    this.hasConsentForDataUsage,
    this.hasConsentForAdsPersonalization,
    this.hasConsentForAdStorage,
  }) : isUserSubjectToGDPR = true;

  /// A user the GDPR does not apply to: all processing counts as permitted.
  const AdshiftConsent.forNonGDPRUser()
    : isUserSubjectToGDPR = false,
      hasConsentForDataUsage = null,
      hasConsentForAdsPersonalization = null,
      hasConsentForAdStorage = null;

  /// Whether the GDPR applies to this user; the flags are ignored otherwise.
  final bool isUserSubjectToGDPR;

  /// Consent to using the user's data for advertising.
  final bool? hasConsentForDataUsage;

  /// Consent to personalised advertising.
  final bool? hasConsentForAdsPersonalization;

  /// Consent to storing advertising identifiers.
  final bool? hasConsentForAdStorage;

  /// Whether measurement is permitted: always for a non-GDPR user; a GDPR user
  /// must have granted both data usage and ad storage.
  bool isConsentGranted() =>
      !isUserSubjectToGDPR ||
      (hasConsentForDataUsage == true && hasConsentForAdStorage == true);

  @override
  bool operator ==(Object other) =>
      other is AdshiftConsent &&
      other.isUserSubjectToGDPR == isUserSubjectToGDPR &&
      other.hasConsentForDataUsage == hasConsentForDataUsage &&
      other.hasConsentForAdsPersonalization ==
          hasConsentForAdsPersonalization &&
      other.hasConsentForAdStorage == hasConsentForAdStorage;

  @override
  int get hashCode => Object.hash(
    isUserSubjectToGDPR,
    hasConsentForDataUsage,
    hasConsentForAdsPersonalization,
    hasConsentForAdStorage,
  );

  @override
  String toString() => isUserSubjectToGDPR
      ? 'AdshiftConsent.forGDPRUser(dataUsage: $hasConsentForDataUsage, '
            'adsPersonalization: $hasConsentForAdsPersonalization, '
            'adStorage: $hasConsentForAdStorage)'
      : 'AdshiftConsent.forNonGDPRUser()';
}
