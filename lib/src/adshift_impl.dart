import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show WidgetsFlutterBinding;

import 'adshift.dart';
import 'converters.dart';
import 'deep_link_stream.dart';
import 'info.dart';
import 'log.dart';
import 'messages.g.dart';
import 'models/adshift_config.dart';
import 'models/adshift_consent.dart';
import 'models/adshift_consent_snapshot.dart';
import 'models/adshift_deep_link.dart';
import 'models/adshift_error.dart';
import 'models/adshift_info.dart';
import 'models/adshift_mediation_network.dart';
import 'models/adshift_result.dart';
import 'models/adshift_third_party_sharing.dart';
import 'plain_param_names.dart';

/// The SDK behind [Adshift.instance], connected to the platform.
Adshift createAdshift() => AdshiftImpl(
  host: AdshiftHostApi(),
  registerHandler: (handler) {
    WidgetsFlutterBinding.ensureInitialized();
    AdshiftFlutterApi.setUp(handler);
  },
);

enum _State { uninitialized, initialized, starting, started, stopped }

typedef _PlatformCall = Future<ErrorMessage?> Function();

typedef _QueuedCall = ({_PlatformCall send, Completer<AdshiftResult> answer});

/// Setters called before `initialize()`: the last value of each, every push
/// path.
final class _PendingSettings {
  String? customerUserId;
  bool? debugEnabled;
  int? appOpenDebounceMs;
  List<String>? brandedDomains;
  String? metaAppId;
  String? oaid;
  AdshiftConsent? consent;
  bool? tcfEnabled;
  bool? gppEnabled;
  AdshiftThirdPartySharing? thirdPartySharing;

  /// The last sharing call was a clear, which must still reach the SDK.
  bool thirdPartySharingCleared = false;
  final List<List<String>> pushDeepLinkPaths = [];
}

final class _DeepLinkHandler implements AdshiftFlutterApi {
  _DeepLinkHandler(this._deepLinks);

  final DeepLinkStream _deepLinks;

  @override
  void onDeepLink(DeepLinkMessage link) =>
      _deepLinks.add(deepLinkFromMessage(link));
}

/// [Adshift] over the platform channel. `host` carries the calls to the
/// platform; `registerHandler` installs the receiver of deep link results.
final class AdshiftImpl implements Adshift {
  AdshiftImpl({required this._host, required this._registerHandler});

  static const int _queueLimit = 100;

  /// For the warning only; on iOS the limit applies to amounts in USD.
  static const int _maxAdRevenuePerImpression = 10;

  /// Sent by the SDK itself.
  static const Set<String> _reservedEventNames = {'app_install', 'app_open'};

  final AdshiftHostApi _host;
  final void Function(AdshiftFlutterApi handler) _registerHandler;
  final DeepLinkStream _deepLinks = DeepLinkStream();
  final List<_QueuedCall> _queue = [];
  final Set<String> _reportedPlainNames = {};

  _State _state = _State.uninitialized;
  _PendingSettings _pending = _PendingSettings();
  void Function(AdshiftError error)? _onError;
  bool _handlerRegistered = false;

  /// Why `initialize()` was refused; `start()` answers with it.
  AdshiftError? _initializeError;

  /// Set until the platform has answered `initialize()`.
  Future<void>? _initializing;
  Future<AdshiftStartResult>? _startInFlight;

  /// One per start attempt, so a superseded attempt cannot touch the state.
  int _startEpoch = 0;

  /// Why the last `start()` failed, when a retry cannot fix it. Tracking calls
  /// answer with it until the next attempt, instead of waiting for one.
  AdshiftError? _startRefusal;

