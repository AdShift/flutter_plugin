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

    /**
     * Runs on the main thread, each block in a later turn of it and in the order launched. It is
     * the queue Flutter puts the bridge methods on that answer later.
     */
    val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    var sdkInitialized = false
        private set

    private var listenerRegistered = false
    private var collectOaidApplied = false
    private val registeredPushPaths = HashSet<String>()

    /** False until `initialize` has applied its options; no Intent reaches the SDK before that. */
    private var optionsApplied = false
    private var autoHandleDeepLinks = true

    /** The instances attached to an Activity; the one whose Activity started last comes last. */
    private val attached = ArrayList<AdshiftFlutterSdkPlugin>()

    /** The Intents handed to the SDK, each with whether the SDK took a notification's link from it. */
    private val forwardedIntents = WeakHashMap<Intent, Boolean>()

    /** By [linkKey], the links the SDK took from Intents in the last two seconds, with the time of each. */
    private val autoForwardedLinks = HashMap<String, Long>()

    private val heldResults = ArrayDeque<DeepLinkResult>()

    /**
     * Only the instance whose Activity started last, the one the user sees, may call the SDK and
     * gets its results.
     */
    fun isOwner(plugin: AdshiftFlutterSdkPlugin): Boolean = attached.lastOrNull() === plugin

    /** The Activity of [plugin] was attached, or has started again. */
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
     * save would be re-created from it and count the same link a second time. The same goes for
     * the launch Intent's link when the app passed it itself meanwhile.
     */
    fun forwardWaitingIntents(plugin: AdshiftFlutterSdkPlugin) {
        val intents = plugin.intents ?: return
        if (!optionsApplied || intents.stateSaved) return
        val waiting = intents.waiting()
        intents.waitingIntent = null
        if (autoHandleDeepLinks) {
            for (intent in waiting) {
                forward(intent)?.let { pushAccepted -> intents.forwarded(intent, pushAccepted) }
            }
        }
        val link = intents.deferredLaunchLink ?: return
        intents.deferredLaunchLink = null
        try {
            AdShiftLib.handleAppLinkIntent(Intent(Intent.ACTION_VIEW, link))
            intents.launchLinkPassed()
        } catch (e: Exception) {
            Log.w(TAG, "Link not processed: ${e.javaClass.simpleName}")
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

    /**
     * Hands the SDK a link the app passed itself, unless the link is counted with an Intent. The
     * link the Activity was opened with waits, like the Intent itself, while the Activity's state
     * is saved and the Activity has not started again.
     */
    fun forwardLink(plugin: AdshiftFlutterSdkPlugin, url: String, uri: Uri): ErrorMessage? {
        val key = linkKey(url)
        if (countedWithAnIntent(plugin, key)) return null
        val launch = plugin.intents?.takeIf { it.opensWith(key) }
        if (launch != null && launch.stateSaved) {
            launch.deferredLaunchLink = uri
            return null
        }
        return try {
            AdShiftLib.handleAppLinkIntent(Intent(Intent.ACTION_VIEW, uri))
            launch?.launchLinkPassed()
            null
        } catch (e: Exception) {
            thrownError(e)
        }
    }

    /**
     * Hands the SDK a notification payload the app passed itself, unless the SDK has the
     * notification, or will get it, with its Intent: one of the payload's links is among those the
     * SDK took from the extras of an Intent of the Activity, or is in the extras of one that waits.
     * A link that was only the data of an Intent says nothing about a notification.
     */
    fun forwardPush(plugin: AdshiftFlutterSdkPlugin, payload: Map<String, Any?>): Boolean {
        val intents = plugin.intents
        if (intents != null) {
            val waitingLinks = waitingToBeForwarded(intents).flatMap(::extrasLinkKeys)
            val counted = payloadLinkKeys(payload).any { intents.hasNotificationLink(it) || it in waitingLinks }
            if (counted) return true
        }
        return AdShiftLib.handlePushNotification(payload)
    }

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
        return intents.hasLink(key) || waitingToBeForwarded(intents).any { key in carriedLinkKeys(it) }
    }

    /** The Intents of the Activity that wait and will be forwarded; none when the app handles deep links itself. */
    private fun waitingToBeForwarded(intents: ActivityIntents): List<Intent> =
        if (autoHandleDeepLinks && (!optionsApplied || intents.stateSaved)) {
            intents.waiting().filterNot { it.isRelaunch }
        } else {
            emptyList()
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
        const val REMEMBERED_LINK_LIMIT = 100
    }

    /** Whether the SDK has [launchIntent], from this Activity or the one it was re-created from. */
    var launchForwarded = false
        private set

    /** Whether the SDK took a notification's link from the extras of [launchIntent]. */
    var launchPushAccepted = false
        private set

    /** The latest Intent the running Activity received that the SDK does not have yet. */
    var waitingIntent: Intent? = null

    /** The link of [launchIntent], passed by the app while [stateSaved] and not handed over yet. */
    var deferredLaunchLink: Uri? = null

    /** Whether the Activity's state was saved and the Activity has not started again since. */
    var stateSaved = false

    private var followedByNewIntent = false

    /** By [linkKey], the links the SDK has as the data of this Activity's Intents; the latest of them. */
    private val dataLinks = LinkedHashSet<String>()

    /** By [linkKey], the links in the extras of the Intents the SDK took a notification's link from. */
    private val notificationLinks = LinkedHashSet<String>()

    init {
        // A relaunch from Recents repeats an earlier open, whose links were counted then.
        if (launchIntent?.isRelaunch == true) {
            dataLinkKey(launchIntent)?.let { dataLinks += it }
            notificationLinks += extrasLinkKeys(launchIntent)
        }
    }

    /** The Intents the SDK does not have yet, in the order they arrived. */
    fun waiting(): List<Intent> =
        listOfNotNull(launchIntent.takeUnless { launchForwarded }, waitingIntent)

    /** Whether [key] is the link the Activity was opened with and no Intent has arrived since. */
    fun opensWith(key: String): Boolean =
        !followedByNewIntent && launchIntent?.let(::dataLinkKey) == key

    /** The running Activity received [intent], which carries [links]. */
    fun received(intent: Intent, links: Set<String>) {
        followedByNewIntent = true
        waitingIntent = intent
        dataLinks.removeAll(links)
        notificationLinks.removeAll(links)
    }

    /** The SDK was handed [intent]. It reads an app link from a view Intent only. */
    fun forwarded(intent: Intent, pushAccepted: Boolean) {
        if (intent === launchIntent) launchForwarded = true
        if (intent.action == Intent.ACTION_VIEW) dataLinkKey(intent)?.let { remember(dataLinks, listOf(it)) }
        if (pushAccepted) notificationTaken(intent)
    }

    /** What the SDK has from [launchIntent] by the saved state the Activity was re-created from. */
    fun restored(forwarded: Boolean, pushAccepted: Boolean) {
        val launch = launchIntent ?: return
        if (forwarded) forwarded(launch, pushAccepted = false)
        if (pushAccepted) notificationTaken(launch)
    }

    private fun notificationTaken(intent: Intent) {
        if (intent === launchIntent) launchPushAccepted = true
        remember(notificationLinks, extrasLinkKeys(intent))
    }

    /** The SDK has the link the Activity was opened with: the app passed it itself. */
    fun launchLinkPassed() {
        launchForwarded = true
        if (!followedByNewIntent) launchIntent?.let(::dataLinkKey)?.let { remember(dataLinks, listOf(it)) }
    }

    /** Whether the SDK has the link from one of this Activity's Intents. */
    fun hasLink(key: String): Boolean = key in dataLinks || key in notificationLinks

    /** Whether the link was in the extras of an Intent the SDK took a notification's link from. */
    fun hasNotificationLink(key: String): Boolean = key in notificationLinks

    private fun remember(links: LinkedHashSet<String>, keys: Collection<String>) {
        links += keys
        while (links.size > REMEMBERED_LINK_LIMIT) links.remove(links.first())
    }
}
