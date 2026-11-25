import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:adshift_flutter_sdk/src/adshift_impl.dart';
import 'package:adshift_flutter_sdk/src/messages.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart' show settle;

const codec = AdshiftHostApi.pigeonChannelCodec;
const channelPrefix = 'dev.flutter.pigeon.adshift_flutter_sdk';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUp(() {
    final printed = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
    addTearDown(() => debugPrint = printed);
  });

  /// Answers the platform call [method] with [reply], and records it.
  void answer(String method, Object? reply, List<String> received) {
    final channel = BasicMessageChannel<Object?>(
      '$channelPrefix.AdshiftHostApi.$method',
      codec,
    );
    messenger.setMockDecodedMessageHandler<Object?>(channel, (message) async {
      received.add(method);
      return <Object?>[reply];
    });
    addTearDown(
      () => messenger.setMockDecodedMessageHandler<Object?>(channel, null),
    );
  }

  test('without a platform side every call is answered, none throws', () async {
    final errors = <AdshiftError>[];
    final sdk = createAdshift();

    sdk.initialize(AdshiftConfig(apiKey: 'key-123', onError: errors.add));
    final started = await sdk.start();
    final tracked = await sdk.trackEvent('e');

    expect(errors.single.code, AdshiftErrorCode.unknown);
    expect(errors.single.nativeCode, 'channel-error');
    expect(started.error, same(errors.single));
    expect(tracked.error!.code, AdshiftErrorCode.notInitialized);
    expect(sdk.isStarted, isFalse);
  });

  test('over the real channels it initializes, starts and receives a deep '
      'link', () async {
    final received = <String>[];
    answer('initialize', null, received);
    answer('deepLinkListenerReady', null, received);
    answer(
      'start',
      StartMessage(success: true, keyStatus: KeyStatusMessage.valid),
      received,
    );
    answer('trackEvent', null, received);
    final errors = <AdshiftError>[];
    final sdk = createAdshift();
    final links = <AdshiftDeepLink>[];
    sdk.onDeepLink.listen(links.add);

    sdk.initialize(AdshiftConfig(apiKey: 'key-123', onError: errors.add));
    final started = await sdk.start();
    final tracked = await sdk.trackEvent('e', values: {'n': 1, 'ok': true});
    await messenger.handlePlatformMessage(
      '$channelPrefix.AdshiftFlutterApi.onDeepLink',
      codec.encodeMessage(<Object?>[
        DeepLinkMessage(
          status: DeepLinkStatusMessage.found,
          isDeferred: false,
          deepLink: 'https://links.example.com/p',
          params: {'deep_link_value': 'home'},
          source: DeepLinkSourceMessage.appLink,
        ),
      ]),
      (_) {},
    );
    await settle();

    expect(errors, isEmpty);
    expect(received, [
      'initialize',
      'deepLinkListenerReady',
      'start',
      'trackEvent',
    ]);
    // A value the channel cannot carry is reported, not thrown.
    expect(await sdk.handlePushNotification({'when': DateTime(2026)}), isFalse);
    expect(errors.single.code, AdshiftErrorCode.unknown);
    expect(started.success, isTrue);
    expect(started.apiKeyValidationStatus, AdshiftApiKeyValidationStatus.valid);
    expect(tracked.success, isTrue);
    expect(links.single.deepLinkValue, 'home');
    expect(links.single.source, AdshiftDeepLinkSource.appLink);
  });
}
