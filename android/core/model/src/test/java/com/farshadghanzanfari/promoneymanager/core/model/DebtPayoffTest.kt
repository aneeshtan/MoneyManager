package com.farshadghanzanfari.promoneymanager.core.model

import com.google.common.truth.Truth.assertThat
import org.junit.Assert.assertThrows
import org.junit.Test

class DebtPayoffTest {
    private val aed = CurrencyCode.of("AED")

    @Test
    fun debtPlanRequiresNamePositiveBalancesAndMatchingPaymentCurrency() {
        val blankName = assertThrows(IllegalArgumentException::class.java) {
            plan(name = " ")
        }
        assertThat(blankName).hasMessageThat().contains("name")

        assertThrows(MoneyFormatException::class.java) {
            plan(currentBalance = Money.zero(aed))
        }

        val mismatchedPayment = assertThrows(CurrencyMismatchException::class.java) {
            plan(minimumPayment = Money(50_000, CurrencyCode.of("USD")))
        }
        assertThat(mismatchedPayment).hasMessageThat().contains("AED")
    }

    @Test
    fun debtPlanStoresStrategyAndArchiveState() {
        val archived = plan(
            strategy = DebtPayoffStrategy.AVALANCHE,
            isArchived = true,
        )

        assertThat(archived.strategy).isEqualTo(DebtPayoffStrategy.AVALANCHE)
        assertThat(archived.isArchived).isTrue()
        assertThat(archived.copy(isArchived = false).isArchived).isFalse()
    }

    private fun plan(
        name: String = "Credit card payoff",
        originalBalance: Money = Money(1_000_000, aed),
        currentBalance: Money = Money(600_000, aed),
        minimumPayment: Money = Money(50_000, aed),
        extraPayment: Money = Money(25_000, aed),
        strategy: DebtPayoffStrategy = DebtPayoffStrategy.SNOWBALL,
        isArchived: Boolean = false,
    ) = DebtPayoffPlan(
        id = DebtPlanId("debt-card"),
        name = name,
        originalBalance = originalBalance,
        currentBalance = currentBalance,
        annualInterestRateBasisPoints = 0,
        minimumPayment = minimumPayment,
        extraPayment = extraPayment,
        strategy = strategy,
        isArchived = isArchived,
    )
}
