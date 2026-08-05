package com.farshadghanzanfari.promoneymanager.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.farshadghanzanfari.promoneymanager.core.database.AppDatabase
import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.farshadghanzanfari.promoneymanager.core.model.AttachmentId
import com.farshadghanzanfari.promoneymanager.core.model.Category
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.Tag
import com.farshadghanzanfari.promoneymanager.core.model.TagId
import com.farshadghanzanfari.promoneymanager.core.model.Transaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionAttachment
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.google.common.truth.Truth.assertThat
import java.time.Instant
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
class RoomWorkspaceRepositoryCrudTest {
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
    fun savesAndArchivesAccountsAndCategories() = runTest {
        repository.createLocalWorkspace("Local User", aed)
        repository.saveAccount(
            Account(AccountId("travel-card"), "Travel Card", aed, Money.zero(aed), AccountType.CREDIT_CARD),
        )
        repository.saveCategory(
            Category(CategoryId("travel"), "Travel", TransactionKind.EXPENSE, sortOrder = 10),
        )

        repository.setAccountArchived(AccountId("travel-card"), true)
        repository.setCategoryArchived(CategoryId("travel"), true)

        assertThat(repository.observeAccounts().first().first { it.id == AccountId("travel-card") }.isArchived)
            .isTrue()
        assertThat(repository.observeCategories().first().first { it.id == CategoryId("travel") }.isArchived)
            .isTrue()
    }

    @Test
    fun savesTagsAndRichTransactions() = runTest {
        repository.createLocalWorkspace("Local User", aed)
        repository.saveCategory(
            Category(CategoryId("food"), "Food", TransactionKind.EXPENSE),
        )
        repository.saveTag(Tag(TagId("business"), "Business", "8151d1"))
        repository.saveTransaction(
            Transaction.posting(
                id = "txn",
                accountId = AccountId("cash"),
                amount = Money(1250, aed),
                kind = TransactionKind.EXPENSE,
                localDate = LocalDate.parse("2026-07-10"),
                merchant = "Amazon Grocery Dubai",
                normalizedMerchant = "AMAZON GROCERY",
                categoryId = CategoryId("food"),
                tagIds = listOf(TagId("business")),
                attachments = listOf(
                    TransactionAttachment(
                        id = AttachmentId("receipt"),
                        fileName = "receipt.jpg",
                        originalFileName = "IMG_1000.JPG",
                        contentType = "image/jpeg",
                        createdAt = Instant.parse("2026-07-10T10:00:00Z"),
                    ),
                ),
            ),
        )

        val transaction = repository.observeTransactions().first().single { it.id.value == "txn" }

        assertThat(repository.observeTags().first().single { it.id == TagId("business") }.colorHex)
            .isEqualTo("8151D1")
        assertThat(transaction.categoryId).isEqualTo(CategoryId("food"))
        assertThat(transaction.tagIds).containsExactly(TagId("business"))
        assertThat(transaction.attachments.single().originalFileName).isEqualTo("IMG_1000.JPG")
    }
}
