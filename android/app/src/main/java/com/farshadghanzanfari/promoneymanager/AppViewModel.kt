package com.farshadghanzanfari.promoneymanager

import android.net.Uri
import com.farshadghanzanfari.promoneymanager.backup.BackupCodec
import com.farshadghanzanfari.promoneymanager.backup.BackupFileStore
import com.farshadghanzanfari.promoneymanager.backup.TransactionsCsvWriter
import com.farshadghanzanfari.promoneymanager.importing.ImportDocumentReader
import com.farshadghanzanfari.promoneymanager.reminders.ReminderScheduler
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.farshadghanzanfari.promoneymanager.core.domain.BackupEngine
import com.farshadghanzanfari.promoneymanager.core.domain.CategorizationBulkApplyPlan
import com.farshadghanzanfari.promoneymanager.core.domain.MerchantNormalizer
import com.farshadghanzanfari.promoneymanager.core.domain.SavingsGoalCalculator
import com.farshadghanzanfari.promoneymanager.core.domain.SmartCategorizationService
import com.farshadghanzanfari.promoneymanager.core.domain.TransferPostingFactory
import com.farshadghanzanfari.promoneymanager.core.domain.UniversalImportParser
import com.farshadghanzanfari.promoneymanager.core.domain.WorkspaceRepository
import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.farshadghanzanfari.promoneymanager.core.model.Budget
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffPlan
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffStrategy
import com.farshadghanzanfari.promoneymanager.core.model.DebtPlanId
import com.farshadghanzanfari.promoneymanager.core.model.ImportBatchId
import com.farshadghanzanfari.promoneymanager.core.model.ImportFormat
import com.farshadghanzanfari.promoneymanager.core.model.ImportReviewSaveCommand
import com.farshadghanzanfari.promoneymanager.core.model.MatchType
import com.farshadghanzanfari.promoneymanager.core.model.MerchantRule
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.NotificationSettings
import com.farshadghanzanfari.promoneymanager.core.model.ParsedImportTransaction
import com.farshadghanzanfari.promoneymanager.core.model.PrivacySettings
import com.farshadghanzanfari.promoneymanager.core.model.RegionalSettings
import com.farshadghanzanfari.promoneymanager.core.model.BudgetId
import com.farshadghanzanfari.promoneymanager.core.model.CompleteBackupSnapshot
import com.farshadghanzanfari.promoneymanager.core.model.GoalContributionId
import com.farshadghanzanfari.promoneymanager.core.model.NotificationPermissionState
import com.farshadghanzanfari.promoneymanager.core.model.RestorePreview
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
import com.farshadghanzanfari.promoneymanager.core.model.TransactionId
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.farshadghanzanfari.promoneymanager.core.model.TransferId
import dagger.hilt.android.lifecycle.HiltViewModel
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.UUID
import javax.inject.Inject
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class AppUiState(
    val isLoading: Boolean = false,
    val hasWorkspace: Boolean = false,
    val accounts: List<Account> = emptyList(),
    val categories: List<Category> = emptyList(),
    val tags: List<Tag> = emptyList(),
    val transactions: List<Transaction> = emptyList(),
    val merchantRules: List<MerchantRule> = emptyList(),
    val budgets: List<Budget> = emptyList(),
    val scheduledTransactions: List<ScheduledTransaction> = emptyList(),
    val savingsGoals: List<SavingsGoal> = emptyList(),
    val savingsGoalContributions: List<SavingsGoalContribution> = emptyList(),
    val debtPayoffPlans: List<DebtPayoffPlan> = emptyList(),
    val privacySettings: PrivacySettings = PrivacySettings(),
    val notificationSettings: NotificationSettings = NotificationSettings(),
    val regionalSettings: RegionalSettings = RegionalSettings(),
    val importText: String = "",
    val importRows: List<ParsedImportTransaction> = emptyList(),
    val importStatus: String? = null,
    val importSourceName: String = "Pasted statement",
    val isImporting: Boolean = false,
    val errorMessage: String? = null,
    val backupStatus: String? = null,
    val restorePreview: RestorePreview? = null,
)

