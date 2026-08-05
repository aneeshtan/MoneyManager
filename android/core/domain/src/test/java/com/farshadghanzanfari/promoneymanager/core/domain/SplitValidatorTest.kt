package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.SplitId
import com.google.common.truth.Truth.assertThat
import org.junit.Test

class SplitValidatorTest {
    private val aed = CurrencyCode.of("AED")

    @Test
    fun acceptsAllocationsThatExactlyEqualParent() {
        val result = SplitValidator.validate(
            Money(1_000, aed),
            listOf(
                SplitAllocation(SplitId("1"), CategoryId("food"), Money(600, aed)),
                SplitAllocation(SplitId("2"), CategoryId("travel"), Money(400, aed)),
            ),
        )

        assertThat(result).isEqualTo(SplitValidation.Valid)
    }

    @Test
    fun rejectsUnderAllocation() {
        val result = SplitValidator.validate(
            Money(1_000, aed),
            listOf(
                SplitAllocation(SplitId("1"), CategoryId("food"), Money(600, aed)),
                SplitAllocation(SplitId("2"), CategoryId("travel"), Money(399, aed)),
            ),
        )

        assertThat(result).isEqualTo(
            SplitValidation.TotalMismatch(expectedMinor = 1_000, actualMinor = 999),
        )
    }

    @Test
    fun rejectsMixedCurrency() {
        val result = SplitValidator.validate(
            Money(1_000, aed),
            listOf(
                SplitAllocation(
                    SplitId("1"),
                    CategoryId("food"),
                    Money(1_000, CurrencyCode.of("USD")),
                ),
            ),
        )

        assertThat(result).isEqualTo(SplitValidation.CurrencyMismatch)
    }
}
