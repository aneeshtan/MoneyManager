package com.farshadghanzanfari.promoneymanager.backup

import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.Tag
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import java.math.BigDecimal

/** Builds the portable transactions CSV, mirroring the iOS ExportService columns that Android records can fill. */
object TransactionsCsvWriter {
    fun build(
        transactions: List<Transaction>,
        accounts: List<Account>,
        categories: List<Category>,
        tags: List<Tag>,
    ): String {
        val accountNames = accounts.associate { it.id to it.name }
        val categoryNames = categories.associate { it.id to it.name }
        val tagNames = tags.associate { it.id to it.name }
        val header = listOf(
            "Date", "Account", "Kind", "Category", "Subcategory", "Merchant",
            "Amount", "Currency", "Note", "Tags", "Source", "SourceRow",
        ).joinToString(",")
        val rows = transactions
            .sortedByDescending { it.localDate }
            .map { transaction ->
                val digits = runCatching { transaction.amount.currency.fractionDigits }.getOrDefault(2)
                listOf(
                    transaction.localDate.toString(),
                    accountNames[transaction.accountId] ?: transaction.accountId.value,
                    transaction.kind.name,
                    transaction.categoryId?.let { categoryNames[it] ?: it.value } ?: "",
                    transaction.subcategoryId?.let { categoryNames[it] ?: it.value } ?: "",
                    transaction.merchant,
                    BigDecimal(transaction.amount.minorUnits).movePointLeft(digits).toPlainString(),
                    transaction.amount.currency.value,
                    transaction.note,
                    transaction.tagIds.joinToString("; ") { tagNames[it] ?: it.value },
                    transaction.source?.sourceName ?: "",
                    transaction.source?.sourceRow?.toString() ?: "",
                ).joinToString(",", transform = ::escape)
            }
        return (listOf(header) + rows).joinToString("\n")
    }

    private fun escape(value: String): String {
        val escaped = value.replace("\"", "\"\"")
        return if (escaped.any { it == ',' || it == '\n' || it == '"' }) "\"$escaped\"" else escaped
    }
}
