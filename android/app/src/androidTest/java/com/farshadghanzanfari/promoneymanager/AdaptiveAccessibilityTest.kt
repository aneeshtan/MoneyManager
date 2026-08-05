package com.farshadghanzanfari.promoneymanager

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.farshadghanzanfari.promoneymanager.core.designsystem.ProMoneyManagerTheme
import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Tag
import com.farshadghanzanfari.promoneymanager.core.model.TagId
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import java.time.LocalDate
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AdaptiveAccessibilityTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun preservesDestinationPanelFilterAndDraftAcrossRecomposition() {
        var state by mutableStateOf(seedState())
        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = state,
                    onContinueOnDevice = {},
                    onImportTextChanged = { state = state.copy(importText = it) },
                )
            }
        }

        composeRule.onNodeWithText("More").performClick()
        composeRule.onNodeWithText("Search").performClick()
        composeRule.onNodeWithText("Search tools").assertIsDisplayed()
        composeRule.onNodeWithText("Transactions").performClick()
        composeRule.onNodeWithText("Business filter").performClick()
        composeRule.onNodeWithText("Import").performClick()
        composeRule.onNodeWithText("Paste statement text").performTextInput("statement draft")

        state = state.copy(errorMessage = "Recoverable validation failed")

        composeRule.onNodeWithText("Recoverable validation failed").assertIsDisplayed()
        composeRule.onNodeWithText("statement draft").assertIsDisplayed()
    }

    @Test
    fun exposesAccessibleSummariesAndStateLabels() {
        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(state = seedState(), onContinueOnDevice = {})
            }
        }

        composeRule.onNodeWithContentDescription("Monthly totals summary").assertIsDisplayed()
        composeRule.onNodeWithContentDescription("Category share summary").assertIsDisplayed()

        composeRule.onNodeWithText("More").performClick()
        composeRule.onNodeWithText("Privacy").performScrollTo().performClick()
        composeRule.onNodeWithText("Privacy lock").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Delete workspace").performScrollTo().assertIsDisplayed()
        composeRule
            .onNodeWithText("Deletes profile, accounts, categories, transactions, rules, planning records, and local settings.")
            .performScrollTo()
            .assertIsDisplayed()
    }

    @Test
    fun emptyStatesOfferRelevantActions() {
        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = AppUiState(hasWorkspace = true),
                    onContinueOnDevice = {},
                )
            }
        }

        composeRule.onNodeWithText("Transactions").performClick()
        composeRule.onNodeWithText("No transactions yet").assertIsDisplayed()
        composeRule.onNodeWithText("Add your first transaction").assertIsDisplayed()
        composeRule.onNodeWithText("More").performClick()
        composeRule.onNodeWithText("No accounts saved").performScrollTo().assertIsDisplayed()
    }

    private fun seedState(): AppUiState {
        val aed = CurrencyCode.of("AED")
        return AppUiState(
            hasWorkspace = true,
            accounts = listOf(Account(AccountId("cash"), "Cash", aed, Money.zero(aed), AccountType.CASH)),
            tags = listOf(Tag(TagId("business"), "Business", "8151D1")),
            transactions = listOf(
                Transaction.posting(
                    id = "tx-business",
                    accountId = AccountId("cash"),
                    amount = Money(1_250, aed),
                    kind = TransactionKind.EXPENSE,
                    localDate = LocalDate.parse("2026-07-10"),
                    merchant = "Amazon Grocery Dubai",
                    tagIds = listOf(TagId("business")),
                ),
            ),
        )
    }
}
