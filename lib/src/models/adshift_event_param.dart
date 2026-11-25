/// Standard names for the values of `Adshift.instance.trackEvent()`.
///
/// Reports add up only these; any other key is kept as a custom parameter and
/// never counted, so use the constants for revenue above all.
///
/// `Adshift.instance.logAdRevenue()` fills [revenue], [currency],
/// [adRevenueSource] and [adRevenueNetworkName] itself and drops them from
/// `additionalParameters`.
abstract final class AdshiftEventParam {
  /// Price of an item.
  static const String price = 'as_price';

  /// The number reports read as revenue. Always pair it with [currency].
  static const String revenue = 'as_revenue';

  /// Revenue you expect rather than money already taken.
  static const String projectedRevenue = 'as_projected_revenue';

  /// ISO 4217 code, e.g. `USD`.
  static const String currency = 'as_currency';

  /// Number of items.
  static const String quantity = 'as_quantity';

  /// Receipt identifier.
  static const String receiptId = 'as_receipt_id';

  /// Your own order identifier, for matching purchases with your records.
  static const String orderId = 'as_order_id';

  /// Coupon code that was used.
  static const String couponCode = 'as_coupon_code';

  /// Whether payment details are available.
  static const String paymentInfoAvailable = 'as_payment_info_available';

  /// Whether the purchase was validated.
  static const String validated = 'as_validated';

  /// Type or category of the content.
  static const String contentType = 'as_content_type';

  /// Identifier of the content or product.
  static const String contentId = 'as_content_id';

  /// List of content identifiers.
  static const String contentList = 'as_content_list';

  /// The content itself, e.g. a product name.
  static const String content = 'as_content';

  /// Class of the item, e.g. a travel class. Named `classValue` because
  /// `class` is a reserved word in Dart.
  static const String classValue = 'as_class';

  /// Free-text description.
  static const String description = 'as_description';

  /// The search query.
  static const String searchString = 'as_search_string';

  /// Rating that was given.
  static const String ratingValue = 'as_rating_value';

  /// Highest possible rating.
  static const String maxRatingValue = 'as_max_rating_value';

  /// Text of a review.
  static const String reviewText = 'as_review_text';

  /// Your own user id.
  static const String customerUserId = 'as_customer_user_id';

  /// How the user registered, e.g. `email`.
  static const String registrationMethod = 'as_registration_method';

  /// Level that was reached.
  static const String level = 'as_level';

  /// Score that was reached.
  static const String score = 'as_score';

  /// Whether the action succeeded.
  static const String success = 'as_success';

  /// Identifier of the tutorial.
  static const String tutorialId = 'as_tutorial_id';

  /// Identifier of the achievement.
  static const String achievementId = 'as_achievement_id';

  /// Name of the in-app currency.
  static const String virtualCurrencyName = 'as_virtual_currency_name';

  /// Deep link that led to the event.
  static const String deepLink = 'as_deep_link';

  /// App version before an update.
  static const String oldVersion = 'as_old_version';

  /// App version after an update.
  static const String newVersion = 'as_new_version';

  /// Channel the action went through, e.g. where content was shared.
  static const String channel = 'as_channel';

  /// Object the user interacted with.
  static const String touchObj = 'as_touch_obj';

  /// First date of a range.
  static const String dateA = 'as_date_a';

  /// Second date of a range.
  static const String dateB = 'as_date_b';

  /// When the event starts.
  static const String eventStart = 'as_event_start';

  /// When the event ends.
  static const String eventEnd = 'as_event_end';

  /// Latitude.
  static const String latitude = 'as_lat';

  /// Longitude.
  static const String longitude = 'as_long';

  /// City.
  static const String city = 'as_city';

  /// Region.
  static const String region = 'as_region';

  /// Country.
  static const String country = 'as_country';

  /// First destination.
  static const String destinationA = 'as_destination_a';

  /// Second destination.
  static const String destinationB = 'as_destination_b';

  /// List of destinations.
  static const String destinationList = 'as_destination_list';

  /// Departure date of the outbound trip.
  static const String departingDepartureDate = 'as_departing_departure_date';

  /// Departure date of the return trip.
  static const String returningDepartureDate = 'as_returning_departure_date';

  /// Arrival date of the outbound trip.
  static const String departingArrivalDate = 'as_departing_arrival_date';

  /// Arrival date of the return trip.
  static const String returningArrivalDate = 'as_returning_arrival_date';

  /// Start of the trip.
  static const String travelStart = 'as_travel_start';

