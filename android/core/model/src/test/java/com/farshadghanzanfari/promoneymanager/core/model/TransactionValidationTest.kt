package com.farshadghanzanfari.promoneymanager.core.model

import com.google.common.truth.Truth.assertThat
import java.time.LocalDate
import java.time.Instant
import org.junit.Assert.assertThrows
import org.junit.Test

class TransactionValidationTest {
    private val aed = CurrencyCode.of("AED")
    private val accountId = AccountId("account-main")

    @Test
    fun postingStoresClassificationTagsAttachmentsAndSourceMetadata() {
        val transaction = Transaction.posting(
            id = "txn-1",
            accountId = accountId,
            amount = Money(12_50, aed),
            kind = TransactionKind.EXPENSE,
            localDate = LocalDate.parse("2026-07-10"),
            merchant = "Amazon Grocery Dubai",
            normalizedMerchant = "AMAZON GROCERY DUBAI",
            note = "weekly food",
            categoryId = CategoryId("category-food"),
            subcategoryId = CategoryId("category-grocery"),
            tagIds = listOf(TagId("tag-business")),
            attachments = listOf(
                TransactionAttachment(
                    id = AttachmentId("attachment-receipt"),
                    fileName = "receipt.jpg",
                    originalFileName = "IMG_1000.JPG",
                    contentType = "image/jpeg",
                    createdAt = Instant.parse("2026-07-10T10:15:30Z"),
                ),
            ),
            source = TransactionSourceMetadata(
                sourceName = "statement.pdf",
                sourceRow = 4,
                rawDescription = "AMAZON GROCERY DUBAI",
                importBatchId = ImportBatchId("batch-1"),
            ),
        )

        assertThat(transaction.localDate).isEqualTo(LocalDate.parse("2026-07-10"))
        assertThat(transaction.categoryId).isEqualTo(CategoryId("category-food"))
        assertThat(transaction.subcategoryId).isEqualTo(CategoryId("category-grocery"))
        assertThat(transaction.tagIds).containsExactly(TagId("tag-business"))
        assertThat(transaction.attachments.single().originalFileName).isEqualTo("IMG_1000.JPG")
        assertThat(transaction.source?.sourceName).isEqualTo("statement.pdf")
    }

    @Test
    fun postingRejectsBlankMerchantAndMismatchedSubcategory() {
        assertThrows(IllegalArgumentException::class.java) {
            Transaction.posting(
                id = "txn-1",
                accountId = accountId,
                amount = Money(12_50, aed),
                kind = TransactionKind.EXPENSE,
                merchant = "",
            )
        }

        assertThrows(IllegalArgumentException::class.java) {
            Transaction.posting(
                id = "txn-1",
                accountId = accountId,
                amount = Money(12_50, aed),
                kind = TransactionKind.EXPENSE,
                categoryId = null,
                subcategoryId = CategoryId("category-grocery"),
            )
        }
    }

    @Test
    fun transferLegKeepsTransferInvariantWithRicherFields() {
        val transfer = Transaction.transferLeg(
            id = "transfer-out",
            accountId = accountId,
            amount = Money(5_000, aed),
            transferId = TransferId("transfer-1"),
            direction = TransferDirection.OUT,
            localDate = LocalDate.parse("2026-07-10"),
            note = "move to savings",
            tagIds = listOf(TagId("tag-planned")),
        )

        assertThat(transfer.kind).isEqualTo(TransactionKind.TRANSFER)
        assertThat(transfer.transferId).isEqualTo(TransferId("transfer-1"))
        assertThat(transfer.transferDirection).isEqualTo(TransferDirection.OUT)
        assertThat(transfer.note).isEqualTo("move to savings")
        assertThat(transfer.tagIds).containsExactly(TagId("tag-planned"))
    }

    @Test
    fun splitAllocationsMustMatchParentCurrencyAndTotal() {
        val transaction = Transaction.posting(
            id = "txn-1",
            accountId = accountId,
            amount = Money(10_00, aed),
            kind = TransactionKind.EXPENSE,
            splitAllocations = listOf(
                TransactionSplitAllocation(
                    id = SplitId("split-food"),
                    categoryId = CategoryId("category-food"),
                    amount = Money(6_00, aed),
                ),
                TransactionSplitAllocation(
                    id = SplitId("split-transport"),
                    categoryId = CategoryId("category-transport"),
                    amount = Money(4_00, aed),
                ),
            ),
        )

        assertThat(transaction.splitAllocations).hasSize(2)

        assertThrows(IllegalArgumentException::class.java) {
            Transaction.posting(
                id = "txn-bad",
                accountId = accountId,
                amount = Money(10_00, aed),
                kind = TransactionKind.EXPENSE,
                splitAllocations = listOf(
                    TransactionSplitAllocation(
                        id = SplitId("split-food"),
                        categoryId = CategoryId("category-food"),
                        amount = Money(5_00, aed),
                    ),
                    TransactionSplitAllocation(
                        id = SplitId("split-travel"),
                        categoryId = CategoryId("category-travel"),
                        amount = Money(6_00, aed),
                    ),
                ),
            )
        }
    }
}
