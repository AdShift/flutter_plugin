package com.adshift.adshift_flutter_sdk

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import com.adshift.sdk.core.AdShiftLib
import com.adshift.sdk.core.AdShiftConsent
import com.adshift.sdk.core.AdShiftRequestListener
import com.adshift.sdk.core.deeplink.DeepLinkListener
import com.adshift.sdk.core.deeplink.DeepLinkResult
import com.adshift.sdk.core.deeplink.DeepLinkStatus

/**
 * Flutter plugin for AdShift SDK.
 *
 * Bridges Flutter method channel calls to the native AdShift Android SDK.
 */
class AdshiftFlutterSdkPlugin :
    FlutterPlugin,
    MethodCallHandler,
    ActivityAware,
    EventChannel.StreamHandler {

    // MARK: - Properties
    
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var applicationContext: Context? = null
    private var activity: Activity? = null
    private var eventSink: EventChannel.EventSink? = null
    private var deepLinkListenerRegistered = false
    
    // Handler for main thread operations (required by Flutter channels)
    private val mainHandler = Handler(Looper.getMainLooper())

    // MARK: - FlutterPlugin

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = flutterPluginBinding.applicationContext
        
        // Method channel for request/response calls
        methodChannel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            "com.adshift/sdk"
        )
        methodChannel.setMethodCallHandler(this)
        
        // Event channel for deep link stream
        eventChannel = EventChannel(
            flutterPluginBinding.binaryMessenger,
            "com.adshift/sdk/deeplinks"
        )
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        applicationContext = null
    }

    // MARK: - ActivityAware

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    // MARK: - MethodCallHandler

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> handleInitialize(call, result)
            "start" -> handleStart(result)
            "stop" -> handleStop(result)
            "isStarted" -> handleIsStarted(result)
            "setDebugEnabled" -> handleSetDebugEnabled(call, result)
            "setCustomerUserId" -> handleSetCustomerUserId(call, result)
            "setAppOpenDebounceMs" -> handleSetAppOpenDebounceMs(call, result)
            "trackEvent" -> handleTrackEvent(call, result)
            "trackPurchase" -> handleTrackPurchase(call, result)
            "setConsentData" -> handleSetConsentData(call, result)
            "enableTCFDataCollection" -> handleEnableTCFDataCollection(call, result)
            "refreshConsent" -> handleRefreshConsent(result)
            "handleDeepLink" -> handleDeepLink(call, result)
            else -> result.notImplemented()
        }
    }

    // MARK: - Lifecycle Methods

    private fun handleInitialize(call: MethodCall, result: Result) {
        val context = applicationContext
        if (context == null) {
            result.error("NO_CONTEXT", "Application context not available", null)
            return
        }

        val args = call.arguments as? Map<*, *>
        val apiKey = args?.get("apiKey") as? String
        
        if (apiKey.isNullOrBlank()) {
            result.error("INVALID_ARGS", "apiKey is required", null)
            return
        }

        try {
            // Initialize SDK
            AdShiftLib.initSdk(context, apiKey)
            
            // Apply optional configuration
            val isDebug = args["isDebug"] as? Boolean
            if (isDebug != null) {
                AdShiftLib.setDebugLog(isDebug)
            }
            
            val appOpenDebounceMs = args["appOpenDebounceMs"] as? Int
            if (appOpenDebounceMs != null) {
                AdShiftLib.setAppOpenDebounceMs(appOpenDebounceMs.toLong())
            }
            
            val collectOaid = args["collectOaid"] as? Boolean
            if (collectOaid != null) {
                AdShiftLib.setCollectOaid(collectOaid)
            }
            
            result.success(null)
        } catch (e: Exception) {
            result.error("INIT_ERROR", e.message, null)
        }
    }

    private fun handleStart(result: Result) {
        try {
            AdShiftLib.start(object : AdShiftRequestListener {
                override fun onSuccess() {
                    result.success(null)
                }

                override fun onError(code: Int, error: String) {
                    result.error("START_ERROR", error, code.toString())
                }
            })
        } catch (e: Exception) {
            result.error("START_ERROR", e.message, null)
        }
    }

    private fun handleStop(result: Result) {
        try {
            AdShiftLib.stop()
            result.success(null)
        } catch (e: Exception) {
            result.error("STOP_ERROR", e.message, null)
        }
    }

    private fun handleIsStarted(result: Result) {
        try {
            val isStarted = AdShiftLib.isStarted()
            result.success(isStarted)
        } catch (e: Exception) {
            result.success(false)
        }
    }

    // MARK: - Configuration Methods

    private fun handleSetDebugEnabled(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *>
        val enabled = args?.get("enabled") as? Boolean
        
        if (enabled == null) {
            result.error("INVALID_ARGS", "enabled is required", null)
            return
        }

        try {
            AdShiftLib.setDebugLog(enabled)
            result.success(null)
        } catch (e: Exception) {
            result.error("CONFIG_ERROR", e.message, null)
        }
    }

    private fun handleSetCustomerUserId(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *>
        val userId = args?.get("userId") as? String
        
        if (userId.isNullOrBlank()) {
            result.error("INVALID_ARGS", "userId is required", null)
            return
        }

        try {
            AdShiftLib.setCustomerUserId(userId)
            result.success(null)
        } catch (e: Exception) {
            result.error("CONFIG_ERROR", e.message, null)
        }
    }

    private fun handleSetAppOpenDebounceMs(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *>
        val ms = args?.get("ms") as? Int
        
        if (ms == null) {
            result.error("INVALID_ARGS", "ms is required", null)
            return
        }

        try {
            AdShiftLib.setAppOpenDebounceMs(ms.toLong())
            result.success(null)
        } catch (e: Exception) {
            result.error("CONFIG_ERROR", e.message, null)
        }
    }

    // MARK: - Event Tracking Methods

    private fun handleTrackEvent(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *>
        val eventName = args?.get("eventName") as? String
        
        if (eventName.isNullOrBlank()) {
            result.error("INVALID_ARGS", "eventName is required", null)
            return
        }

        @Suppress("UNCHECKED_CAST")
        val values = (args["values"] as? Map<String, Any>) ?: emptyMap()

        try {
            AdShiftLib.trackEvent(
                eventName = eventName,
                eventValue = values,
                listener = object : AdShiftRequestListener {
                    override fun onSuccess() {
                        result.success(null)
                    }

                    override fun onError(code: Int, error: String) {
                        result.error("TRACK_ERROR", error, code.toString())
                    }
                }
            )
        } catch (e: Exception) {
            result.error("TRACK_ERROR", e.message, null)
        }
    }

    private fun handleTrackPurchase(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *>
        
        val productId = args?.get("productId") as? String
        val revenue = args?.get("revenue") as? Double
        val currency = args?.get("currency") as? String
        val transactionId = args?.get("transactionId") as? String
        
        if (productId.isNullOrBlank() || revenue == null || currency.isNullOrBlank() || transactionId.isNullOrBlank()) {
            result.error("INVALID_ARGS", "productId, revenue, currency, transactionId are required", null)
            return
        }

        try {
            // IMPORTANT: Native SDK uses "price" parameter name
            // We receive "revenue" from Flutter and pass it as price
            AdShiftLib.trackPurchase(
                productId = productId,
                price = revenue,
                currency = currency,
                token = transactionId,
                listener = object : AdShiftRequestListener {
                    override fun onSuccess() {
                        result.success(null)
                    }

                    override fun onError(code: Int, error: String) {
                        result.error("TRACK_ERROR", error, code.toString())
                    }
                }
            )
        } catch (e: Exception) {
            result.error("TRACK_ERROR", e.message, null)
        }
    }

    // MARK: - Consent Methods

    private fun handleSetConsentData(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.error("INVALID_ARGS", "consent data is required", null)
            return
        }

        try {
            val consent = mapToAdShiftConsent(args)
            AdShiftLib.setConsentData(consent)
            result.success(null)
        } catch (e: Exception) {
            result.error("CONSENT_ERROR", e.message, null)
        }
    }

    private fun handleEnableTCFDataCollection(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *>
        val enabled = args?.get("enabled") as? Boolean
        
        if (enabled == null) {
            result.error("INVALID_ARGS", "enabled is required", null)
            return
        }

        try {
            AdShiftLib.enableTCFDataCollection(enabled)
            result.success(null)
        } catch (e: Exception) {
            result.error("CONFIG_ERROR", e.message, null)
        }
    }

    private fun handleRefreshConsent(result: Result) {
        try {
            AdShiftLib.refreshConsent()
            result.success(null)
        } catch (e: Exception) {
            result.error("CONSENT_ERROR", e.message, null)
        }
    }

    // MARK: - Deep Link Methods

    private fun handleDeepLink(call: MethodCall, result: Result) {
        val args = call.arguments as? Map<*, *>
        val urlString = args?.get("url") as? String
        
        if (urlString.isNullOrBlank()) {
            result.error("INVALID_ARGS", "url is required", null)
            return
        }

        try {
            val uri = Uri.parse(urlString)
            val intent = Intent(Intent.ACTION_VIEW, uri)
            
            // Register one-time listener for this specific call
            AdShiftLib.setDeepLinkListener(object : DeepLinkListener {
                override fun onDeepLinking(deepLinkResult: DeepLinkResult) {
                    val responseMap = mapDeepLinkResultToMap(deepLinkResult)
                    // Callback may be on background thread, post to main
                    mainHandler.post {
                        result.success(responseMap)
                    }
                }
            })
            
            AdShiftLib.handleAppLinkIntent(intent)
        } catch (e: Exception) {
            result.success(mapOf(
                "status" to "error",
                "errorMessage" to (e.message ?: "Unknown error")
            ))
        }
    }

    // MARK: - EventChannel.StreamHandler (Deep Link Events)

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        
        // Register deep link listener with native SDK
        if (!deepLinkListenerRegistered) {
            try {
                AdShiftLib.setDeepLinkListener(object : DeepLinkListener {
                    override fun onDeepLinking(deepLinkResult: DeepLinkResult) {
                        val responseMap = mapDeepLinkResultToMap(deepLinkResult)
                        // Must call eventSink on main thread
                        mainHandler.post {
                            eventSink?.success(responseMap)
                        }
                    }
                })
                deepLinkListenerRegistered = true
            } catch (e: Exception) {
                // SDK might not be initialized yet, that's ok
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // MARK: - Mappers

    /**
     * Maps Flutter consent map to native AdShiftConsent
     */
    private fun mapToAdShiftConsent(args: Map<*, *>): AdShiftConsent {
        val isGDPR = args["isUserSubjectToGDPR"] as? Boolean ?: false
        val dataUsage = args["hasConsentForDataUsage"] as? Boolean ?: false
        val personalization = args["hasConsentForAdsPersonalization"] as? Boolean ?: false
        val storage = args["hasConsentForAdStorage"] as? Boolean ?: false

        return if (isGDPR) {
            AdShiftConsent.forGDPRUser(
                hasConsentForDataUsage = dataUsage,
                hasConsentForAdsPersonalization = personalization,
                hasConsentForAdStorage = storage
            )
        } else {
            AdShiftConsent.forNonGDPRUser()
        }
    }

    /**
     * Maps native DeepLinkResult to Flutter map
     */
    private fun mapDeepLinkResultToMap(result: DeepLinkResult): Map<String, Any?> {
        val params = mutableMapOf<String, String>()
        
        result.queryParams?.let { params.putAll(it) }
        result.sub1?.let { params["deep_link_sub1"] = it }
        result.sub2?.let { params["deep_link_sub2"] = it }
        result.sub3?.let { params["deep_link_sub3"] = it }
        result.sub4?.let { params["deep_link_sub4"] = it }
        result.sub5?.let { params["deep_link_sub5"] = it }

        val statusString = when (result.status) {
            DeepLinkStatus.FOUND -> "found"
            DeepLinkStatus.NOT_FOUND -> "notFound"
            DeepLinkStatus.ERROR -> "error"
        }

        val errorMessage = result.error?.name?.lowercase()?.replace("_", " ")

        return mapOf(
            "deepLink" to result.uri?.toString(),
            "params" to if (params.isEmpty()) null else params,
            "isDeferred" to result.isDeferred,
            "status" to statusString,
            "errorMessage" to errorMessage
        )
    }
}
