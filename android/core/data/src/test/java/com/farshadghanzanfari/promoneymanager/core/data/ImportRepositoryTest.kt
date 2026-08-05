package com.farshadghanzanfari.promoneymanager.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.farshadghanzanfari.promoneymanager.core.database.AppDatabase
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.ImportBatchId
import com.farshadghanzanfari.promoneymanager.core.model.ImportReviewSaveCommand
import com.farshadghanzanfari.promoneymanager.core.model.MatchType
import com.farshadghanzanfari.promoneymanager.core.model.MerchantRule
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.ParsedImportTransaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.google.common.truth.Truth.assertThat
import java.time.LocalDate
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.After
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ImportRepositoryTest {
    private lateinit var database: AppDatabase
    private lateinit var repository: RoomWorkspaceRepository
    private val aed = CurrencyCode.of("AED")

    @Before
    fun setUp() {
        database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            AppDatabase::class.java,
        ).allowMainThreadQueries().build()
        repository = RoomWorkspaceRepository(database, DefaultWorkspaceSeeder(database))
    }

    @After
    fun tearDown() = database.close()

    @Test
    fun savesSelectedImportRowsWithSourceMetadata() = runTest {
        repository.createLocalWorkspace("Local User", aed)

        val result = repository.saveReviewedImport(
            ImportReviewSaveCommand(
                batchId = ImportBatchId("batch-2026-06"),
                sourceName = "statement-june.pdf",
                accountId = AccountId("credit-card"),
                rows = listOf(
                    parsedRow(
                        sourceRow = 2,
                        merchant = "CAREEM HALA RIDE",
                        categoryId = CategoryId("category-transportation"),
                    ),
                    parsedRow(
                        sourceRow = 3,
                        merchant = "5% CASHBACK",
                        kind = TransactionKind.INCOME,
                        categoryId = CategoryId("category-salary"),
                        isSelected = false,
                        isReviewOnly = true,
                    ),
                ),
            ),
        )

        val transaction = repository.observeTransactions().first().single()

        assertThat(result.savedCount).isEqualTo(1)
        assertThat(result.skippedCount).isEqualTo(1)
        assertThat(transaction.accountId).isEqualTo(AccountId("credit-card"))
        assertThat(transaction.source?.importBatchId).isEqualTo(ImportBatchId("batch-2026-06"))
        assertThat(transaction.source?.sourceName).isEqualTo("statement-june.pdf")
        assertThat(transaction.source?.sourceRow).isEqualTo(2)
        assertThat(transaction.source?.rawDescription).isEqualTo("CAREEM HALA RIDE")
    }

    @Test
    fun ignoresDuplicateAndUnselectedRows() = runTest {
        repository.createLocalWorkspace("Local User", aed)

        val result = repository.saveReviewedImport(
            ImportReviewSaveCommand(
                batchId = ImportBatchId("batch-dupes"),
                sourceName = "statement.csv",
                accountId = AccountId("credit-card"),
                rows = listOf(
                    parsedRow(merchant = "Duplicate", isDuplicate = true),
                    parsedRow(merchant = "Unselected", isSelected = false),
                ),
            ),
        )

        assertThat(result.savedCount).isEqualTo(0)
        assertThat(result.skippedCount).isEqualTo(2)
        assertThat(repository.observeTransactions().first()).isEmpty()
    }

    @Test
    fun persistsAndDisablesMerchantRules() = runTest {
        repository.createLocalWorkspace("Local User", aed)
        val rule = MerchantRule(
            id = "rule-careem",
            pattern = "CAREEM HALA",
            matchType = MatchType.CONTAINS,
            categoryId = CategoryId("category-transportation"),
            kind = TransactionKind.EXPENSE,
            confidence = 0.91,
            sampleCount = 4,
            priority = 5,
        )

        repository.saveMerchantRule(rule)
        repository.setMerchantRuleEnabled("rule-careem", false)

        val persisted = repository.observeMerchantRules().first().single { it.id == "rule-careem" }

        assertThat(persisted.pattern).isEqualTo("CAREEM HALA")
        assertThat(persisted.isEnabled).isFalse()
        assertThat(persisted.priority).isEqualTo(5)
    }

    @Test
    fun importSaveIsTransactionalWhenASelectedRowIsInvalid() = runTest {
        repository.createLocalWorkspace("Local User", aed)

        val error = runCatching {
            repository.saveReviewedImport(
                ImportReviewSaveCommand(
                    batchId = ImportBatchId("batch-invalid"),
                    sourceName = "statement.csv",
                    accountId = AccountId("credit-card"),
                    rows = listOf(
                        parsedRow(merchant = "Valid"),
                        parsedRow(merchant = "Missing date", localDate = null),
                    ),
                ),
            )
        }.exceptionOrNull()

        assertThat(error).isInstanceOf(IllegalArgumentException::class.java)
        assertThat(repository.observeTransactions().first()).isEmpty()
    }

    private fun parsedRow(
        merchant: String,
        sourceRow: Int = 1,
        localDate: LocalDate? = LocalDate.parse("2026-06-10"),
        kind: TransactionKind = TransactionKind.EXPENSE,
        categoryId: CategoryId? = CategoryId("category-food"),
        isSelected: Boolean = true,
        isDuplicate: Boolean = false,
        isReviewOnly: Boolean = false,
    ) = ParsedImportTransaction(
        localDate = localDate,
        merchant = merchant,
        normalizedMerchant = merchant.uppercase(),
        kind = kind,
        amount = Money(5_800, aed),
        suggestedCategoryId = categoryId,
        isSelected = isSelected,
        isDuplicate = isDuplicate,
        isReviewOnly = isReviewOnly,
        sourceRow = sourceRow,
    )
}
