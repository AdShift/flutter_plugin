/// Status of a deep link resolution.
enum AdshiftDeepLinkStatus {
  /// Deep link was found and resolved successfully.
  found,

  /// No deep link was found (e.g., organic install).
  notFound,

  /// Error occurred while resolving deep link.
  error,
}

/// Response from deep link handling.
///
/// Contains the resolved deep link URL, parameters, and status.
///
/// Example:
/// ```dart
/// final deepLink = await AdshiftFlutterSdk.instance.handleDeepLink(uri);
/// if (deepLink.status == AdshiftDeepLinkStatus.found) {
///   final productId = deepLink.params?['product_id'];
///   // Navigate to product
/// }
/// ```
class AdshiftDeepLink {
  /// The deep link URL string.
  final String? deepLink;

  /// Query parameters extracted from the deep link.
  final Map<String, dynamic>? params;

  /// Whether this is a deferred deep link.
  /// 
  /// Deferred deep links are resolved after app install,
  /// typically from ad campaigns.
  final bool isDeferred;

  /// Status of the deep link resolution.
  final AdshiftDeepLinkStatus status;

  /// Error message if [status] is [AdshiftDeepLinkStatus.error].
  final String? errorMessage;

  /// Creates a deep link response.
  const AdshiftDeepLink({
    this.deepLink,
    this.params,
    this.isDeferred = false,
    required this.status,
    this.errorMessage,
  });

  /// Creates a successful deep link response.
  factory AdshiftDeepLink.found({
    required String deepLink,
    Map<String, dynamic>? params,
    bool isDeferred = false,
  }) {
    return AdshiftDeepLink(
      deepLink: deepLink,
      params: params,
      isDeferred: isDeferred,
      status: AdshiftDeepLinkStatus.found,
    );
  }

  /// Creates a "not found" deep link response.
  factory AdshiftDeepLink.notFound() {
    return const AdshiftDeepLink(
      status: AdshiftDeepLinkStatus.notFound,
    );
  }

  /// Creates an error deep link response.
  factory AdshiftDeepLink.error(String message) {
    return AdshiftDeepLink(
      status: AdshiftDeepLinkStatus.error,
      errorMessage: message,
    );
  }

  /// Creates deep link from a Map (platform channel response).
  factory AdshiftDeepLink.fromMap(Map<String, dynamic> map) {
    final statusStr = map['status'] as String? ?? 'notFound';
    final status = AdshiftDeepLinkStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => AdshiftDeepLinkStatus.notFound,
    );

    return AdshiftDeepLink(
      deepLink: map['deepLink'] as String?,
      params: map['params'] != null 
          ? Map<String, dynamic>.from(map['params'] as Map) 
          : null,
      isDeferred: map['isDeferred'] as bool? ?? false,
      status: status,
      errorMessage: map['errorMessage'] as String?,
    );
  }

  /// Converts deep link to a Map for platform channel communication.
  Map<String, dynamic> toMap() {
    return {
      'deepLink': deepLink,
      'params': params,
      'isDeferred': isDeferred,
      'status': status.name,
      'errorMessage': errorMessage,
    };
  }

  @override
  String toString() {
    return 'AdshiftDeepLink(status: $status, deepLink: $deepLink, '
        'isDeferred: $isDeferred, params: $params)';
  }
}

