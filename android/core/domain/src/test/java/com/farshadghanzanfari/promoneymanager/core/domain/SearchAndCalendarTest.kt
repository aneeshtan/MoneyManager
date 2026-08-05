package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.google.common.truth.Truth.assertThat
import java.time.LocalDate
import java.time.YearMonth
import org.junit.Test

class SearchAndCalendarTest {
    private val aed = CurrencyCode.of("AED")

    @Test
    fun globalSearchFindsTransactionsAccountsAndCategories() {
        val result = SearchAndCalendar.search(
            query = SearchQuery(text = "food"),
            transactions = listOf(
                transaction("t1", "Amazon Grocery", note = "weekly food", categoryId = "food"),
                transaction("t2", "Dubai Taxi", categoryId = "transport"),
            ),
            accounts = listOf(
                Account(AccountId("cash"), "Cash Wallet", aed, Money.zero(aed), AccountType.CASH),
            ),
            categories = listOf(
                Category(CategoryId("food"), "Food", TransactionKind.EXPENSE),
                Category(CategoryId("transport"), "Transportation", TransactionKind.EXPENSE),
            ),
        )

        assertThat(result.map { it.label }).containsExactly("Amazon Grocery", "Food").inOrder()
    }

    @Test
    fun searchCanReturnUncategorizedSuggestions() {
        val result = SearchAndCalendar.search(
            query = SearchQuery(text = "", onlyUncategorized = true),
            transactions = listOf(
                transaction("uncat", "Careem Hala"),
                transaction("cat", "Amazon Grocery", categoryId = "food"),
            ),
            accounts = emptyList(),
            categories = emptyList(),
        )

        assertThat(result).hasSize(1)
        assertThat(result.single().id).isEqualTo("uncat")
        assertThat(result.single().suggestedCategoryId).isEqualTo(CategoryId("category-transportation"))
    }

    @Test
    fun calendarSummariesAggregateDailyIncomeAndExpense() {
        val summaries = SearchAndCalendar.calendarSummaries(
            month = YearMonth.of(2026, 6),
            transactions = listOf(
                transaction("salary", "Salary", Money(1_000_00, aed), TransactionKind.INCOME, date = "2026-06-01"),
                transaction("food", "Food", Money(50_00, aed), TransactionKind.EXPENSE, date = "2026-06-01"),
                transaction("taxi", "Taxi", Money(20_00, aed), TransactionKind.EXPENSE, date = "2026-06-02"),
                transaction("old", "Old", Money(1_00, aed), TransactionKind.EXPENSE, date = "2026-05-31"),
            ),
        )

        assertThat(summaries).hasSize(2)
        assertThat(summaries[0]).isEqualTo(
            DailyCalendarSummary(
                date = LocalDate.parse("2026-06-01"),
                income = Money(1_000_00, aed),
                expense = Money(50_00, aed),
                transactionCount = 2,
            ),
        )
        assertThat(summaries[1].expense).isEqualTo(Money(20_00, aed))
    }

    @Test
    fun trendBucketsSupportSixTwelveAndTwentyFourMonthRanges() {
        val buckets = SearchAndCalendar.trends(
            endMonth = YearMonth.of(2026, 6),
            range = TrendRange.SIX_MONTHS,
            transactions = listOf(
                transaction("jan", "January", Money(10_00, aed), TransactionKind.EXPENSE, date = "2026-01-15"),
                transaction("jun-income", "June Salary", Money(50_00, aed), TransactionKind.INCOME, date = "2026-06-01"),
                transaction("jun-expense", "June Food", Money(20_00, aed), TransactionKind.EXPENSE, date = "2026-06-02"),
                transaction("old", "Old", Money(99_00, aed), TransactionKind.EXPENSE, date = "2025-12-31"),
            ),
        )

        assertThat(TrendRange.entries.map { it.monthCount }).containsExactly(6, 12, 24).inOrder()
        assertThat(buckets).hasSize(6)
        assertThat(buckets.first().month).isEqualTo(YearMonth.of(2026, 1))
        assertThat(buckets.last()).isEqualTo(
            TrendBucket(
                month = YearMonth.of(2026, 6),
                income = Money(50_00, aed),
                expense = Money(20_00, aed),
                net = Money(30_00, aed),
            ),
        )
    }

    private fun transaction(
        id: String,
        merchant: String,
        amount: Money = Money(1_000, aed),
        kind: TransactionKind = TransactionKind.EXPENSE,
        categoryId: String? = null,
        note: String = "",
        date: String = "2026-06-10",
    ) = Transaction.posting(
        id = id,
        accountId = AccountId("cash"),
        amount = amount,
        kind = kind,
        localDate = LocalDate.parse(date),
        merchant = merchant,
        normalizedMerchant = MerchantNormalizer.normalize(merchant),
        note = note,
        categoryId = categoryId?.let(::CategoryId),
    )
}
