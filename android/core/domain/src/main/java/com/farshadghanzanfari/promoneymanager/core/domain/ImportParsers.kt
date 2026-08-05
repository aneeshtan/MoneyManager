package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.ImportFormat
import com.farshadghanzanfari.promoneymanager.core.model.ImportParseException
import com.farshadghanzanfari.promoneymanager.core.model.MerchantRule
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.ParsedImportTransaction
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Locale

object UniversalImportParser {
    private val dateFormatter: DateTimeFormatter = DateTimeFormatter.ofPattern("dd/MM/uuuu")
    private val statementLine = Regex("""^(\d{2}/\d{2}/\d{4})\s+(.+?)\s+(CR|DR)\s+([\d,]+(?:\.\d+)?)$""")
    private val currencyHeader = Regex("""(?i)\bAmount\s+in\s+([A-Z]{3})\b""")
    private val pastedMessage = Regex("""(?i)\b([A-Z]{3})\s+([\d,]+(?:\.\d+)?)\s+(?:spent|paid|debited|credited).*?\bat\s+(.+)$""")

    fun parseText(
        text: String,
        format: ImportFormat,
        accountId: AccountId,
        fallbackCurrency: CurrencyCode,
        rules: List<MerchantRule>,
        existingTransactions: List<Transaction>,
    ): List<ParsedImportTransaction> = when (format) {
        ImportFormat.PDF -> parseStrictStatement(
            text = text,
            accountId = accountId,
            fallbackCurrency = fallbackCurrency,
            rules = rules,
            existingTransactions = existingTransactions,
        ).ifEmpty {
            parsePlainText(text, accountId, fallbackCurrency, rules, existingTransactions, requireDate = true)
        }
        ImportFormat.PLAIN_TEXT -> parsePlainText(
            text,
            accountId,
            fallbackCurrency,
            rules,
            existingTransactions,
            requireDate = true,
        )
        ImportFormat.PASTED_MESSAGE -> parsePastedMessages(
            text,
            accountId,
            fallbackCurrency,
            rules,
            existingTransactions,
        )
        ImportFormat.CSV -> parseCsv(text, accountId, fallbackCurrency, rules, existingTransactions)
        ImportFormat.XLSX,
        ImportFormat.XLS -> throw ImportParseException(
            "Excel files are not parsed directly yet. Export the sheet as CSV and import that file.",
        )
    }.ifEmpty {
        throw ImportParseException("No transaction rows were found.")
    }

    private fun parseStrictStatement(
        text: String,
        accountId: AccountId,
        fallbackCurrency: CurrencyCode,
        rules: List<MerchantRule>,
        existingTransactions: List<Transaction>,
    ): List<ParsedImportTransaction> {
        val currency = detectedCurrency(text, fallbackCurrency)
        return text.lineSequence()
            .mapIndexedNotNull { index, rawLine ->
                val line = rawLine.trim()
                val match = statementLine.matchEntire(line) ?: return@mapIndexedNotNull null
                runCatching {
                    buildRow(
                        date = LocalDate.parse(match.groupValues[1], dateFormatter),
                        merchant = match.groupValues[2].trim(),
                        direction = match.groupValues[3],
                        amountText = match.groupValues[4],
                        currency = currency,
                        accountId = accountId,
                        rules = rules,
                        existingTransactions = existingTransactions,
                        sourceRow = index + 1,
                    )
                }.getOrNull()
            }
            .toList()
    }

    private fun parsePlainText(
        text: String,
        accountId: AccountId,
        fallbackCurrency: CurrencyCode,
        rules: List<MerchantRule>,
        existingTransactions: List<Transaction>,
        requireDate: Boolean,
    ): List<ParsedImportTransaction> =
        text.lineSequence()
            .mapIndexedNotNull { index, rawLine ->
                val line = rawLine.trim()
                if (line.isBlank() || line.isPaginationOrMetadata()) return@mapIndexedNotNull null
                val match = statementLine.matchEntire(line)
                if (match != null) {
                    return@mapIndexedNotNull runCatching {
                        buildRow(
                            date = LocalDate.parse(match.groupValues[1], dateFormatter),
                            merchant = match.groupValues[2].trim(),
                            direction = match.groupValues[3],
                            amountText = match.groupValues[4],
                            currency = fallbackCurrency,
                            accountId = accountId,
                            rules = rules,
                            existingTransactions = existingTransactions,
                            sourceRow = index + 1,
                        )
                    }.getOrNull()
                }
                if (requireDate) null else parsePastedLine(line, accountId, fallbackCurrency, rules, existingTransactions, index + 1)
            }
            .toList()

    private fun parsePastedMessages(
        text: String,
        accountId: AccountId,
        fallbackCurrency: CurrencyCode,
        rules: List<MerchantRule>,
        existingTransactions: List<Transaction>,
    ): List<ParsedImportTransaction> =
        text.lineSequence()
            .mapIndexedNotNull { index, line ->
                parsePastedLine(line.trim(), accountId, fallbackCurrency, rules, existingTransactions, index + 1)
            }
            .toList()

    private fun parsePastedLine(
        line: String,
        accountId: AccountId,
        fallbackCurrency: CurrencyCode,
        rules: List<MerchantRule>,
        existingTransactions: List<Transaction>,
        sourceRow: Int,
    ): ParsedImportTransaction? {
        val match = pastedMessage.find(line) ?: return null
        val currency = runCatching { CurrencyCode.of(match.groupValues[1]) }.getOrDefault(fallbackCurrency)
        return runCatching {
            buildRow(
                date = null,
                merchant = match.groupValues[3].trim(),
                direction = "DR",
                amountText = match.groupValues[2],
                currency = currency,
                accountId = accountId,
                rules = rules,
                existingTransactions = existingTransactions,
                sourceRow = sourceRow,
            )
        }.getOrNull()
    }

