package com.adshift.adshift_flutter_sdk

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.adshift.sdk.core.AdShiftLib
import com.adshift.sdk.core.deeplink.DeepLinkListener
import com.adshift.sdk.core.deeplink.DeepLinkResult
import java.util.WeakHashMap
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

/**
 * What the plugin keeps per process: the native SDK is created once, while Flutter engines and
 * their plugin instances come and go. Used on the main thread only, where Flutter calls plugins.
 */
internal class AdshiftBridge private constructor() {

    companion object {
        const val TAG = "AdShiftFlutter"

        val shared = AdshiftBridge()

        private const val WRAPPER = "flutter"
        private const val AUTO_FORWARD_DEDUP_WINDOW_MS = 2_000L
        private const val HELD_RESULT_LIMIT = 20
    }

    /** Runs on the main thread, each block in a later turn of it and in the order launched. */
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    var sdkInitialized = false
        private set

    private var listenerRegistered = false
    private var collectOaidApplied = false
    private val registeredPushPaths = HashSet<String>()

    /** False until `initialize` has applied its options; no Intent reaches the SDK before that. */
    private var optionsApplied = false
    private var autoHandleDeepLinks = true

    /** The instances attached to an Activity, the latest last. */
    private val attached = ArrayList<AdshiftFlutterSdkPlugin>()

    /** The Intents handed to the SDK, each with whether the SDK took a notification's link from it. */
    private val forwardedIntents = WeakHashMap<Intent, Boolean>()

    /** By [linkKey], the links the SDK took from Intents in the last two seconds, with the time of each. */
    private val autoForwardedLinks = HashMap<String, Long>()

    private val heldResults = ArrayDeque<DeepLinkResult>()

    /** Only the instance attached to an Activity last may call the SDK and gets its results. */
    fun isOwner(plugin: AdshiftFlutterSdkPlugin): Boolean = attached.lastOrNull() === plugin

    fun attach(plugin: AdshiftFlutterSdkPlugin) {
        attached.remove(plugin)
        attached.add(plugin)
        sendHeldResults()
    }

    fun detach(plugin: AdshiftFlutterSdkPlugin) {
        attached.remove(plugin)
        sendHeldResults()
    }

    /**
     * Creates the SDK on the first call. Every call applies [options] and then lets through the
     * Intents that waited for them, so that a link is read with the app's domains and push paths.
     */
    fun initialize(options: InitializeMessage, context: Context): ErrorMessage? {
        if (options.apiKey.isBlank()) {
            return ErrorMessage(ErrorCodeMessage.INVALID_ARGUMENT, "apiKey is required")
        }
        try {
            if (!sdkInitialized) {
                AdShiftLib.initSdk(context, options.apiKey)
                sdkInitialized = true
            }
            if (!listenerRegistered) {
                AdShiftLib.setDeepLinkListener(object : DeepLinkListener {
                    override fun onDeepLinking(result: DeepLinkResult) = onMainThread { deliver(result) }
                })
                listenerRegistered = true
            }
        } catch (e: Exception) {
            return thrownError(e)
        }
        // On its own: a failure here must not keep the options and the links from the SDK.
        try {
            AdShiftLib.setWrapper(WRAPPER)
        } catch (e: Exception) {
            Log.w(TAG, "setWrapper failed: ${e.javaClass.simpleName}")
        }
        try {
            apply(options)
        } catch (e: Exception) {
            return thrownError(e)
        }
        autoHandleDeepLinks = options.autoHandleDeepLinks ?: true
        optionsApplied = true
        attached.forEach(::forwardWaitingIntents)
        return null
    }

    private fun apply(options: InitializeMessage) {
        options.isDebug?.let { AdShiftLib.setDebugLog(it) }
        options.appOpenDebounceMs?.let { AdShiftLib.setAppOpenDebounceMs(it) }
        options.collectOaid?.let {
            if (!collectOaidApplied) {
                AdShiftLib.setCollectOaid(it)
                collectOaidApplied = true
            }
        }
        options.brandedDomains?.let { AdShiftLib.setBrandedDomains(it.withoutBlanks()) }
        options.testMode?.let { AdShiftLib.setTestMode(it) }
        options.metaAppId?.takeIf { it.isNotBlank() }?.let { AdShiftLib.setMetaAppId(it) }
        options.pushDeepLinkPaths?.forEach { registerPushPath(it) }
    }

