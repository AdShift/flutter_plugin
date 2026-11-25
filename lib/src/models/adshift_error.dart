/// Why the SDK declined a call.
enum AdshiftErrorCode {
  /// `Adshift.instance.initialize()` has not been called, or was refused.
  notInitialized('NOT_INITIALIZED'),

  /// The SDK is stopped; call `Adshift.instance.start()` first.
  notStarted('NOT_STARTED'),

  /// The API key was rejected. Android answers `start()` with it; on iOS a
  /// rejected key is usually not reported to the app.
  invalidApiKey('INVALID_API_KEY'),

  /// Tracking is turned off for this device.
  optedOut('OPTED_OUT'),

  /// Too many calls are waiting; this one was not accepted.
  queueFull('QUEUE_FULL'),

  /// An argument failed validation.
  invalidArgument('INVALID_ARGUMENT'),

  /// Any other failure; see [AdshiftError.nativeCode].
  unknown('UNKNOWN');

  const AdshiftErrorCode(this.wireName);

  /// The code as written in the documentation and in support requests.
  final String wireName;
}

/// A problem the SDK reports instead of throwing. It arrives in the result of
/// `start()` and of the tracking calls, and through `AdshiftConfig.onError`.
final class AdshiftError {
  /// Creates an error value, for example for a test.
  const AdshiftError(
    this.code,
    this.message, {
    this.nativeCode,
    this.nativeDomain,
  });

  /// What went wrong.
  final AdshiftErrorCode code;

  /// A description for logs; not meant to be shown to users.
  final String message;

  /// The code the platform reported, when it reported one. Include it in
  /// support requests.
  final String? nativeCode;

  /// The error domain the platform reported, when it reported one (iOS).
  final String? nativeDomain;

  @override
  String toString() => 'AdshiftError(${code.wireName}): $message';
}
