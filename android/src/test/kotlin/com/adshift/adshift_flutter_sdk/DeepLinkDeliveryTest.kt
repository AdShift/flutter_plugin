package com.adshift.adshift_flutter_sdk

import android.net.Uri
import com.adshift.sdk.core.deeplink.DeepLinkError
import com.adshift.sdk.core.deeplink.DeepLinkResult
import com.adshift.sdk.core.deeplink.DeepLinkSource
import com.adshift.sdk.core.deeplink.DeepLinkStatus
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

/** Each result of the SDK reaches Dart once, and only once Dart listens. */
class DeepLinkDeliveryTest : BridgeTest() {

    private lateinit var host: Host

    @Before
    fun initialize() {
        host = Host().also { it.initialize() }
    }

    @Test
    fun `holds results until dart listens, then sends them oldest first`() {
        result(link(1))
        result(link(2))

        assertEquals("results sent so far", emptyList<String>(), host.dart.links)

        host.plugin.deepLinkListenerReady()

        assertEquals(listOf(link(1), link(2)), host.dart.links)
    }

    @Test
    fun `sends a result straight away while dart listens`() {
        host.plugin.deepLinkListenerReady()

        result(link(1))

        assertEquals(listOf(link(1)), host.dart.links)
    }

    @Test
    fun `sends a waiting result only once`() {
        result(link(1))

        host.plugin.deepLinkListenerReady()
        host.plugin.deepLinkListenerReady()

        assertEquals(listOf(link(1)), host.dart.links)
    }

    @Test
    fun `keeps the newest direct results when more arrive than can be held`() {
        repeat(DISPATCHED) { index -> result(link(index)) }

        host.plugin.deepLinkListenerReady()

        assertEquals((DISPATCHED - LIMIT until DISPATCHED).map(::link), host.dart.links)
    }

    @Test
    fun `gives up the oldest direct result before a deferred one`() {
        result(link(0), isDeferred = true)
        repeat(LIMIT) { index -> result(link(index + 1)) }

        host.plugin.deepLinkListenerReady()

        assertEquals(listOf(link(0)) + (2..LIMIT).map(::link), host.dart.links)
    }

    @Test
    fun `never gives up a deferred result for a direct one`() {
        repeat(LIMIT) { index -> result(link(index), isDeferred = true) }
        result(link(LIMIT))

        host.plugin.deepLinkListenerReady()

        assertEquals((0 until LIMIT).map(::link), host.dart.links)
    }

    @Test
    fun `gives up the oldest deferred result for a newer deferred one`() {
        repeat(LIMIT + 1) { index -> result(link(index), isDeferred = true) }

        host.plugin.deepLinkListenerReady()

        assertEquals((1..LIMIT).map(::link), host.dart.links)
    }

    @Test
    fun `holds results again once the engine is gone, for the next one that listens`() {
        host.plugin.deepLinkListenerReady()
        host.finish()

        result(link(1))
        val next = Host().also { it.initialize() }
        assertEquals("sent before dart listens", emptyList<String>(), next.dart.links)
        next.plugin.deepLinkListenerReady()

        assertEquals("sent to the engine that is gone", emptyList<String>(), host.dart.links)
        assertEquals(listOf(link(1)), next.dart.links)
    }

    @Test
    fun `holds results again when dart restarts, until it listens again`() {
        host.plugin.deepLinkListenerReady()

        // A hot restart: Dart starts over with initialize() and then says that it listens.
        host.initialize()
        result(link(1))
        result(link(2))
        assertEquals("results sent before dart listens", emptyList<String>(), host.dart.links)

        host.plugin.deepLinkListenerReady()

        assertEquals(listOf(link(1), link(2)), host.dart.links)
    }

    @Test
    fun `states the value, the source and the click of a result`() {
        host.plugin.deepLinkListenerReady()

        sdk.deepLinkListener?.onDeepLinking(
            DeepLinkResult(
                uri = Uri.parse(link(1)),
                queryParams = mapOf("deep_link_value" to "from_query", "color" to "red"),
                isDeferred = false,
                status = DeepLinkStatus.FOUND,
                sub1 = "first",
                sub5 = "fifth",
                isFirstSession = false,
                deepLinkValue = "promo",
                source = DeepLinkSource.META_APPLINK,
                clickId = "click-1",
            )
        )

        val message = host.dart.deepLinks.single()
        assertEquals(DeepLinkStatusMessage.FOUND, message.status)
        assertEquals(link(1), message.deepLink)
        assertEquals("promo", message.deepLinkValue)
        assertEquals(DeepLinkSourceMessage.META_APP_LINK, message.source)
        assertEquals("click-1", message.clickId)
        assertEquals(false, message.isDeferred)
        assertEquals(false, message.isFirstSession)
        assertEquals("first", message.sub1)
        assertNull("sub2", message.sub2)
        assertEquals("fifth", message.sub5)
        assertEquals(
            mapOf(
                "deep_link_value" to "from_query",
                "color" to "red",
                "deep_link_sub1" to "first",
                "deep_link_sub5" to "fifth",
            ),
            message.params,
        )
        assertNull("android states no match quality", message.matchGuaranteed)
        assertNull("error", message.errorMessage)
    }

    @Test
    fun `passes the value on as the sdk states it`() {
        host.plugin.deepLinkListenerReady()

        sdk.deepLinkListener?.onDeepLinking(
            DeepLinkResult(
                uri = Uri.parse(link(1)),
                queryParams = mapOf("deep_link_value" to "from_query"),
                isDeferred = true,
                status = DeepLinkStatus.FOUND,
            )
        )

        val message = host.dart.deepLinks.single()
        assertNull("value", message.deepLinkValue)
        assertEquals(mapOf("deep_link_value" to "from_query"), message.params)
    }

    @Test
    fun `leaves out the source and the click when the sdk states none`() {
        host.plugin.deepLinkListenerReady()

        result(link(1))

        val message = host.dart.deepLinks.single()
        assertNull("source", message.source)
        assertNull("click", message.clickId)
        assertEquals(emptyMap<String, String>(), message.params)
    }

    @Test
    fun `states why a link has no answer yet`() {
        host.plugin.deepLinkListenerReady()

        sdk.deepLinkListener?.onDeepLinking(
            DeepLinkResult(
                uri = Uri.parse(link(1)),
                isDeferred = false,
                status = DeepLinkStatus.ERROR,
                error = DeepLinkError.HTTP_STATUS_CODE,
                source = DeepLinkSource.APP_LINK,
            )
        )

        val message = host.dart.deepLinks.single()
        assertEquals(DeepLinkStatusMessage.ERROR, message.status)
        assertEquals("http status code", message.errorMessage)
        assertEquals(DeepLinkSourceMessage.APP_LINK, message.source)
    }

    @Test
    fun `sends a result from another thread on the main thread`() {
        host.plugin.deepLinkListenerReady()

        val thread = Thread { result(link(1)) }
        thread.start()
        thread.join()
        assertEquals("sent off the main thread", emptyList<String>(), host.dart.links)
        idle()

        assertEquals(listOf(link(1)), host.dart.links)
    }

    private fun result(url: String, isDeferred: Boolean = false) {
        sdk.deepLinkListener?.onDeepLinking(deepLinkResult(url, isDeferred))
    }

    private fun link(index: Int) = "https://$BRANDED_DOMAIN/open/$index"

    private companion object {
        const val LIMIT = 20
        const val DISPATCHED = 25
    }
}
