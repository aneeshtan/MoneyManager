package com.farshadghanzanfari.promoneymanager

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class MonthlySnapshotWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { appWidgetId ->
            appWidgetManager.updateAppWidget(appWidgetId, buildRemoteViews(context))
        }
    }

    private fun buildRemoteViews(context: Context): RemoteViews {
        val openAppIntent = Intent(context, MainActivity::class.java)
        val openAppPendingIntent = PendingIntent.getActivity(
            context,
            0,
            openAppIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return RemoteViews(context.packageName, R.layout.widget_monthly_snapshot).apply {
            setTextViewText(R.id.widget_title, context.getString(R.string.widget_monthly_snapshot_title))
            setTextViewText(R.id.widget_balance, context.getString(R.string.widget_values_hidden))
            setTextViewText(R.id.widget_hint, context.getString(R.string.widget_tap_to_open))
            setOnClickPendingIntent(R.id.widget_root, openAppPendingIntent)
        }
    }
}
