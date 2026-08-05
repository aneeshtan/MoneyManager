package com.farshadghanzanfari.promoneymanager

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

object ScheduledReminderNotificationFactory {
    private const val CHANNEL_ID = "scheduled_reminders"
    private const val CHANNEL_NAME = "Scheduled reminders"

    fun create(
        context: Context,
        scheduleId: String,
        merchant: String,
        amount: String,
    ): Notification {
        ensureChannel(context)
        return Notification.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_promoney)
            .setContentTitle(context.getString(R.string.notification_scheduled_title, merchant))
            .setContentText(amount)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(actionPendingIntent(context, scheduleId, ScheduledNotificationActionReceiver.ACTION_OPEN))
            .addAction(action(context, scheduleId, ScheduledNotificationActionReceiver.ACTION_POST, R.string.notification_action_post))
            .addAction(action(context, scheduleId, ScheduledNotificationActionReceiver.ACTION_SKIP, R.string.notification_action_skip))
            .addAction(action(context, scheduleId, ScheduledNotificationActionReceiver.ACTION_OPEN, R.string.notification_action_open))
            .build()
    }

    private fun action(
        context: Context,
        scheduleId: String,
        action: String,
        titleRes: Int,
    ): Notification.Action =
        Notification.Action.Builder(
            R.drawable.ic_stat_promoney,
            context.getString(titleRes),
            actionPendingIntent(context, scheduleId, action),
        ).build()

    private fun actionPendingIntent(context: Context, scheduleId: String, action: String): PendingIntent {
        val requestCode = "$scheduleId:$action".hashCode()
        val intent = Intent(context, ScheduledNotificationActionReceiver::class.java)
            .setAction(action)
            .putExtra(ScheduledNotificationActionReceiver.EXTRA_SCHEDULE_ID, scheduleId)
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val notificationManager = context.getSystemService(NotificationManager::class.java)
        if (notificationManager.getNotificationChannel(CHANNEL_ID) != null) return
        notificationManager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_DEFAULT,
            ),
        )
    }
}
