package com.farshadghanzanfari.promoneymanager.core.data

import androidx.room.withTransaction
import com.farshadghanzanfari.promoneymanager.core.database.AccountEntity
import com.farshadghanzanfari.promoneymanager.core.database.AppDatabase
import com.farshadghanzanfari.promoneymanager.core.database.BudgetEntity
import com.farshadghanzanfari.promoneymanager.core.database.CategoryEntity
import com.farshadghanzanfari.promoneymanager.core.database.DebtPayoffPlanEntity
import com.farshadghanzanfari.promoneymanager.core.database.MerchantRuleEntity
import com.farshadghanzanfari.promoneymanager.core.database.ProfileEntity
import com.farshadghanzanfari.promoneymanager.core.database.SavingsGoalContributionEntity
import com.farshadghanzanfari.promoneymanager.core.database.SavingsGoalEntity
import com.farshadghanzanfari.promoneymanager.core.database.ScheduledTransactionEntity
import com.farshadghanzanfari.promoneymanager.core.database.TagEntity
import com.farshadghanzanfari.promoneymanager.core.database.TransactionAttachmentEntity
import com.farshadghanzanfari.promoneymanager.core.database.TransactionEntity
import com.farshadghanzanfari.promoneymanager.core.database.TransactionTagCrossRef
import com.farshadghanzanfari.promoneymanager.core.database.TransactionWithRelations
import com.farshadghanzanfari.promoneymanager.core.domain.PostedScheduleResult
import com.farshadghanzanfari.promoneymanager.core.domain.BackupEngine
import com.farshadghanzanfari.promoneymanager.core.domain.ScheduleCalculator
import com.farshadghanzanfari.promoneymanager.core.domain.WorkspaceRepository
import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.farshadghanzanfari.promoneymanager.core.model.AttachmentId
import com.farshadghanzanfari.promoneymanager.core.model.Budget
import com.farshadghanzanfari.promoneymanager.core.model.BudgetId
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CompleteBackupSnapshot
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffPlan
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffStrategy
import com.farshadghanzanfari.promoneymanager.core.model.DebtPlanId
import com.farshadghanzanfari.promoneymanager.core.model.GoalContributionId
import com.farshadghanzanfari.promoneymanager.core.model.ImportBatchId
import com.farshadghanzanfari.promoneymanager.core.model.ImportReviewSaveCommand
import com.farshadghanzanfari.promoneymanager.core.model.ImportReviewSaveResult
import com.farshadghanzanfari.promoneymanager.core.model.MatchType
import com.farshadghanzanfari.promoneymanager.core.model.MerchantRule
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.NotificationSettings
import com.farshadghanzanfari.promoneymanager.core.model.PrivacySettings
import com.farshadghanzanfari.promoneymanager.core.model.RegionalSettings
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoal
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContribution
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContributionDirection
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalId
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleFrequency
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleId
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleStatus
import com.farshadghanzanfari.promoneymanager.core.model.ScheduledTransaction
import com.farshadghanzanfari.promoneymanager.core.model.Tag
import com.farshadghanzanfari.promoneymanager.core.model.TagId
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionAttachment
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.farshadghanzanfari.promoneymanager.core.model.TransactionSourceMetadata
import com.farshadghanzanfari.promoneymanager.core.model.TransactionId
import com.farshadghanzanfari.promoneymanager.core.model.TransferDirection
import com.farshadghanzanfari.promoneymanager.core.model.TransferId
import java.time.Instant
import java.time.LocalDate
import java.time.YearMonth
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