  @override
  void initialize(AdshiftConfig config) {
    if (_state != _State.uninitialized) {
      debugWarn(
        'initialize() called more than once; the first config is kept.',
      );
      return;
    }
    _onError = config.onError;
    final problem = _configProblem(config);
    if (problem != null) {
      _refuseInitialize(_invalidArgument(problem));
      return;
    }
    final settings = _pending;
    final Future<ErrorMessage?> reply;
    try {
      if (!_handlerRegistered) {
        _registerHandler(_DeepLinkHandler(_deepLinks));
        _handlerRegistered = true;
      }
      reply = _host.initialize(_initializeMessage(config, settings));
    } catch (thrown) {
      _refuseInitialize(errorFromThrown(thrown));
      return;
    }
    // The state moves on before the platform answers, so that calls made
    // right after this one reach the platform in order, behind `initialize`.
    _initializeError = null;
    _state = _State.initialized;
    _pending = _PendingSettings();
    _applySettings(settings);
    _initializing = _awaitInitialize(reply, settings);
  }

  Future<void> _awaitInitialize(
    Future<ErrorMessage?> reply,
    _PendingSettings settings,
  ) async {
    AdshiftError? error;
    try {
      final message = await reply;
      if (message != null) error = errorFromMessage(message);
    } catch (thrown) {
      error = errorFromThrown(thrown);
    }
    _initializing = null;
    if (error == null) {
      _send(_host.deepLinkListenerReady);
      return;
    }
    // The platform did not take the config: as if initialize() had not been
    // called, with the earlier settings kept for the next one.
    _state = _State.uninitialized;
    _pending = settings;
    _failQueue(error);
    _refuseInitialize(error);
  }

  void _refuseInitialize(AdshiftError error) {
    _initializeError = error;
    _report(error);
  }

  static String? _configProblem(AdshiftConfig config) {
    if (_isBlank(config.apiKey)) {
      return 'AdShift SDK: apiKey is required in config';
    }
    if ((config.appOpenDebounceMs ?? 0) < 0) {
      return 'AdShift SDK: appOpenDebounceMs must not be negative';
    }
    if ((config.attTimeoutMs ?? 0) < 0) {
      return 'AdShift SDK: attTimeoutMs must not be negative';
    }
    if (config.brandedDomains?.any(_isBlank) ?? false) {
      return 'AdShift SDK: brandedDomains must be a list of non-empty strings';
    }
    if (config.pushDeepLinkPaths?.any((path) => path.any(_isBlank)) ?? false) {
      return 'AdShift SDK: pushDeepLinkPaths must be a list of lists of '
          'non-empty strings';
    }
    return null;
  }

  /// The config wins over a value set before `initialize()`; push paths from
  /// both are kept.
  static InitializeMessage _initializeMessage(
    AdshiftConfig config,
    _PendingSettings settings,
  ) {
    final pushPaths = [
      ...?config.pushDeepLinkPaths,
      ...settings.pushDeepLinkPaths,
    ];
    return InitializeMessage(
      apiKey: config.apiKey,
      isDebug: config.isDebug ?? settings.debugEnabled,
      appOpenDebounceMs: config.appOpenDebounceMs ?? settings.appOpenDebounceMs,
      brandedDomains: config.brandedDomains ?? settings.brandedDomains,
      testMode: config.testMode,
      metaAppId: config.metaAppId ?? settings.metaAppId,
      pushDeepLinkPaths: pushPaths.isEmpty ? null : pushPaths,
      autoHandleDeepLinks: config.autoHandleDeepLinks,
      disableSkan: config.disableSKAN,
      waitForAttBeforeStart: config.waitForATTBeforeStart,
      attTimeoutMs: config.attTimeoutMs,
      deferredDeepLinkClipboard: clipboardModeToMessage(
        config.deferredDeepLinkClipboard,
      ),
      collectOaid: config.collectOaid,
    );
  }

  /// The settings that have no config option, in a fixed order.
  void _applySettings(_PendingSettings settings) {
    if (settings.customerUserId case final userId?) setCustomerUserId(userId);
    if (settings.oaid case final oaid?) setOaidData(oaid);
    if (settings.consent case final consent?) setConsentData(consent);
    if (settings.tcfEnabled case final enabled?) {
      enableTCFDataCollection(enabled);
    }
    if (settings.gppEnabled case final enabled?) {
      enableGPPDataCollection(enabled);
    }
    if (settings.thirdPartySharing case final sharing?) {
      setThirdPartySharing(sharing);
    } else if (settings.thirdPartySharingCleared) {
      clearThirdPartySharing();
    }
  }

