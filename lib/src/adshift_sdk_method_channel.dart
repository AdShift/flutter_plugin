import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'adshift_sdk_platform_interface.dart';
import 'models/adshift_config.dart';
import 'models/adshift_consent.dart';
import 'models/adshift_deeplink.dart';

/// Method channel implementation of [AdshiftSdkPlatform].
///
/// Communicates with native iOS and Android code via platform channels.
class MethodChannelAdshiftSdk extends AdshiftSdkPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('com.adshift/sdk');

  /// Event channel for receiving deep link events from native code.
  @visibleForTesting
  final eventChannel = const EventChannel('com.adshift/sdk/deeplinks');

  /// Stream controller for deep link events.
  StreamController<AdshiftDeepLink>? _deepLinkController;

  /// Stream of deep link events.
  Stream<AdshiftDeepLink>? _deepLinkStream;

  // ============ Lifecycle ============

  @override
  Future<void> initialize(AdshiftConfig config) async {
    try {
      await methodChannel.invokeMethod('initialize', config.toMap());
    } on PlatformException catch (e) {
      throw _handleError('initialize', e);
    }
  }

  @override
  Future<void> start() async {
    try {
      await methodChannel.invokeMethod('start');
    } on PlatformException catch (e) {
      throw _handleError('start', e);
    }
  }

  @override
  Future<void> stop() async {
    try {
      await methodChannel.invokeMethod('stop');
    } on PlatformException catch (e) {
      throw _handleError('stop', e);
    }
  }

  @override
  Future<bool> isStarted() async {
    try {
      final result = await methodChannel.invokeMethod<bool>('isStarted');
      return result ?? false;
    } on PlatformException catch (e) {
      throw _handleError('isStarted', e);
    }
  }

  // ============ Configuration ============

  @override
  Future<void> setDebugEnabled(bool enabled) async {
    try {
      await methodChannel.invokeMethod('setDebugEnabled', {'enabled': enabled});
    } on PlatformException catch (e) {
      throw _handleError('setDebugEnabled', e);
    }
  }

  @override
  Future<void> setCustomerUserId(String userId) async {
    try {
      await methodChannel.invokeMethod('setCustomerUserId', {'userId': userId});
    } on PlatformException catch (e) {
      throw _handleError('setCustomerUserId', e);
    }
  }

  @override
  Future<void> setAppOpenDebounceMs(int ms) async {
    try {
      await methodChannel.invokeMethod('setAppOpenDebounceMs', {'ms': ms});
    } on PlatformException catch (e) {
      throw _handleError('setAppOpenDebounceMs', e);
    }
  }

  // ============ Events ============

  @override
  Future<void> trackEvent(String eventName, Map<String, dynamic>? values) async {
    try {
      await methodChannel.invokeMethod('trackEvent', {
        'eventName': eventName,
        'values': values,
      });
    } on PlatformException catch (e) {
      throw _handleError('trackEvent', e);
    }
  }

  @override
  Future<void> trackPurchase({
    required String productId,
    required double revenue,
    required String currency,
    required String transactionId,
  }) async {
    try {
      await methodChannel.invokeMethod('trackPurchase', {
        'productId': productId,
        'revenue': revenue,
        'currency': currency,
        'transactionId': transactionId,
      });
    } on PlatformException catch (e) {
      throw _handleError('trackPurchase', e);
    }
  }

  // ============ Consent ============

  @override
  Future<void> setConsentData(AdshiftConsent consent) async {
    try {
      await methodChannel.invokeMethod('setConsentData', consent.toMap());
    } on PlatformException catch (e) {
      throw _handleError('setConsentData', e);
    }
  }

  @override
  Future<void> enableTCFDataCollection(bool enabled) async {
    try {
      await methodChannel.invokeMethod('enableTCFDataCollection', {'enabled': enabled});
    } on PlatformException catch (e) {
      throw _handleError('enableTCFDataCollection', e);
    }
  }

  @override
  Future<void> refreshConsent() async {
    try {
      await methodChannel.invokeMethod('refreshConsent');
    } on PlatformException catch (e) {
      throw _handleError('refreshConsent', e);
    }
  }

  // ============ Deep Links ============

  @override
  Future<AdshiftDeepLink> handleDeepLink(String url) async {
    try {
      final result = await methodChannel.invokeMethod<Map<Object?, Object?>>('handleDeepLink', {'url': url});
      if (result == null) {
        return AdshiftDeepLink.notFound();
      }
      return AdshiftDeepLink.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      return AdshiftDeepLink.error(e.message ?? 'Unknown error');
    }
  }

  @override
  Stream<AdshiftDeepLink> get onDeepLinkReceived {
    _deepLinkStream ??= _createDeepLinkStream();
    return _deepLinkStream!;
  }

  Stream<AdshiftDeepLink> _createDeepLinkStream() {
    _deepLinkController = StreamController<AdshiftDeepLink>.broadcast(
      onListen: _startListeningToDeepLinks,
      onCancel: _stopListeningToDeepLinks,
    );
    return _deepLinkController!.stream;
  }

  StreamSubscription<dynamic>? _deepLinkSubscription;

  void _startListeningToDeepLinks() {
    _deepLinkSubscription = eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final deepLink = AdshiftDeepLink.fromMap(Map<String, dynamic>.from(event));
          _deepLinkController?.add(deepLink);
        }
      },
      onError: (error) {
        _deepLinkController?.addError(error);
      },
    );
  }

  void _stopListeningToDeepLinks() {
    _deepLinkSubscription?.cancel();
    _deepLinkSubscription = null;
  }

  // ============ Error Handling ============

  Exception _handleError(String method, PlatformException e) {
    debugPrint('AdshiftFlutterSdk: Error in $method: ${e.message}');
    return Exception('AdshiftFlutterSdk.$method failed: ${e.message}');
  }
}

