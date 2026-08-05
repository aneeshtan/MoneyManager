package com.farshadghanzanfari.promoneymanager.reminders

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.farshadghanzanfari.promoneymanager.AppFormatters
import com.farshadghanzanfari.promoneymanager.core.domain.ScheduleCalculator
import com.farshadghanzanfari.promoneymanager.core.model.NotificationAvailability
import com.farshadghanzanfari.promoneymanager.core.model.ScheduledTransaction
import dagger.hilt.android.qualifiers.ApplicationContext
import java.time.Duration
import java.time.ZoneId
import java.time.ZonedDateTime
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Keeps WorkManager in sync with the persisted scheduled transactions: one deferred
 * one-time work item per active reminder, cancelled wholesale whenever reminders are
 * disabled or the schedule list changes.
 */
@Singleton
class ReminderScheduler @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    fun sync(
        schedules: List<ScheduledTransaction>,
        remindersAllowed: Boolean,
        zoneId: ZoneId,
    ) {
        val workManager = WorkManager.getInstance(context)
        workManager.cancelAllWorkByTag(REMINDER_TAG)
        if (!remindersAllowed) return

        val now = ZonedDateTime.now(zoneId)
        schedules.forEach { schedule ->
            val plan = ScheduleCalculator.reminderPlan(
                schedule = schedule,
                zoneId = zoneId,
                availability = NotificationAvailability.PERMISSION_GRANTED,
            ) ?: return@forEach
            val delay = Duration.between(now, plan.scheduledAt)
            if (delay.isNegative) return@forEach

            val request = OneTimeWorkRequestBuilder<ReminderNotificationWorker>()
                .setInitialDelay(delay)
                .addTag(REMINDER_TAG)
                .setInputData(
                    workDataOf(
                        ReminderNotificationWorker.KEY_SCHEDULE_ID to schedule.id.value,
                        ReminderNotificationWorker.KEY_MERCHANT to schedule.merchant,
                        ReminderNotificationWorker.KEY_AMOUNT_TEXT to AppFormatters.money(schedule.amount),
                    ),
                )
                .build()
            workManager.enqueueUniqueWork(
                "reminder-${schedule.id.value}",
                ExistingWorkPolicy.REPLACE,
                request,
            )
        }
    }

    private companion object {
        const val REMINDER_TAG = "scheduled-transaction-reminder"
    }
}
