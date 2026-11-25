// A change to these lists is a public API change: note it in the CHANGELOG,
// and release a removal only in a major version.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'support/source_parser.dart';

const publicExports = [
  'Adshift',
  'AdshiftApiKeyValidationStatus',
  'AdshiftConfig',
  'AdshiftConsent',
  'AdshiftConsentSnapshot',
  'AdshiftConsentSource',
  'AdshiftDeepLink',
  'AdshiftDeepLinkSource',
  'AdshiftDeepLinkStatus',
  'AdshiftDeferredDeepLinkClipboard',
  'AdshiftError',
  'AdshiftErrorCode',
  'AdshiftEventParam',
  'AdshiftEventType',
  'AdshiftInfo',
  'AdshiftMediationNetwork',
  'AdshiftResult',
  'AdshiftStartResult',
  'AdshiftThirdPartySharing',
  'adshiftPluginVersion',
];

const adshiftMembers = [
  'static Adshift get instance',
  'static set instance(Adshift value)',
  'void initialize(AdshiftConfig config)',
  'Future<AdshiftStartResult> start()',
  'void stop()',
  'bool get isStarted',
  'AdshiftInfo getInfo()',
  'void setCustomerUserId(String userId)',
  'void setDebugEnabled(bool enabled)',
  'void setAppOpenDebounceMs(int ms)',
  'void setBrandedDomains(List<String> domains)',
  'void setMetaAppId(String appId)',
  'void setOaidData(String oaid)',
  'void setConsentData(AdshiftConsent consent)',
  'void enableTCFDataCollection(bool enabled)',
  'void enableGPPDataCollection(bool enabled)',
  'void setThirdPartySharing(AdshiftThirdPartySharing sharing)',
  'void clearThirdPartySharing()',
  'Future<AdshiftConsentSnapshot?> refreshConsent()',
  'Future<AdshiftResult> trackEvent(String eventName, '
      '{Map<String, Object>? values})',
  'Future<AdshiftResult> trackPurchase({required String productId, '
      'required double revenue, required String currency, '
      'required String transactionId})',
  'Future<AdshiftResult> logAdRevenue({required String monetizationNetwork, '
      'required AdshiftMediationNetwork mediationNetwork, '
      'required String currency, required double revenue, String? adUnitId, '
      'String? precision, Map<String, Object>? additionalParameters})',
  'Future<String?> getAdShiftDeviceId()',
  'Future<void> handleDeepLink(Uri url)',
  'void handlePastedDeepLink(Uri? url)',
  'void addPushNotificationDeepLinkPath(List<String> path)',
  'Future<bool> handlePushNotification(Map<String, Object?> payload)',
  'Stream<AdshiftDeepLink> get onDeepLink',
];

/// What the fake adds to the members of `Adshift`.
const fakeOnlyMembers = [
  'AdshiftStartResult startResult',
  'AdshiftResult trackingResult',
  'AdshiftConsentSnapshot? consentSnapshot',
  'String? deviceId',
  'bool pushNotificationResult',
  'final List<AdshiftFakeCall> calls',
  'void emitDeepLink(AdshiftDeepLink link)',
  'void reset()',
];

void main() {
  test('the library exports exactly the documented names', () {
    expect(exportedNames('lib/adshift_flutter_sdk.dart'), publicExports);
  });

  test('Adshift has exactly the documented members', () {
    expect(memberSignatures('lib/src/adshift.dart', 'Adshift'), adshiftMembers);
  });

  test('the fake has the members of Adshift, with the same signatures', () {
    final instanceMembers = adshiftMembers.where(
      (member) => !member.startsWith('static '),
    );

    expect(
      memberSignatures('lib/testing.dart', 'AdshiftFake'),
      unorderedEquals([...instanceMembers, ...fakeOnlyMembers]),
    );
  });

  test('the testing library declares exactly the fake and its call record', () {
    final declared = RegExp(
      r'^(?:\w+ )*class (\w+)',
      multiLine: true,
    ).allMatches(File('lib/testing.dart').readAsStringSync());

    expect(declared.map((match) => match[1]), [
      'AdshiftFakeCall',
      'AdshiftFake',
    ]);
  });
}
