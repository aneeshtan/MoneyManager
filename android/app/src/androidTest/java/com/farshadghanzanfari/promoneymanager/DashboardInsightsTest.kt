package com.farshadghanzanfari.promoneymanager

import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.onFirst
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollToNode
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.farshadghanzanfari.promoneymanager.core.designsystem.ProMoneyManagerTheme
import com.farshadghanzanfari.promoneymanager.core.domain.MerchantNormalizer
import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.farshadghanzanfari.promoneymanager.core.model.Budget
import com.farshadghanzanfari.promoneymanager.core.model.BudgetId
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import java.time.LocalDate
import java.time.YearMonth
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class DashboardInsightsTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun statsShowsDashboardBudgetsInsightsAndMoreAnalysisPanels() {
        val aed = CurrencyCode.of("AED")
        val state = AppUiState(
            hasWorkspace = true,
            accounts = listOf(Account(AccountId("cash"), "Cash", aed, Money.zero(aed), AccountType.CASH)),
            categories = listOf(
                Category(CategoryId("food"), "Food", TransactionKind.EXPENSE),
                Category(CategoryId("transport"), "Transportation", TransactionKind.EXPENSE),
            ),
            budgets = listOf(
                Budget(
                    id = BudgetId("budget-food"),
                    categoryId = CategoryId("food"),
                    month = YearMonth.of(2026, 6),
                    amount = Money(20_000, aed),
                ),
            ),
            transactions = listOf(
                transaction("salary", "Salary", Money(100_000, aed), TransactionKind.INCOME),
                transaction("grocery", "Amazon Grocery", Money(12_000, aed), categoryId = "food", note = "weekly grocery"),
                transaction("taxi", "Dubai Taxi", Money(3_000, aed), categoryId = "transport"),
            ),
        )

        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = state,
                    onContinueOnDevice = {},
                )
            }
        }

        composeRule.onNodeWithText("AED 1,000.00").assertIsDisplayed()
        composeRule.onNodeWithText("AED 150.00").assertIsDisplayed()
        composeRule.onAllNodesWithText("AED 850.00").onFirst().assertIsDisplayed()
        val statsList = composeRule.onNodeWithTag("stats-list")
        statsList.performScrollToNode(hasText("AED 120.00 · 80%"))
        composeRule.onNodeWithText("AED 120.00 · 80%").assertIsDisplayed()
        statsList.performScrollToNode(hasText("AED 80.00 left · 60%"))
        composeRule.onNodeWithText("AED 80.00 left · 60%").assertIsDisplayed()
        statsList.performScrollToNode(hasText("• weekly grocery"))
        composeRule.onNodeWithText("• weekly grocery").assertIsDisplayed()
        statsList.performScrollToNode(hasText("Local insights"))
        composeRule.onNodeWithText("Local insights").assertIsDisplayed()

        composeRule.onNodeWithText("More").performClick()
        composeRule.onNodeWithText("Search").performClick()
        composeRule.onNodeWithText("Search tools").assertIsDisplayed()
        composeRule.onNodeWithText("Calendar").performClick()
        composeRule.onNodeWithText("Calendar summaries").assertIsDisplayed()
        composeRule.onNodeWithText("Trends").performClick()
        composeRule.onNodeWithText("Trend ranges").assertIsDisplayed()
        composeRule.onNodeWithText("Budgets").performClick()
        composeRule.onNodeWithText("Budget center").assertIsDisplayed()
    }

    private fun transaction(
        id: String,
        merchant: String,
        amount: Money,
        kind: TransactionKind = TransactionKind.EXPENSE,
        categoryId: String? = null,
        note: String = "",
    ) = Transaction.posting(
        id = id,
        accountId = AccountId("cash"),
        amount = amount,
        kind = kind,
        localDate = LocalDate.parse("2026-06-10"),
        merchant = merchant,
        normalizedMerchant = MerchantNormalizer.normalize(merchant),
        categoryId = categoryId?.let(::CategoryId),
        note = note,
    )
}
