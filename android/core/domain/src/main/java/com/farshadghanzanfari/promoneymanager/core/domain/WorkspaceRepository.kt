package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.Budget
import com.farshadghanzanfari.promoneymanager.core.model.BudgetId
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CompleteBackupSnapshot
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffPlan
import com.farshadghanzanfari.promoneymanager.core.model.DebtPlanId
import com.farshadghanzanfari.promoneymanager.core.model.ImportReviewSaveCommand
import com.farshadghanzanfari.promoneymanager.core.model.ImportReviewSaveResult
import com.farshadghanzanfari.promoneymanager.core.model.MerchantRule
import com.farshadghanzanfari.promoneymanager.core.model.NotificationSettings
import com.farshadghanzanfari.promoneymanager.core.model.PrivacySettings
import com.farshadghanzanfari.promoneymanager.core.model.RegionalSettings
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoal
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContribution
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalId
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleId
import com.farshadghanzanfari.promoneymanager.core.model.ScheduledTransaction
import com.farshadghanzanfari.promoneymanager.core.model.Tag
import com.farshadghanzanfari.promoneymanager.core.model.TagId
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionId
import com.farshadghanzanfari.promoneymanager.core.model.RestorePreview
import java.time.Instant
import java.time.LocalDate
import kotlinx.coroutines.flow.Flow

interface WorkspaceRepository {
    fun observeAccounts(): Flow<List<Account>>

    fun observeCategories(): Flow<List<Category>>

    fun observeTags(): Flow<List<Tag>>

    fun observeTransactions(): Flow<List<Transaction>>

    fun observeMerchantRules(): Flow<List<MerchantRule>>

    fun observeBudgets(): Flow<List<Budget>>

    fun observeScheduledTransactions(): Flow<List<ScheduledTransaction>>

    fun observeSavingsGoals(): Flow<List<SavingsGoal>>

    fun observeSavingsGoalContributions(): Flow<List<SavingsGoalContribution>>

    fun observeDebtPayoffPlans(): Flow<List<DebtPayoffPlan>>

    fun observePrivacySettings(): Flow<PrivacySettings>

    fun observeNotificationSettings(): Flow<NotificationSettings>

    fun observeRegionalSettings(): Flow<RegionalSettings>

    suspend fun saveAccount(account: Account)

    suspend fun setAccountArchived(accountId: AccountId, isArchived: Boolean)

    suspend fun saveCategory(category: Category)

    suspend fun setCategoryArchived(categoryId: CategoryId, isArchived: Boolean)

    suspend fun saveTag(tag: Tag)

    suspend fun deleteTag(tagId: TagId)

    suspend fun saveTransaction(transaction: Transaction)

    suspend fun deleteTransaction(transactionId: TransactionId)

    suspend fun saveMerchantRule(rule: MerchantRule)

    suspend fun setMerchantRuleEnabled(ruleId: String, isEnabled: Boolean)

    suspend fun saveBudget(budget: Budget)

    suspend fun setBudgetArchived(budgetId: BudgetId, isArchived: Boolean)

    suspend fun saveScheduledTransaction(schedule: ScheduledTransaction)

    suspend fun setScheduledTransactionArchived(scheduleId: ScheduleId, isArchived: Boolean)

    suspend fun postScheduledTransaction(scheduleId: ScheduleId, postingDate: LocalDate): PostedScheduleResult

    suspend fun saveSavingsGoal(goal: SavingsGoal)

    suspend fun setSavingsGoalArchived(goalId: SavingsGoalId, isArchived: Boolean)

    suspend fun saveSavingsGoalContribution(contribution: SavingsGoalContribution)

    suspend fun saveDebtPayoffPlan(plan: DebtPayoffPlan)

    suspend fun setDebtPayoffPlanArchived(planId: DebtPlanId, isArchived: Boolean)

    suspend fun saveReviewedImport(command: ImportReviewSaveCommand): ImportReviewSaveResult

    suspend fun createCompleteBackupSnapshot(createdAt: Instant): CompleteBackupSnapshot

    suspend fun previewRestore(snapshot: CompleteBackupSnapshot): RestorePreview

    suspend fun restoreCompleteBackup(snapshot: CompleteBackupSnapshot)

    suspend fun savePrivacySettings(settings: PrivacySettings)

    suspend fun saveNotificationSettings(settings: NotificationSettings)

    suspend fun saveRegionalSettings(settings: RegionalSettings)

    suspend fun createLocalWorkspace(displayName: String, currency: CurrencyCode)

    suspend fun clearWorkspace()
}
