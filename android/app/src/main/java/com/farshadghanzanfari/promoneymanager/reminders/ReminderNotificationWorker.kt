package com.farshadghanzanfari.promoneymanager.reminders

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import androidx.work.Worker
import androidx.work.WorkerParameters
import com.farshadghanzanfari.promoneymanager.ScheduledReminderNotificationFactory

/**
 * Posts one scheduled-transaction reminder notification. All content arrives in the
 * input data at enqueue time, so the worker needs no database or network access.
 */
class ReminderNotificationWorker(
    context: Context,
    parameters: WorkerParameters,
) : Worker(context, parameters) {
    override fun doWork(): Result {
        val scheduleId = inputData.getString(KEY_SCHEDULE_ID) ?: return Result.failure()
        val merchant = inputData.getString(KEY_MERCHANT) ?: return Result.failure()
        val amountText = inputData.getString(KEY_AMOUNT_TEXT) ?: ""
        if (!canPostNotifications()) return Result.success()

        val notification = ScheduledReminderNotificationFactory.create(
            context = applicationContext,
            scheduleId = scheduleId,
            merchant = merchant,
            amount = amountText,
        )
        applicationContext.getSystemService(NotificationManager::class.java)
            .notify(scheduleId.hashCode(), notification)
        return Result.success()
    }

    private fun canPostNotifications(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            applicationContext,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    companion object {
        const val KEY_SCHEDULE_ID = "schedule_id"
        const val KEY_MERCHANT = "merchant"
        const val KEY_AMOUNT_TEXT = "amount_text"
    }
}