    /** Registers a push payload key path once per process; a path without keys is ignored. */
    fun registerPushPath(path: List<String>) {
        val keys = path.withoutBlanks()
        if (keys.isEmpty()) return
        val id = keys.joinToString("\u001F")
        if (!registeredPushPaths.add(id)) return
        try {
            AdShiftLib.addPushNotificationDeepLinkPath(*keys.toTypedArray())
        } catch (e: Exception) {
            registeredPushPaths.remove(id)
            throw e
        }
    }

    /**
     * An Intent the Activity of [plugin] received while running. It is a new tap: its links count
     * again, also when an earlier Intent carried them. Of the Intents that wait, the latest is kept.
     */
    fun onNewIntent(plugin: AdshiftFlutterSdkPlugin, intent: Intent) {
        val intents = plugin.intents ?: return
        val links = carriedLinkKeys(intent)
        autoForwardedLinks.keys.removeAll(links)
        intents.received(intent, links)
        forwardWaitingIntents(plugin)
    }

    /**
     * Hands the SDK the Intents of the Activity of [plugin] that it does not have yet: the one the
     * Activity was created with, then the latest it received. They wait for `initialize`. They
     * also wait while the Activity's state is saved and the Activity has not started again: that
     * state says the SDK does not have the launch Intent, and a process killed before the next
     * save would be re-created from it and count the same link a second time.
     */
    fun forwardWaitingIntents(plugin: AdshiftFlutterSdkPlugin) {
        val intents = plugin.intents ?: return
        if (!optionsApplied || intents.stateSaved) return
        val waiting = intents.waiting()
        intents.waitingIntent = null
        if (!autoHandleDeepLinks) return
        for (intent in waiting) {
            forward(intent)?.let { pushAccepted -> intents.forwarded(intent, pushAccepted) }
        }
    }

    /**
     * Hands [intent] to the SDK, each Intent once. Returns whether the SDK took a notification's
     * link from its extras, or null for a relaunch from Recents, which is not handed over.
     */
    private fun forward(intent: Intent): Boolean? {
        if (intent.isRelaunch) return null
        forwardedIntents[intent]?.let { return it }
        var pushAccepted = false
        try {
            pushAccepted = AdShiftLib.handlePushNotification(intent.extras)
            AdShiftLib.handleAppLinkIntent(intent)
        } catch (e: Exception) {
            Log.w(TAG, "Intent not processed: ${e.javaClass.simpleName}")
        }
        forwardedIntents[intent] = pushAccepted
        val now = SystemClock.elapsedRealtime()
        autoForwardedLinks.values.removeAll { now - it > AUTO_FORWARD_DEDUP_WINDOW_MS }
        takenLinkKeys(intent, pushAccepted).forEach { autoForwardedLinks[it] = now }
        return pushAccepted
    }

    /** Hands the SDK a link the app passed itself, unless the link is counted with an Intent. */
    fun forwardLink(plugin: AdshiftFlutterSdkPlugin, url: String, uri: Uri): ErrorMessage? {
        val key = linkKey(url)
        if (countedWithAnIntent(plugin, key)) return null
        return try {
            AdShiftLib.handleAppLinkIntent(Intent(Intent.ACTION_VIEW, uri))
            plugin.intents?.passedByApp(key)
            null
        } catch (e: Exception) {
            thrownError(e)
        }
    }

    /**
     * Hands the SDK a notification payload the app passed itself, unless a link in it is counted
     * with an Intent: the notification's own, which the SDK already took the link from.
     */
    fun forwardPush(plugin: AdshiftFlutterSdkPlugin, payload: Map<String, Any?>): Boolean =
        payloadLinkKeys(payload).any { countedWithAnIntent(plugin, it) } ||
            AdShiftLib.handlePushNotification(payload)