    private fun parseCsv(
        text: String,
        accountId: AccountId,
        fallbackCurrency: CurrencyCode,
        rules: List<MerchantRule>,
        existingTransactions: List<Transaction>,
    ): List<ParsedImportTransaction> {
        val lines = text.lineSequence().filter { it.isNotBlank() }.toList()
        if (lines.isEmpty()) return emptyList()
        val headers = splitCsvLine(lines.first()).map { it.lowercase(Locale.ROOT).trim() }

        fun indexOf(vararg names: String): Int? =
            names.firstNotNullOfOrNull { name -> headers.indexOf(name).takeIf { it >= 0 } }

        val dateIndex = indexOf("transaction date", "date") ?: return emptyList()
        val descriptionIndex = indexOf("description", "merchant", "details") ?: return emptyList()
        val debitIndex = indexOf("debit", "withdrawal", "dr")
        val creditIndex = indexOf("credit", "deposit", "cr")
        val amountIndex = indexOf("amount")
        val currencyIndex = indexOf("currency")

        return lines.drop(1).mapIndexedNotNull { index, rawLine ->
            val cells = splitCsvLine(rawLine)
            fun cell(at: Int?): String = at?.let { cells.getOrNull(it) }.orEmpty().trim()

            val merchant = cell(descriptionIndex)
            if (merchant.isBlank()) return@mapIndexedNotNull null
            val date = runCatching { LocalDate.parse(cell(dateIndex), dateFormatter) }.getOrNull()
                ?: return@mapIndexedNotNull null
            val currency = runCatching { CurrencyCode.of(cell(currencyIndex).ifBlank { fallbackCurrency.value }) }
                .getOrDefault(fallbackCurrency)
            val debit = cell(debitIndex)
            val credit = cell(creditIndex)
            val rawAmount = cell(amountIndex)
            val kind: TransactionKind
            val amountText: String
            when {
                debit.isNotBlank() -> {
                    kind = TransactionKind.EXPENSE
                    amountText = debit
                }
                credit.isNotBlank() -> {
                    kind = TransactionKind.INCOME
                    amountText = credit
                }
                rawAmount.startsWith("-") -> {
                    kind = TransactionKind.EXPENSE
                    amountText = rawAmount.removePrefix("-")
                }
                rawAmount.isNotBlank() -> {
                    kind = TransactionKind.INCOME
                    amountText = rawAmount
                }
                else -> return@mapIndexedNotNull null
            }

            runCatching {
                buildRow(
                    date = date,
                    merchant = merchant,
                    direction = if (kind == TransactionKind.INCOME) "CR" else "DR",
                    amountText = amountText,
                    currency = currency,
                    accountId = accountId,
                    rules = rules,
                    existingTransactions = existingTransactions,
                    sourceRow = index + 2,
                )
            }.getOrNull()
        }
    }

    private fun buildRow(
        date: LocalDate?,
        merchant: String,
        direction: String,
        amountText: String,
        currency: CurrencyCode,
        accountId: AccountId,
        rules: List<MerchantRule>,
        existingTransactions: List<Transaction>,
        sourceRow: Int,
    ): ParsedImportTransaction {
        val kind = if (direction == "CR") TransactionKind.INCOME else TransactionKind.EXPENSE
        val amount = Money.parseStrict(amountText, currency)
        val normalized = MerchantNormalizer.normalize(merchant)
        val suggestion = CategoryMatcher.match(
            merchant = normalized,
            rules = rules,
            fallbackKind = kind,
        )
        val duplicate = date != null && existingTransactions.any { transaction ->
            transaction.accountId == accountId &&
                transaction.localDate == date &&
                transaction.amount == amount &&
                MerchantNormalizer.normalize(
                    transaction.normalizedMerchant.ifBlank { transaction.merchant },
                ) == normalized
        }
        val reviewOnly = kind == TransactionKind.INCOME && normalized.contains("CASHBACK")
        return ParsedImportTransaction(
            localDate = date,
            merchant = merchant,
            normalizedMerchant = normalized,
            kind = suggestion?.kind ?: kind,
            amount = amount,
            suggestedCategoryId = suggestion?.categoryId,
            suggestedSubcategoryId = suggestion?.subcategoryId,
            confidence = suggestion?.confidence ?: 0.0,
            isSelected = !duplicate && !reviewOnly,
            isDuplicate = duplicate,
            isReviewOnly = reviewOnly,
            sourceRow = sourceRow,
        )
    }

    private fun detectedCurrency(text: String, fallbackCurrency: CurrencyCode): CurrencyCode =
        currencyHeader.find(text)?.groupValues?.getOrNull(1)
            ?.let { code -> runCatching { CurrencyCode.of(code) }.getOrNull() }
            ?: fallbackCurrency

    private fun String.isPaginationOrMetadata(): Boolean {
        if (matches(Regex("""\d+"""))) return true
        if (startsWith("Page ", ignoreCase = true)) return true
        if (startsWith("Statement Date", ignoreCase = true)) return true
        if (startsWith("Statement Period", ignoreCase = true)) return true
        return false
    }

    private fun splitCsvLine(line: String): List<String> {
        val cells = mutableListOf<String>()
        val current = StringBuilder()
        var inQuotes = false
        for (char in line) {
            when {
                char == '"' -> inQuotes = !inQuotes
                char == ',' && !inQuotes -> {
                    cells += current.toString().trim().trim('"')
                    current.clear()
                }
                else -> current.append(char)
            }
        }
        cells += current.toString().trim().trim('"')
        return cells
    }
}
