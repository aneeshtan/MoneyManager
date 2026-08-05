package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.Budget
import com.farshadghanzanfari.promoneymanager.core.model.BudgetId
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.google.common.truth.Truth.assertThat
import java.time.LocalDate
import java.time.YearMonth
import org.junit.Test

class BudgetProgressTest {
    private val aed = CurrencyCode.of("AED")
    private val month = YearMonth.of(2026, 6)

    @Test
    fun calculatesSpentRemainingFractionAndOverspentState() {
        val budget = budget(amount = Money(10_000, aed))

        val progress = BudgetProgressCalculator.progress(
            budget = budget,
            transactions = listOf(
                transaction("food-1", Money(4_000, aed), categoryId = "food"),
                transaction("food-2", Money(7_000, aed), categoryId = "food"),
                transaction("salary", Money(99_000, aed), TransactionKind.INCOME, categoryId = "food"),
                transaction("other", Money(2_000, aed), categoryId = "transport"),
            ),
            rolloverFromPrevious = Money.zero(aed),
        )

        assertThat(progress.spent).isEqualTo(Money(11_000, aed))
        assertThat(progress.remaining).isEqualTo(Money(-1_000, aed))
        assertThat(progress.fractionUsed).isEqualTo(1.1)
        assertThat(progress.isOverspent).isTrue()
    }

    @Test
    fun filtersBySubcategoryWhenBudgetTargetsSubcategory() {
        val budget = budget(
            amount = Money(10_000, aed),
            subcategoryId = CategoryId("groceries"),
        )

        val progress = BudgetProgressCalculator.progress(
            budget = budget,
            transactions = listOf(
                transaction("groceries", Money(4_000, aed), categoryId = "food", subcategoryId = "groceries"),
                transaction("coffee", Money(3_000, aed), categoryId = "food", subcategoryId = "coffee"),
            ),
            rolloverFromPrevious = Money.zero(aed),
        )

        assertThat(progress.spent).isEqualTo(Money(4_000, aed))
        assertThat(progress.remaining).isEqualTo(Money(6_000, aed))
        assertThat(progress.isOverspent).isFalse()
    }

    @Test
    fun appliesRolloverOnlyWhenEnabled() {
        val rolloverBudget = budget(amount = Money(10_000, aed), rolloverEnabled = true)
        val fixedBudget = budget(amount = Money(10_000, aed), rolloverEnabled = false)

        val rolloverProgress = BudgetProgressCalculator.progress(
            budget = rolloverBudget,
            transactions = listOf(transaction("food", Money(11_000, aed), categoryId = "food")),
            rolloverFromPrevious = Money(2_000, aed),
        )
        val fixedProgress = BudgetProgressCalculator.progress(
            budget = fixedBudget,
            transactions = listOf(transaction("food", Money(11_000, aed), categoryId = "food")),
            rolloverFromPrevious = Money(2_000, aed),
        )

        assertThat(rolloverProgress.available).isEqualTo(Money(12_000, aed))
        assertThat(rolloverProgress.remaining).isEqualTo(Money(1_000, aed))
        assertThat(fixedProgress.available).isEqualTo(Money(10_000, aed))
        assertThat(fixedProgress.remaining).isEqualTo(Money(-1_000, aed))
    }

    private fun budget(
        amount: Money,
        subcategoryId: CategoryId? = null,
        rolloverEnabled: Boolean = false,
    ) = Budget(
        id = BudgetId("budget-food"),
        categoryId = CategoryId("food"),
        subcategoryId = subcategoryId,
        month = month,
        amount = amount,
        rolloverEnabled = rolloverEnabled,
    )

    private fun transaction(
        id: String,
        amount: Money,
        kind: TransactionKind = TransactionKind.EXPENSE,
        categoryId: String,
        subcategoryId: String? = null,
    ) = Transaction.posting(
        id = id,
        accountId = AccountId("cash"),
        amount = amount,
        kind = kind,
        localDate = LocalDate.parse("2026-06-10"),
        merchant = id,
        categoryId = CategoryId(categoryId),
        subcategoryId = subcategoryId?.let(::CategoryId),
    )
}
