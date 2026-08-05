package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.NotificationAvailability
import com.farshadghanzanfari.promoneymanager.core.model.ReminderPlan
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleFrequency
import com.farshadghanzanfari.promoneymanager.core.model.ScheduledTransaction
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffPlan
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffStrategy
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffSummary
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoal
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContribution
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContributionDirection
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalProgress
import com.farshadghanzanfari.promoneymanager.core.model.SubscriptionCandidate
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.farshadghanzanfari.promoneymanager.core.model.TransactionSourceMetadata
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId
import kotlin.math.ceil

data class PostedScheduleResult(
    val transaction: Transaction,
    val updatedSchedule: ScheduledTransaction,
)

object ScheduleCalculator {
    fun nextOccurrence(date: LocalDate, frequency: ScheduleFrequency): LocalDate =
        when (frequency) {
            ScheduleFrequency.WEEKLY -> date.plusWeeks(1)
            ScheduleFrequency.BIWEEKLY -> date.plusWeeks(2)
            ScheduleFrequency.MONTHLY -> date.plusMonths(1)
            ScheduleFrequency.QUARTERLY -> date.plusMonths(3)
            ScheduleFrequency.YEARLY -> date.plusYears(1)
        }

    fun reminderPlan(
        schedule: ScheduledTransaction,
        zoneId: ZoneId,
        availability: NotificationAvailability,
    ): ReminderPlan? {
        if (!schedule.isActive || !schedule.reminderEnabled) return null

        return ReminderPlan(
            identifier = "scheduled-${schedule.id.value}",
            scheduledAt = schedule.nextDate.minusDays(1).atTime(LocalTime.of(9, 0)).atZone(zoneId),
            title = "Upcoming ${schedule.merchant}",
            body = "Scheduled ${schedule.kind.name.lowercase()} for ${schedule.amount.currency.value}",
            availability = availability,
        )
    }

    fun postNow(
        schedule: ScheduledTransaction,
        postingDate: LocalDate,
    ): PostedScheduleResult {
        val transaction = Transaction.posting(
            id = "scheduled-${schedule.id.value}-$postingDate",
            accountId = schedule.accountId,
            amount = schedule.amount,
            kind = schedule.kind,
            localDate = postingDate,
            merchant = schedule.merchant,
            normalizedMerchant = schedule.normalizedMerchant,
            note = schedule.note,
            categoryId = schedule.categoryId,
            subcategoryId = schedule.subcategoryId,
            source = TransactionSourceMetadata(
                sourceName = "Scheduled transaction",
                rawDescription = schedule.merchant,
            ),
        )

        return PostedScheduleResult(
            transaction = transaction,
            updatedSchedule = schedule.copy(
                lastRunDate = postingDate,
                nextDate = nextOccurrence(schedule.nextDate, schedule.frequency),
            ),
        )
    }
}

data class AppliedSavingsGoalContribution(
    val updatedGoal: SavingsGoal,
    val contribution: SavingsGoalContribution,
)

object SavingsGoalCalculator {
    fun progress(goal: SavingsGoal): SavingsGoalProgress {
        val remainingMinorUnits =
            (goal.targetAmount.minorUnits - goal.currentAmount.minorUnits).coerceAtLeast(0)
        val percentComplete = ((goal.currentAmount.minorUnits * 100) / goal.targetAmount.minorUnits)
            .coerceIn(0, 100)
            .toInt()

        return SavingsGoalProgress(
            goalId = goal.id,
            savedAmount = goal.currentAmount,
            remainingAmount = goal.currentAmount.copy(minorUnits = remainingMinorUnits),
            percentComplete = percentComplete,
            isComplete = goal.currentAmount.minorUnits >= goal.targetAmount.minorUnits,
        )
    }

    fun applyContribution(
        goal: SavingsGoal,
        contribution: SavingsGoalContribution,
    ): AppliedSavingsGoalContribution {
        require(contribution.goalId == goal.id) { "Contribution goalId must match the savings goal." }
        if (contribution.amount.currency != goal.targetAmount.currency) {
            throw com.farshadghanzanfari.promoneymanager.core.model.CurrencyMismatchException(
                goal.targetAmount.currency,
                contribution.amount.currency,
            )
        }

        val updatedMinorUnits = when (contribution.direction) {
            SavingsGoalContributionDirection.CONTRIBUTION ->
                Math.addExact(goal.currentAmount.minorUnits, contribution.amount.minorUnits)
            SavingsGoalContributionDirection.WITHDRAWAL ->
                (goal.currentAmount.minorUnits - contribution.amount.minorUnits).coerceAtLeast(0)
        }

        return AppliedSavingsGoalContribution(
            updatedGoal = goal.copy(currentAmount = goal.currentAmount.copy(minorUnits = updatedMinorUnits)),
            contribution = contribution,
        )
    }
}

