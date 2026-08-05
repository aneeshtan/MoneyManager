package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.MatchType
import com.farshadghanzanfari.promoneymanager.core.model.MerchantRule
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionId
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import kotlin.math.min

data class LearnedMerchantRuleCandidate(
    val pattern: String,
    val matchType: MatchType = MatchType.CONTAINS,
    val categoryId: CategoryId,
    val subcategoryId: CategoryId? = null,
    val kind: TransactionKind,
    val confidence: Double,
    val sampleCount: Int,
)

data class CategorizationPreview(
    val transactionId: TransactionId,
    val normalizedMerchant: String,
    val suggestedCategoryId: CategoryId,
    val suggestedSubcategoryId: CategoryId? = null,
    val confidence: Double,
)

data class CategorizationBulkApplyOperation(
    val transactionId: TransactionId,
    val categoryId: CategoryId,
    val subcategoryId: CategoryId? = null,
)

data class CategorizationBulkApplyPlan(
    val operations: List<CategorizationBulkApplyOperation>,
    val isAtomic: Boolean = true,
)

object SmartCategorizationService {
    fun learnRuleCandidates(
        transactions: List<Transaction>,
        existingRules: List<MerchantRule>,
        minimumSamples: Int = 2,
    ): List<LearnedMerchantRuleCandidate> {
        require(minimumSamples >= 2) { "minimumSamples must be at least 2." }

        return transactions
            .filter { it.categoryId != null && it.kind != TransactionKind.TRANSFER }
            .groupBy { CategoryGroup(it.categoryId!!, it.subcategoryId, it.kind) }
            .flatMap { (categoryGroup, categoryTransactions) ->
                candidatesForGroup(
                    categoryGroup = categoryGroup,
                    transactions = categoryTransactions,
                    existingRules = existingRules,
                    minimumSamples = minimumSamples,
                )
            }
            .sortedWith(
                compareByDescending<LearnedMerchantRuleCandidate> { it.sampleCount }
                    .thenByDescending { it.confidence }
                    .thenBy { it.pattern },
            )
    }

    fun previewCategorization(
        transactions: List<Transaction>,
        rules: List<MerchantRule>,
    ): List<CategorizationPreview> =
        transactions
            .asSequence()
            .filter { it.categoryId == null && it.kind != TransactionKind.TRANSFER }
            .mapNotNull { transaction ->
                val suggestion = CategoryMatcher.match(
                    merchant = transaction.normalizedMerchant.ifBlank { transaction.merchant },
                    accountId = transaction.accountId,
                    note = transaction.note,
                    amount = transaction.amount,
                    rules = rules,
                    fallbackKind = transaction.kind,
                ) ?: return@mapNotNull null

                CategorizationPreview(
                    transactionId = transaction.id,
                    normalizedMerchant = MerchantNormalizer.normalize(transaction.normalizedMerchant.ifBlank { transaction.merchant }),
                    suggestedCategoryId = suggestion.categoryId,
                    suggestedSubcategoryId = suggestion.subcategoryId,
                    confidence = suggestion.confidence,
                )
            }
            .toList()

    fun createBulkApplyPlan(
        previews: List<CategorizationPreview>,
        selectedTransactionIds: Set<TransactionId>,
    ): CategorizationBulkApplyPlan =
        CategorizationBulkApplyPlan(
            operations = previews
                .filter { it.transactionId in selectedTransactionIds }
                .map {
                    CategorizationBulkApplyOperation(
                        transactionId = it.transactionId,
                        categoryId = it.suggestedCategoryId,
                        subcategoryId = it.suggestedSubcategoryId,
                    )
                },
        )

    private fun candidatesForGroup(
        categoryGroup: CategoryGroup,
        transactions: List<Transaction>,
        existingRules: List<MerchantRule>,
        minimumSamples: Int,
    ): List<LearnedMerchantRuleCandidate> {
        val byPattern = transactions
            .map { learnedPattern(it.normalizedMerchant.ifBlank { it.merchant }) }
            .filter { it.isNotBlank() }
            .groupingBy { it }
            .eachCount()

        return byPattern
            .filterValues { it >= minimumSamples }
            .filterKeys { pattern -> !existingRules.hasEquivalentRule(pattern, categoryGroup) }
            .map { (pattern, sampleCount) ->
                LearnedMerchantRuleCandidate(
                    pattern = pattern,
                    categoryId = categoryGroup.categoryId,
                    subcategoryId = categoryGroup.subcategoryId,
                    kind = categoryGroup.kind,
                    confidence = min(0.95, 0.75 + (sampleCount * 0.05)),
                    sampleCount = sampleCount,
                )
            }
    }

    private fun learnedPattern(merchant: String): String {
        val tokens = MerchantNormalizer.normalize(merchant)
            .split(" ")
            .filter { it.isNotBlank() && it.any(Char::isLetter) }
            .dropLastWhile { it in genericTrailingTokens }

        if (tokens.size <= 2) return tokens.joinToString(" ")
        return tokens.take(2).joinToString(" ")
    }

    private fun List<MerchantRule>.hasEquivalentRule(
        pattern: String,
        categoryGroup: CategoryGroup,
    ): Boolean {
        val normalizedPattern = MerchantNormalizer.normalize(pattern)
        return any { rule ->
            if (!rule.isEnabled) return@any false
            if (rule.categoryId != categoryGroup.categoryId) return@any false
            if (rule.subcategoryId != categoryGroup.subcategoryId) return@any false
            if (rule.kind != categoryGroup.kind) return@any false
            val normalizedRule = MerchantNormalizer.normalize(rule.pattern)
            normalizedRule == normalizedPattern ||
                normalizedRule.contains(normalizedPattern) ||
                normalizedPattern.contains(normalizedRule)
        }
    }

    private data class CategoryGroup(
        val categoryId: CategoryId,
        val subcategoryId: CategoryId?,
        val kind: TransactionKind,
    )

    private val genericTrailingTokens = setOf(
        "BRANCH",
        "STORE",
        "SHOP",
        "LLC",
        "LTD",
        "FZCO",
        "FZE",
        "INC",
    )
}
