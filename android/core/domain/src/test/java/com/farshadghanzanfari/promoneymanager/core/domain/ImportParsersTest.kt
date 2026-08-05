package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.ImportFormat
import com.farshadghanzanfari.promoneymanager.core.model.ImportParseException
import com.farshadghanzanfari.promoneymanager.core.model.MatchType
import com.farshadghanzanfari.promoneymanager.core.model.MerchantRule
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.google.common.truth.Truth.assertThat
import java.time.LocalDate
import org.junit.Assert.assertThrows
import org.junit.Test

class ImportParsersTest {
    private val aed = CurrencyCode.of("AED")
    private val accountId = AccountId("daily-card")
    private val rules = listOf(
        MerchantRule(
            id = "rule-careem",
            pattern = "CAREEM HALA",
            matchType = MatchType.CONTAINS,
            categoryId = CategoryId("transportation"),
            subcategoryId = CategoryId("taxi"),
            kind = TransactionKind.EXPENSE,
            confidence = 0.91,
            sampleCount = 10,
        ),
        MerchantRule(
            id = "rule-agoda",
            pattern = "AGODA",
            matchType = MatchType.CONTAINS,
            categoryId = CategoryId("travel"),
            kind = TransactionKind.EXPENSE,
            confidence = 0.88,
            sampleCount = 3,
        ),
    )

    @Test
    fun parsesStrictStatementLinesAndClassifiesKnownMerchants() {
        val text = """
            Transaction Date Description Cr/Dr Amount in AED
            10/06/2026 CAREEM HALA RIDE DUBAI ARE DR 58.00
            10/06/2026 Amazon.ae DR 265.90
            10/06/2026 5% CASHBACK - GROCERY MAY-26 CR 208.21
            09/06/2026 AGODA.COM DR 1,161.00
        """.trimIndent()

        val rows = UniversalImportParser.parseText(
            text = text,
            format = ImportFormat.PDF,
            accountId = accountId,
            fallbackCurrency = aed,
            rules = rules,
            existingTransactions = emptyList(),
        )

        assertThat(rows).hasSize(4)
        assertThat(rows[0].localDate).isEqualTo(LocalDate.parse("2026-06-10"))
        assertThat(rows[0].merchant).isEqualTo("CAREEM HALA RIDE DUBAI ARE")
        assertThat(rows[0].normalizedMerchant).isEqualTo("CAREEM HALA RIDE")
        assertThat(rows[0].suggestedCategoryId).isEqualTo(CategoryId("transportation"))
        assertThat(rows[0].suggestedSubcategoryId).isEqualTo(CategoryId("taxi"))
        assertThat(rows[1].amount).isEqualTo(Money(26_590, aed))
        assertThat(rows[2].kind).isEqualTo(TransactionKind.INCOME)
        assertThat(rows[2].isReviewOnly).isTrue()
        assertThat(rows[2].isSelected).isFalse()
        assertThat(rows[3].amount).isEqualTo(Money(116_100, aed))
        assertThat(rows[3].suggestedCategoryId).isEqualTo(CategoryId("travel"))
    }

    @Test
    fun detectsCurrencyFromStatementHeader() {
        val rows = UniversalImportParser.parseText(
            text = """
                Transaction Date Description Cr/Dr Amount in USD
                10/06/2026 Coffee Shop DR 12.50
            """.trimIndent(),
            format = ImportFormat.PDF,
            accountId = accountId,
            fallbackCurrency = aed,
            rules = emptyList(),
            existingTransactions = emptyList(),
        )

        assertThat(rows.single().amount).isEqualTo(Money(1_250, CurrencyCode.of("USD")))
    }

    @Test
    fun plainTextRejectsPaginationRowsAndKeepsValidTransactions() {
        val rows = UniversalImportParser.parseText(
            text = """
                10/06/2026 CAREEM HALA RIDE DUBAI ARE DR 58.00
                5
                12
                Page 3 of 12
                Statement Period 01/06/2026 - 10/06/2026
                09/06/2026 AGODA.COM DR 1,161.00
            """.trimIndent(),
            format = ImportFormat.PLAIN_TEXT,
            accountId = accountId,
            fallbackCurrency = aed,
            rules = rules,
            existingTransactions = emptyList(),
        )

        assertThat(rows.map { it.merchant }).containsExactly("CAREEM HALA RIDE DUBAI ARE", "AGODA.COM").inOrder()
    }

