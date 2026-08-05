package com.farshadghanzanfari.promoneymanager.core.model

import java.time.LocalDate
import java.time.ZonedDateTime

enum class ScheduleFrequency {
    WEEKLY,
    BIWEEKLY,
    MONTHLY,
    QUARTERLY,
    YEARLY,
}

enum class ScheduleStatus {
    ACTIVE,
    PAUSED,
}

enum class NotificationAvailability {
    PERMISSION_GRANTED,
    PERMISSION_DENIED,
    DISABLED_IN_SETTINGS,
}

data class ScheduledTransaction(
    val id: ScheduleId,
    val accountId: AccountId,
    val amount: Money,
    val kind: TransactionKind,
    val merchant: String,
    val normalizedMerchant: String = merchant.trim().uppercase(),
    val categoryId: CategoryId? = null,
    val subcategoryId: CategoryId? = null,
    val note: String = "",
    val frequency: ScheduleFrequency,
    val nextDate: LocalDate,
    val lastRunDate: LocalDate? = null,
    val status: ScheduleStatus = ScheduleStatus.ACTIVE,
    val reminderEnabled: Boolean = false,
) {
    val isActive: Boolean
        get() = status == ScheduleStatus.ACTIVE

    init {
        amount.requirePositiveMagnitude()
        require(merchant.isNotBlank()) { "Scheduled transaction merchant must not be blank." }
        require(subcategoryId == null || categoryId != null) {
            "Scheduled transaction subcategory requires a parent category."
        }
    }
}

data class ReminderPlan(
    val identifier: String,
    val scheduledAt: ZonedDateTime,
    val title: String,
    val body: String,
    val availability: NotificationAvailability,
)

data class SavingsGoal(
    val id: SavingsGoalId,
    val name: String,
    val targetAmount: Money,
    val currentAmount: Money,
    val targetDate: LocalDate? = null,
    val isArchived: Boolean = false,
) {
    init {
        require(name.isNotBlank()) { "Savings goal name must not be blank." }
        targetAmount.requirePositiveMagnitude()
        if (currentAmount.currency != targetAmount.currency) {
            throw CurrencyMismatchException(targetAmount.currency, currentAmount.currency)
        }
        require(currentAmount.minorUnits >= 0) { "Savings goal current amount must not be negative." }
    }
}

enum class SavingsGoalContributionDirection {
    CONTRIBUTION,
    WITHDRAWAL,
}

data class SavingsGoalContribution(
    val id: GoalContributionId,
    val goalId: SavingsGoalId,
    val amount: Money,
    val direction: SavingsGoalContributionDirection,
    val localDate: LocalDate,
    val note: String = "",
) {
    init {
        amount.requirePositiveMagnitude()
    }
}

data class SavingsGoalProgress(
    val goalId: SavingsGoalId,
    val savedAmount: Money,
    val remainingAmount: Money,
    val percentComplete: Int,
    val isComplete: Boolean,
)

enum class DebtPayoffStrategy {
    SNOWBALL,
    AVALANCHE,
}

data class DebtPayoffPlan(
    val id: DebtPlanId,
    val name: String,
    val originalBalance: Money,
    val currentBalance: Money,
    val annualInterestRateBasisPoints: Int,
    val minimumPayment: Money,
    val extraPayment: Money,
    val strategy: DebtPayoffStrategy,
    val isArchived: Boolean = false,
) {
    init {
        require(name.isNotBlank()) { "Debt payoff name must not be blank." }
        originalBalance.requirePositiveMagnitude()
        currentBalance.requirePositiveMagnitude()
        minimumPayment.requirePositiveMagnitude()
        require(extraPayment.minorUnits >= 0) { "Debt payoff extra payment must not be negative." }
        require(annualInterestRateBasisPoints >= 0) {
            "Debt payoff annual interest rate must not be negative."
        }
        if (currentBalance.currency != originalBalance.currency) {
            throw CurrencyMismatchException(originalBalance.currency, currentBalance.currency)
        }
        if (minimumPayment.currency != originalBalance.currency) {
            throw CurrencyMismatchException(originalBalance.currency, minimumPayment.currency)
        }
        if (extraPayment.currency != originalBalance.currency) {
            throw CurrencyMismatchException(originalBalance.currency, extraPayment.currency)
        }
    }
}

data class DebtPayoffSummary(
    val planId: DebtPlanId,
    val strategyLabel: String,
    val monthlyPayment: Money,
    val percentPaid: Int,
    val estimatedMonthsRemaining: Int?,
    val canAmortize: Boolean,
    val warning: String? = null,
)

data class SubscriptionCandidate(
    val merchant: String,
    val normalizedMerchant: String,
    val averageAmount: Money,
    val sampleCount: Int,
    val nextExpectedDate: LocalDate,
    val hasPriceIncrease: Boolean,
)
