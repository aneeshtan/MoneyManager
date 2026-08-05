package com.farshadghanzanfari.promoneymanager.core.domain

import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.CategoryId
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.NotificationAvailability
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleFrequency
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleId
import com.farshadghanzanfari.promoneymanager.core.model.ScheduleStatus
import com.farshadghanzanfari.promoneymanager.core.model.ScheduledTransaction
import com.farshadghanzanfari.promoneymanager.core.model.TransactionKind
import com.google.common.truth.Truth.assertThat
import java.time.LocalDate
import java.time.ZoneId
import org.junit.Test

class ScheduleCalculatorTest {
    private val aed = CurrencyCode.of("AED")

    @Test
    fun advancesNextOccurrenceForAllSupportedFrequencies() {
        val start = LocalDate.parse("2026-07-15")

        assertThat(ScheduleCalculator.nextOccurrence(start, ScheduleFrequency.WEEKLY))
            .isEqualTo(LocalDate.parse("2026-07-22"))
        assertThat(ScheduleCalculator.nextOccurrence(start, ScheduleFrequency.BIWEEKLY))
            .isEqualTo(LocalDate.parse("2026-07-29"))
        assertThat(ScheduleCalculator.nextOccurrence(start, ScheduleFrequency.MONTHLY))
            .isEqualTo(LocalDate.parse("2026-08-15"))
        assertThat(ScheduleCalculator.nextOccurrence(start, ScheduleFrequency.QUARTERLY))
            .isEqualTo(LocalDate.parse("2026-10-15"))
        assertThat(ScheduleCalculator.nextOccurrence(start, ScheduleFrequency.YEARLY))
            .isEqualTo(LocalDate.parse("2027-07-15"))
    }

    @Test
    fun createsDayBeforeReminderPlanAtNineInSelectedZone() {
        val reminder = ScheduleCalculator.reminderPlan(
            schedule = schedule(),
            zoneId = ZoneId.of("Asia/Dubai"),
            availability = NotificationAvailability.PERMISSION_GRANTED,
        )

        assertThat(reminder?.scheduledAt?.toString()).isEqualTo("2026-07-14T09:00+04:00[Asia/Dubai]")
        assertThat(reminder?.identifier).isEqualTo("scheduled-schedule-careem")
        assertThat(reminder?.availability).isEqualTo(NotificationAvailability.PERMISSION_GRANTED)
    }

    @Test
    fun pausedOrDisabledSchedulesHaveNoReminderPlan() {
        assertThat(
            ScheduleCalculator.reminderPlan(
                schedule = schedule(status = ScheduleStatus.PAUSED),
                zoneId = ZoneId.of("Asia/Dubai"),
                availability = NotificationAvailability.PERMISSION_GRANTED,
            ),
        ).isNull()
        assertThat(
            ScheduleCalculator.reminderPlan(
                schedule = schedule(reminderEnabled = false),
                zoneId = ZoneId.of("Asia/Dubai"),
                availability = NotificationAvailability.PERMISSION_GRANTED,
            ),
        ).isNull()
    }

    @Test
    fun postNowCreatesTransactionAndAdvancedSchedule() {
        val result = ScheduleCalculator.postNow(schedule(), LocalDate.parse("2026-07-11"))

        assertThat(result.transaction.merchant).isEqualTo("Careem Hala")
        assertThat(result.transaction.amount).isEqualTo(Money(5_800, aed))
        assertThat(result.transaction.source?.sourceName).isEqualTo("Scheduled transaction")
        assertThat(result.updatedSchedule.lastRunDate).isEqualTo(LocalDate.parse("2026-07-11"))
        assertThat(result.updatedSchedule.nextDate).isEqualTo(LocalDate.parse("2026-08-15"))
    }

    private fun schedule(
        status: ScheduleStatus = ScheduleStatus.ACTIVE,
        reminderEnabled: Boolean = true,
    ) = ScheduledTransaction(
        id = ScheduleId("schedule-careem"),
        accountId = AccountId("credit-card"),
        amount = Money(5_800, aed),
        kind = TransactionKind.EXPENSE,
        merchant = "Careem Hala",
        normalizedMerchant = "CAREEM HALA",
        categoryId = CategoryId("transportation"),
        note = "airport ride",
        frequency = ScheduleFrequency.MONTHLY,
        nextDate = LocalDate.parse("2026-07-15"),
        lastRunDate = null,
        status = status,
        reminderEnabled = reminderEnabled,
    )
}
