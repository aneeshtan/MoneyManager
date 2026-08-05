package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.farshadghanzanfari.promoneymanager.core.model.BackupRecordType
import com.farshadghanzanfari.promoneymanager.core.model.Budget
import com.farshadghanzanfari.promoneymanager.core.model.BudgetId
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffPlan
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffStrategy
import com.farshadghanzanfari.promoneymanager.core.model.DebtPlanId
import com.farshadghanzanfari.promoneymanager.core.model.GoalContributionId
import com.farshadghanzanfari.promoneymanager.core.model.MatchType
import com.farshadghanzanfari.promoneymanager.core.model.MerchantRule
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoal
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContribution
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContributionDirection
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalId
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleFrequency
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleId
import com.farshadghanzanfari.promoneymanager.core.model.ScheduledTransaction
import com.farshadghanzanfari.promoneymanager.core.model.Tag
import com.farshadghanzanfari.promoneymanager.core.model.TagId
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.google.common.truth.Truth.assertThat
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import org.junit.Test

class BackupEngineTest {
    private val aed = CurrencyCode.of("AED")

    @Test
    fun completeSnapshotCountsEveryPersistedRecordType() {
        val snapshot = BackupEngine.completeSnapshot(
            createdAt = Instant.parse("2026-07-11T00:00:00Z"),
            accounts = listOf(Account(AccountId("cash"), "Cash", aed, Money.zero(aed), AccountType.CASH)),
            categories = listOf(Category(CategoryId("food"), "Food", TransactionKind.EXPENSE)),
            tags = listOf(Tag(TagId("business"), "Business")),
            transactions = listOf(transaction()),
            merchantRules = listOf(rule()),
            budgets = listOf(Budget(BudgetId("budget-food"), CategoryId("food"), YearMonth.of(2026, 7), Money(20_000, aed))),
            scheduledTransactions = listOf(schedule()),
            savingsGoals = listOf(goal()),
            savingsGoalContributions = listOf(contribution()),
            debtPayoffPlans = listOf(debt()),
        )

        assertThat(snapshot.manifest.recordCounts)
            .containsAtLeast(
                BackupRecordType.ACCOUNTS, 1,
                BackupRecordType.CATEGORIES, 1,
                BackupRecordType.TAGS, 1,
                BackupRecordType.TRANSACTIONS, 1,
                BackupRecordType.MERCHANT_RULES, 1,
                BackupRecordType.BUDGETS, 1,
                BackupRecordType.SCHEDULED_TRANSACTIONS, 1,
                BackupRecordType.SAVINGS_GOALS, 1,
                BackupRecordType.SAVINGS_GOAL_CONTRIBUTIONS, 1,
                BackupRecordType.DEBT_PAYOFF_PLANS, 1,
            )
        assertThat(snapshot.accounts.single().name).isEqualTo("Cash")
    }

    @Test
    fun legacyIosCompatibilityReportListsUnsupportedRecords() {
        val report = BackupEngine.legacyIosCompatibilityReport(
            snapshot = BackupEngine.completeSnapshot(
                createdAt = Instant.parse("2026-07-11T00:00:00Z"),
                accounts = listOf(Account(AccountId("cash"), "Cash", aed, Money.zero(aed), AccountType.CASH)),
                categories = emptyList(),
                tags = listOf(Tag(TagId("business"), "Business")),
                transactions = listOf(transaction()),
                merchantRules = emptyList(),
                budgets = listOf(Budget(BudgetId("budget-food"), CategoryId("food"), YearMonth.of(2026, 7), Money(20_000, aed))),
                scheduledTransactions = listOf(schedule()),
                savingsGoals = listOf(goal()),
                savingsGoalContributions = listOf(contribution()),
                debtPayoffPlans = listOf(debt()),
            ),
        )

        assertThat(report.canExportWithoutLoss).isFalse()
        assertThat(report.excludedCounts[BackupRecordType.TAGS]).isEqualTo(1)
        assertThat(report.excludedCounts[BackupRecordType.BUDGETS]).isEqualTo(1)
        assertThat(report.excludedCounts[BackupRecordType.SCHEDULED_TRANSACTIONS]).isEqualTo(1)
        assertThat(report.warnings.joinToString()).contains("complete .pmmbackup")
    }

    @Test
    fun restorePreviewBlocksFutureBackupVersions() {
        val preview = BackupEngine.restorePreview(
            schemaVersion = 99,
            recordCounts = mapOf(BackupRecordType.ACCOUNTS to 1),
        )

        assertThat(preview.canRestore).isFalse()
        assertThat(preview.warnings.single()).contains("newer")
    }

    private fun transaction() = Transaction.posting(
        id = "tx-grocery",
        accountId = AccountId("cash"),
        amount = Money(12_000, aed),
        kind = TransactionKind.EXPENSE,
        localDate = LocalDate.parse("2026-07-11"),
        merchant = "Amazon Grocery",
        categoryId = CategoryId("food"),
    )

    private fun rule() = MerchantRule(
        id = "rule-amazon",
        pattern = "AMAZON",
        matchType = MatchType.CONTAINS,
        categoryId = CategoryId("food"),
        kind = TransactionKind.EXPENSE,
        confidence = 0.8,
        sampleCount = 3,
    )

    private fun schedule() = ScheduledTransaction(
        id = ScheduleId("schedule-careem"),
        accountId = AccountId("cash"),
        amount = Money(5_800, aed),
        kind = TransactionKind.EXPENSE,
        merchant = "Careem Hala",
        frequency = ScheduleFrequency.MONTHLY,
        nextDate = LocalDate.parse("2026-07-15"),
    )

    private fun goal() = SavingsGoal(
        id = SavingsGoalId("goal-emergency"),
        name = "Emergency fund",
        targetAmount = Money(1_000_000, aed),
        currentAmount = Money(125_000, aed),
    )

    private fun contribution() = SavingsGoalContribution(
        id = GoalContributionId("goal-contribution-1"),
        goalId = SavingsGoalId("goal-emergency"),
        amount = Money(25_000, aed),
        direction = SavingsGoalContributionDirection.CONTRIBUTION,
        localDate = LocalDate.parse("2026-07-11"),
    )

    private fun debt() = DebtPayoffPlan(
        id = DebtPlanId("debt-card"),
        name = "Credit card payoff",
        originalBalance = Money(1_000_000, aed),
        currentBalance = Money(600_000, aed),
        annualInterestRateBasisPoints = 0,
        minimumPayment = Money(50_000, aed),
        extraPayment = Money(25_000, aed),
        strategy = DebtPayoffStrategy.SNOWBALL,
    )
}
