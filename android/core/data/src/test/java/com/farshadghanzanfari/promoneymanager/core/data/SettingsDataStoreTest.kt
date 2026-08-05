package com.farshadghanzanfari.promoneymanager.core.data

import androidx.datastore.preferences.core.PreferenceDataStoreFactory
import com.farshadghanzanfari.promoneymanager.core.model.AppLockTimeout
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.NotificationPermissionState
import com.farshadghanzanfari.promoneymanager.core.model.NotificationSettings
import com.farshadghanzanfari.promoneymanager.core.model.PrivacySettings
import com.farshadghanzanfari.promoneymanager.core.model.RegionalSettings
import com.farshadghanzanfari.promoneymanager.core.model.SupportedLanguage
import com.google.common.truth.Truth.assertThat
import java.io.File
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.runTest
import org.junit.Test

class SettingsDataStoreTest {
    @OptIn(ExperimentalCoroutinesApi::class)
    @Test
    fun settingsSurviveADataSourceRecreationAndResetAtomically() = runTest {
        val file = File.createTempFile("pro-money-settings", ".preferences_pb").also { it.delete() }
        val scope = TestScope(UnconfinedTestDispatcher(testScheduler))
        val dataStore = PreferenceDataStoreFactory.create(scope = scope) { file }
        val first = SettingsDataStore(dataStore)
        val privacy = PrivacySettings(true, AppLockTimeout.FIFTEEN_MINUTES, true, false)
        val notifications = NotificationSettings(true, NotificationPermissionState.GRANTED)
        val region = RegionalSettings(
            language = SupportedLanguage.ARABIC,
            baseCurrency = CurrencyCode.of("EUR"),
            countryCode = "DE",
            timeZoneId = "Europe/Berlin",
        )

        first.savePrivacySettings(privacy)
        first.saveNotificationSettings(notifications)
        first.saveRegionalSettings(region)

        val recreated = SettingsDataStore(dataStore)
        assertThat(recreated.privacySettings.first()).isEqualTo(privacy)
        assertThat(recreated.notificationSettings.first()).isEqualTo(notifications)
        assertThat(recreated.regionalSettings.first()).isEqualTo(region)

        recreated.reset()

        assertThat(recreated.privacySettings.first()).isEqualTo(PrivacySettings())
        assertThat(recreated.notificationSettings.first()).isEqualTo(NotificationSettings())
        assertThat(recreated.regionalSettings.first()).isEqualTo(RegionalSettings())
    }
}
