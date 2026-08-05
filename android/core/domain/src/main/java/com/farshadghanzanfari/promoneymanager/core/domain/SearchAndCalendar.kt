package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import java.time.LocalDate
import java.time.YearMonth
import java.util.Locale

data class SearchQuery(
    val text: String,
    val onlyUncategorized: Boolean = false,
)

data class SearchResult(
    val id: String,
    val label: String,
    val type: SearchResultType,
    val suggestedCategoryId: CategoryId? = null,
)

enum class SearchResultType {
    TRANSACTION,
    ACCOUNT,
    CATEGORY,
}

data class SavedSearchFilter(
    val name: String,
    val query: SearchQuery,
)

data class DailyCalendarSummary(
    val date: LocalDate,
    val income: Money,
    val expense: Money,
    val transactionCount: Int,
)

enum class TrendRange(val monthCount: Int) {
    SIX_MONTHS(6),
    TWELVE_MONTHS(12),
    TWENTY_FOUR_MONTHS(24),
}

data class TrendBucket(
    val month: YearMonth,
    val income: Money,
    val expense: Money,
    val net: Money,
)

object SearchAndCalendar {
    fun search(
        query: SearchQuery,
        transactions: List<Transaction>,
        accounts: List<Account>,
        categories: List<Category>,
    ): List<SearchResult> {
        val normalizedQuery = query.text.trim().lowercase(Locale.ROOT)

        val transactionResults = transactions
            .filter { transaction ->
                val matchesText = normalizedQuery.isBlank() ||
                    transaction.merchant.contains(normalizedQuery, ignoreCase = true) ||
                    transaction.note.contains(normalizedQuery, ignoreCase = true) ||
                    transaction.normalizedMerchant.contains(normalizedQuery, ignoreCase = true)
                val matchesUncategorized = !query.onlyUncategorized || transaction.categoryId == null
                matchesText && matchesUncategorized
            }
            .map { transaction ->
                SearchResult(
                    id = transaction.id.value,
                    label = transaction.merchant,
                    type = SearchResultType.TRANSACTION,
                    suggestedCategoryId = if (transaction.categoryId == null) {
                        CategoryMatcher.match(
                            merchant = transaction.normalizedMerchant.ifBlank { transaction.merchant },
                            rules = emptyList(),
                            fallbackKind = transaction.kind,
                        )?.categoryId
                    } else {
                        null
                    },
                )
            }

        if (query.onlyUncategorized) return transactionResults

        val accountResults = accounts
            .filter { normalizedQuery.isNotBlank() && it.name.contains(normalizedQuery, ignoreCase = true) }
            .map {
                SearchResult(
                    id = it.id.value,
                    label = it.name,
                    type = SearchResultType.ACCOUNT,
                )
            }

        val categoryResults = categories
            .filter { normalizedQuery.isNotBlank() && it.name.contains(normalizedQuery, ignoreCase = true) }
            .map {
                SearchResult(
                    id = it.id.value,
                    label = it.name,
                    type = SearchResultType.CATEGORY,
                )
            }

        return transactionResults + accountResults + categoryResults
    }

    fun calendarSummaries(
        month: YearMonth,
        transactions: List<Transaction>,
    ): List<DailyCalendarSummary> =
        transactions
            .filter { YearMonth.from(it.localDate) == month }
            .groupBy { it.localDate to it.amount.currency }
            .map { (key, dayTransactions) ->
                val (date, currency) = key
                DailyCalendarSummary(
                    date = date,
                    income = dayTransactions
                        .filter { it.kind == TransactionKind.INCOME }
                        .sumMoney(currency),
                    expense = dayTransactions
                        .filter { it.kind == TransactionKind.EXPENSE }
                        .sumMoney(currency),
                    transactionCount = dayTransactions.size,
                )
            }
            .sortedBy { it.date }

    fun trends(
        endMonth: YearMonth,
        range: TrendRange,
        transactions: List<Transaction>,
    ): List<TrendBucket> {
        val startMonth = endMonth.minusMonths((range.monthCount - 1).toLong())
        val months = (0 until range.monthCount).map { startMonth.plusMonths(it.toLong()) }
        val currency = transactions
            .firstOrNull { YearMonth.from(it.localDate) in startMonth..endMonth }
            ?.amount
            ?.currency
            ?: transactions.firstOrNull()?.amount?.currency
            ?: CurrencyCode.of("AED")

        return months.map { month ->
            val monthTransactions = transactions.filter {
                YearMonth.from(it.localDate) == month && it.amount.currency == currency
            }
            val income = monthTransactions
                .filter { it.kind == TransactionKind.INCOME }
                .sumMoney(currency)
            val expense = monthTransactions
                .filter { it.kind == TransactionKind.EXPENSE }
                .sumMoney(currency)
            TrendBucket(
                month = month,
                income = income,
                expense = expense,
                net = income - expense,
            )
        }
    }

    private fun List<Transaction>.sumMoney(currency: CurrencyCode): Money =
        fold(Money.zero(currency)) { total, transaction -> total + transaction.amount }
}
