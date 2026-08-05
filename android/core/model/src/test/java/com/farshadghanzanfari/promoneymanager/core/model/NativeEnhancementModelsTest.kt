package com.farshadghanzanfari.promoneymanager.core.model

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class NativeEnhancementModelsTest {
    @Test
    fun shareTargetAcceptsReviewableFinanceInputsOnly() {
        val accepted = listOf(
            "application/pdf",
            "text/csv",
            "text/plain",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
        val rejected = listOf("image/png", "video/mp4", "application/zip")

        assertThat(accepted.all(ShareTargetSpec::acceptsMimeType)).isTrue()
        assertThat(rejected.none(ShareTargetSpec::acceptsMimeType)).isTrue()
    }

    @Test
    fun shareTargetRoutesEverythingToImportReview() {
        val intake = SharedImportIntake(
            sourceLabel = "Gmail",
            mimeType = "text/plain",
            textPreview = "AED 42.00 CAREEM",
            uriCount = 0,
        )

        assertThat(intake.destination).isEqualTo(AndroidEnhancementDestination.IMPORT_REVIEW)
        assertThat(intake.isReviewRequired).isTrue()
    }

    @Test
    fun widgetSnapshotRedactsMoneyWhenPrivacyRequiresIt() {
        val snapshot = WidgetSnapshot(
            safeToSpend = "AED 800.00",
            monthIncome = "AED 5000.00",
            monthExpense = "AED 4200.00",
            upcomingBill = "Rent tomorrow",
            privacyMode = WidgetPrivacyMode.REDACTED,
        )

        val redacted = snapshot.display()

        assertThat(redacted.safeToSpend).isEqualTo("Hidden")
        assertThat(redacted.monthIncome).isEqualTo("Hidden")
        assertThat(redacted.monthExpense).isEqualTo("Hidden")
        assertThat(redacted.upcomingBill).isEqualTo("Open app")
    }

    @Test
    fun widgetSnapshotKeepsVisibleValuesWhenPrivacyAllowsIt() {
        val snapshot = WidgetSnapshot(
            safeToSpend = "AED 800.00",
            monthIncome = "AED 5000.00",
            monthExpense = "AED 4200.00",
            upcomingBill = "Rent tomorrow",
            privacyMode = WidgetPrivacyMode.VISIBLE,
        )

        val visible = snapshot.display()

        assertThat(visible.safeToSpend).isEqualTo("AED 800.00")
        assertThat(visible.monthIncome).isEqualTo("AED 5000.00")
        assertThat(visible.monthExpense).isEqualTo("AED 4200.00")
        assertThat(visible.upcomingBill).isEqualTo("Rent tomorrow")
    }

    @Test
    fun shortcutsExposeExpectedAndroidActions() {
        assertThat(AppShortcutSpec.defaults().map { it.id }).containsExactly(
            "add_expense",
            "import_statement",
            "search",
            "upcoming_bills",
        ).inOrder()
    }

    @Test
    fun scheduledNotificationActionsAreReviewableAndLocal() {
        val actions = ScheduledNotificationAction.defaults()

        assertThat(actions.map { it.id }).containsExactly("post", "skip", "open").inOrder()
        assertThat(actions.all { it.requiresNetwork.not() }).isTrue()
    }

    @Test
    fun ocrDraftRequiresReviewBeforeApplyingFields() {
        val draft = OcrReviewDraft(
            sourceLabel = "Receipt camera",
            recognizedText = "Coffee AED 18.50",
            confidence = OcrConfidence.LOW,
        )

        assertThat(draft.destination).isEqualTo(AndroidEnhancementDestination.IMPORT_REVIEW)
        assertThat(draft.canAutoSave).isFalse()
    }

    @Test
    fun smsCapabilityIsDisabledUntilPolicyApproval() {
        val policy = SmsIngestionPolicy()

        assertThat(policy.isEnabled).isFalse()
        assertThat(policy.requiredConditions).contains("Google Play SMS permission approval")
        assertThat(policy.requiresSeparateBuildWithoutSmsPermission).isTrue()
    }
}
