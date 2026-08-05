package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import java.time.YearMonth

data class MonthlyDashboardSummary(
    val month: YearMonth,
    val totals: List<CurrencyPeriodTotal>,
    val safeToSpend: List<CurrencySafeToSpend>,
    val categoryTotals: List<CategorySpendTotal>,
    val notes: List<String>,
    val insights: List<DashboardInsight>,
)

data class CurrencyPeriodTotal(
    val currency: CurrencyCode,
    val income: Money,
    val expense: Money,
    val net: Money,
)

data class CurrencySafeToSpend(
    val currency: CurrencyCode,
    val amount: Money,
)

data class CategorySpendTotal(
    val categoryId: CategoryId?,
    val amount: Money,
    val subcategoryTotals: List<CategorySpendTotal> = emptyList(),
)

enum class DashboardInsightKind {
    DOMINANT_CATEGORY,
    UNCATEGORIZED,
    SPENDING_INCREASE,
    POSSIBLE_DUPLICATES,
}

data class DashboardInsight(
    val kind: DashboardInsightKind,
    val count: Int = 0,
    // Only populated for DOMINANT_CATEGORY; null means the dominant bucket is "Uncategorized".
    // Callers resolve this to a display name and localized copy - the domain layer must not
    // bake English sentences or raw category ids into UI-facing text.
    val categoryId: CategoryId? = null,
)

object DashboardAnalytics {
    fun monthlySummary(
        month: YearMonth,
        transactions: List<Transaction>,
        currentResources: List<Money>,
        plannedBudgetRemaining: List<Money>,
        scheduledObligations: List<Money>,
    ): MonthlyDashboardSummary {
        val monthTransactions = transactions.filter { YearMonth.from(it.localDate) == month }
        val previousMonthTransactions = transactions.filter { YearMonth.from(it.localDate) == month.minusMonths(1) }

        val totals = periodTotals(monthTransactions)
        val categoryTotals = rankedCategoryTotals(monthTransactions)
        return MonthlyDashboardSummary(
            month = month,
            totals = totals,
            safeToSpend = safeToSpend(
                currentResources = currentResources,
                plannedBudgetRemaining = plannedBudgetRemaining,
                scheduledObligations = scheduledObligations,
            ),
            categoryTotals = categoryTotals,
            notes = monthTransactions.map { it.note.trim() }.filter { it.isNotBlank() }.distinct(),
            insights = insights(
                monthTransactions = monthTransactions,
                previousMonthTransactions = previousMonthTransactions,
                categoryTotals = categoryTotals,
            ),
        )
    }

    private fun periodTotals(transactions: List<Transaction>): List<CurrencyPeriodTotal> {
        val currencies = transactions.map { it.amount.currency }.distinct().sortedBy { it.value }
        return currencies.map { currency ->
            val income = transactions
                .filter { it.amount.currency == currency && it.kind == TransactionKind.INCOME }
                .sumMoney(currency)
            val expense = transactions
                .filter { it.amount.currency == currency && it.kind == TransactionKind.EXPENSE }
                .sumMoney(currency)
            CurrencyPeriodTotal(
                currency = currency,
                income = income,
                expense = expense,
                net = income - expense,
            )
        }
    }

    private fun safeToSpend(
        currentResources: List<Money>,
        plannedBudgetRemaining: List<Money>,
        scheduledObligations: List<Money>,
    ): List<CurrencySafeToSpend> {
        val currencies = (currentResources + plannedBudgetRemaining + scheduledObligations)
            .map { it.currency }
            .distinct()
            .sortedBy { it.value }
        return currencies.map { currency ->
            val resources = currentResources.filter { it.currency == currency }.sumMoneyValues(currency)
            val budgets = plannedBudgetRemaining.filter { it.currency == currency }.sumMoneyValues(currency)
            val obligations = scheduledObligations.filter { it.currency == currency }.sumMoneyValues(currency)
            CurrencySafeToSpend(currency, resources - budgets - obligations)
        }
    }

    private fun rankedCategoryTotals(transactions: List<Transaction>): List<CategorySpendTotal> {
        // Uncategorized expenses (categoryId == null) are kept in their own bucket rather than
        // dropped, so the Stats category breakdown always accounts for 100% of monthly spending
        // (matching the iOS dashboard's "Uncategorized" grouping).
        val expenses = transactions.filter { it.kind == TransactionKind.EXPENSE }
        return expenses
            .groupBy { it.categoryId to it.amount.currency }
            .map { (key, categoryTransactions) ->
                val (categoryId, currency) = key
                val subcategoryTotals = categoryTransactions
                    .filter { it.subcategoryId != null }
                    .groupBy { it.subcategoryId!! to it.amount.currency }
                    .map { (subcategoryKey, subcategoryTransactions) ->
                        CategorySpendTotal(
                            categoryId = subcategoryKey.first,
                            amount = subcategoryTransactions.sumMoney(subcategoryKey.second),
                        )
                    }
                    .sortedByDescending { it.amount.minorUnits }

                CategorySpendTotal(
                    categoryId = categoryId,
                    amount = categoryTransactions.sumMoney(currency),
                    subcategoryTotals = subcategoryTotals,
                )
            }
            .sortedWith(
                compareByDescending<CategorySpendTotal> { it.amount.minorUnits }
                    .thenBy { it.categoryId?.value ?: "" },
            )
    }

    private fun insights(
        monthTransactions: List<Transaction>,
        previousMonthTransactions: List<Transaction>,
        categoryTotals: List<CategorySpendTotal>,
    ): List<DashboardInsight> {
        val insights = mutableListOf<DashboardInsight>()
        val dominantCategory = categoryTotals.firstOrNull()
        if (dominantCategory != null) {
            insights += DashboardInsight(
                kind = DashboardInsightKind.DOMINANT_CATEGORY,
                count = 1,
                categoryId = dominantCategory.categoryId,
            )
        }

        val uncategorizedCount = monthTransactions.count {
            it.kind == TransactionKind.EXPENSE && it.categoryId == null
        }
        if (uncategorizedCount > 0) {
            insights += DashboardInsight(
                kind = DashboardInsightKind.UNCATEGORIZED,
                count = uncategorizedCount,
            )
        }

        val duplicateCount = DuplicateReviewService.candidates(monthTransactions).count()
        if (duplicateCount > 0) {
            insights += DashboardInsight(
                kind = DashboardInsightKind.POSSIBLE_DUPLICATES,
                count = duplicateCount,
            )
        }

        val currentExpenses = periodTotals(monthTransactions).associate { it.currency to it.expense }
        val previousExpenses = periodTotals(previousMonthTransactions).associate { it.currency to it.expense }
        val increasedCurrencies = currentExpenses.count { (currency, currentExpense) ->
            currentExpense.minorUnits > (previousExpenses[currency]?.minorUnits ?: 0L)
        }
        if (increasedCurrencies > 0) {
            insights += DashboardInsight(
                kind = DashboardInsightKind.SPENDING_INCREASE,
                count = increasedCurrencies,
            )
        }

        return insights
    }

    private fun List<Transaction>.sumMoney(currency: CurrencyCode): Money =
        fold(Money.zero(currency)) { total, transaction -> total + transaction.amount }

    private fun List<Money>.sumMoneyValues(currency: CurrencyCode): Money =
        fold(Money.zero(currency)) { total, money -> total + money }
}
