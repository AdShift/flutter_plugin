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
/// `INVALID_API_KEY`. On iOS `start()` usually answers `pending` and a
/// rejected key is not reported to the app, so check the debug log while
/// integrating.
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
/// Success means the SDK accepted the call into its queue, not that the data
/// was delivered.
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