  @override
  Future<AdshiftStartResult> start() {
    if (_state == _State.uninitialized) {
      return Future.value(
        AdshiftStartResult.failure(_initializeError ?? _notInitialized()),
      );
    }
    if (_state == _State.started) {
      return Future.value(const AdshiftStartResult.success());
    }
    final inFlight = _startInFlight;
    if (inFlight != null) return inFlight;
    late final Future<AdshiftStartResult> attempt;
    attempt = _performStart().whenComplete(() {
      if (identical(_startInFlight, attempt)) _startInFlight = null;
    });
    return _startInFlight = attempt;
  }

  Future<AdshiftStartResult> _performStart() async {
    final previous = _state;
    final epoch = ++_startEpoch;
    _state = _State.starting;
    _startRefusal = null;

    final initializing = _initializing;
    if (initializing != null) {
      await initializing;
      if (_state == _State.uninitialized) {
        return AdshiftStartResult.failure(
          _initializeError ?? _notInitialized(),
        );
      }
      if (epoch != _startEpoch || _state != _State.starting) {
        return AdshiftStartResult.failure(_notStarted());
      }
    }

    final AdshiftStartResult result;
    try {
      result = startResultFromMessage(await _host.start());
    } catch (thrown) {
      if (epoch == _startEpoch && _state == _State.starting) _state = previous;
      return AdshiftStartResult.failure(errorFromThrown(thrown));
    }
    // A newer start() owns the state now.
    if (epoch != _startEpoch) return result;
    if (_state != _State.starting) {
      // stop() was called while this attempt was in flight; the last call
      // wins.
      if (result.success) _send(_host.stop);
      return AdshiftStartResult.failure(_notStarted());
    }
    final error = result.error;
    if (error == null) {
      _state = _State.started;
      _flushQueue();
      if (result.apiKeyValidationStatus ==
          AdshiftApiKeyValidationStatus.invalid) {
        _report(
          const AdshiftError(
            AdshiftErrorCode.invalidApiKey,
            'AdShift SDK: the API key was rejected; no data will be reported.',
          ),
        );
      }
      return result;
    }
    _state = previous;
    _report(error);
    if (_isTerminalStartFailure(error.code)) {
      _startRefusal = error;
      _failQueue(error);
    }
    return result;
  }

  /// Failures a retry cannot fix, which end the calls waiting for `start()`.
  /// After any other failure they wait for the next attempt.
  static bool _isTerminalStartFailure(AdshiftErrorCode code) =>
      code == AdshiftErrorCode.invalidApiKey ||
      code == AdshiftErrorCode.optedOut ||
      code == AdshiftErrorCode.notInitialized;

  @override
  void stop() {
    if (_state == _State.uninitialized) {
      _report(_notInitialized());
      return;
    }
    _state = _State.stopped;
    // A later start() must not receive the future of the attempt this stop
    // cancels.
    _startInFlight = null;
    _failQueue(_notStarted());
    _send(_host.stop);
  }

  @override
  bool get isStarted => _state == _State.started;

  @override
  AdshiftInfo getInfo() => readInfo();

  @override
  void setCustomerUserId(String userId) {
    if (_isBlank(userId)) {
      return _reportInvalid('AdShift SDK: userId must be a non-empty string');
    }
    _set(
      (pending) => pending.customerUserId = userId,
      () => _host.setCustomerUserId(userId),
    );
  }

  @override
  void setDebugEnabled(bool enabled) => _set(
    (pending) => pending.debugEnabled = enabled,
    () => _host.setDebugEnabled(enabled),
  );

  @override
  void setAppOpenDebounceMs(int ms) {
    if (ms < 0) {
      return _reportInvalid('AdShift SDK: ms must not be negative');
    }
    _set(
      (pending) => pending.appOpenDebounceMs = ms,
      () => _host.setAppOpenDebounceMs(ms),
    );
  }

