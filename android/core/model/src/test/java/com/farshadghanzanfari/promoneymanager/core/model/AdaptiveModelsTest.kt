package com.farshadghanzanfari.promoneymanager.core.model

import com.google.common.truth.Truth.assertThat
import org.junit.Test

class AdaptiveModelsTest {
    @Test
    fun adaptivePolicySelectsSinglePaneRailAndSupportingPane() {
        assertThat(AdaptivePolicy.forWidthDp(360).navigationMode).isEqualTo(NavigationMode.BOTTOM_BAR)
        assertThat(AdaptivePolicy.forWidthDp(700).navigationMode).isEqualTo(NavigationMode.NAVIGATION_RAIL)
        assertThat(AdaptivePolicy.forWidthDp(1_200).paneMode).isEqualTo(PaneMode.LIST_DETAIL)
    }

    @Test
    fun foldAwarePolicyAvoidsOccludingHinge() {
        val policy = AdaptivePolicy.forWidthDp(widthDp = 900, hasOccludingFold = true)

        assertThat(policy.avoidFoldOcclusion).isTrue()
        assertThat(policy.paneMode).isEqualTo(PaneMode.SUPPORTING_PANE)
    }

    @Test
    fun destinationStatePreservesSelectionFilterAndDraft() {
        val state = DestinationState(
            selectedDestination = "More",
            selectedMorePanel = "Search",
            transactionTagFilter = "Business",
            importDraft = "statement text",
        )

        assertThat(state.selectedDestination).isEqualTo("More")
        assertThat(state.selectedMorePanel).isEqualTo("Search")
        assertThat(state.transactionTagFilter).isEqualTo("Business")
        assertThat(state.importDraft).isEqualTo("statement text")
    }

    @Test
    fun accessibilitySummariesDoNotRequireChartColor() {
        val summary = AccessibilitySummary.monthlyTotals(
            incomeLabel = "Income AED 1000.00",
            expenseLabel = "Expense AED 150.00",
            netLabel = "Net AED 850.00",
        )

        assertThat(summary).contains("Income AED 1000.00")
        assertThat(summary).contains("Expense AED 150.00")
        assertThat(summary).contains("Net AED 850.00")
    }

    @Test
    fun releaseGateAggregatesRequiredChecks() {
        val gate = ReleaseGateStatus(
            unitTestsPass = true,
            lintPass = true,
            connectedTestsPass = true,
            releaseBundleBuilt = true,
            permissionAuditPass = true,
        )

        assertThat(gate.isPassing).isTrue()
    }

    @Test
    fun releaseGateFailsWhenPermissionAuditOrBundleIsMissing() {
        val gate = ReleaseGateStatus(
            unitTestsPass = true,
            lintPass = true,
            connectedTestsPass = true,
            releaseBundleBuilt = false,
            permissionAuditPass = true,
        )

        assertThat(gate.isPassing).isFalse()
    }
}
