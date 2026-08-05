package com.farshadghanzanfari.promoneymanager

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
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
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class CrudFlowTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun canCreateAccountCategoryTagAndTransactionThroughEditors() {
        val aed = CurrencyCode.of("AED")
        var state by mutableStateOf(
            AppUiState(
                hasWorkspace = true,
                accounts = listOf(
                    Account(AccountId("cash"), "Cash", aed, Money.zero(aed), AccountType.CASH),
                ),
            ),
        )

        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = state,
                    onContinueOnDevice = {},
                    onSaveAccount = { state = state.copy(accounts = state.accounts + it) },
                    onSaveCategory = { state = state.copy(categories = state.categories + it) },
                    onSaveTag = { state = state.copy(tags = state.tags + it) },
                    onSaveTransaction = {
                        state = state.copy(transactions = state.transactions + it)
                    },
                )
            }
        }

        composeRule.onNodeWithText("More").performClick()

        composeRule.onNodeWithText("Accounts").performClick()
        composeRule.onNodeWithText("Add account").performClick()
        composeRule.onNodeWithText("Account name").performTextInput("Travel Card")
        composeRule.onNodeWithText("Save account").performClick()
        composeRule.onNodeWithText("Travel Card").assertIsDisplayed()

        composeRule.onNodeWithText("Categories").performClick()
        composeRule.onNodeWithText("Add category").performClick()
        composeRule.onNodeWithText("Category name").performTextInput("Food")
        composeRule.onNodeWithText("Save category").performClick()
        composeRule.onNodeWithText("Food · Expense").assertIsDisplayed()

        composeRule.onNodeWithText("Tags").performClick()
        composeRule.onNodeWithText("Add tag").performClick()
        composeRule.onNodeWithText("Tag name").performTextInput("Business")
        composeRule.onNodeWithText("Save tag").performClick()
        composeRule.onNodeWithText("Business").assertIsDisplayed()

        composeRule.onNodeWithText("Transactions").performClick()
        composeRule.onNodeWithContentDescription("Add transaction").performClick()
        composeRule.onNodeWithText("Amount").performTextInput("12.50")
        composeRule.onNodeWithText("Merchant").performTextInput("Amazon Grocery Dubai")
        composeRule.onNodeWithText("Business").performClick()
        composeRule.onNodeWithText("Save transaction").performClick()
        composeRule.onNodeWithText("Amazon Grocery Dubai").assertIsDisplayed()

        composeRule.onNodeWithText("Business filter").performClick()
        composeRule.onNodeWithText("Filtered by Business").assertIsDisplayed()
        composeRule.onNodeWithText("Amazon Grocery Dubai").assertIsDisplayed()
    }
}