  /// End of the trip.
  static const String travelEnd = 'as_travel_end';

  /// Destinations suggested to the user.
  static const String suggestedDestinations = 'as_suggested_destinations';

  /// Hotels suggested to the user.
  static const String suggestedHotels = 'as_suggested_hotels';

  /// Number of adults.
  static const String numAdults = 'as_num_adults';

  /// Number of children.
  static const String numChildren = 'as_num_children';

  /// Number of infants.
  static const String numInfants = 'as_num_infants';

  /// Score given by the user.
  static const String userScore = 'as_user_score';

  /// Score of the hotel.
  static const String hotelScore = 'as_hotel_score';

  /// Currency of the purchase, as an ISO 4217 code.
  static const String purchaseCurrency = 'as_purchase_currency';

  /// Hotel star ratings the user prefers.
  static const String preferredStarRatings = 'as_preferred_star_ratings';

  /// Price range the user prefers.
  static const String preferredPriceRange = 'as_preferred_price_range';

  /// Neighbourhoods the user prefers.
  static const String preferredNeighborhoods = 'as_preferred_neighborhoods';

  /// Number of stops the user prefers.
  static const String preferredNumStops = 'as_preferred_num_stops';

  /// Custom parameter 1.
  static const String param1 = 'as_param_1';

  /// Custom parameter 2.
  static const String param2 = 'as_param_2';

  /// Custom parameter 3.
  static const String param3 = 'as_param_3';

  /// Custom parameter 4.
  static const String param4 = 'as_param_4';

  /// Custom parameter 5.
  static const String param5 = 'as_param_5';

  /// Custom parameter 6.
  static const String param6 = 'as_param_6';

  /// Custom parameter 7.
  static const String param7 = 'as_param_7';

  /// Custom parameter 8.
  static const String param8 = 'as_param_8';

  /// Custom parameter 9.
  static const String param9 = 'as_param_9';

  /// Custom parameter 10.
  static const String param10 = 'as_param_10';

  /// Mediation platform that reported an ad impression.
  static const String adRevenueSource = 'as_adrev_source';

  /// Ad network that served an impression.
  static const String adRevenueNetworkName = 'as_adrev_network_name';

  /// Mediated network behind an impression.
  static const String adRevenueMediatedNetworkName =
      'as_adrev_mediated_network_name';

  /// Ad format, e.g. `banner`.
  static const String adRevenueAdType = 'as_adrev_ad_type';

  /// Ad size, e.g. `320x50`.
  static const String adRevenueAdSize = 'as_adrev_ad_size';

  /// Placement identifier.
  static const String adRevenuePlacementId = 'as_adrev_placement_id';

  /// Ad unit identifier.
  static const String adRevenueAdUnitId = 'as_adrev_ad_unit_id';

  /// Revenue precision reported by the network, e.g. `exact`.
  static const String adRevenuePrecision = 'as_adrev_precision';

  /// Every standard parameter name.
  static const List<String> all = [
    price,
    revenue,
    projectedRevenue,
    currency,
    quantity,
    receiptId,
    orderId,
    couponCode,
    paymentInfoAvailable,
    validated,
    contentType,
    contentId,
    contentList,
    content,
    classValue,
    description,
    searchString,
    ratingValue,
    maxRatingValue,
    reviewText,
    customerUserId,
    registrationMethod,
    level,
    score,
    success,
    tutorialId,
    achievementId,
    virtualCurrencyName,
    deepLink,
    oldVersion,
    newVersion,
    channel,
    touchObj,
    dateA,
    dateB,
    eventStart,
    eventEnd,
    latitude,
    longitude,
    city,
    region,
    country,
    destinationA,
    destinationB,
    destinationList,
    departingDepartureDate,
    returningDepartureDate,
    departingArrivalDate,
    returningArrivalDate,
    travelStart,
    travelEnd,
    suggestedDestinations,
    suggestedHotels,
    numAdults,
    numChildren,
    numInfants,
    userScore,
    hotelScore,
    purchaseCurrency,
    preferredStarRatings,
    preferredPriceRange,
    preferredNeighborhoods,
    preferredNumStops,
    param1,
    param2,
    param3,
    param4,
    param5,
    param6,
    param7,
    param8,
    param9,
    param10,
    adRevenueSource,
    adRevenueNetworkName,
    adRevenueMediatedNetworkName,
    adRevenueAdType,
    adRevenueAdSize,
    adRevenuePlacementId,
    adRevenueAdUnitId,
    adRevenuePrecision,
  ];
}
