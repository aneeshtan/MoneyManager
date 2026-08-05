package com.farshadghanzanfari.promoneymanager.core.model

import com.google.common.truth.Truth.assertThat
import java.time.Duration
import java.time.Instant
import org.junit.Test

class AppLockSessionPolicyTest {
    private val backgroundedAt = Instant.parse("2026-07-11T10:00:00Z")

    @Test
    fun disabledLockNeverRequiresAuthentication() {
        assertThat(
            AppLockSessionPolicy.requiresAuthentication(
                settings = PrivacySettings(appLockEnabled = false),
                authenticatedInSession = false,
                backgroundedAt = backgroundedAt,
                now = backgroundedAt.plusSeconds(3_600),
            ),
        ).isFalse()
    }

    @Test
    fun enabledLockRequiresInitialAuthenticationAndImmediateRelock() {
        val settings = PrivacySettings(
            appLockEnabled = true,
            lockTimeout = AppLockTimeout.IMMEDIATE,
        )

        assertThat(
            AppLockSessionPolicy.requiresAuthentication(
                settings = settings,
                authenticatedInSession = false,
                backgroundedAt = null,
                now = backgroundedAt,
            ),
        ).isTrue()
        assertThat(
            AppLockSessionPolicy.requiresAuthentication(
                settings = settings,
                authenticatedInSession = true,
                backgroundedAt = backgroundedAt,
                now = backgroundedAt,
            ),
        ).isTrue()
    }

    @Test
    fun delayedLockUsesExactTimeoutBoundaryAndToleratesClockRollback() {
        val settings = PrivacySettings(
            appLockEnabled = true,
            lockTimeout = AppLockTimeout.FIVE_MINUTES,
        )

        assertThat(required(settings, Duration.ofMinutes(5).minusMillis(1))).isFalse()
        assertThat(required(settings, Duration.ofMinutes(5))).isTrue()
        assertThat(required(settings, Duration.ofSeconds(-1))).isFalse()
    }

    private fun required(settings: PrivacySettings, elapsed: Duration): Boolean =
        AppLockSessionPolicy.requiresAuthentication(
            settings = settings,
            authenticatedInSession = true,
            backgroundedAt = backgroundedAt,
            now = backgroundedAt.plus(elapsed),
        )
}
