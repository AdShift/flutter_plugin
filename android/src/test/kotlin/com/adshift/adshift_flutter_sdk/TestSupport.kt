package com.adshift.adshift_flutter_sdk

import android.app.Activity
import android.app.Application
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import com.adshift.sdk.core.AdShiftLib
import com.adshift.sdk.core.AdShiftRequestListener
import com.adshift.sdk.core.ConsentSnapshot
import com.adshift.sdk.core.ConsentSource
import com.adshift.sdk.core.deeplink.DeepLinkListener
import com.adshift.sdk.core.deeplink.DeepLinkResult
import com.adshift.sdk.core.deeplink.DeepLinkStatus
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.mockk.every
import io.mockk.mockk
import io.mockk.mockkStatic
import io.mockk.unmockkStatic
import java.lang.reflect.Modifier
import java.nio.ByteBuffer
import java.time.Duration
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.junit.After
import org.junit.Before
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf

const val API_KEY = "test-api-key"
const val BRANDED_DOMAIN = "links.example.com"
const val PUSH_LINK_KEY = "as_push_link"
const val LINK = "https://$BRANDED_DOMAIN/promo?id=42"
const val OTHER_LINK = "https://$BRANDED_DOMAIN/other?id=7"

/** Each test starts in a new process, with a stand-in for the native SDK. */
@RunWith(RobolectricTestRunner::class)
abstract class BridgeTest {

    val sdk = FakeSdk()

    @Before
    fun startProcess() {
        killProcess()
        sdk.install()
    }

    @After
    fun endProcess() {
        sdk.uninstall()
        killProcess()
    }
}

/** As when Android kills the process: what the plugin keeps in memory goes. */
fun killProcess() {
    val type = AdshiftBridge::class.java
    val fresh = type.getDeclaredConstructor().apply { isAccessible = true }.newInstance()
    type.declaredFields.filterNot { Modifier.isStatic(it.modifiers) }.forEach { field ->
        field.isAccessible = true
        field.set(AdshiftBridge.shared, field.get(fresh))
    }
}

/** Runs what is queued on the main thread. */
fun idle() = shadowOf(Looper.getMainLooper()).idle()

/** Lets [duration] pass, running what falls due on the main thread. */
fun wait(duration: Duration) = shadowOf(Looper.getMainLooper()).idleFor(duration)

/** Past the two seconds in which a link from any Intent and the same link from the app count once. */
fun waitOutDedupWindow() = wait(Duration.ofMillis(2_001))

fun options(
    autoHandleDeepLinks: Boolean? = null,
    testMode: Boolean? = null,
    collectOaid: Boolean? = null,
) = InitializeMessage(
    apiKey = API_KEY,
    isDebug = true,
    brandedDomains = listOf(BRANDED_DOMAIN),
    pushDeepLinkPaths = listOf(listOf(PUSH_LINK_KEY)),
    autoHandleDeepLinks = autoHandleDeepLinks,
    testMode = testMode,
    collectOaid = collectOaid,
)

fun linkIntent(url: String = LINK) = Intent(Intent.ACTION_VIEW, Uri.parse(url))

fun launcherIntent() = Intent(Intent.ACTION_MAIN).apply { addCategory(Intent.CATEGORY_LAUNCHER) }

/** A launcher start carrying a notification payload, as a tapped notification delivers it. */
fun notificationIntent(link: String) = launcherIntent().apply {
    putExtra(PUSH_LINK_KEY, link)
    putExtra("google.message_id", "0:1757600000000000%abcdef")
}

fun deepLinkResult(url: String, isDeferred: Boolean = false) = DeepLinkResult(
    uri = Uri.parse(url),
    isDeferred = isDeferred,
    status = DeepLinkStatus.FOUND,
)

/** Stands in for the native SDK and records what reaches it. */
class FakeSdk {

    /** The names of the SDK functions called, in order. */
    val calls = mutableListOf<String>()

    /** The data of each Intent handed over as an app link. */
    val links = mutableListOf<String?>()

    /** The extras of each Intent handed over as a tapped notification. */
    val pushExtras = mutableListOf<Bundle?>()

    /** The extras keys the SDK finds a notification's link under. */
    val pushLinkKeys = mutableSetOf(PUSH_LINK_KEY)

    /** The notification payloads the app passed itself. */
    val pushPayloads = mutableListOf<Map<String, Any?>>()

