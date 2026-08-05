package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.MatchType
import com.farshadghanzanfari.promoneymanager.core.model.MerchantRule
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.google.common.truth.Truth.assertThat
import org.junit.Test

class CategoryMatcherTest {
    private val aed = CurrencyCode.of("AED")

    @Test
    fun enabledRulesBeatFallbacksAndPreserveConfidence() {
        val rule = MerchantRule(
            id = "rule-matovi",
            pattern = "MATOVI DIGITAL FZCO",
            matchType = MatchType.CONTAINS,
            categoryId = CategoryId("entertainment"),
            subcategoryId = CategoryId("subscriptions"),
            kind = TransactionKind.EXPENSE,
            confidence = 0.95,
            sampleCount = 41,
        )

        val suggestion = CategoryMatcher.match(
            merchant = "MATOVI DIGITAL FZCO DUBAI ARE",
            rules = listOf(rule),
            fallbackKind = TransactionKind.EXPENSE,
        )

        assertThat(suggestion?.categoryId).isEqualTo(CategoryId("entertainment"))
        assertThat(suggestion?.subcategoryId).isEqualTo(CategoryId("subscriptions"))
        assertThat(suggestion?.confidence).isEqualTo(0.95)
    }

    @Test
    fun ignoresDisabledRulesAndUsesFallbacks() {
        val disabled = MerchantRule(
            id = "rule-disabled",
            pattern = "DUBAI TAXI",
            matchType = MatchType.EXACT,
            categoryId = CategoryId("wrong"),
            kind = TransactionKind.EXPENSE,
            isEnabled = false,
        )

        val suggestion = CategoryMatcher.match(
            merchant = "DUBAI TAXI",
            rules = listOf(disabled),
            fallbackKind = TransactionKind.EXPENSE,
        )

        assertThat(suggestion?.categoryId).isEqualTo(CategoryId("category-transportation"))
        assertThat(suggestion?.subcategoryId).isEqualTo(CategoryId("category-taxi"))
    }

    @Test
    fun respectsAccountNoteAndAmountConstraints() {
        val rule = MerchantRule(
            id = "rule-careem-work",
            pattern = "CAREEM HALA",
            matchType = MatchType.CONTAINS,
            categoryId = CategoryId("transportation"),
            subcategoryId = CategoryId("taxi"),
            kind = TransactionKind.EXPENSE,
            accountId = AccountId("daily-card"),
            notePattern = "client",
            minAmount = Money(1_000, aed),
            maxAmount = Money(10_000, aed),
        )

        assertThat(
            CategoryMatcher.match(
                merchant = "CAREEM HALA RIDE",
                accountId = AccountId("daily-card"),
                note = "Client visit",
                amount = Money(5_800, aed),
                rules = listOf(rule),
                fallbackKind = TransactionKind.EXPENSE,
            )?.categoryId,
        ).isEqualTo(CategoryId("transportation"))

        assertThat(
            CategoryMatcher.match(
                merchant = "CAREEM HALA RIDE",
                accountId = AccountId("cash"),
                note = "Client visit",
                amount = Money(5_800, aed),
                rules = listOf(rule),
                fallbackKind = TransactionKind.EXPENSE,
            )?.confidence,
        ).isEqualTo(0.75)
    }

    @Test
    fun sortsRulesByPriorityThenSamplesThenPatternLength() {
        val lowPriority = MerchantRule(
            id = "low",
            pattern = "AMAZON",
            matchType = MatchType.CONTAINS,
            categoryId = CategoryId("shopping"),
            kind = TransactionKind.EXPENSE,
            sampleCount = 99,
            priority = 0,
        )
        val highPriority = MerchantRule(
            id = "high",
            pattern = "AMAZON GROCERY",
            matchType = MatchType.CONTAINS,
            categoryId = CategoryId("food"),
            kind = TransactionKind.EXPENSE,
            sampleCount = 1,
            priority = 10,
        )

        val suggestion = CategoryMatcher.match(
            merchant = "Amazon Grocery Dubai",
            rules = listOf(lowPriority, highPriority),
            fallbackKind = TransactionKind.EXPENSE,
        )

        assertThat(suggestion?.categoryId).isEqualTo(CategoryId("food"))
    }

    @Test
    fun coversCoreFallbackMerchants() {
        assertThat(CategoryMatcher.match("DUBAI TAXI", emptyList(), TransactionKind.EXPENSE)?.categoryId)
            .isEqualTo(CategoryId("category-transportation"))
        assertThat(CategoryMatcher.match("Amazon Grocery Dubai", emptyList(), TransactionKind.EXPENSE)?.categoryId)
            .isEqualTo(CategoryId("category-food"))
        assertThat(CategoryMatcher.match("Amazon Grocery Dubai", emptyList(), TransactionKind.EXPENSE)?.subcategoryId)
            .isEqualTo(CategoryId("category-groceries"))
    }

