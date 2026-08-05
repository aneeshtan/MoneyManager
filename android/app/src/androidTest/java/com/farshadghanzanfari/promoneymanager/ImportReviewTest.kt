package com.farshadghanzanfari.promoneymanager

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.compose.ui.test.performTextInput
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.farshadghanzanfari.promoneymanager.core.designsystem.ProMoneyManagerTheme
import com.farshadghanzanfari.promoneymanager.core.domain.UniversalImportParser
import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.ImportBatchId
import com.farshadghanzanfari.promoneymanager.core.model.ImportFormat
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.ParsedImportTransaction
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.farshadghanzanfari.promoneymanager.core.model.TransactionSourceMetadata
import java.time.LocalDate
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class ImportReviewTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun canPasteReviewAndSaveImportedStatementRows() {
        val aed = CurrencyCode.of("AED")
        var state by mutableStateOf(
            AppUiState(
                hasWorkspace = true,
                accounts = listOf(
                    Account(AccountId("credit-card"), "Credit Card", aed, Money.zero(aed), AccountType.CREDIT_CARD),
                ),
                categories = listOf(
                    Category(CategoryId("category-transportation"), "Transportation", TransactionKind.EXPENSE),
                    Category(CategoryId("category-salary"), "Salary", TransactionKind.INCOME),
                ),
            ),
        )

        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = state,
                    onContinueOnDevice = {},
                    onImportTextChanged = { state = state.copy(importText = it) },
                    onParseImportText = {
                        state = state.copy(
                            importRows = UniversalImportParser.parseText(
                                text = state.importText,
                                format = ImportFormat.PDF,
                                accountId = AccountId("credit-card"),
                                fallbackCurrency = aed,
                                rules = emptyList(),
                                existingTransactions = state.transactions,
                            ),
                            importStatus = "2 rows ready for review",
                        )
                    },
                    onToggleImportRow = { sourceRow ->
                        state = state.copy(
                            importRows = state.importRows.map { row ->
                                if (row.sourceRow == sourceRow) row.copy(isSelected = !row.isSelected) else row
                            },
                        )
                    },
                    onSaveReviewedImport = {
                        val selected = state.importRows.filter { it.isSelected && !it.isDuplicate }
                        state = state.copy(
                            transactions = selected.mapIndexed { index, row ->
                                Transaction.posting(
                                    id = "imported-$index",
                                    accountId = AccountId("credit-card"),
                                    amount = row.amount,
                                    kind = row.kind,
                                    localDate = row.localDate ?: LocalDate.parse("2026-06-10"),
                                    merchant = row.merchant,
                                    normalizedMerchant = row.normalizedMerchant,
                                    categoryId = row.suggestedCategoryId,
                                    source = TransactionSourceMetadata(
                                        sourceName = "Pasted statement",
                                        sourceRow = row.sourceRow,
                                        rawDescription = row.merchant,
                                        importBatchId = ImportBatchId("ui-test"),
                                    ),
                                )
                            },
                            importStatus = "Saved ${selected.size} imported transactions",
                        )
                    },
                )
            }
        }

        composeRule.onNodeWithText("Import").performClick()
        composeRule.onNodeWithText("Choose PDF or file").assertIsDisplayed()
        composeRule.onNodeWithText("Account: Credit Card").assertIsDisplayed()
        composeRule.onNodeWithText("Paste statement text").performTextInput(
            """
            Transaction Date Description Cr/Dr Amount in AED
            10/06/2026 CAREEM HALA RIDE DUBAI ARE DR 58.00
            10/06/2026 5% CASHBACK - GROCERY MAY-26 CR 208.21
            """.trimIndent(),
        )
        composeRule.onNodeWithText("Parse import").performClick()

        composeRule.onNodeWithText("Select clean").assertIsDisplayed()
        composeRule.onNodeWithText("CAREEM HALA RIDE DUBAI ARE").assertIsDisplayed()
        composeRule.onNodeWithText("Review only").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Save selected").performClick()
        composeRule.onNodeWithText("Saved 1 imported transactions").assertIsDisplayed()

        composeRule.onNodeWithText("Transactions").performClick()
        composeRule.onNodeWithText("CAREEM HALA RIDE DUBAI ARE").assertIsDisplayed()
        composeRule.onNodeWithText("Imported from Pasted statement row 2").assertIsDisplayed()
    }
}
