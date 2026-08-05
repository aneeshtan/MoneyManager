package com.farshadghanzanfari.promoneymanager.core.domain

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class MerchantNormalizerTest {
    @Test
    fun trimsBankNoiseAndLocationSuffixes() {
        assertThat(
            MerchantNormalizer.normalize(
                "Cr.Card XXX1234 used for AED22.00 at CAREEM HALA RIDE Dubai-AE. Avl. Cr.limit is AED1000.00",
            ),
        ).isEqualTo("CAREEM HALA RIDE")

        assertThat(MerchantNormalizer.normalize("NATIONAL TAXI DUBAI ARE"))
            .isEqualTo("NATIONAL TAXI")
    }

    @Test
    fun collapsesPunctuationSpacingAndCase() {
        assertThat(MerchantNormalizer.normalize("  Amazon.ae   Dubai, AE "))
            .isEqualTo("AMAZON.AE")
    }
}
