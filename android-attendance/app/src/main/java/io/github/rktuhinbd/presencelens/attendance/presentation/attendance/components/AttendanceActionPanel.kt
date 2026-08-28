package io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import io.github.rktuhinbd.presencelens.attendance.R
import io.github.rktuhinbd.presencelens.attendance.ui.theme.AttendanceTheme
import io.github.rktuhinbd.presencelens.attendance.ui.theme.OverlineTextStyle

/**
 * The attendance region from the reference (AND-20, AND-21): a dashed container carrying a
 * lock icon and the Mark Attendance button, plus the office-hours line beneath it.
 *
 * Locked and unlocked are the same container rather than two, so crossing the boundary reads
 * as one thing changing state - the dashes resolve into a solid outline and the lock becomes
 * a check. [enabled] arrives already decided from `AttendanceUiState.canMarkAttendance`; this
 * Composable evaluates no rule of its own.
 *
 * [blockedReasonText] is the panel's other job. A disabled button with no explanation is a
 * dead end, so whenever the action is unavailable the reason is stated directly beneath it -
 * already resolved by `AttendanceStatusPresenter`, never worked out here.
 *
 * Once attendance has been marked the button does not stay a live "Mark Attendance" the user
 * could press again. It becomes a completed control - a check and "Attendance marked" - which
 * is a local confirmation of what just happened on this device and implies no record anywhere
 * else ([isMarked]).
 *
 * The office-hours line is drawn here and consulted by nothing (ADR-011). It is a label, not
 * a condition: no value on this panel other than [enabled] can affect whether the button
 * works.
 */
@Composable
fun AttendanceActionPanel(
    enabled: Boolean,
    onMarkAttendance: () -> Unit,
    modifier: Modifier = Modifier,
    blockedReasonText: String? = null,
    isMarked: Boolean = false
) {
    val colorScheme = MaterialTheme.colorScheme
    val statusColors = AttendanceTheme.statusColors
    val isCompleted = isMarked && enabled

    val accentColor by animateColorAsState(
        targetValue = if (enabled) statusColors.success else colorScheme.outlineVariant,
        animationSpec = tween(durationMillis = STATE_TRANSITION_MILLIS),
        label = "attendancePanelBorder"
    )
    val headerColor by animateColorAsState(
        targetValue = if (enabled) statusColors.success else colorScheme.onSurfaceVariant,
        animationSpec = tween(durationMillis = STATE_TRANSITION_MILLIS),
        label = "attendancePanelHeader"
    )

    // A single settle on the icon when the region unlocks. Spring rather than tween because
    // the gesture being described is a latch releasing, not a fade.
    val iconScale by animateFloatAsState(
        targetValue = if (enabled) 1f else 0.92f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "attendancePanelIconScale"
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .dashedOutline(color = accentColor, solid = enabled)
            .padding(horizontal = 18.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(10.dp)
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
                tint = headerColor,
                modifier = Modifier
                    .size(20.dp)
                    .scale(iconScale)
            )
            Text(
                text = stringResource(
                    when {
                        isCompleted -> R.string.mark_attendance_done
                        enabled -> R.string.mark_attendance_ready
                        else -> R.string.mark_attendance_locked
                    }
                ),
                style = OverlineTextStyle,
                color = headerColor
            )
        }

        // Completed is a third button state, not a fourth colour: it is disabled like the
        // locked state, but keeps the success role so the screen still reads as having
        // succeeded rather than as having stopped working.
        Button(
            onClick = onMarkAttendance,
            enabled = enabled && !isCompleted,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = PRIMARY_BUTTON_HEIGHT_DP.dp),
            shape = MaterialTheme.shapes.medium,
            colors = ButtonDefaults.buttonColors(
                containerColor = statusColors.success,
                contentColor = statusColors.onSuccess,
                disabledContainerColor = if (isCompleted) {
                    statusColors.successContainer
                } else {
                    colorScheme.surfaceContainerHighest
                },
                disabledContentColor = if (isCompleted) {
                    statusColors.onSuccessContainer
                } else {
                    colorScheme.onSurfaceVariant.copy(alpha = 0.62f)
                }
            )
        ) {
            if (isCompleted) {
                Icon(
                    painter = painterResource(R.drawable.ic_check_circle),
                    // The label immediately after says what happened.
                    contentDescription = null,
                    modifier = Modifier.size(18.dp)
                )
                Spacer(modifier = Modifier.width(8.dp))
            }
            Text(
                text = stringResource(
                    if (isCompleted) {
                        R.string.mark_attendance_done_action
                    } else {
                        R.string.mark_attendance
                    }
                ),
                style = MaterialTheme.typography.labelLarge
            )
        }

        // Why the button cannot be pressed, in one line, where the user is already looking.
        AnimatedVisibility(
            visible = blockedReasonText != null,
            enter = fadeIn() + expandVertically(),
            exit = fadeOut() + shrinkVertically()
        ) {
            InlineNote(
                iconResId = R.drawable.ic_info,
                text = blockedReasonText.orEmpty(),
                color = colorScheme.onSurfaceVariant
            )
        }

        HorizontalDivider(
            modifier = Modifier.padding(top = 2.dp),
            color = colorScheme.outlineVariant.copy(alpha = 0.7f)
        )

        // AND-21 / ADR-011. The reference screenshot's "AVAILABLE 09:00 AM - 10:30 AM" reads
        // as a rule; it is not one, and no sentence in the assessment makes it one. Labelling
        // the same value "Office hours" keeps the element and drops the false promise.
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                painter = painterResource(R.drawable.ic_clock),
                contentDescription = null,
                tint = colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .size(15.dp)
                    .clearAndSetSemantics { }
            )
            Text(
                text = stringResource(R.string.office_hours_label),
                style = MaterialTheme.typography.labelMedium,
                color = colorScheme.onSurfaceVariant
            )
            Text(
                text = stringResource(R.string.office_hours_value),
                style = MaterialTheme.typography.labelMedium,
                color = colorScheme.onSurface,
                textAlign = TextAlign.Center
            )
        }
    }
}

/** A one-line note under the button: a small icon, then the sentence. */
@Composable
private fun InlineNote(
    iconResId: Int,
    text: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.Center,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            painter = painterResource(iconResId),
            contentDescription = null,
            tint = color,
            modifier = Modifier
                .size(16.dp)
                .clearAndSetSemantics { }
        )
        Text(
            text = text,
            style = MaterialTheme.typography.bodyMedium,
            color = color,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(start = 8.dp)
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

private const val STATE_TRANSITION_MILLIS = 400

/** Comfortably above Android's 48 dp minimum touch target for the screen's primary action. */
private const val PRIMARY_BUTTON_HEIGHT_DP = 56
