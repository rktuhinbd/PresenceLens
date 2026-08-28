package io.github.rktuhinbd.presencelens.attendance.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * Success and warning roles, which Material 3 does not define.
 *
 * ADR-012 requires status colour that carries meaning, and the screen has three distinct
 * outcomes to signal: in range, out of range, and a degraded fix. Out of range reuses the
 * Material `error` role; the other two need roles of their own, built to the same
 * container/on-container contrast contract so they behave predictably in both themes.
 */
@Immutable
data class StatusColors(
    val success: Color,
    val onSuccess: Color,
    val successContainer: Color,
    val onSuccessContainer: Color,
    val warning: Color,
    val onWarning: Color,
    val warningContainer: Color,
    val onWarningContainer: Color
)

internal val LightStatusColors = StatusColors(
    success = Color(0xFF146C43),
    onSuccess = Color(0xFFFFFFFF),
    successContainer = Color(0xFFC5F0D4),
    onSuccessContainer = Color(0xFF00210E),
    warning = Color(0xFF8B5000),
    onWarning = Color(0xFFFFFFFF),
    warningContainer = Color(0xFFFFDDB8),
    onWarningContainer = Color(0xFF2C1600)
)

internal val DarkStatusColors = StatusColors(
    success = Color(0xFF7FD8A0),
    onSuccess = Color(0xFF00391C),
    successContainer = Color(0xFF005329),
    onSuccessContainer = Color(0xFFC5F0D4),
    warning = Color(0xFFFFB871),
    onWarning = Color(0xFF4A2800),
    warningContainer = Color(0xFF6A3C00),
    onWarningContainer = Color(0xFFFFDDB8)
)

internal val LocalStatusColors = staticCompositionLocalOf { LightStatusColors }
