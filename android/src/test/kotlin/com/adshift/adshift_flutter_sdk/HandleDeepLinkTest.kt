package com.adshift.adshift_flutter_sdk

import android.content.Intent
import com.adshift.sdk.core.AdShiftLib
import io.mockk.every
import java.time.Duration
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/** A link the app passes itself, next to the links the plugin takes from Intents. */
class HandleDeepLinkTest : BridgeTest() {

    @Test
    fun `forwards a link the app passes`() {
        val host = Host().also { it.initialize() }

        val answer = dartCalls { host.plugin.handleDeepLink(LINK) }

        assertNull("error", answer.value)
        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `counts once a link that just arrived in the notification extras`() {
        val host = Host(notificationIntent(LINK)).also { it.initialize() }

        val answer = dartCalls { host.plugin.handleDeepLink(LINK) }

        assertNull("error", answer.value)
        assertEquals("links forwarded to the SDK", emptyList<String>(), sdk.forwardedLinks())
    }

    @Test
    fun `counts once a link nested in a json payload extra`() {
        val intent = launcherIntent().apply {
            putExtra("as_push_payload", """{"data":{"$PUSH_LINK_KEY":"$LINK"}}""")
        }
        sdk.pushLinkKeys += "as_push_payload"
        val host = Host(intent).also { it.initialize() }

        val answer = dartCalls { host.plugin.handleDeepLink(LINK) }

        assertNull("error", answer.value)
        assertEquals("links forwarded to the SDK", emptyList<String>(), sdk.forwardedLinks())
    }

    @Test
    fun `counts once a link that just arrived as the intent data`() {
        val host = Host(linkIntent()).also { it.initialize() }

        val answer = dartCalls { host.plugin.handleDeepLink(LINK) }

        assertNull("error", answer.value)
        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `counts once a link that just arrived with a new intent`() {
        val host = Host().also { it.initialize() }
        host.newIntent(linkIntent())

        dartCalls { host.plugin.handleDeepLink(LINK) }

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `counts once a link the app passes in the spelling dart gives it`() {
        // Dart's Uri lower-cases the scheme and the host and rewrites percent-escapes.
        val host = Host(linkIntent("HTTPS://Example.RightLink.me/x?a=%7e")).also { it.initialize() }

        val answer = dartCalls { host.plugin.handleDeepLink("https://example.rightlink.me/x?a=~") }

        assertNull("error", answer.value)
        assertEquals(listOf("HTTPS://Example.RightLink.me/x?a=%7e"), sdk.forwardedLinks())
    }

    @Test
    fun `counts once a notification link the app passes in the spelling dart gives it`() {
        val intent = notificationIntent("https://Example.com:443/a%2fb/%c3%a9?q=a%20b+c&r=%26#Frag%7e")
        val host = Host(intent).also { it.initialize() }

        dartCalls { host.plugin.handleDeepLink("https://example.com/a%2Fb/%C3%A9?q=a%20b+c&r=%26#Frag~") }

        assertEquals(emptyList<String>(), sdk.forwardedLinks())
    }

    @Test
    fun `tells links apart that differ in more than their spelling`() {
        val host = Host(linkIntent("https://example.rightlink.me/x?a=1")).also { it.initialize() }

        for (other in listOf(
            "https://example.rightlink.me/X?a=1",
            "https://example.rightlink.me/x?a=2",
            "https://example.rightlink.me:8443/x?a=1",
            "http://example.rightlink.me/x?a=1",
            "https://other.rightlink.me/x?a=1",
        )) {
            dartCalls { host.plugin.handleDeepLink(other) }
        }

        assertEquals(6, sdk.forwardedLinks().size)
    }

    @Test
    fun `forwards a link that did not arrive with the intent`() {
        val host = Host(notificationIntent(LINK)).also { it.initialize() }

        val answer = dartCalls { host.plugin.handleDeepLink(OTHER_LINK) }

        assertNull("error", answer.value)
        assertEquals(listOf(OTHER_LINK), sdk.forwardedLinks())
    }

    @Test
    fun `counts once a link an intent of another activity brought in the last two seconds`() {
        Host(linkIntent()).also { it.initialize() }
        val owner = Host()

        dartCalls { owner.plugin.handleDeepLink(LINK) }
        assertEquals("within two seconds", listOf(LINK), sdk.forwardedLinks())
        waitOutDedupWindow()
        dartCalls { owner.plugin.handleDeepLink(LINK) }

        assertEquals("afterwards", listOf(LINK, LINK), sdk.forwardedLinks())
    }

    @Test
    fun `counts once the launch link the app passes again much later`() {
        val host = Host(linkIntent()).also { it.initialize() }
        wait(Duration.ofSeconds(12))

        val answer = dartCalls { host.plugin.handleDeepLink(LINK) }

        assertNull("error", answer.value)
        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `counts once the link of a later intent the app passes again much later`() {
        val host = Host().also { it.initialize() }
        host.newIntent(linkIntent("HTTPS://Example.RightLink.me/x?a=%7e"))
        wait(Duration.ofSeconds(12))

        dartCalls { host.plugin.handleDeepLink("https://example.rightlink.me/x?a=~") }

        assertEquals(listOf("HTTPS://Example.RightLink.me/x?a=%7e"), sdk.forwardedLinks())
    }

    @Test
    fun `forwards a new intent with a link forwarded before, as the new tap it is`() {
        val host = Host(linkIntent()).also { it.initialize() }
        wait(Duration.ofSeconds(12))

        host.newIntent(linkIntent())
        assertEquals(listOf(LINK, LINK), sdk.forwardedLinks())
        wait(Duration.ofSeconds(12))
        dartCalls { host.plugin.handleDeepLink(LINK) }

        assertEquals("with the app passing the new tap's link too", listOf(LINK, LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards a link the app passes that sits in extras the sdk took no link from`() {
        // Another library's notification Intent: the SDK does not read the link where that one puts it.
        val intent = launcherIntent().apply { putExtra("payload", """{"url":"$LINK"}""") }
        val host = Host(intent).also { it.initialize() }
        wait(Duration.ofSeconds(12))

        dartCalls { host.plugin.handleDeepLink(LINK) }

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards a link the app passes from an intent that is not a view intent`() {
        // The SDK reads an app link from a view Intent only, so this one is not counted yet.
        val intent = linkIntent().setAction("android.nfc.action.NDEF_DISCOVERED")
        val host = Host(intent).also { it.initialize() }
        wait(Duration.ofSeconds(12))

        dartCalls { host.plugin.handleDeepLink(LINK) }
        dartCalls { host.plugin.handleDeepLink(LINK) }

        assertEquals("once handed over as the intent, once by the app", 2, sdk.forwardedLinks().size)
    }

    @Test
    fun `skips the launch link the app passes when the activity was relaunched from recents`() {
        val relaunched = linkIntent().addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY)
        val host = Host(relaunched).also { it.initialize(options(autoHandleDeepLinks = false)) }

        val answer = dartCalls { host.plugin.handleDeepLink(LINK) }

        assertNull("error", answer.value)
        assertEquals(emptyList<String>(), sdk.forwardedLinks())
    }

    @Test
    fun `forwards the link of a new tap the app passes after a relaunch from recents`() {
        val relaunched = linkIntent().addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY)
        val host = Host(relaunched).also { it.initialize(options(autoHandleDeepLinks = false)) }

        host.newIntent(linkIntent())
        dartCalls { host.plugin.handleDeepLink(LINK) }

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards a link the app passes while the activity is stopped`() {
        val host = Host().also { it.initialize() }
        host.stop()

        val answer = dartCalls { host.plugin.handleDeepLink(LINK) }

        assertNull("error", answer.value)
        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `counts once the launch link the app passes while it waits for the activity to return`() {
        val host = Host(linkIntent())
        host.stop()
        host.initialize()

        val answer = dartCalls { host.plugin.handleDeepLink(LINK) }
        assertNull("error", answer.value)
        assertEquals("forwarded while stopped", emptyList<String>(), sdk.forwardedLinks())
        host.start()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `counts once the launch link the app passes while stopped when the process is then killed`() {
        val first = Host(linkIntent())
        val state = first.stop()
        first.initialize()
        dartCalls { first.plugin.handleDeepLink(LINK) }

        killProcess()
        Host(linkIntent(), state).initialize()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards another link the app passes while the launch link waits, which still goes out once`() {
        val host = Host(linkIntent())
        host.stop()
        host.initialize()

        dartCalls { host.plugin.handleDeepLink(OTHER_LINK) }
        assertEquals("forwarded while stopped", listOf(OTHER_LINK), sdk.forwardedLinks())
        host.start()
        host.start()

        assertEquals(listOf(OTHER_LINK, LINK), sdk.forwardedLinks())
    }

    @Test
    fun `counts once a link the app passes that waits in an intent received while stopped`() {
        val host = Host().also { it.initialize() }
        host.stop()
        host.newIntent(notificationIntent("HTTPS://Example.RightLink.me/x?a=%7e"))

        dartCalls { host.plugin.handleDeepLink("https://example.rightlink.me/x?a=~") }
        host.start()

        assertEquals("links the app's call forwarded", emptyList<String>(), sdk.forwardedLinks())
        assertEquals("notification payloads forwarded on return", 2, sdk.pushExtras.size)
    }

    @Test
    fun `counts once the launch link the app passes while stopped and again after the process was killed`() {
        // The app handles deep links itself; the saved state cannot say what it passes while stopped.
        val first = Host(linkIntent())
        val state = first.stop()
        first.initialize(manual())
        val answer = dartCalls { first.plugin.handleDeepLink(LINK) }
        assertNull("error", answer.value)
        assertEquals("forwarded while stopped", emptyList<String>(), sdk.forwardedLinks())

        killProcess()
        val second = Host(linkIntent(), state).also { it.initialize(manual()) }
        dartCalls { second.plugin.handleDeepLink(LINK) }

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards the launch link the app passed while stopped when the user returns`() {
        val host = Host(linkIntent())
        host.stop()
        host.initialize(manual())
        dartCalls { host.plugin.handleDeepLink(LINK) }
        dartCalls { host.plugin.handleDeepLink(LINK) }
        assertEquals("forwarded while stopped", emptyList<String>(), sdk.forwardedLinks())

        host.start()
        assertEquals("forwarded on return", listOf(LINK), sdk.forwardedLinks())

        val again = host.recreatedInNewProcess(linkIntent()).also { it.initialize(manual()) }
        dartCalls { again.plugin.handleDeepLink(LINK) }

        assertEquals("with the link passed again after re-creation", listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards another link the app passes while stopped at once when it handles deep links itself`() {
        val host = Host(linkIntent())
        host.stop()
        host.initialize(manual())

        dartCalls { host.plugin.handleDeepLink(OTHER_LINK) }

        assertEquals(listOf(OTHER_LINK), sdk.forwardedLinks())
    }

    @Test
    fun `refuses a url that is not absolute`() {
        val host = Host().also { it.initialize() }

        for (url in listOf("", "promo?id=42", "//$BRANDED_DOMAIN/promo", "https:///promo")) {
            val answer = dartCalls { host.plugin.handleDeepLink(url) }
            assertEquals(url, ErrorCodeMessage.INVALID_ARGUMENT, answer.value?.code)
        }
        assertEquals(emptyList<String>(), sdk.forwardedLinks())
    }

    @Test
    fun `forwards a link in the app's own scheme`() {
        val host = Host().also { it.initialize() }

        val answer = dartCalls { host.plugin.handleDeepLink("myapp://promo") }

        assertNull("error", answer.value)
        assertEquals(listOf("myapp://promo"), sdk.forwardedLinks())
    }

    @Test
    fun `refuses a link before initialize`() {
        val host = Host()

        val answer = dartCalls { host.plugin.handleDeepLink(LINK) }

        assertEquals(ErrorCodeMessage.NOT_INITIALIZED, answer.value?.code)
        assertEquals(emptyList<String>(), sdk.forwardedLinks())
    }

    private fun manual() = options(autoHandleDeepLinks = false)

    @Test
    fun `reports what the sdk throws for a link`() {
        val host = Host().also { it.initialize() }
        every { AdShiftLib.handleAppLinkIntent(any()) } throws IllegalStateException("broken")

        val answer = dartCalls { host.plugin.handleDeepLink(LINK) }

        assertEquals(ErrorCodeMessage.UNKNOWN, answer.value?.code)
        assertEquals("broken", answer.value?.message)
    }
}
