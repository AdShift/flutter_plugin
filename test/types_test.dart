import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:adshift_flutter_sdk/src/converters.dart';
import 'package:adshift_flutter_sdk/src/messages.g.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdshiftConfig', () {
    test('describes itself with the key masked', () {
      const config = AdshiftConfig(
        apiKey: 'secret-key-123',
        isDebug: true,
        brandedDomains: ['links.example.com'],
        deferredDeepLinkClipboard: AdshiftDeferredDeepLinkClipboard.prompt,
      );

      expect(
        '$config',
        'AdshiftConfig(apiKey: secr***, isDebug: true, '
            'brandedDomains: [links.example.com], '
            'deferredDeepLinkClipboard: prompt)',
      );
    });

    test('describes itself whatever the key length', () {
      for (final apiKey in ['', 'a', 'abc', 'abcd']) {
        expect(
          '${AdshiftConfig(apiKey: apiKey)}',
          'AdshiftConfig(apiKey: ***)',
        );
      }
      expect(
        '${const AdshiftConfig(apiKey: 'abcde')}',
        'AdshiftConfig(apiKey: abcd***)',
      );
    });

    test('leaves every option unset by default', () {
      const config = AdshiftConfig(apiKey: 'k');

      expect([
        config.isDebug,
        config.appOpenDebounceMs,
        config.brandedDomains,
        config.testMode,
        config.metaAppId,
        config.pushDeepLinkPaths,
        config.autoHandleDeepLinks,
        config.disableSKAN,
        config.waitForATTBeforeStart,
        config.attTimeoutMs,
        config.deferredDeepLinkClipboard,
        config.collectOaid,
        config.onError,
      ], everyElement(isNull));
    });
  });

  group('AdshiftConsent', () {
    test('keeps three states per flag for a GDPR user', () {
      const consent = AdshiftConsent.forGDPRUser(
        hasConsentForDataUsage: true,
        hasConsentForAdStorage: false,
      );

      expect(consent.isUserSubjectToGDPR, isTrue);
      expect(consent.hasConsentForDataUsage, isTrue);
      expect(consent.hasConsentForAdsPersonalization, isNull);
      expect(consent.hasConsentForAdStorage, isFalse);
    });

    test('carries no flags for a non-GDPR user', () {
      const consent = AdshiftConsent.forNonGDPRUser();

      expect(consent.isUserSubjectToGDPR, isFalse);
      expect(consent.hasConsentForDataUsage, isNull);
      expect(consent.hasConsentForAdsPersonalization, isNull);
      expect(consent.hasConsentForAdStorage, isNull);
    });

    test('isConsentGranted needs an explicit yes from a GDPR user', () {
      expect(const AdshiftConsent.forNonGDPRUser().isConsentGranted(), isTrue);
      expect(const AdshiftConsent.forGDPRUser().isConsentGranted(), isFalse);
      expect(
        const AdshiftConsent.forGDPRUser(
          hasConsentForDataUsage: true,
        ).isConsentGranted(),
        isFalse,
      );
      expect(
        const AdshiftConsent.forGDPRUser(
          hasConsentForDataUsage: true,
          hasConsentForAdStorage: false,
        ).isConsentGranted(),
        isFalse,
      );
      expect(
        const AdshiftConsent.forGDPRUser(
          hasConsentForDataUsage: true,
          hasConsentForAdStorage: true,
        ).isConsentGranted(),
        isTrue,
      );
    });

    test('compares by value', () {
      // Not const, so that equal values are different objects.
      AdshiftConsent gdpr({bool? dataUsage, bool? ads, bool? adStorage}) =>
          AdshiftConsent.forGDPRUser(
            hasConsentForDataUsage: dataUsage,
            hasConsentForAdsPersonalization: ads,
            hasConsentForAdStorage: adStorage,
          );

      expect(gdpr(dataUsage: true), gdpr(dataUsage: true));
      expect(gdpr(dataUsage: true).hashCode, gdpr(dataUsage: true).hashCode);
      expect(gdpr(dataUsage: true), isNot(gdpr(dataUsage: false)));
      expect(gdpr(dataUsage: true), isNot(gdpr()));
      expect(gdpr(ads: true), isNot(gdpr()));
      expect(gdpr(adStorage: true), isNot(gdpr()));
      expect(gdpr(), isNot(const AdshiftConsent.forNonGDPRUser()));
    });

    test('travels with its flags only for a GDPR user', () {
      expect(
        consentToMessage(
          const AdshiftConsent.forGDPRUser(hasConsentForAdStorage: true),
        ),
        ConsentMessage(isUserSubjectToGdpr: true, hasConsentForAdStorage: true),
      );
      expect(
        consentToMessage(const AdshiftConsent.forNonGDPRUser()),
        ConsentMessage(isUserSubjectToGdpr: false),
      );
    });
  });

  group('AdshiftThirdPartySharing', () {
    test('states the answer and compares by value', () {
      expect(const AdshiftThirdPartySharing.optedOut().optOut, isTrue);
      expect(const AdshiftThirdPartySharing.allowed().optOut, isFalse);
      expect(
        const AdshiftThirdPartySharing.optedOut(),
        isNot(const AdshiftThirdPartySharing.allowed()),
      );
      // Not const, so that the equal values are different objects.
      // ignore: prefer_const_constructors
      final optedOut = AdshiftThirdPartySharing.optedOut();
      expect(optedOut, const AdshiftThirdPartySharing.optedOut());
      expect(
        optedOut.hashCode,
        const AdshiftThirdPartySharing.optedOut().hashCode,
      );
    });
  });

  group('AdshiftDeepLink', () {
    test('found() carries the value, the params and where the link came '
        'from', () {
      const link = AdshiftDeepLink.found(
        deepLink: 'https://x',
        deepLinkValue: 'home',
        params: {'deep_link_value': 'home'},
        isDeferred: true,
        isFirstSession: true,
        source: AdshiftDeepLinkSource.deferred,
        clickId: 'c-1',
        matchGuaranteed: false,
        deepLinkSub1: '1',
        deepLinkSub2: '2',
        deepLinkSub3: '3',
        deepLinkSub4: '4',
        deepLinkSub5: '5',
      );

      expect(link.status, AdshiftDeepLinkStatus.found);
      expect(link.deepLink, 'https://x');
      expect(link.deepLinkValue, 'home');
      expect(link.params, {'deep_link_value': 'home'});
      expect(link.isDeferred, isTrue);
      expect(link.isFirstSession, isTrue);
      expect(link.source, AdshiftDeepLinkSource.deferred);
      expect(link.clickId, 'c-1');
      expect(link.matchGuaranteed, isFalse);
      expect(link.errorMessage, isNull);
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

    test('the builders set the status and leave the rest unset', () {
      const found = AdshiftDeepLink.found(deepLink: 'https://x');
      expect(found.status, AdshiftDeepLinkStatus.found);
      expect(found.isDeferred, isFalse);
      expect(found.deepLinkValue, isNull);

      const notFound = AdshiftDeepLink.notFound();
      expect(notFound.status, AdshiftDeepLinkStatus.notFound);
      expect(notFound.isDeferred, isFalse);
      expect(notFound.deepLink, isNull);

      const error = AdshiftDeepLink.error('offline');
      expect(error.status, AdshiftDeepLinkStatus.error);
      expect(error.errorMessage, 'offline');
      expect(error.isDeferred, isFalse);
    });

    test('the plain constructor builds the shapes the builders do not', () {
      const deferred = AdshiftDeepLink(
        status: AdshiftDeepLinkStatus.found,
        isDeferred: true,
        deepLinkValue: 'promo',
      );
      const ownUrl = AdshiftDeepLink(
        status: AdshiftDeepLinkStatus.notFound,
        deepLink: 'myapp://settings',
      );

      expect(deferred.deepLink, isNull);
      expect(deferred.deepLinkValue, 'promo');
      expect(ownUrl.deepLink, 'myapp://settings');
      expect(ownUrl.isDeferred, isFalse);
    });
  });

  group('results and errors', () {
    test('a result succeeds exactly when it carries no error', () {
      const error = AdshiftError(AdshiftErrorCode.queueFull, 'full');

      expect(const AdshiftResult.success().success, isTrue);
      expect(const AdshiftResult.success().error, isNull);
      expect(const AdshiftResult.failure(error).success, isFalse);
      expect(const AdshiftResult.failure(error).error, same(error));

      expect(const AdshiftStartResult.success().success, isTrue);
      expect(const AdshiftStartResult.success().apiKeyValidationStatus, isNull);
      expect(const AdshiftStartResult.failure(error).success, isFalse);
      expect(const AdshiftStartResult.failure(error).error, same(error));
    });

    test('an error describes itself with its wire code', () {
      const error = AdshiftError(
        AdshiftErrorCode.unknown,
        'native failure',
        nativeCode: 'E_NATIVE',
        nativeDomain: 'com.adshift.sdk',
      );

      expect('$error', 'AdshiftError(UNKNOWN): native failure');
      expect(error.nativeCode, 'E_NATIVE');
      expect(error.nativeDomain, 'com.adshift.sdk');
    });

    test('whatever the platform throws becomes UNKNOWN', () {
      final platform = errorFromThrown(
        PlatformException(code: 'channel-error', message: 'no connection'),
      );
      expect(platform.code, AdshiftErrorCode.unknown);
      expect(platform.message, 'no connection');
      expect(platform.nativeCode, 'channel-error');

      final bare = errorFromThrown(PlatformException(code: 'E'));
      expect(bare.message, 'Unknown error');
      expect(bare.nativeCode, 'E');

      final other = errorFromThrown(MissingPluginException('not registered'));
      expect(other.code, AdshiftErrorCode.unknown);
      expect(other.message, contains('not registered'));
      expect(other.nativeCode, isNull);
    });

    test('values describe themselves for logs', () {
      expect(
        '${const AdshiftResult.failure(AdshiftError(AdshiftErrorCode.optedOut, 'off'))}',
        'AdshiftResult.failure(AdshiftError(OPTED_OUT): off)',
      );
      expect(
        '${const AdshiftStartResult.success(apiKeyValidationStatus: AdshiftApiKeyValidationStatus.valid)}',
        'AdshiftStartResult.success(valid)',
      );
      expect(
        '${const AdshiftDeepLink.found(deepLink: 'https://x', source: AdshiftDeepLinkSource.appLink)}',
        'AdshiftDeepLink(status: found, isDeferred: false, '
            'deepLink: https://x, deepLinkValue: null, source: app_link)',
      );
      expect(
        '${const AdshiftConsent.forNonGDPRUser()}',
        'AdshiftConsent.forNonGDPRUser()',
      );
      expect(
        '${const AdshiftThirdPartySharing.optedOut()}',
        'AdshiftThirdPartySharing.optedOut()',
      );
    });
  });

  group('wire names', () {
    // Spelled out so adding, renaming or dropping one is a deliberate edit:
    // these values are public API.
    test('the 30 event names', () {
      expect(AdshiftEventType.all.toList()..sort(), [
        'as_achievement_unlocked',
        'as_ad_click',
        'as_ad_revenue',
        'as_ad_view',
        'as_add_payment_info',
        'as_add_to_cart',
        'as_add_to_wishlist',
        'as_complete_registration',
        'as_content_view',
        'as_customer_segment',
        'as_initiated_checkout',
        'as_invite',
        'as_level_achieved',
        'as_list_view',
        'as_location_changed',
        'as_location_coordinates',
        'as_login',
        'as_opened_from_push_notification',
        'as_order_id',
        'as_purchase',
        'as_rate',
        'as_re_engage',
        'as_search',
        'as_share',
        'as_spent_credits',
        'as_start_trial',
        'as_subscribe',
        'as_travel_booking',
        'as_tutorial_completion',
        'as_update',
      ]);
      expect(AdshiftEventType.all.toSet(), hasLength(30));
      expect(AdshiftEventType.adRevenue, 'as_ad_revenue');
    });

    test('the 14 mediation networks', () {
      expect(
        {
          for (final network in AdshiftMediationNetwork.values)
            network.name: network.wireName,
        },
        {
          'appLovinMax': 'applovin_max',
          'googleAdMob': 'google_admob',
          'ironSource': 'ironsource',
          'chartboost': 'chartboost',
          'topOn': 'topon',
          'tradPlus': 'tradplus',
          'adMost': 'admost',
          'appodeal': 'appodeal',
          'fyber': 'fyber',
          'unity': 'unity',
          'yandex': 'yandex',
          'customMediation': 'custom_mediation',
          'directMonetization': 'direct_monetization_network',
          'other': 'other',
        },
      );
    });

    test('the 9 deep link sources', () {
      expect(
        {
          for (final source in AdshiftDeepLinkSource.values)
            source.name: source.wireName,
        },
        {
          'universalLink': 'ul',
          'appLink': 'app_link',
          'scheme': 'scheme',
          'cta': 'cta',
          'push': 'push',
          'adAttributionKit': 'aak',
          'metaAppLink': 'meta_applink',
          'deferred': 'deferred',
          'foreign': 'foreign',
        },
      );
    });

    test('the 7 error codes', () {
      expect(
        {for (final code in AdshiftErrorCode.values) code.name: code.wireName},
        {
          'notInitialized': 'NOT_INITIALIZED',
          'notStarted': 'NOT_STARTED',
          'invalidApiKey': 'INVALID_API_KEY',
          'optedOut': 'OPTED_OUT',
          'queueFull': 'QUEUE_FULL',
          'invalidArgument': 'INVALID_ARGUMENT',
          'unknown': 'UNKNOWN',
        },
      );
    });

    test('the other enums', () {
      expect(AdshiftDeepLinkStatus.values.map((v) => v.name), [
        'found',
        'notFound',
        'error',
      ]);
      expect(AdshiftConsentSource.values.map((v) => v.name), [
        'manual',
        'tcf',
        'gpp',
        'none',
      ]);
      expect(AdshiftApiKeyValidationStatus.values.map((v) => v.name), [
        'pending',
        'valid',
        'invalid',
      ]);
      expect(AdshiftDeferredDeepLinkClipboard.values.map((v) => v.name), [
        'disabled',
        'prompt',
        'pasteControl',
      ]);
    });
  });
}
