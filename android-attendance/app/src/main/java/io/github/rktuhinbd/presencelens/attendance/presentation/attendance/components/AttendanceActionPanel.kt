package io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components

import androidx.compose.animation.AnimatedContent
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
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import io.github.rktuhinbd.presencelens.attendance.R
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.MarkAttendanceAction
import io.github.rktuhinbd.presencelens.attendance.ui.theme.AttendanceTheme
import io.github.rktuhinbd.presencelens.attendance.ui.theme.OverlineTextStyle

/**
 * The attendance region from the reference (AND-20, AND-21), and what it becomes once the
 * action it exists for is finished.
 *
 * Before the mark, this is the dashed container carrying a lock icon and the Mark Attendance
 * button. Locked and unlocked are the same container rather than two, so crossing the boundary
 * reads as one thing changing state - the dashes resolve into a solid outline and the lock
 * becomes a check. [action] arrives already decided by `AttendanceStatusPresenter`; this
 * Composable evaluates no rule of its own.
 *
 * [blockedReasonText] is the panel's other job while the action is refused. A disabled button
 * with no explanation is a dead end, so whenever the action is unavailable the reason is stated
 * directly beneath it - already resolved upstream, never worked out here.
 *
 * After the mark, the control is gone. A completed action is not an action: no relabelled
 * button, no disabled control, no second heading repeating what the status card already said in
 * its own words. What is left is a compact confirmation of the two facts worth keeping - when
 * attendance was marked, and the distance that was verified at that moment - and it is a
 * statement, not something a screen reader can mistake for a button. It is a local confirmation
 * of what happened on this device and implies no record anywhere else.
 *
 * The office-hours line is drawn here and consulted by nothing (ADR-011). It is a label, not a
 * condition: no value on this panel can affect whether the action works.
 */
@Composable
fun AttendanceActionPanel(
    action: MarkAttendanceAction,
    onMarkAttendance: () -> Unit,
    modifier: Modifier = Modifier,
    blockedReasonText: String? = null,
    markedAtText: String? = null,
    verifiedDistanceText: String? = null
) {
    // Cross-fading between "offer the action" and "confirm it happened" rather than cutting:
    // the panel changes shape at that moment, and a hard swap under the user's own tap reads
    // as a glitch. Nothing waits on it - both faces render their text on the first frame.
    AnimatedContent(
        targetState = action == MarkAttendanceAction.COMPLETED,
        transitionSpec = { fadeIn(tween(220)) togetherWith fadeOut(tween(160)) },
        label = "attendanceActionPanel",
        modifier = modifier.fillMaxWidth()
    ) { isCompleted ->
        if (isCompleted) {
            CompletedAttendancePanel(
                markedAtText = markedAtText.orEmpty(),
                verifiedDistanceText = verifiedDistanceText.orEmpty(),
                modifier = Modifier.fillMaxWidth()
            )
        } else {
            PendingAttendancePanel(
                enabled = action == MarkAttendanceAction.AVAILABLE,
                onMarkAttendance = onMarkAttendance,
                blockedReasonText = blockedReasonText,
                modifier = Modifier.fillMaxWidth()
            )
        }
    }
}

/** The attendance region while the action is still ahead of the user: locked, or unlocked. */
@Composable
private fun PendingAttendancePanel(
    enabled: Boolean,
    onMarkAttendance: () -> Unit,
    blockedReasonText: String?,
    modifier: Modifier = Modifier
) {
    val colorScheme = MaterialTheme.colorScheme
    val statusColors = AttendanceTheme.statusColors

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
                    if (enabled) R.string.mark_attendance_ready else R.string.mark_attendance_locked
                ),
                style = OverlineTextStyle,
                color = headerColor
            )
        }

        Button(
            onClick = onMarkAttendance,
            enabled = enabled,
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = PRIMARY_BUTTON_HEIGHT_DP.dp),
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

        OfficeHoursRow()
    }
}

