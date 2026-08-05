package com.farshadghanzanfari.promoneymanager

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.farshadghanzanfari.promoneymanager.core.designsystem.ProMoneyManagerTheme
import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import java.time.LocalDate
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class PlanningToolsTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun planningToolsCreateRecordsThroughEditors() {
        val aed = CurrencyCode.of("AED")
        var state by mutableStateOf(
            AppUiState(
                hasWorkspace = true,
                accounts = listOf(Account(AccountId("cash"), "Cash", aed, Money.zero(aed), AccountType.CASH)),
                transactions = listOf(
                    expense("tx-netflix-1", "Netflix", 4_900, "2026-04-04", aed),
                    expense("tx-netflix-2", "Netflix", 4_900, "2026-05-04", aed),
                    expense("tx-netflix-3", "Netflix", 5_900, "2026-06-04", aed),
                ),
            ),
        )

        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = state,
                    onContinueOnDevice = {},
                    onSaveSchedule = {
                        state = state.copy(
                            scheduledTransactions = state.scheduledTransactions + it,
                        )
                    },
                    onSaveSavingsGoal = {
                        state = state.copy(savingsGoals = state.savingsGoals + it)
                    },
                    onSaveDebtPlan = {
                        state = state.copy(debtPayoffPlans = state.debtPayoffPlans + it)
                    },
                )
            }
        }

        composeRule.onNodeWithText("More").performClick()

        composeRule.onNodeWithText("Schedule").performClick()
        composeRule.onNodeWithText("Add schedule").performClick()
        composeRule.onNodeWithText("Payee").performTextInput("Careem Hala")
        composeRule.onNodeWithText("Amount").performTextInput("58.00")
        composeRule.onNodeWithText("Save schedule").performClick()
        composeRule.onNodeWithText("Careem Hala").assertIsDisplayed()
        composeRule.onNodeWithText("Reminder disabled").assertIsDisplayed()

        composeRule.onNodeWithText("Goals").performClick()
        composeRule.onNodeWithText("Add goal").performClick()
        composeRule.onNodeWithText("Goal name").performTextInput("Emergency fund")
        composeRule.onNodeWithText("Target amount").performTextInput("10000")
        composeRule.onNodeWithText("Saved so far (optional)").performTextInput("1250")
        composeRule.onNodeWithText("Save goal").performClick()
        composeRule.onNodeWithText("Emergency fund").assertIsDisplayed()
        composeRule.onNodeWithText("AED 8,750.00 remaining").assertIsDisplayed()

        composeRule.onNodeWithText("Debt Payoff").performClick()
        composeRule.onNodeWithText("Add debt plan").performClick()
        composeRule.onNodeWithText("Debt name").performTextInput("Credit card payoff")
        composeRule.onNodeWithText("Current balance").performTextInput("6000")
        composeRule.onNodeWithText("Minimum payment").performTextInput("500")
        composeRule.onNodeWithText("Extra payment (optional)").performTextInput("250")
        composeRule.onNodeWithText("Save debt plan").performClick()
        composeRule.onNodeWithText("Credit card payoff").assertIsDisplayed()
        composeRule.onNodeWithText("Snowball · 8 months").assertIsDisplayed()

        composeRule.onNodeWithText("Subscriptions").performClick()
        composeRule.onNodeWithText("Netflix").assertIsDisplayed()
        composeRule.onNodeWithText("Next expected 2026-07-04").assertIsDisplayed()
        composeRule.onNodeWithText("Price increased").assertIsDisplayed()
    }

    private fun expense(
        id: String,
        merchant: String,
        minorUnits: Long,
        date: String,
        currency: CurrencyCode,
    ) = Transaction.posting(
        id = id,
        accountId = AccountId("cash"),
        amount = Money(minorUnits, currency),
        kind = TransactionKind.EXPENSE,
        localDate = LocalDate.parse(date),
        merchant = merchant,
    )
}
