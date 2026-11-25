/// Standard event names for `Adshift.instance.trackEvent()`. Any other name is
/// tracked as a custom event.
abstract final class AdshiftEventType {
  /// An item was added to the cart.
  static const String addToCart = 'as_add_to_cart';

  /// An item was added to the wish list.
  static const String addToWishList = 'as_add_to_wishlist';

  /// Payment details were added.
  static const String addPaymentInfo = 'as_add_payment_info';

  /// Checkout was started.
  static const String initiatedCheckout = 'as_initiated_checkout';

  /// A purchase was completed.
  static const String purchase = 'as_purchase';

  /// A piece of content or a product was viewed.
  static const String contentView = 'as_content_view';

  /// A list of items was viewed.
  static const String listView = 'as_list_view';

  /// A search was made.
  static const String search = 'as_search';

  /// Registration was completed.
  static const String completeRegistration = 'as_complete_registration';

  /// The user logged in.
  static const String login = 'as_login';

  /// The tutorial was completed.
  static const String tutorialCompletion = 'as_tutorial_completion';

  /// A subscription was started.
  static const String subscribe = 'as_subscribe';

  /// A trial was started.
  static const String startTrial = 'as_start_trial';

  /// A level was reached.
  static const String levelAchieved = 'as_level_achieved';

  /// An achievement was unlocked.
  static const String achievementUnlocked = 'as_achievement_unlocked';

  /// In-app credits were spent.
  static const String spentCredit = 'as_spent_credits';

  /// The app or a piece of content was rated.
  static const String rate = 'as_rate';

  /// Content was shared.
  static const String share = 'as_share';

  /// Another user was invited.
  static const String invite = 'as_invite';

  /// The user came back to the app.
  static const String reEngage = 'as_re_engage';

  /// The app was updated.
  static const String update = 'as_update';

  /// The app was opened from a push notification.
  static const String openedFromPushNotification =
      'as_opened_from_push_notification';

  /// A trip was booked.
  static const String travelBooking = 'as_travel_booking';

  /// An ad was clicked.
  static const String adClick = 'as_ad_click';

  /// An ad was viewed.
  static const String adView = 'as_ad_view';

  /// An ad impression earned revenue. Prefer
  /// `Adshift.instance.logAdRevenue()`.
  static const String adRevenue = 'as_ad_revenue';

  /// The user moved to another region or place, as your own values.
  static const String locationChanged = 'as_location_changed';

  /// Latitude and longitude. Send only what your privacy notice covers.
  static const String locationCoordinates = 'as_location_coordinates';

  /// Your order identifier, for matching purchases with your own records.
  static const String orderId = 'as_order_id';

  /// The segment the user belongs to, for audience reporting.
  static const String customerSegment = 'as_customer_segment';

  /// Every standard event name.
  static const List<String> all = [
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
    adRevenue,
    locationChanged,
    locationCoordinates,
    orderId,
    customerSegment,
  ];
}
