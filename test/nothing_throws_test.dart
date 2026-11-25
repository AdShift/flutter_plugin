import 'dart:async';

import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';
import 'support/source_parser.dart';

/// One call of every member of `Adshift`, with valid arguments.
final Map<String, FutureOr<void> Function(Adshift sdk)> everyMember = {
  'initialize': (sdk) => sdk.initialize(const AdshiftConfig(apiKey: 'other')),
  'start': (sdk) => sdk.start(),
  'stop': (sdk) => sdk.stop(),
  'isStarted': (sdk) => sdk.isStarted,
  'getInfo': (sdk) => sdk.getInfo(),
  'setCustomerUserId': (sdk) => sdk.setCustomerUserId('user-1'),
  'setDebugEnabled': (sdk) => sdk.setDebugEnabled(true),
  'setAppOpenDebounceMs': (sdk) => sdk.setAppOpenDebounceMs(5000),
  'setBrandedDomains': (sdk) => sdk.setBrandedDomains(['links.example.com']),
  'setMetaAppId': (sdk) => sdk.setMetaAppId('meta-1'),
  'setOaidData': (sdk) => sdk.setOaidData('oaid-1'),
  'setConsentData': (sdk) =>
      sdk.setConsentData(const AdshiftConsent.forGDPRUser()),
  'enableTCFDataCollection': (sdk) => sdk.enableTCFDataCollection(true),
  'enableGPPDataCollection': (sdk) => sdk.enableGPPDataCollection(true),
  'setThirdPartySharing': (sdk) =>
      sdk.setThirdPartySharing(const AdshiftThirdPartySharing.optedOut()),
  'clearThirdPartySharing': (sdk) => sdk.clearThirdPartySharing(),
  'refreshConsent': (sdk) => sdk.refreshConsent(),
  'trackEvent': (sdk) => sdk.trackEvent('e', values: {'a': 1}),
  'trackPurchase': (sdk) => sdk.trackPurchase(
    productId: 'p',
    revenue: 1,
    currency: 'USD',
    transactionId: 't',
  ),
  'logAdRevenue': (sdk) => sdk.logAdRevenue(
    monetizationNetwork: 'admob',
    mediationNetwork: AdshiftMediationNetwork.googleAdMob,
    currency: 'USD',
    revenue: 0.01,
  ),
  'getAdShiftDeviceId': (sdk) => sdk.getAdShiftDeviceId(),
  'handleDeepLink': (sdk) => sdk.handleDeepLink(Uri.parse('https://x')),
  'handlePastedDeepLink': (sdk) => sdk.handlePastedDeepLink(null),
  'addPushNotificationDeepLinkPath': (sdk) =>
      sdk.addPushNotificationDeepLinkPath(['data', 'link']),
  'handlePushNotification': (sdk) => sdk.handlePushNotification({'a': 'b'}),
  'onDeepLink': (sdk) => sdk.onDeepLink.listen((_) {}).cancel(),
};

/// The same members with arguments the SDK refuses.
final Map<String, FutureOr<void> Function(Adshift sdk)> refusedCalls = {
  'initialize': (sdk) => sdk.initialize(const AdshiftConfig(apiKey: '')),
  'setCustomerUserId': (sdk) => sdk.setCustomerUserId(''),
  'setAppOpenDebounceMs': (sdk) => sdk.setAppOpenDebounceMs(-1),
  'setBrandedDomains': (sdk) => sdk.setBrandedDomains(['']),
  'setMetaAppId': (sdk) => sdk.setMetaAppId(''),
  'setOaidData': (sdk) => sdk.setOaidData(''),
  'trackEvent': (sdk) => sdk.trackEvent('', values: {'a': Object()}),
  'trackPurchase': (sdk) => sdk.trackPurchase(
    productId: '',
    revenue: double.nan,
    currency: '',
    transactionId: '',
  ),
  'logAdRevenue': (sdk) => sdk.logAdRevenue(
    monetizationNetwork: '',
    mediationNetwork: AdshiftMediationNetwork.other,
    currency: '',
    revenue: double.infinity,
  ),
  'handleDeepLink': (sdk) => sdk.handleDeepLink(Uri()),
  'handlePastedDeepLink': (sdk) => sdk.handlePastedDeepLink(Uri()),
  'addPushNotificationDeepLinkPath': (sdk) =>
      sdk.addPushNotificationDeepLinkPath([]),
  'handlePushNotification': (sdk) =>
      sdk.handlePushNotification({'when': DateTime(2026)}),
};

