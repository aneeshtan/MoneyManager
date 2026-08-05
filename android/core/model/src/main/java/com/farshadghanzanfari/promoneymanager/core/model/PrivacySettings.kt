package com.farshadghanzanfari.promoneymanager.core.model

enum class AppLockTimeout(val minutesUntilLock: Int) {
    IMMEDIATE(0),
    ONE_MINUTE(1),
    FIVE_MINUTES(5),
    FIFTEEN_MINUTES(15),
}

data class PrivacySettings(
    val appLockEnabled: Boolean = false,
    val lockTimeout: AppLockTimeout = AppLockTimeout.IMMEDIATE,
    val secureScreenEnabled: Boolean = true,
    val redactSensitiveContent: Boolean = true,
)

enum class NotificationPermissionState {
    NOT_REQUIRED,
    NOT_REQUESTED,
    GRANTED,
    DENIED,
    DISABLED_IN_SETTINGS,
}

data class NotificationSettings(
    val remindersEnabled: Boolean = false,
    val permissionState: NotificationPermissionState = NotificationPermissionState.NOT_REQUESTED,
) {
    val canScheduleReminder: Boolean
        get() = remindersEnabled && permissionState in setOf(
            NotificationPermissionState.NOT_REQUIRED,
            NotificationPermissionState.GRANTED,
        )
}

enum class SupportedLanguage(
    val languageTag: String,
    val displayName: String,
    val suggestedRegion: String,
    val suggestedTimeZone: String,
    val suggestedCurrency: String,
    val isRtl: Boolean = false,
) {
    ENGLISH("en", "English", "US", "America/New_York", "USD"),
    SPANISH("es", "Español", "ES", "Europe/Madrid", "EUR"),
    ARABIC("ar", "العربية", "AE", "Asia/Dubai", "AED", isRtl = true),
    HINDI("hi", "हिन्दी", "IN", "Asia/Kolkata", "INR"),
    PERSIAN("fa", "فارسی", "IR", "Asia/Tehran", "IRR", isRtl = true),
    GERMAN("de", "Deutsch", "DE", "Europe/Berlin", "EUR"),
    FRENCH("fr", "Français", "FR", "Europe/Paris", "EUR"),
    PORTUGUESE("pt", "Português", "BR", "America/Sao_Paulo", "BRL"),
}

data class RegionalSettings(
    val language: SupportedLanguage = SupportedLanguage.ENGLISH,
    val countryCode: String = "AE",
    val timeZoneId: String = "Asia/Dubai",
    val baseCurrency: CurrencyCode = CurrencyCode.of("AED"),
) {
    val usesPersianCalendar: Boolean
        get() = language == SupportedLanguage.PERSIAN

    init {
        require(countryCode.isNotBlank()) { "Regional country must not be blank." }
        require(timeZoneId.isNotBlank()) { "Regional time zone must not be blank." }
    }
}

object PrivacySupportInfo {
    const val NO_TELEMETRY_NOTICE: String =
        "Finance data stays on this device. No analytics, ads, or telemetry are collected."
}
