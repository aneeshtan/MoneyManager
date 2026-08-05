package com.farshadghanzanfari.promoneymanager.core.model

import java.time.YearMonth

data class Budget(
    val id: BudgetId,
    val categoryId: CategoryId,
    val month: YearMonth,
    val amount: Money,
    val subcategoryId: CategoryId? = null,
    val rolloverEnabled: Boolean = false,
    val isArchived: Boolean = false,
) {
    init {
        amount.requirePositiveMagnitude()
    }
}
