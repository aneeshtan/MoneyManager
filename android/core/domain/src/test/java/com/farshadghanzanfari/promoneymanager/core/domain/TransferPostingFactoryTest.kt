package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.TransferDirection
import com.farshadghanzanfari.promoneymanager.core.model.TransferId
import com.google.common.truth.Truth.assertThat
import org.junit.Assert.assertThrows
import org.junit.Test

class TransferPostingFactoryTest {
    private val aed = CurrencyCode.of("AED")

    @Test
    fun createsBalancedSameCurrencyLegs() {
        val result = TransferPostingFactory.create(
            TransferId("transfer"),
            AccountId("source"),
            AccountId("destination"),
            Money(1_000, aed),
            Money(1_000, aed),
        )

        assertThat(result.source.transferDirection).isEqualTo(TransferDirection.OUT)
        assertThat(result.destination.transferDirection).isEqualTo(TransferDirection.IN)
    }

    @Test
    fun preservesBothCrossCurrencyAmounts() {
        val result = TransferPostingFactory.create(
            TransferId("transfer"),
            AccountId("source"),
            AccountId("destination"),
            Money(1_000, aed),
            Money(272, CurrencyCode.of("USD")),
        )

        assertThat(result.destination.amount.minorUnits).isEqualTo(272)
    }

    @Test
    fun rejectsSameAccount() {
        assertThrows(IllegalArgumentException::class.java) {
            TransferPostingFactory.create(
                TransferId("transfer"),
                AccountId("same"),
                AccountId("same"),
                Money(1_000, aed),
                Money(1_000, aed),
            )
        }
    }
}
