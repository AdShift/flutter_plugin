package com.adshift.adshift_flutter_sdk

import android.content.Intent
import com.adshift.sdk.core.AdShiftLib
import io.mockk.every
import io.mockk.verify
import java.time.Duration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** A notification payload the app passes itself, next to the notification's own Intent. */
class PushNotificationTest : BridgeTest() {

    private val payload = mapOf<String, Any?>(PUSH_LINK_KEY to LINK, "title" to "Sale")

    @Test
    fun `counts once a notification the app opened from and passes later`() {
        // A cold start from a notification; the app reads the message that opened it afterwards.
        val host = Host(notificationIntent(LINK)).also { it.initialize() }
        wait(Duration.ofSeconds(12))

        assertTrue("answer", host.passes(payload))

        assertEquals("payloads handed to the SDK", emptyList<Map<String, Any?>>(), sdk.pushPayloads)
        assertEquals("notification Intents handed to the SDK", 1, sdk.pushExtras.size)
    }

    @Test
    fun `counts once a notification the app passes with more in it than its intent carried`() {
        val host = Host(notificationIntent(LINK)).also { it.initialize() }
        wait(Duration.ofSeconds(12))

        val message = payload + ("image" to "https://cdn.example.com/sale.png")
        assertTrue("answer", host.passes(message))

        assertEquals("payloads handed to the SDK", emptyList<Map<String, Any?>>(), sdk.pushPayloads)
    }

    @Test
    fun `counts once a notification tapped while the app runs`() {
        val host = Host().also { it.initialize() }
        host.newIntent(notificationIntent("HTTPS://Example.RightLink.me/x?a=%7e"))
        wait(Duration.ofSeconds(12))

        val nested = mapOf<String, Any?>("data" to mapOf(PUSH_LINK_KEY to "https://example.rightlink.me/x?a=~"))
        assertTrue("answer", host.passes(nested))

        assertEquals("payloads handed to the SDK", emptyList<Map<String, Any?>>(), sdk.pushPayloads)
    }

    @Test
    fun `counts once a notification whose intent waits for the activity to return`() {
        val host = Host().also { it.initialize() }
        host.stop()
        host.newIntent(notificationIntent(LINK))

        assertTrue("answer", host.passes(payload))
        host.start()

        assertEquals("payloads handed to the SDK", emptyList<Map<String, Any?>>(), sdk.pushPayloads)
        assertEquals(LINK, sdk.pushExtras.last()?.getString(PUSH_LINK_KEY))
    }

    @Test
    fun `counts once a notification passed again after the activity was re-created`() {
        val first = Host(notificationIntent(LINK)).also { it.initialize() }

        val second = first.recreatedInNewProcess(notificationIntent(LINK)).also { it.initialize() }
        wait(Duration.ofSeconds(12))
        assertTrue("answer", second.passes(payload))

        assertEquals("payloads handed to the SDK", emptyList<Map<String, Any?>>(), sdk.pushPayloads)
        assertEquals("notification Intents handed to the SDK", 1, sdk.pushExtras.size)
    }

    @Test
    fun `skips a notification passed after a relaunch from recents`() {
        val relaunched = notificationIntent(LINK).addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY)
        val host = Host(relaunched).also { it.initialize() }

        assertTrue("answer", host.passes(payload))

        assertEquals("payloads handed to the SDK", emptyList<Map<String, Any?>>(), sdk.pushPayloads)
    }

    @Test
    fun `hands over a notification the app built with the link that opened the activity in it`() {
        // The app's own URL once opened the Activity as a link; that says nothing about a notification.
        val host = Host(linkIntent(OTHER_LINK)).also { it.initialize() }
        val built = mapOf<String, Any?>(PUSH_LINK_KEY to LINK, "screen" to OTHER_LINK)

        assertTrue("the SDK's answer", host.passes(built))

        assertEquals(listOf(built), sdk.pushPayloads)
    }

    @Test
    fun `hands over a notification with a link the activity was opened with as a link`() {
        val host = Host(linkIntent()).also { it.initialize() }
        wait(Duration.ofSeconds(12))

        assertTrue("the SDK's answer", host.passes(payload))

        assertEquals(listOf(payload), sdk.pushPayloads)
    }

    @Test
    fun `hands over a notification without a known link and answers as the sdk does`() {
        val host = Host(notificationIntent(LINK)).also { it.initialize() }
        every { AdShiftLib.handlePushNotification(any<Map<String, Any?>>()) } returns false

        val plain = mapOf<String, Any?>("title" to "Sale")
        val other = mapOf<String, Any?>(PUSH_LINK_KEY to OTHER_LINK)
        assertFalse("the SDK's answer", host.passes(plain))
        assertFalse("the SDK's answer", host.passes(other))

        verify(exactly = 1) { AdShiftLib.handlePushNotification(plain) }
        verify(exactly = 1) { AdShiftLib.handlePushNotification(other) }
    }

    @Test
    fun `hands over a notification whose intent the sdk took no link from`() {
        // Another library's notification Intent: the SDK does not read the link where that one puts it.
        val intent = launcherIntent().apply { putExtra("payload", """{"$PUSH_LINK_KEY":"$LINK"}""") }
        val host = Host(intent).also { it.initialize() }

        assertTrue("the SDK's answer", host.passes(payload))

        assertEquals(listOf(payload), sdk.pushPayloads)
    }

    @Test
    fun `hands over a notification for a new tap of a link taken before`() {
        val host = Host(notificationIntent(LINK)).also { it.initialize() }

        // A notification the app shows itself: its Intent carries the link where the SDK does not read it.
        host.newIntent(launcherIntent().apply { putExtra("payload", LINK) })
        assertTrue("the SDK's answer", host.passes(payload))

        assertEquals(listOf(payload), sdk.pushPayloads)
    }

    @Test
    fun `hands over every notification when the app handles deep links itself`() {
        val first = Host(notificationIntent(LINK)).also { it.initialize(options(autoHandleDeepLinks = false)) }
        assertTrue("the SDK's answer", first.passes(payload))

        val second = first.recreatedInNewProcess(notificationIntent(LINK))
        second.initialize(options(autoHandleDeepLinks = false))
        assertTrue("the SDK's answer", second.passes(payload))

        assertEquals(listOf(payload, payload), sdk.pushPayloads)
    }

    private fun Host.passes(payload: Map<String, Any?>): Boolean =
        dartCalls { plugin.handlePushNotification(payload) }.value
}
