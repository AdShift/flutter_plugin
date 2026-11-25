package com.adshift.adshift_flutter_sdk

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test

/** Only the engine attached to an Activity drives the SDK; the latest one when there are several. */
class OwnerEngineTest : BridgeTest() {

    @Test
    fun `refuses initialize from an engine without an activity`() {
        val error = BackgroundEngine().plugin.initialize(options())

        assertEquals(ErrorCodeMessage.NOT_INITIALIZED, error?.code)
        assertEquals("calls that reached the SDK", emptyList<String>(), sdk.calls)
    }

    @Test
    fun `keeps every call of a background engine from the sdk the app has running`() {
        val host = Host().also { it.initialize() }
        val reachedByTheApp = sdk.calls.toList()
        val background = BackgroundEngine().plugin

        val start = dartCalls { background.start() }
        val event = dartCalls { background.trackEvent("as_login", emptyMap()) }
        val purchase = dartCalls { background.trackPurchase("sku", 1.0, "USD", "token") }
        val revenue = dartCalls {
            background.logAdRevenue(AdRevenueMessage("admob", "google_admob", "USD", 0.01))
        }
        val link = dartCalls { background.handleDeepLink(LINK) }
        background.initialize(options())
        background.stop()
        background.setCustomerUserId("user-1")
        background.setDebugEnabled(true)
        background.setAppOpenDebounceMs(1_000)
        background.setBrandedDomains(listOf(BRANDED_DOMAIN))
        background.setMetaAppId("1234567890")
        background.setOaidData("oaid")
        background.setConsentData(ConsentMessage(isUserSubjectToGdpr = false))
        background.enableTcfDataCollection(true)
        background.enableGppDataCollection(true)
        background.setThirdPartySharing(true)
        background.clearThirdPartySharing()
        background.addPushNotificationDeepLinkPath(listOf("data", "link"))
        background.handlePastedDeepLink(LINK)
        idle()

        assertFalse("start", start.value.success)
        assertEquals(ErrorCodeMessage.NOT_INITIALIZED, start.value.error?.code)
        assertEquals(ErrorCodeMessage.NOT_INITIALIZED, event.value?.code)
        assertEquals(ErrorCodeMessage.NOT_INITIALIZED, purchase.value?.code)
        assertEquals(ErrorCodeMessage.NOT_INITIALIZED, revenue.value?.code)
        assertEquals(ErrorCodeMessage.NOT_INITIALIZED, link.value?.code)
        assertNull("consent", dartCalls { background.refreshConsent() }.value)
        assertNull("device id", background.getAdShiftDeviceId())
        assertFalse("push", dartCalls { background.handlePushNotification(mapOf(PUSH_LINK_KEY to LINK)) }.value)
        assertEquals("calls that reached the SDK", reachedByTheApp, sdk.calls)

        dartCalls { host.plugin.start() }
        assertEquals("starts by the app's engine", 1, sdk.count("start"))
    }

    @Test
    fun `sends results to the engine that owns the sdk only`() {
        val host = Host().also { it.initialize() }
        val background = BackgroundEngine()
        background.plugin.deepLinkListenerReady()

        sdk.deepLinkListener?.onDeepLinking(deepLinkResult(LINK))
        assertEquals("sent before the app listens", emptyList<String>(), host.dart.links)
        host.plugin.deepLinkListenerReady()

        assertEquals(emptyList<String>(), background.dart.links)
        assertEquals(listOf(LINK), host.dart.links)
    }

    @Test
    fun `makes the engine attached last the owner, and the earlier one again when that goes`() {
        val first = Host().also { it.initialize() }
        first.plugin.deepLinkListenerReady()

        val second = Host()
        val event = dartCalls { first.plugin.trackEvent("as_login", emptyMap()) }
        assertEquals(ErrorCodeMessage.NOT_INITIALIZED, event.value?.code)
        assertNull("device id in the earlier engine", first.plugin.getAdShiftDeviceId())
        assertEquals("device-id", second.plugin.getAdShiftDeviceId())

        sdk.deepLinkListener?.onDeepLinking(deepLinkResult(LINK))
        assertEquals("sent to the earlier engine", emptyList<String>(), first.dart.links)

        second.finish()

        assertEquals("device-id", first.plugin.getAdShiftDeviceId())
        assertEquals(listOf(LINK), first.dart.links)
        assertEquals(emptyList<String>(), second.dart.links)
    }

    @Test
    fun `follows the activity the user goes back to`() {
        // A link opened from another app starts a second Activity, with an engine of its own.
        val first = Host().also { it.initialize() }
        first.plugin.deepLinkListenerReady()
        val second = Host(linkIntent()).also { it.initialize() }
        second.plugin.deepLinkListenerReady()

        first.start()
        val event = dartCalls { first.plugin.trackEvent("as_login", emptyMap()) }
        sdk.trackListener?.onSuccess()
        idle()
        sdk.deepLinkListener?.onDeepLinking(deepLinkResult(OTHER_LINK))

        assertNull("error for the activity on screen", event.value)
        assertEquals("results in the activity on screen", listOf<String?>(OTHER_LINK), first.dart.links)
        assertEquals("results in the hidden activity", emptyList<String?>(), second.dart.links)
        assertNull("device id in the hidden activity", second.plugin.getAdShiftDeviceId())

        second.start()

        assertEquals("device-id", second.plugin.getAdShiftDeviceId())
        assertNull("device id in the activity left again", first.plugin.getAdShiftDeviceId())
    }

    @Test
    fun `hands a result held for a hidden activity to the one the user goes back to`() {
        val first = Host().also { it.initialize() }
        first.plugin.deepLinkListenerReady()
        Host(linkIntent())
        sdk.deepLinkListener?.onDeepLinking(deepLinkResult(LINK))
        assertEquals("sent before anyone on screen listens", emptyList<String?>(), first.dart.links)

        first.start()

        assertEquals(listOf<String?>(LINK), first.dart.links)
    }

    @Test
    fun `refuses an engine whose activity is gone`() {
        val host = Host().also { it.initialize() }
        host.plugin.onDetachedFromActivity()

        val event = dartCalls { host.plugin.trackEvent("as_login", emptyMap()) }

        assertEquals(ErrorCodeMessage.NOT_INITIALIZED, event.value?.code)
        assertEquals(0, sdk.count("trackEvent"))
    }
}
