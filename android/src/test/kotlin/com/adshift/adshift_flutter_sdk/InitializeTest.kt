package com.adshift.adshift_flutter_sdk

import com.adshift.sdk.core.AdShiftLib
import io.mockk.every
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class InitializeTest : BridgeTest() {

    @Test
    fun `applies the options before forwarding an intent that arrives during initialize`() {
        val host = Host(linkIntent())
        every { AdShiftLib.setDeepLinkListener(any()) } answers {
            sdk.calls += "setDeepLinkListener"
            host.newIntent(linkIntent(OTHER_LINK))
        }

        assertNull(host.initialize())

        assertOptionsPrecedeForwarding()
        assertEquals(listOf(LINK, OTHER_LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards an intent received before initialize once the options are applied`() {
        val host = Host()
        host.newIntent(linkIntent())

        assertTrue("intent forwarded before initialize: ${sdk.calls}", forwardIndex() < 0)

        host.initialize()

        assertOptionsPrecedeForwarding()
        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `turns test mode on before forwarding an intent`() {
        val host = Host(linkIntent())

        host.initialize(options(testMode = true))

        assertTrue(
            "test mode set after the intent: ${sdk.calls}",
            sdk.calls.indexOf("setTestMode") in 0 until forwardIndex(),
        )
    }

    @Test
    fun `names the plugin right after the sdk is initialized and before start`() {
        val host = Host(linkIntent())

        host.initialize()
        dartCalls { host.plugin.start() }

        val wrapper = sdk.calls.indexOf("setWrapper")
        assertTrue("plugin not named: ${sdk.calls}", wrapper >= 0)
        assertTrue("named before initSdk: ${sdk.calls}", sdk.calls.indexOf("initSdk") in 0 until wrapper)
        assertTrue("named after an option: ${sdk.calls}", wrapper < sdk.calls.indexOf("setDebugLog"))
        assertTrue("named after an intent was forwarded: ${sdk.calls}", wrapper < forwardIndex())
        assertTrue("named after start: ${sdk.calls}", wrapper < sdk.calls.indexOf("start"))
        verify { AdShiftLib.setWrapper("flutter") }
    }

    @Test
    fun `names the plugin on every initialize`() {
        val host = Host()

        host.initialize()
        host.initialize()

        verify(exactly = 2) { AdShiftLib.setWrapper("flutter") }
    }

    @Test
    fun `forwards links when naming the plugin fails`() {
        every { AdShiftLib.setWrapper(any()) } throws IllegalStateException("not available")
        val host = Host(linkIntent())

        assertNull(host.initialize())

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `reports an sdk that could not be initialized and does not name the plugin`() {
        every { AdShiftLib.initSdk(any(), any()) } throws IllegalStateException("no context")
        val host = Host(linkIntent())

        val error = host.initialize()

        assertEquals(ErrorCodeMessage.UNKNOWN, error?.code)
        assertEquals("no context", error?.message)
        assertFalse("named without an SDK: ${sdk.calls}", sdk.calls.contains("setWrapper"))
        assertEquals(emptyList<String>(), sdk.forwardedLinks())
    }

    @Test
    fun `refuses a blank api key`() {
        val error = Host().initialize(InitializeMessage(apiKey = " "))

        assertEquals(ErrorCodeMessage.INVALID_ARGUMENT, error?.code)
        assertEquals(emptyList<String>(), sdk.calls)
    }

    @Test
    fun `applies only the options that are present`() {
        Host().initialize(InitializeMessage(apiKey = API_KEY))

        assertEquals(listOf("initSdk", "setDeepLinkListener", "setWrapper"), sdk.calls.take(3))
        assertEquals(
            "options applied: ${sdk.calls}",
            emptyList<String>(),
            sdk.calls.filter { it.startsWith("set") && it != "setDeepLinkListener" && it != "setWrapper" },
        )
        assertEquals(0, sdk.count("addPushNotificationDeepLinkPath"))
    }

    @Test
    fun `passes every option to the sdk`() {
        Host().initialize(
            InitializeMessage(
                apiKey = API_KEY,
                isDebug = false,
                appOpenDebounceMs = 3_000,
                brandedDomains = listOf(BRANDED_DOMAIN, " "),
                testMode = true,
                metaAppId = "1234567890",
                pushDeepLinkPaths = listOf(listOf("data", "link"), listOf(" "), emptyList()),
                collectOaid = false,
                disableSkan = true,
                waitForAttBeforeStart = true,
                attTimeoutMs = 30_000,
                deferredDeepLinkClipboard = ClipboardModeMessage.PROMPT,
            )
        )

        verify { AdShiftLib.setDebugLog(false) }
        verify { AdShiftLib.setAppOpenDebounceMs(3_000L) }
        verify { AdShiftLib.setBrandedDomains(listOf(BRANDED_DOMAIN)) }
        verify { AdShiftLib.setTestMode(true) }
        verify { AdShiftLib.setMetaAppId("1234567890") }
        verify { AdShiftLib.setCollectOaid(false) }
        verify(exactly = 1) { AdShiftLib.addPushNotificationDeepLinkPath("data", "link") }
        assertEquals(1, sdk.count("addPushNotificationDeepLinkPath"))
    }

    @Test
    fun `keeps a link back while the options could not be applied`() {
        every { AdShiftLib.setBrandedDomains(any()) } throws IllegalArgumentException("bad domain")
        val host = Host(linkIntent())

        val error = host.initialize()

        assertEquals(ErrorCodeMessage.INVALID_ARGUMENT, error?.code)
        assertEquals(emptyList<String>(), sdk.forwardedLinks())

        every { AdShiftLib.setBrandedDomains(any()) } answers { sdk.calls += "setBrandedDomains" }
        assertNull(host.initialize())

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `accepts initialize and start again after dart restarts`() {
        val host = Host(linkIntent())
        host.initialize(options(collectOaid = true))
        val firstStart = dartCalls { host.plugin.start() }
        sdk.startListener?.onSuccess()
        idle()
        assertTrue("first start", firstStart.value.success)

        // A hot restart: the engine, its plugin instance and the Activity stay, Dart starts over.
        assertNull(host.initialize(options(collectOaid = true)))
        val secondStart = dartCalls { host.plugin.start() }
        sdk.startListener?.onSuccess()
        idle()

        assertTrue("second start", secondStart.value.success)
        assertEquals("sdk created", 1, sdk.count("initSdk"))
        assertEquals("listener registered", 1, sdk.count("setDeepLinkListener"))
        assertEquals("oaid collection set", 1, sdk.count("setCollectOaid"))
        assertEquals("push path registered", 1, sdk.count("addPushNotificationDeepLinkPath"))
        assertEquals("options applied again", 2, sdk.count("setBrandedDomains"))
        assertEquals("the launch link counted once", listOf(LINK), sdk.forwardedLinks())
    }

    private fun assertOptionsPrecedeForwarding() {
        val forward = forwardIndex()
        assertTrue("no intent reached the SDK: ${sdk.calls}", forward >= 0)
        assertTrue(
            "branded domains applied after the intent: ${sdk.calls}",
            sdk.calls.indexOf("setBrandedDomains") in 0 until forward,
        )
        assertTrue(
            "push path registered after the intent: ${sdk.calls}",
            sdk.calls.indexOf("addPushNotificationDeepLinkPath") in 0 until forward,
        )
    }

    private fun forwardIndex(): Int =
        sdk.calls.indexOfFirst { it == "handlePushNotification" || it == "handleAppLinkIntent" }
}
