import 'dart:async';

import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

List<String?> collect(Harness h) {
  final seen = <String?>[];
  h.adshift.onDeepLink.listen((link) => seen.add(link.deepLink));
  return seen;
}

void main() {
  group('onDeepLink delivery', () {
    test('can be listened to before initialize and receives live '
        'results', () async {
      final h = Harness();
      final seen = <AdshiftDeepLink>[];
      h.adshift.onDeepLink.listen(seen.add);
      await h.initialize();

      h.emit(
        DeepLinkMessage(
          status: DeepLinkStatusMessage.found,
          isDeferred: false,
          deepLink: 'https://links.example.com/p?deep_link_value=home',
          params: {'deep_link_value': 'home', 'deep_link_sub1': 'a'},
        ),
      );
      await settle();

      final link = seen.single;
      expect(link.status, AdshiftDeepLinkStatus.found);
      expect(link.isDeferred, isFalse);
      expect(link.deepLink, 'https://links.example.com/p?deep_link_value=home');
      expect(link.deepLinkValue, 'home');
      expect(link.deepLinkSub1, 'a');
    });

    test('is a broadcast stream, the same one on every read', () {
      final h = Harness();

      expect(h.adshift.onDeepLink.isBroadcast, isTrue);
      expect(h.adshift.onDeepLink, same(h.adshift.onDeepLink));
    });

    test('holds results until the first listener and keeps their '
        'order', () async {
      final h = Harness();
      await h.initialize();
      h.emit(foundLink('https://a'));
      h.emit(foundLink('https://b', isDeferred: true));
      await settle();

      final seen = collect(h);
      // Listeners added in the same turn receive the held results as well.
      final alsoSeen = collect(h);
      expect(seen, isEmpty);
      await settle();
      expect(seen, ['https://a', 'https://b']);
      expect(alsoSeen, seen);

      h.emit(foundLink('https://c'));
      await settle();
      expect(seen, ['https://a', 'https://b', 'https://c']);
    });

    test('delivers each result once, to the listeners present at that '
        'moment', () async {
      final h = Harness();
      await h.initialize();
      h.emit(foundLink('https://held'));
      final first = collect(h);
      await settle();

      final second = collect(h);
      h.emit(foundLink('https://live'));
      await settle();

      expect(first, ['https://held', 'https://live']);
      expect(second, ['https://live']);
    });

    test('keeps arrival order when a result lands before the held ones are '
        'delivered', () async {
      final h = Harness();
      await h.initialize();
      h.emit(foundLink('https://deferred', isDeferred: true));

      final seen = collect(h);
      h.emit(foundLink('https://tapped'));
      await settle();

      expect(seen, ['https://deferred', 'https://tapped']);
    });

    test('holds results again for a later listener once the previous one '
        'left', () async {
      final h = Harness();
      await h.initialize();
      final first = h.adshift.onDeepLink.listen((_) {});
      await first.cancel();
      await first.cancel();
      h.emit(foundLink('https://held'));
      await settle();

      final seen = collect(h);
      await settle();

      expect(seen, ['https://held']);
    });

    test('keeps the 20 newest direct results and never drops a deferred '
        'one', () async {
      final h = Harness();
      await h.initialize();
      h.emit(foundLink('https://deferred', isDeferred: true));
      for (var i = 0; i < 25; i++) {
        h.emit(foundLink('https://direct/$i'));
      }

      final seen = collect(h);
      await settle();

      // Spelled out, because a buffer that dropped from the wrong end would
      // still have the right length and the right first and last entry.
      expect(seen, [
        'https://deferred',
        for (var i = 6; i < 25; i++) 'https://direct/$i',
      ]);
    });

    test('drops a direct result when only deferred ones are held, and the '
        'oldest deferred one for a newer', () async {
      final h = Harness();
      await h.initialize();
      for (var i = 0; i < 20; i++) {
        h.emit(foundLink('https://deferred/$i', isDeferred: true));
      }
      h.emit(foundLink('https://direct'));
      h.emit(foundLink('https://deferred/20', isDeferred: true));

      final seen = collect(h);
      await settle();

      expect(seen, [for (var i = 1; i <= 20; i++) 'https://deferred/$i']);
      expect(h.logs.single, contains('dropping a direct deep link'));
    });

    test('contains a listener that throws', () async {
      final h = Harness();
      await h.initialize();
      final seen = <String?>[];
      h.adshift.onDeepLink.listen((_) => throw StateError('listener failure'));
      late final StreamSubscription<AdshiftDeepLink> second;
      second = h.adshift.onDeepLink.listen((link) {
        seen.add(link.deepLink);
        second.cancel();
      });
      h.adshift.onDeepLink.listen((link) => seen.add('third:${link.deepLink}'));

      h.emit(foundLink('https://x'));
      h.emit(foundLink('https://y'));
      await settle();

      expect(seen, ['https://x', 'third:https://x', 'third:https://y']);
      expect(h.logs, hasLength(2));
      expect(h.logs.first, contains('listener threw'));
      expect(h.logs.first, contains('listener failure'));
    });

    test('works with await for and stream transformations', () async {
      final h = Harness();
      await h.initialize();
      h.emit(foundLink('https://a'));
      h.emit(foundLink('https://b', isDeferred: true));

      final deferred = await h.adshift.onDeepLink
          .where((link) => link.isDeferred)
          .map((link) => link.deepLink)
          .first;

      expect(deferred, 'https://b');
    });
  });

  group('what a result carries', () {
    Future<AdshiftDeepLink> deliver(DeepLinkMessage message) async {
      final h = Harness();
      await h.initialize();
      final seen = <AdshiftDeepLink>[];
      h.adshift.onDeepLink.listen(seen.add);
      h.emit(message);
      await settle();
      return seen.single;
    }

    test('every field the platform states', () async {
      final link = await deliver(
        DeepLinkMessage(
          status: DeepLinkStatusMessage.found,
          isDeferred: true,
          deepLink: 'https://links.example.com/p',
          deepLinkValue: 'promo',
          params: {'deep_link_value': 'other', 'utm': 'x'},
          source: DeepLinkSourceMessage.deferred,
          clickId: 'click-1',
          matchGuaranteed: false,
          isFirstSession: true,
          sub1: '1',
          sub2: '2',
          sub3: '3',
          sub4: '4',
          sub5: '5',
        ),
      );

      expect(link.status, AdshiftDeepLinkStatus.found);
      expect(link.isDeferred, isTrue);
      expect(link.deepLink, 'https://links.example.com/p');
      expect(link.deepLinkValue, 'promo');
      expect(link.params, {'deep_link_value': 'other', 'utm': 'x'});
      expect(link.errorMessage, isNull);
      expect(link.source, AdshiftDeepLinkSource.deferred);
      expect(link.clickId, 'click-1');
      expect(link.matchGuaranteed, isFalse);
      expect(link.isFirstSession, isTrue);
      expect(
        [
          link.deepLinkSub1,
          link.deepLinkSub2,
          link.deepLinkSub3,
          link.deepLinkSub4,
          link.deepLinkSub5,
        ],
        ['1', '2', '3', '4', '5'],
      );
    });

    test('the routing value and the sub-parameters from params when the '
        'platform left them out', () async {
      final link = await deliver(
        DeepLinkMessage(
          status: DeepLinkStatusMessage.found,
          isDeferred: false,
          params: {
            'deep_link_value': 'home',
            for (var i = 1; i <= 5; i++) 'deep_link_sub$i': 'sub$i',
          },
        ),
      );

      expect(link.deepLinkValue, 'home');
      expect(
        [
          link.deepLinkSub1,
          link.deepLinkSub2,
          link.deepLinkSub3,
          link.deepLinkSub4,
          link.deepLinkSub5,
        ],
        ['sub1', 'sub2', 'sub3', 'sub4', 'sub5'],
      );
    });

    test(
      'no params when they are empty, no click id when it is empty',
      () async {
        final link = await deliver(
          DeepLinkMessage(
            status: DeepLinkStatusMessage.notFound,
            isDeferred: true,
            params: {},
            clickId: '',
            isFirstSession: true,
          ),
        );

        expect(link.status, AdshiftDeepLinkStatus.notFound);
        expect(link.isDeferred, isTrue);
        expect(link.params, isNull);
        expect(link.clickId, isNull);
        expect(link.deepLink, isNull);
        expect(link.deepLinkValue, isNull);
        expect(link.source, isNull);
        expect(link.isFirstSession, isTrue);
      },
    );

    test('params the app cannot change for the other listeners', () async {
      final link = await deliver(
        DeepLinkMessage(
          status: DeepLinkStatusMessage.found,
          isDeferred: false,
          params: {'a': 'b'},
        ),
      );

      expect(() => link.params!['c'] = 'd', throwsUnsupportedError);
    });

    test('a link that is not a RightLink link as notFound with its '
        'URL', () async {
      final link = await deliver(
        DeepLinkMessage(
          status: DeepLinkStatusMessage.notFound,
          isDeferred: false,
          deepLink: 'myapp://settings',
          source: DeepLinkSourceMessage.scheme,
          isFirstSession: false,
        ),
      );

      expect(link.status, AdshiftDeepLinkStatus.notFound);
      expect(link.deepLink, 'myapp://settings');
      expect(link.params, isNull);
      expect(link.source, AdshiftDeepLinkSource.scheme);
      expect(link.isFirstSession, isFalse);
    });

    test('an error with its message', () async {
      final link = await deliver(
        DeepLinkMessage(
          status: DeepLinkStatusMessage.error,
          isDeferred: false,
          deepLink: 'https://app.rightlink.me/abc',
          errorMessage: 'Network error',
        ),
      );

      expect(link.status, AdshiftDeepLinkStatus.error);
      expect(link.errorMessage, 'Network error');
    });

    test('every source', () async {
      for (final (message, source) in [
        (
          DeepLinkSourceMessage.universalLink,
          AdshiftDeepLinkSource.universalLink,
        ),
        (DeepLinkSourceMessage.appLink, AdshiftDeepLinkSource.appLink),
        (DeepLinkSourceMessage.scheme, AdshiftDeepLinkSource.scheme),
        (DeepLinkSourceMessage.cta, AdshiftDeepLinkSource.cta),
        (DeepLinkSourceMessage.push, AdshiftDeepLinkSource.push),
        (
          DeepLinkSourceMessage.adAttributionKit,
          AdshiftDeepLinkSource.adAttributionKit,
        ),
        (DeepLinkSourceMessage.metaAppLink, AdshiftDeepLinkSource.metaAppLink),
        (DeepLinkSourceMessage.deferred, AdshiftDeepLinkSource.deferred),
        (DeepLinkSourceMessage.foreign, AdshiftDeepLinkSource.foreign),
      ]) {
        final link = await deliver(
          DeepLinkMessage(
            status: DeepLinkStatusMessage.found,
            isDeferred: false,
            source: message,
          ),
        );
        expect(link.source, source);
      }
    });
  });

  group('handlePastedDeepLink', () {
    test('passes the pasted URL, or null for a skipped paste', () async {
      final h = Harness();
      await h.initialize();

      h.adshift
        ..handlePastedDeepLink(
          Uri.parse('https://app.rightlink.me/_c/abcdefghijklmnop'),
        )
        ..handlePastedDeepLink(null)
        ..handlePastedDeepLink(Uri());

      expect(h.host.argumentsOf('handlePastedDeepLink'), [
        ['https://app.rightlink.me/_c/abcdefghijklmnop'],
        [null],
        [null],
      ]);
    });

    test('reports a call before initialize', () {
      final h = Harness();

      h.adshift.handlePastedDeepLink(null);

      expect(h.logs.single, contains('NOT_INITIALIZED'));
      expect(h.host.calls, isEmpty);
    });
  });

  group('handleDeepLink', () {
    test('reports a call before initialize and an empty URL', () async {
      final h = Harness();
      await h.adshift.handleDeepLink(Uri.parse('https://x'));
      expect(h.logs.single, contains('NOT_INITIALIZED'));

      await h.initialize();
      await h.adshift.handleDeepLink(Uri());

      expect(h.errorCodes, [AdshiftErrorCode.invalidArgument]);
      expect(h.host.count('handleDeepLink'), 0);
    });

    test('passes the URL on in every state after initialize', () async {
      final h = Harness();
      await h.initialize();

      await h.adshift.handleDeepLink(Uri.parse('https://x/a?b=c'));
      await h.adshift.start();
      await h.adshift.handleDeepLink(Uri.parse('https://x/started'));
      h.adshift.stop();
      await h.adshift.handleDeepLink(Uri.parse('https://x/stopped'));
      // The same URL again goes through as well: repeats are told apart on
      // the platform side.
      await h.adshift.handleDeepLink(Uri.parse('https://x/stopped'));

      expect(h.host.argumentsOf('handleDeepLink'), [
        ['https://x/a?b=c'],
        ['https://x/started'],
        ['https://x/stopped'],
        ['https://x/stopped'],
      ]);
      expect(h.errors, isEmpty);
    });

    test('reports a problem the platform had with the link', () async {
      final h = Harness();
      await h.initialize();

      h.host.onHandleDeepLink = () async =>
          ErrorMessage(code: ErrorCodeMessage.invalidArgument, message: 'bad');
      await h.adshift.handleDeepLink(Uri.parse('nope'));
      expect(h.errorCodes, [AdshiftErrorCode.invalidArgument]);

      h.host.failure = PlatformException(
        code: 'E_SOMETHING_NEW',
        message: 'from the future',
      );
      await h.adshift.handleDeepLink(Uri.parse('https://z'));
      expect(h.errors.last.code, AdshiftErrorCode.unknown);
      expect(h.errors.last.message, 'from the future');
      expect(h.errors.last.nativeCode, 'E_SOMETHING_NEW');
    });
  });
}
