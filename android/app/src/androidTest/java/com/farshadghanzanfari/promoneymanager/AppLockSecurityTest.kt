package com.farshadghanzanfari.promoneymanager

import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.compose.material3.Text
import androidx.compose.ui.test.assertIsDisplayed
import androidx.compose.ui.test.junit4.createAndroidComposeRule
import androidx.compose.ui.test.onNodeWithText
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.farshadghanzanfari.promoneymanager.core.model.PrivacySettings
import org.junit.Assert.assertEquals
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AppLockSecurityTest {
    @get:Rule
    val composeRule = createAndroidComposeRule<ComponentActivity>()

    @Test
    fun enabledLockFailsClosedAndSupportsExplicitRetry() {
        val authenticator = RecordingAuthenticator(canAuthenticate = false)
        composeRule.setContent {
            AppLockGate(
                settings = PrivacySettings(appLockEnabled = true),
                authenticator = authenticator,
            ) {
                Text("Private workspace")
            }
        }

        composeRule.onNodeWithText("Pro Money Manager is locked").assertIsDisplayed()
        composeRule.onNodeWithText("Private workspace").assertDoesNotExist()
        composeRule.onNodeWithText("Set up a screen lock or biometric in Android Settings.")
            .assertIsDisplayed()
        val checksBeforeRetry = composeRule.runOnIdle { authenticator.availabilityChecks }

        composeRule.onNodeWithText("Try again").performClick()
        composeRule.runOnIdle {
            assertEquals(checksBeforeRetry + 1, authenticator.availabilityChecks)
        }
    }

    @Test
    fun successfulSystemAuthenticationRevealsWorkspace() {
        val authenticator = RecordingAuthenticator(canAuthenticate = true, succeeds = true)
        composeRule.setContent {
            AppLockGate(
                settings = PrivacySettings(appLockEnabled = true),
                authenticator = authenticator,
            ) {
                Text("Private workspace")
            }
        }

        composeRule.onNodeWithText("Private workspace").assertIsDisplayed()
        composeRule.onNodeWithText("Pro Money Manager is locked").assertDoesNotExist()
    }

    @Test
    fun secureScreenPreferenceAppliesFlagSecure() {
        ActivityScenario.launch(MainActivity::class.java).use { scenario ->
            scenario.onActivity { activity ->
                val flags = activity.window.attributes.flags
                assertEquals(
                    WindowManager.LayoutParams.FLAG_SECURE,
                    flags and WindowManager.LayoutParams.FLAG_SECURE,
                )
            }
        }
    }

    private class RecordingAuthenticator(
        private val canAuthenticate: Boolean,
        private val succeeds: Boolean = false,
    ) : AppAuthenticator {
        var requests: Int = 0
        var availabilityChecks: Int = 0

        override fun canAuthenticate(): Boolean {
            availabilityChecks += 1
            return canAuthenticate
        }

        override fun authenticate(onResult: (Boolean) -> Unit) {
            requests += 1
            if (succeeds) onResult(true)
        }
    }
}
