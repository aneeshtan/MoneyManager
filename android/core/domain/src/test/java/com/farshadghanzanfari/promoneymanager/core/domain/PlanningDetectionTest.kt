package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffPlan
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffStrategy
import com.farshadghanzanfari.promoneymanager.core.model.DebtPlanId
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.google.common.truth.Truth.assertThat
import java.time.LocalDate
import org.junit.Test

class PlanningDetectionTest {
    private val aed = CurrencyCode.of("AED")

    @Test
    fun summarizesDebtPayoffProgressAndEstimatedMonths() {
        val summary = DebtPayoffCalculator.summary(
            plan = plan(
                originalBalance = Money(1_000_000, aed),
                currentBalance = Money(600_000, aed),
                minimumPayment = Money(50_000, aed),
                extraPayment = Money(25_000, aed),
                annualInterestRateBasisPoints = 0,
            ),
        )

        assertThat(summary.strategyLabel).isEqualTo("Snowball")
        assertThat(summary.monthlyPayment).isEqualTo(Money(75_000, aed))
        assertThat(summary.percentPaid).isEqualTo(40)
        assertThat(summary.estimatedMonthsRemaining).isEqualTo(8)
        assertThat(summary.canAmortize).isTrue()
        assertThat(summary.warning).isNull()
    }

    @Test
    fun flagsDebtPlanThatCannotAmortize() {
        val summary = DebtPayoffCalculator.summary(
            plan = plan(
                currentBalance = Money(1_000_000, aed),
                minimumPayment = Money(1_000, aed),
                extraPayment = Money.zero(aed),
                annualInterestRateBasisPoints = 2_400,
            ),
        )

        assertThat(summary.canAmortize).isFalse()
        assertThat(summary.estimatedMonthsRemaining).isNull()
        assertThat(summary.warning).contains("payment")
    }

    @Test
    fun detectsRepeatedMonthlySubscriptionAndPriceIncrease() {
        val candidates = SubscriptionDetector.detect(
            transactions = listOf(
                expense("tx-netflix-1", "Netflix", 4_900, "2026-04-04"),
                expense("tx-netflix-2", "Netflix", 4_900, "2026-05-04"),
                expense("tx-netflix-3", "Netflix", 5_900, "2026-06-04"),
                expense("tx-groceries", "Carrefour", 23_000, "2026-06-05"),
            ),
            asOf = LocalDate.parse("2026-07-11"),
        )

        assertThat(candidates).hasSize(1)
        assertThat(candidates.first().merchant).isEqualTo("Netflix")
        assertThat(candidates.first().sampleCount).isEqualTo(3)
        assertThat(candidates.first().averageAmount).isEqualTo(Money(5_233, aed))
        assertThat(candidates.first().nextExpectedDate).isEqualTo(LocalDate.parse("2026-07-04"))
        assertThat(candidates.first().hasPriceIncrease).isTrue()
    }

    private fun plan(
        originalBalance: Money = Money(1_000_000, aed),
        currentBalance: Money = Money(600_000, aed),
        minimumPayment: Money = Money(50_000, aed),
        extraPayment: Money = Money(25_000, aed),
        annualInterestRateBasisPoints: Int = 0,
        strategy: DebtPayoffStrategy = DebtPayoffStrategy.SNOWBALL,
    ) = DebtPayoffPlan(
        id = DebtPlanId("debt-card"),
        name = "Credit card payoff",
        originalBalance = originalBalance,
        currentBalance = currentBalance,
        annualInterestRateBasisPoints = annualInterestRateBasisPoints,
        minimumPayment = minimumPayment,
        extraPayment = extraPayment,
        strategy = strategy,
    )

    private fun expense(
        id: String,
        merchant: String,
        minorUnits: Long,
        localDate: String,
    ) = Transaction.posting(
        id = id,
        accountId = AccountId("credit-card"),
        amount = Money(minorUnits, aed),
        kind = TransactionKind.EXPENSE,
        localDate = LocalDate.parse(localDate),
        merchant = merchant,
    )
}
