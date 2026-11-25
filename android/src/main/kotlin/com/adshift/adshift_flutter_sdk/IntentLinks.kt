package com.adshift.adshift_flutter_sdk

import android.content.Intent
import android.net.Uri
import org.json.JSONObject

/** A notification payload nests its link at most this deep, JSON strings included. */
private const val PAYLOAD_SEARCH_DEPTH = 3

private val DEFAULT_PORTS = mapOf("http" to 80, "https" to 443)

/**
 * One spelling for a link, whatever the case of its scheme and host, its percent-escapes and a
 * default port. A link the app passes arrives rewritten by Dart's `Uri`, so the same link read
 * from an Intent can differ from it letter by letter; their keys are equal.
 */
internal fun linkKey(link: String): String {
    val uri = Uri.parse(link)
    val scheme = uri.scheme?.lowercase()
    if (uri.isOpaque) return "$scheme:${uri.schemeSpecificPart}#${uri.fragment}"
    val port = uri.port.takeUnless { it == DEFAULT_PORTS[scheme] } ?: -1
    return listOf(scheme, uri.userInfo, uri.host?.lowercase(), port, uri.path, uri.query, uri.fragment)
        .joinToString("\n")
}

/** Relaunched from Recents: the Intent of an earlier open, not a new tap. */
internal val Intent.isRelaunch: Boolean
    get() = (flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0

/** The [linkKey] of the link [intent] has as its data. */
internal fun dataLinkKey(intent: Intent): String? = intent.dataString?.let(::linkKey)

/** The [linkKey]s of every link [intent] carries. */
internal fun carriedLinkKeys(intent: Intent): Set<String> =
    extrasLinkKeys(intent) + setOfNotNull(dataLinkKey(intent))

/**
 * The [linkKey]s of the links the SDK took from [intent] when handed it: the data of a view
 * Intent, and the links in the extras when it accepted a notification's link from them.
 */
internal fun takenLinkKeys(intent: Intent, pushAccepted: Boolean): Set<String> {
    val keys = linkedSetOf<String>()
    if (intent.action == Intent.ACTION_VIEW) dataLinkKey(intent)?.let { keys += it }
    if (pushAccepted) keys += extrasLinkKeys(intent)
    return keys
}

/**
 * The [linkKey]s of the links in the extras of [intent], where a tapped notification carries its
 * link. Extras that cannot be read carry none.
 */
internal fun extrasLinkKeys(intent: Intent): Set<String> {
    val found = linkedSetOf<String>()
    runCatching {
        val extras = intent.extras ?: return@runCatching
        for (key in extras.keySet()) {
            @Suppress("DEPRECATION")
            collectLinkKeys(extras.get(key), PAYLOAD_SEARCH_DEPTH, found)
        }
    }
    return found
}

/** The [linkKey]s of the links in a notification payload the app passed. */
internal fun payloadLinkKeys(payload: Map<*, *>): Set<String> {
    val found = linkedSetOf<String>()
    payload.values.forEach { collectLinkKeys(it, PAYLOAD_SEARCH_DEPTH, found) }
    return found
}

private fun collectLinkKeys(node: Any?, depth: Int, into: MutableSet<String>) {
    when (node) {
        is String ->
            if (Uri.parse(node).host?.isNotEmpty() == true) {
                into += linkKey(node)
            } else if (depth > 0) {
                runCatching { JSONObject(node) }.getOrNull()?.let { collectLinkKeys(it, depth - 1, into) }
            }
        is JSONObject ->
            if (depth > 0) {
                node.keys().forEach { key -> collectLinkKeys(node.opt(key), depth - 1, into) }
            }
        is Map<*, *> ->
            if (depth > 0) {
                node.values.forEach { collectLinkKeys(it, depth - 1, into) }
            }
    }
}
