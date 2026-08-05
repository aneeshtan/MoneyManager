package com.farshadghanzanfari.promoneymanager.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.farshadghanzanfari.promoneymanager.core.database.AppDatabase
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.google.common.truth.Truth.assertThat
import kotlinx.coroutines.test.runTest
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class DefaultWorkspaceSeederTest {
    @Test
    fun createsOneProfileAndFourGenericAccountsOnlyOnce() = runTest {
        val database = Room.inMemoryDatabaseBuilder(
            ApplicationProvider.getApplicationContext(),
            AppDatabase::class.java,
        ).allowMainThreadQueries().build()
        val seeder = DefaultWorkspaceSeeder(database)

        seeder.seed(CurrencyCode.of("AED"))
        seeder.seed(CurrencyCode.of("AED"))

        assertThat(database.financeDao().countProfiles()).isEqualTo(1)
        assertThat(database.financeDao().countAccounts()).isEqualTo(4)
        assertThat(database.financeDao().countCategories()).isAtLeast(4)
        assertThat(database.financeDao().countMerchantRules()).isAtLeast(1)
        database.close()
    }
}