/// What [call] throws: at once, through its future, or later where nobody
/// awaits it. A call that waits for `start()` is not waited for.
Future<List<Object>> errorsOf(FutureOr<void> Function() call) async {
  final errors = <Object>[];
  await runZonedGuarded(() async {
    try {
      final answer = call();
      if (answer is Future<void>) {
        unawaited(answer.then((_) {}, onError: (Object e) => errors.add(e)));
      }
    } catch (error) {
      errors.add(error);
    }
    await settle();
  }, (error, _) => errors.add(error));
  return errors;
}

/// A harness whose `onError` throws and whose platform fails with [failure],
/// from the moment [prepare] sets it.
Future<Harness> harness(
  Object? failure, {
  required bool synchronously,
  required Future<void> Function(Harness h) prepare,
}) async {
  final h = Harness();
  h.host.failSynchronously = synchronously;
  await prepare(h);
  h.host.failure = failure;
  return h;
}

final throwingConfig = AdshiftConfig(
  apiKey: 'key-123',
  onError: (_) => throw StateError('onError failure'),
);

void main() {
  test('the calls below cover every member of Adshift', () {
    final members = memberSignatures(
      'lib/src/adshift.dart',
      'Adshift',
    ).where((member) => !member.startsWith('static ')).map(memberName);

    expect(everyMember.keys, members);
    expect(members, containsAll(refusedCalls.keys));
  });

  final states = <String, Future<void> Function(Harness h)>{
    'before initialize': (h) async {},
    'after a refused initialize': (h) async =>
        h.adshift.initialize(AdshiftConfig(apiKey: '', onError: h.errors.add)),
    'after initialize': (h) => h.initialize(throwingConfig),
    'after start': (h) async {
      await h.initialize(throwingConfig);
      await h.adshift.start();
    },
    'after stop': (h) async {
      await h.initialize(throwingConfig);
      await h.adshift.start();
      h.adshift.stop();
    },
  };
  final failures = <String, (Object?, bool)>{
    'a platform that works': (null, false),
    'a platform whose answers fail': (
      PlatformException(code: 'channel-error', message: 'no connection'),
      false,
    ),
    'a platform whose calls throw': (StateError('no platform'), true),
  };

  for (final MapEntry(key: state, value: prepare) in states.entries) {
    for (final MapEntry(key: platform, value: (failure, synchronously))
        in failures.entries) {
      test('nothing throws $state, with $platform', () async {
        for (final calls in [everyMember, refusedCalls]) {
          for (final MapEntry(key: member, value: call) in calls.entries) {
            final h = await harness(
              failure,
              synchronously: synchronously,
              prepare: prepare,
            );

            final errors = await errorsOf(() => call(h.adshift));

            expect(errors, isEmpty, reason: member);
          }
        }
      });
    }
  }

  test('nothing throws when the platform fails from the first call', () async {
    for (final synchronously in [false, true]) {
      for (final MapEntry(key: member, value: call) in everyMember.entries) {
        final h = Harness();
        h.host
          ..failure = PlatformException(code: 'channel-error')
          ..failSynchronously = synchronously;

        final errors = await errorsOf(() async {
          h.adshift.initialize(throwingConfig);
          await call(h.adshift);
          await h.adshift.start();
        });

        expect(errors, isEmpty, reason: member);
        expect(h.adshift.isStarted, isFalse);
      }
    }
  });

  test('nothing throws while calls wait for a start that fails', () async {
    final h = Harness();
    await h.initialize(throwingConfig);
    h.host.failure = PlatformException(code: 'channel-error');

    final errors = await errorsOf(() async {
      final waiting = [
        h.adshift.trackEvent('e'),
        h.adshift.trackPurchase(
          productId: 'p',
          revenue: 1,
          currency: 'USD',
          transactionId: 't',
        ),
      ];
      await h.adshift.start();
      h.adshift.stop();
      await Future.wait(waiting);
    });

    expect(errors, isEmpty);
  });
}
