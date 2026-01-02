/// User consent data for GDPR/DMA compliance.
///
/// Use factory methods to create consent objects:
/// ```dart
/// // For GDPR users who accepted all
/// final consent = AdshiftConsent.forGDPRUser(
///   hasConsentForDataUsage: true,
///   hasConsentForAdsPersonalization: true,
///   hasConsentForAdStorage: true,
/// );
///
/// // For non-GDPR users
/// final consent = AdshiftConsent.forNonGDPRUser();
/// ```
class AdshiftConsent {
  /// Whether the user is subject to GDPR.
  final bool isUserSubjectToGDPR;

  /// Whether user has consented to data usage.
  final bool hasConsentForDataUsage;

  /// Whether user has consented to ads personalization.
  final bool hasConsentForAdsPersonalization;

  /// Whether user has consented to ad storage.
  final bool hasConsentForAdStorage;

  /// Creates a consent object with explicit values.
  /// 
  /// Prefer using factory methods [forGDPRUser] or [forNonGDPRUser].
  const AdshiftConsent({
    required this.isUserSubjectToGDPR,
    required this.hasConsentForDataUsage,
    required this.hasConsentForAdsPersonalization,
    required this.hasConsentForAdStorage,
  });

  /// Creates consent for a user subject to GDPR.
  /// 
  /// Use this when user is in a GDPR region and has provided explicit consent.
  /// 
  /// Example:
  /// ```dart
  /// final consent = AdshiftConsent.forGDPRUser(
  ///   hasConsentForDataUsage: true,
  ///   hasConsentForAdsPersonalization: true,
  ///   hasConsentForAdStorage: true,
  /// );
  /// ```
  factory AdshiftConsent.forGDPRUser({
    required bool hasConsentForDataUsage,
    required bool hasConsentForAdsPersonalization,
    required bool hasConsentForAdStorage,
  }) {
    return AdshiftConsent(
      isUserSubjectToGDPR: true,
      hasConsentForDataUsage: hasConsentForDataUsage,
      hasConsentForAdsPersonalization: hasConsentForAdsPersonalization,
      hasConsentForAdStorage: hasConsentForAdStorage,
    );
  }

  /// Creates consent for a user NOT subject to GDPR.
  /// 
  /// Use this when user is in a non-GDPR region (e.g., US, Asia).
  /// All consent flags are set to true by default.
  /// 
  /// Example:
  /// ```dart
  /// final consent = AdshiftConsent.forNonGDPRUser();
  /// ```
  factory AdshiftConsent.forNonGDPRUser() {
    return const AdshiftConsent(
      isUserSubjectToGDPR: false,
      hasConsentForDataUsage: true,
      hasConsentForAdsPersonalization: true,
      hasConsentForAdStorage: true,
    );
  }

  /// Determines whether consent is granted for tracking.
  /// 
  /// If user is not subject to GDPR, consent is assumed granted.
  /// If subject to GDPR, both data usage and ad storage must be granted.
  bool isConsentGranted() {
    if (!isUserSubjectToGDPR) return true;
    return hasConsentForDataUsage && hasConsentForAdStorage;
  }

  /// Converts consent to a Map for platform channel communication.
  Map<String, dynamic> toMap() {
    return {
      'isUserSubjectToGDPR': isUserSubjectToGDPR,
      'hasConsentForDataUsage': hasConsentForDataUsage,
      'hasConsentForAdsPersonalization': hasConsentForAdsPersonalization,
      'hasConsentForAdStorage': hasConsentForAdStorage,
    };
  }

  /// Creates consent from a Map (platform channel response).
  factory AdshiftConsent.fromMap(Map<String, dynamic> map) {
    return AdshiftConsent(
      isUserSubjectToGDPR: map['isUserSubjectToGDPR'] as bool? ?? false,
      hasConsentForDataUsage: map['hasConsentForDataUsage'] as bool? ?? false,
      hasConsentForAdsPersonalization: map['hasConsentForAdsPersonalization'] as bool? ?? false,
      hasConsentForAdStorage: map['hasConsentForAdStorage'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'AdshiftConsent(gdpr: $isUserSubjectToGDPR, dataUsage: $hasConsentForDataUsage, '
        'personalization: $hasConsentForAdsPersonalization, storage: $hasConsentForAdStorage)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AdshiftConsent &&
        other.isUserSubjectToGDPR == isUserSubjectToGDPR &&
        other.hasConsentForDataUsage == hasConsentForDataUsage &&
        other.hasConsentForAdsPersonalization == hasConsentForAdsPersonalization &&
        other.hasConsentForAdStorage == hasConsentForAdStorage;
  }

  @override
  int get hashCode {
    return Object.hash(
      isUserSubjectToGDPR,
      hasConsentForDataUsage,
      hasConsentForAdsPersonalization,
      hasConsentForAdStorage,
    );
  }
}

