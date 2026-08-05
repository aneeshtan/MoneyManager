package com.farshadghanzanfari.promoneymanager.core.data

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.emptyPreferences
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.farshadghanzanfari.promoneymanager.core.model.AppLockTimeout
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.NotificationPermissionState
import com.farshadghanzanfari.promoneymanager.core.model.NotificationSettings
import com.farshadghanzanfari.promoneymanager.core.model.PrivacySettings
import com.farshadghanzanfari.promoneymanager.core.model.RegionalSettings
import com.farshadghanzanfari.promoneymanager.core.model.SupportedLanguage
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.catch
import kotlinx.coroutines.flow.map

private val Context.proMoneySettings by preferencesDataStore(name = "pro_money_settings")

interface SettingsStore {
    val privacySettings: Flow<PrivacySettings>
    val notificationSettings: Flow<NotificationSettings>
    val regionalSettings: Flow<RegionalSettings>

    suspend fun savePrivacySettings(settings: PrivacySettings)
    suspend fun saveNotificationSettings(settings: NotificationSettings)
    suspend fun saveRegionalSettings(settings: RegionalSettings)
    suspend fun reset()
}

@Singleton
class SettingsDataStore internal constructor(
    private val dataStore: DataStore<Preferences>,
) : SettingsStore {
    @Inject
    constructor(@ApplicationContext context: Context) : this(context.proMoneySettings)

    override val privacySettings: Flow<PrivacySettings> = safeData.map { preferences ->
        PrivacySettings(
            appLockEnabled = preferences[Keys.APP_LOCK_ENABLED] ?: false,
            lockTimeout = enumValueOrDefault(
                preferences[Keys.APP_LOCK_TIMEOUT],
                AppLockTimeout.IMMEDIATE,
            ),
            secureScreenEnabled = preferences[Keys.SECURE_SCREEN_ENABLED] ?: true,
            redactSensitiveContent = preferences[Keys.REDACT_SENSITIVE_CONTENT] ?: true,
        )
    }

    override val notificationSettings: Flow<NotificationSettings> = safeData.map { preferences ->
        NotificationSettings(
            remindersEnabled = preferences[Keys.REMINDERS_ENABLED] ?: false,
            permissionState = enumValueOrDefault(
                preferences[Keys.NOTIFICATION_PERMISSION_STATE],
                NotificationPermissionState.NOT_REQUESTED,
            ),
        )
    }

    override val regionalSettings: Flow<RegionalSettings> = safeData.map { preferences ->
        RegionalSettings(
            language = enumValueOrDefault(preferences[Keys.LANGUAGE], SupportedLanguage.ENGLISH),
            countryCode = preferences[Keys.COUNTRY_CODE] ?: "AE",
            timeZoneId = preferences[Keys.TIME_ZONE_ID] ?: "Asia/Dubai",
            baseCurrency = currencyOrDefault(preferences[Keys.BASE_CURRENCY]),
        )
    }

    override suspend fun savePrivacySettings(settings: PrivacySettings) {
        dataStore.edit { preferences ->
            preferences[Keys.APP_LOCK_ENABLED] = settings.appLockEnabled
            preferences[Keys.APP_LOCK_TIMEOUT] = settings.lockTimeout.name
            preferences[Keys.SECURE_SCREEN_ENABLED] = settings.secureScreenEnabled
            preferences[Keys.REDACT_SENSITIVE_CONTENT] = settings.redactSensitiveContent
        }
    }

    override suspend fun saveNotificationSettings(settings: NotificationSettings) {
        dataStore.edit { preferences ->
            preferences[Keys.REMINDERS_ENABLED] = settings.remindersEnabled
            preferences[Keys.NOTIFICATION_PERMISSION_STATE] = settings.permissionState.name
        }
    }

    override suspend fun saveRegionalSettings(settings: RegionalSettings) {
        dataStore.edit { preferences ->
            preferences[Keys.LANGUAGE] = settings.language.name
            preferences[Keys.COUNTRY_CODE] = settings.countryCode
            preferences[Keys.TIME_ZONE_ID] = settings.timeZoneId
            preferences[Keys.BASE_CURRENCY] = settings.baseCurrency.value
        }
    }

    override suspend fun reset() {
        dataStore.edit { it.clear() }
    }

    private val safeData: Flow<Preferences>
        get() = dataStore.data.catch { error ->
            if (error is IOException) emit(emptyPreferences()) else throw error
        }

    private inline fun <reified T : Enum<T>> enumValueOrDefault(value: String?, default: T): T =
        enumValues<T>().firstOrNull { it.name == value } ?: default

    private fun currencyOrDefault(value: String?): CurrencyCode =
        runCatching { CurrencyCode.of(value ?: "AED") }.getOrDefault(CurrencyCode.of("AED"))

    private object Keys {
        val APP_LOCK_ENABLED = booleanPreferencesKey("app_lock_enabled")
        val APP_LOCK_TIMEOUT = stringPreferencesKey("app_lock_timeout")
        val SECURE_SCREEN_ENABLED = booleanPreferencesKey("secure_screen_enabled")
        val REDACT_SENSITIVE_CONTENT = booleanPreferencesKey("redact_sensitive_content")
        val REMINDERS_ENABLED = booleanPreferencesKey("reminders_enabled")
        val NOTIFICATION_PERMISSION_STATE = stringPreferencesKey("notification_permission_state")
        val LANGUAGE = stringPreferencesKey("language")
        val COUNTRY_CODE = stringPreferencesKey("country_code")
        val TIME_ZONE_ID = stringPreferencesKey("time_zone_id")
        val BASE_CURRENCY = stringPreferencesKey("base_currency")
    }
}

internal class MemorySettingsStore : SettingsStore {
    private val privacy = MutableStateFlow(PrivacySettings())
    private val notifications = MutableStateFlow(NotificationSettings())
    private val regional = MutableStateFlow(RegionalSettings())

    override val privacySettings: Flow<PrivacySettings> = privacy
    override val notificationSettings: Flow<NotificationSettings> = notifications
    override val regionalSettings: Flow<RegionalSettings> = regional

    override suspend fun savePrivacySettings(settings: PrivacySettings) { privacy.value = settings }
    override suspend fun saveNotificationSettings(settings: NotificationSettings) { notifications.value = settings }
    override suspend fun saveRegionalSettings(settings: RegionalSettings) { regional.value = settings }
    override suspend fun reset() {
        privacy.value = PrivacySettings()
        notifications.value = NotificationSettings()
        regional.value = RegionalSettings()
    }
}
