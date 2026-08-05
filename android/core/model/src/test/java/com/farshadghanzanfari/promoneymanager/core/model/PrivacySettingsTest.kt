package com.farshadghanzanfari.promoneymanager.core.model

import com.google.common.truth.Truth.assertThat
import org.junit.Assert.assertThrows
import org.junit.Test

class PrivacySettingsTest {
    @Test
    fun appLockDefaultsToLocalOnlySecureScreenWithoutTelemetry() {
        val settings = PrivacySettings()

        assertThat(settings.appLockEnabled).isFalse()
        assertThat(settings.lockTimeout).isEqualTo(AppLockTimeout.IMMEDIATE)
        assertThat(settings.secureScreenEnabled).isTrue()
        assertThat(settings.redactSensitiveContent).isTrue()
        assertThat(PrivacySupportInfo.NO_TELEMETRY_NOTICE.lowercase()).contains("no analytics")
    }

    @Test
    fun appLockTimeoutsExposeAndroidRelockPolicies() {
        assertThat(AppLockTimeout.entries.map { it.minutesUntilLock })
            .containsExactly(0, 1, 5, 15)
            .inOrder()
    }

    @Test
    fun notificationSettingsDoNotPretendPermissionWasRequested() {
        val settings = NotificationSettings()

        assertThat(settings.remindersEnabled).isFalse()
        assertThat(settings.permissionState).isEqualTo(NotificationPermissionState.NOT_REQUESTED)
        assertThat(settings.canScheduleReminder).isFalse()
    }

    @Test
    fun regionalSettingsCoverApprovedLanguagesAndRtl() {
        assertThat(SupportedLanguage.entries.map { it.languageTag })
            .containsExactly("en", "es", "ar", "hi", "fa", "de", "fr", "pt")
            .inOrder()
        assertThat(SupportedLanguage.ARABIC.isRtl).isTrue()
        assertThat(SupportedLanguage.PERSIAN.isRtl).isTrue()
        assertThat(RegionalSettings(language = SupportedLanguage.PERSIAN).usesPersianCalendar).isTrue()
    }

    @Test
    fun regionalSettingsPreserveValidatedBaseCurrency() {
        val settings = RegionalSettings(
            language = SupportedLanguage.GERMAN,
            baseCurrency = CurrencyCode.of("EUR"),
            countryCode = "DE",
            timeZoneId = "Europe/Berlin",
        )

        assertThat(settings.baseCurrency.value).isEqualTo("EUR")
    }

    @Test
    fun regionalSettingsRequireValidTimezone() {
        val failure = assertThrows(IllegalArgumentException::class.java) {
            RegionalSettings(timeZoneId = "")
        }

        assertThat(failure).hasMessageThat().contains("time zone")
    }
}