/**
 * The attendance region once the mark is done.
 *
 * No outline, no overline, no control - the dashed container existed to frame an action that no
 * longer exists, and keeping it would leave the completed state looking exactly as pressable as
 * the state before it. What remains is a receipt and the office-hours line, which is both
 * shorter than the panel it replaces and quieter than it.
 */
@Composable
private fun CompletedAttendancePanel(
    markedAtText: String,
    verifiedDistanceText: String,
    modifier: Modifier = Modifier
) {
    val colorScheme = MaterialTheme.colorScheme
    val statusColors = AttendanceTheme.statusColors

    // Resolved here rather than inside the semantics lambda, which is not a composable scope.
    val confirmationDescription = stringResource(
        R.string.content_description_attendance_confirmation,
        markedAtText,
        verifiedDistanceText
    )

    // One settle as the confirmation arrives, alongside the haptic the screen already fires.
    // The text is laid out at full size from the first frame; only the badge moves.
    var settled by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { settled = true }
    val badgeScale by animateFloatAsState(
        targetValue = if (settled) 1f else 0.82f,
        animationSpec = spring(dampingRatio = Spring.DampingRatioMediumBouncy),
        label = "attendanceConfirmationBadge"
    )

    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        // A quiet card in the screen's own surface role, not a second green announcement. The
        // status card above has already said this happened; down here the job is to record it,
        // and two saturated success blocks saying the same words would be the repetition this
        // panel was rewritten to remove. The check keeps the success colour, so the signal is
        // present without being restated at full volume.
        Surface(
            modifier = Modifier.fillMaxWidth(),
            shape = MaterialTheme.shapes.large,
            color = colorScheme.surfaceContainerLow,
            contentColor = colorScheme.onSurface
        ) {
            Row(
                modifier = Modifier
                    .padding(horizontal = 16.dp, vertical = 14.dp)
                    // One node, one sentence. TalkBack meets a statement of what happened,
                    // not a control it cannot operate.
                    .clearAndSetSemantics {
                        contentDescription = confirmationDescription
                    },
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    modifier = Modifier
                        .size(CONFIRMATION_BADGE_SIZE_DP.dp)
                        .scale(badgeScale)
                        .background(
                            color = statusColors.successContainer,
                            shape = CircleShape
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    Icon(
                        painter = painterResource(R.drawable.ic_check_circle),
                        contentDescription = null,
                        tint = statusColors.onSuccessContainer,
                        modifier = Modifier.size(18.dp)
                    )
                }

                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(2.dp)
                ) {
                    Text(
                        text = stringResource(R.string.attendance_confirmation_title),
                        style = MaterialTheme.typography.titleSmall
                    )
                    Text(
                        text = stringResource(
                            R.string.attendance_confirmation_detail,
                            verifiedDistanceText
                        ),
                        style = MaterialTheme.typography.bodySmall,
                        color = colorScheme.onSurfaceVariant
                    )
                }

                // The time sits on the trailing edge, the way a receipt carries its stamp:
                // present and precise, without taking a line of its own.
                Text(
                    text = markedAtText,
                    style = MaterialTheme.typography.labelLarge,
                    color = colorScheme.onSurface
                )
            }
        }

        HorizontalDivider(color = colorScheme.outlineVariant.copy(alpha = 0.7f))

        OfficeHoursRow()
    }
}

/**
 * AND-21 / ADR-011. The reference screenshot's "AVAILABLE 09:00 AM - 10:30 AM" reads as a rule;
 * it is not one, and no sentence in the assessment makes it one. Labelling the same value
 * "Office hours" keeps the element and drops the false promise.
 *
 * It stays secondary in both faces of the panel, below a divider, unchanged by the mark.
 */
@Composable
private fun OfficeHoursRow(modifier: Modifier = Modifier) {
    val colorScheme = MaterialTheme.colorScheme

    Row(
        modifier = modifier,
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

private const val CONFIRMATION_BADGE_SIZE_DP = 32
