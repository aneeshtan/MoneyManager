package com.farshadghanzanfari.promoneymanager.core.database

import androidx.room.Entity
import androidx.room.Embedded
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey
import androidx.room.Relation

@Entity(tableName = "profiles")
data class ProfileEntity(
    @PrimaryKey val id: String,
    val displayName: String,
    val baseCurrency: String,
    val countryCode: String?,
    val timeZoneId: String?,
)

@Entity(
    tableName = "accounts",
    foreignKeys = [
        ForeignKey(
            entity = ProfileEntity::class,
            parentColumns = ["id"],
            childColumns = ["profileId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [
        Index("profileId"),
        Index(value = ["profileId", "name"], unique = true),
    ],
)
data class AccountEntity(
    @PrimaryKey val id: String,
    val profileId: String,
    val name: String,
    val currencyCode: String,
    val openingBalanceMinor: Long,
    val type: String,
    val isArchived: Boolean,
    val sortOrder: Int,
)

@Entity(
    tableName = "categories",
    foreignKeys = [
        ForeignKey(
            entity = ProfileEntity::class,
            parentColumns = ["id"],
            childColumns = ["profileId"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = CategoryEntity::class,
            parentColumns = ["id"],
            childColumns = ["parentId"],
            onDelete = ForeignKey.SET_NULL,
        ),
    ],
    indices = [
        Index("profileId"),
        Index("parentId"),
        Index(value = ["profileId", "name", "parentId"], unique = true),
    ],
)
data class CategoryEntity(
    @PrimaryKey val id: String,
    val profileId: String,
    val name: String,
    val kind: String,
    val parentId: String?,
    val sortOrder: Int,
    val isArchived: Boolean,
)

@Entity(
    tableName = "tags",
    foreignKeys = [
        ForeignKey(
            entity = ProfileEntity::class,
            parentColumns = ["id"],
            childColumns = ["profileId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [
        Index("profileId"),
        Index(value = ["profileId", "name"], unique = true),
    ],
)
data class TagEntity(
    @PrimaryKey val id: String,
    val profileId: String,
    val name: String,
    val colorHex: String,
    val createdAt: String,
)

@Entity(
    tableName = "transactions",
    foreignKeys = [
        ForeignKey(
            entity = AccountEntity::class,
            parentColumns = ["id"],
            childColumns = ["accountId"],
            onDelete = ForeignKey.RESTRICT,
        ),
        ForeignKey(
            entity = CategoryEntity::class,
            parentColumns = ["id"],
            childColumns = ["categoryId"],
            onDelete = ForeignKey.SET_NULL,
        ),
        ForeignKey(
            entity = CategoryEntity::class,
            parentColumns = ["id"],
            childColumns = ["subcategoryId"],
            onDelete = ForeignKey.SET_NULL,
        ),
    ],
    indices = [
        Index("accountId"),
        Index("categoryId"),
        Index("subcategoryId"),
        Index("transferId"),
        Index(
            value = [
                "accountId",
                "localDate",
                "amountMinor",
                "currencyCode",
                "normalizedMerchant",
            ],
        ),
    ],
)
data class TransactionEntity(
    @PrimaryKey val id: String,
    val accountId: String,
    val localDate: String,
    val amountMinor: Long,
    val currencyCode: String,
    val kind: String,
    val merchant: String,
    val normalizedMerchant: String,
    val note: String,
    val categoryId: String? = null,
    val subcategoryId: String? = null,
    val transferId: String? = null,
    val transferDirection: String? = null,
    val importBatchId: String? = null,
    val rawDescription: String = "",
    val sourceName: String? = null,
    val sourceRow: Int? = null,
    val sourcePeriodSerial: String? = null,
    val sourceAccountColumn: String? = null,
    val sourceCategoryColumn: String? = null,
    val sourceSubcategoryColumn: String? = null,
    val sourceNoteColumn: String? = null,
    val sourceAmountColumn: String? = null,
    val sourceCurrencyColumn: String? = null,
)

@Entity(
    tableName = "transaction_tags",
    primaryKeys = ["transactionId", "tagId"],
    foreignKeys = [
        ForeignKey(
            entity = TransactionEntity::class,
            parentColumns = ["id"],
            childColumns = ["transactionId"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = TagEntity::class,
            parentColumns = ["id"],
            childColumns = ["tagId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [
        Index("transactionId"),
        Index("tagId"),
    ],
)
data class TransactionTagCrossRef(
    val transactionId: String,
    val tagId: String,
)

@Entity(
    tableName = "transaction_attachments",
    foreignKeys = [
        ForeignKey(
            entity = TransactionEntity::class,
            parentColumns = ["id"],
            childColumns = ["transactionId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("transactionId")],
)
data class TransactionAttachmentEntity(
    @PrimaryKey val id: String,
    val transactionId: String,
    val fileName: String,
    val originalFileName: String,
    val contentType: String,
    val createdAt: String,
)

@Entity(
    tableName = "merchant_rules",
    foreignKeys = [
        ForeignKey(
            entity = ProfileEntity::class,
            parentColumns = ["id"],
            childColumns = ["profileId"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = CategoryEntity::class,
            parentColumns = ["id"],
            childColumns = ["categoryId"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = CategoryEntity::class,
            parentColumns = ["id"],
            childColumns = ["subcategoryId"],
            onDelete = ForeignKey.SET_NULL,
        ),
        ForeignKey(
            entity = AccountEntity::class,
            parentColumns = ["id"],
            childColumns = ["accountId"],
            onDelete = ForeignKey.SET_NULL,
        ),
    ],
    indices = [
        Index("profileId"),
        Index("categoryId"),
        Index("subcategoryId"),
        Index("accountId"),
    ],
)
data class MerchantRuleEntity(
    @PrimaryKey val id: String,
    val profileId: String,
    val pattern: String,
    val matchType: String,
    val categoryId: String,
    val subcategoryId: String?,
    val kind: String,
    val confidence: Double,
    val sampleCount: Int,
    val isEnabled: Boolean,
    val createdAt: String,
    val accountId: String?,
    val notePattern: String?,
    val minAmountMinor: Long?,
    val maxAmountMinor: Long?,
    val amountCurrencyCode: String?,
    val priority: Int,
    val isAutoGenerated: Boolean,
)

@Entity(
    tableName = "budgets",
    foreignKeys = [
        ForeignKey(
            entity = ProfileEntity::class,
            parentColumns = ["id"],
            childColumns = ["profileId"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = CategoryEntity::class,
            parentColumns = ["id"],
            childColumns = ["categoryId"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = CategoryEntity::class,
            parentColumns = ["id"],
            childColumns = ["subcategoryId"],
            onDelete = ForeignKey.SET_NULL,
        ),
    ],
    indices = [
        Index("profileId"),
        Index("categoryId"),
        Index("subcategoryId"),
        Index(value = ["profileId", "categoryId", "subcategoryId", "month"], unique = true),
    ],
)
data class BudgetEntity(
    @PrimaryKey val id: String,
    val profileId: String,
    val categoryId: String,
    val subcategoryId: String?,
    val month: String,
    val amountMinor: Long,
    val currencyCode: String,
    val rolloverEnabled: Boolean,
    val isArchived: Boolean,
)

@Entity(
    tableName = "scheduled_transactions",
    foreignKeys = [
        ForeignKey(
            entity = ProfileEntity::class,
            parentColumns = ["id"],
            childColumns = ["profileId"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = AccountEntity::class,
            parentColumns = ["id"],
            childColumns = ["accountId"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = CategoryEntity::class,
            parentColumns = ["id"],
            childColumns = ["categoryId"],
            onDelete = ForeignKey.SET_NULL,
        ),
        ForeignKey(
            entity = CategoryEntity::class,
            parentColumns = ["id"],
            childColumns = ["subcategoryId"],
            onDelete = ForeignKey.SET_NULL,
        ),
    ],
    indices = [
        Index("profileId"),
        Index("accountId"),
        Index("categoryId"),
        Index("subcategoryId"),
        Index("nextDate"),
    ],
)
data class ScheduledTransactionEntity(
    @PrimaryKey val id: String,
    val profileId: String,
    val accountId: String,
    val amountMinor: Long,
    val currencyCode: String,
    val kind: String,
    val merchant: String,
    val normalizedMerchant: String,
    val categoryId: String?,
    val subcategoryId: String?,
    val note: String,
    val frequency: String,
    val nextDate: String,
    val lastRunDate: String?,
    val status: String,
    val reminderEnabled: Boolean,
)

@Entity(
    tableName = "savings_goals",
    foreignKeys = [
        ForeignKey(
            entity = ProfileEntity::class,
            parentColumns = ["id"],
            childColumns = ["profileId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [
        Index("profileId"),
        Index("isArchived"),
    ],
)
data class SavingsGoalEntity(
    @PrimaryKey val id: String,
    val profileId: String,
    val name: String,
    val targetAmountMinor: Long,
    val currentAmountMinor: Long,
    val currencyCode: String,
    val targetDate: String?,
    val isArchived: Boolean,
)

@Entity(
    tableName = "savings_goal_contributions",
    foreignKeys = [
        ForeignKey(
            entity = SavingsGoalEntity::class,
            parentColumns = ["id"],
            childColumns = ["goalId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [
        Index("goalId"),
        Index("localDate"),
    ],
)
data class SavingsGoalContributionEntity(
    @PrimaryKey val id: String,
    val goalId: String,
    val amountMinor: Long,
    val currencyCode: String,
    val direction: String,
    val localDate: String,
    val note: String,
)

@Entity(
    tableName = "debt_payoff_plans",
    foreignKeys = [
        ForeignKey(
            entity = ProfileEntity::class,
            parentColumns = ["id"],
            childColumns = ["profileId"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [
        Index("profileId"),
        Index("isArchived"),
    ],
)
data class DebtPayoffPlanEntity(
    @PrimaryKey val id: String,
    val profileId: String,
    val name: String,
    val originalBalanceMinor: Long,
    val currentBalanceMinor: Long,
    val currencyCode: String,
    val annualInterestRateBasisPoints: Int,
    val minimumPaymentMinor: Long,
    val extraPaymentMinor: Long,
    val strategy: String,
    val isArchived: Boolean,
)

data class TransactionWithRelations(
    @Embedded val transaction: TransactionEntity,
    @Relation(
        parentColumn = "id",
        entityColumn = "transactionId",
    )
    val tagRefs: List<TransactionTagCrossRef>,
    @Relation(
        parentColumn = "id",
        entityColumn = "transactionId",
    )
    val attachments: List<TransactionAttachmentEntity>,
)
