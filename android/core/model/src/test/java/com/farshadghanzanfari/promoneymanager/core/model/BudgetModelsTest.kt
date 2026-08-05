package com.farshadghanzanfari.promoneymanager.core.model

import com.google.common.truth.Truth.assertThat
import java.time.YearMonth
import org.junit.Assert.assertThrows
import org.junit.Test

class BudgetModelsTest {
    private val aed = CurrencyCode.of("AED")

    @Test
    fun budgetRequiresPositiveAmount() {
        val error = assertThrows(MoneyFormatException::class.java) {
            Budget(
                id = BudgetId("budget-food"),
                categoryId = CategoryId("food"),
                month = YearMonth.of(2026, 6),
                amount = Money.zero(aed),
            )
        }

        assertThat(error).hasMessageThat().contains("greater than zero")
    }

    @Test
    fun budgetStoresCategorySubcategoryMonthAndRollover() {
        val budget = Budget(
            id = BudgetId("budget-groceries"),
            categoryId = CategoryId("food"),
            subcategoryId = CategoryId("groceries"),
            month = YearMonth.of(2026, 6),
            amount = Money(50_000, aed),
            rolloverEnabled = true,
            isArchived = false,
        )

        assertThat(budget.categoryId).isEqualTo(CategoryId("food"))
        assertThat(budget.subcategoryId).isEqualTo(CategoryId("groceries"))
        assertThat(budget.month).isEqualTo(YearMonth.of(2026, 6))
        assertThat(budget.rolloverEnabled).isTrue()
    }
}
