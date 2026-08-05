package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.google.common.truth.Truth.assertThat
import java.time.LocalDate
import org.junit.Test

class DuplicateReviewServiceTest {
    private val aed = CurrencyCode.of("AED")
    private val account = AccountId("daily-card")

    @Test
    fun groupsExactDuplicatesByAccountDateAmountCurrencyAndMerchant() {
        val candidates = DuplicateReviewService.candidates(
            listOf(
                tx("a", "CAREEM HALA RIDE", LocalDate.parse("2026-06-10"), 5_800),
                tx("b", "CAREEM HALA RIDE DUBAI ARE", LocalDate.parse("2026-06-10"), 5_800),
                tx("different-account", "CAREEM HALA RIDE", LocalDate.parse("2026-06-10"), 5_800, AccountId("cash")),
            ),
        )

        assertThat(candidates).hasSize(1)
        assertThat(candidates.single().isExact).isTrue()
        assertThat(candidates.single().transactions.map { it.id.value }).containsExactly("a", "b")
    }

    @Test
    fun groupsLikelyDuplicatesByThreeDayBucketAmountAndMerchantRoot() {
        val candidates = DuplicateReviewService.candidates(
            listOf(
                tx("old", "AMAZON GROCERY 12345 DUBAI", LocalDate.parse("2026-06-10"), 26_590),
                tx("new", "Amazon Grocery Dubai", LocalDate.parse("2026-06-11"), 26_590),
            ),
        )

        assertThat(candidates).hasSize(1)
        assertThat(candidates.single().isExact).isFalse()
        assertThat(candidates.single().transactions.map { it.id.value }).containsExactly("old", "new")
    }

    @Test
    fun doesNotGroupDifferentCurrencies() {
        val candidates = DuplicateReviewService.candidates(
            listOf(
                tx("aed", "AGODA.COM", LocalDate.parse("2026-06-10"), 116_100),
                tx(
                    id = "usd",
                    merchant = "AGODA.COM",
                    localDate = LocalDate.parse("2026-06-10"),
                    minor = 116_100,
                    currency = CurrencyCode.of("USD"),
                ),
            ),
        )

        assertThat(candidates).isEmpty()
    }

    private fun tx(
        id: String,
        merchant: String,
        localDate: LocalDate,
        minor: Long,
        accountId: AccountId = account,
        currency: CurrencyCode = aed,
    ): Transaction = Transaction.posting(
        id = id,
        accountId = accountId,
        amount = Money(minor, currency),
        kind = TransactionKind.EXPENSE,
        localDate = localDate,
        merchant = merchant,
        normalizedMerchant = MerchantNormalizer.normalize(merchant),
    )
}
