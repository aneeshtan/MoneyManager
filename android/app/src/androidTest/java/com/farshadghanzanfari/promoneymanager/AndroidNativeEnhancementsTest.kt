package com.farshadghanzanfari.promoneymanager

import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.content.pm.ShortcutManager
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.farshadghanzanfari.promoneymanager.core.designsystem.ProMoneyManagerTheme
import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import org.xmlpull.v1.XmlPullParser

@RunWith(AndroidJUnit4::class)
class AndroidNativeEnhancementsTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun sharedStatementTextOpensImportReviewDraft() {
        val aed = CurrencyCode.of("AED")
        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = AppUiState(
                        hasWorkspace = true,
                        accounts = listOf(
                            Account(
                                id = AccountId("credit-card"),
                                name = "Credit Card",
                                currency = aed,
                                openingBalance = Money.zero(aed),
                                type = AccountType.CREDIT_CARD,
                            ),
                        ),
                        importText = "AED 42.00 CAREEM shared from Gmail",
                        importStatus = "Shared from Android share target. Review before saving.",
                    ),
                    onContinueOnDevice = {},
                )
            }
        }

        composeRule.onNodeWithText("Paste statement text").assertIsDisplayed()
        composeRule.onNodeWithText("AED 42.00 CAREEM shared from Gmail").assertIsDisplayed()
        composeRule.onNodeWithText("Shared from Android share target. Review before saving.").assertIsDisplayed()
        composeRule.onNodeWithText("Parse import").assertIsDisplayed()
    }

    @Test
    fun androidEnhancementPanelShowsNativeFeatureGates() {
        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = AppUiState(hasWorkspace = true),
                    onContinueOnDevice = {},
                )
            }
        }

        composeRule.onNodeWithText("More").performClick()
        composeRule.onNodeWithText("Android").performScrollTo().performClick()

        composeRule.onNodeWithText("Share target imports").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Add expense shortcut").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Import statement shortcut").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Widget values hidden while privacy lock is active").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Notification actions: Post, Skip, Open").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Receipt OCR drafts require review").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("SMS import disabled until Play policy approval").performScrollTo().assertIsDisplayed()
    }

    @Test
    fun mainActivityPublishesExpectedStaticShortcuts() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val activityInfo = context.packageManager.getActivityInfo(
            ComponentName(context, MainActivity::class.java),
            PackageManager.GET_META_DATA,
        )
        val shortcutResource = activityInfo.metaData.getInt("android.app.shortcuts")

        val shortcutIds = mutableListOf<String>()
        val parser = context.resources.getXml(shortcutResource)
        while (parser.next() != XmlPullParser.END_DOCUMENT) {
            if (parser.eventType == XmlPullParser.START_TAG && parser.name == "shortcut") {
                shortcutIds += parser.getAttributeValue(ANDROID_NS, "shortcutId")
            }
        }

        assertEquals(
            listOf("add_expense", "import_statement", "search", "upcoming_bills"),
            shortcutIds,
        )
    }

    @Test
    fun dynamicShortcutsPublishExpectedDestinations() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()

        AndroidShortcutPublisher.publish(context)

        val shortcutManager = context.getSystemService(ShortcutManager::class.java)
        assertEquals(
            listOf("dynamic_add_expense", "dynamic_import_statement", "dynamic_search", "dynamic_upcoming_bills"),
            shortcutManager.dynamicShortcuts.map { it.id }.sorted(),
        )
    }

    @Test
    fun addExpenseShortcutOpensTransactions() {
        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = AppUiState(hasWorkspace = true),
                    shortcutDestination = "add_expense",
                    onContinueOnDevice = {},
                )
            }
        }

        composeRule.onNodeWithText("Add your first transaction").assertIsDisplayed()
    }

    @Test
    fun importStatementShortcutOpensImport() {
        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = AppUiState(hasWorkspace = true),
                    shortcutDestination = "import_statement",
                    onContinueOnDevice = {},
                )
            }
        }

        composeRule.onNodeWithText("Paste statement text").assertIsDisplayed()
    }

    @Test
    fun searchShortcutOpensSearchTools() {
        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = AppUiState(hasWorkspace = true),
                    shortcutDestination = "search",
                    onContinueOnDevice = {},
                )
            }
        }

        composeRule.onNodeWithText("Search tools").assertIsDisplayed()
    }

    @Test
    fun upcomingBillsShortcutOpensSchedule() {
        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = AppUiState(hasWorkspace = true),
                    shortcutDestination = "upcoming_bills",
                    onContinueOnDevice = {},
                )
            }
        }

        composeRule.onNodeWithText("Add schedule").assertIsDisplayed()
    }

    @Test
    fun monthlySnapshotWidgetProviderIsPublished() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val receiverInfo = context.packageManager.getReceiverInfo(
            ComponentName(context.packageName, "${context.packageName}.MonthlySnapshotWidgetProvider"),
            PackageManager.GET_META_DATA,
        )
        val widgetProviderResource = receiverInfo.metaData.getInt("android.appwidget.provider")

        assertEquals("monthly_snapshot_widget", context.resources.getResourceEntryName(widgetProviderResource))

        var initialLayoutResource = 0
        val parser = context.resources.getXml(widgetProviderResource)
        while (parser.next() != XmlPullParser.END_DOCUMENT) {
            if (parser.eventType == XmlPullParser.START_TAG && parser.name == "appwidget-provider") {
                initialLayoutResource = parser.getAttributeResourceValue(ANDROID_NS, "initialLayout", 0)
            }
        }

        assertEquals("widget_monthly_snapshot", context.resources.getResourceEntryName(initialLayoutResource))
    }

    @Test
    fun scheduledNotificationActionReceiverIsPrivate() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val receiverInfo = context.packageManager.getReceiverInfo(
            ComponentName(context.packageName, "${context.packageName}.ScheduledNotificationActionReceiver"),
            0,
        )

        assertEquals(false, receiverInfo.exported)
    }

    @Test
    fun scheduledNotificationPublishesPostSkipOpenActions() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val notification = ScheduledReminderNotificationFactory.create(
            context = context,
            scheduleId = "rent",
            merchant = "Rent",
            amount = "AED 5,000.00",
        )

        assertEquals(listOf("Post", "Skip", "Open"), notification.actions.map { it.title.toString() })
    }

    @Test
    fun shareTargetAcceptsReceiptImages() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        val matches = context.packageManager.queryIntentActivities(
            Intent(Intent.ACTION_SEND)
                .setType("image/jpeg")
                .setPackage(context.packageName),
            PackageManager.MATCH_DEFAULT_ONLY,
        )

        assertEquals(
            listOf(ComponentName(context, MainActivity::class.java)),
            matches.map { ComponentName(it.activityInfo.packageName, it.activityInfo.name) },
        )
    }

    @Test
    fun receiptImageShareCreatesReviewOnlyOcrDraft() {
        val intent = Intent(Intent.ACTION_SEND)
            .setType("image/jpeg")
            .putExtra(Intent.EXTRA_STREAM, Uri.parse("content://receipts/july-rent.jpg"))

        assertEquals(
            "Shared image/jpeg receipt from Android share target. OCR review required before saving.",
            AndroidShareImportIntake.reviewableText(intent),
        )
    }

    private companion object {
        const val ANDROID_NS = "http://schemas.android.com/apk/res/android"
    }
}
