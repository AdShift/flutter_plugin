import 'package:flutter/foundation.dart';

/// The user's answer on passing their data on to advertising partners, for
/// `Adshift.instance.setThirdPartySharing()`.
///
/// Unlike consent, no answer means allowed. Until an answer is set, or after
/// `clearThirdPartySharing()`, the question counts as unanswered.
@immutable
final class AdshiftThirdPartySharing {
  /// The user asked not to have their data passed on.
  const AdshiftThirdPartySharing.optedOut() : optOut = true;

  /// The user was asked and did not opt out. Not a default for startup: a
  /// later answer cannot correct events already sent.
  const AdshiftThirdPartySharing.allowed() : optOut = false;

  /// Whether this user's data is withheld from advertising partners.
  final bool optOut;

  @override
  bool operator ==(Object other) =>
      other is AdshiftThirdPartySharing && other.optOut == optOut;

  @override
  int get hashCode => optOut.hashCode;

  @override
  String toString() => optOut
      ? 'AdshiftThirdPartySharing.optedOut()'
      : 'AdshiftThirdPartySharing.allowed()';
}
