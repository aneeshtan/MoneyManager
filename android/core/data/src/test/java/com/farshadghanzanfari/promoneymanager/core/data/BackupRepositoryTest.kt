package com.farshadghanzanfari.promoneymanager.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.farshadghanzanfari.promoneymanager.core.database.AppDatabase
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.BackupRecordType
import com.farshadghanzanfari.promoneymanager.core.model.Budget
import com.farshadghanzanfari.promoneymanager.core.model.BudgetId
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffPlan
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffStrategy
import com.farshadghanzanfari.promoneymanager.core.model.DebtPlanId
import com.farshadghanzanfari.promoneymanager.core.model.GoalContributionId
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoal
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContribution
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContributionDirection
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalId
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleFrequency
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleId
import com.farshadghanzanfari.promoneymanager.core.model.ScheduledTransaction
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.google.common.truth.Truth.assertThat
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class BackupRepositoryTest {
    private lateinit var database: AppDatabase
    private lateinit var repository: RoomWorkspaceRepository
    private val aed = CurrencyCode.of("AED")

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            AppDatabase::class.java,
        ).allowMainThreadQueries().build()
        repository = RoomWorkspaceRepository(database, DefaultWorkspaceSeeder(database))
    }

    @After
    fun tearDown() = database.close()

    @Test
    fun completeBackupSnapshotPreviewAndRestoreRoundTrip() = runTest {
        repository.createLocalWorkspace("Local User", aed)
        repository.saveTransaction(
            Transaction.posting(
                id = "tx-grocery",
                accountId = AccountId("cash"),
                amount = Money(12_000, aed),
                kind = TransactionKind.EXPENSE,
                localDate = LocalDate.parse("2026-07-11"),
                merchant = "Amazon Grocery",
                categoryId = CategoryId("category-food"),
            ),
        )
        repository.saveBudget(
            Budget(BudgetId("budget-food"), CategoryId("category-food"), YearMonth.of(2026, 7), Money(20_000, aed)),
        )
        repository.saveScheduledTransaction(
            ScheduledTransaction(
                id = ScheduleId("schedule-careem"),
                accountId = AccountId("cash"),
                amount = Money(5_800, aed),
                kind = TransactionKind.EXPENSE,
                merchant = "Careem Hala",
                categoryId = CategoryId("category-transportation"),
                frequency = ScheduleFrequency.MONTHLY,
                nextDate = LocalDate.parse("2026-07-15"),
            ),
        )
        repository.saveSavingsGoal(goal())
        repository.saveSavingsGoalContribution(contribution())
        repository.saveDebtPayoffPlan(debt())

        val snapshot = repository.createCompleteBackupSnapshot(Instant.parse("2026-07-11T00:00:00Z"))
        val preview = repository.previewRestore(snapshot)

        assertThat(preview.canRestore).isTrue()
        assertThat(snapshot.manifest.recordCounts[BackupRecordType.ACCOUNTS]).isEqualTo(4)
        assertThat(snapshot.manifest.recordCounts[BackupRecordType.TRANSACTIONS]).isEqualTo(1)
        assertThat(snapshot.manifest.recordCounts[BackupRecordType.SCHEDULED_TRANSACTIONS]).isEqualTo(1)
        assertThat(snapshot.manifest.recordCounts[BackupRecordType.SAVINGS_GOAL_CONTRIBUTIONS]).isEqualTo(1)

        repository.clearWorkspace()
        assertThat(repository.observeAccounts().first()).isEmpty()

        repository.restoreCompleteBackup(snapshot)

        assertThat(repository.observeAccounts().first()).hasSize(4)
        assertThat(repository.observeTransactions().first().single().merchant).isEqualTo("Amazon Grocery")
        assertThat(repository.observeScheduledTransactions().first().single().merchant).isEqualTo("Careem Hala")
        assertThat(repository.observeSavingsGoals().first().single().name).isEqualTo("Emergency fund")
        assertThat(repository.observeSavingsGoalContributions().first().single().note).isEqualTo("monthly transfer")
        assertThat(repository.observeDebtPayoffPlans().first().single().name).isEqualTo("Credit card payoff")
    }

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
        note = "monthly transfer",
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
