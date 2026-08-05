package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.google.common.truth.Truth.assertThat
import java.time.LocalDate
import java.time.YearMonth
import org.junit.Test

class DashboardAnalyticsTest {
    private val aed = CurrencyCode.of("AED")
    private val usd = CurrencyCode.of("USD")
    private val month = YearMonth.of(2026, 6)

    @Test
    fun monthlyTotalsKeepCurrenciesSeparateAndCalculateNet() {
        val summary = DashboardAnalytics.monthlySummary(
            month = month,
            transactions = listOf(
                transaction("salary", Money(1_000_00, aed), TransactionKind.INCOME),
                transaction("grocery", Money(150_00, aed), TransactionKind.EXPENSE),
                transaction("coffee", Money(25_00, aed), TransactionKind.EXPENSE),
                transaction("usd", Money(12_50, usd), TransactionKind.EXPENSE),
                transaction("last-month", Money(500_00, aed), TransactionKind.INCOME, date = "2026-05-31"),
            ),
            currentResources = listOf(Money(2_000_00, aed), Money(50_00, usd)),
            plannedBudgetRemaining = listOf(Money(400_00, aed)),
            scheduledObligations = listOf(Money(300_00, aed), Money(10_00, usd)),
        )

        assertThat(summary.totals).containsExactly(
            CurrencyPeriodTotal(aed, income = Money(1_000_00, aed), expense = Money(175_00, aed), net = Money(825_00, aed)),
            CurrencyPeriodTotal(usd, income = Money.zero(usd), expense = Money(12_50, usd), net = Money(-12_50, usd)),
        )
        assertThat(summary.safeToSpend).containsExactly(
            CurrencySafeToSpend(aed, Money(1_300_00, aed)),
            CurrencySafeToSpend(usd, Money(40_00, usd)),
        )
    }

    @Test
    fun ranksCategoryTotalsAndCollectsMonthNotes() {
        val summary = DashboardAnalytics.monthlySummary(
            month = month,
            transactions = listOf(
                transaction("food-1", Money(80_00, aed), TransactionKind.EXPENSE, categoryId = "food", note = "weekly grocery"),
                transaction("food-2", Money(20_00, aed), TransactionKind.EXPENSE, categoryId = "food", subcategoryId = "coffee"),
                transaction("taxi", Money(58_00, aed), TransactionKind.EXPENSE, categoryId = "transport"),
                transaction("old-note", Money(1_00, aed), TransactionKind.EXPENSE, note = "old", date = "2026-05-10"),
            ),
            currentResources = emptyList(),
            plannedBudgetRemaining = emptyList(),
            scheduledObligations = emptyList(),
        )

        assertThat(summary.categoryTotals.map { it.categoryId }).containsExactly(
            CategoryId("food"),
            CategoryId("transport"),
        ).inOrder()
        assertThat(summary.categoryTotals.first().amount).isEqualTo(Money(100_00, aed))
        assertThat(summary.categoryTotals.first().subcategoryTotals).containsExactly(
            CategorySpendTotal(CategoryId("coffee"), Money(20_00, aed), emptyList()),
        )
        assertThat(summary.notes).containsExactly("weekly grocery")
    }

    @Test
    fun categoryTotalsIncludeAnUncategorizedBucketInsteadOfDroppingThoseExpenses() {
        val summary = DashboardAnalytics.monthlySummary(
            month = month,
            transactions = listOf(
                transaction("food", Money(80_00, aed), TransactionKind.EXPENSE, categoryId = "food"),
                transaction("no-category-1", Money(50_00, aed), TransactionKind.EXPENSE),
                transaction("no-category-2", Money(20_00, aed), TransactionKind.EXPENSE),
            ),
            currentResources = emptyList(),
            plannedBudgetRemaining = emptyList(),
            scheduledObligations = emptyList(),
        )

        assertThat(summary.categoryTotals.map { it.categoryId }).containsExactly(
            CategoryId("food"),
            null,
        ).inOrder()
        assertThat(summary.categoryTotals.first { it.categoryId == null }.amount).isEqualTo(Money(70_00, aed))
    }

    @Test
    fun createsLocalInsightCards() {
        val transactions = listOf(
            transaction("food-1", Money(80_00, aed), TransactionKind.EXPENSE, categoryId = "food"),
            transaction("food-2", Money(20_00, aed), TransactionKind.EXPENSE, categoryId = "food"),
            transaction("uncategorized", Money(58_00, aed), TransactionKind.EXPENSE),
            transaction("duplicate-a", Money(10_00, aed), TransactionKind.EXPENSE, merchant = "CAFE"),
            transaction("duplicate-b", Money(10_00, aed), TransactionKind.EXPENSE, merchant = "CAFE"),
            transaction("previous", Money(50_00, aed), TransactionKind.EXPENSE, categoryId = "food", date = "2026-05-10"),
        )

        val summary = DashboardAnalytics.monthlySummary(
            month = month,
            transactions = transactions,
            currentResources = emptyList(),
            plannedBudgetRemaining = emptyList(),
            scheduledObligations = emptyList(),
        )

        assertThat(summary.insights.map { it.kind }).containsAtLeast(
            DashboardInsightKind.DOMINANT_CATEGORY,
            DashboardInsightKind.UNCATEGORIZED,
            DashboardInsightKind.SPENDING_INCREASE,
            DashboardInsightKind.POSSIBLE_DUPLICATES,
        )
        assertThat(summary.insights.first { it.kind == DashboardInsightKind.UNCATEGORIZED }.count).isEqualTo(3)
        assertThat(summary.insights.first { it.kind == DashboardInsightKind.POSSIBLE_DUPLICATES }.count).isEqualTo(1)
        // The domain layer must hand back a structured categoryId, not a pre-baked English
        // sentence with a raw id embedded in it - the UI resolves the display name and localizes.
        assertThat(summary.insights.first { it.kind == DashboardInsightKind.DOMINANT_CATEGORY }.categoryId)
            .isEqualTo(CategoryId("food"))
    }

    private fun transaction(
        id: String,
        amount: Money,
        kind: TransactionKind,
        merchant: String = id,
        categoryId: String? = null,
        subcategoryId: String? = null,
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
        categoryId = categoryId?.let(::CategoryId),
        subcategoryId = subcategoryId?.let(::CategoryId),
        note = note,
    )
}
