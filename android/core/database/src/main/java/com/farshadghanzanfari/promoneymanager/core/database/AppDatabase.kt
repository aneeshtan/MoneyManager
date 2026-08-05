package com.farshadghanzanfari.promoneymanager.core.database

import androidx.room.AutoMigration
import androidx.room.Database
import androidx.room.RoomDatabase

@Database(
    entities = [
        ProfileEntity::class,
        AccountEntity::class,
        CategoryEntity::class,
        TagEntity::class,
        TransactionEntity::class,
        TransactionTagCrossRef::class,
        TransactionAttachmentEntity::class,
        MerchantRuleEntity::class,
        BudgetEntity::class,
        ScheduledTransactionEntity::class,
        SavingsGoalEntity::class,
        SavingsGoalContributionEntity::class,
        DebtPayoffPlanEntity::class,
    ],
    version = 4,
    exportSchema = true,
    autoMigrations = [
        AutoMigration(from = 2, to = 3),
        AutoMigration(from = 3, to = 4),
    ],
)
abstract class AppDatabase : RoomDatabase() {
    abstract fun financeDao(): FinanceDao

    suspend fun clearWorkspace() = financeDao().clearWorkspace()
}
