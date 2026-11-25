import 'dart:async';

import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Run with `--dart-define=ADSHIFT_API_KEY=<your key>`.
const _apiKey = String.fromEnvironment(
  'ADSHIFT_API_KEY',
  defaultValue: 'YOUR_API_KEY',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ExampleApp());
}

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  final _adshift = Adshift.instance;
  final _log = <String>[];
  StreamSubscription<AdshiftDeepLink>? _links;

  @override
  void initState() {
    super.initState();

    // Listen first, so a link that opened the app is not missed.
    _links = _adshift.onDeepLink.listen(_onDeepLink);

    _adshift.initialize(
      AdshiftConfig(
        apiKey: _apiKey,
        isDebug: kDebugMode,
        // Test traffic stays out of your reports.
        testMode: true,
        onError: (error) =>
            _add('error ${error.code.wireName}: ${error.message}'),
      ),
    );

    // With a consent platform, set the consent before start().
    _adshift.setConsentData(const AdshiftConsent.forNonGDPRUser());

    // Not awaited: the first frame must not wait for start().
    _start();
  }

  @override
  void dispose() {
    _links?.cancel();
    super.dispose();
  }

  void _onDeepLink(AdshiftDeepLink link) {
    switch (link.status) {
      case AdshiftDeepLinkStatus.found:
        // Route on deepLinkValue; this is the only status to navigate on.
        _add(
          'link found: ${link.deepLinkValue} (deferred: ${link.isDeferred})',
        );
      case AdshiftDeepLinkStatus.notFound:
        // Not an AdShift link: the app's own URL, if any, is in deepLink.
        _add('link not found: ${link.deepLink ?? '-'}');
      case AdshiftDeepLinkStatus.error:
        // Not resolved yet; a found result can follow.
        _add('link pending: ${link.errorMessage}');
    }
  }

  Future<void> _start() async {
    final result = await _adshift.start();
    _add(
      result.success
          ? 'started (key: ${result.apiKeyValidationStatus?.name})'
          : 'start failed: ${result.error?.code.wireName}',
    );
  }

  Future<void> _track(String label, Future<AdshiftResult> call) async {
    final result = await call;
    _add(
      result.success
          ? '$label queued'
          : '$label: ${result.error?.code.wireName}',
    );
  }

  void _add(String line) {
    debugPrint('[adshift example] $line');
    if (mounted) setState(() => _log.insert(0, line));
  }

  late final _actions = <(String, VoidCallback)>[
    ('Start', _start),
    (
      'Stop',
      () {
        _adshift.stop();
        _add('stopped');
      },
    ),
    (
      'Track login',
      () {
        _track(
          'login',
          _adshift.trackEvent(
            AdshiftEventType.login,
            values: {AdshiftEventParam.registrationMethod: 'email'},
          ),
        );
      },
    ),
    (
      'Track purchase',
      () {
        _track(
          'purchase',
          _adshift.trackPurchase(
            productId: 'premium_monthly',
            revenue: 9.99,
            currency: 'USD',
            transactionId: 'txn-${DateTime.now().millisecondsSinceEpoch}',
          ),
        );
      },
    ),
    (
      'Log ad revenue',
      () {
        _track(
          'ad revenue',
          _adshift.logAdRevenue(
            monetizationNetwork: 'applovin',
            mediationNetwork: AdshiftMediationNetwork.appLovinMax,
            currency: 'USD',
            revenue: 0.012,
            adUnitId: 'home_banner',
          ),
        );
      },
    ),
    (
      'Consent: granted',
      () {
        _adshift.setConsentData(
          const AdshiftConsent.forGDPRUser(
            hasConsentForDataUsage: true,
            hasConsentForAdsPersonalization: true,
            hasConsentForAdStorage: true,
          ),
        );
        _add('consent granted');
      },
    ),
    (
      'Consent: denied',
      () {
        _adshift.setConsentData(
          const AdshiftConsent.forGDPRUser(
            hasConsentForDataUsage: false,
            hasConsentForAdsPersonalization: false,
            hasConsentForAdStorage: false,
          ),
        );
        _add('consent denied');
      },
    ),
    (
      'Refresh consent',
      () async {
        final snapshot = await _adshift.refreshConsent();
        _add(
          'consent source: ${snapshot?.source.name}, '
          'ad identifiers allowed: ${snapshot?.adIdentifiersAllowed}',
        );
      },
    ),
    (
      'Set customer user id',
      () {
        _adshift.setCustomerUserId('user-42');
        _add('customer user id set');
      },
    ),
    (
      'Device id',
      () async {
        _add('device id: ${await _adshift.getAdShiftDeviceId()}');
      },
    ),
    (
      'Pass a link manually',
      () {
        _adshift.handleDeepLink(
          Uri.parse('https://example.rightlink.me/app?pid=demo&c=example'),
        );
      },
    ),
    (
      'Push payload with a link',
      () async {
        final handled = await _adshift.handlePushNotification({
          'as_push_link': 'https://example.rightlink.me/app?pid=push&c=example',
        });
        _add('push carried an AdShift link: $handled');
      },
    ),
    ('Versions', () => _add('${_adshift.getInfo()}')),
  ];

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      color: const Color(0xFF1565C0),
      textStyle: const TextStyle(color: Color(0xFF202124), fontSize: 15),
      builder: (context, _) => ColoredBox(
        color: const Color(0xFFFFFFFF),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    for (final (label, action) in _actions)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: action,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          child: Text(
                            label,
                            style: const TextStyle(color: Color(0xFF1565C0)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                height: 220,
                width: double.infinity,
                color: const Color(0xFFF1F3F4),
                padding: const EdgeInsets.all(12),
                child: ListView(
                  children: [for (final line in _log) Text(line)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