  @override
  void setBrandedDomains(List<String> domains) {
    if (domains.any(_isBlank)) {
      return _reportInvalid(
        'AdShift SDK: domains must be a list of non-empty strings',
      );
    }
    final copy = List.of(domains);
    _set(
      (pending) => pending.brandedDomains = copy,
      () => _host.setBrandedDomains(copy),
    );
  }

  @override
  void setMetaAppId(String appId) {
    if (_isBlank(appId)) {
      return _reportInvalid('AdShift SDK: appId must be a non-empty string');
    }
    _set(
      (pending) => pending.metaAppId = appId,
      () => _host.setMetaAppId(appId),
    );
  }

  @override
  void setOaidData(String oaid) {
    if (_isBlank(oaid)) {
      return _reportInvalid('AdShift SDK: oaid must be a non-empty string');
    }
    _set((pending) => pending.oaid = oaid, () => _host.setOaidData(oaid));
  }

  @override
  void setConsentData(AdshiftConsent consent) => _set(
    (pending) => pending.consent = consent,
    () => _host.setConsentData(consentToMessage(consent)),
  );

  @override
  void enableTCFDataCollection(bool enabled) => _set(
    (pending) => pending.tcfEnabled = enabled,
    () => _host.enableTcfDataCollection(enabled),
  );

  @override
  void enableGPPDataCollection(bool enabled) => _set(
    (pending) => pending.gppEnabled = enabled,
    () => _host.enableGppDataCollection(enabled),
  );

  @override
  void setThirdPartySharing(AdshiftThirdPartySharing sharing) => _set(
    (pending) => pending
      ..thirdPartySharing = sharing
      ..thirdPartySharingCleared = false,
    () => _host.setThirdPartySharing(sharing.optOut),
  );

  @override
  void clearThirdPartySharing() => _set(
    (pending) => pending
      ..thirdPartySharing = null
      ..thirdPartySharingCleared = true,
    _host.clearThirdPartySharing,
  );

  @override
  Future<AdshiftConsentSnapshot?> refreshConsent() async {
    if (_state == _State.uninitialized) {
      _report(_notInitialized());
      return null;
    }
    try {
      final snapshot = await _host.refreshConsent();
      if (snapshot != null) return consentSnapshotFromMessage(snapshot);
      _report(_notInitialized());
    } catch (thrown) {
      _report(errorFromThrown(thrown));
    }
    return null;
  }

  @override
  Future<AdshiftResult> trackEvent(
    String eventName, {
    Map<String, Object>? values,
  }) {
    if (_isBlank(eventName)) {
      return _invalid('AdShift SDK: eventName must be a non-empty string');
    }
    if (_reservedEventNames.contains(eventName.trim().toLowerCase())) {
      return _invalid(
        'AdShift SDK: "$eventName" is reserved and sent by the SDK; use your '
        'own event name',
      );
    }
    final problem = _valuesProblem(values, 'values');
    if (problem != null) return _invalid(problem);
    _warnAboutPlainNames(values);
    // Copied, because the call may wait for start() while the caller's map
    // changes.
    final sent = Map<String, Object?>.of(values ?? const {});
    return _whenStarted(() => _host.trackEvent(eventName, sent));
  }

  @override
  Future<AdshiftResult> trackPurchase({
    required String productId,
    required double revenue,
    required String currency,
    required String transactionId,
  }) {
    if (_isBlank(productId)) {
      return _invalid('AdShift SDK: productId is required');
    }
    if (!revenue.isFinite || revenue < 0) {
      return _invalid('AdShift SDK: revenue must be a non-negative number');
    }
    if (_isBlank(currency)) {
      return _invalid('AdShift SDK: currency is required');
    }
    if (_isBlank(transactionId)) {
      return _invalid('AdShift SDK: transactionId is required');
    }
    return _whenStarted(
      () => _host.trackPurchase(productId, revenue, currency, transactionId),
    );
  }

