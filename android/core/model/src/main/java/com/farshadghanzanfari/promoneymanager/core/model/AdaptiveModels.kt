package com.farshadghanzanfari.promoneymanager.core.model

enum class NavigationMode {
    BOTTOM_BAR,
    NAVIGATION_RAIL,
    NAVIGATION_DRAWER,
}

enum class PaneMode {
    SINGLE_PANE,
    SUPPORTING_PANE,
    LIST_DETAIL,
}

data class AdaptivePolicy(
    val navigationMode: NavigationMode,
    val paneMode: PaneMode,
    val maxContentWidthDp: Int,
    val avoidFoldOcclusion: Boolean,
) {
    companion object {
        fun forWidthDp(widthDp: Int, hasOccludingFold: Boolean = false): AdaptivePolicy {
            require(widthDp > 0) { "Window width must be positive." }
            return when {
                widthDp >= 1_000 && !hasOccludingFold -> AdaptivePolicy(
                    navigationMode = NavigationMode.NAVIGATION_DRAWER,
                    paneMode = PaneMode.LIST_DETAIL,
                    maxContentWidthDp = 1_200,
                    avoidFoldOcclusion = false,
                )
                widthDp >= 600 -> AdaptivePolicy(
                    navigationMode = NavigationMode.NAVIGATION_RAIL,
                    paneMode = PaneMode.SUPPORTING_PANE,
                    maxContentWidthDp = 900,
                    avoidFoldOcclusion = hasOccludingFold,
                )
                else -> AdaptivePolicy(
                    navigationMode = NavigationMode.BOTTOM_BAR,
                    paneMode = PaneMode.SINGLE_PANE,
                    maxContentWidthDp = 560,
                    avoidFoldOcclusion = hasOccludingFold,
                )
            }
        }
    }
}

data class DestinationState(
    val selectedDestination: String = "Stats",
    val selectedMorePanel: String = "Home",
    val transactionTagFilter: String? = null,
    val importDraft: String = "",
)

object AccessibilitySummary {
    fun monthlyTotals(incomeLabel: String, expenseLabel: String, netLabel: String): String =
        "$incomeLabel. $expenseLabel. $netLabel."
}

data class ReleaseGateStatus(
    val unitTestsPass: Boolean,
    val lintPass: Boolean,
    val connectedTestsPass: Boolean,
    val releaseBundleBuilt: Boolean,
    val permissionAuditPass: Boolean,
) {
    val isPassing: Boolean
        get() = unitTestsPass && lintPass && connectedTestsPass && releaseBundleBuilt && permissionAuditPass
}
