package com.farshadghanzanfari.promoneymanager.core.data

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import com.farshadghanzanfari.promoneymanager.core.database.AppDatabase
import com.farshadghanzanfari.promoneymanager.core.domain.WorkspaceRepository
import com.farshadghanzanfari.promoneymanager.core.model.AppLockTimeout
import com.farshadghanzanfari.promoneymanager.core.model.NotificationPermissionState
import com.farshadghanzanfari.promoneymanager.core.model.NotificationSettings
import com.farshadghanzanfari.promoneymanager.core.model.PrivacySettings
import com.farshadghanzanfari.promoneymanager.core.model.RegionalSettings
import com.farshadghanzanfari.promoneymanager.core.model.SupportedLanguage
import com.google.common.truth.Truth.assertThat
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
class SettingsRepositoryTest {
    private lateinit var database: AppDatabase
    private lateinit var repository: WorkspaceRepository

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
    fun savesSettingsAndResetsThemOnWorkspaceDeletion() = runTest {
        repository.savePrivacySettings(
            PrivacySettings(
                appLockEnabled = true,
                lockTimeout = AppLockTimeout.FIVE_MINUTES,
                secureScreenEnabled = true,
                redactSensitiveContent = true,
            ),
        )
        repository.saveNotificationSettings(
            NotificationSettings(
                remindersEnabled = true,
                permissionState = NotificationPermissionState.GRANTED,
            ),
        )
        repository.saveRegionalSettings(
            RegionalSettings(
                language = SupportedLanguage.PERSIAN,
                countryCode = "IR",
                timeZoneId = "Asia/Tehran",
            ),
        )

        assertThat(repository.observePrivacySettings().first().lockTimeout)
            .isEqualTo(AppLockTimeout.FIVE_MINUTES)
        assertThat(repository.observeNotificationSettings().first().canScheduleReminder).isTrue()
        assertThat(repository.observeRegionalSettings().first().usesPersianCalendar).isTrue()

        repository.clearWorkspace()

        assertThat(repository.observePrivacySettings().first()).isEqualTo(PrivacySettings())
        assertThat(repository.observeNotificationSettings().first()).isEqualTo(NotificationSettings())
        assertThat(repository.observeRegionalSettings().first()).isEqualTo(RegionalSettings())
    }
}