@Singleton
class RoomWorkspaceRepository @Inject constructor(
    private val database: AppDatabase,
    private val seeder: DefaultWorkspaceSeeder,
    private val settingsStore: SettingsStore,
) : WorkspaceRepository {
    internal constructor(database: AppDatabase, seeder: DefaultWorkspaceSeeder) :
        this(database, seeder, MemorySettingsStore())

    private val dao = database.financeDao()

    override fun observeAccounts(): Flow<List<Account>> = dao.observeAccounts().map { rows ->
        rows.map { row ->
            val currency = CurrencyCode.of(row.currencyCode)
            Account(
                id = AccountId(row.id),
                name = row.name,
                currency = currency,
                openingBalance = Money(row.openingBalanceMinor, currency),
                type = AccountType.valueOf(row.type),
                isArchived = row.isArchived,
            )
        }
    }

    override fun observeCategories(): Flow<List<Category>> = dao.observeCategories().map { rows ->
        rows.map {
            Category(
                id = CategoryId(it.id),
                name = it.name,
                kind = TransactionKind.valueOf(it.kind),
                parentId = it.parentId?.let(::CategoryId),
                sortOrder = it.sortOrder,
                isArchived = it.isArchived,
            )
        }
    }

    override fun observeTags(): Flow<List<Tag>> = dao.observeTags().map { rows ->
        rows.map { Tag(TagId(it.id), it.name, it.colorHex) }
    }

    override fun observeTransactions(): Flow<List<Transaction>> =
        dao.observeTransactionsWithRelations().map { rows ->
            rows.map(::mapTransaction)
        }

    override fun observeMerchantRules(): Flow<List<MerchantRule>> =
        dao.observeMerchantRules().map { rows -> rows.map(::mapMerchantRule) }

    override fun observeBudgets(): Flow<List<Budget>> =
        dao.observeBudgets().map { rows -> rows.map(::mapBudget) }

    override fun observeScheduledTransactions(): Flow<List<ScheduledTransaction>> =
        dao.observeScheduledTransactions().map { rows -> rows.map(::mapScheduledTransaction) }

    override fun observeSavingsGoals(): Flow<List<SavingsGoal>> =
        dao.observeSavingsGoals().map { rows -> rows.map(::mapSavingsGoal) }

    override fun observeSavingsGoalContributions(): Flow<List<SavingsGoalContribution>> =
        dao.observeSavingsGoalContributions().map { rows -> rows.map(::mapSavingsGoalContribution) }

    override fun observeDebtPayoffPlans(): Flow<List<DebtPayoffPlan>> =
        dao.observeDebtPayoffPlans().map { rows -> rows.map(::mapDebtPayoffPlan) }

    override fun observePrivacySettings(): Flow<PrivacySettings> = settingsStore.privacySettings

    override fun observeNotificationSettings(): Flow<NotificationSettings> = settingsStore.notificationSettings

    override fun observeRegionalSettings(): Flow<RegionalSettings> = settingsStore.regionalSettings

    override suspend fun saveAccount(account: Account) {
        dao.upsertAccount(
            AccountEntity(
                id = account.id.value,
                profileId = PRIMARY_PROFILE_ID,
                name = account.name,
                currencyCode = account.currency.value,
                openingBalanceMinor = account.openingBalance.minorUnits,
                type = account.type.name,
                isArchived = account.isArchived,
                sortOrder = 0,
            ),
        )
    }

    override suspend fun setAccountArchived(accountId: AccountId, isArchived: Boolean) =
        dao.setAccountArchived(accountId.value, isArchived)

    override suspend fun saveCategory(category: Category) {
        dao.upsertCategory(
            CategoryEntity(
                id = category.id.value,
                profileId = PRIMARY_PROFILE_ID,
                name = category.name,
                kind = category.kind.name,
                parentId = category.parentId?.value,
                sortOrder = category.sortOrder,
                isArchived = category.isArchived,
            ),
        )
    }

    override suspend fun setCategoryArchived(categoryId: CategoryId, isArchived: Boolean) =
        dao.setCategoryArchived(categoryId.value, isArchived)

    override suspend fun saveTag(tag: Tag) {
        dao.upsertTag(
            TagEntity(
                id = tag.id.value,
                profileId = PRIMARY_PROFILE_ID,
                name = tag.name,
                colorHex = tag.colorHex,
                createdAt = Instant.EPOCH.toString(),
            ),
        )
    }

    override suspend fun deleteTag(tagId: TagId) = dao.deleteTagById(tagId.value)

    override suspend fun saveTransaction(transaction: Transaction) {
        database.withTransaction {
            dao.upsertTransactions(listOf(transaction.toEntity()))
            dao.deleteTransactionTagsForTransaction(transaction.id.value)
            dao.deleteAttachmentsForTransaction(transaction.id.value)
            dao.upsertTransactionTagRefs(
                transaction.tagIds.map {
                    TransactionTagCrossRef(transaction.id.value, it.value)
                },
            )
            transaction.attachments.forEach {
                dao.upsertAttachment(it.toEntity(transaction.id))
            }
        }
    }

    override suspend fun deleteTransaction(transactionId: TransactionId) =
        dao.deleteTransactionById(transactionId.value)

    override suspend fun saveMerchantRule(rule: MerchantRule) {
        dao.upsertMerchantRule(rule.toEntity())
    }

    override suspend fun setMerchantRuleEnabled(ruleId: String, isEnabled: Boolean) =
        dao.setMerchantRuleEnabled(ruleId, isEnabled)

    override suspend fun saveBudget(budget: Budget) {
        dao.upsertBudget(budget.toEntity())
    }

    override suspend fun setBudgetArchived(budgetId: BudgetId, isArchived: Boolean) =
        dao.setBudgetArchived(budgetId.value, isArchived)

    override suspend fun saveScheduledTransaction(schedule: ScheduledTransaction) {
        dao.upsertScheduledTransaction(schedule.toEntity())
    }

    override suspend fun setScheduledTransactionArchived(scheduleId: ScheduleId, isArchived: Boolean) =
        dao.setScheduledTransactionArchived(scheduleId.value, isArchived)

    override suspend fun postScheduledTransaction(
        scheduleId: ScheduleId,
        postingDate: LocalDate,
    ): PostedScheduleResult {
        lateinit var result: PostedScheduleResult
        database.withTransaction {
            val schedule = requireNotNull(dao.getScheduledTransaction(scheduleId.value)) {
                "Scheduled transaction ${scheduleId.value} was not found."
            }.let(::mapScheduledTransaction)
            result = ScheduleCalculator.postNow(schedule, postingDate)
            dao.upsertTransactions(listOf(result.transaction.toEntity()))
            dao.upsertScheduledTransaction(result.updatedSchedule.toEntity())
        }
        return result
    }

    override suspend fun saveSavingsGoal(goal: SavingsGoal) {
        dao.upsertSavingsGoal(goal.toEntity())
    }

    override suspend fun setSavingsGoalArchived(goalId: SavingsGoalId, isArchived: Boolean) =
        dao.setSavingsGoalArchived(goalId.value, isArchived)

    override suspend fun saveSavingsGoalContribution(contribution: SavingsGoalContribution) {
        dao.upsertSavingsGoalContribution(contribution.toEntity())
    }

    override suspend fun saveDebtPayoffPlan(plan: DebtPayoffPlan) {
        dao.upsertDebtPayoffPlan(plan.toEntity())
    }

    override suspend fun setDebtPayoffPlanArchived(planId: DebtPlanId, isArchived: Boolean) =
        dao.setDebtPayoffPlanArchived(planId.value, isArchived)

    override suspend fun saveReviewedImport(command: ImportReviewSaveCommand): ImportReviewSaveResult {
        val validCategoryIds = dao.observeCategories().first().map { it.id }.toSet()
        val selectedRows = command.rows.filter { it.isSelected && !it.isDuplicate }
        val transactions = selectedRows.mapIndexed { index, row ->
            val localDate = requireNotNull(row.localDate) {
                "Selected import rows must include a transaction date."
            }
            Transaction.posting(
                id = command.importTransactionId(row.sourceRow, index, row.normalizedMerchant),
                accountId = command.accountId,
                amount = row.amount,
                kind = row.kind,
                localDate = localDate,
                merchant = row.merchant,
                normalizedMerchant = row.normalizedMerchant,
                categoryId = row.suggestedCategoryId?.takeIf { it.value in validCategoryIds },
                subcategoryId = row.suggestedSubcategoryId?.takeIf { it.value in validCategoryIds },
                source = TransactionSourceMetadata(
                    sourceName = command.sourceName,
                    sourceRow = row.sourceRow,
                    rawDescription = row.merchant,
                    importBatchId = command.batchId,
                ),
            )
        }

        database.withTransaction {
            if (transactions.isNotEmpty()) {
                dao.upsertTransactions(transactions.map { it.toEntity() })
            }
        }

        return ImportReviewSaveResult(
            batchId = command.batchId,
            savedCount = transactions.size,
            skippedCount = command.rows.size - transactions.size,
        )
    }

    override suspend fun createCompleteBackupSnapshot(createdAt: Instant): CompleteBackupSnapshot =
        BackupEngine.completeSnapshot(
            createdAt = createdAt,
            accounts = observeAccounts().first(),
            categories = observeCategories().first(),
            tags = observeTags().first(),
            transactions = observeTransactions().first(),
            merchantRules = observeMerchantRules().first(),
            budgets = observeBudgets().first(),
            scheduledTransactions = observeScheduledTransactions().first(),
            savingsGoals = observeSavingsGoals().first(),
            savingsGoalContributions = observeSavingsGoalContributions().first(),
            debtPayoffPlans = observeDebtPayoffPlans().first(),
        )

    override suspend fun previewRestore(snapshot: CompleteBackupSnapshot) =
        BackupEngine.restorePreview(
            schemaVersion = snapshot.manifest.schemaVersion,
            recordCounts = snapshot.manifest.recordCounts,
        )

    override suspend fun restoreCompleteBackup(snapshot: CompleteBackupSnapshot) {
        require(previewRestore(snapshot).canRestore) {
            "Backup cannot be restored by this app version."
        }
        database.withTransaction {
            dao.clearWorkspace()
            val baseCurrency = snapshot.accounts.firstOrNull()?.currency?.value ?: "AED"
            dao.upsertProfile(
                ProfileEntity(
                    id = PRIMARY_PROFILE_ID,
                    displayName = "Restored User",
                    baseCurrency = baseCurrency,
                    countryCode = null,
                    timeZoneId = null,
                ),
            )
            snapshot.accounts.forEach { dao.upsertAccount(it.toEntity()) }
            snapshot.categories.forEach { dao.upsertCategory(it.toEntity()) }
            snapshot.tags.forEach { dao.upsertTag(it.toEntity()) }
            snapshot.merchantRules.forEach { dao.upsertMerchantRule(it.toEntity()) }
            snapshot.budgets.forEach { dao.upsertBudget(it.toEntity()) }
            snapshot.scheduledTransactions.forEach { dao.upsertScheduledTransaction(it.toEntity()) }
            snapshot.savingsGoals.forEach { dao.upsertSavingsGoal(it.toEntity()) }
            snapshot.savingsGoalContributions.forEach {
                dao.upsertSavingsGoalContribution(it.toEntity())
            }
            snapshot.debtPayoffPlans.forEach { dao.upsertDebtPayoffPlan(it.toEntity()) }
            if (snapshot.transactions.isNotEmpty()) {
                dao.upsertTransactions(snapshot.transactions.map { it.toEntity() })
                dao.upsertTransactionTagRefs(
                    snapshot.transactions.flatMap { transaction ->
                        transaction.tagIds.map {
                            TransactionTagCrossRef(transaction.id.value, it.value)
                        }
                    },
                )
                snapshot.transactions.flatMap { transaction ->
                    transaction.attachments.map { it.toEntity(transaction.id) }
                }.forEach { dao.upsertAttachment(it) }
            }
        }
    }

    override suspend fun createLocalWorkspace(displayName: String, currency: CurrencyCode) {
        seeder.seed(currency, displayName)
    }

    override suspend fun savePrivacySettings(settings: PrivacySettings) {
        settingsStore.savePrivacySettings(settings)
    }

    override suspend fun saveNotificationSettings(settings: NotificationSettings) {
        settingsStore.saveNotificationSettings(settings)
    }

    override suspend fun saveRegionalSettings(settings: RegionalSettings) {
        settingsStore.saveRegionalSettings(settings)
    }

    override suspend fun clearWorkspace() {
        database.clearWorkspace()
        settingsStore.reset()
    }

    private fun mapTransaction(row: TransactionWithRelations): Transaction {
        val entity = row.transaction
        return Transaction(
            id = TransactionId(entity.id),
            accountId = AccountId(entity.accountId),
            amount = Money(entity.amountMinor, CurrencyCode.of(entity.currencyCode)),
            kind = TransactionKind.valueOf(entity.kind),
            localDate = LocalDate.parse(entity.localDate),
            merchant = entity.merchant,
            normalizedMerchant = entity.normalizedMerchant,
            note = entity.note,
            categoryId = entity.categoryId?.let(::CategoryId),
            subcategoryId = entity.subcategoryId?.let(::CategoryId),
            tagIds = row.tagRefs.map { TagId(it.tagId) },
            attachments = row.attachments.map {
                TransactionAttachment(
                    id = AttachmentId(it.id),
                    fileName = it.fileName,
                    originalFileName = it.originalFileName,
                    contentType = it.contentType,
                    createdAt = Instant.parse(it.createdAt),
                )
            },
            source = entity.toSource(),
            transferId = entity.transferId?.let(::TransferId),
            transferDirection = entity.transferDirection?.let(TransferDirection::valueOf),
        )
    }

    private fun mapMerchantRule(entity: MerchantRuleEntity): MerchantRule {
        val amountCurrency = entity.amountCurrencyCode?.let(CurrencyCode::of)
        return MerchantRule(
            id = entity.id,
            pattern = entity.pattern,
            matchType = MatchType.valueOf(entity.matchType),
            categoryId = CategoryId(entity.categoryId),
            subcategoryId = entity.subcategoryId?.let(::CategoryId),
            kind = TransactionKind.valueOf(entity.kind),
            confidence = entity.confidence,
            sampleCount = entity.sampleCount,
            isEnabled = entity.isEnabled,
            accountId = entity.accountId?.let(::AccountId),
            notePattern = entity.notePattern,
            minAmount = entity.minAmountMinor?.let {
                Money(it, requireNotNull(amountCurrency) { "Merchant rule min amount requires a currency." })
            },
            maxAmount = entity.maxAmountMinor?.let {
                Money(it, requireNotNull(amountCurrency) { "Merchant rule max amount requires a currency." })
            },
            priority = entity.priority,
            isAutoGenerated = entity.isAutoGenerated,
        )
    }

    private fun mapBudget(entity: BudgetEntity): Budget {
        val currency = CurrencyCode.of(entity.currencyCode)
        return Budget(
            id = BudgetId(entity.id),
            categoryId = CategoryId(entity.categoryId),
            subcategoryId = entity.subcategoryId?.let(::CategoryId),
            month = YearMonth.parse(entity.month),
            amount = Money(entity.amountMinor, currency),
            rolloverEnabled = entity.rolloverEnabled,
            isArchived = entity.isArchived,
        )
    }

    private fun mapScheduledTransaction(entity: ScheduledTransactionEntity): ScheduledTransaction {
        val currency = CurrencyCode.of(entity.currencyCode)
        return ScheduledTransaction(
            id = ScheduleId(entity.id),
            accountId = AccountId(entity.accountId),
            amount = Money(entity.amountMinor, currency),
            kind = TransactionKind.valueOf(entity.kind),
            merchant = entity.merchant,
            normalizedMerchant = entity.normalizedMerchant,
            categoryId = entity.categoryId?.let(::CategoryId),
            subcategoryId = entity.subcategoryId?.let(::CategoryId),
            note = entity.note,
            frequency = ScheduleFrequency.valueOf(entity.frequency),
            nextDate = LocalDate.parse(entity.nextDate),
            lastRunDate = entity.lastRunDate?.let(LocalDate::parse),
            status = ScheduleStatus.valueOf(entity.status),
            reminderEnabled = entity.reminderEnabled,
        )
    }

    private fun mapSavingsGoal(entity: SavingsGoalEntity): SavingsGoal {
        val currency = CurrencyCode.of(entity.currencyCode)
        return SavingsGoal(
            id = SavingsGoalId(entity.id),
            name = entity.name,
            targetAmount = Money(entity.targetAmountMinor, currency),
            currentAmount = Money(entity.currentAmountMinor, currency),
            targetDate = entity.targetDate?.let(LocalDate::parse),
            isArchived = entity.isArchived,
        )
    }

    private fun mapSavingsGoalContribution(
        entity: SavingsGoalContributionEntity,
    ): SavingsGoalContribution {
        val currency = CurrencyCode.of(entity.currencyCode)
        return SavingsGoalContribution(
            id = GoalContributionId(entity.id),
            goalId = SavingsGoalId(entity.goalId),
            amount = Money(entity.amountMinor, currency),
            direction = SavingsGoalContributionDirection.valueOf(entity.direction),
            localDate = LocalDate.parse(entity.localDate),
            note = entity.note,
        )
    }

    private fun mapDebtPayoffPlan(entity: DebtPayoffPlanEntity): DebtPayoffPlan {
        val currency = CurrencyCode.of(entity.currencyCode)
        return DebtPayoffPlan(
            id = DebtPlanId(entity.id),
            name = entity.name,
            originalBalance = Money(entity.originalBalanceMinor, currency),
            currentBalance = Money(entity.currentBalanceMinor, currency),
            annualInterestRateBasisPoints = entity.annualInterestRateBasisPoints,
            minimumPayment = Money(entity.minimumPaymentMinor, currency),
            extraPayment = Money(entity.extraPaymentMinor, currency),
            strategy = DebtPayoffStrategy.valueOf(entity.strategy),
            isArchived = entity.isArchived,
        )
    }

    private fun Budget.toEntity(): BudgetEntity = BudgetEntity(
        id = id.value,
        profileId = PRIMARY_PROFILE_ID,
        categoryId = categoryId.value,
        subcategoryId = subcategoryId?.value,
        month = month.toString(),
        amountMinor = amount.minorUnits,
        currencyCode = amount.currency.value,
        rolloverEnabled = rolloverEnabled,
        isArchived = isArchived,
    )

    private fun Account.toEntity(): AccountEntity = AccountEntity(
        id = id.value,
        profileId = PRIMARY_PROFILE_ID,
        name = name,
        currencyCode = currency.value,
        openingBalanceMinor = openingBalance.minorUnits,
        type = type.name,
        isArchived = isArchived,
        sortOrder = 0,
    )

    private fun Category.toEntity(): CategoryEntity = CategoryEntity(
        id = id.value,
        profileId = PRIMARY_PROFILE_ID,
        name = name,
        kind = kind.name,
        parentId = parentId?.value,
        sortOrder = sortOrder,
        isArchived = isArchived,
    )

    private fun Tag.toEntity(): TagEntity = TagEntity(
        id = id.value,
        profileId = PRIMARY_PROFILE_ID,
        name = name,
        colorHex = colorHex,
        createdAt = Instant.EPOCH.toString(),
    )

    private fun ScheduledTransaction.toEntity(): ScheduledTransactionEntity =
        ScheduledTransactionEntity(
            id = id.value,
            profileId = PRIMARY_PROFILE_ID,
            accountId = accountId.value,
            amountMinor = amount.minorUnits,
            currencyCode = amount.currency.value,
            kind = kind.name,
            merchant = merchant,
            normalizedMerchant = normalizedMerchant,
            categoryId = categoryId?.value,
            subcategoryId = subcategoryId?.value,
            note = note,
            frequency = frequency.name,
            nextDate = nextDate.toString(),
            lastRunDate = lastRunDate?.toString(),
            status = status.name,
            reminderEnabled = reminderEnabled,
        )

    private fun SavingsGoal.toEntity(): SavingsGoalEntity = SavingsGoalEntity(
        id = id.value,
        profileId = PRIMARY_PROFILE_ID,
        name = name,
        targetAmountMinor = targetAmount.minorUnits,
        currentAmountMinor = currentAmount.minorUnits,
        currencyCode = targetAmount.currency.value,
        targetDate = targetDate?.toString(),
        isArchived = isArchived,
    )

    private fun SavingsGoalContribution.toEntity(): SavingsGoalContributionEntity =
        SavingsGoalContributionEntity(
            id = id.value,
            goalId = goalId.value,
            amountMinor = amount.minorUnits,
            currencyCode = amount.currency.value,
            direction = direction.name,
            localDate = localDate.toString(),
            note = note,
        )

    private fun DebtPayoffPlan.toEntity(): DebtPayoffPlanEntity = DebtPayoffPlanEntity(
        id = id.value,
        profileId = PRIMARY_PROFILE_ID,
        name = name,
        originalBalanceMinor = originalBalance.minorUnits,
        currentBalanceMinor = currentBalance.minorUnits,
        currencyCode = originalBalance.currency.value,
        annualInterestRateBasisPoints = annualInterestRateBasisPoints,
        minimumPaymentMinor = minimumPayment.minorUnits,
        extraPaymentMinor = extraPayment.minorUnits,
        strategy = strategy.name,
        isArchived = isArchived,
    )

    private fun MerchantRule.toEntity(): MerchantRuleEntity {
        val amountCurrency = minAmount?.currency ?: maxAmount?.currency
        return MerchantRuleEntity(
            id = id,
            profileId = PRIMARY_PROFILE_ID,
            pattern = pattern,
            matchType = matchType.name,
            categoryId = categoryId.value,
            subcategoryId = subcategoryId?.value,
            kind = kind.name,
            confidence = confidence,
            sampleCount = sampleCount,
            isEnabled = isEnabled,
            createdAt = Instant.EPOCH.toString(),
            accountId = accountId?.value,
            notePattern = notePattern,
            minAmountMinor = minAmount?.minorUnits,
            maxAmountMinor = maxAmount?.minorUnits,
            amountCurrencyCode = amountCurrency?.value,
            priority = priority,
            isAutoGenerated = isAutoGenerated,
        )
    }

    private fun Transaction.toEntity(): TransactionEntity = TransactionEntity(
        id = id.value,
        accountId = accountId.value,
        localDate = localDate.toString(),
        amountMinor = amount.minorUnits,
        currencyCode = amount.currency.value,
        kind = kind.name,
        merchant = merchant,
        normalizedMerchant = normalizedMerchant,
        note = note,
        categoryId = categoryId?.value,
        subcategoryId = subcategoryId?.value,
        transferId = transferId?.value,
        transferDirection = transferDirection?.name,
        importBatchId = source?.importBatchId?.value,
        rawDescription = source?.rawDescription.orEmpty(),
        sourceName = source?.sourceName,
        sourceRow = source?.sourceRow,
    )

    private fun TransactionAttachment.toEntity(transactionId: TransactionId): TransactionAttachmentEntity =
        TransactionAttachmentEntity(
            id = id.value,
            transactionId = transactionId.value,
            fileName = fileName,
            originalFileName = originalFileName,
            contentType = contentType,
            createdAt = createdAt.toString(),
        )

    private fun TransactionEntity.toSource(): TransactionSourceMetadata? {
        if (
            importBatchId == null &&
            rawDescription.isBlank() &&
            sourceName == null &&
            sourceRow == null
        ) {
            return null
        }
        return TransactionSourceMetadata(
            sourceName = sourceName,
            sourceRow = sourceRow,
            rawDescription = rawDescription,
            importBatchId = importBatchId?.let(::ImportBatchId),
        )
    }

    private fun ImportReviewSaveCommand.importTransactionId(
        sourceRow: Int?,
        index: Int,
        normalizedMerchant: String,
    ): String {
        val normalizedSuffix = normalizedMerchant
            .lowercase(Locale.ROOT)
            .replace(Regex("""[^a-z0-9]+"""), "-")
            .trim('-')
            .take(24)
            .ifBlank { "row" }
        return "import-${batchId.value}-${sourceRow ?: index + 1}-$normalizedSuffix"
    }

    private companion object {
        const val PRIMARY_PROFILE_ID = "primary-user"
    }
}
