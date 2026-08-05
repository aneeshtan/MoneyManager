package com.farshadghanzanfari.promoneymanager.core.model

import java.time.Instant

enum class BackupRecordType {
    ACCOUNTS,
    CATEGORIES,
    TAGS,
    TRANSACTIONS,
    MERCHANT_RULES,
    BUDGETS,
    SCHEDULED_TRANSACTIONS,
    SAVINGS_GOALS,
    SAVINGS_GOAL_CONTRIBUTIONS,
    DEBT_PAYOFF_PLANS,
}

data class BackupManifest(
    val schemaVersion: Int,
    val createdAt: Instant,
    val recordCounts: Map<BackupRecordType, Int>,
    val packageName: String = PACKAGE_NAME,
) {
    init {
        require(schemaVersion in 1..CURRENT_SCHEMA_VERSION) {
            "Backup version $schemaVersion is not supported."
        }
        require(recordCounts.values.all { it >= 0 }) {
            "Backup record counts must not be negative."
        }
    }

    companion object {
        const val CURRENT_SCHEMA_VERSION = 1
        const val PACKAGE_NAME = "ProMoneyManager"
    }
}

data class CompleteBackupSnapshot(
    val manifest: BackupManifest,
    val accounts: List<Account>,
    val categories: List<Category>,
    val tags: List<Tag>,
    val transactions: List<Transaction>,
    val merchantRules: List<MerchantRule>,
    val budgets: List<Budget>,
    val scheduledTransactions: List<ScheduledTransaction>,
    val savingsGoals: List<SavingsGoal>,
    val savingsGoalContributions: List<SavingsGoalContribution>,
    val debtPayoffPlans: List<DebtPayoffPlan>,
)

data class LegacyExportCompatibilityReport(
    val canExportWithoutLoss: Boolean,
    val includedCounts: Map<BackupRecordType, Int>,
    val excludedCounts: Map<BackupRecordType, Int>,
    val warnings: List<String>,
)

data class RestorePreview(
    val canRestore: Boolean,
    val schemaVersion: Int,
    val recordCounts: Map<BackupRecordType, Int>,
    val warnings: List<String> = emptyList(),
)
