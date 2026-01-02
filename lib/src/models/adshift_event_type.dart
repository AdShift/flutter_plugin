/// Predefined event types for AdShift SDK.
///
/// Use these constants for consistent event naming across your app.
///
/// Example:
/// ```dart
/// await AdshiftFlutterSdk.instance.trackEvent(
///   AdshiftEventType.addToCart,
///   values: {'product_id': 'SKU123', 'price': 29.99},
/// );
/// ```
///
/// You can also use custom event names as strings:
/// ```dart
/// await AdshiftFlutterSdk.instance.trackEvent('custom_event_name');
/// ```
class AdshiftEventType {
  AdshiftEventType._(); // Prevent instantiation

  // ============ E-commerce Events ============

  /// User added item to cart.
  static const String addToCart = 'as_add_to_cart';

  /// User added item to wishlist.
  static const String addToWishList = 'as_add_to_wishlist';

  /// User added payment info.
  static const String addPaymentInfo = 'as_add_payment_info';

  /// User initiated checkout.
  static const String initiatedCheckout = 'as_initiated_checkout';

  /// User completed a purchase.
  static const String purchase = 'as_purchase';

  /// User viewed content/product.
  static const String contentView = 'as_content_view';

  /// User viewed a list of items.
  static const String listView = 'as_list_view';

  /// User searched.
  static const String search = 'as_search';

  // ============ User Lifecycle Events ============

  /// User completed registration.
  static const String completeRegistration = 'as_complete_registration';

  /// User logged in.
  static const String login = 'as_login';

  /// User completed tutorial.
  static const String tutorialCompletion = 'as_tutorial_completion';

  /// User subscribed.
  static const String subscribe = 'as_subscribe';

  /// User started a trial.
  static const String startTrial = 'as_start_trial';

  // ============ Gaming Events ============

  /// User achieved a level.
  static const String levelAchieved = 'as_level_achieved';

  /// User unlocked an achievement.
  static const String achievementUnlocked = 'as_achievement_unlocked';

  /// User spent credits/currency.
  static const String spentCredit = 'as_spent_credits';

  // ============ Engagement Events ============

  /// User rated the app/content.
  static const String rate = 'as_rate';

  /// User shared content.
  static const String share = 'as_share';

  /// User invited others.
  static const String invite = 'as_invite';

  /// User re-engaged with the app.
  static const String reEngage = 'as_re_engage';

  /// User updated the app.
  static const String update = 'as_update';

  /// User opened from push notification.
  static const String openedFromPushNotification = 'as_opened_from_push_notification';

  // ============ Travel Events ============

  /// User made a travel booking.
  static const String travelBooking = 'as_travel_booking';

  // ============ Ad Events ============

  /// User clicked an ad.
  static const String adClick = 'as_ad_click';

  /// User viewed an ad.
  static const String adView = 'as_ad_view';

  // ============ Location Events ============

  /// User location changed.
  static const String locationChanged = 'as_location_changed';

  /// User location coordinates updated.
  static const String locationCoordinates = 'as_location_coordinates';

  // ============ Other Events ============

  /// Order ID event.
  static const String orderId = 'as_order_id';

  /// Customer segment event.
  static const String customerSegment = 'as_customer_segment';

  /// Returns all predefined event types.
  static List<String> get all => [
        addToCart,
        addToWishList,
        addPaymentInfo,
        initiatedCheckout,
        purchase,
        contentView,
        listView,
        search,
        completeRegistration,
        login,
        tutorialCompletion,
        subscribe,
        startTrial,
        levelAchieved,
        achievementUnlocked,
        spentCredit,
        rate,
        share,
        invite,
        reEngage,
        update,
        openedFromPushNotification,
        travelBooking,
        adClick,
        adView,
        locationChanged,
        locationCoordinates,
        orderId,
        customerSegment,
      ];
}

