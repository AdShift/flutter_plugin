package com.adshift.adshift_flutter_sdk

import android.app.Activity
import android.app.Application
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import com.adshift.sdk.core.AdShiftConsent
import com.adshift.sdk.core.AdShiftLib
import com.adshift.sdk.core.AdShiftRequestListener
import com.adshift.sdk.core.AdShiftThirdPartySharing
import com.adshift.sdk.core.deeplink.DeepLinkResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Connects one Flutter engine to the AdShift SDK. The SDK runs once per process and answers to the
 * engine of the Activity the user sees, or saw last; in any other engine, such as one that runs
 * Dart in the background, calls are answered without reaching the SDK.
 */
class AdshiftFlutterSdkPlugin :
    FlutterPlugin,
    ActivityAware,
    PluginRegistry.NewIntentListener,
    ActivityPluginBinding.OnSaveInstanceStateListener,
    AdshiftHostApi {

    private companion object {
        const val STATE_LAUNCH_INTENT_FORWARDED = "com.adshift.launch_intent_forwarded"
        const val STATE_LAUNCH_PUSH_ACCEPTED = "com.adshift.launch_push_accepted"
        const val START_VERDICT_TIMEOUT_MS = 5_000L
    }

    private val bridge = AdshiftBridge.shared

    private var flutterApi: AdshiftFlutterApi? = null
    private var activityBinding: ActivityPluginBinding? = null

    /** Whether Dart has called `deepLinkListenerReady` since its last `initialize`. */
    private var dartListening = false

    internal var intents: ActivityIntents? = null
        private set

    /** Tells when the attached Activity comes back to the user. */
    private val activityStarts = object : Application.ActivityLifecycleCallbacks {
        override fun onActivityStarted(activity: Activity) = onStarted(activity)
        override fun onActivityResumed(activity: Activity) = onStarted(activity)
        override fun onActivityCreated(activity: Activity, savedInstanceState: Bundle?) = Unit
        override fun onActivityPaused(activity: Activity) = Unit
        override fun onActivityStopped(activity: Activity) = Unit
        override fun onActivitySaveInstanceState(activity: Activity, outState: Bundle) = Unit
        override fun onActivityDestroyed(activity: Activity) = Unit
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        flutterApi = AdshiftFlutterApi(binding.binaryMessenger)
        AdshiftHostApi.setUp(binding.binaryMessenger, this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        AdshiftHostApi.setUp(binding.binaryMessenger, null)
        flutterApi = null
        dartListening = false
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) = attach(binding)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = attach(binding)

    override fun onDetachedFromActivityForConfigChanges() = detach()

    override fun onDetachedFromActivity() = detach()

    private fun attach(binding: ActivityPluginBinding) {
        activityBinding = binding
        intents = ActivityIntents(binding.activity.intent)
        binding.addOnNewIntentListener(this)
        binding.addOnSaveStateListener(this)
        binding.activity.application.registerActivityLifecycleCallbacks(activityStarts)
        bridge.attach(this)
    }

    private fun detach() {
        activityBinding?.let {
            it.removeOnNewIntentListener(this)
            it.removeOnSaveStateListener(this)
            it.activity.application.unregisterActivityLifecycleCallbacks(activityStarts)
        }
        activityBinding = null
        intents = null
        bridge.detach(this)
    }

    /** Flutter calls this while the Activity is created; [bundle] is null unless it is re-created. */
    override fun onRestoreInstanceState(bundle: Bundle?) {
        if (bundle != null) {
            intents?.restored(
                forwarded = bundle.getBoolean(STATE_LAUNCH_INTENT_FORWARDED),
                pushAccepted = bundle.getBoolean(STATE_LAUNCH_PUSH_ACCEPTED),
            )
        }
        bridge.forwardWaitingIntents(this)
    }

    override fun onSaveInstanceState(bundle: Bundle) {
        val intents = intents ?: return
        bundle.putBoolean(STATE_LAUNCH_INTENT_FORWARDED, intents.launchForwarded)
        bundle.putBoolean(STATE_LAUNCH_PUSH_ACCEPTED, intents.launchPushAccepted)
        intents.stateSaved = true
    }

    /** The Activity the user returns to drives the SDK again, and what waited for it goes on. */
    private fun onStarted(activity: Activity) {
        if (activity !== activityBinding?.activity) return
        intents?.stateSaved = false
        bridge.attach(this)
        bridge.forwardWaitingIntents(this)
    }

    /** Returns false: the Intent stays available to the app and to other plugins. */
    override fun onNewIntent(intent: Intent): Boolean {
        bridge.onNewIntent(this, intent)
        return false
    }

    /** Sends [result] to Dart; false when Dart does not listen, so that the result is kept. */
    internal fun send(result: DeepLinkResult): Boolean {
        val api = flutterApi?.takeIf { dartListening } ?: return false
        bridge.scope.launch(Dispatchers.Main.immediate) {
            try {
                api.onDeepLink(result.toMessage())
            } catch (e: Exception) {
                Log.w(AdshiftBridge.TAG, "onDeepLink failed: ${e.javaClass.simpleName}")
            }
        }
        return true
    }

    override fun deepLinkListenerReady() {
        dartListening = true
        bridge.sendHeldResults()
    }

    override fun initialize(options: InitializeMessage): ErrorMessage? {
        // Dart has started, or started over: results wait until it says that it listens.
        dartListening = false
        val activity = activityBinding?.activity
        if (activity == null || !bridge.isOwner(this)) return notOwner()
        return bridge.initialize(options, activity.applicationContext)
    }

    /**
     * Waits up to [START_VERDICT_TIMEOUT_MS] for the answer on the API key; without one, answers
     * started with the key pending.
     */
    override suspend fun start(): StartMessage {
        refusal()?.let { return StartMessage(success = false, error = it) }
        val verdict = CompletableDeferred<StartMessage>()
        try {
            AdShiftLib.start(object : AdShiftRequestListener {
                override fun onSuccess() {
                    verdict.complete(StartMessage(success = true, keyStatus = KeyStatusMessage.VALID))
                }

                override fun onError(code: Int, error: String) {
                    verdict.complete(
                        StartMessage(
                            success = false,
                            keyStatus = KeyStatusMessage.INVALID.takeIf { code == SdkErrorCode.INVALID_API_KEY },
                            error = sdkError(code, error),
                        )
                    )
                }
            })
        } catch (e: Exception) {
            return StartMessage(success = false, error = thrownError(e))
        }
        return withTimeoutOrNull(START_VERDICT_TIMEOUT_MS) { verdict.await() }
            ?: StartMessage(success = true, keyStatus = KeyStatusMessage.PENDING)
    }

    override fun stop() = queued("stop") { AdShiftLib.stop() }

    override fun setCustomerUserId(userId: String) = queued("setCustomerUserId") {
        AdShiftLib.setCustomerUserId(userId)
    }

    override fun setDebugEnabled(enabled: Boolean) = queued("setDebugEnabled") {
        AdShiftLib.setDebugLog(enabled)
    }

    override fun setAppOpenDebounceMs(ms: Long) = queued("setAppOpenDebounceMs") {
        AdShiftLib.setAppOpenDebounceMs(ms)
    }

    override fun setBrandedDomains(domains: List<String>) = queued("setBrandedDomains") {
        AdShiftLib.setBrandedDomains(domains.filter { it.isNotBlank() })
    }

    override fun setMetaAppId(appId: String) = queued("setMetaAppId") {
        AdShiftLib.setMetaAppId(appId)
    }

    override fun setOaidData(oaid: String) = queued("setOaidData") {
        AdShiftLib.setOaidData(oaid)
    }

    override fun setConsentData(consent: ConsentMessage) = queued("setConsentData") {
        AdShiftLib.setConsentData(
            if (consent.isUserSubjectToGdpr) {
                AdShiftConsent.forGDPRUser(
                    hasConsentForDataUsage = consent.hasConsentForDataUsage,
                    hasConsentForAdsPersonalization = consent.hasConsentForAdsPersonalization,
                    hasConsentForAdStorage = consent.hasConsentForAdStorage,
                )
            } else {
                AdShiftConsent.forNonGDPRUser()
            }
        )
    }

    override fun enableTcfDataCollection(enabled: Boolean) = queued("enableTcfDataCollection") {
        AdShiftLib.enableTCFDataCollection(enabled)
    }

    override fun enableGppDataCollection(enabled: Boolean) = queued("enableGppDataCollection") {
        AdShiftLib.enableGPPDataCollection(enabled)
    }

    override fun setThirdPartySharing(optOut: Boolean) = queued("setThirdPartySharing") {
        AdShiftLib.setThirdPartySharing(
            if (optOut) AdShiftThirdPartySharing.optedOut() else AdShiftThirdPartySharing.allowed()
        )
    }

    override fun clearThirdPartySharing() = queued("clearThirdPartySharing") {
        AdShiftLib.clearThirdPartySharing()
    }

    override suspend fun refreshConsent(): ConsentSnapshotMessage? = sdk("refreshConsent", null) {
        AdShiftLib.refreshConsent().toMessage()
    }

    override suspend fun trackEvent(name: String, values: Map<String, Any?>): ErrorMessage? =
        track { listener -> AdShiftLib.trackEvent(name, values.withoutNulls(), listener) }

    override suspend fun trackPurchase(
        productId: String,
        price: Double,
        currency: String,
        token: String,
    ): ErrorMessage? =
        track { listener -> AdShiftLib.trackPurchase(productId, price, currency, token, listener) }

    /** Answers once the SDK has taken the event into its queue, or refused it. */
    private suspend fun track(call: (AdShiftRequestListener) -> Unit): ErrorMessage? {
        refusal()?.let { return it }
        val answer = CompletableDeferred<ErrorMessage?>()
        try {
            call(object : AdShiftRequestListener {
                override fun onSuccess() {
                    answer.complete(null)
                }

                override fun onError(code: Int, error: String) {
                    answer.complete(sdkError(code, error))
                }
            })
        } catch (e: Exception) {
            return thrownError(e)
        }
        return answer.await()
    }

    override suspend fun logAdRevenue(data: AdRevenueMessage): ErrorMessage? {
        refusal()?.let { return it }
        return try {
            AdShiftLib.logAdRevenue(data.toSdkData(), data.toSdkParameters())
            null
        } catch (e: Exception) {
            thrownError(e)
        }
    }

    override fun getAdShiftDeviceId(): String? = sdk("getAdShiftDeviceId", null) {
        AdShiftLib.getAdShiftDeviceId()
    }

    override suspend fun handleDeepLink(url: String): ErrorMessage? {
        val uri = Uri.parse(url)
        val scheme = uri.scheme
        val isWeb = scheme.equals("http", ignoreCase = true) || scheme.equals("https", ignoreCase = true)
        if (scheme.isNullOrEmpty() || (isWeb && uri.host.isNullOrEmpty())) {
            return ErrorMessage(ErrorCodeMessage.INVALID_ARGUMENT, "url must be an absolute URL")
        }
        refusal()?.let { return it }
        return bridge.forwardLink(this, url, uri)
    }

    /** The clipboard lookup of a deferred link exists on iOS only. */
    override fun handlePastedDeepLink(url: String?) = Unit

    override fun addPushNotificationDeepLinkPath(path: List<String>) =
        queued("addPushNotificationDeepLinkPath") { bridge.registerPushPath(path) }

    override suspend fun handlePushNotification(payload: Map<String, Any?>): Boolean =
        sdk("handlePushNotification", false) { bridge.forwardPush(this, payload) }

    /** Why this instance may not call the SDK now, or null when it may. */
    private fun refusal(): ErrorMessage? = when {
        !bridge.isOwner(this) -> notOwner()
        !bridge.sdkInitialized -> ErrorMessage(ErrorCodeMessage.NOT_INITIALIZED, "initialize() has not been called")
        else -> null
    }

    private fun notOwner() = ErrorMessage(
        ErrorCodeMessage.NOT_INITIALIZED,
        "The SDK runs only in the Flutter engine of the app's current Activity",
    )

    /**
     * For a method that answers nothing: runs [call] on the queue Flutter runs the answering
     * methods on, so that every call reaches the SDK in the order Dart made it.
     */
    private fun queued(method: String, call: () -> Unit) {
        bridge.scope.launch { sdk(method, Unit, call) }
    }

    /** Runs [call] when this instance may call the SDK; [otherwise] also stands in for a failure. */
    private inline fun <T> sdk(method: String, otherwise: T, call: () -> T): T {
        if (refusal() != null) return otherwise
        return try {
            call()
        } catch (e: Exception) {
            Log.w(AdshiftBridge.TAG, "$method failed: ${e.javaClass.simpleName}: ${e.message}")
            otherwise
        }
    }
}
