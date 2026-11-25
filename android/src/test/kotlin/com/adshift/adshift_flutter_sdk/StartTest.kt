package com.adshift.adshift_flutter_sdk

import com.adshift.sdk.core.AdShiftLib
import io.mockk.every
import java.time.Duration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class StartTest : BridgeTest() {

    private val host by lazy { Host().also { it.initialize() } }

    @Test
    fun `reports a start before initialize as not initialized`() {
        val start = dartCalls { Host().plugin.start() }

        assertFalse("success", start.value.success)
        assertEquals(ErrorCodeMessage.NOT_INITIALIZED, start.value.error?.code)
        assertEquals(0, sdk.count("start"))
    }

    @Test
    fun `reports a valid key when the sdk answers the start`() {
        val start = dartCalls { host.plugin.start() }
        sdk.startListener?.onSuccess()
        idle()

        assertTrue("success", start.value.success)
        assertEquals(KeyStatusMessage.VALID, start.value.keyStatus)
        assertNull("error", start.value.error)
    }

    @Test
    fun `reports an api key that was refused`() {
        val start = dartCalls { host.plugin.start() }
        sdk.startListener?.onError(SdkErrorCode.INVALID_API_KEY, "Invalid Dev Key")
        idle()

        assertFalse("success", start.value.success)
        assertEquals(KeyStatusMessage.INVALID, start.value.keyStatus)
        assertEquals(ErrorCodeMessage.INVALID_API_KEY, start.value.error?.code)
        assertEquals("Invalid Dev Key", start.value.error?.message)
        assertEquals("41", start.value.error?.nativeCode)
    }

    @Test
    fun `reports a device that opted out instead of a successful start`() {
        val start = dartCalls { host.plugin.start() }
        sdk.startListener?.onError(SdkErrorCode.OPTED_OUT, "Device opted out of tracking")
        idle()

        assertFalse("success", start.value.success)
        assertNull("key status", start.value.keyStatus)
        assertEquals(ErrorCodeMessage.OPTED_OUT, start.value.error?.code)
    }

    @Test
    fun `reports a full queue and any other code with the code the sdk gave`() {
        val full = dartCalls { host.plugin.start() }
        sdk.startListener?.onError(SdkErrorCode.QUEUE_FULL, "Event queue full")
        val other = dartCalls { host.plugin.start() }
        sdk.startListener?.onError(99, "Something else")
        idle()

        assertEquals(ErrorCodeMessage.QUEUE_FULL, full.value.error?.code)
        assertEquals(ErrorCodeMessage.UNKNOWN, other.value.error?.code)
        assertEquals("99", other.value.error?.nativeCode)
        assertFalse("success", other.value.success)
    }

    @Test
    fun `answers without a verdict rather than leaving the app waiting`() {
        val start = dartCalls { host.plugin.start() }
        wait(Duration.ofMillis(4_999))
        assertEquals("answers before the wait elapsed", 0, start.count)

        wait(Duration.ofMillis(1))

        assertTrue("success", start.value.success)
        assertEquals(KeyStatusMessage.PENDING, start.value.keyStatus)
    }

    @Test
    fun `keeps the first answer when the sdk reports twice`() {
        val start = dartCalls { host.plugin.start() }
        sdk.startListener?.onSuccess()
        sdk.startListener?.onError(SdkErrorCode.INVALID_API_KEY, "Invalid Dev Key")
        wait(Duration.ofSeconds(5))

        assertEquals("answers", 1, start.count)
        assertTrue("success", start.value.success)
    }

    @Test
    fun `keeps the answer it gave when the sdk reports after the wait`() {
        val start = dartCalls { host.plugin.start() }
        wait(Duration.ofSeconds(5))
        sdk.startListener?.onError(SdkErrorCode.INVALID_API_KEY, "Invalid Dev Key")
        idle()

        assertEquals("answers", 1, start.count)
        assertEquals(KeyStatusMessage.PENDING, start.value.keyStatus)
    }

    @Test
    fun `reports what the sdk throws at start`() {
        every { AdShiftLib.start(any()) } throws IllegalStateException("broken")

        val start = dartCalls { host.plugin.start() }

        assertFalse("success", start.value.success)
        assertEquals(ErrorCodeMessage.UNKNOWN, start.value.error?.code)
        assertEquals("broken", start.value.error?.message)
    }

    @Test
    fun `stops after a start called first`() {
        host.dart.call("start")
        host.dart.call("stop")
        idle()

        assertEquals(listOf("start", "stop"), startsAndStops())
    }

    @Test
    fun `starts after a stop called first`() {
        host.dart.call("stop")
        host.dart.call("start")
        idle()

        assertEquals(listOf("stop", "start"), startsAndStops())
    }

    @Test
    fun `runs a setting after an event tracked before it`() {
        // The event must carry the user id and the consent it was tracked under, not the later ones.
        host.dart.call("trackEvent", "logout", emptyMap<String, Any?>())
        host.dart.call("setCustomerUserId", "guest")
        host.dart.call("trackEvent", "browse", emptyMap<String, Any?>())
        host.dart.call("setConsentData", ConsentMessage(isUserSubjectToGdpr = false))
        idle()

        assertEquals(
            listOf("trackEvent", "setCustomerUserId", "trackEvent", "setConsentData"),
            sdk.calls.filter { it == "trackEvent" || it.startsWith("set") }.takeLast(4),
        )
    }

    @Test
    fun `runs the calls that answer and those that do not in the order dart made them`() {
        host.dart.call("trackEvent", "browse", emptyMap<String, Any?>())
        host.dart.call("addPushNotificationDeepLinkPath", listOf("data", "link"))
        host.dart.call("handlePushNotification", mapOf("data" to mapOf("link" to LINK)))
        host.dart.call("setConsentData", ConsentMessage(isUserSubjectToGdpr = false))
        host.dart.call("refreshConsent")
        host.dart.call("stop")
        assertEquals("calls run before their turn", 0, sdk.count("trackEvent"))
        idle()

        assertEquals(
            listOf(
                "trackEvent",
                "addPushNotificationDeepLinkPath",
                "handlePushNotification",
                "setConsentData",
                "refreshConsent",
                "stop",
            ),
            sdk.calls.takeLast(6),
        )
    }

    @Test
    fun `ignores a stop before initialize`() {
        Host().plugin.stop()
        idle()

        assertEquals(0, sdk.count("stop"))
    }

    private fun startsAndStops() = sdk.calls.filter { it == "start" || it == "stop" }
}
