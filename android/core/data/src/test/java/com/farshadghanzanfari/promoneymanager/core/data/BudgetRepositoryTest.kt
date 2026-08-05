package com.farshadghanzanfari.promoneymanager.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.farshadghanzanfari.promoneymanager.core.database.AppDatabase
import com.farshadghanzanfari.promoneymanager.core.model.Budget
import com.farshadghanzanfari.promoneymanager.core.model.BudgetId
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.google.common.truth.Truth.assertThat
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
class BudgetRepositoryTest {
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
    fun savesObservesArchivesAndRestoresBudgets() = runTest {
        repository.createLocalWorkspace("Local User", aed)
        repository.saveBudget(
            Budget(
                id = BudgetId("budget-food-june"),
                categoryId = CategoryId("category-food"),
                subcategoryId = CategoryId("category-groceries"),
                month = YearMonth.of(2026, 6),
                amount = Money(50_000, aed),
                rolloverEnabled = true,
            ),
        )

        val saved = repository.observeBudgets().first().single()

        assertThat(saved.id).isEqualTo(BudgetId("budget-food-june"))
        assertThat(saved.month).isEqualTo(YearMonth.of(2026, 6))
        assertThat(saved.amount).isEqualTo(Money(50_000, aed))
        assertThat(saved.rolloverEnabled).isTrue()

        repository.setBudgetArchived(BudgetId("budget-food-june"), true)
        assertThat(repository.observeBudgets().first().single().isArchived).isTrue()

        repository.setBudgetArchived(BudgetId("budget-food-june"), false)
        assertThat(repository.observeBudgets().first().single().isArchived).isFalse()
    }
}
