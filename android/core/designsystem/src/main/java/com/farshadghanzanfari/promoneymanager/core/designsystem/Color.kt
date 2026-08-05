package com.farshadghanzanfari.promoneymanager.core.designsystem

import androidx.compose.ui.graphics.Color

// Exact RGB float values ported from the iOS AppTheme palette
// (MManger/Views/Formatters.swift) so both platforms render identical brand colors.
val BrandViolet = Color(0xFF7955D0)
val BrandTeal = Color(0xFF0B998E)
val BrandMint = Color(0xFF2ABB9F)
val BrandCoral = Color(0xFFF6697C)
val BrandRose = Color(0xFFE65285)
val BrandGold = Color(0xFFE7AC50)
val BrandLavenderAccent = Color(0xFFA67CED)

/** Subtle violet tint used for pale chip/badge backgrounds, matching iOS's `violet.opacity(n)` pattern. */
val BrandLavender = BrandViolet.copy(alpha = 0.14f)

internal val LightBackground = Color(0xFFF9FAFC)
internal val LightSurface = Color(0xFFFCFDFE)
internal val LightSurfaceVariant = Color(0xFFF4F5F9)
internal val LightInk = Color(0xFF1B1D22)
internal val LightMutedInk = Color(0xFF747986)
internal val LightOutline = Color(0xFFE1E4EA)

internal val DarkBackground = Color(0xFF0E0F13)
internal val DarkSurface = Color(0xFF21242B)
internal val DarkSurfaceVariant = Color(0xFF2A2D37)
internal val DarkInk = Color(0xFFE3E8F1)
internal val DarkMutedInk = Color(0xFF9CA3B2)
internal val DarkOutline = Color(0xFF343945)
