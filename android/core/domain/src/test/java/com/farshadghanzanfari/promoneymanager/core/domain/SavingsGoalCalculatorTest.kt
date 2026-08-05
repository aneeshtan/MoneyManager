package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyMismatchException
import com.farshadghanzanfari.promoneymanager.core.model.GoalContributionId
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoal
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContribution
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContributionDirection
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalId
import com.google.common.truth.Truth.assertThat
import java.time.LocalDate
import org.junit.Assert.assertThrows
import org.junit.Test

class SavingsGoalCalculatorTest {
    private val aed = CurrencyCode.of("AED")

    @Test
    fun summarizesSavingsProgressAndCompletion() {
        val progress = SavingsGoalCalculator.progress(goal(currentAmount = Money(250_000, aed)))

        assertThat(progress.savedAmount).isEqualTo(Money(250_000, aed))
        assertThat(progress.remainingAmount).isEqualTo(Money(750_000, aed))
        assertThat(progress.percentComplete).isEqualTo(25)
        assertThat(progress.isComplete).isFalse()

        val complete = SavingsGoalCalculator.progress(goal(currentAmount = Money(1_250_000, aed)))
        assertThat(complete.remainingAmount).isEqualTo(Money.zero(aed))
        assertThat(complete.percentComplete).isEqualTo(100)
        assertThat(complete.isComplete).isTrue()
    }

    @Test
    fun appliesContributionAndWithdrawalWithAuditTrail() {
        val goal = goal(currentAmount = Money(25_000, aed))

        val contributed = SavingsGoalCalculator.applyContribution(
            goal = goal,
            contribution = contribution(
                amount = Money(10_000, aed),
                direction = SavingsGoalContributionDirection.CONTRIBUTION,
            ),
        )
        val withdrawn = SavingsGoalCalculator.applyContribution(
            goal = contributed.updatedGoal,
            contribution = contribution(
                id = "goal-contribution-2",
                amount = Money(50_000, aed),
                direction = SavingsGoalContributionDirection.WITHDRAWAL,
            ),
        )

        assertThat(contributed.updatedGoal.currentAmount).isEqualTo(Money(35_000, aed))
        assertThat(contributed.contribution.goalId).isEqualTo(goal.id)
        assertThat(withdrawn.updatedGoal.currentAmount).isEqualTo(Money.zero(aed))
        assertThat(withdrawn.contribution.direction).isEqualTo(SavingsGoalContributionDirection.WITHDRAWAL)
    }

    @Test
    fun rejectsContributionInDifferentCurrency() {
        assertThrows(CurrencyMismatchException::class.java) {
            SavingsGoalCalculator.applyContribution(
                goal = goal(),
                contribution = contribution(amount = Money(10_000, CurrencyCode.of("USD"))),
            )
        }
    }

    private fun goal(
        currentAmount: Money = Money(125_000, aed),
    ) = SavingsGoal(
        id = SavingsGoalId("goal-emergency"),
        name = "Emergency fund",
        targetAmount = Money(1_000_000, aed),
        currentAmount = currentAmount,
        targetDate = LocalDate.parse("2026-12-31"),
    )

    private fun contribution(
        id: String = "goal-contribution-1",
        amount: Money = Money(10_000, aed),
        direction: SavingsGoalContributionDirection = SavingsGoalContributionDirection.CONTRIBUTION,
    ) = SavingsGoalContribution(
        id = GoalContributionId(id),
        goalId = SavingsGoalId("goal-emergency"),
        amount = amount,
        direction = direction,
        localDate = LocalDate.parse("2026-07-11"),
        note = "monthly transfer",
    )
}
