package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CategorySuggestion
import com.farshadghanzanfari.promoneymanager.core.model.MatchType
import com.farshadghanzanfari.promoneymanager.core.model.MerchantRule
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind

object CategoryMatcher {
    fun match(
        merchant: String,
        rules: List<MerchantRule>,
        fallbackKind: TransactionKind,
    ): CategorySuggestion? = match(
        merchant = merchant,
        accountId = null,
        note = null,
        amount = null,
        rules = rules,
        fallbackKind = fallbackKind,
    )

    fun match(
        merchant: String,
        accountId: AccountId?,
        note: String?,
        amount: Money?,
        rules: List<MerchantRule>,
        fallbackKind: TransactionKind,
    ): CategorySuggestion? {
        val normalized = MerchantNormalizer.normalize(merchant)
        val sortedRules = rules
            .filter { it.isEnabled }
            .sortedWith(
                compareByDescending<MerchantRule> { it.priority }
                    .thenByDescending { it.sampleCount }
                    .thenByDescending { it.pattern.length },
            )

        for (rule in sortedRules) {
            val pattern = MerchantNormalizer.normalize(rule.pattern)
            if (pattern.isEmpty()) continue

            val merchantMatches = when (rule.matchType) {
                MatchType.EXACT -> normalized == pattern
                MatchType.CONTAINS -> normalized.contains(pattern) || pattern.contains(normalized)
            }
            if (!merchantMatches) continue

            if (accountId != null && rule.accountId != null && accountId != rule.accountId) continue

            val notePattern = rule.notePattern
            if (!notePattern.isNullOrBlank() && note != null) {
                val normalizedNote = MerchantNormalizer.normalize(note)
                val normalizedRuleNote = MerchantNormalizer.normalize(notePattern)
                if (!normalizedNote.contains(normalizedRuleNote) &&
                    !normalizedRuleNote.contains(normalizedNote)
                ) {
                    continue
                }
            }

            if (amount != null) {
                val minAmount = rule.minAmount
                if (minAmount != null) {
                    if (amount.currency != minAmount.currency ||
                        amount.minorUnits < minAmount.minorUnits
                    ) {
                        continue
                    }
                }
                val maxAmount = rule.maxAmount
                if (maxAmount != null) {
                    if (amount.currency != maxAmount.currency ||
                        amount.minorUnits > maxAmount.minorUnits
                    ) {
                        continue
                    }
                }
            }

            return CategorySuggestion(
                categoryId = rule.categoryId,
                subcategoryId = rule.subcategoryId,
                kind = rule.kind,
                confidence = rule.confidence,
            )
        }

        return fallback(normalized, fallbackKind)
    }

    private fun fallback(merchant: String, fallbackKind: TransactionKind): CategorySuggestion? {
        val brandMatch = MerchantCategoryFallbacks.brandRules.firstOrNull { merchant.contains(it.pattern) }
        if (brandMatch != null) {
            return CategorySuggestion(
                categoryId = CategoryId(brandMatch.categoryId),
                subcategoryId = brandMatch.subcategoryId?.let(::CategoryId),
                kind = fallbackKind,
                confidence = brandMatch.confidence,
            )
        }

        val keywordMatch = MerchantCategoryFallbacks.keywordRules.firstOrNull { rule ->
            rule.keywords.any { merchant.contains(it) }
        }
        if (keywordMatch != null) {
            return CategorySuggestion(
                categoryId = CategoryId(keywordMatch.categoryId),
                subcategoryId = keywordMatch.subcategoryId?.let(::CategoryId),
                kind = fallbackKind,
                confidence = keywordMatch.confidence,
            )
        }

        return null
    }
}
