package com.farshadghanzanfari.promoneymanager

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.drawable.Icon

object AndroidShortcutPublisher {
    fun publish(context: Context) {
        context.getSystemService(ShortcutManager::class.java).dynamicShortcuts = shortcuts(context)
    }

    private fun shortcuts(context: Context): List<ShortcutInfo> = listOf(
        shortcut(
            context = context,
            id = "dynamic_add_expense",
            destination = "add_expense",
            shortLabel = R.string.shortcut_add_expense_short,
            longLabel = R.string.shortcut_add_expense_long,
        ),
        shortcut(
            context = context,
            id = "dynamic_import_statement",
            destination = "import_statement",
            shortLabel = R.string.shortcut_import_statement_short,
            longLabel = R.string.shortcut_import_statement_long,
        ),
        shortcut(
            context = context,
            id = "dynamic_search",
            destination = "search",
            shortLabel = R.string.shortcut_search_short,
            longLabel = R.string.shortcut_search_long,
        ),
        shortcut(
            context = context,
            id = "dynamic_upcoming_bills",
            destination = "upcoming_bills",
            shortLabel = R.string.shortcut_upcoming_bills_short,
            longLabel = R.string.shortcut_upcoming_bills_long,
        ),
    )

    private fun shortcut(
        context: Context,
        id: String,
        destination: String,
        shortLabel: Int,
        longLabel: Int,
    ): ShortcutInfo =
        ShortcutInfo.Builder(context, id)
            .setShortLabel(context.getString(shortLabel))
            .setLongLabel(context.getString(longLabel))
            .setIcon(Icon.createWithResource(context, R.drawable.ic_stat_promoney))
            .setIntent(
                Intent(context, MainActivity::class.java)
                    .setAction(Intent.ACTION_VIEW)
                    .putExtra("shortcut_destination", destination),
            )
            .build()
}