  @override
  Future<AdshiftResult> logAdRevenue({
    required String monetizationNetwork,
    required AdshiftMediationNetwork mediationNetwork,
    required String currency,
    required double revenue,
    String? adUnitId,
    String? precision,
    Map<String, Object>? additionalParameters,
  }) {
    if (_isBlank(monetizationNetwork)) {
      return _invalid('AdShift SDK: monetizationNetwork is required');
    }
    if (_isBlank(currency)) {
      return _invalid('AdShift SDK: currency is required');
    }
    if (currency.length != 3) {
      return _invalid('AdShift SDK: currency must be a 3-letter ISO 4217 code');
    }
    if (!revenue.isFinite || revenue <= 0) {
      return _invalid('AdShift SDK: revenue must be a positive number');
    }
    final problem = _valuesProblem(
      additionalParameters,
      'additionalParameters',
    );
    if (problem != null) return _invalid(problem);
    if (revenue > _maxAdRevenuePerImpression &&
        (defaultTargetPlatform == TargetPlatform.android ||
            currency.toUpperCase() == 'USD')) {
      debugWarn(
        'logAdRevenue: revenue above $_maxAdRevenuePerImpression is not '
        'recorded. Pass the revenue of a single impression, not an aggregate.',
      );
    }
    _warnAboutPlainNames(additionalParameters);
    final data = AdRevenueMessage(
      monetizationNetwork: monetizationNetwork,
      mediationNetwork: mediationNetwork.wireName,
      currency: currency,
      revenue: revenue,
      adUnitId: adUnitId,
      precision: precision,
      additionalParameters: additionalParameters == null
          ? null
          : Map<String, Object?>.of(additionalParameters),
    );
    return _whenStarted(() => _host.logAdRevenue(data));
  }

  @override
  Future<String?> getAdShiftDeviceId() async {
    if (_state == _State.uninitialized) return null;
    try {
      final id = await _host.getAdShiftDeviceId();
      return id == null || id.isEmpty ? null : id;
    } catch (thrown) {
      _report(errorFromThrown(thrown));
      return null;
    }
  }

  @override
  Future<void> handleDeepLink(Uri url) async {
    if (_state == _State.uninitialized) {
      _report(_notInitialized());
      return;
    }
    final link = url.toString();
    if (_isBlank(link)) {
      _reportInvalid('AdShift SDK: url must not be empty');
      return;
    }
    try {
      final error = await _host.handleDeepLink(link);
      if (error != null) _report(errorFromMessage(error));
    } catch (thrown) {
      _report(errorFromThrown(thrown));
    }
  }

  @override
  void handlePastedDeepLink(Uri? url) {
    if (_state == _State.uninitialized) {
      _report(_notInitialized());
      return;
    }
    final link = url?.toString();
    final pasted = link == null || _isBlank(link) ? null : link;
    _send(() => _host.handlePastedDeepLink(pasted));
  }

  @override
  void addPushNotificationDeepLinkPath(List<String> path) {
    if (path.isEmpty || path.any(_isBlank)) {
      return _reportInvalid(
        'AdShift SDK: path must be a non-empty list of non-empty strings',
      );
    }
    final copy = List.of(path);
    _set(
      (pending) => pending.pushDeepLinkPaths.add(copy),
      () => _host.addPushNotificationDeepLinkPath(copy),
    );
  }

  @override
  Future<bool> handlePushNotification(Map<String, Object?> payload) async {
    if (_state == _State.uninitialized) {
      _report(_notInitialized());
      return false;
    }
    try {
      return await _host.handlePushNotification(payload);
    } catch (thrown) {
      _report(errorFromThrown(thrown));
      return false;
    }
  }

  @override
  Stream<AdshiftDeepLink> get onDeepLink => _deepLinks.stream;

  /// Keeps a setting until `initialize()`, or passes it on at once.
  void _set(
    void Function(_PendingSettings pending) keep,
    Future<void> Function() send,
  ) {
    if (_state == _State.uninitialized) {
      keep(_pending);
    } else {
      _send(send);
    }
  }

  /// Makes a platform call that has nothing to answer; a failure is reported.
  void _send(Future<void> Function() call) => unawaited(_reportFailure(call));

