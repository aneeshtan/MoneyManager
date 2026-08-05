package com.farshadghanzanfari.promoneymanager

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class ScheduledNotificationActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val scheduleId = intent.getStringExtra(EXTRA_SCHEDULE_ID) ?: return
        val actionId = when (intent.action) {
            ACTION_POST -> "post"
            ACTION_SKIP -> "skip"
            ACTION_OPEN -> "open"
            else -> return
        }
        persistLastAction(context, scheduleId, actionId)
        if (intent.action == ACTION_OPEN) {
            context.startActivity(
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    .putExtra("shortcut_destination", "upcoming_bills"),
            )
        }
    }

    companion object {
        const val ACTION_POST = "com.farshadghanzanfari.promoneymanager.notification.POST"
        const val ACTION_SKIP = "com.farshadghanzanfari.promoneymanager.notification.SKIP"
        const val ACTION_OPEN = "com.farshadghanzanfari.promoneymanager.notification.OPEN"
        const val EXTRA_SCHEDULE_ID = "schedule_id"

        fun lastAction(context: Context, scheduleId: String): String? =
            context
                .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .getString(scheduleId, null)

        private fun persistLastAction(context: Context, scheduleId: String, actionId: String) {
            context
                .getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(scheduleId, actionId)
                .apply()
        }

        private const val PREFERENCES_NAME = "scheduled_notification_actions"
    }
}
