package com.adshift.adshift_flutter_sdk

import com.adshift.sdk.core.AdShiftConsent
import com.adshift.sdk.core.AdShiftLib
import com.adshift.sdk.core.AdShiftThirdPartySharing
import com.adshift.sdk.core.ConsentSnapshot
import com.adshift.sdk.core.ConsentSource
import io.mockk.every
import io.mockk.verify
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

class ConsentTest : BridgeTest() {

    private lateinit var host: Host

    @Before
    fun initialize() {
        host = Host().also { it.initialize() }
    }

    @Test
    fun `allows the advertising id when both flags are granted under gdpr`() {
        assertTrue("allowed", allowed(gdprApplies = 1, storage = true, dataUsage = true))
    }

    @Test
    fun `withholds the advertising id when only one flag is granted under gdpr`() {
        assertFalse("allowed", allowed(gdprApplies = 1, storage = true, dataUsage = false))
        assertFalse("allowed", allowed(gdprApplies = 1, storage = false, dataUsage = true))
    }

    @Test
    fun `treats an undecided flag under gdpr as a refusal`() {
        assertFalse("allowed", allowed(gdprApplies = 1, storage = true, dataUsage = null))
    }

    @Test
    fun `allows the advertising id outside gdpr when nothing was decided`() {
        assertTrue("allowed", allowed(gdprApplies = 0, storage = null, dataUsage = null))
        assertTrue("allowed", allowed(gdprApplies = null, storage = null, dataUsage = null))
    }

    @Test
    fun `honours an explicit denial outside gdpr`() {
        assertFalse("allowed", allowed(gdprApplies = 0, storage = false, dataUsage = true))
    }

    @Test
    fun `reports the rest of the snapshot as the sdk stated it`() {
        val message = refreshConsent(snapshot(gdprApplies = 1, storage = true, dataUsage = false))

        assertEquals(ConsentSourceMessage.MANUAL, message?.source)
        assertEquals(1L, message?.gdprApplies)
        assertEquals(false, message?.tcStringPresent)
        assertEquals(true, message?.gppPresent)
        assertEquals(false, message?.cmpDetected)
        assertEquals(false, message?.adUserDataEnabled)
        assertNull("adPersonalizationEnabled", message?.adPersonalizationEnabled)
        assertEquals(true, message?.adStorageEnabled)
        assertEquals(7L, message?.appliedAtMillis)
    }

    @Test
    fun `forwards that a cmp has run even with nothing decided`() {
        val message = refreshConsent(
            snapshot(gdprApplies = null, storage = null, dataUsage = null, cmpDetected = true)
        )

        assertEquals(true, message?.cmpDetected)
        assertNull("gdprApplies", message?.gdprApplies)
    }

    @Test
    fun `names each source of the consent`() {
        val sources = ConsentSource.entries.associateWith {
            refreshConsent(snapshot(gdprApplies = null, storage = null, dataUsage = null, source = it))?.source
        }

        assertEquals(
            mapOf(
                ConsentSource.MANUAL to ConsentSourceMessage.MANUAL,
                ConsentSource.TCF to ConsentSourceMessage.TCF,
                ConsentSource.GPP_US_NAT to ConsentSourceMessage.GPP,
                ConsentSource.NONE to ConsentSourceMessage.NONE,
            ),
            sources,
        )
    }

    @Test
    fun `answers nothing when the sdk cannot refresh the consent`() {
        every { AdShiftLib.refreshConsent(any(), any()) } throws IllegalStateException("broken")

        assertNull(host.plugin.refreshConsent())
    }

    @Test
    fun `passes the consent with what was not decided left undecided`() {
        host.plugin.setConsentData(
            ConsentMessage(
                isUserSubjectToGdpr = true,
                hasConsentForDataUsage = true,
                hasConsentForAdsPersonalization = null,
                hasConsentForAdStorage = false,
            )
        )
        verify {
            AdShiftLib.setConsentData(
                AdShiftConsent.forGDPRUser(
                    hasConsentForDataUsage = true,
                    hasConsentForAdsPersonalization = null,
                    hasConsentForAdStorage = false,
                )
            )
        }

        host.plugin.setConsentData(ConsentMessage(isUserSubjectToGdpr = false, hasConsentForDataUsage = true))
        verify { AdShiftLib.setConsentData(AdShiftConsent.forNonGDPRUser()) }
    }

    @Test
    fun `states the sharing answer it was given`() {
        host.plugin.setThirdPartySharing(true)
        verify { AdShiftLib.setThirdPartySharing(AdShiftThirdPartySharing.optedOut()) }

        host.plugin.setThirdPartySharing(false)
        verify { AdShiftLib.setThirdPartySharing(AdShiftThirdPartySharing.allowed()) }

        host.plugin.clearThirdPartySharing()
        verify { AdShiftLib.clearThirdPartySharing() }
    }

    @Test
    fun `turns the reading of cmp consent on and off`() {
        host.plugin.enableTcfDataCollection(true)
        host.plugin.enableGppDataCollection(false)

        verify { AdShiftLib.enableTCFDataCollection(true) }
        verify { AdShiftLib.enableGPPDataCollection(false) }
    }

    private fun allowed(gdprApplies: Int?, storage: Boolean?, dataUsage: Boolean?): Boolean =
        refreshConsent(snapshot(gdprApplies, storage, dataUsage))!!.adIdentifiersAllowed

    private fun refreshConsent(snapshot: ConsentSnapshot): ConsentSnapshotMessage? {
        every { AdShiftLib.refreshConsent(any(), any()) } returns snapshot
        return host.plugin.refreshConsent()
    }

    private fun snapshot(
        gdprApplies: Int?,
        storage: Boolean?,
        dataUsage: Boolean?,
        cmpDetected: Boolean = false,
        source: ConsentSource = ConsentSource.MANUAL,
    ) = ConsentSnapshot(
        source = source,
        gdprApplies = gdprApplies,
        tcStringPresent = false,
        gppPresent = true,
        adUserDataEnabled = dataUsage,
        adPersonalizationEnabled = null,
        adStorageEnabled = storage,
        appliedAtMillis = 7L,
        cmpDetected = cmpDetected,
    )
}