    var deepLinkListener: DeepLinkListener? = null
    var startListener: AdShiftRequestListener? = null
    var trackListener: AdShiftRequestListener? = null

    fun install() {
        mockkStatic(AdShiftLib::class)
        every { AdShiftLib.initSdk(any(), any()) } answers { calls += "initSdk" }
        every { AdShiftLib.setDeepLinkListener(any()) } answers {
            calls += "setDeepLinkListener"
            deepLinkListener = firstArg()
        }
        every { AdShiftLib.setWrapper(any()) } answers { calls += "setWrapper" }
        every { AdShiftLib.setDebugLog(any()) } answers { calls += "setDebugLog" }
        every { AdShiftLib.setAppOpenDebounceMs(any()) } answers { calls += "setAppOpenDebounceMs" }
        every { AdShiftLib.setCollectOaid(any()) } answers { calls += "setCollectOaid" }
        every { AdShiftLib.setBrandedDomains(any()) } answers { calls += "setBrandedDomains" }
        every { AdShiftLib.setTestMode(any()) } answers { calls += "setTestMode" }
        every { AdShiftLib.setMetaAppId(any()) } answers { calls += "setMetaAppId" }
        every { AdShiftLib.addPushNotificationDeepLinkPath(*anyVararg()) } answers {
            calls += "addPushNotificationDeepLinkPath"
        }
        every { AdShiftLib.handlePushNotification(any<Bundle>()) } answers {
            calls += "handlePushNotification"
            val extras = firstArg<Bundle?>()
            pushExtras += extras
            pushLinkKeys.any { extras?.containsKey(it) == true }
        }
        every { AdShiftLib.handlePushNotification(any<Map<String, Any?>>()) } answers {
            calls += "handlePushNotification"
            pushPayloads += firstArg<Map<String, Any?>>()
            true
        }
        every { AdShiftLib.handleAppLinkIntent(any()) } answers {
            calls += "handleAppLinkIntent"
            links += firstArg<Intent?>()?.dataString
        }
        every { AdShiftLib.start(any()) } answers {
            calls += "start"
            startListener = firstArg()
        }
        every { AdShiftLib.stop() } answers { calls += "stop" }
        every { AdShiftLib.setCustomerUserId(any()) } answers { calls += "setCustomerUserId" }
        every { AdShiftLib.setOaidData(any()) } answers { calls += "setOaidData" }
        every { AdShiftLib.setConsentData(any()) } answers { calls += "setConsentData" }
        every { AdShiftLib.enableTCFDataCollection(any()) } answers { calls += "enableTCFDataCollection" }
        every { AdShiftLib.enableGPPDataCollection(any()) } answers { calls += "enableGPPDataCollection" }
        every { AdShiftLib.setThirdPartySharing(any()) } answers { calls += "setThirdPartySharing" }
        every { AdShiftLib.clearThirdPartySharing() } answers { calls += "clearThirdPartySharing" }
        every { AdShiftLib.refreshConsent(any(), any()) } answers {
            calls += "refreshConsent"
            ConsentSnapshot(ConsentSource.NONE, null, false, false, null, null, null, 0L)
        }
        every { AdShiftLib.trackEvent(any(), any(), any()) } answers {
            calls += "trackEvent"
            trackListener = thirdArg()
        }
        every { AdShiftLib.trackPurchase(any(), any(), any(), any(), any()) } answers {
            calls += "trackPurchase"
            trackListener = arg(4)
        }
        every { AdShiftLib.logAdRevenue(any(), any()) } answers { calls += "logAdRevenue" }
        every { AdShiftLib.getAdShiftDeviceId() } answers {
            calls += "getAdShiftDeviceId"
            "device-id"
        }
    }

    fun uninstall() = unmockkStatic(AdShiftLib::class)

    /** The links handed over, without the Intents that carried none. */
    fun forwardedLinks(): List<String> = links.filterNotNull()

    fun count(call: String): Int = calls.count { it == call }
}

/** The Dart side of an engine: receives deep link results and calls the bridge. */
class FakeDart : BinaryMessenger {

    private val handlers = HashMap<String, BinaryMessenger.BinaryMessageHandler>()

    val deepLinks = mutableListOf<DeepLinkMessage>()

    val links: List<String?> get() = deepLinks.map { it.deepLink }

    /** Calls a bridge method through its channel, as Dart does. */
    fun call(method: String, vararg arguments: Any?) {
        val message = AdshiftHostApi.codec.encodeMessage(arguments.toList())!!
        message.flip()
        handlers.getValue("dev.flutter.pigeon.adshift_flutter_sdk.AdshiftHostApi.$method").onMessage(message) {}
    }