  Future<void> _reportFailure(Future<void> Function() call) async {
    try {
      await call();
    } catch (thrown) {
      _report(errorFromThrown(thrown));
    }
  }

  /// Makes a tracking call now, or once `start()` has succeeded.
  Future<AdshiftResult> _whenStarted(_PlatformCall send) {
    switch (_state) {
      case _State.uninitialized:
        return _failed(_notInitialized());
      case _State.stopped:
        return _failed(_notStarted());
      case _State.started:
        return _deliver(send);
      case _State.initialized:
      case _State.starting:
        final refusal = _startRefusal;
        if (refusal != null) return _failed(refusal);
        if (_queue.length >= _queueLimit) {
          return _failed(
            const AdshiftError(
              AdshiftErrorCode.queueFull,
              'AdShift SDK: too many calls are waiting for start().',
            ),
          );
        }
        if (_startEpoch == 0 && _queue.isEmpty) {
          debugWarn('Call queued until start() succeeds.');
        }
        final answer = Completer<AdshiftResult>();
        _queue.add((send: send, answer: answer));
        return answer.future;
    }
  }

  Future<AdshiftResult> _deliver(_PlatformCall send) async {
    try {
      final error = await send();
      return error == null
          ? const AdshiftResult.success()
          : AdshiftResult.failure(errorFromMessage(error));
    } catch (thrown) {
      return AdshiftResult.failure(errorFromThrown(thrown));
    }
  }

  void _flushQueue() {
    final calls = List.of(_queue);
    _queue.clear();
    for (final call in calls) {
      call.answer.complete(_deliver(call.send));
    }
  }

  void _failQueue(AdshiftError error) {
    final calls = List.of(_queue);
    _queue.clear();
    for (final call in calls) {
      call.answer.complete(AdshiftResult.failure(error));
    }
  }

  /// Tells the app about a declined call. Whatever its handler throws stays
  /// here.
  void _report(AdshiftError error) {
    debugWarn('${error.message} (${error.code.wireName})');
    try {
      _onError?.call(error);
    } catch (thrown) {
      debugWarn('config.onError threw; ignoring it: $thrown');
    }
  }

  void _reportInvalid(String message) => _report(_invalidArgument(message));

  /// Warns once per name; the value is still sent, as a custom parameter.
  void _warnAboutPlainNames(Map<String, Object>? values) {
    if (!kDebugMode || values == null) return;
    for (final key in values.keys) {
      final standard = plainParamNames[key];
      if (standard == null || !_reportedPlainNames.add(key)) continue;
      debugWarn(
        '"$key" is kept as a custom parameter. Use '
        'AdshiftEventParam.${eventParamConstant(standard)} ("$standard") for '
        'a value reports should count.',
      );
    }
  }

  static String? _valuesProblem(Map<String, Object>? values, String name) {
    if (values == null) return null;
    for (final MapEntry(:key, :value) in values.entries) {
      if (value is! String && value is! num && value is! bool) {
        return 'AdShift SDK: $name.$key must be a string, number or boolean';
      }
      if (value is num && !value.isFinite) {
        return 'AdShift SDK: $name.$key must be finite';
      }
    }
    return null;
  }

  static bool _isBlank(String value) => value.trim().isEmpty;

  static Future<AdshiftResult> _failed(AdshiftError error) =>
      Future.value(AdshiftResult.failure(error));

  static Future<AdshiftResult> _invalid(String message) =>
      _failed(_invalidArgument(message));

  static AdshiftError _invalidArgument(String message) =>
      AdshiftError(AdshiftErrorCode.invalidArgument, message);

  static AdshiftError _notInitialized() => const AdshiftError(
    AdshiftErrorCode.notInitialized,
    'AdShift SDK is not initialized. Call Adshift.instance.initialize(config) '
    'first.',
  );

  static AdshiftError _notStarted() => const AdshiftError(
    AdshiftErrorCode.notStarted,
    'AdShift SDK is stopped. Call Adshift.instance.start() first.',
  );
}
