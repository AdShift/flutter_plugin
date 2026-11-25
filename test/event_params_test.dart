import 'dart:io';

import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:adshift_flutter_sdk/src/plain_param_names.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/harness.dart';

/// Spelled out so a rename on either platform has to be repeated here on
/// purpose.
const wireNames = [
  'as_achievement_id',
  'as_adrev_ad_size',
  'as_adrev_ad_type',
  'as_adrev_ad_unit_id',
  'as_adrev_mediated_network_name',
  'as_adrev_network_name',
  'as_adrev_placement_id',
  'as_adrev_precision',
  'as_adrev_source',
  'as_channel',
  'as_city',
  'as_class',
  'as_content',
  'as_content_id',
  'as_content_list',
  'as_content_type',
  'as_country',
  'as_coupon_code',
  'as_currency',
  'as_customer_user_id',
  'as_date_a',
  'as_date_b',
  'as_deep_link',
  'as_departing_arrival_date',
  'as_departing_departure_date',
  'as_description',
  'as_destination_a',
  'as_destination_b',
  'as_destination_list',
  'as_event_end',
  'as_event_start',
  'as_hotel_score',
  'as_lat',
  'as_level',
  'as_long',
  'as_max_rating_value',
  'as_new_version',
  'as_num_adults',
  'as_num_children',
  'as_num_infants',
  'as_old_version',
  'as_order_id',
  'as_param_1',
  'as_param_10',
  'as_param_2',
  'as_param_3',
  'as_param_4',
  'as_param_5',
  'as_param_6',
  'as_param_7',
  'as_param_8',
  'as_param_9',
  'as_payment_info_available',
  'as_preferred_neighborhoods',
  'as_preferred_num_stops',
  'as_preferred_price_range',
  'as_preferred_star_ratings',
  'as_price',
  'as_projected_revenue',
  'as_purchase_currency',
  'as_quantity',
  'as_rating_value',
  'as_receipt_id',
  'as_region',
  'as_registration_method',
  'as_returning_arrival_date',
  'as_returning_departure_date',
  'as_revenue',
  'as_review_text',
  'as_score',
  'as_search_string',
  'as_success',
  'as_suggested_destinations',
  'as_suggested_hotels',
  'as_touch_obj',
  'as_travel_end',
  'as_travel_start',
  'as_tutorial_id',
  'as_user_score',
  'as_validated',
  'as_virtual_currency_name',
];

/// The constants as declared in the source: name to wire name.
Map<String, String> declaredConstants() => {
  for (final match
      in RegExp(r"static const String (\w+) =\s+'(\w+)';").allMatches(
        File('lib/src/models/adshift_event_param.dart').readAsStringSync(),
      ))
    match[1]!: match[2]!,
};

void main() {
  group('AdshiftEventParam', () {
    test('exposes exactly the 81 names the native SDKs define', () {
      expect(wireNames, hasLength(81));
      expect(AdshiftEventParam.all.toList()..sort(), wireNames);
    });

    test('lists every declared constant in all, each once', () {
      final declared = declaredConstants();

      expect(declared, hasLength(81));
      expect(AdshiftEventParam.all, declared.values);
      expect(declared.values.toSet(), hasLength(81));
    });

    test('keeps revenue and currency on their wire names', () {
      expect(AdshiftEventParam.revenue, 'as_revenue');
      expect(AdshiftEventParam.currency, 'as_currency');
    });
  });

  group('plain parameter names', () {
    Future<Harness> started() async {
      final h = Harness();
      await h.initializeAndStart();
      return h;
    }

    test('know the constant behind every wire name', () {
      expect({
        for (final wireName in AdshiftEventParam.all)
          eventParamConstant(wireName): wireName,
      }, declaredConstants());
    });

    test(
      'name the constant to use and still send the value untouched',
      () async {
        final h = await started();

        await h.adshift.trackEvent('checkout', values: {'price': 29.99});

        expect(h.logs.single, contains('AdshiftEventParam.price'));
        expect(h.logs.single, contains('as_price'));
        expect(h.host.argumentsOf('trackEvent').single, [
          'checkout',
          {'price': 29.99},
        ]);
      },
    );

    test('recognise snake case, camel case and the constant name', () async {
      final h = await started();

      await h.adshift.trackEvent(
        'e',
        values: {
          'content_id': 'SKU1',
          'contentId': 'SKU1',
          'latitude': 52.2,
          'lat': 52.2,
          'class': 'economy',
        },
      );

      expect(h.logs, [
        contains('AdshiftEventParam.contentId'),
        contains('AdshiftEventParam.contentId'),
        contains('AdshiftEventParam.latitude'),
        contains('AdshiftEventParam.latitude'),
        contains('AdshiftEventParam.classValue'),
      ]);
    });

    test('stay quiet for standard names and for names of your own', () async {
      final h = await started();

      await h.adshift.trackEvent(
        'e',
        values: {
          AdshiftEventParam.revenue: 9.99,
          AdshiftEventParam.currency: 'USD',
          'shirt_size': 'XL',
        },
      );

      expect(h.logs, isEmpty);
    });

    test('warn once per name, however many events carry it', () async {
      final h = await started();

      await h.adshift.trackEvent('first', values: {'quantity': 1});
      await h.adshift.trackEvent('second', values: {'quantity': 2});

      expect(h.logs, hasLength(1));
    });

    test('cover the additional parameters of logAdRevenue', () async {
      final h = await started();

      await h.adshift.logAdRevenue(
        monetizationNetwork: 'admob',
        mediationNetwork: AdshiftMediationNetwork.googleAdMob,
        currency: 'USD',
        revenue: 0.01,
        additionalParameters: {'adRevenueAdSize': '320x50'},
      );

      expect(h.logs.single, contains('AdshiftEventParam.adRevenueAdSize'));
    });
  });
}
