import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:adshift_flutter_sdk/src/adshift_impl.dart';
import 'package:adshift_flutter_sdk/src/messages.g.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_host.dart';

export 'package:adshift_flutter_sdk/src/messages.g.dart';

export 'fake_host.dart';

/// The real implementation over a [FakeHost]. What it prints in debug builds
/// lands in [logs], what it reports through `onError` in [errors].
class Harness {
  Harness() {
    final printed = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) => logs.add(message ?? '');
    addTearDown(() => debugPrint = printed);
  }

  final FakeHost host = FakeHost();
  final List<String> logs = [];
  final List<AdshiftError> errors = [];
  AdshiftFlutterApi? _handler;

  late final AdshiftImpl adshift = AdshiftImpl(
    host: host,
    registerHandler: (handler) {
      host.calls.add(['registerHandler']);
      _handler = handler;
    },
  );

  /// A valid config that collects what the SDK reports.
  AdshiftConfig get config =>
      AdshiftConfig(apiKey: 'key-123', onError: errors.add);

  List<AdshiftErrorCode> get errorCodes => [
    for (final error in errors) error.code,
  ];

  /// Initializes and waits for the platform's answer.
  Future<void> initialize([AdshiftConfig? config]) async {
    adshift.initialize(config ?? this.config);
    await settle();
  }

  Future<void> initializeAndStart() async {
    await initialize();
    await adshift.start();
  }

  /// A deep link result arriving from the platform.
  void emit(DeepLinkMessage link) => _handler!.onDeepLink(link);
}

/// Lets everything already scheduled run.
Future<void> settle() => pumpEventQueue();

DeepLinkMessage foundLink(String deepLink, {bool isDeferred = false}) =>
    DeepLinkMessage(
      status: DeepLinkStatusMessage.found,
      isDeferred: isDeferred,
      deepLink: deepLink,
    );

/// Matches a result that carries an error with [code].
Matcher failsWith(AdshiftErrorCode code) => anyOf(
  isA<AdshiftResult>().having((r) => r.error?.code, 'error.code', code),
  isA<AdshiftStartResult>().having((r) => r.error?.code, 'error.code', code),
);

/// Matches a tracking result without an error.
final Matcher succeeds = isA<AdshiftResult>().having(
  (r) => r.error,
  'error',
  isNull,
);
