package com.farshadghanzanfari.promoneymanager.core.model

import com.google.common.truth.Truth.assertThat
import java.time.LocalDate
import org.junit.Assert.assertThrows
import org.junit.Test

class SavingsGoalTest {
    private val aed = CurrencyCode.of("AED")

    @Test
    fun savingsGoalRequiresNameTargetAndCurrentAmountInSameCurrency() {
        val blankName = assertThrows(IllegalArgumentException::class.java) {
            goal(name = " ")
        }
        assertThat(blankName).hasMessageThat().contains("name")

        assertThrows(MoneyFormatException::class.java) {
            goal(targetAmount = Money.zero(aed))
        }

        val usdCurrent = assertThrows(CurrencyMismatchException::class.java) {
            goal(currentAmount = Money(1_000, CurrencyCode.of("USD")))
        }
        assertThat(usdCurrent).hasMessageThat().contains("AED")
    }

    @Test
    fun savingsGoalSupportsArchiveRestoreAndContributionHistoryFields() {
        val contribution = SavingsGoalContribution(
            id = GoalContributionId("goal-contribution-1"),
            goalId = SavingsGoalId("goal-emergency"),
            amount = Money(25_000, aed),
            direction = SavingsGoalContributionDirection.CONTRIBUTION,
            localDate = LocalDate.parse("2026-07-11"),
            note = "monthly transfer",
        )
        val archived = goal(isArchived = true)

        assertThat(contribution.amount).isEqualTo(Money(25_000, aed))
        assertThat(contribution.direction).isEqualTo(SavingsGoalContributionDirection.CONTRIBUTION)
        assertThat(contribution.note).isEqualTo("monthly transfer")
        assertThat(archived.isArchived).isTrue()
        assertThat(archived.copy(isArchived = false).isArchived).isFalse()
    }

    private fun goal(
        name: String = "Emergency fund",
        targetAmount: Money = Money(1_000_000, aed),
        currentAmount: Money = Money(125_000, aed),
        isArchived: Boolean = false,
    ) = SavingsGoal(
        id = SavingsGoalId("goal-emergency"),
        name = name,
        targetAmount = targetAmount,
        currentAmount = currentAmount,
        targetDate = LocalDate.parse("2026-12-31"),
        isArchived = isArchived,
    )
}