    /**
     * Whether the SDK has the link, or will get it, with an Intent: one it took the link from in
     * the last two seconds, one of the Activity of [plugin] at any time, or one that still waits
     * to be forwarded. A new tap arrives as a new Intent, so the app passing such a link itself is
     * the same tap once more.
     */
    private fun countedWithAnIntent(plugin: AdshiftFlutterSdkPlugin, key: String): Boolean {
        val forwardedAt = autoForwardedLinks[key]
        if (forwardedAt != null &&
            SystemClock.elapsedRealtime() - forwardedAt <= AUTO_FORWARD_DEDUP_WINDOW_MS
        ) {
            return true
        }
        val intents = plugin.intents ?: return false
        if (intents.hasCounted(key)) return true
        val waitingIsForwarded = autoHandleDeepLinks && (!optionsApplied || intents.stateSaved)
        return waitingIsForwarded &&
            intents.waiting().any { !it.isRelaunch && key in carriedLinkKeys(it) }
    }

    /** Sends [result] to the Dart side that owns the SDK, or holds it until that side listens. */
    private fun deliver(result: DeepLinkResult) {
        if (attached.lastOrNull()?.send(result) != true) hold(result)
    }

    /**
     * Keeps [result] for the next listener. When full, the oldest direct result makes room; a
     * deferred result is given up only for another deferred one.
     */
    private fun hold(result: DeepLinkResult) {
        if (heldResults.size >= HELD_RESULT_LIMIT) {
            val oldestDirect = heldResults.indexOfFirst { !it.isDeferred }
            when {
                oldestDirect >= 0 -> heldResults.removeAt(oldestDirect)
                result.isDeferred -> heldResults.removeFirst()
                else -> return
            }
        }
        heldResults.addLast(result)
    }

    fun sendHeldResults() {
        if (heldResults.isEmpty()) return
        val results = heldResults.toList()
        heldResults.clear()
        results.forEach(::deliver)
    }

    private fun onMainThread(block: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) block() else scope.launch { block() }
    }

    private fun List<String>.withoutBlanks(): List<String> = filter { it.isNotBlank() }
}

/**
 * The Intents of the Activity a plugin instance is attached to. The system hands [launchIntent],
 * the one the Activity was created with, over again when it re-creates the Activity, so the plugin
 * keeps what the SDK has from it in the Activity's saved state.
 */
internal class ActivityIntents(val launchIntent: Intent?) {

    private companion object {
        const val COUNTED_LINK_LIMIT = 100
    }

    /** Whether the SDK has [launchIntent], from this Activity or the one it was re-created from. */
    var launchForwarded = false
        private set

    /** Whether the SDK took a notification's link from the extras of [launchIntent]. */
    var launchPushAccepted = false
        private set

    /** The latest Intent the running Activity received that the SDK does not have yet. */
    var waitingIntent: Intent? = null

    /** Whether the Activity's state was saved and the Activity has not started again since. */
    var stateSaved = false

    private var followedByNewIntent = false

    /** By [linkKey], the links the SDK has from this Activity's Intents; the latest of them. */
    private val countedLinks = LinkedHashSet<String>()

    init {
        // A relaunch from Recents repeats an earlier open, whose links were counted then.
        if (launchIntent?.isRelaunch == true) count(carriedLinkKeys(launchIntent))
    }

    /** The Intents the SDK does not have yet, in the order they arrived. */
    fun waiting(): List<Intent> =
        listOfNotNull(launchIntent.takeUnless { launchForwarded }, waitingIntent)

    /** The running Activity received [intent], which carries [links]. */
    fun received(intent: Intent, links: Set<String>) {
        followedByNewIntent = true
        waitingIntent = intent
        countedLinks.removeAll(links)
    }

    /** The SDK was handed [intent], now or before the Activity was re-created. */
    fun forwarded(intent: Intent, pushAccepted: Boolean) {
        if (intent === launchIntent) {
            launchForwarded = true
            launchPushAccepted = pushAccepted
        }
        count(takenLinkKeys(intent, pushAccepted))
    }

    /** The app passed a link itself: when it is the one the Activity was opened with, the SDK has it now. */
    fun passedByApp(key: String) {
        if (followedByNewIntent || launchIntent?.let(::dataLinkKey) != key) return
        launchForwarded = true
        count(listOf(key))
    }

    fun hasCounted(key: String): Boolean = key in countedLinks

    private fun count(keys: Collection<String>) {
        countedLinks += keys
        while (countedLinks.size > COUNTED_LINK_LIMIT) countedLinks.remove(countedLinks.first())
    }
}
