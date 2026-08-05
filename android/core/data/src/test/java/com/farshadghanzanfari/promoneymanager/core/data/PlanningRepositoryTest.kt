package com.farshadghanzanfari.promoneymanager.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.farshadghanzanfari.promoneymanager.core.database.AppDatabase
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
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
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.google.common.truth.Truth.assertThat
import java.time.LocalDate
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
class PlanningRepositoryTest {
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
    fun savesObservesArchivesAndPostsPlanningRecords() = runTest {
        repository.createLocalWorkspace("Local User", aed)
        val schedule = ScheduledTransaction(
            id = ScheduleId("schedule-careem"),
            accountId = AccountId("cash"),
            amount = Money(5_800, aed),
            kind = TransactionKind.EXPENSE,
            merchant = "Careem Hala",
            normalizedMerchant = "CAREEM HALA",
            categoryId = CategoryId("category-transportation"),
            note = "airport ride",
            frequency = ScheduleFrequency.MONTHLY,
            nextDate = LocalDate.parse("2026-07-15"),
            reminderEnabled = true,
        )
        val goal = SavingsGoal(
            id = SavingsGoalId("goal-emergency"),
            name = "Emergency fund",
            targetAmount = Money(1_000_000, aed),
            currentAmount = Money(125_000, aed),
            targetDate = LocalDate.parse("2026-12-31"),
        )
        val contribution = SavingsGoalContribution(
            id = GoalContributionId("goal-contribution-1"),
            goalId = goal.id,
            amount = Money(25_000, aed),
            direction = SavingsGoalContributionDirection.CONTRIBUTION,
            localDate = LocalDate.parse("2026-07-11"),
            note = "monthly transfer",
        )
        val debt = DebtPayoffPlan(
            id = DebtPlanId("debt-card"),
            name = "Credit card payoff",
            originalBalance = Money(1_000_000, aed),
            currentBalance = Money(600_000, aed),
            annualInterestRateBasisPoints = 0,
            minimumPayment = Money(50_000, aed),
            extraPayment = Money(25_000, aed),
            strategy = DebtPayoffStrategy.SNOWBALL,
        )

        repository.saveScheduledTransaction(schedule)
        repository.saveSavingsGoal(goal)
        repository.saveSavingsGoalContribution(contribution)
        repository.saveDebtPayoffPlan(debt)

        assertThat(repository.observeScheduledTransactions().first().single().merchant)
            .isEqualTo("Careem Hala")
        assertThat(repository.observeSavingsGoals().first().single().targetDate)
            .isEqualTo(LocalDate.parse("2026-12-31"))
        assertThat(repository.observeSavingsGoalContributions().first().single().note)
            .isEqualTo("monthly transfer")
        assertThat(repository.observeDebtPayoffPlans().first().single().strategy)
            .isEqualTo(DebtPayoffStrategy.SNOWBALL)

        val posted = repository.postScheduledTransaction(ScheduleId("schedule-careem"), LocalDate.parse("2026-07-11"))

        assertThat(posted.transaction.source?.sourceName).isEqualTo("Scheduled transaction")
        assertThat(repository.observeTransactions().first().single { it.id == posted.transaction.id }.merchant)
            .isEqualTo("Careem Hala")
        assertThat(repository.observeScheduledTransactions().first().single().nextDate)
            .isEqualTo(LocalDate.parse("2026-08-15"))

        repository.setScheduledTransactionArchived(ScheduleId("schedule-careem"), true)
        repository.setSavingsGoalArchived(SavingsGoalId("goal-emergency"), true)
        repository.setDebtPayoffPlanArchived(DebtPlanId("debt-card"), true)

        assertThat(repository.observeScheduledTransactions().first().single().isActive).isFalse()
        assertThat(repository.observeSavingsGoals().first().single().isArchived).isTrue()
        assertThat(repository.observeDebtPayoffPlans().first().single().isArchived).isTrue()
    }
}
