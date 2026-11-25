import 'dart:async';

import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

Future<AdshiftResult> purchase(
  Harness h, {
  String productId = 'p',
  double revenue = 1,
  String currency = 'USD',
  String transactionId = 't',
}) => h.adshift.trackPurchase(
  productId: productId,
  revenue: revenue,
  currency: currency,
  transactionId: transactionId,
);

Future<AdshiftResult> adRevenue(
  Harness h, {
  String monetizationNetwork = 'admob',
  String currency = 'USD',
  double revenue = 0.5,
  String? adUnitId,
  String? precision,
  Map<String, Object>? additionalParameters,
}) => h.adshift.logAdRevenue(
  monetizationNetwork: monetizationNetwork,
  mediationNetwork: AdshiftMediationNetwork.googleAdMob,
  currency: currency,
  revenue: revenue,
  adUnitId: adUnitId,
  precision: precision,
  additionalParameters: additionalParameters,
);

StartMessage failedStart(ErrorCodeMessage code, String message) => StartMessage(
  success: false,
  error: ErrorMessage(code: code, message: message),
);

void main() {
  group('tracking before start', () {
    test('answers NOT_INITIALIZED before initialize', () async {
      final h = Harness();

      expect(
        await h.adshift.trackEvent('e'),
        failsWith(AdshiftErrorCode.notInitialized),
      );
      expect(await purchase(h), failsWith(AdshiftErrorCode.notInitialized));
      expect(await adRevenue(h), failsWith(AdshiftErrorCode.notInitialized));
    });

    test('holds calls until start succeeds and sends them in order', () async {
      final h = Harness();
      await h.initialize();
      h.host.calls.clear();

      final answers = [
        h.adshift.trackEvent('first', values: {'a': 1}),
        purchase(h),
        adRevenue(h, revenue: 0.01),
      ];
      await settle();
      expect(h.host.calls, isEmpty);
      expect(h.logs.single, contains('queued until start()'));

      await h.adshift.start();

      expect(await Future.wait(answers), everyElement(succeeds));
      expect(h.host.calls, [
        ['start'],
        [
          'trackEvent',
          'first',
          {'a': 1},
        ],
        ['trackPurchase', 'p', 1.0, 'USD', 't'],
        [
          'logAdRevenue',
          AdRevenueMessage(
            monetizationNetwork: 'admob',
            mediationNetwork: 'google_admob',
            currency: 'USD',
            revenue: 0.01,
          ),
        ],
      ]);
    });

    test('sends the values as they were when the call was made', () async {
      final h = Harness();
      await h.initialize();
      final values = <String, Object>{'a': 1};

      final answer = h.adshift.trackEvent('e', values: values);
      values['b'] = 2;
      await h.adshift.start();
      await answer;

      expect(h.host.argumentsOf('trackEvent').single, [
        'e',
        {'a': 1},
      ]);
    });

    test('answers QUEUE_FULL beyond 100 waiting calls', () async {
      final h = Harness();
      await h.initialize();

      final waiting = [
        for (var i = 0; i < 100; i++) h.adshift.trackEvent('e$i'),
      ];
      expect(
        await h.adshift.trackEvent('overflow'),
        failsWith(AdshiftErrorCode.queueFull),
      );
      await h.adshift.start();

      expect(await Future.wait(waiting), everyElement(succeeds));
      expect(h.host.argumentsOf('trackEvent').map((call) => call.first), [
        for (var i = 0; i < 100; i++) 'e$i',
      ]);
    });

    for (final (code, expected) in [
      (ErrorCodeMessage.invalidApiKey, AdshiftErrorCode.invalidApiKey),
      (ErrorCodeMessage.optedOut, AdshiftErrorCode.optedOut),
      (ErrorCodeMessage.notInitialized, AdshiftErrorCode.notInitialized),
    ]) {
      test('ends waiting calls when start fails with '
          '${expected.wireName}', () async {
        final h = Harness();
        h.host.onStart = () async => failedStart(code, 'rejected');
        await h.initialize();

        final waiting = h.adshift.trackEvent('e');
        await h.adshift.start();
        final result = await waiting;

        // Retrying cannot fix this one, so the call must not keep waiting.
        expect(result, failsWith(expected));
        expect(result.error!.message, 'rejected');
        expect(h.host.count('trackEvent'), 0);
      });

      test('answers calls made after start failed with '
          '${expected.wireName}, until the next attempt', () async {
        final h = Harness();
        var attempts = 0;
        h.host.onStart = () async => ++attempts == 1
            ? failedStart(code, 'rejected')
            : StartMessage(success: true);
        await h.initialize();
        await h.adshift.start();

        // The app may never call start() again, so these must not wait for it.
        const soon = Duration(seconds: 1);
        expect(
          await h.adshift.trackEvent('e').timeout(soon),
          failsWith(expected),
        );
        expect(await purchase(h).timeout(soon), failsWith(expected));
        expect(await adRevenue(h).timeout(soon), failsWith(expected));
        expect(h.host.count('trackEvent'), 0);

        await h.adshift.start();
        expect(await h.adshift.trackEvent('e'), succeeds);
        expect(h.host.count('trackEvent'), 1);
      });
    }

    test('keeps waiting calls when start fails for another reason', () async {
      final h = Harness();
      var attempts = 0;
      h.host.onStart = () async => ++attempts == 1
          ? failedStart(ErrorCodeMessage.unknown, 'offline')
          : StartMessage(success: true);
      await h.initialize();

      final waiting = h.adshift.trackEvent('e');
      await h.adshift.start();
      expect(h.host.count('trackEvent'), 0);
      await h.adshift.start();

      expect(await waiting, succeeds);
      expect(h.host.count('trackEvent'), 1);
    });

    test('keeps waiting calls when the platform start throws', () async {
      final h = Harness();
      await h.initialize();
      h.host.failure = PlatformException(code: 'E');

      final waiting = h.adshift.trackEvent('e');
      await h.adshift.start();
      h.host.failure = null;
      await h.adshift.start();

      expect(await waiting, succeeds);
    });

    test('ends waiting calls when stop() interrupts a start', () async {
      final h = Harness();
      final platformStart = Completer<StartMessage>();
      h.host.onStart = () => platformStart.future;
      await h.initialize();

      final waiting = h.adshift.trackEvent('e');
      final starting = h.adshift.start();
      h.adshift.stop();
      platformStart.complete(StartMessage(success: true));
      await starting;

      expect(await waiting, failsWith(AdshiftErrorCode.notStarted));
    });

    test('answers NOT_STARTED after stop, to waiting calls too', () async {
      final h = Harness();
      await h.initialize();

      final waiting = h.adshift.trackEvent('waiting');
      h.adshift.stop();

      expect(await waiting, failsWith(AdshiftErrorCode.notStarted));
      expect(
        await h.adshift.trackEvent('after'),
        failsWith(AdshiftErrorCode.notStarted),
      );
      expect(h.host.count('trackEvent'), 0);
    });
  });

  group('tracking after start', () {
    test('passes events straight through', () async {
      final h = Harness();
      await h.initializeAndStart();

      expect(await h.adshift.trackEvent('e', values: {'ok': true}), succeeds);
      expect(await h.adshift.trackEvent('e'), succeeds);

      expect(h.host.argumentsOf('trackEvent'), [
        [
          'e',
          {'ok': true},
        ],
        ['e', <String, Object?>{}],
      ]);
      expect(h.errors, isEmpty);
    });

    test('carries the platform error in the result', () async {
      final h = Harness();
      await h.initializeAndStart();

      h.host.onTrack = () async => ErrorMessage(
        code: ErrorCodeMessage.optedOut,
        message: 'disabled',
        nativeCode: '12',
      );
      final declined = await h.adshift.trackEvent('e');
      expect(declined, failsWith(AdshiftErrorCode.optedOut));
      expect(declined.error!.message, 'disabled');
      expect(declined.error!.nativeCode, '12');
      expect(await purchase(h), failsWith(AdshiftErrorCode.optedOut));
      expect(await adRevenue(h), failsWith(AdshiftErrorCode.optedOut));

      h.host.failure = StateError('plain');
      final thrown = await h.adshift.trackEvent('e');
      expect(thrown, failsWith(AdshiftErrorCode.unknown));
      expect(thrown.error!.message, contains('plain'));
      // The caller has the result; onError is for calls that return nothing.
      expect(h.errors, isEmpty);
    });

    test('validates the event name and values', () async {
      final h = Harness();
      await h.initializeAndStart();

      for (final answer in [
        h.adshift.trackEvent(''),
        h.adshift.trackEvent('  '),
        h.adshift.trackEvent('app_open'),
        h.adshift.trackEvent(' App_Install '),
        h.adshift.trackEvent('e', values: {'nested': <String, Object>{}}),
        h.adshift.trackEvent('e', values: {'list': <Object>[]}),
        h.adshift.trackEvent('e', values: {'when': DateTime(2026)}),
        h.adshift.trackEvent('e', values: {'n': double.nan}),
        h.adshift.trackEvent('e', values: {'n': double.infinity}),
      ]) {
        expect(await answer, failsWith(AdshiftErrorCode.invalidArgument));
      }
      expect(h.host.count('trackEvent'), 0);

      expect(
        await h.adshift.trackEvent('e', values: {'s': 'x', 'i': 1, 'd': 1.5}),
        succeeds,
      );
    });

    test('names the value that was refused', () async {
      final h = Harness();
      await h.initializeAndStart();

      final result = await h.adshift.trackEvent(
        'e',
        values: {'when': Object()},
      );

      expect(result.error!.message, contains('values.when'));
    });

    test('validates purchases', () async {
      final h = Harness();
      await h.initializeAndStart();

      for (final answer in [
        purchase(h, productId: ''),
        purchase(h, revenue: -1),
        purchase(h, revenue: double.nan),
        purchase(h, currency: ''),
        purchase(h, transactionId: ' '),
      ]) {
        expect(await answer, failsWith(AdshiftErrorCode.invalidArgument));
      }
      expect(h.host.count('trackPurchase'), 0);

      expect(await purchase(h, revenue: 0), succeeds);
      expect(h.host.argumentsOf('trackPurchase').single, [
        'p',
        0.0,
        'USD',
        't',
      ]);
    });

    test('validates ad revenue and forwards the optional fields', () async {
      final h = Harness();
      await h.initializeAndStart();

      for (final answer in [
        adRevenue(h, monetizationNetwork: ''),
        adRevenue(h, monetizationNetwork: '  '),
        adRevenue(h, revenue: 0),
        adRevenue(h, revenue: -0.1),
        adRevenue(h, revenue: double.infinity),
        adRevenue(h, revenue: double.nan),
        adRevenue(h, currency: ''),
        adRevenue(h, currency: '   '),
        adRevenue(h, additionalParameters: {'deep': <Object>[]}),
      ]) {
        expect(await answer, failsWith(AdshiftErrorCode.invalidArgument));
      }
      expect(h.host.count('logAdRevenue'), 0);

      expect(
        await adRevenue(
          h,
          adUnitId: 'unit',
          precision: 'exact',
          additionalParameters: {'placement': 'home'},
        ),
        succeeds,
      );
      expect(
        h.host.argumentsOf('logAdRevenue').single.single,
        AdRevenueMessage(
          monetizationNetwork: 'admob',
          mediationNetwork: 'google_admob',
          currency: 'USD',
          revenue: 0.5,
          adUnitId: 'unit',
          precision: 'exact',
          additionalParameters: {'placement': 'home'},
        ),
      );
    });

    test('sends every mediation network under its wire name', () async {
      final h = Harness();
      await h.initializeAndStart();

      for (final network in AdshiftMediationNetwork.values) {
        await h.adshift.logAdRevenue(
          monetizationNetwork: 'admob',
          mediationNetwork: network,
          currency: 'USD',
          revenue: 0.5,
        );
      }

      expect(
        h.host
            .argumentsOf('logAdRevenue')
            .map((call) => (call.single as AdRevenueMessage).mediationNetwork),
        AdshiftMediationNetwork.values.map((network) => network.wireName),
      );
    });

    test('requires a three-letter currency for ad revenue', () async {
      final h = Harness();
      await h.initializeAndStart();

      expect(
        await adRevenue(h, currency: 'US'),
        failsWith(AdshiftErrorCode.invalidArgument),
      );
      expect(
        await adRevenue(h, currency: 'DOLLAR'),
        failsWith(AdshiftErrorCode.invalidArgument),
      );
      expect(h.host.count('logAdRevenue'), 0);
      expect(await adRevenue(h, currency: 'USD'), succeeds);
    });

    test('warns in debug builds when ad revenue is above the recorded '
        'maximum', () async {
      final h = Harness();
      await h.initializeAndStart();

      expect(await adRevenue(h, revenue: 15), succeeds);

      expect(h.logs.single, contains('revenue above 10 is not recorded'));
      // The value still reaches the SDK: the plugin does not decide what is
      // tracked.
      final sent = h.host.argumentsOf('logAdRevenue').single.single;
      expect((sent as AdRevenueMessage).revenue, 15);

      h.logs.clear();
      await adRevenue(h, revenue: 10);
      expect(h.logs, isEmpty);
    });

    test('warns about a large amount in another currency on Android '
        'only', () async {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ios = Harness();
      await ios.initializeAndStart();
      await adRevenue(ios, currency: 'KRW', revenue: 50);
      expect(ios.logs, isEmpty);
      await adRevenue(ios, currency: 'usd', revenue: 50);
      expect(ios.logs.single, contains('revenue above 10 is not recorded'));

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final android = Harness();
      await android.initializeAndStart();
      await adRevenue(android, currency: 'KRW', revenue: 50);
      expect(android.logs.single, contains('revenue above 10 is not recorded'));
    });
  });
}
