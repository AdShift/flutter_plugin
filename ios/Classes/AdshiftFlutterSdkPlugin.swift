import Flutter
import UIKit
import AdshiftSDK

/// Flutter plugin for AdShift SDK.
///
/// Bridges Flutter method channel calls to the native AdShift iOS SDK.
@available(iOS 15.0, *)
public class AdshiftFlutterSdkPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    
    // MARK: - Properties
    
    private var eventSink: FlutterEventSink?
    private var deepLinkListenerRegistered = false
    
    // MARK: - Plugin Registration
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        // Method channel for request/response calls
        let methodChannel = FlutterMethodChannel(
            name: "com.adshift/sdk",
            binaryMessenger: registrar.messenger()
        )
        
        // Event channel for deep link stream
        let eventChannel = FlutterEventChannel(
            name: "com.adshift/sdk/deeplinks",
            binaryMessenger: registrar.messenger()
        )
        
        let instance = AdshiftFlutterSdkPlugin()
        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }
    
    // MARK: - FlutterPlugin Method Handler
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        Task { @MainActor in
            await handleMethodCall(call, result: result)
        }
    }
    
    @MainActor
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
        switch call.method {
        case "initialize":
            handleInitialize(call, result: result)
            
        case "start":
            handleStart(result: result)
            
        case "stop":
            handleStop(result: result)
            
        case "isStarted":
            handleIsStarted(result: result)
            
        case "setDebugEnabled":
            handleSetDebugEnabled(call, result: result)
            
        case "setCustomerUserId":
            handleSetCustomerUserId(call, result: result)
            
        case "setAppOpenDebounceMs":
            handleSetAppOpenDebounceMs(call, result: result)
            
        case "trackEvent":
            await handleTrackEvent(call, result: result)
            
        case "trackPurchase":
            await handleTrackPurchase(call, result: result)
            
        case "setConsentData":
            handleSetConsentData(call, result: result)
            
        case "enableTCFDataCollection":
            handleEnableTCFDataCollection(call, result: result)
            
        case "refreshConsent":
            handleRefreshConsent(result: result)
            
        case "handleDeepLink":
            await handleDeepLink(call, result: result)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - Lifecycle Methods
    
    @MainActor
    private func handleInitialize(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let apiKey = args["apiKey"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "apiKey is required", details: nil))
            return
        }
        
        // Set API key
        Adshift.shared.apiKey = apiKey
        
        // Set optional configuration
        if let isDebug = args["isDebug"] as? Bool {
            Adshift.shared.isDebug = isDebug
        }
        
        if let appOpenDebounceMs = args["appOpenDebounceMs"] as? Int {
            Adshift.shared.appOpenDebounceMs = appOpenDebounceMs
        }
        
        if let disableSKAN = args["disableSKAN"] as? Bool {
            Adshift.shared.disableSKAN = disableSKAN
        }
        
        if let waitForATTBeforeStart = args["waitForATTBeforeStart"] as? Bool {
            Adshift.shared.waitForATTBeforeStart = waitForATTBeforeStart
        }
        
        if let attTimeoutMs = args["attTimeoutMs"] as? Int {
            Adshift.shared.attTimeoutMs = attTimeoutMs
        }
        
        result(nil)
    }
    
    @MainActor
    private func handleStart(result: @escaping FlutterResult) {
        Adshift.shared.start { response, error in
            if let error = error {
                result(FlutterError(
                    code: "START_ERROR",
                    message: error.localizedDescription,
                    details: nil
                ))
            } else {
                result(nil)
            }
        }
    }
    
    @MainActor
    private func handleStop(result: @escaping FlutterResult) {
        Adshift.shared.stop()
        result(nil)
    }
    
    @MainActor
    private func handleIsStarted(result: @escaping FlutterResult) {
        let isStarted = Adshift.shared.isStarted()
        result(isStarted)
    }
    
    // MARK: - Configuration Methods
    
    @MainActor
    private func handleSetDebugEnabled(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "enabled is required", details: nil))
            return
        }
        
        Adshift.shared.isDebug = enabled
        result(nil)
    }
    
    @MainActor
    private func handleSetCustomerUserId(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let userId = args["userId"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "userId is required", details: nil))
            return
        }
        
        Adshift.shared.setCustomerUserId(userId)
        result(nil)
    }
    
    @MainActor
    private func handleSetAppOpenDebounceMs(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let ms = args["ms"] as? Int else {
            result(FlutterError(code: "INVALID_ARGS", message: "ms is required", details: nil))
            return
        }
        
        Adshift.shared.appOpenDebounceMs = ms
        result(nil)
    }
    
    // MARK: - Event Tracking Methods
    
    @MainActor
    private func handleTrackEvent(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
        guard let args = call.arguments as? [String: Any],
              let eventName = args["eventName"] as? String else {
            result(FlutterError(code: "INVALID_ARGS", message: "eventName is required", details: nil))
            return
        }
        
        let values = args["values"] as? [String: Any]
        let eventType = mapStringToEventType(eventName)
        
        await Adshift.shared.track(
            event: eventType,
            values: values,
            completionHandler: { response, error in
                if let error = error {
                    result(FlutterError(
                        code: "TRACK_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                } else {
                    result(nil)
                }
            }
        )
    }
    
    @MainActor
    private func handleTrackPurchase(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
        guard let args = call.arguments as? [String: Any],
              let productId = args["productId"] as? String,
              let revenue = args["revenue"] as? Double,
              let currency = args["currency"] as? String,
              let transactionId = args["transactionId"] as? String else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "productId, revenue, currency, transactionId are required",
                details: nil
            ))
            return
        }
        
        // IMPORTANT: We pass revenue as price to native SDK
        // The native trackPurchase uses "price" internally
        await Adshift.shared.trackPurchase(
            productId: productId,
            price: revenue,
            currency: currency,
            token: transactionId,
            completionHandler: { response, error in
                if let error = error {
                    result(FlutterError(
                        code: "TRACK_ERROR",
                        message: error.localizedDescription,
                        details: nil
                    ))
                } else {
                    result(nil)
                }
            }
        )
    }
    
    // MARK: - Consent Methods
    
    @MainActor
    private func handleSetConsentData(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "INVALID_ARGS", message: "consent data is required", details: nil))
            return
        }
        
        let consent = mapToAdShiftConsent(args)
        Adshift.shared.setConsentData(consent)
        result(nil)
    }
    
    @MainActor
    private func handleEnableTCFDataCollection(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(code: "INVALID_ARGS", message: "enabled is required", details: nil))
            return
        }
        
        Adshift.shared.enableTCFDataCollection(enabled)
        result(nil)
    }
    
    @MainActor
    private func handleRefreshConsent(result: @escaping FlutterResult) {
        _ = Adshift.shared.refreshConsent()
        result(nil)
    }
    
    // MARK: - Deep Link Methods
    
    @MainActor
    private func handleDeepLink(_ call: FlutterMethodCall, result: @escaping FlutterResult) async {
        guard let args = call.arguments as? [String: Any],
              let urlString = args["url"] as? String,
              let url = URL(string: urlString) else {
            result(FlutterError(code: "INVALID_ARGS", message: "valid url is required", details: nil))
            return
        }
        
        do {
            let response = try await Adshift.shared.handleDeepLink(url: url)
            result(mapDeeplinkResponseToDict(response))
        } catch {
            result([
                "status": "error",
                "errorMessage": error.localizedDescription
            ])
        }
    }
    
    // MARK: - FlutterStreamHandler (Deep Link Events)
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        
        // Register deep link listener with native SDK
        if !deepLinkListenerRegistered {
            Task { @MainActor in
                Adshift.shared.onDeepLinkReceived { [weak self] response in
                    guard let self = self, let sink = self.eventSink else { return }
                    let dict = self.mapDeeplinkResponseToDict(response)
                    sink(dict)
                }
            }
            deepLinkListenerRegistered = true
        }
        
        return nil
    }
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
    
    // MARK: - Mappers
    
    /// Maps string event name to ASInAppEventType enum
    private func mapStringToEventType(_ eventName: String) -> ASInAppEventType {
        switch eventName {
        case "as_purchase": return .purchase
        case "as_login": return .login
        case "as_add_to_cart": return .addToCart
        case "as_add_to_wishlist": return .addToWishList
        case "as_add_payment_info": return .addPaymentInfo
        case "as_initiated_checkout": return .initiatedCheckout
        case "as_complete_registration": return .completeRegistration
        case "as_tutorial_completion": return .tutorialCompletion
        case "as_level_achieved": return .levelAchieved
        case "as_achievement_unlocked": return .achievementUnlocked
        case "as_content_view": return .contentView
        case "as_list_view": return .listView
        case "as_search": return .search
        case "as_rate": return .rate
        case "as_share": return .share
        case "as_invite": return .invite
        case "as_re_engage": return .reEngage
        case "as_update": return .update
        case "as_opened_from_push_notification": return .openedFromPushNotification
        case "as_subscribe": return .subscribe
        case "as_start_trial": return .startTrial
        case "as_ad_click": return .adClick
        case "as_ad_view": return .adView
        case "as_spent_credits": return .spentCredit
        case "as_travel_booking": return .travelBooking
        case "as_location_changed": return .locationChanged
        case "as_location_coordinates": return .locationCoordinates
        case "as_order_id": return .orderId
        case "as_customer_segment": return .customerSegment
        default: return .customEvent(eventName)
        }
    }
    
    /// Maps Flutter consent dictionary to native AdShiftConsent
    private func mapToAdShiftConsent(_ args: [String: Any]) -> AdShiftConsent {
        let isGDPR = args["isUserSubjectToGDPR"] as? Bool ?? false
        let dataUsage = args["hasConsentForDataUsage"] as? Bool ?? false
        let personalization = args["hasConsentForAdsPersonalization"] as? Bool ?? false
        let storage = args["hasConsentForAdStorage"] as? Bool ?? false
        
        if isGDPR {
            return AdShiftConsent.forGDPRUser(
                hasConsentForDataUsage: dataUsage,
                hasConsentForAdsPersonalization: personalization,
                hasConsentForAdStorage: storage
            )
        } else {
            return AdShiftConsent.forNonGDPRUser()
        }
    }
    
    /// Maps native DeeplinkResponse to Flutter dictionary
    private func mapDeeplinkResponseToDict(_ response: DeeplinkResponse) -> [String: Any?] {
        var params: [String: String] = [:]
        if let p = response.params {
            params = p
        }
        // Add sub parameters if present
        if let sub1 = response.deep_link_sub1 { params["deep_link_sub1"] = sub1 }
        if let sub2 = response.deep_link_sub2 { params["deep_link_sub2"] = sub2 }
        if let sub3 = response.deep_link_sub3 { params["deep_link_sub3"] = sub3 }
        if let sub4 = response.deep_link_sub4 { params["deep_link_sub4"] = sub4 }
        if let sub5 = response.deep_link_sub5 { params["deep_link_sub5"] = sub5 }
        
        // Map error enum to string
        var errorMessage: String? = nil
        if let error = response.error {
            switch error {
            case .decodingError:
                errorMessage = "Decoding error"
            case .invalidURL:
                errorMessage = "Invalid URL"
            case .deepLinkNotFound:
                errorMessage = "Deep link not found"
            case .systemError(let message):
                errorMessage = message
            @unknown default:
                errorMessage = "Unknown error"
            }
        }
        
        return [
            "deepLink": response.deeplink ?? response.deep_link_value,
            "params": params.isEmpty ? nil : params,
            "isDeferred": response.isDeferred ?? false,
            "status": response.status?.rawValue ?? "notFound",
            "errorMessage": errorMessage
        ]
    }
}
