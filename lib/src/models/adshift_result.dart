import 'adshift_error.dart';

/// How far the API key check had got when `start()` answered.
///
/// Android waits up to 5 seconds for the check before it answers. iOS answers
/// before the key is checked, so there the status is usually [pending].
enum AdshiftApiKeyValidationStatus {
  /// Not checked yet; needs no action.
  pending,

  /// The key was accepted.
  valid,

  /// The key was rejected; no data is reported.
  invalid,
}

/// The answer of `Adshift.instance.start()`.
///
/// [success] says whether the SDK started on the device. A rejected API key
/// shows differently on each platform. On Android `start()` fails with
/// `INVALID_API_KEY`. On iOS `start()` usually answers `pending`, so a rejected
/// key is usually not reported to the app: check the debug log while
/// integrating. It is reported, as `invalid` here and as `INVALID_API_KEY` to
/// `AdshiftConfig.onError`, when the SDK already knows the verdict, for
/// example at a `start()` after `stop()` in the same run.
final class AdshiftStartResult {
  /// The SDK started.
  const AdshiftStartResult.success({this.apiKeyValidationStatus})
    : error = null;

  /// The SDK did not start because of [error].
  const AdshiftStartResult.failure(
    AdshiftError this.error, {
    this.apiKeyValidationStatus,
  });

  /// The API key check, when the platform stated it.
  final AdshiftApiKeyValidationStatus? apiKeyValidationStatus;

  /// Why the SDK did not start; null on success.
  final AdshiftError? error;

  /// Whether the SDK started.
  bool get success => error == null;

  @override
  String toString() => success
      ? 'AdshiftStartResult.success(${apiKeyValidationStatus?.name ?? ''})'
      : 'AdshiftStartResult.failure($error)';
}

/// The answer of `trackEvent()`, `trackPurchase()` and `logAdRevenue()`.
///
/// For an event or a purchase, success means the SDK accepted the call into
/// its queue, not that the data was delivered. For ad revenue it means the
/// record was handed to the SDK, which gives no verdict on it: the answer is a
/// success also on a device with tracking turned off.
final class AdshiftResult {
  /// The call was accepted.
  const AdshiftResult.success() : error = null;

  /// The call was declined because of [error].
  const AdshiftResult.failure(AdshiftError this.error);

  /// Why the call was declined; null on success.
  final AdshiftError? error;

  /// Whether the call was accepted.
  bool get success => error == null;

  @override
  String toString() =>
      success ? 'AdshiftResult.success()' : 'AdshiftResult.failure($error)';
}
