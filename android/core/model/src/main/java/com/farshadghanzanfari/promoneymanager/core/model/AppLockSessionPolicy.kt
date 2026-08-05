package com.farshadghanzanfari.promoneymanager.core.model

import java.time.Duration
import java.time.Instant

object AppLockSessionPolicy {
    fun requiresAuthentication(
        settings: PrivacySettings,
        authenticatedInSession: Boolean,
        backgroundedAt: Instant?,
        now: Instant,
    ): Boolean {
        if (!settings.appLockEnabled) return false
        if (!authenticatedInSession) return true
        if (backgroundedAt == null) return false

        val elapsed = Duration.between(backgroundedAt, now).coerceAtLeast(Duration.ZERO)
        val timeout = Duration.ofMinutes(settings.lockTimeout.minutesUntilLock.toLong())
        return elapsed >= timeout
    }
}
