package com.farshadghanzanfari.promoneymanager.core.database

import androidx.room.Dao
import androidx.room.Query
import androidx.room.Transaction
import androidx.room.Upsert
import kotlinx.coroutines.flow.Flow

@Dao
interface FinanceDao {
    @Upsert
    suspend fun upsertProfile(profile: ProfileEntity)

    @Upsert
    suspend fun upsertAccount(account: AccountEntity)

    @Upsert
    suspend fun upsertCategory(category: CategoryEntity)

    @Upsert
    suspend fun upsertTag(tag: TagEntity)

    @Upsert
    suspend fun upsertTransactions(transactions: List<TransactionEntity>)

    @Upsert
    suspend fun upsertTransactionTagRefs(refs: List<TransactionTagCrossRef>)

    @Upsert
    suspend fun upsertAttachment(attachment: TransactionAttachmentEntity)

    @Upsert
    suspend fun upsertMerchantRule(rule: MerchantRuleEntity)

    @Upsert
    suspend fun upsertBudget(budget: BudgetEntity)

    @Upsert
    suspend fun upsertScheduledTransaction(schedule: ScheduledTransactionEntity)

    @Upsert
    suspend fun upsertSavingsGoal(goal: SavingsGoalEntity)

    @Upsert
    suspend fun upsertSavingsGoalContribution(contribution: SavingsGoalContributionEntity)

    @Upsert
    suspend fun upsertDebtPayoffPlan(plan: DebtPayoffPlanEntity)

    @Query("SELECT * FROM accounts ORDER BY sortOrder, name")
    fun observeAccounts(): Flow<List<AccountEntity>>

    @Query("SELECT * FROM categories ORDER BY sortOrder, name")
    fun observeCategories(): Flow<List<CategoryEntity>>

    @Query("SELECT * FROM tags ORDER BY name")
    fun observeTags(): Flow<List<TagEntity>>

    @Query("SELECT * FROM transactions ORDER BY localDate DESC, id")
    fun observeTransactions(): Flow<List<TransactionEntity>>

    @Transaction
    @Query("SELECT * FROM transactions ORDER BY localDate DESC, id")
    fun observeTransactionsWithRelations(): Flow<List<TransactionWithRelations>>

    @Query("SELECT tagId FROM transaction_tags WHERE transactionId = :transactionId ORDER BY tagId")
    suspend fun getTagIdsForTransaction(transactionId: String): List<String>

    @Query("SELECT * FROM transaction_attachments WHERE transactionId = :transactionId ORDER BY createdAt, id")
    fun observeAttachments(transactionId: String): Flow<List<TransactionAttachmentEntity>>

    @Query("SELECT * FROM merchant_rules ORDER BY priority DESC, sampleCount DESC, pattern")
    fun observeMerchantRules(): Flow<List<MerchantRuleEntity>>

    @Query("SELECT * FROM budgets ORDER BY month DESC, categoryId, subcategoryId")
    fun observeBudgets(): Flow<List<BudgetEntity>>

    @Query("SELECT * FROM scheduled_transactions ORDER BY nextDate, merchant")
    fun observeScheduledTransactions(): Flow<List<ScheduledTransactionEntity>>

    @Query("SELECT * FROM scheduled_transactions WHERE id = :scheduleId")
    suspend fun getScheduledTransaction(scheduleId: String): ScheduledTransactionEntity?

    @Query("SELECT * FROM savings_goals ORDER BY isArchived, name")
    fun observeSavingsGoals(): Flow<List<SavingsGoalEntity>>

    @Query("SELECT * FROM savings_goal_contributions ORDER BY localDate DESC, id")
    fun observeSavingsGoalContributions(): Flow<List<SavingsGoalContributionEntity>>

    @Query("SELECT * FROM debt_payoff_plans ORDER BY isArchived, name")
    fun observeDebtPayoffPlans(): Flow<List<DebtPayoffPlanEntity>>

    @Query("UPDATE accounts SET isArchived = :isArchived WHERE id = :accountId")
    suspend fun setAccountArchived(accountId: String, isArchived: Boolean)

    @Query("UPDATE categories SET isArchived = :isArchived WHERE id = :categoryId")
    suspend fun setCategoryArchived(categoryId: String, isArchived: Boolean)

    @Query("UPDATE merchant_rules SET isEnabled = :isEnabled WHERE id = :ruleId")
    suspend fun setMerchantRuleEnabled(ruleId: String, isEnabled: Boolean)

