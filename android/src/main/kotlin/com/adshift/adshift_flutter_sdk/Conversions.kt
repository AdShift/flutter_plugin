package com.adshift.adshift_flutter_sdk

import com.adshift.sdk.core.ASAdRevenueData
import com.adshift.sdk.core.ASInAppEventParameterName
import com.adshift.sdk.core.ASMediationNetwork
import com.adshift.sdk.core.ConsentSnapshot
import com.adshift.sdk.core.ConsentSource
import com.adshift.sdk.core.deeplink.DeepLinkResult
import com.adshift.sdk.core.deeplink.DeepLinkSource
import com.adshift.sdk.core.deeplink.DeepLinkStatus

/** The codes the SDK's request listener reports. */
internal object SdkErrorCode {
    const val OPTED_OUT = 12
    const val INVALID_API_KEY = 41
    const val QUEUE_FULL = 51
}

internal fun sdkError(code: Int, message: String) = ErrorMessage(
    code = when (code) {
        SdkErrorCode.OPTED_OUT -> ErrorCodeMessage.OPTED_OUT
        SdkErrorCode.INVALID_API_KEY -> ErrorCodeMessage.INVALID_API_KEY
        SdkErrorCode.QUEUE_FULL -> ErrorCodeMessage.QUEUE_FULL
        else -> ErrorCodeMessage.UNKNOWN
    },
    message = message,
    nativeCode = code.toString(),
)

/**
 * For an exception the SDK threw once initialized. It uses [IllegalArgumentException] both for a
 * refused argument and for a call before initialization, which the plugin rules out beforehand.
 */
internal fun thrownError(e: Exception) = ErrorMessage(
    code = if (e is IllegalArgumentException) ErrorCodeMessage.INVALID_ARGUMENT else ErrorCodeMessage.UNKNOWN,
    message = e.message ?: e.javaClass.simpleName,
)

internal fun Map<String, Any?>.withoutNulls(): Map<String, Any> {
    val out = LinkedHashMap<String, Any>()
    for ((key, value) in this) if (value != null) out[key] = value
    return out
}

internal fun DeepLinkResult.toMessage(): DeepLinkMessage {
    val params = LinkedHashMap(queryParams.orEmpty())
    listOf(sub1, sub2, sub3, sub4, sub5).forEachIndexed { index, sub ->
        if (sub != null) params["deep_link_sub${index + 1}"] = sub
    }
    return DeepLinkMessage(
        status = when (status) {
            DeepLinkStatus.FOUND -> DeepLinkStatusMessage.FOUND
            DeepLinkStatus.NOT_FOUND -> DeepLinkStatusMessage.NOT_FOUND
            DeepLinkStatus.ERROR -> DeepLinkStatusMessage.ERROR
        },
        isDeferred = isDeferred,
        deepLink = uri?.toString(),
        deepLinkValue = deepLinkValue,
        params = params,
        errorMessage = error?.name?.lowercase()?.replace('_', ' '),
        source = when (source) {
            DeepLinkSource.APP_LINK -> DeepLinkSourceMessage.APP_LINK
            DeepLinkSource.SCHEME -> DeepLinkSourceMessage.SCHEME
            DeepLinkSource.CTA -> DeepLinkSourceMessage.CTA
            DeepLinkSource.PUSH -> DeepLinkSourceMessage.PUSH
            DeepLinkSource.META_APPLINK -> DeepLinkSourceMessage.META_APP_LINK
            DeepLinkSource.DEFERRED -> DeepLinkSourceMessage.DEFERRED
            DeepLinkSource.FOREIGN -> DeepLinkSourceMessage.FOREIGN
            null -> null
        },
        clickId = clickId,
        isFirstSession = isFirstSession,
        sub1 = sub1,
        sub2 = sub2,
        sub3 = sub3,
        sub4 = sub4,
        sub5 = sub5,
    )
}

internal fun ConsentSnapshot.toMessage() = ConsentSnapshotMessage(
    source = when (source) {
        ConsentSource.MANUAL -> ConsentSourceMessage.MANUAL
        ConsentSource.TCF -> ConsentSourceMessage.TCF
        ConsentSource.GPP_US_NAT -> ConsentSourceMessage.GPP
        ConsentSource.NONE -> ConsentSourceMessage.NONE
    },
    gdprApplies = gdprApplies?.toLong(),
    tcStringPresent = tcStringPresent,
    gppPresent = gppPresent,
    cmpDetected = cmpDetected,
    adUserDataEnabled = adUserDataEnabled,
    adPersonalizationEnabled = adPersonalizationEnabled,
    adStorageEnabled = adStorageEnabled,
    appliedAtMillis = appliedAtMillis,
    adIdentifiersAllowed = adIdentifiersAllowed(),
)

/**
 * Whether the SDK may attach the advertising id. Under GDPR an undecided flag counts as a
 * refusal; outside it, only an explicit denial does.
 */
private fun ConsentSnapshot.adIdentifiersAllowed(): Boolean =
    if (gdprApplies == 1) {
        adStorageEnabled == true && adUserDataEnabled == true
    } else {
        adStorageEnabled != false && adUserDataEnabled != false
    }

/** A mediation network the SDK does not name is reported as `other`. */
internal fun AdRevenueMessage.toSdkData() = ASAdRevenueData(
    monetizationNetwork = monetizationNetwork,
    mediationNetwork = ASMediationNetwork.entries.firstOrNull { it.networkName == mediationNetwork }
        ?: ASMediationNetwork.OTHER,
    currencyIso4217Code = currency,
    revenue = revenue,
)

/** The four required fields have keys of their own, which `additionalParameters` may not set. */
private val RESERVED_AD_REVENUE_KEYS = setOf(
    ASInAppEventParameterName.REVENUE,
    ASInAppEventParameterName.CURRENCY,
    ASInAppEventParameterName.AD_REVENUE_SOURCE,
    ASInAppEventParameterName.AD_REVENUE_NETWORK_NAME,
)

internal fun AdRevenueMessage.toSdkParameters(): Map<String, Any>? {
    val out = LinkedHashMap<String, Any>()
    additionalParameters?.withoutNulls()?.forEach { (key, value) ->
        if (key !in RESERVED_AD_REVENUE_KEYS) out[key] = value
    }
    adUnitId?.let { out[ASInAppEventParameterName.AD_REVENUE_AD_UNIT_ID] = it }
    precision?.let { out[ASInAppEventParameterName.AD_REVENUE_PRECISION] = it }
    return out.takeIf { it.isNotEmpty() }
}
