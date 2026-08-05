package com.farshadghanzanfari.promoneymanager.core.model

enum class AndroidEnhancementDestination {
    IMPORT_REVIEW,
    SCHEDULE_REVIEW,
    OPEN_APP,
}

object ShareTargetSpec {
    private val exactMimeTypes = setOf(
        "application/pdf",
        "text/csv",
        "text/plain",
        "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    )

    fun acceptsMimeType(mimeType: String): Boolean {
        val normalized = mimeType.trim().lowercase()
        return normalized in exactMimeTypes || normalized.startsWith("text/")
    }
}

data class SharedImportIntake(
    val sourceLabel: String,
    val mimeType: String,
    val textPreview: String?,
    val uriCount: Int,
) {
    val destination: AndroidEnhancementDestination = AndroidEnhancementDestination.IMPORT_REVIEW
    val isReviewRequired: Boolean = true
}

enum class WidgetPrivacyMode {
    VISIBLE,
    REDACTED,
}

data class WidgetSnapshot(
    val safeToSpend: String,
    val monthIncome: String,
    val monthExpense: String,
    val upcomingBill: String,
    val privacyMode: WidgetPrivacyMode,
) {
    fun display(): WidgetSnapshotDisplay =
        when (privacyMode) {
            WidgetPrivacyMode.VISIBLE -> WidgetSnapshotDisplay(
                safeToSpend = safeToSpend,
                monthIncome = monthIncome,
                monthExpense = monthExpense,
                upcomingBill = upcomingBill,
            )
            WidgetPrivacyMode.REDACTED -> WidgetSnapshotDisplay(
                safeToSpend = HIDDEN_VALUE,
                monthIncome = HIDDEN_VALUE,
                monthExpense = HIDDEN_VALUE,
                upcomingBill = OPEN_APP_VALUE,
            )
        }

    private companion object {
        const val HIDDEN_VALUE = "Hidden"
        const val OPEN_APP_VALUE = "Open app"
    }
}

data class WidgetSnapshotDisplay(
    val safeToSpend: String,
    val monthIncome: String,
    val monthExpense: String,
    val upcomingBill: String,
)

data class AppShortcutSpec(
    val id: String,
    val shortLabel: String,
    val destination: AndroidEnhancementDestination,
) {
    companion object {
        fun defaults(): List<AppShortcutSpec> = listOf(
            AppShortcutSpec(
                id = "add_expense",
                shortLabel = "Add expense",
                destination = AndroidEnhancementDestination.IMPORT_REVIEW,
            ),
            AppShortcutSpec(
                id = "import_statement",
                shortLabel = "Import statement",
                destination = AndroidEnhancementDestination.IMPORT_REVIEW,
            ),
            AppShortcutSpec(
                id = "search",
                shortLabel = "Search",
                destination = AndroidEnhancementDestination.OPEN_APP,
            ),
            AppShortcutSpec(
                id = "upcoming_bills",
                shortLabel = "Upcoming bills",
                destination = AndroidEnhancementDestination.SCHEDULE_REVIEW,
            ),
        )
    }
}

data class ScheduledNotificationAction(
    val id: String,
    val label: String,
    val requiresNetwork: Boolean,
) {
    companion object {
        fun defaults(): List<ScheduledNotificationAction> = listOf(
            ScheduledNotificationAction(id = "post", label = "Post", requiresNetwork = false),
            ScheduledNotificationAction(id = "skip", label = "Skip", requiresNetwork = false),
            ScheduledNotificationAction(id = "open", label = "Open", requiresNetwork = false),
        )
    }
}

enum class OcrConfidence {
    LOW,
    MEDIUM,
    HIGH,
}

data class OcrReviewDraft(
    val sourceLabel: String,
    val recognizedText: String,
    val confidence: OcrConfidence,
) {
    val destination: AndroidEnhancementDestination = AndroidEnhancementDestination.IMPORT_REVIEW
    val canAutoSave: Boolean = false
}

data class SmsIngestionPolicy(
    val isEnabled: Boolean = false,
    val requiredConditions: List<String> = DEFAULT_REQUIRED_CONDITIONS,
    val requiresSeparateBuildWithoutSmsPermission: Boolean = true,
) {
    companion object {
        val DEFAULT_REQUIRED_CONDITIONS: List<String> = listOf(
            "Google Play SMS permission approval",
            "Prominent disclosure and granular consent",
            "On-device processing only",
            "Review queue before saving",
            "No SMS-content transmission",
        )
    }
}
