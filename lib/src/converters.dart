import 'package:flutter/services.dart' show PlatformException;

import 'messages.g.dart';
import 'models/adshift_config.dart';
import 'models/adshift_consent.dart';
import 'models/adshift_consent_snapshot.dart';
import 'models/adshift_deep_link.dart';
import 'models/adshift_error.dart';
import 'models/adshift_result.dart';

AdshiftError errorFromMessage(ErrorMessage message) => AdshiftError(
  switch (message.code) {
    ErrorCodeMessage.notInitialized => AdshiftErrorCode.notInitialized,
    ErrorCodeMessage.notStarted => AdshiftErrorCode.notStarted,
    ErrorCodeMessage.invalidApiKey => AdshiftErrorCode.invalidApiKey,
    ErrorCodeMessage.optedOut => AdshiftErrorCode.optedOut,
    ErrorCodeMessage.queueFull => AdshiftErrorCode.queueFull,
    ErrorCodeMessage.invalidArgument => AdshiftErrorCode.invalidArgument,
    ErrorCodeMessage.unknown => AdshiftErrorCode.unknown,
  },
  message.message,
  nativeCode: message.nativeCode,
  nativeDomain: message.nativeDomain,
);

/// Anything a platform call threw becomes `UNKNOWN`.
AdshiftError errorFromThrown(Object thrown) => switch (thrown) {
  PlatformException(:final code, :final message) => AdshiftError(
    AdshiftErrorCode.unknown,
    message ?? 'Unknown error',
    nativeCode: code,
  ),
  _ => AdshiftError(AdshiftErrorCode.unknown, thrown.toString()),
};

AdshiftStartResult startResultFromMessage(StartMessage message) {
  final keyStatus = switch (message.keyStatus) {
    KeyStatusMessage.pending => AdshiftApiKeyValidationStatus.pending,
    KeyStatusMessage.valid => AdshiftApiKeyValidationStatus.valid,
    KeyStatusMessage.invalid => AdshiftApiKeyValidationStatus.invalid,
    null => null,
  };
  if (message.success) {
    return AdshiftStartResult.success(apiKeyValidationStatus: keyStatus);
  }
  final error = message.error;
  return AdshiftStartResult.failure(
    error == null
        ? const AdshiftError(
            AdshiftErrorCode.unknown,
            'AdShift SDK failed to start.',
          )
        : errorFromMessage(error),
    apiKeyValidationStatus: keyStatus,
  );
}

ClipboardModeMessage? clipboardModeToMessage(
  AdshiftDeferredDeepLinkClipboard? mode,
) => switch (mode) {
  AdshiftDeferredDeepLinkClipboard.disabled => ClipboardModeMessage.disabled,
  AdshiftDeferredDeepLinkClipboard.prompt => ClipboardModeMessage.prompt,
  AdshiftDeferredDeepLinkClipboard.pasteControl =>
    ClipboardModeMessage.pasteControl,
  null => null,
};

/// The flags travel only for a GDPR user, an undecided one as null.
ConsentMessage consentToMessage(AdshiftConsent consent) =>
    consent.isUserSubjectToGDPR
    ? ConsentMessage(
        isUserSubjectToGdpr: true,
        hasConsentForDataUsage: consent.hasConsentForDataUsage,
        hasConsentForAdsPersonalization:
            consent.hasConsentForAdsPersonalization,
        hasConsentForAdStorage: consent.hasConsentForAdStorage,
      )
    : ConsentMessage(isUserSubjectToGdpr: false);

AdshiftConsentSnapshot consentSnapshotFromMessage(
  ConsentSnapshotMessage message,
) => AdshiftConsentSnapshot(
  source: switch (message.source) {
    ConsentSourceMessage.manual => AdshiftConsentSource.manual,
    ConsentSourceMessage.tcf => AdshiftConsentSource.tcf,
    ConsentSourceMessage.gpp => AdshiftConsentSource.gpp,
    ConsentSourceMessage.none => AdshiftConsentSource.none,
  },
  gdprApplies: message.gdprApplies,
  tcStringPresent: message.tcStringPresent,
  gppPresent: message.gppPresent,
  cmpDetected: message.cmpDetected,
  adUserDataEnabled: message.adUserDataEnabled,
  adPersonalizationEnabled: message.adPersonalizationEnabled,
  adStorageEnabled: message.adStorageEnabled,
  appliedAtMillis: message.appliedAtMillis,
  adIdentifiersAllowed: message.adIdentifiersAllowed,
);

/// Fills the routing value and the sub-parameters from `params` when the
/// platform left them out, and drops empty `params` and an empty click id.
AdshiftDeepLink deepLinkFromMessage(DeepLinkMessage message) {
  final received = message.params;
  final params = received == null || received.isEmpty
      ? null
      : Map<String, String>.unmodifiable(received);
  final clickId = message.clickId;
  return AdshiftDeepLink(
    status: switch (message.status) {
      DeepLinkStatusMessage.found => AdshiftDeepLinkStatus.found,
      DeepLinkStatusMessage.notFound => AdshiftDeepLinkStatus.notFound,
      DeepLinkStatusMessage.error => AdshiftDeepLinkStatus.error,
    },
    isDeferred: message.isDeferred,
    deepLink: message.deepLink,
    deepLinkValue: message.deepLinkValue ?? params?['deep_link_value'],
    params: params,
    errorMessage: message.errorMessage,
    source: switch (message.source) {
      DeepLinkSourceMessage.universalLink =>
        AdshiftDeepLinkSource.universalLink,
      DeepLinkSourceMessage.appLink => AdshiftDeepLinkSource.appLink,
      DeepLinkSourceMessage.scheme => AdshiftDeepLinkSource.scheme,
      DeepLinkSourceMessage.cta => AdshiftDeepLinkSource.cta,
      DeepLinkSourceMessage.push => AdshiftDeepLinkSource.push,
      DeepLinkSourceMessage.adAttributionKit =>
        AdshiftDeepLinkSource.adAttributionKit,
      DeepLinkSourceMessage.metaAppLink => AdshiftDeepLinkSource.metaAppLink,
      DeepLinkSourceMessage.deferred => AdshiftDeepLinkSource.deferred,
      DeepLinkSourceMessage.foreign => AdshiftDeepLinkSource.foreign,
      null => null,
    },
    clickId: clickId == null || clickId.isEmpty ? null : clickId,
    matchGuaranteed: message.matchGuaranteed,
    isFirstSession: message.isFirstSession,
    deepLinkSub1: message.sub1 ?? params?['deep_link_sub1'],
    deepLinkSub2: message.sub2 ?? params?['deep_link_sub2'],
    deepLinkSub3: message.sub3 ?? params?['deep_link_sub3'],
    deepLinkSub4: message.sub4 ?? params?['deep_link_sub4'],
    deepLinkSub5: message.sub5 ?? params?['deep_link_sub5'],
  );
}