object DebtPayoffCalculator {
    fun summary(plan: DebtPayoffPlan): DebtPayoffSummary {
        val monthlyPayment = plan.minimumPayment + plan.extraPayment
        val percentPaid = (((plan.originalBalance.minorUnits - plan.currentBalance.minorUnits)
            .coerceAtLeast(0) * 100) / plan.originalBalance.minorUnits)
            .coerceIn(0, 100)
            .toInt()
        val monthlyInterest = plan.currentBalance.minorUnits *
            (plan.annualInterestRateBasisPoints / 10_000.0) / 12.0

        if (monthlyPayment.minorUnits <= monthlyInterest) {
            return DebtPayoffSummary(
                planId = plan.id,
                strategyLabel = plan.strategy.label,
                monthlyPayment = monthlyPayment,
                percentPaid = percentPaid,
                estimatedMonthsRemaining = null,
                canAmortize = false,
                warning = "Monthly payment is too low to reduce this debt balance.",
            )
        }

        return DebtPayoffSummary(
            planId = plan.id,
            strategyLabel = plan.strategy.label,
            monthlyPayment = monthlyPayment,
            percentPaid = percentPaid,
            estimatedMonthsRemaining = estimateMonthsRemaining(plan),
            canAmortize = true,
        )
    }

    private fun estimateMonthsRemaining(plan: DebtPayoffPlan): Int {
        if (plan.annualInterestRateBasisPoints == 0) {
            val monthlyPayment = plan.minimumPayment.minorUnits + plan.extraPayment.minorUnits
            return ceil(plan.currentBalance.minorUnits / monthlyPayment.toDouble()).toInt()
        }

        var balance = plan.currentBalance.minorUnits.toDouble()
        val monthlyPayment = plan.minimumPayment.minorUnits + plan.extraPayment.minorUnits
        val monthlyRate = (plan.annualInterestRateBasisPoints / 10_000.0) / 12.0
        var months = 0
        while (balance > 0 && months < 1_200) {
            balance += balance * monthlyRate
            balance -= monthlyPayment
            months += 1
        }
        return months
    }

    private val DebtPayoffStrategy.label: String
        get() = when (this) {
            DebtPayoffStrategy.SNOWBALL -> "Snowball"
            DebtPayoffStrategy.AVALANCHE -> "Avalanche"
        }
}

object SubscriptionDetector {
    fun detect(
        transactions: List<Transaction>,
        asOf: LocalDate,
    ): List<SubscriptionCandidate> =
        transactions
            .asSequence()
            .filter { it.kind == TransactionKind.EXPENSE }
            .filter { !it.localDate.isAfter(asOf) }
            .groupBy { it.normalizedMerchant }
            .values
            .mapNotNull { group -> group.toSubscriptionCandidate() }
            .sortedBy { it.normalizedMerchant }

    private fun List<Transaction>.toSubscriptionCandidate(): SubscriptionCandidate? {
        if (size < 2) return null

        val sorted = sortedBy { it.localDate }
        val uniqueMonths = sorted.map { it.localDate.year to it.localDate.monthValue }.distinct()
        if (uniqueMonths.size < 2) return null

        val first = sorted.first()
        val last = sorted.last()
        val totalMinorUnits = sorted.fold(0L) { sum, transaction ->
            Math.addExact(sum, transaction.amount.minorUnits)
        }
        val average = Money(
            minorUnits = totalMinorUnits / sorted.size,
            currency = first.amount.currency,
        )

        return SubscriptionCandidate(
            merchant = first.merchant,
            normalizedMerchant = first.normalizedMerchant,
            averageAmount = average,
            sampleCount = sorted.size,
            nextExpectedDate = last.localDate.plusMonths(1),
            hasPriceIncrease = last.amount.minorUnits > first.amount.minorUnits,
        )
    }
}
