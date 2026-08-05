package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.Transaction

data class DuplicateReviewCandidate(
    val transactions: List<Transaction>,
    val isExact: Boolean,
) {
    val isLikely: Boolean = !isExact
}

object DuplicateReviewService {
    fun candidates(transactions: List<Transaction>): List<DuplicateReviewCandidate> =
        transactions
            .groupBy(::likelyKey)
            .values
            .filter { it.size > 1 }
            .map { group ->
                DuplicateReviewCandidate(
                    transactions = group.sortedBy { it.localDate },
                    isExact = group.map(::exactKey).toSet().size == 1,
                )
            }
            .sortedByDescending { it.transactions.firstOrNull()?.localDate }

    private fun exactKey(transaction: Transaction): String =
        listOf(
            transaction.accountId.value,
            transaction.localDate.toEpochDay().toString(),
            transaction.amount.minorUnits.toString(),
            transaction.amount.currency.value,
            MerchantNormalizer.normalize(
                transaction.normalizedMerchant.ifBlank { transaction.merchant },
            ),
        ).joinToString("|")

    private fun likelyKey(transaction: Transaction): String {
        val merchant = MerchantNormalizer.normalize(
            transaction.normalizedMerchant.ifBlank { transaction.merchant },
        )
        val stableTokens = merchant
            .split(" ")
            .filter { token -> token.isNotBlank() && !token.all { it.isDigit() } }
        val allTokens = merchant.split(" ").filter { it.isNotBlank() }
        val root = (stableTokens.ifEmpty { allTokens }).take(2).joinToString(" ")

        return listOf(
            transaction.accountId.value,
            (transaction.localDate.toEpochDay() / 3).toString(),
            transaction.amount.minorUnits.toString(),
            transaction.amount.currency.value,
            root,
        ).joinToString("|")
    }
}
