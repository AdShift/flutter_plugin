import 'dart:async';
import 'package:flutter/material.dart';
import 'package:adshift_flutter_sdk/adshift_flutter_sdk.dart';

void main() {
  runApp(const AdShiftExampleApp());
}

class AdShiftExampleApp extends StatelessWidget {
  const AdShiftExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AdShift SDK Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6366F1), // Indigo
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  // SDK State
  bool _isInitialized = false;
  bool _isStarted = false;
  String _status = 'Not initialized';

  // Consent State
  String _consentStatus = 'Not set';
  bool _tcfEnabled = false;

  // Event State
  int _selectedEventIndex = 0;
  String _lastEventResult = 'No events tracked yet';

  // DeepLink State
  String _deepLinkText = 'No deep links received';
  StreamSubscription<AdshiftDeepLink>? _deepLinkSubscription;

  // Customer ID
  String _customerIdText = 'null';

  // Logs
  final List<String> _logs = [];

  // Event Types (matching iOS/Android SDKs)
  final List<(String, String)> _eventTypes = [
    ('LEVEL_ACHIEVED', AdshiftEventType.levelAchieved),
    ('ADD_PAYMENT_INFO', AdshiftEventType.addPaymentInfo),
    ('ADD_TO_CART', AdshiftEventType.addToCart),
    ('ADD_TO_WISHLIST', AdshiftEventType.addToWishList),
    ('COMPLETE_REGISTRATION', AdshiftEventType.completeRegistration),
    ('TUTORIAL_COMPLETION', AdshiftEventType.tutorialCompletion),
    ('INITIATED_CHECKOUT', AdshiftEventType.initiatedCheckout),
    ('PURCHASE', AdshiftEventType.purchase),
    ('RATE', AdshiftEventType.rate),
    ('SEARCH', AdshiftEventType.search),
    ('SPENT_CREDIT', AdshiftEventType.spentCredit),
    ('ACHIEVEMENT_UNLOCKED', AdshiftEventType.achievementUnlocked),
    ('CONTENT_VIEW', AdshiftEventType.contentView),
    ('TRAVEL_BOOKING', AdshiftEventType.travelBooking),
    ('SHARE', AdshiftEventType.share),
    ('INVITE', AdshiftEventType.invite),
    ('LOGIN', AdshiftEventType.login),
    ('RE_ENGAGE', AdshiftEventType.reEngage),
    ('UPDATE', AdshiftEventType.update),
    ('OPENED_FROM_PUSH', AdshiftEventType.openedFromPushNotification),
    ('LIST_VIEW', AdshiftEventType.listView),
    ('SUBSCRIBE', AdshiftEventType.subscribe),
    ('START_TRIAL', AdshiftEventType.startTrial),
    ('AD_CLICK', AdshiftEventType.adClick),
    ('AD_VIEW', AdshiftEventType.adView),
  ];

  @override
  void initState() {
    super.initState();
    _initSdk();
    _setupDeepLinkListener();
  }

  @override
  void dispose() {
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  // ============================================
  // SDK Lifecycle
  // ============================================

  Future<void> _initSdk() async {
    try {
      await AdshiftFlutterSdk.instance.initialize(
        const AdshiftConfig(
          apiKey: 'YOUR_API_KEY_HERE', // Replace with real API key
          isDebug: true,
          appOpenDebounceMs: 10000,
        ),
      );
      _addLog('✅ SDK initialized');
      setState(() {
        _isInitialized = true;
        _status = 'Initialized (not started)';
      });
    } catch (e) {
      _addLog('❌ Init error: $e');
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _startSdk() async {
    if (!_isInitialized) {
      _addLog('⚠️ SDK not initialized');
      return;
    }
    try {
      await AdshiftFlutterSdk.instance.start();
      final started = await AdshiftFlutterSdk.instance.isStarted();
      _addLog('✅ SDK started');
      setState(() {
        _isStarted = started;
        _status = 'Running';
      });
    } catch (e) {
      _addLog('❌ Start error: $e');
    }
  }

  Future<void> _stopSdk() async {
    try {
      await AdshiftFlutterSdk.instance.stop();
      _addLog('⏹️ SDK stopped');
      setState(() {
        _isStarted = false;
        _status = 'Stopped';
      });
    } catch (e) {
      _addLog('❌ Stop error: $e');
    }
  }

  // ============================================
  // Consent Methods
  // ============================================

  Future<void> _giveConsent() async {
    try {
      await AdshiftFlutterSdk.instance.setConsentData(
        AdshiftConsent.forNonGDPRUser(),
      );
      _addLog('✅ Consent granted (non-GDPR)');
      setState(() => _consentStatus = 'Granted (non-GDPR)');
    } catch (e) {
      _addLog('❌ Consent error: $e');
    }
  }

  Future<void> _gdprAllow() async {
    try {
      await AdshiftFlutterSdk.instance.setConsentData(
        AdshiftConsent.forGDPRUser(
          hasConsentForDataUsage: true,
          hasConsentForAdsPersonalization: true,
          hasConsentForAdStorage: true,
        ),
      );
      _addLog('✅ GDPR consent: ALLOW');
      setState(() => _consentStatus = 'GDPR: Allow All');
    } catch (e) {
      _addLog('❌ Consent error: $e');
    }
  }

  Future<void> _gdprBlock() async {
    try {
      await AdshiftFlutterSdk.instance.setConsentData(
        AdshiftConsent.forGDPRUser(
          hasConsentForDataUsage: false,
          hasConsentForAdsPersonalization: false,
          hasConsentForAdStorage: false,
        ),
      );
      _addLog('🚫 GDPR consent: BLOCK');
      setState(() => _consentStatus = 'GDPR: Blocked');
    } catch (e) {
      _addLog('❌ Consent error: $e');
    }
  }

  Future<void> _toggleTCF() async {
    try {
      final newState = !_tcfEnabled;
      await AdshiftFlutterSdk.instance.enableTCFDataCollection(newState);
      _addLog('${newState ? '✅' : '❌'} TCF collection: ${newState ? 'enabled' : 'disabled'}');
      setState(() => _tcfEnabled = newState);
    } catch (e) {
      _addLog('❌ TCF error: $e');
    }
  }

  Future<void> _refreshConsent() async {
    try {
      await AdshiftFlutterSdk.instance.refreshConsent();
      _addLog('🔄 Consent refreshed');
    } catch (e) {
      _addLog('❌ Refresh error: $e');
    }
  }

  // ============================================
  // Event Tracking
  // ============================================

  Future<void> _trackSelectedEvent() async {
    if (!_isStarted) {
      _addLog('⚠️ SDK not started');
      return;
    }
    try {
      final event = _eventTypes[_selectedEventIndex];
      await AdshiftFlutterSdk.instance.trackEvent(
        event.$2,
        values: {'timestamp': DateTime.now().millisecondsSinceEpoch},
      );
      _addLog('📊 Tracked: ${event.$1}');
      setState(() => _lastEventResult = '${event.$1} sent ✅');
    } catch (e) {
      _addLog('❌ Track error: $e');
      setState(() => _lastEventResult = 'Error: $e');
    }
  }

  Future<void> _trackPurchase() async {
    if (!_isStarted) {
      _addLog('⚠️ SDK not started');
      return;
    }
    try {
      await AdshiftFlutterSdk.instance.trackPurchase(
        productId: 'premium_subscription',
        revenue: 9.99,
        currency: 'USD',
        transactionId: 'TXN_${DateTime.now().millisecondsSinceEpoch}',
      );
      _addLog('💰 Tracked: PURCHASE (9.99 USD)');
      setState(() => _lastEventResult = 'PURCHASE sent ✅ (9.99 USD)');
    } catch (e) {
      _addLog('❌ Purchase error: $e');
      setState(() => _lastEventResult = 'Error: $e');
    }
  }

  // ============================================
  // Customer ID & Config
  // ============================================

  Future<void> _setCustomerId() async {
    try {
      final cuid = 'user_${DateTime.now().millisecondsSinceEpoch % 10000}';
      await AdshiftFlutterSdk.instance.setCustomerUserId(cuid);
      _addLog('👤 Customer ID: $cuid');
      setState(() => _customerIdText = cuid);
    } catch (e) {
      _addLog('❌ CUID error: $e');
    }
  }

  Future<void> _setDebounceZero() async {
    try {
      await AdshiftFlutterSdk.instance.setAppOpenDebounceMs(0);
      _addLog('⏱️ Debounce set to 0ms');
    } catch (e) {
      _addLog('❌ Debounce error: $e');
    }
  }

  // ============================================
  // Deep Links
  // ============================================

  void _setupDeepLinkListener() {
    _deepLinkSubscription = AdshiftFlutterSdk.instance.onDeepLinkReceived.listen(
      (deepLink) {
        _addLog('🔗 DeepLink received: ${deepLink.status}');
        setState(() {
          final type = deepLink.isDeferred ? 'Deferred' : 'Direct';
          switch (deepLink.status) {
            case AdshiftDeepLinkStatus.found:
              _deepLinkText = '$type Link\n${deepLink.deepLink ?? 'N/A'}';
              if (deepLink.params != null) {
                _deepLinkText += '\nParams: ${deepLink.params}';
              }
              break;
            case AdshiftDeepLinkStatus.notFound:
              _deepLinkText = '$type Link\nNo deep link available';
              break;
            case AdshiftDeepLinkStatus.error:
              _deepLinkText = 'Error processing deep link';
              break;
          }
        });
      },
      onError: (e) {
        _addLog('❌ DeepLink stream error: $e');
      },
    );
  }

  Future<void> _handleTestDeepLink() async {
    try {
      final result = await AdshiftFlutterSdk.instance.handleDeepLink(
        Uri.parse('https://rightlink.me/app?pid=test&c=campaign'),
      );
      _addLog('🔗 DeepLink handled: ${result.status}');
      setState(() {
        if (result.status == AdshiftDeepLinkStatus.found) {
          _deepLinkText = 'Direct Link\n${result.deepLink ?? 'N/A'}';
        } else {
          _deepLinkText = 'No deep link found';
        }
      });
    } catch (e) {
      _addLog('❌ DeepLink error: $e');
    }
  }

  // ============================================
  // Helpers
  // ============================================

  void _addLog(String message) {
    final time = DateTime.now().toIso8601String().substring(11, 19);
    setState(() {
      _logs.insert(0, '[$time] $message');
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  // ============================================
  // UI
  // ============================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AdShift SDK Demo'),
        centerTitle: true,
        backgroundColor: theme.colorScheme.primaryContainer,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // SDK Status Card
            _buildSdkStatusCard(theme),
            const SizedBox(height: 16),

            // Consent Section
            _buildConsentSection(theme),
            const SizedBox(height: 16),

            // SDK Control Section
            _buildSdkControlSection(theme),
            const SizedBox(height: 16),

            // Events Section
            _buildEventsSection(theme),
            const SizedBox(height: 16),

            // Customer ID Section
            _buildCustomerIdSection(theme),
            const SizedBox(height: 16),

            // DeepLink Section
            _buildDeepLinkSection(theme),
            const SizedBox(height: 16),

            // Last Event Section
            _buildLastEventSection(theme),
            const SizedBox(height: 16),

            // Logs Section
            _buildLogsSection(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildSdkStatusCard(ThemeData theme) {
    return Card(
      color: _isStarted 
          ? Colors.green.shade50 
          : (_isInitialized ? Colors.orange.shade50 : Colors.grey.shade100),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isStarted 
                    ? Colors.green 
                    : (_isInitialized ? Colors.orange : Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isStarted ? 'SDK Running' : (_isInitialized ? 'SDK Ready' : 'SDK Not Initialized'),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(_status, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConsentSection(ThemeData theme) {
    return _buildSection(
      theme,
      title: '🛡️ Consent Testing (DMA/GDPR)',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildButton('Give Consent', _giveConsent),
            _buildButton('GDPR Allow', _gdprAllow, color: Colors.green),
            _buildButton('GDPR Block', _gdprBlock, color: Colors.red),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildButton(
              _tcfEnabled ? '✅ TCF Enabled' : 'Enable TCF',
              _toggleTCF,
              color: _tcfEnabled ? Colors.green : null,
            ),
            _buildButton('Refresh Consent', _refreshConsent),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Status: $_consentStatus',
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildSdkControlSection(ThemeData theme) {
    return _buildSection(
      theme,
      title: '⚙️ SDK Control',
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildButton(
              'Start',
              _isInitialized && !_isStarted ? _startSdk : null,
              color: Colors.green,
            ),
            _buildButton(
              'Stop',
              _isStarted ? _stopSdk : null,
              color: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEventsSection(ThemeData theme) {
    return _buildSection(
      theme,
      title: '📊 Event Tracking',
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                initialValue: _selectedEventIndex,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: _eventTypes.asMap().entries.map((e) {
                  return DropdownMenuItem(value: e.key, child: Text(e.value.$1, style: const TextStyle(fontSize: 12)));
                }).toList(),
                onChanged: (value) => setState(() => _selectedEventIndex = value ?? 0),
              ),
            ),
            const SizedBox(width: 8),
            _buildButton('Track', _trackSelectedEvent),
          ],
        ),
        const SizedBox(height: 12),
        _buildButton('💰 Track Purchase (9.99 USD)', _trackPurchase, fullWidth: true),
      ],
    );
  }

  Widget _buildCustomerIdSection(ThemeData theme) {
    return _buildSection(
      theme,
      title: '👤 Customer ID',
      children: [
        Row(
          children: [
            _buildButton('Set Customer ID', _setCustomerId),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _customerIdText,
                style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildButton('Debounce 0ms', _setDebounceZero),
      ],
    );
  }

  Widget _buildDeepLinkSection(ThemeData theme) {
    return _buildSection(
      theme,
      title: '🔗 Deep Links',
      children: [
        _buildButton('Handle Test DeepLink', _handleTestDeepLink),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.indigo.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.indigo.shade200),
          ),
          child: Text(
            _deepLinkText,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildLastEventSection(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📨 Last Event', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_lastEventResult, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildLogsSection(ThemeData theme) {
    return _buildSection(
      theme,
      title: '📋 Logs',
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _logs.length,
            itemBuilder: (context, index) {
              return Text(
                _logs[index],
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: Colors.greenAccent,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSection(ThemeData theme, {required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildButton(String label, VoidCallback? onPressed, {Color? color, bool fullWidth = false}) {
    final button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: color != null ? Colors.white : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
    
    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }
}
