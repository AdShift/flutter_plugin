package com.adshift.adshift_flutter_sdk

import com.adshift.sdk.core.ASAdRevenueData
import com.adshift.sdk.core.ASMediationNetwork
import com.adshift.sdk.core.AdShiftLib
import io.mockk.every
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** Events, identity and push: what the SDK is handed, and what its answers become. */
class EventsTest : BridgeTest() {

    private lateinit var host: Host

    @Before
    fun initialize() {
        host = Host().also { it.initialize() }
    }

    @Test
    fun `tracks an event without the values that are null`() {
        val answer = dartCalls {
            host.plugin.trackEvent("as_login", mapOf("method" to "email", "count" to 3L, "skipped" to null))
        }
        assertEquals("answers before the SDK took the event", 0, answer.count)
        sdk.trackListener?.onSuccess()
        idle()

        assertNull("error", answer.value)
        verify { AdShiftLib.trackEvent("as_login", mapOf("method" to "email", "count" to 3L), any()) }
    }

    @Test
    fun `reports the reason the sdk refused an event`() {
        val reasons = listOf(
            SdkErrorCode.OPTED_OUT to ErrorCodeMessage.OPTED_OUT,
            SdkErrorCode.QUEUE_FULL to ErrorCodeMessage.QUEUE_FULL,
            99 to ErrorCodeMessage.UNKNOWN,
        )
        for ((sdkCode, code) in reasons) {
            val answer = dartCalls { host.plugin.trackEvent("as_login", emptyMap()) }
            sdk.trackListener?.onError(sdkCode, "refused")
            idle()

            assertEquals(code, answer.value?.code)
            assertEquals("refused", answer.value?.message)
            assertEquals(sdkCode.toString(), answer.value?.nativeCode)
        }
    }

    @Test
    fun `refuses an event before initialize`() {
        killProcess()

        val answer = dartCalls { Host().plugin.trackEvent("as_login", emptyMap()) }

        assertEquals(ErrorCodeMessage.NOT_INITIALIZED, answer.value?.code)
        assertEquals(0, sdk.count("trackEvent"))
    }

    @Test
    fun `tells an argument the sdk refused from an sdk that is not initialized`() {
        every { AdShiftLib.trackEvent(any(), any(), any()) } throws IllegalArgumentException("bad name")

        val answer = dartCalls { host.plugin.trackEvent("", emptyMap()) }

        assertEquals(ErrorCodeMessage.INVALID_ARGUMENT, answer.value?.code)
        assertEquals("bad name", answer.value?.message)
    }

    @Test
    fun `tracks a purchase`() {
        val answer = dartCalls { host.plugin.trackPurchase("sku-1", 4.99, "EUR", "token-1") }
        sdk.trackListener?.onSuccess()
        idle()

        assertNull("error", answer.value)
        verify { AdShiftLib.trackPurchase("sku-1", 4.99, "EUR", "token-1", any()) }
    }

    @Test
    fun `logs ad revenue with its ad unit and precision`() {
        val answer = dartCalls {
            host.plugin.logAdRevenue(
                AdRevenueMessage(
                    monetizationNetwork = "admob",
                    mediationNetwork = "applovin_max",
                    currency = "USD",
                    revenue = 0.02,
                    adUnitId = "unit-1",
                    precision = "exact",
                    additionalParameters = mapOf(
                        "placement" to "home",
                        "skipped" to null,
                        "as_revenue" to 9.0,
                        "as_currency" to "PLN",
                        "as_adrev_source" to "other",
                        "as_adrev_network_name" to "other",
                    ),
                )
            )
        }

        assertNull("error", answer.value)
        verify {
            AdShiftLib.logAdRevenue(
                ASAdRevenueData("admob", ASMediationNetwork.APPLOVIN_MAX, "USD", 0.02),
                mapOf("placement" to "home", "as_adrev_ad_unit_id" to "unit-1", "as_adrev_precision" to "exact"),
            )
        }
    }

    @Test
    fun `logs ad revenue of a mediation network the sdk does not name as other`() {
        dartCalls { host.plugin.logAdRevenue(AdRevenueMessage("admob", "brand_new", "USD", 0.02)) }

        verify { AdShiftLib.logAdRevenue(ASAdRevenueData("admob", ASMediationNetwork.OTHER, "USD", 0.02), null) }
    }