    @Test
    fun fallbacksOnlyUseCategoryIdsThatExistInDefaultWorkspaceSeeder() {
        // Every fallback categoryId/subcategoryId must match an id DefaultWorkspaceSeeder actually
        // creates, otherwise saving an imported transaction violates the categories foreign key
        // and aborts the whole import batch (see RoomWorkspaceRepository.saveReviewedImport).
        // DefaultCategories.ids is the single source of truth for both the seeder and this check,
        // so the two can never drift out of sync as the fallback tables grow.
        val seededCategoryIds = DefaultCategories.ids

        MerchantCategoryFallbacks.brandRules.forEach { rule ->
            assertThat(rule.categoryId in seededCategoryIds).isTrue()
            assertThat(rule.subcategoryId == null || rule.subcategoryId in seededCategoryIds).isTrue()
        }
        MerchantCategoryFallbacks.keywordRules.forEach { rule ->
            assertThat(rule.categoryId in seededCategoryIds).isTrue()
            assertThat(rule.subcategoryId == null || rule.subcategoryId in seededCategoryIds).isTrue()
        }
    }

    @Test
    fun keywordTierCatchesMerchantsTheBrandListDoesNotNameExplicitly() {
        // None of these appear verbatim in MerchantCategoryFallbacks.brandRules; they should
        // still resolve via the generic keyword bucket instead of falling through uncategorized.
        val merchants = listOf(
            "AL FUTTAIM MEDICAL CENTRE" to CategoryId("category-doctor"),
            "GREEN VALLEY NURSERY" to CategoryId("category-education"),
            "CITY PARKING TICKET" to CategoryId("category-parking"),
            "HORIZON FITNESS GYM" to CategoryId("category-fitness"),
            "SEASIDE RESTAURANT" to CategoryId("category-restaurants"),
            "QUICK DRY CLEAN" to CategoryId("category-laundry"),
        )

        merchants.forEach { (merchant, expectedSubcategory) ->
            val suggestion = CategoryMatcher.match(merchant, emptyList(), TransactionKind.EXPENSE)
            assertThat(suggestion).isNotNull()
            assertThat(suggestion?.subcategoryId).isEqualTo(expectedSubcategory)
        }
    }

    @Test
    fun realisticStatementSampleStaysUnderFivePercentUncategorized() {
        // A representative slice of a UAE bank/credit-card statement's merchant descriptions.
        val merchants = listOf(
            "CAREEM HALA RIDE DUBAI ARE", "CARREFOUR MOE DUBAI ARE", "STARBUCKS DIFC DUBAI ARE",
            "TALABAT DUBAI ARE", "ADNOC FUEL STATION DUBAI ARE", "SALIK RECHARGE",
            "NETFLIX.COM", "SPOTIFY AB", "NOON.COM DUBAI ARE", "AMAZON.AE DUBAI ARE",
            "DEWA DUBAI ARE", "ETISALAT DUBAI ARE", "VOX CINEMAS MALL OF THE EMIRATES",
            "AGODA.COM", "EMIRATES AIRLINE DUBAI ARE", "SPINNEYS UMM SUQEIM DUBAI ARE",
            "MCDONALDS JBR DUBAI ARE", "KFC DUBAI ARE", "IKEA DUBAI FESTIVAL CITY",
            "ZARA MALL OF EMIRATES", "FITNESS FIRST JLT DUBAI ARE", "BOOTS PHARMACY DUBAI ARE",
            "MEDCARE HOSPITAL DUBAI ARE", "WESTERN UNION EXCHANGE DUBAI ARE",
            "AL ANSARI EXCHANGE DUBAI ARE", "GIFTS VILLAGE DUBAI ARE", "HERTZ RENT A CAR",
            "SALARY TRANSFER JUNE", "SERVICE CHARGE - ANNUAL FEE", "VAT PAYMENT Q2",
            "GREEN VALLEY NURSERY FEES", "CITY PARKING TICKET DUBAI ARE",
            "SEASIDE RESTAURANT JBR DUBAI ARE", "QUICK DRY CLEAN SHOP", "TIM HORTONS DUBAI ARE",
            "DUBAI TAXI RIDE", "RTA DUBAI METRO NOL TOPUP", "TEMU.COM PURCHASE",
            "H&M MIRDIF CITY CENTRE", "AL MAYA SUPERMARKET DUBAI ARE", "JUSTLIFE CLEANING",
        )

        val uncategorized = merchants.count { merchant ->
            CategoryMatcher.match(merchant, emptyList(), TransactionKind.EXPENSE) == null
        }
        val uncategorizedRate = uncategorized.toDouble() / merchants.size

        assertThat(uncategorizedRate).isAtMost(0.05)
    }
}
