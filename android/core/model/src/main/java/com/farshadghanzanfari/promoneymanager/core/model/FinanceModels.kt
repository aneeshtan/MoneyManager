package com.farshadghanzanfari.promoneymanager.core.model

import java.time.Instant
import java.time.LocalDate

enum class AccountType {
    CASH,
    BANK,
    CREDIT_CARD,
    LIABILITY,
    INVESTMENT,
    OTHER,
}

enum class TransactionKind {
    EXPENSE,
    INCOME,
    TRANSFER,
}

enum class TransferDirection {
    OUT,
    IN,
}

data class Account(
    val id: AccountId,
    val name: String,
    val currency: CurrencyCode,
    val openingBalance: Money,
    val type: AccountType,
    val isArchived: Boolean = false,
)

data class Category(
    val id: CategoryId,
    val name: String,
    val kind: TransactionKind,
    val parentId: CategoryId? = null,
    val sortOrder: Int = 0,
    val isArchived: Boolean = false,
) {
    init {
        require(name.isNotBlank()) { "Category name must not be blank." }
        require(parentId != id) { "Category parent must be different from the category id." }
    }
}

class Tag(
    val id: TagId,
    val name: String,
    colorHex: String = "8151D1",
) {
    val colorHex: String = colorHex.uppercase()

    init {
        require(name.isNotBlank()) { "Tag name must not be blank." }
        require(this.colorHex.matches(HEX_COLOR_PATTERN)) {
            "Tag colorHex must be a six-character hexadecimal color."
        }
    }

    private companion object {
        val HEX_COLOR_PATTERN = Regex("[0-9A-F]{6}")
    }
}

data class TransactionAttachment(
    val id: AttachmentId,
    val fileName: String,
    val originalFileName: String,
    val contentType: String,
    val createdAt: Instant,
) {
    init {
        require(fileName.isNotBlank()) { "Attachment fileName must not be blank." }
        require(originalFileName.isNotBlank()) { "Attachment originalFileName must not be blank." }
        require(contentType.isNotBlank()) { "Attachment contentType must not be blank." }
    }
}

data class TransactionSourceMetadata(
    val sourceName: String? = null,
    val sourceRow: Int? = null,
    val rawDescription: String = "",
    val importBatchId: ImportBatchId? = null,
)

data class TransactionSplitAllocation(
    val id: SplitId,
    val categoryId: CategoryId,
    val amount: Money,
    val subcategoryId: CategoryId? = null,
) {
    init {
        amount.requirePositiveMagnitude()
    }
}

data class Transaction(
    val id: TransactionId,
    val accountId: AccountId,
    val amount: Money,
    val kind: TransactionKind,
    val localDate: LocalDate = LocalDate.of(1970, 1, 1),
    val merchant: String = "Manual",
    val normalizedMerchant: String = merchant.trim().uppercase(),
    val note: String = "",
    val categoryId: CategoryId? = null,
    val subcategoryId: CategoryId? = null,
    val tagIds: List<TagId> = emptyList(),
    val attachments: List<TransactionAttachment> = emptyList(),
    val source: TransactionSourceMetadata? = null,
    val splitAllocations: List<TransactionSplitAllocation> = emptyList(),
    val transferId: TransferId? = null,
    val transferDirection: TransferDirection? = null,
) {
    init {
        amount.requirePositiveMagnitude()
        require(merchant.isNotBlank()) { "Transaction merchant must not be blank." }
        require(subcategoryId == null || categoryId != null) {
            "Transaction subcategory requires a parent category."
        }
        validateSplits()
        require(
            (kind == TransactionKind.TRANSFER) ==
                (transferId != null && transferDirection != null),
        )
    }

    private fun validateSplits() {
        if (splitAllocations.isEmpty()) return

        require(splitAllocations.size >= 2) {
            "Split transactions require at least two allocations."
        }
        require(splitAllocations.all { it.amount.currency == amount.currency }) {
            "Split allocation currency must match the parent transaction."
        }

        val total = splitAllocations.fold(0L) { sum, allocation ->
            Math.addExact(sum, allocation.amount.minorUnits)
        }
        require(total == amount.minorUnits) {
            "Split allocation total must match the parent transaction amount."
        }
    }

    companion object {
        fun posting(
            id: String,
            accountId: AccountId,
            amount: Money,
            kind: TransactionKind,
            localDate: LocalDate = LocalDate.of(1970, 1, 1),
            merchant: String = "Manual",
            normalizedMerchant: String = merchant.trim().uppercase(),
            note: String = "",
            categoryId: CategoryId? = null,
            subcategoryId: CategoryId? = null,
            tagIds: List<TagId> = emptyList(),
            attachments: List<TransactionAttachment> = emptyList(),
            source: TransactionSourceMetadata? = null,
            splitAllocations: List<TransactionSplitAllocation> = emptyList(),
        ) = Transaction(
            id = TransactionId(id),
            accountId = accountId,
            amount = amount,
            kind = kind,
            localDate = localDate,
            merchant = merchant,
            normalizedMerchant = normalizedMerchant,
            note = note,
            categoryId = categoryId,
            subcategoryId = subcategoryId,
            tagIds = tagIds,
            attachments = attachments,
            source = source,
            splitAllocations = splitAllocations,
        )

        fun transferLeg(
            id: String,
            accountId: AccountId,
            amount: Money,
            transferId: TransferId,
            direction: TransferDirection,
            localDate: LocalDate = LocalDate.of(1970, 1, 1),
            merchant: String = "Transfer",
            normalizedMerchant: String = merchant.trim().uppercase(),
            note: String = "",
            tagIds: List<TagId> = emptyList(),
            attachments: List<TransactionAttachment> = emptyList(),
            source: TransactionSourceMetadata? = null,
        ) = Transaction(
            id = TransactionId(id),
            accountId = accountId,
            amount = amount,
            kind = TransactionKind.TRANSFER,
            localDate = localDate,
            merchant = merchant,
            normalizedMerchant = normalizedMerchant,
            note = note,
            tagIds = tagIds,
            attachments = attachments,
            source = source,
            transferId = transferId,
            transferDirection = direction,
        )
    }
}
