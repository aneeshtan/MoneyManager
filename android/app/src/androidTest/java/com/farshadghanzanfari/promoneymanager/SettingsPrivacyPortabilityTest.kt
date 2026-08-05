package com.farshadghanzanfari.promoneymanager

import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.v2.createComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.onAllNodesWithText
import androidx.compose.ui.test.performClick
import androidx.compose.ui.test.performScrollTo
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.farshadghanzanfari.promoneymanager.core.designsystem.ProMoneyManagerTheme
import com.farshadghanzanfari.promoneymanager.core.model.Account
import com.farshadghanzanfari.promoneymanager.core.model.AccountId
import com.farshadghanzanfari.promoneymanager.core.model.AccountType
import com.farshadghanzanfari.promoneymanager.core.model.CurrencyCode
import com.farshadghanzanfari.promoneymanager.core.model.Money
import com.farshadghanzanfari.promoneymanager.core.model.RegionalSettings
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class SettingsPrivacyPortabilityTest {
    @get:Rule
    val composeRule = createComposeRule()

    @Test
    fun moreShowsPrivacyPortabilityNotificationAndLanguageSettings() {
        val aed = CurrencyCode.of("AED")
        var regionalSettings by androidx.compose.runtime.mutableStateOf(RegionalSettings())
        composeRule.setContent {
            ProMoneyManagerTheme {
                ProMoneyManagerContent(
                    state = AppUiState(
                        hasWorkspace = true,
                        accounts = listOf(
                            Account(AccountId("cash"), "Cash", aed, Money.zero(aed), AccountType.CASH),
                        ),
                        regionalSettings = regionalSettings,
                    ),
                    onContinueOnDevice = {},
                    onSaveRegionalSettings = { regionalSettings = it },
                )
            }
        }

        composeRule.onNodeWithText("More").performClick()

        composeRule.onNodeWithText("Backup").performScrollTo().performClick()
        composeRule.onNodeWithText("Complete backup package").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Restore preview").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Legacy export report").performScrollTo().assertIsDisplayed()

        composeRule.onNodeWithText("Privacy").performScrollTo().performClick()
        composeRule.onNodeWithText("Privacy lock").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("App lock disabled").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Secure screen enabled").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Delete workspace").performScrollTo().assertIsDisplayed()

        composeRule.onNodeWithText("Notifications").performScrollTo().performClick()
        composeRule.onNodeWithText("Reminder permission not requested").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Permission is requested only when reminders are enabled.").performScrollTo().assertIsDisplayed()

        composeRule.onNodeWithText("Language").performScrollTo().performClick()
        composeRule.onNodeWithText("Language & region").performScrollTo().assertIsDisplayed()
        composeRule.onAllNodesWithText("English")[0].performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Arabic and Persian use RTL").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Persian calendar supported").performScrollTo().assertIsDisplayed()
        composeRule.onNodeWithText("Base currency").performScrollTo().performClick()
        composeRule.onNodeWithText("EUR", substring = true).performClick()
        composeRule.onNodeWithText("Save regional settings").performScrollTo().performClick()
        composeRule.onAllNodesWithText("EUR", substring = true)[0].performScrollTo().assertIsDisplayed()
    }
}
