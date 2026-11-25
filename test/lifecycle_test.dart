import 'dart:async';

import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:adshift_flutter_sdk/src/native_sdk_versions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

ErrorMessage notOwner() => ErrorMessage(
  code: ErrorCodeMessage.notInitialized,
  message: 'This engine does not own the SDK.',
);

void main() {
  group('initialize', () {
    test('reports a missing apiKey through onError instead of throwing', () {
      final h = Harness();

      h.adshift.initialize(AdshiftConfig(apiKey: ' ', onError: h.errors.add));

      expect(h.host.calls, isEmpty);
      expect(h.errorCodes, [AdshiftErrorCode.invalidArgument]);
    });

    test('answers start() with the reason the config was refused', () async {
      final h = Harness();
      h.adshift.initialize(const AdshiftConfig(apiKey: ''));

      final result = await h.adshift.start();

      expect(result, failsWith(AdshiftErrorCode.invalidArgument));
      expect(result.error!.message, contains('apiKey'));
      expect(h.host.calls, isEmpty);
    });

    test('accepts a valid config after a refused one', () async {
      final h = Harness();
      h.adshift.initialize(const AdshiftConfig(apiKey: ''));

      await h.initialize();

      expect((await h.adshift.start()).success, isTrue);
    });

    for (final synchronously in [false, true]) {
      test('survives a platform initialize that fails '
          '${synchronously ? 'at once' : 'in its answer'}', () async {
        final h = Harness();
        h.host
          ..failure = PlatformException(code: 'E', message: 'bridge failed')
          ..failSynchronously = synchronously;

        await h.initialize();

        expect(h.errors, hasLength(1));
        expect(h.errors.single.message, 'bridge failed');
        expect(h.adshift.isStarted, isFalse);
        expect(await h.adshift.start(), failsWith(AdshiftErrorCode.unknown));
        expect(h.host.count('start'), 0);
      });
    }

    test('passes only the options that were set', () async {
      final h = Harness();

      await h.initialize();

      expect(h.host.argumentsOf('initialize'), [
        [InitializeMessage(apiKey: 'key-123')],
      ]);
    });

    test('passes every option to the platform', () async {
      final h = Harness();

      await h.initialize(
        const AdshiftConfig(
          apiKey: 'k',
          isDebug: true,
          appOpenDebounceMs: 0,
          brandedDomains: ['links.example.com'],
          testMode: true,
          metaAppId: 'meta-1',
          pushDeepLinkPaths: [
            ['data', 'link'],
          ],
          autoHandleDeepLinks: false,
          disableSKAN: true,
          waitForATTBeforeStart: true,
          attTimeoutMs: 45000,
          deferredDeepLinkClipboard:
              AdshiftDeferredDeepLinkClipboard.pasteControl,
          collectOaid: false,
        ),
      );

      expect(
        h.host.argumentsOf('initialize').single.single,
        InitializeMessage(
          apiKey: 'k',
          isDebug: true,
          appOpenDebounceMs: 0,
          brandedDomains: ['links.example.com'],
          testMode: true,
          metaAppId: 'meta-1',
          pushDeepLinkPaths: [
            ['data', 'link'],
          ],
          autoHandleDeepLinks: false,
          disableSkan: true,
          waitForAttBeforeStart: true,
          attTimeoutMs: 45000,
          deferredDeepLinkClipboard: ClipboardModeMessage.pasteControl,
          collectOaid: false,
        ),
      );
    });

    test('maps every clipboard mode', () async {
      for (final (mode, message) in [
        (
          AdshiftDeferredDeepLinkClipboard.disabled,
          ClipboardModeMessage.disabled,
        ),
        (AdshiftDeferredDeepLinkClipboard.prompt, ClipboardModeMessage.prompt),
        (
          AdshiftDeferredDeepLinkClipboard.pasteControl,
          ClipboardModeMessage.pasteControl,
        ),
      ]) {
        final h = Harness();
        await h.initialize(
          AdshiftConfig(apiKey: 'k', deferredDeepLinkClipboard: mode),
        );
        final sent =
            h.host.argumentsOf('initialize').single.single as InitializeMessage;
        expect(sent.deferredDeepLinkClipboard, message);
      }
    });

    test('reports a rejected API key once, not twice', () async {
      final h = Harness();
      h.host.onStart = () async =>
          StartMessage(success: true, keyStatus: KeyStatusMessage.invalid);
      await h.initialize();

      final result = await h.adshift.start();

      expect(result.success, isTrue);
      expect(
        result.apiKeyValidationStatus,
        AdshiftApiKeyValidationStatus.invalid,
      );
      expect(h.errorCodes, [AdshiftErrorCode.invalidApiKey]);
    });

    test('listens for deep links before the platform is initialized, and says '
        'so once it has answered', () async {
      final h = Harness();

      h.adshift.initialize(h.config);
      expect(h.host.methods, ['registerHandler', 'initialize']);

      await settle();
      expect(h.host.methods, [
        'registerHandler',
        'initialize',
        'deepLinkListenerReady',
      ]);
    });

    test('keeps the first config and ignores later calls', () async {
      final h = Harness();
      await h.initialize();

      await h.initialize(const AdshiftConfig(apiKey: 'other'));

      expect(h.host.count('initialize'), 1);
      expect(h.host.count('registerHandler'), 1);
      expect(h.host.count('deepLinkListenerReady'), 1);
    });

    test('refuses blank brandedDomains without throwing', () {
      final h = Harness();

      h.adshift.initialize(
        AdshiftConfig(
          apiKey: 'k',
          brandedDomains: const [''],
          onError: h.errors.add,
        ),
      );

      expect(h.host.calls, isEmpty);
      expect(h.errors.single.message, contains('brandedDomains'));
    });

    test('refuses blank pushDeepLinkPaths without throwing', () {
      final h = Harness();

      h.adshift.initialize(
        AdshiftConfig(
          apiKey: 'k',
          pushDeepLinkPaths: const [
            ['data', ''],
          ],
          onError: h.errors.add,
        ),
      );

      expect(h.host.calls, isEmpty);
      expect(h.errors.single.message, contains('pushDeepLinkPaths'));
    });

    for (final (option, build)
        in <(String, AdshiftConfig Function(void Function(AdshiftError)))>[
          (
            'appOpenDebounceMs',
            (onError) => AdshiftConfig(
              apiKey: 'k',
              appOpenDebounceMs: -1,
              onError: onError,
            ),
          ),
          (
            'attTimeoutMs',
            (onError) =>
                AdshiftConfig(apiKey: 'k', attTimeoutMs: -1, onError: onError),
          ),
        ]) {
      test('refuses a negative $option, like its setter would', () async {
        final h = Harness();

        h.adshift.initialize(build(h.errors.add));

        expect(h.host.calls, isEmpty);
        expect(h.errorCodes, [AdshiftErrorCode.invalidArgument]);
        expect(h.errors.single.message, contains(option));
        expect(
          await h.adshift.start(),
          failsWith(AdshiftErrorCode.invalidArgument),
        );
      });
    }

    test('accepts zero for appOpenDebounceMs and attTimeoutMs', () async {
      final h = Harness();

      await h.initialize(
        const AdshiftConfig(apiKey: 'k', appOpenDebounceMs: 0, attTimeoutMs: 0),
      );

      expect(
        h.host.argumentsOf('initialize').single.single,
        InitializeMessage(apiKey: 'k', appOpenDebounceMs: 0, attTimeoutMs: 0),
      );
    });
  });

  group('an engine that does not own the SDK', () {
    test('stays uninitialized and answers start() with the reason', () async {
      final h = Harness();
      h.host.onInitialize = () async => notOwner();

      await h.initialize();
      final result = await h.adshift.start();

      expect(h.errorCodes, [AdshiftErrorCode.notInitialized]);
      expect(result, failsWith(AdshiftErrorCode.notInitialized));
      expect(result.error!.message, 'This engine does not own the SDK.');
      expect(h.adshift.isStarted, isFalse);
      expect(h.host.count('start'), 0);
      expect(h.host.count('deepLinkListenerReady'), 0);
    });

    test('answers a start() made before the platform answered', () async {
      final h = Harness();
      h.host.onInitialize = () async => notOwner();

      h.adshift.initialize(h.config);
      final result = await h.adshift.start();

      expect(result, failsWith(AdshiftErrorCode.notInitialized));
      expect(h.host.count('start'), 0);
    });

    test('ends the tracking calls that were waiting', () async {
      final h = Harness();
      h.host.onInitialize = () async => notOwner();

      h.adshift.initialize(h.config);
      final waiting = h.adshift.trackEvent('e');

      expect(await waiting, failsWith(AdshiftErrorCode.notInitialized));
      expect(
        await h.adshift.trackEvent('later'),
        failsWith(AdshiftErrorCode.notInitialized),
      );
      expect(h.host.count('trackEvent'), 0);
    });

    test('keeps earlier settings for an initialize that is accepted', () async {
      final h = Harness();
      h.adshift.setCustomerUserId('user-1');
      h.adshift.addPushNotificationDeepLinkPath(['data', 'link']);
      h.host.onInitialize = () async => notOwner();
      await h.initialize();

      h.host.onInitialize = () async => null;
      await h.initialize();

      expect(h.host.count('initialize'), 2);
      expect(h.host.count('registerHandler'), 1);
      expect(h.host.argumentsOf('setCustomerUserId'), [
        ['user-1'],
        ['user-1'],
      ]);
      final accepted =
          h.host.argumentsOf('initialize').last.single as InitializeMessage;
      expect(accepted.pushDeepLinkPaths, [
        ['data', 'link'],
      ]);
      expect((await h.adshift.start()).success, isTrue);
    });
  });

  group('start', () {
    test('answers NOT_INITIALIZED before initialize', () async {
      final h = Harness();

      expect(
        await h.adshift.start(),
        failsWith(AdshiftErrorCode.notInitialized),
      );
      expect(h.adshift.isStarted, isFalse);
    });

    test(
      'answers with the platform result and marks the SDK started',
      () async {
        final h = Harness();
        await h.initialize();

        final result = await h.adshift.start();

        expect(result.success, isTrue);
        expect(
          result.apiKeyValidationStatus,
          AdshiftApiKeyValidationStatus.pending,
        );
        expect(h.adshift.isStarted, isTrue);
        expect(h.host.count('start'), 1);
      },
    );

    test('reaches the platform behind initialize when called right after '
        'it', () async {
      final h = Harness();

      h.adshift.initialize(h.config);
      final result = await h.adshift.start();

      expect(result.success, isTrue);
      expect(h.host.methods, [
        'registerHandler',
        'initialize',
        'deepLinkListenerReady',
        'start',
      ]);
    });

    test(
      'answers success to repeated calls without another platform call',
      () async {
        final h = Harness();
        await h.initializeAndStart();

        final again = await h.adshift.start();

        expect(again.success, isTrue);
        expect(again.apiKeyValidationStatus, isNull);
        expect(h.host.count('start'), 1);
      },
    );

    test('shares one attempt between concurrent callers', () async {
      final h = Harness();
      await h.initialize();

      final results = await Future.wait([h.adshift.start(), h.adshift.start()]);

      expect(results.map((r) => r.success), [true, true]);
      expect(h.host.count('start'), 1);
    });

    test('maps a failed start and stays not started', () async {
      final h = Harness();
      h.host.onStart = () async => StartMessage(
        success: false,
        keyStatus: KeyStatusMessage.invalid,
        error: ErrorMessage(
          code: ErrorCodeMessage.invalidApiKey,
          message: 'rejected',
          nativeCode: '41',
          nativeDomain: 'com.adshift.sdk',
        ),
      );
      await h.initialize();

      final result = await h.adshift.start();

      expect(result.success, isFalse);
      expect(
        result.apiKeyValidationStatus,
        AdshiftApiKeyValidationStatus.invalid,
      );
      expect(result.error!.code, AdshiftErrorCode.invalidApiKey);
      expect(result.error!.message, 'rejected');
      expect(result.error!.nativeCode, '41');
      expect(result.error!.nativeDomain, 'com.adshift.sdk');
      expect(h.adshift.isStarted, isFalse);
      expect(h.errorCodes, [AdshiftErrorCode.invalidApiKey]);
    });

    test('maps every error code and key status', () async {
      for (final (message, code) in [
        (ErrorCodeMessage.notInitialized, AdshiftErrorCode.notInitialized),
        (ErrorCodeMessage.notStarted, AdshiftErrorCode.notStarted),
        (ErrorCodeMessage.invalidApiKey, AdshiftErrorCode.invalidApiKey),
        (ErrorCodeMessage.optedOut, AdshiftErrorCode.optedOut),
        (ErrorCodeMessage.queueFull, AdshiftErrorCode.queueFull),
        (ErrorCodeMessage.invalidArgument, AdshiftErrorCode.invalidArgument),
        (ErrorCodeMessage.unknown, AdshiftErrorCode.unknown),
      ]) {
        final h = Harness();
        h.host.onStart = () async => StartMessage(
          success: false,
          error: ErrorMessage(code: message, message: 'm'),
        );
        await h.initialize();
        expect(await h.adshift.start(), failsWith(code));
      }
      for (final (message, status) in [
        (KeyStatusMessage.pending, AdshiftApiKeyValidationStatus.pending),
        (KeyStatusMessage.valid, AdshiftApiKeyValidationStatus.valid),
        (KeyStatusMessage.invalid, AdshiftApiKeyValidationStatus.invalid),
      ]) {
        final h = Harness();
        h.host.onStart = () async =>
            StartMessage(success: true, keyStatus: message);
        await h.initialize();
        expect((await h.adshift.start()).apiKeyValidationStatus, status);
      }
    });

    test('answers UNKNOWN to a failed start that names no reason', () async {
      final h = Harness();
      h.host.onStart = () async => StartMessage(success: false);
      await h.initialize();

      final result = await h.adshift.start();

      expect(result, failsWith(AdshiftErrorCode.unknown));
      expect(result.error!.message, isNotEmpty);
    });

    test('reports a start failure through onError', () async {
      final h = Harness();
      h.host.onStart = () async => StartMessage(
        success: false,
        error: ErrorMessage(
          code: ErrorCodeMessage.optedOut,
          message: 'tracking disabled for this device',
        ),
      );
      await h.initialize();

      await h.adshift.start();

      expect(h.errorCodes, [AdshiftErrorCode.optedOut]);
    });

    test('turns an exception from the platform into a failed result', () async {
      final h = Harness();
      await h.initialize();
      h.host.failure = PlatformException(
        code: 'E_SOMETHING_NEW',
        message: 'boom',
      );

      final result = await h.adshift.start();

      expect(result, failsWith(AdshiftErrorCode.unknown));
      expect(result.error!.message, 'boom');
      expect(result.error!.nativeCode, 'E_SOMETHING_NEW');
      expect(h.adshift.isStarted, isFalse);

      h.host.failure = null;
      expect((await h.adshift.start()).success, isTrue);
    });

    test('survives an exception that carries nothing usable', () async {
      final h = Harness();
      await h.initialize();
      h.host.failure = 'not an error object';

      final result = await h.adshift.start();

      expect(result, failsWith(AdshiftErrorCode.unknown));
      expect(result.error!.message, 'not an error object');
      expect(result.error!.nativeCode, isNull);
    });

    test('honours stop() called while start() is in flight', () async {
      final h = Harness();
      final platformStart = Completer<StartMessage>();
      h.host.onStart = () => platformStart.future;
      await h.initialize();

      final starting = h.adshift.start();
      await settle();
      expect(h.host.count('start'), 1);
      h.adshift.stop();
      platformStart.complete(StartMessage(success: true));

      expect(await starting, failsWith(AdshiftErrorCode.notStarted));
      // The platform had started meanwhile, so it is stopped once more.
      expect(h.host.count('stop'), 2);
      expect(h.adshift.isStarted, isFalse);
    });

    test('does not start the platform when stop() came before it answered '
        'initialize', () async {
      final h = Harness();

      h.adshift.initialize(h.config);
      final starting = h.adshift.start();
      h.adshift.stop();

      expect(await starting, failsWith(AdshiftErrorCode.notStarted));
      expect(h.host.count('start'), 0);
      expect(h.host.count('stop'), 1);
      expect(h.adshift.isStarted, isFalse);
    });

    test(
      'starts again when start() follows stop() during an in-flight start',
      () async {
        final h = Harness();
        final answers = <Completer<StartMessage>>[];
        h.host.onStart = () {
          answers.add(Completer<StartMessage>());
          return answers.last.future;
        };
        await h.initialize();

        final first = h.adshift.start();
        await settle();
        h.adshift.stop();
        final second = h.adshift.start();
        await settle();
        expect(h.host.count('start'), 2);
        for (final answer in answers) {
          answer.complete(StartMessage(success: true));
        }
        await first;

        expect((await second).success, isTrue);
        expect(h.adshift.isStarted, isTrue);
      },
    );

    test(
      'keeps the newer attempt in charge when an older one answers late',
      () async {
        final h = Harness();
        final answers = <Completer<StartMessage>>[];
        h.host.onStart = () {
          answers.add(Completer<StartMessage>());
          return answers.last.future;
        };
        await h.initialize();

        final first = h.adshift.start();
        await settle();
        h.adshift.stop();
        final second = h.adshift.start();
        await settle();
        answers[1].complete(StartMessage(success: true));
        expect((await second).success, isTrue);
        answers[0].complete(
          StartMessage(
            success: false,
            error: ErrorMessage(
              code: ErrorCodeMessage.unknown,
              message: 'late',
            ),
          ),
        );
        await first;

        expect(h.adshift.isStarted, isTrue);
        expect(h.errors, isEmpty);
      },
    );
  });

  group('stop and isStarted', () {
    test('stop() before initialize is skipped without throwing', () {
      final h = Harness();

      h.adshift.stop();

      expect(h.host.calls, isEmpty);
      expect(h.logs.single, contains('NOT_INITIALIZED'));
    });

    test('isStarted is safe before initialize and false after stop', () async {
      final h = Harness();
      expect(h.adshift.isStarted, isFalse);
      await h.initializeAndStart();

      h.adshift.stop();
      expect(h.host.count('stop'), 1);
      expect(h.adshift.isStarted, isFalse);

      final restarted = await h.adshift.start();
      expect(restarted.success, isTrue);
      expect(
        restarted.apiKeyValidationStatus,
        AdshiftApiKeyValidationStatus.pending,
      );
      expect(h.adshift.isStarted, isTrue);
    });
  });

  group('settings', () {
    test(
      'made before initialize are applied by it, in a fixed order',
      () async {
        final h = Harness();

        h.adshift
          ..setThirdPartySharing(const AdshiftThirdPartySharing.optedOut())
          ..enableGPPDataCollection(true)
          ..enableTCFDataCollection(true)
          ..setConsentData(const AdshiftConsent.forNonGDPRUser())
          ..setBrandedDomains(['links.example.com'])
          ..setAppOpenDebounceMs(5000)
          ..setMetaAppId('meta-1')
          ..setOaidData('oaid-1')
          ..setDebugEnabled(true)
          ..setCustomerUserId('user-1');
        expect(h.host.calls, isEmpty);

        await h.initialize();

        expect(h.host.calls, [
          ['registerHandler'],
          [
            'initialize',
            InitializeMessage(
              apiKey: 'key-123',
              brandedDomains: ['links.example.com'],
              appOpenDebounceMs: 5000,
              metaAppId: 'meta-1',
              isDebug: true,
            ),
          ],
          ['setCustomerUserId', 'user-1'],
          ['setOaidData', 'oaid-1'],
          ['setConsentData', ConsentMessage(isUserSubjectToGdpr: false)],
          ['enableTcfDataCollection', true],
          ['enableGppDataCollection', true],
          ['setThirdPartySharing', true],
          ['deepLinkListenerReady'],
        ]);
      },
    );

    test('lose to the config when both set an option', () async {
      final h = Harness();

      h.adshift
        ..setBrandedDomains(['old.example.com'])
        ..setDebugEnabled(true)
        ..setAppOpenDebounceMs(1)
        ..setMetaAppId('old');
      await h.initialize(
        const AdshiftConfig(
          apiKey: 'key-123',
          brandedDomains: ['new.example.com'],
          isDebug: false,
          appOpenDebounceMs: 2,
          metaAppId: 'new',
        ),
      );

      expect(
        h.host.argumentsOf('initialize').single.single,
        InitializeMessage(
          apiKey: 'key-123',
          brandedDomains: ['new.example.com'],
          isDebug: false,
          appOpenDebounceMs: 2,
          metaAppId: 'new',
        ),
      );
    });

    test(
      'append push paths made before initialize to the config paths',
      () async {
        final h = Harness();

        h.adshift.addPushNotificationDeepLinkPath(['data', 'early']);
        await h.initialize(
          const AdshiftConfig(
            apiKey: 'key-123',
            pushDeepLinkPaths: [
              ['data', 'from_config'],
            ],
          ),
        );

        expect(
          h.host.argumentsOf('initialize').single.single,
          InitializeMessage(
            apiKey: 'key-123',
            pushDeepLinkPaths: [
              ['data', 'from_config'],
              ['data', 'early'],
            ],
          ),
        );
        expect(h.host.count('addPushNotificationDeepLinkPath'), 0);
      },
    );

    test('apply the last value once when set repeatedly before '
        'initialize', () async {
      final h = Harness();

      h.adshift
        ..setCustomerUserId('user-1')
        ..setCustomerUserId('user-2')
        ..setCustomerUserId('user-3');
      await h.initialize();

      expect(h.host.argumentsOf('setCustomerUserId'), [
        ['user-3'],
      ]);
    });

    test('report a declined call through onError', () async {
      final h = Harness();
      await h.initialize();

      h.adshift.setCustomerUserId('');

      expect(h.host.count('setCustomerUserId'), 0);
      expect(h.errorCodes, [AdshiftErrorCode.invalidArgument]);
      expect(h.errors.single.message, contains('userId'));
    });

    test('survive an onError callback that throws', () async {
      final h = Harness();
      await h.initialize(
        AdshiftConfig(
          apiKey: 'key-123',
          onError: (_) => throw StateError('handler failure'),
        ),
      );

      h.adshift.setMetaAppId('');

      expect(h.logs.last, contains('handler failure'));
    });

    test('skip invalid arguments, before and after initialize', () async {
      void callAll(Harness h) => h.adshift
        ..setCustomerUserId('')
        ..setAppOpenDebounceMs(-1)
        ..setBrandedDomains(['a', ''])
        ..setMetaAppId(' ')
        ..setOaidData('')
        ..addPushNotificationDeepLinkPath([])
        ..addPushNotificationDeepLinkPath(['data', '']);

      final early = Harness();
      callAll(early);
      await early.initialize();
      expect(early.host.methods, [
        'registerHandler',
        'initialize',
        'deepLinkListenerReady',
      ]);
      expect(early.host.argumentsOf('initialize').single, [
        InitializeMessage(apiKey: 'key-123'),
      ]);

      final after = Harness();
      await after.initialize();
      after.host.calls.clear();
      callAll(after);
      expect(after.host.calls, isEmpty);
      expect(
        after.errorCodes,
        List.filled(7, AdshiftErrorCode.invalidArgument),
      );
    });

    test('reach the platform at once after initialize', () async {
      final h = Harness();
      await h.initialize();
      h.host.calls.clear();

      h.adshift
        ..setCustomerUserId('user-1')
        ..setDebugEnabled(true)
        ..setAppOpenDebounceMs(5000)
        ..setBrandedDomains(['links.example.com'])
        ..setMetaAppId('123')
        ..setOaidData('oaid-1')
        ..enableTCFDataCollection(true)
        ..enableGPPDataCollection(false)
        ..addPushNotificationDeepLinkPath(['data', 'link']);

      expect(h.host.calls, [
        ['setCustomerUserId', 'user-1'],
        ['setDebugEnabled', true],
        ['setAppOpenDebounceMs', 5000],
        [
          'setBrandedDomains',
          ['links.example.com'],
        ],
        ['setMetaAppId', '123'],
        ['setOaidData', 'oaid-1'],
        ['enableTcfDataCollection', true],
        ['enableGppDataCollection', false],
        [
          'addPushNotificationDeepLinkPath',
          ['data', 'link'],
        ],
      ]);
    });

    test('report a platform failure instead of throwing', () async {
      final h = Harness();
      await h.initialize();
      h.host.failure = PlatformException(code: 'E', message: 'lost');

      h.adshift.setCustomerUserId('user-1');
      await settle();

      expect(h.errorCodes, [AdshiftErrorCode.unknown]);
      expect(h.errors.single.nativeCode, 'E');
    });
  });

  group('consent', () {
    test(
      'sends every flag of a GDPR user, the undecided ones as null',
      () async {
        final h = Harness();
        await h.initialize();

        h.adshift.setConsentData(
          const AdshiftConsent.forGDPRUser(
            hasConsentForDataUsage: true,
            hasConsentForAdStorage: false,
          ),
        );
        h.adshift.setConsentData(const AdshiftConsent.forNonGDPRUser());

        expect(h.host.argumentsOf('setConsentData'), [
          [
            ConsentMessage(
              isUserSubjectToGdpr: true,
              hasConsentForDataUsage: true,
              hasConsentForAdStorage: false,
            ),
          ],
          [ConsentMessage(isUserSubjectToGdpr: false)],
        ]);
      },
    );

    test('sends the sharing answer and its withdrawal', () async {
      final h = Harness();
      await h.initialize();

      h.adshift
        ..setThirdPartySharing(const AdshiftThirdPartySharing.optedOut())
        ..setThirdPartySharing(const AdshiftThirdPartySharing.allowed())
        ..clearThirdPartySharing();

      expect(h.host.argumentsOf('setThirdPartySharing'), [
        [true],
        [false],
      ]);
      expect(h.host.count('clearThirdPartySharing'), 1);
    });

    test(
      'lets a clear made before initialize cancel an earlier answer',
      () async {
        final h = Harness();

        h.adshift
          ..setThirdPartySharing(const AdshiftThirdPartySharing.optedOut())
          ..clearThirdPartySharing();
        await h.initialize();

        expect(h.host.count('setThirdPartySharing'), 0);
        expect(h.host.count('clearThirdPartySharing'), 1);
      },
    );

    test(
      'lets an answer made before initialize cancel an earlier clear',
      () async {
        final h = Harness();

        h.adshift
          ..clearThirdPartySharing()
          ..setThirdPartySharing(const AdshiftThirdPartySharing.allowed());
        await h.initialize();

        expect(h.host.argumentsOf('setThirdPartySharing'), [
          [false],
        ]);
        expect(h.host.count('clearThirdPartySharing'), 0);
      },
    );

    test('refreshConsent returns the snapshot', () async {
      final h = Harness();
      expect(await h.adshift.refreshConsent(), isNull);
      expect(h.logs.single, contains('NOT_INITIALIZED'));
      expect(h.host.calls, isEmpty);

      await h.initialize();
      final snapshot = (await h.adshift.refreshConsent())!;

      expect(snapshot.source, AdshiftConsentSource.manual);
      expect(snapshot.gdprApplies, isNull);
      expect(snapshot.tcStringPresent, isFalse);
      expect(snapshot.gppPresent, isNull);
      expect(snapshot.cmpDetected, isFalse);
      expect(snapshot.adUserDataEnabled, isNull);
      expect(snapshot.adPersonalizationEnabled, isNull);
      expect(snapshot.adStorageEnabled, isTrue);
      expect(snapshot.appliedAtMillis, 1);
      expect(snapshot.adIdentifiersAllowed, isTrue);
    });

    test('refreshConsent carries every field and source', () async {
      final h = Harness();
      await h.initialize();
      h.host.consentSnapshot = ConsentSnapshotMessage(
        source: ConsentSourceMessage.tcf,
        gdprApplies: 1,
        tcStringPresent: true,
        gppPresent: true,
        cmpDetected: true,
        adUserDataEnabled: true,
        adPersonalizationEnabled: false,
        adStorageEnabled: false,
        appliedAtMillis: 1700000000000,
        adIdentifiersAllowed: false,
      );

      final snapshot = (await h.adshift.refreshConsent())!;

      expect(snapshot.source, AdshiftConsentSource.tcf);
      expect(snapshot.gdprApplies, 1);
      expect(snapshot.tcStringPresent, isTrue);
      expect(snapshot.gppPresent, isTrue);
      expect(snapshot.cmpDetected, isTrue);
      expect(snapshot.adUserDataEnabled, isTrue);
      expect(snapshot.adPersonalizationEnabled, isFalse);
      expect(snapshot.adStorageEnabled, isFalse);
      expect(snapshot.appliedAtMillis, 1700000000000);
      expect(snapshot.adIdentifiersAllowed, isFalse);

      for (final (message, source) in [
        (ConsentSourceMessage.manual, AdshiftConsentSource.manual),
        (ConsentSourceMessage.gpp, AdshiftConsentSource.gpp),
        (ConsentSourceMessage.none, AdshiftConsentSource.none),
      ]) {
        h.host.consentSnapshot!.source = message;
        expect((await h.adshift.refreshConsent())!.source, source);
      }
    });

    test('refreshConsent answers null and reports when the platform has no '
        'snapshot or fails', () async {
      final h = Harness();
      await h.initialize();

      h.host.consentSnapshot = null;
      expect(await h.adshift.refreshConsent(), isNull);
      expect(h.errorCodes, [AdshiftErrorCode.notInitialized]);

      h.host.failure = PlatformException(code: 'E', message: 'lost');
      expect(await h.adshift.refreshConsent(), isNull);
      expect(h.errorCodes.last, AdshiftErrorCode.unknown);
    });
  });

  group('getAdShiftDeviceId and getInfo', () {
    test('answers null before initialize and the id afterwards', () async {
      final h = Harness();
      expect(await h.adshift.getAdShiftDeviceId(), isNull);
      expect(h.host.calls, isEmpty);
      expect(h.logs, isEmpty);

      await h.initialize();
      expect(await h.adshift.getAdShiftDeviceId(), 'device-1');

      h.host.deviceId = '';
      expect(await h.adshift.getAdShiftDeviceId(), isNull);
      expect(h.errors, isEmpty);

      h.host.failure = PlatformException(code: 'E', message: 'lost');
      expect(await h.adshift.getAdShiftDeviceId(), isNull);
      expect(h.errorCodes, [AdshiftErrorCode.unknown]);
    });

    test('getInfo reports the platform and the versions', () {
      final h = Harness();
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final android = h.adshift.getInfo();
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      final ios = h.adshift.getInfo();

      expect(android.platform, 'android');
      expect(ios.platform, 'ios');
      expect(android.version, adshiftPluginVersion);
      expect(android.androidSdkVersion, androidSdkVersion);
      expect(android.iosSdkVersion, iosSdkVersion);
      expect(h.host.calls, isEmpty);
    });
  });

  group('push notifications', () {
    test('answers what the platform found in the payload', () async {
      final h = Harness();
      expect(await h.adshift.handlePushNotification({}), isFalse);
      expect(h.logs.single, contains('NOT_INITIALIZED'));
      expect(h.host.calls, isEmpty);

      await h.initialize();
      final payload = {
        'data': {'as_push_link': 'x'},
      };
      expect(await h.adshift.handlePushNotification(payload), isTrue);
      expect(h.host.argumentsOf('handlePushNotification'), [
        [payload],
      ]);

      h.host.pushNotificationResult = false;
      expect(await h.adshift.handlePushNotification(payload), isFalse);
      expect(h.errors, isEmpty);

      h.host.failure = PlatformException(code: 'E', message: 'lost');
      expect(await h.adshift.handlePushNotification(payload), isFalse);
      expect(h.errorCodes, [AdshiftErrorCode.unknown]);
    });
  });
}