    override fun send(channel: String, message: ByteBuffer?) = send(channel, message, null)

    override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {
        message!!.flip()
        val arguments = AdshiftFlutterApi.codec.decodeMessage(message) as List<*>
        deepLinks += arguments.single() as DeepLinkMessage
        val reply = AdshiftFlutterApi.codec.encodeMessage(listOf(null))!!
        reply.flip()
        callback?.reply(reply)
    }

    override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
        if (handler == null) handlers.remove(channel) else handlers[channel] = handler
    }
}

/** An Activity with its own Flutter engine, driven the way `FlutterActivity` drives a plugin. */
class Host(intent: Intent? = launcherIntent(), savedState: Bundle? = null, restoresState: Boolean = true) {

    val dart = FakeDart()
    val plugin = AdshiftFlutterSdkPlugin()

    /** What the plugin watches the Activity's starts with, while it does. */
    var watcher: Application.ActivityLifecycleCallbacks? = null
        private set

    private val engine = engineBinding(dart)
    private val application = mockk<Application>(relaxed = true)
    private val activity = mockk<Activity>(relaxed = true)
    private val binding = mockk<ActivityPluginBinding>(relaxed = true)

    init {
        every { application.registerActivityLifecycleCallbacks(any()) } answers { watcher = firstArg() }
        every { application.unregisterActivityLifecycleCallbacks(any()) } answers { watcher = null }
        every { activity.application } returns application
        every { activity.intent } returns intent
        every { activity.applicationContext } returns ApplicationProvider.getApplicationContext<Context>()
        every { binding.activity } returns activity
        plugin.onAttachedToEngine(engine)
        plugin.onAttachedToActivity(binding)
        if (restoresState) plugin.onRestoreInstanceState(savedState)
    }

    fun initialize(options: InitializeMessage = options()): ErrorMessage? = plugin.initialize(options)

    /** An Intent delivered to the running Activity, such as a link tapped while the app is open. */
    fun newIntent(intent: Intent) {
        plugin.onNewIntent(intent)
    }

    /** The Activity leaves the screen. Returns the state the system keeps to re-create it from. */
    fun stop(): Bundle = Bundle().also(plugin::onSaveInstanceState)

    /** The user returns to the Activity. */
    fun start() {
        watcher?.onActivityStarted(activity)
        watcher?.onActivityResumed(activity)
    }

    /** A configuration change: the system re-creates the Activity with [intent], the engine stays. */
    fun recreateActivity(intent: Intent) {
        val state = stop()
        plugin.onDetachedFromActivityForConfigChanges()
        every { activity.intent } returns intent
        plugin.onReattachedToActivityForConfigChanges(binding)
        plugin.onRestoreInstanceState(state)
    }

    /** The Activity is closed for good, for example with Back, and its engine goes with it. */
    fun finish() {
        plugin.onDetachedFromActivity()
        plugin.onDetachedFromEngine(engine)
    }

    /** Android kills the process in the background, then re-creates the Activity with [intent]. */
    fun recreatedInNewProcess(intent: Intent): Host {
        val state = stop()
        killProcess()
        return Host(intent, state)
    }
}

/** An engine without an Activity, such as one that runs Dart for a background message. */
class BackgroundEngine {
    val dart = FakeDart()
    val plugin = AdshiftFlutterSdkPlugin().also { it.onAttachedToEngine(engineBinding(dart)) }
}

private fun engineBinding(dart: FakeDart): FlutterPlugin.FlutterPluginBinding =
    mockk<FlutterPlugin.FlutterPluginBinding>(relaxed = true).also {
        every { it.binaryMessenger } returns dart
    }

/** The answer of a bridge method that Flutter runs in a later turn of the main thread. */
class Answer<T> {
    var count = 0
        private set

    private var answer: T? = null

    val value: T
        get() {
            check(count > 0) { "not answered yet" }
            @Suppress("UNCHECKED_CAST")
            return answer as T
        }

    fun set(value: T) {
        answer = value
        count++
    }
}

/** Calls an asynchronous bridge method as Flutter does and runs it up to where it waits. */
fun <T> dartCalls(call: suspend () -> T): Answer<T> {
    val answer = Answer<T>()
    CoroutineScope(Dispatchers.Main).launch { answer.set(call()) }
    idle()
    return answer
}
