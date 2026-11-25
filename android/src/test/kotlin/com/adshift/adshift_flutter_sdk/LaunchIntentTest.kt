package com.adshift.adshift_flutter_sdk

import android.content.Intent
import android.os.Bundle
import io.mockk.every
import io.mockk.mockk
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.robolectric.annotation.Config

/** The link an Activity was opened with reaches the SDK exactly once, whatever happens to the Activity. */
class LaunchIntentTest : BridgeTest() {

    @Test
    fun `forwards the link the app was opened with`() {
        Host(linkIntent()).initialize()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `skips the link of an activity re-created in a new process`() {
        val first = Host(linkIntent()).also { it.initialize() }

        first.recreatedInNewProcess(linkIntent()).initialize()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    @Config(sdk = [28])
    fun `android 9 skips the link of an activity re-created in a new process`() {
        val first = Host(linkIntent()).also { it.initialize() }

        first.recreatedInNewProcess(linkIntent()).initialize()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    @Config(sdk = [24])
    fun `android 7 skips the link of an activity re-created in a new process`() {
        val first = Host(linkIntent()).also { it.initialize() }

        first.recreatedInNewProcess(linkIntent()).initialize()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `skips the link of an activity re-created twice`() {
        val first = Host(linkIntent()).also { it.initialize() }
        val second = first.recreatedInNewProcess(linkIntent()).also { it.initialize() }

        second.recreatedInNewProcess(linkIntent()).initialize()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards the link of a process killed before initialize`() {
        // The app waits for consent before initialize(); Android kills it in the background.
        val first = Host(linkIntent())

        first.recreatedInNewProcess(linkIntent()).initialize()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    @Config(sdk = [24])
    fun `android 7 forwards the link of a process killed before initialize`() {
        val first = Host(linkIntent())

        first.recreatedInNewProcess(linkIntent()).initialize()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `counts the link once when initialize comes while the activity is stopped and the process is killed`() {
        // The saved state says "not forwarded": forwarding now, unseen by it, would count twice.
        val first = Host(linkIntent())
        val state = first.stop()
        first.initialize()
        assertEquals("forwarded while stopped", emptyList<String>(), sdk.forwardedLinks())

        killProcess()
        Host(linkIntent(), state).initialize()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards the link when the user returns after an initialize that came while the activity was stopped`() {
        val host = Host(linkIntent())
        host.stop()
        host.initialize()
        assertEquals("forwarded while stopped", emptyList<String>(), sdk.forwardedLinks())

        host.start()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
        assertTrue("saved as forwarded at the next stop", host.stop().getBoolean(FORWARDED))
    }

    @Test
    fun `forwards the link at once when initialize comes after the user returned`() {
        val host = Host(linkIntent())
        host.stop()
        host.start()

        host.initialize()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `skips the link after the user returned, left again, and the process was killed`() {
        val first = Host(linkIntent())
        first.stop()
        first.initialize()
        first.start()

        first.recreatedInNewProcess(linkIntent()).initialize()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `holds an intent that arrives while the activity is stopped until it starts`() {
        val host = Host().also { it.initialize() }
        host.stop()

        host.newIntent(linkIntent())
        assertEquals("forwarded while stopped", emptyList<String>(), sdk.forwardedLinks())
        host.start()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `watches the activity only while attached to it`() {
        val host = Host(linkIntent())
        assertTrue("watched while attached", host.watcher != null)

        host.finish()

        assertNull("watched after it is gone", host.watcher)
    }

    @Test
    fun `saves what the sdk has from the launch intent, and no link`() {
        val host = Host(notificationIntent(LINK))
        val before = host.stop()
        host.start()

        host.initialize()
        val after = host.stop()

        assertEquals(setOf(FORWARDED, PUSH_ACCEPTED), after.keySet())
        assertFalse("forwarded, before initialize", before.getBoolean(FORWARDED))
        assertFalse("notification link taken, before initialize", before.getBoolean(PUSH_ACCEPTED))
        assertTrue("forwarded, after initialize", after.getBoolean(FORWARDED))
        assertTrue("notification link taken, after initialize", after.getBoolean(PUSH_ACCEPTED))
    }

    @Test
    fun `skips the link of a re-created activity whose intent another library marked`() {
        val opened = linkIntent()
        val first = Host(opened)
        opened.putExtra("consumed_at", 1_000L)
        first.initialize()

        val restored = linkIntent()
        val second = first.recreatedInNewProcess(restored)
        restored.putExtra("consumed_at", 2_000L)
        second.initialize()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `initialize survives a launch intent whose extras cannot be read`() {
        // Below Android 13 a Bundle holding a class the app does not know throws when it is read.
        val unreadable = mockk<Intent>(relaxed = true)
        val extras = mockk<Bundle>(relaxed = true)
        every { unreadable.dataString } returns null
        every { unreadable.flags } returns 0
        every { unreadable.extras } returns extras
        every { extras.keySet() } throws RuntimeException("Parcelable encountered ClassNotFoundException")

        assertNull(Host(unreadable).initialize())

        assertEquals("the Intent still reaches the SDK", 1, sdk.links.size)
    }

    @Test
    fun `forwards the same link tapped again after the process was killed`() {
        val first = Host(linkIntent()).also { it.initialize() }

        val second = first.recreatedInNewProcess(linkIntent()).also { it.initialize() }
        second.newIntent(linkIntent())

        assertEquals(listOf(LINK, LINK), sdk.forwardedLinks())
    }

    @Test
    @Config(sdk = [28])
    fun `android 9 forwards the same link tapped again after the process was killed`() {
        val first = Host(linkIntent()).also { it.initialize() }

        // The tap re-creates the Activity with its first Intent and hands it the new one.
        val second = first.recreatedInNewProcess(linkIntent())
        second.newIntent(linkIntent())
        second.initialize()

        assertEquals(listOf(LINK, LINK), sdk.forwardedLinks())
    }

    @Test
    @Config(sdk = [24])
    fun `android 7 forwards the same link tapped again after the process was killed`() {
        val first = Host(linkIntent()).also { it.initialize() }

        val second = first.recreatedInNewProcess(linkIntent())
        second.newIntent(linkIntent())
        second.initialize()

        assertEquals(listOf(LINK, LINK), sdk.forwardedLinks())
    }

    @Test
    fun `opened from the icon after the process was killed sends the old link nowhere`() {
        val first = Host(linkIntent()).also { it.initialize() }

        val second = first.recreatedInNewProcess(linkIntent())
        second.newIntent(launcherIntent())
        second.initialize()
        second.newIntent(linkIntent())

        assertEquals("the old link once, the new tap once", listOf(LINK, LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards the same link opening a new activity after back closed the first`() {
        val first = Host(linkIntent()).also { it.initialize() }
        first.finish()

        Host(linkIntent())

        assertEquals(listOf(LINK, LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards a link tapped after the activity was re-created`() {
        val first = Host(linkIntent()).also { it.initialize() }

        // A rotation the app does not handle itself: a new Activity and engine, the same process.
        val state = first.stop()
        first.finish()
        val second = Host(linkIntent(), state)
        second.newIntent(linkIntent())

        assertEquals(listOf(LINK, LINK), sdk.forwardedLinks())
    }

    @Test
    fun `skips the link of an activity re-created around the engine it keeps`() {
        val host = Host(linkIntent()).also { it.initialize() }
        host.plugin.deepLinkListenerReady()

        host.recreateActivity(linkIntent())
        sdk.deepLinkListener?.onDeepLinking(deepLinkResult(OTHER_LINK))

        assertEquals(listOf(LINK), sdk.forwardedLinks())
        assertEquals("results dart still receives", listOf<String?>(OTHER_LINK), host.dart.links)
    }

    @Test
    fun `skips a notification redelivered to a re-created activity`() {
        val first = Host(notificationIntent(LINK)).also { it.initialize() }

        val state = first.stop()
        first.finish()
        Host(notificationIntent(LINK), state).initialize()

        assertEquals(
            "notification payload forwarded once",
            1,
            sdk.pushExtras.count { it?.getString(PUSH_LINK_KEY) == LINK },
        )
    }

    @Test
    fun `forwards a tapped notification that carries no data uri`() {
        val host = Host(launcherIntent()).also { it.initialize() }

        host.newIntent(notificationIntent(LINK))

        assertEquals("deliveries forwarded to the SDK", 2, sdk.pushExtras.size)
        assertNull("a plain launcher start carries no extras", sdk.pushExtras[0])
        assertEquals(LINK, sdk.pushExtras[1]?.getString(PUSH_LINK_KEY))
    }

    @Test
    fun `skips an intent relaunched from recents`() {
        val fromRecents = notificationIntent(LINK).apply {
            addFlags(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY)
        }

        Host(fromRecents).initialize()

        assertEquals(emptyList<String>(), sdk.calls.filter { it.startsWith("handle") })
    }

    @Test
    fun `counts an intent once when two engines are handed it`() {
        val opened = linkIntent()
        val tapped = linkIntent(OTHER_LINK)
        val first = Host(opened).also { it.initialize() }
        val second = Host(opened)

        first.newIntent(tapped)
        second.newIntent(tapped)

        assertEquals(listOf(LINK, OTHER_LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards the launch intent, then the latest intent received before initialize`() {
        val host = Host(linkIntent())
        host.newIntent(linkIntent("https://$BRANDED_DOMAIN/dropped"))
        host.newIntent(linkIntent(OTHER_LINK))

        host.initialize()

        assertEquals(listOf(LINK, OTHER_LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards nothing by itself when the app handles deep links`() {
        val host = Host(linkIntent())
        host.newIntent(linkIntent(OTHER_LINK))

        host.initialize(options(autoHandleDeepLinks = false))
        host.newIntent(notificationIntent(LINK))

        assertEquals(emptyList<String>(), sdk.calls.filter { it.startsWith("handle") })
    }

    @Test
    fun `forwards the launch intent at initialize in a host that restores no state`() {
        Host(linkIntent(), restoresState = false).initialize()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards the launch intent once when dart restarts in a host that restores no state`() {
        val host = Host(linkIntent(), restoresState = false)

        host.initialize()
        host.initialize()

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `skips the launch link the app passes again after the activity was re-created`() {
        val first = Host(linkIntent())
        first.initialize(manual())
        dartCalls { first.plugin.handleDeepLink(LINK) }

        val second = first.recreatedInNewProcess(linkIntent())
        second.initialize(manual())
        val replay = dartCalls { second.plugin.handleDeepLink(LINK) }

        assertNull("error", replay.value)
        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `skips the launch link the app passes after it was forwarded from the intent before the activity was re-created`() {
        val first = Host(linkIntent()).also { it.initialize() }

        val second = first.recreatedInNewProcess(linkIntent()).also { it.initialize() }
        dartCalls { second.plugin.handleDeepLink(LINK) }

        assertEquals(listOf(LINK), sdk.forwardedLinks())
    }

    @Test
    fun `skips the launch link the app passes in the spelling dart gives it after the activity was re-created`() {
        val opened = "HTTPS://Example.RightLink.me/x?a=%7e"
        val first = Host(linkIntent(opened)).also { it.initialize() }

        val second = first.recreatedInNewProcess(linkIntent(opened)).also { it.initialize() }
        dartCalls { second.plugin.handleDeepLink("https://example.rightlink.me/x?a=~") }

        assertEquals(listOf(opened), sdk.forwardedLinks())
    }

    @Test
    fun `forwards the launch link the app passes after the activity was handed a new intent`() {
        val first = Host(linkIntent())
        first.initialize(manual())
        dartCalls { first.plugin.handleDeepLink(LINK) }

        val second = first.recreatedInNewProcess(linkIntent())
        second.initialize(manual())
        second.newIntent(linkIntent())
        dartCalls { second.plugin.handleDeepLink(LINK) }

        assertEquals(listOf(LINK, LINK), sdk.forwardedLinks())
    }

    @Test
    fun `forwards a link the app passes that is not the one the activity opened with`() {
        val first = Host(linkIntent())
        first.initialize(manual())
        dartCalls { first.plugin.handleDeepLink(LINK) }

        val second = first.recreatedInNewProcess(linkIntent())
        second.initialize(manual())
        dartCalls { second.plugin.handleDeepLink(OTHER_LINK) }

        assertEquals(listOf(LINK, OTHER_LINK), sdk.forwardedLinks())
    }

    private fun manual() = options(autoHandleDeepLinks = false)

    private companion object {
        const val FORWARDED = "com.adshift.launch_intent_forwarded"
        const val PUSH_ACCEPTED = "com.adshift.launch_push_accepted"
    }
}
