package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.BackupManifest
import com.farshadghanzanfari.promoneymanager.core.model.BackupRecordType
import com.farshadghanzanfari.promoneymanager.core.model.Budget
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CompleteBackupSnapshot
import com.farshadghanzanfari.promoneymanager.core.model.DebtPayoffPlan
import com.farshadghanzanfari.promoneymanager.core.model.LegacyExportCompatibilityReport
import com.farshadghanzanfari.promoneymanager.core.model.MerchantRule
import com.farshadghanzanfari.promoneymanager.core.model.RestorePreview
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoal
import com.farshadghanzanfari.promoneymanager.core.model.SavingsGoalContribution
import com.farshadghanzanfari.promoneymanager.core.model.ScheduledTransaction
import com.farshadghanzanfari.promoneymanager.core.model.Tag
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import java.time.Instant

object BackupEngine {
    fun completeSnapshot(
        createdAt: Instant,
        accounts: List<Account>,
        categories: List<Category>,
        tags: List<Tag>,
        transactions: List<Transaction>,
        merchantRules: List<MerchantRule>,
        budgets: List<Budget>,
        scheduledTransactions: List<ScheduledTransaction>,
        savingsGoals: List<SavingsGoal>,
        savingsGoalContributions: List<SavingsGoalContribution>,
        debtPayoffPlans: List<DebtPayoffPlan>,
    ): CompleteBackupSnapshot {
        val recordCounts = mapOf(
            BackupRecordType.ACCOUNTS to accounts.size,
            BackupRecordType.CATEGORIES to categories.size,
            BackupRecordType.TAGS to tags.size,
            BackupRecordType.TRANSACTIONS to transactions.size,
            BackupRecordType.MERCHANT_RULES to merchantRules.size,
            BackupRecordType.BUDGETS to budgets.size,
            BackupRecordType.SCHEDULED_TRANSACTIONS to scheduledTransactions.size,
            BackupRecordType.SAVINGS_GOALS to savingsGoals.size,
            BackupRecordType.SAVINGS_GOAL_CONTRIBUTIONS to savingsGoalContributions.size,
            BackupRecordType.DEBT_PAYOFF_PLANS to debtPayoffPlans.size,
        )

        return CompleteBackupSnapshot(
            manifest = BackupManifest(
                schemaVersion = BackupManifest.CURRENT_SCHEMA_VERSION,
                createdAt = createdAt,
                recordCounts = recordCounts,
            ),
            accounts = accounts,
            categories = categories,
            tags = tags,
            transactions = transactions,
            merchantRules = merchantRules,
            budgets = budgets,
            scheduledTransactions = scheduledTransactions,
            savingsGoals = savingsGoals,
            savingsGoalContributions = savingsGoalContributions,
            debtPayoffPlans = debtPayoffPlans,
        )
    }

    fun legacyIosCompatibilityReport(
        snapshot: CompleteBackupSnapshot,
    ): LegacyExportCompatibilityReport {
        val includedCounts = mapOf(
            BackupRecordType.ACCOUNTS to snapshot.accounts.size,
            BackupRecordType.CATEGORIES to snapshot.categories.size,
            BackupRecordType.TRANSACTIONS to snapshot.transactions.size,
            BackupRecordType.MERCHANT_RULES to snapshot.merchantRules.size,
        ).filterValues { it > 0 }
        val excludedCounts = mapOf(
            BackupRecordType.TAGS to snapshot.tags.size,
            BackupRecordType.BUDGETS to snapshot.budgets.size,
            BackupRecordType.SCHEDULED_TRANSACTIONS to snapshot.scheduledTransactions.size,
            BackupRecordType.SAVINGS_GOALS to snapshot.savingsGoals.size,
            BackupRecordType.SAVINGS_GOAL_CONTRIBUTIONS to snapshot.savingsGoalContributions.size,
            BackupRecordType.DEBT_PAYOFF_PLANS to snapshot.debtPayoffPlans.size,
        ).filterValues { it > 0 }
        val warnings = if (excludedCounts.isEmpty()) {
            emptyList()
        } else {
            listOf(
                "Legacy iOS JSON cannot represent every Android record. Use complete .pmmbackup for a lossless export.",
            )
        }

        return LegacyExportCompatibilityReport(
            canExportWithoutLoss = excludedCounts.isEmpty(),
            includedCounts = includedCounts,
            excludedCounts = excludedCounts,
            warnings = warnings,
        )
    }

    fun restorePreview(
        schemaVersion: Int,
        recordCounts: Map<BackupRecordType, Int>,
    ): RestorePreview =
        if (schemaVersion > BackupManifest.CURRENT_SCHEMA_VERSION) {
            RestorePreview(
                canRestore = false,
                schemaVersion = schemaVersion,
                recordCounts = recordCounts,
                warnings = listOf("Backup version $schemaVersion is newer than this app supports."),
            )
        } else {
            RestorePreview(
                canRestore = true,
                schemaVersion = schemaVersion,
                recordCounts = recordCounts,
            )
        }
}
