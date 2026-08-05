package com.farshadghanzanfari.promoneymanager

import android.icu.text.DateFormat
import android.icu.text.SimpleDateFormat
import android.icu.util.TimeZone
import android.icu.util.ULocale
import com.farshadghanzanfari.promoneymanager.core.model.Money
import java.math.BigDecimal
import java.text.NumberFormat
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneOffset
import java.util.Date
import java.util.Locale

/**
 * Locale-aware value formatting for the whole app. Money honors each currency's own
 * minor-unit scale (not a hardcoded 2 decimals) and the locale's grouping/decimal
 * separators. The currency code is used as the prefix rather than a symbol lookup,
 * since symbol/spacing rules for uncommon codes (e.g. AED) are ICU-version-dependent
 * and would make output unpredictable across platforms; dates render in the Persian
 * (Jalali) calendar whenever the Persian language is active, matching iOS.
 */
object AppFormatters {
    fun money(money: Money, locale: Locale = Locale.getDefault()): String {
        val digits = runCatching { money.currency.fractionDigits }.getOrDefault(2)
        val value = BigDecimal(money.minorUnits).movePointLeft(digits)
        val format = NumberFormat.getNumberInstance(locale)
        format.minimumFractionDigits = digits
        format.maximumFractionDigits = digits
        return "${money.currency.value} ${format.format(value)}"
    }

    fun date(
        date: LocalDate,
        usePersianCalendar: Boolean,
        locale: Locale = Locale.getDefault(),
    ): String {
        val format = DateFormat.getDateInstance(DateFormat.MEDIUM, uLocale(locale, usePersianCalendar))
        return formatUtc(format, date)
    }

    fun dayWithWeekday(
        date: LocalDate,
        usePersianCalendar: Boolean,
        locale: Locale = Locale.getDefault(),
    ): String {
        val pattern = if (usePersianCalendar) "EEE d MMMM" else "EEE, MMM d"
        return formatUtc(SimpleDateFormat(pattern, uLocale(locale, usePersianCalendar)), date)
    }

    fun monthYear(
        month: YearMonth,
        usePersianCalendar: Boolean,
        locale: Locale = Locale.getDefault(),
    ): String =
        formatUtc(
            SimpleDateFormat("MMMM y", uLocale(locale, usePersianCalendar)),
            month.atDay(15),
        )

    private fun uLocale(locale: Locale, usePersianCalendar: Boolean): ULocale =
        if (usePersianCalendar) {
            ULocale("${locale.language.ifBlank { "fa" }}@calendar=persian")
        } else {
            ULocale.forLocale(locale)
        }

    private fun formatUtc(format: DateFormat, date: LocalDate): String {
        format.timeZone = TimeZone.getTimeZone("UTC")
        return format.format(utcNoon(date))
    }

    private fun utcNoon(date: LocalDate): Date =
        Date.from(date.atStartOfDay(ZoneOffset.UTC).plusHours(12).toInstant())
}
