package com.farshadghanzanfari.promoneymanager

import android.content.Context
import android.content.ContextWrapper
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import com.farshadghanzanfari.promoneymanager.core.model.AppLockSessionPolicy
import com.farshadghanzanfari.promoneymanager.core.model.PrivacySettings
import java.time.Instant

interface AppAuthenticator {
    fun canAuthenticate(): Boolean
    fun authenticate(onResult: (Boolean) -> Unit)
}

class AppLockSessionState internal constructor() {
    var authenticated by mutableStateOf(false)
    var backgroundedAt: Instant? = null
}

@Composable
fun rememberAppLockSessionState(): AppLockSessionState = remember { AppLockSessionState() }

@Composable
fun rememberAndroidAppAuthenticator(): AppAuthenticator {
    val activity = LocalContext.current.findFragmentActivity()
    return remember(activity) { AndroidAppAuthenticator(activity) }
}

@Composable
fun AppLockGate(
    settings: PrivacySettings,
    authenticator: AppAuthenticator,
    sessionState: AppLockSessionState = rememberAppLockSessionState(),
    content: @Composable () -> Unit,
) {
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var message by remember { mutableStateOf<String?>(null) }
    var requestNumber by remember { mutableStateOf(0) }

    fun requestAuthentication() {
        requestNumber += 1
    }

    DisposableEffect(lifecycle, settings) {
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_STOP -> {
                    sessionState.backgroundedAt = Instant.now()
                    if (settings.lockTimeout.minutesUntilLock == 0) {
                        sessionState.authenticated = false
                    }
                }
                Lifecycle.Event.ON_START -> {
                    if (
                        sessionState.backgroundedAt != null &&
                        AppLockSessionPolicy.requiresAuthentication(
                            settings = settings,
                            authenticatedInSession = sessionState.authenticated,
                            backgroundedAt = sessionState.backgroundedAt,
                            now = Instant.now(),
                        )
                    ) {
                        sessionState.authenticated = false
                        requestAuthentication()
                    }
                    sessionState.backgroundedAt = null
                }
                else -> Unit
            }
        }
        lifecycle.addObserver(observer)
        onDispose { lifecycle.removeObserver(observer) }
    }

    LaunchedEffect(settings.appLockEnabled) {
        if (settings.appLockEnabled && !sessionState.authenticated) requestAuthentication()
        if (!settings.appLockEnabled) sessionState.authenticated = true
    }

    val screenLockMessage = stringResource(R.string.set_up_screen_lock)
    val authNotCompletedMessage = stringResource(R.string.authentication_not_completed)
    LaunchedEffect(requestNumber) {
        if (requestNumber == 0) return@LaunchedEffect
        if (!authenticator.canAuthenticate()) {
            message = screenLockMessage
            return@LaunchedEffect
        }
        message = null
        authenticator.authenticate { success ->
            sessionState.authenticated = success
            if (!success) message = authNotCompletedMessage
        }
    }

    if (!settings.appLockEnabled || sessionState.authenticated) {
        content()
    } else {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .padding(32.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = stringResource(R.string.app_locked_title),
                style = MaterialTheme.typography.headlineMedium,
                fontWeight = FontWeight.SemiBold,
                textAlign = TextAlign.Center,
            )
            Text(
                text = message ?: stringResource(R.string.app_locked_message),
                modifier = Modifier.padding(vertical = 16.dp),
                style = MaterialTheme.typography.bodyLarge,
                textAlign = TextAlign.Center,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Button(onClick = ::requestAuthentication) {
                Text(stringResource(R.string.try_again))
            }
        }
    }
}

private class AndroidAppAuthenticator(
    private val activity: FragmentActivity,
) : AppAuthenticator {
    override fun canAuthenticate(): Boolean =
        BiometricManager.from(activity).canAuthenticate(AUTHENTICATORS) ==
            BiometricManager.BIOMETRIC_SUCCESS

    override fun authenticate(onResult: (Boolean) -> Unit) {
        val prompt = BiometricPrompt(
            activity,
            ContextCompat.getMainExecutor(activity),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    onResult(true)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    onResult(false)
                }
            },
        )
        prompt.authenticate(
            BiometricPrompt.PromptInfo.Builder()
                .setTitle(activity.getString(R.string.unlock_prompt_title))
                .setSubtitle(activity.getString(R.string.unlock_prompt_subtitle))
                .setAllowedAuthenticators(AUTHENTICATORS)
                .build(),
        )
    }

    companion object {
        private const val AUTHENTICATORS =
            BiometricManager.Authenticators.BIOMETRIC_WEAK or
                BiometricManager.Authenticators.DEVICE_CREDENTIAL
    }
}

private tailrec fun Context.findFragmentActivity(): FragmentActivity = when (this) {
    is FragmentActivity -> this
    is ContextWrapper -> baseContext.findFragmentActivity()
    else -> error("App lock requires a FragmentActivity host.")
}
