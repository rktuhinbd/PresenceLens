package io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import io.github.rktuhinbd.presencelens.attendance.R
import io.github.rktuhinbd.presencelens.attendance.ui.theme.AttendanceTheme
import io.github.rktuhinbd.presencelens.attendance.ui.theme.OverlineTextStyle

/**
 * The attendance region from the reference (AND-20, AND-21): a dashed container carrying a
 * lock icon and the Mark Attendance button, plus the availability caption beneath it.
 *
 * Locked and unlocked are the same container rather than two, so crossing the boundary reads
 * as one thing changing state - the dashes resolve into a solid outline and the lock becomes
 * a check. [enabled] arrives already decided from `AttendanceUiState.canMarkAttendance`; this
 * Composable evaluates no rule of its own.
 *
 * The availability caption is drawn here and consulted by nothing (ADR-011). It is a label,
 * not a condition.
 */
@Composable
fun AttendanceActionPanel(
    enabled: Boolean,
    onMarkAttendance: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colorScheme = MaterialTheme.colorScheme
    val statusColors = AttendanceTheme.statusColors

    val borderColor by animateColorAsState(
        targetValue = if (enabled) statusColors.success else colorScheme.outlineVariant,
        animationSpec = tween(durationMillis = 400),
        label = "attendancePanelBorder"
    )
    val iconTint by animateColorAsState(
        targetValue = if (enabled) statusColors.success else colorScheme.onSurfaceVariant,
        animationSpec = tween(durationMillis = 400),
        label = "attendancePanelIcon"
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .dashedOutline(color = borderColor, solid = enabled)
            .padding(horizontal = 20.dp, vertical = 22.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                painter = painterResource(
                    if (enabled) R.drawable.ic_check_circle else R.drawable.ic_lock
                ),
                // When unlocked the label beside it says everything. When locked, the reason
                // is not otherwise announced anywhere a screen reader would reach.
                contentDescription = if (enabled) {
                    null
                } else {
                    stringResource(R.string.content_description_attendance_locked)
                },
                tint = iconTint,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = stringResource(
                    if (enabled) R.string.range_status_in else R.string.mark_attendance_locked
                ),
                style = OverlineTextStyle,
                color = iconTint
            )
        }

        Button(
            onClick = onMarkAttendance,
            enabled = enabled,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = MIN_TOUCH_TARGET_DP.dp),
            shape = MaterialTheme.shapes.medium,
            colors = ButtonDefaults.buttonColors(
                containerColor = statusColors.success,
                contentColor = statusColors.onSuccess,
                disabledContainerColor = colorScheme.surfaceContainerHighest,
                disabledContentColor = colorScheme.onSurfaceVariant.copy(alpha = 0.62f)
            )
        ) {
            Text(
                text = stringResource(R.string.mark_attendance),
                style = MaterialTheme.typography.labelLarge
            )
        }

        Text(
            text = stringResource(R.string.availability_caption),
            style = OverlineTextStyle,
            color = colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center
        )
    }
}

/**
 * A dashed rounded outline that becomes solid when the region unlocks. Drawn rather than
 * composed from a `border` modifier because Compose has no dashed border out of the box.
 */
private fun Modifier.dashedOutline(color: Color, solid: Boolean): Modifier = drawBehind {
    val strokeWidth = 1.5.dp.toPx()
    val inset = strokeWidth / 2f
    val cornerRadius = CornerRadius(24.dp.toPx())
    drawRoundRect(
        color = color,
        topLeft = Offset(inset, inset),
        size = Size(size.width - strokeWidth, size.height - strokeWidth),
        cornerRadius = cornerRadius,
        style = Stroke(
            width = strokeWidth,
            pathEffect = if (solid) {
                null
            } else {
                PathEffect.dashPathEffect(floatArrayOf(9.dp.toPx(), 7.dp.toPx()))
            }
        )
    )
}

/** Android's minimum accessible touch target. */
private const val MIN_TOUCH_TARGET_DP = 56