@HiltViewModel
class AppViewModel @Inject constructor(
    private val repository: WorkspaceRepository,
    private val importDocumentReader: ImportDocumentReader,
    private val backupFileStore: BackupFileStore,
    private val reminderScheduler: ReminderScheduler,
) : ViewModel() {
    private val importState = MutableStateFlow(AppUiState())
    private var pendingRestoreSnapshot: CompleteBackupSnapshot? = null

    init {
        viewModelScope.launch {
            combine(
                repository.observeScheduledTransactions(),
                repository.observeNotificationSettings(),
                repository.observeRegionalSettings(),
            ) { schedules, notificationSettings, regionalSettings ->
                Triple(schedules, notificationSettings, regionalSettings)
            }.collect { (schedules, notificationSettings, regionalSettings) ->
                val zoneId = runCatching { ZoneId.of(regionalSettings.timeZoneId) }
                    .getOrDefault(ZoneId.systemDefault())
                runCatching {
                    reminderScheduler.sync(
                        schedules = schedules,
                        remindersAllowed = notificationSettings.canScheduleReminder,
                        zoneId = zoneId,
                    )
                }
            }
        }
    }

    private val financeState = combine(
        repository.observeAccounts(),
        repository.observeCategories(),
        repository.observeTags(),
        repository.observeTransactions(),
        repository.observeMerchantRules(),
    ) { accounts, categories, tags, transactions, merchantRules ->
            AppUiState(
                hasWorkspace = accounts.isNotEmpty(),
                accounts = accounts,
                categories = categories,
                tags = tags,
                transactions = transactions,
                merchantRules = merchantRules,
            )
        }

    private val repositoryState = combine(
        financeState,
        repository.observeBudgets(),
    ) { financeState, budgets ->
        financeState.copy(budgets = budgets)
    }
        .let { state ->
            combine(state, repository.observeScheduledTransactions()) { current, schedules ->
                current.copy(scheduledTransactions = schedules)
            }
        }
        .let { state ->
            combine(state, repository.observeSavingsGoals()) { current, goals ->
                current.copy(savingsGoals = goals)
            }
        }
        .let { state ->
            combine(state, repository.observeSavingsGoalContributions()) { current, contributions ->
                current.copy(savingsGoalContributions = contributions)
            }
        }
        .let { state ->
            combine(state, repository.observeDebtPayoffPlans()) { current, debts ->
                current.copy(debtPayoffPlans = debts)
            }
        }
        .let { state ->
            combine(state, repository.observePrivacySettings()) { current, settings ->
                current.copy(privacySettings = settings)
            }
        }
        .let { state ->
            combine(state, repository.observeNotificationSettings()) { current, settings ->
                current.copy(notificationSettings = settings)
            }
        }
        .let { state ->
            combine(state, repository.observeRegionalSettings()) { current, settings ->
                current.copy(regionalSettings = settings)
            }
        }

    val uiState: StateFlow<AppUiState> = combine(
        repositoryState,
        importState,
    ) { repositoryState, importState ->
        repositoryState.copy(
            importText = importState.importText,
            importRows = importState.importRows,
            importStatus = importState.importStatus,
            importSourceName = importState.importSourceName,
            isImporting = importState.isImporting,
            errorMessage = importState.errorMessage,
            backupStatus = importState.backupStatus,
            restorePreview = importState.restorePreview,
        )
    }
        .stateIn(
            scope = viewModelScope,
            started = SharingStarted.WhileSubscribed(5_000),
            initialValue = AppUiState(isLoading = true),
        )

    fun updateImportText(text: String) {
        importState.update { it.copy(importText = text, errorMessage = null) }
    }

    fun acceptSharedImportText(text: String) {
        val draft = text.trim()
        if (draft.isEmpty()) return
        importState.update {
            it.copy(
                importText = draft,
                importRows = emptyList(),
                importStatus = "Shared from Android share target. Review before saving.",
                importSourceName = "Shared text",
                errorMessage = null,
            )
        }
    }

    fun parseImportText() {
        val state = uiState.value
        if (state.isImporting || state.importText.isBlank()) return
        importState.update { it.copy(isImporting = true, errorMessage = null) }
        parseImport(
            text = state.importText,
            format = ImportFormat.PDF,
            sourceName = "Pasted statement",
            preserveInputText = true,
        )
    }

    fun importDocument(uri: Uri, mimeType: String?, displayName: String?) {
        importState.update {
            it.copy(
                isImporting = true,
                importRows = emptyList(),
                importStatus = "Reading ${displayName ?: "selected document"}…",
                errorMessage = null,
            )
        }
        viewModelScope.launch {
            runCatching {
                importDocumentReader.read(uri, mimeType, displayName)
            }.onSuccess { document ->
                parseImport(document.text, document.format, document.displayName)
            }.onFailure { error ->
                importState.update {
                    it.copy(
                        isImporting = false,
                        importStatus = null,
                        errorMessage = error.message ?: "The selected document could not be read.",
                    )
                }
            }
        }
    }

    private fun parseImport(
        text: String,
        format: ImportFormat,
        sourceName: String,
        preserveInputText: Boolean = false,
    ) {
        val state = uiState.value
        val account = defaultImportAccount(state)
        if (account == null) {
            importState.update { it.copy(isImporting = false, errorMessage = "Create an account before importing.") }
            return
        }
        viewModelScope.launch {
            runCatching {
                UniversalImportParser.parseText(
                    text = text,
                    format = format,
                    accountId = account.id,
                    fallbackCurrency = account.currency,
                    rules = state.merchantRules + learnedRulesNotYetSaved(state.transactions, state.merchantRules),
                    existingTransactions = state.transactions,
                )
            }.onSuccess { rows ->
                importState.update {
                    it.copy(
                        importText = if (preserveInputText) text else "",
                        importRows = rows,
                        importStatus = "${rows.size} rows ready for review",
                        importSourceName = sourceName,
                        isImporting = false,
                        errorMessage = null,
                    )
                }
            }.onFailure { error ->
                importState.update {
                    it.copy(isImporting = false, errorMessage = error.message ?: "Import parsing failed.")
                }
            }
        }
    }

    // Transient rules learned from the user's own categorization history, applied to this parse only.
    private fun learnedRulesNotYetSaved(
        transactions: List<Transaction>,
        existingRules: List<MerchantRule>,
    ): List<MerchantRule> =
        SmartCategorizationService.learnRuleCandidates(
            transactions = transactions,
            existingRules = existingRules,
        ).map { candidate ->
            MerchantRule(
                id = "learned-${candidate.pattern}-${candidate.categoryId.value}",
                pattern = candidate.pattern,
                matchType = MatchType.CONTAINS,
                categoryId = candidate.categoryId,
                subcategoryId = candidate.subcategoryId,
                kind = candidate.kind,
                confidence = candidate.confidence,
                sampleCount = candidate.sampleCount,
                isAutoGenerated = true,
            )
        }

    fun selectCleanImportRows() {
        importState.update { current ->
            current.copy(
                importRows = current.importRows.map { row ->
                    row.copy(isSelected = !row.isDuplicate && !row.isReviewOnly)
                },
            )
        }
    }

    fun toggleImportRow(sourceRow: Int?) {
        importState.update { current ->
            current.copy(
                importRows = current.importRows.map { row ->
                    if (row.sourceRow == sourceRow && !row.isDuplicate) {
                        row.copy(isSelected = !row.isSelected)
                    } else {
                        row
                    }
                },
            )
        }
    }

    fun editImportRow(
        sourceRow: Int?,
        merchant: String,
        amountMinorUnits: Long,
        categoryId: CategoryId?,
        localDate: LocalDate?,
    ) {
        importState.update { current ->
            current.copy(
                importRows = current.importRows.map { row ->
                    if (row.sourceRow == sourceRow) {
                        row.copy(
                            merchant = merchant,
                            normalizedMerchant = MerchantNormalizer.normalize(merchant),
                            amount = row.amount.copy(minorUnits = amountMinorUnits),
                            suggestedCategoryId = categoryId,
                            suggestedSubcategoryId = null,
                            localDate = localDate ?: row.localDate,
                            isSelected = !row.isDuplicate,
                            isReviewOnly = false,
                        )
                    } else {
                        row
                    }
                },
            )
        }
    }

    fun saveReviewedImport() {
        val state = uiState.value
        val account = defaultImportAccount(state)
        if (account == null) {
            importState.update { it.copy(errorMessage = "Create an account before importing.") }
            return
        }
        viewModelScope.launch {
            runCatching {
                repository.saveReviewedImport(
                    ImportReviewSaveCommand(
                        batchId = ImportBatchId("pasted-${System.currentTimeMillis()}"),
                        sourceName = state.importSourceName,
                        accountId = account.id,
                        rows = state.importRows,
                    ),
                )
            }.onSuccess { result ->
                importState.update {
                    it.copy(
                        importStatus = "Saved ${result.savedCount} imported transactions",
                        importRows = emptyList(),
                        importText = "",
                        errorMessage = null,
                    )
                }
            }.onFailure { error ->
                importState.update {
                    it.copy(errorMessage = error.message ?: "Import save failed.")
                }
            }
        }
    }

    private fun defaultImportAccount(state: AppUiState): Account? =
        state.accounts.firstOrNull { !it.isArchived && it.type == AccountType.CREDIT_CARD }
            ?: state.accounts.firstOrNull { !it.isArchived }

    fun continueOnDevice(settings: RegionalSettings) = viewModelScope.launch {
        repository.saveRegionalSettings(settings)
        repository.createLocalWorkspace("Local User", settings.baseCurrency)
    }

    fun saveRegionalSettings(settings: RegionalSettings) = viewModelScope.launch {
        repository.saveRegionalSettings(settings)
    }

    fun saveTransaction(transaction: Transaction) = viewModelScope.launch {
        runCatching { repository.saveTransaction(transaction) }
            .onFailure { error ->
                importState.update {
                    it.copy(errorMessage = error.message ?: "Saving the transaction failed.")
                }
            }
    }

    fun deleteTransaction(transactionId: TransactionId) = viewModelScope.launch {
        runCatching { repository.deleteTransaction(transactionId) }
            .onFailure { error ->
                importState.update {
                    it.copy(errorMessage = error.message ?: "Deleting the transaction failed.")
                }
            }
    }

    private fun <T> save(label: String, value: T, saver: suspend (T) -> Unit) =
        viewModelScope.launch {
            runCatching { saver(value) }
                .onFailure { error ->
                    importState.update {
                        it.copy(errorMessage = error.message ?: "Saving the $label failed.")
                    }
                }
        }

    fun saveAccount(account: Account) = save("account", account, repository::saveAccount)

    fun setAccountArchived(accountId: AccountId, isArchived: Boolean) = viewModelScope.launch {
        runCatching { repository.setAccountArchived(accountId, isArchived) }
            .onFailure { error ->
                importState.update {
                    it.copy(errorMessage = error.message ?: "Updating the account failed.")
                }
            }
    }

    fun saveCategory(category: Category) = save("category", category, repository::saveCategory)

    fun saveTag(tag: Tag) = save("tag", tag, repository::saveTag)

    fun saveBudget(budget: Budget) = save("budget", budget, repository::saveBudget)

    fun saveScheduledTransaction(schedule: ScheduledTransaction) =
        save("schedule", schedule, repository::saveScheduledTransaction)

    fun saveSavingsGoal(goal: SavingsGoal) = save("goal", goal, repository::saveSavingsGoal)

    fun saveDebtPlan(plan: DebtPayoffPlan) = save("debt plan", plan, repository::saveDebtPayoffPlan)

    fun toggleAppLock() = viewModelScope.launch {
        val current = uiState.value.privacySettings
        repository.savePrivacySettings(current.copy(appLockEnabled = !current.appLockEnabled))
    }

    fun clearWorkspace() = viewModelScope.launch {
        repository.clearWorkspace()
    }

    fun saveTransfer(
        sourceAccountId: AccountId,
        destinationAccountId: AccountId,
        amount: Money,
        localDate: LocalDate,
        note: String,
    ) = viewModelScope.launch {
        runCatching {
            val postings = TransferPostingFactory.create(
                transferId = TransferId("transfer-${UUID.randomUUID()}"),
                sourceAccountId = sourceAccountId,
                destinationAccountId = destinationAccountId,
                sourceAmount = amount,
                destinationAmount = amount,
            )
            repository.saveTransaction(postings.source.copy(localDate = localDate, note = note))
            repository.saveTransaction(postings.destination.copy(localDate = localDate, note = note))
        }.onFailure { error ->
            importState.update {
                it.copy(errorMessage = error.message ?: "Saving the transfer failed.")
            }
        }
    }

    fun postScheduleNow(scheduleId: ScheduleId) = viewModelScope.launch {
        runCatching { repository.postScheduledTransaction(scheduleId, LocalDate.now()) }
            .onFailure { error ->
                importState.update {
                    it.copy(errorMessage = error.message ?: "Posting the scheduled transaction failed.")
                }
            }
    }

    fun setSchedulePaused(schedule: ScheduledTransaction, paused: Boolean) =
        save(
            "schedule",
            schedule.copy(status = if (paused) ScheduleStatus.PAUSED else ScheduleStatus.ACTIVE),
            repository::saveScheduledTransaction,
        )

    fun archiveSchedule(scheduleId: ScheduleId) = viewModelScope.launch {
        runCatching { repository.setScheduledTransactionArchived(scheduleId, true) }
            .onFailure { error ->
                importState.update {
                    it.copy(errorMessage = error.message ?: "Removing the schedule failed.")
                }
            }
    }

    fun setCategoryArchived(categoryId: CategoryId, isArchived: Boolean) = viewModelScope.launch {
        runCatching { repository.setCategoryArchived(categoryId, isArchived) }
            .onFailure { error ->
                importState.update {
                    it.copy(errorMessage = error.message ?: "Updating the category failed.")
                }
            }
    }

    fun setBudgetArchived(budgetId: BudgetId, isArchived: Boolean) = viewModelScope.launch {
        runCatching { repository.setBudgetArchived(budgetId, isArchived) }
            .onFailure { error ->
                importState.update {
                    it.copy(errorMessage = error.message ?: "Updating the budget failed.")
                }
            }
    }

    fun deleteTag(tagId: TagId) = viewModelScope.launch {
        runCatching { repository.deleteTag(tagId) }
            .onFailure { error ->
                importState.update {
                    it.copy(errorMessage = error.message ?: "Deleting the tag failed.")
                }
            }
    }

    fun setSavingsGoalArchived(goalId: SavingsGoalId, isArchived: Boolean) = viewModelScope.launch {
        runCatching { repository.setSavingsGoalArchived(goalId, isArchived) }
            .onFailure { error ->
                importState.update {
                    it.copy(errorMessage = error.message ?: "Updating the goal failed.")
                }
            }
    }

    fun setDebtPlanArchived(planId: DebtPlanId, isArchived: Boolean) = viewModelScope.launch {
        runCatching { repository.setDebtPayoffPlanArchived(planId, isArchived) }
            .onFailure { error ->
                importState.update {
                    it.copy(errorMessage = error.message ?: "Updating the debt plan failed.")
                }
            }
    }

    fun saveGoalContribution(
        goal: SavingsGoal,
        amount: Money,
        direction: SavingsGoalContributionDirection,
        note: String,
    ) = viewModelScope.launch {
        runCatching {
            val applied = SavingsGoalCalculator.applyContribution(
                goal = goal,
                contribution = SavingsGoalContribution(
                    id = GoalContributionId("contrib-${UUID.randomUUID()}"),
                    goalId = goal.id,
                    amount = amount,
                    direction = direction,
                    localDate = LocalDate.now(),
                    note = note,
                ),
            )
            repository.saveSavingsGoal(applied.updatedGoal)
            repository.saveSavingsGoalContribution(applied.contribution)
        }.onFailure { error ->
            importState.update {
                it.copy(errorMessage = error.message ?: "Saving the contribution failed.")
            }
        }
    }

    fun saveMerchantRule(rule: MerchantRule) = save("rule", rule, repository::saveMerchantRule)

    fun setMerchantRuleEnabled(ruleId: String, isEnabled: Boolean) = viewModelScope.launch {
        runCatching { repository.setMerchantRuleEnabled(ruleId, isEnabled) }
            .onFailure { error ->
                importState.update {
                    it.copy(errorMessage = error.message ?: "Updating the rule failed.")
                }
            }
    }

    fun applyCategorizationPlan(plan: CategorizationBulkApplyPlan) = viewModelScope.launch {
        runCatching {
            val transactionsById = uiState.value.transactions.associateBy { it.id }
            plan.operations.forEach { operation ->
                val transaction = transactionsById[operation.transactionId] ?: return@forEach
                repository.saveTransaction(
                    transaction.copy(
                        categoryId = operation.categoryId,
                        subcategoryId = operation.subcategoryId,
                    ),
                )
            }
        }.onFailure { error ->
            importState.update {
                it.copy(errorMessage = error.message ?: "Applying categorization failed.")
            }
        }
    }

    fun setRemindersEnabled(enabled: Boolean, permissionState: NotificationPermissionState) =
        viewModelScope.launch {
            repository.saveNotificationSettings(
                NotificationSettings(remindersEnabled = enabled, permissionState = permissionState),
            )
        }

    fun exportCompleteBackup(uri: Uri) = viewModelScope.launch {
        runCatching {
            val snapshot = repository.createCompleteBackupSnapshot(Instant.now())
            backupFileStore.writeText(uri, BackupCodec.encode(snapshot))
            snapshot
        }.onSuccess { snapshot ->
            importState.update {
                it.copy(
                    backupStatus = "Backup saved with ${snapshot.transactions.size} transactions.",
                    errorMessage = null,
                )
            }
        }.onFailure { error ->
            importState.update {
                it.copy(errorMessage = error.message ?: "Writing the backup failed.")
            }
        }
    }

    fun exportTransactionsCsv(uri: Uri) = viewModelScope.launch {
        runCatching {
            val state = uiState.value
            val csv = TransactionsCsvWriter.build(
                transactions = state.transactions,
                accounts = state.accounts,
                categories = state.categories,
                tags = state.tags,
            )
            backupFileStore.writeText(uri, csv)
            state.transactions.size
        }.onSuccess { count ->
            importState.update {
                it.copy(backupStatus = "CSV exported with $count transactions.", errorMessage = null)
            }
        }.onFailure { error ->
            importState.update {
                it.copy(errorMessage = error.message ?: "Writing the CSV export failed.")
            }
        }
    }

    fun previewRestore(uri: Uri) = viewModelScope.launch {
        runCatching {
            val snapshot = BackupCodec.decode(backupFileStore.readText(uri))
            pendingRestoreSnapshot = snapshot
            repository.previewRestore(snapshot)
        }.onSuccess { preview ->
            importState.update {
                it.copy(restorePreview = preview, backupStatus = null, errorMessage = null)
            }
        }.onFailure { error ->
            pendingRestoreSnapshot = null
            importState.update {
                it.copy(
                    restorePreview = null,
                    errorMessage = error.message ?: "Reading the backup failed.",
                )
            }
        }
    }

    fun confirmRestore() = viewModelScope.launch {
        val snapshot = pendingRestoreSnapshot ?: return@launch
        runCatching { repository.restoreCompleteBackup(snapshot) }
            .onSuccess {
                pendingRestoreSnapshot = null
                importState.update {
                    it.copy(
                        restorePreview = null,
                        backupStatus = "Backup restored with ${snapshot.transactions.size} transactions.",
                        errorMessage = null,
                    )
                }
            }
            .onFailure { error ->
                importState.update {
                    it.copy(errorMessage = error.message ?: "Restoring the backup failed.")
                }
            }
    }

    fun cancelRestore() {
        pendingRestoreSnapshot = null
        importState.update { it.copy(restorePreview = null) }
    }
}