    @Test
    fun `passes ad revenue on as the app gave it`() {
        val answer = dartCalls { host.plugin.logAdRevenue(AdRevenueMessage("admob", "google_admob", "US", 0.0)) }

        assertNull("error", answer.value)
        verify { AdShiftLib.logAdRevenue(ASAdRevenueData("admob", ASMediationNetwork.GOOGLE_ADMOB, "US", 0.0), null) }
    }

    @Test
    fun `reports what the sdk throws for ad revenue`() {
        every { AdShiftLib.logAdRevenue(any(), any()) } throws IllegalStateException("broken")

        val answer = dartCalls { host.plugin.logAdRevenue(AdRevenueMessage("admob", "google_admob", "USD", 0.02)) }

        assertEquals(ErrorCodeMessage.UNKNOWN, answer.value?.code)
    }

    @Test
    fun `passes identity and settings to the sdk`() {
        host.plugin.setCustomerUserId("user-1")
        host.plugin.setDebugEnabled(false)
        host.plugin.setAppOpenDebounceMs(1_500)
        host.plugin.setBrandedDomains(listOf("go.example.com", ""))
        host.plugin.setMetaAppId("1234567890")
        host.plugin.setOaidData("oaid-1")

        verify { AdShiftLib.setCustomerUserId("user-1") }
        verify { AdShiftLib.setDebugLog(false) }
        verify { AdShiftLib.setAppOpenDebounceMs(1_500L) }
        verify { AdShiftLib.setBrandedDomains(listOf("go.example.com")) }
        verify { AdShiftLib.setMetaAppId("1234567890") }
        verify { AdShiftLib.setOaidData("oaid-1") }
        assertEquals("device-id", host.plugin.getAdShiftDeviceId())
    }

    @Test
    fun `absorbs what the sdk throws at a setting`() {
        every { AdShiftLib.setCustomerUserId(any()) } throws IllegalStateException("broken")

        host.plugin.setCustomerUserId("user-1")
    }

    @Test
    fun `ignores settings before initialize`() {
        killProcess()
        val before = sdk.calls.toList()
        val plugin = Host().plugin

        plugin.setCustomerUserId("user-1")
        plugin.setThirdPartySharing(true)
        plugin.addPushNotificationDeepLinkPath(listOf("data", "link"))

        assertEquals(before, sdk.calls)
        assertNull("consent", plugin.refreshConsent())
        assertEquals(false, plugin.handlePushNotification(mapOf(PUSH_LINK_KEY to LINK)))
    }

    @Test
    fun `registers each push link path once`() {
        host.plugin.addPushNotificationDeepLinkPath(listOf("data", " ", "link"))
        host.plugin.addPushNotificationDeepLinkPath(listOf("data", "link"))
        host.plugin.addPushNotificationDeepLinkPath(listOf(PUSH_LINK_KEY))
        host.plugin.addPushNotificationDeepLinkPath(listOf(""))

        verify(exactly = 1) { AdShiftLib.addPushNotificationDeepLinkPath("data", "link") }
        assertEquals("with the path of initialize", 2, sdk.count("addPushNotificationDeepLinkPath"))
    }

    @Test
    fun `registers a push link path again after the sdk refused it`() {
        every { AdShiftLib.addPushNotificationDeepLinkPath(*anyVararg()) } throws IllegalStateException("broken")
        host.plugin.addPushNotificationDeepLinkPath(listOf("data", "link"))

        every { AdShiftLib.addPushNotificationDeepLinkPath(*anyVararg()) } answers {
            sdk.calls += "addPushNotificationDeepLinkPath"
        }
        host.plugin.addPushNotificationDeepLinkPath(listOf("data", "link"))

        assertEquals("with the path of initialize", 2, sdk.count("addPushNotificationDeepLinkPath"))
    }

    @Test
    fun `hands a notification payload to the sdk and returns its answer`() {
        val payload = mapOf(PUSH_LINK_KEY to LINK, "nested" to mapOf("a" to 1L), "empty" to null)

        assertTrue("accepted", host.plugin.handlePushNotification(payload))

        verify { AdShiftLib.handlePushNotification(payload) }
    }

    @Test
    fun `does nothing with a pasted link`() {
        val before = sdk.calls.toList()

        host.plugin.handlePastedDeepLink(LINK)
        host.plugin.handlePastedDeepLink(null)

        assertEquals(before, sdk.calls)
    }
}