    @Test
    fun csvParserReadsCommonHeaders() {
        val rows = UniversalImportParser.parseText(
            text = """
                Transaction Date,Description,Debit,Credit,Currency
                10/06/2026,Coffee Shop,12.50,,USD
                11/06/2026,Salary,,900.00,USD
            """.trimIndent(),
            format = ImportFormat.CSV,
            accountId = accountId,
            fallbackCurrency = aed,
            rules = emptyList(),
            existingTransactions = emptyList(),
        )

        assertThat(rows[0].kind).isEqualTo(TransactionKind.EXPENSE)
        assertThat(rows[0].amount).isEqualTo(Money(1_250, CurrencyCode.of("USD")))
        assertThat(rows[1].kind).isEqualTo(TransactionKind.INCOME)
        assertThat(rows[1].amount).isEqualTo(Money(90_000, CurrencyCode.of("USD")))
    }

    @Test
    fun pastedMessagesCanOmitDate() {
        val rows = UniversalImportParser.parseText(
            text = "AED 58.00 spent at CAREEM HALA RIDE",
            format = ImportFormat.PASTED_MESSAGE,
            accountId = accountId,
            fallbackCurrency = aed,
            rules = rules,
            existingTransactions = emptyList(),
        )

        assertThat(rows.single().localDate).isNull()
        assertThat(rows.single().amount).isEqualTo(Money(5_800, aed))
        assertThat(rows.single().normalizedMerchant).isEqualTo("CAREEM HALA RIDE")
    }

    @Test
    fun duplicateRowsAreUnselected() {
        val existing = listOf(
            Transaction.posting(
                id = "existing",
                accountId = accountId,
                amount = Money(5_800, aed),
                kind = TransactionKind.EXPENSE,
                localDate = LocalDate.parse("2026-06-10"),
                merchant = "CAREEM HALA RIDE",
                normalizedMerchant = "CAREEM HALA RIDE",
            ),
        )

        val rows = UniversalImportParser.parseText(
            text = "10/06/2026 CAREEM HALA RIDE DUBAI ARE DR 58.00",
            format = ImportFormat.PDF,
            accountId = accountId,
            fallbackCurrency = aed,
            rules = rules,
            existingTransactions = existing,
        )

        assertThat(rows.single().isDuplicate).isTrue()
        assertThat(rows.single().isSelected).isFalse()
    }

    @Test
    fun malformedRowIsSkippedInsteadOfFailingWholeImport() {
        // "58.005" has more precision than AED supports (2 fraction digits), which used to
        // throw out of Money.parseStrict and abort the entire batch, discarding every other
        // valid row alongside it. A single garbled line from OCR/copy-paste should not do that.
        val rows = UniversalImportParser.parseText(
            text = """
                10/06/2026 CAREEM HALA RIDE DUBAI ARE DR 58.005
                09/06/2026 AGODA.COM DR 1,161.00
            """.trimIndent(),
            format = ImportFormat.PLAIN_TEXT,
            accountId = accountId,
            fallbackCurrency = aed,
            rules = rules,
            existingTransactions = emptyList(),
        )

        assertThat(rows.map { it.merchant }).containsExactly("AGODA.COM")
    }

    @Test
    fun csvRowWithInvalidCurrencyCodeFallsBackInsteadOfFailingWholeImport() {
        val rows = UniversalImportParser.parseText(
            text = """
                Transaction Date,Description,Debit,Credit,Currency
                10/06/2026,Coffee Shop,12.50,,XXNOTREAL
                11/06/2026,Salary,,900.00,USD
            """.trimIndent(),
            format = ImportFormat.CSV,
            accountId = accountId,
            fallbackCurrency = aed,
            rules = emptyList(),
            existingTransactions = emptyList(),
        )

        assertThat(rows).hasSize(2)
        assertThat(rows[0].amount).isEqualTo(Money(1_250, aed))
        assertThat(rows[1].amount).isEqualTo(Money(90_000, CurrencyCode.of("USD")))
    }

    @Test
    fun rejectsSpreadsheetFormatsWithCsvGuidance() {
        val error = assertThrows(ImportParseException::class.java) {
            UniversalImportParser.parseText(
                text = "",
                format = ImportFormat.XLSX,
                accountId = accountId,
                fallbackCurrency = aed,
                rules = emptyList(),
                existingTransactions = emptyList(),
            )
        }

        assertThat(error).hasMessageThat().contains("CSV")
    }
}
