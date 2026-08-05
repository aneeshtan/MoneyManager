package com.farshadghanzanfari.promoneymanager

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.hasText
import androidx.compose.ui.test.isHeading
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.farshadghanzanfari.promoneymanager.core.designsystem.ProMoneyManagerTheme
import com.farshadghanzanfari.promoneymanager.core.model.RegionalSettings
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class OnboardingTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun continueOnDeviceShowsStats() {
        var hasWorkspace by mutableStateOf(false)
        var completedSettings: RegionalSettings? = null
        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = AppUiState(hasWorkspace = hasWorkspace),
                    onContinueOnDevice = {},
                    onCompleteOnboarding = { settings ->
                        completedSettings = settings
                        hasWorkspace = true
                    },
                )
            }
        }
        composeRule.onNodeWithText("Language").assertIsDisplayed()
        composeRule.onNodeWithText("Deutsch").performClick()
        composeRule.onNodeWithText("Start managing money").performClick()

        assert(completedSettings?.baseCurrency?.value == "EUR")
        assert(completedSettings?.countryCode == "DE")
        assert(completedSettings?.timeZoneId == "Europe/Berlin")
        composeRule.onNode(hasText("Stats") and isHeading()).assertIsDisplayed()
    }
}