    @Query("UPDATE budgets SET isArchived = :isArchived WHERE id = :budgetId")
    suspend fun setBudgetArchived(budgetId: String, isArchived: Boolean)

    @Query("UPDATE scheduled_transactions SET status = CASE WHEN :isArchived THEN 'PAUSED' ELSE 'ACTIVE' END WHERE id = :scheduleId")
    suspend fun setScheduledTransactionArchived(scheduleId: String, isArchived: Boolean)

    @Query("UPDATE savings_goals SET isArchived = :isArchived WHERE id = :goalId")
    suspend fun setSavingsGoalArchived(goalId: String, isArchived: Boolean)

    @Query("UPDATE debt_payoff_plans SET isArchived = :isArchived WHERE id = :planId")
    suspend fun setDebtPayoffPlanArchived(planId: String, isArchived: Boolean)

    @Query("SELECT COUNT(*) FROM profiles")
    suspend fun countProfiles(): Int

    @Query("SELECT COUNT(*) FROM accounts")
    suspend fun countAccounts(): Int

    @Query("SELECT COUNT(*) FROM categories")
    suspend fun countCategories(): Int

    @Query("SELECT COUNT(*) FROM tags")
    suspend fun countTags(): Int

    @Query("SELECT COUNT(*) FROM transactions")
    suspend fun countTransactions(): Int

    @Query("SELECT COUNT(*) FROM transaction_tags")
    suspend fun countTransactionTags(): Int

    @Query("SELECT COUNT(*) FROM transaction_attachments")
    suspend fun countAttachments(): Int

    @Query("SELECT COUNT(*) FROM merchant_rules")
    suspend fun countMerchantRules(): Int

    @Query("SELECT COUNT(*) FROM budgets")
    suspend fun countBudgets(): Int

    @Query("SELECT COUNT(*) FROM scheduled_transactions")
    suspend fun countScheduledTransactions(): Int

    @Query("SELECT COUNT(*) FROM savings_goals")
    suspend fun countSavingsGoals(): Int

    @Query("SELECT COUNT(*) FROM savings_goal_contributions")
    suspend fun countSavingsGoalContributions(): Int

    @Query("SELECT COUNT(*) FROM debt_payoff_plans")
    suspend fun countDebtPayoffPlans(): Int

    @Query("DELETE FROM transaction_attachments")
    suspend fun deleteAttachments()

    @Query("DELETE FROM transaction_attachments WHERE transactionId = :transactionId")
    suspend fun deleteAttachmentsForTransaction(transactionId: String)

    @Query("DELETE FROM transaction_tags")
    suspend fun deleteTransactionTags()

    @Query("DELETE FROM transaction_tags WHERE transactionId = :transactionId")
    suspend fun deleteTransactionTagsForTransaction(transactionId: String)

    @Query("DELETE FROM tags WHERE id = :tagId")
    suspend fun deleteTagById(tagId: String)

    @Query("DELETE FROM transactions WHERE id = :transactionId")
    suspend fun deleteTransactionById(transactionId: String)

    @Query("DELETE FROM merchant_rules")
    suspend fun deleteMerchantRules()

    @Query("DELETE FROM budgets")
    suspend fun deleteBudgets()

    @Query("DELETE FROM scheduled_transactions")
    suspend fun deleteScheduledTransactions()

    @Query("DELETE FROM savings_goal_contributions")
    suspend fun deleteSavingsGoalContributions()

    @Query("DELETE FROM savings_goals")
    suspend fun deleteSavingsGoals()

    @Query("DELETE FROM debt_payoff_plans")
    suspend fun deleteDebtPayoffPlans()

    @Query("DELETE FROM transactions")
    suspend fun deleteTransactions()

    @Query("DELETE FROM tags")
    suspend fun deleteTags()

    @Query("DELETE FROM categories")
    suspend fun deleteCategories()

    @Query("DELETE FROM accounts")
    suspend fun deleteAccounts()

    @Query("DELETE FROM profiles")
    suspend fun deleteProfiles()

    @Transaction
    suspend fun clearWorkspace() {
        deleteAttachments()
        deleteTransactionTags()
        deleteMerchantRules()
        deleteBudgets()
        deleteScheduledTransactions()
        deleteSavingsGoalContributions()
        deleteSavingsGoals()
        deleteDebtPayoffPlans()
        deleteTransactions()
        deleteTags()
        deleteCategories()
        deleteAccounts()
        deleteProfiles()
    }
}
