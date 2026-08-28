package io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import io.github.rktuhinbd.presencelens.attendance.R
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.AttendanceStatusKind
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.AttendanceStatusPresentation
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.StatusAction
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.StatusTone
import io.github.rktuhinbd.presencelens.attendance.ui.theme.AttendanceTheme

/**
 * The screen's headline: one card that always says what the app is doing and, when something
 * is blocked, why (GEN-04).
 *
 * Every condition arrives here already resolved by `AttendanceStatusPresenter`, so this
 * Composable only maps a [AttendanceStatusPresentation] to words, colour, and an icon. Which
 * state the user is in was never decided here.
 *
 * The card is deliberately the same shape in all twelve states. A user reads the difference in
 * the sentence and the tone, not by re-learning where to look.
 */
@Composable
fun AttendanceStatusCard(
    presentation: AttendanceStatusPresentation,
    radiusMeters: Int,
    modifier: Modifier = Modifier,
    distanceText: String? = null,
    markedAtText: String? = null,
    onRequestPermission: () -> Unit = {},
    onOpenApplicationSettings: () -> Unit = {},
    onOpenLocationSettings: () -> Unit = {}
) {
    val tone = statusToneColors(presentation.tone)
    val containerColor by animateColorAsState(
        targetValue = tone.container,
        animationSpec = tween(durationMillis = TONE_TRANSITION_MILLIS),
        label = "statusCardContainer"
    )
    val contentColor by animateColorAsState(
        targetValue = tone.onContainer,
        animationSpec = tween(durationMillis = TONE_TRANSITION_MILLIS),
        label = "statusCardContent"
    )

    // Cross-fading the text rather than swapping it instantly is the whole of the motion here:
    // the card changes wording often, and a hard cut reads as a glitch.
    AnimatedContent(
        targetState = presentation,
        transitionSpec = { fadeIn(tween(220)) togetherWith fadeOut(tween(160)) },
        label = "statusCardContent",
        modifier = modifier.fillMaxWidth()
    ) { current ->
        StatusBanner(
            modifier = Modifier.fillMaxWidth(),
            title = statusTitle(current.kind),
            body = statusBody(current.kind, radiusMeters, distanceText, markedAtText),
            containerColor = containerColor,
            contentColor = contentColor,
            iconResId = statusIcon(current.kind),
            showProgress = current.kind == AttendanceStatusKind.ACQUIRING_FIX,
            actionLabel = current.action?.let { statusActionLabel(current.kind, it) },
            actionIconResId = when (current.action) {
                StatusAction.OPEN_APPLICATION_SETTINGS,
                StatusAction.OPEN_LOCATION_SETTINGS -> R.drawable.ic_open_in_new

                else -> null
            },
            onAction = when (current.action) {
                StatusAction.REQUEST_PERMISSION -> onRequestPermission
                StatusAction.OPEN_APPLICATION_SETTINGS -> onOpenApplicationSettings
                StatusAction.OPEN_LOCATION_SETTINGS -> onOpenLocationSettings
                null -> null
            }
        )
    }
}

@Composable
private fun statusTitle(kind: AttendanceStatusKind): String = when (kind) {
    AttendanceStatusKind.PERMISSION_REQUIRED,
    AttendanceStatusKind.PERMISSION_BLOCKED -> stringResource(R.string.status_permission_title)

    AttendanceStatusKind.PRECISE_REQUIRED,
    AttendanceStatusKind.PRECISE_BLOCKED -> stringResource(R.string.status_precise_title)

    AttendanceStatusKind.SERVICES_DISABLED -> stringResource(R.string.status_services_title)
    AttendanceStatusKind.ACQUIRING_FIX -> stringResource(R.string.status_acquiring_title)

    AttendanceStatusKind.LOCATION_UNAVAILABLE_NO_FIX,
    AttendanceStatusKind.LOCATION_UNAVAILABLE_PROVIDER ->
        stringResource(R.string.status_unavailable_title)

    AttendanceStatusKind.OFFICE_NOT_SET -> stringResource(R.string.status_office_not_set_title)
    AttendanceStatusKind.OUT_OF_RANGE -> stringResource(R.string.status_out_of_range_title)
    AttendanceStatusKind.READY_TO_MARK -> stringResource(R.string.status_ready_title)
    AttendanceStatusKind.ATTENDANCE_MARKED -> stringResource(R.string.status_marked_title)
}

@Composable
private fun statusBody(
    kind: AttendanceStatusKind,
    radiusMeters: Int,
    distanceText: String?,
    markedAtText: String?
): String = when (kind) {
    AttendanceStatusKind.PERMISSION_REQUIRED -> stringResource(R.string.status_permission_body)
    AttendanceStatusKind.PERMISSION_BLOCKED ->
        stringResource(R.string.status_permission_body_settings)

    AttendanceStatusKind.PRECISE_REQUIRED,
    AttendanceStatusKind.PRECISE_BLOCKED ->
        stringResource(R.string.status_precise_body, radiusMeters)

    AttendanceStatusKind.SERVICES_DISABLED -> stringResource(R.string.status_services_body)
    AttendanceStatusKind.ACQUIRING_FIX -> stringResource(R.string.status_acquiring_body)

    AttendanceStatusKind.LOCATION_UNAVAILABLE_NO_FIX ->
        stringResource(R.string.status_unavailable_body_no_fix)

    AttendanceStatusKind.LOCATION_UNAVAILABLE_PROVIDER ->
        stringResource(R.string.status_unavailable_body_provider)

    AttendanceStatusKind.OFFICE_NOT_SET -> stringResource(R.string.status_office_not_set_body)

    AttendanceStatusKind.OUT_OF_RANGE ->
        stringResource(R.string.status_out_of_range_body, distanceText.orEmpty(), radiusMeters)

    AttendanceStatusKind.READY_TO_MARK ->
        stringResource(R.string.status_ready_body, distanceText.orEmpty(), radiusMeters)

    AttendanceStatusKind.ATTENDANCE_MARKED ->
        stringResource(R.string.status_marked_body, markedAtText.orEmpty())
}

private fun statusIcon(kind: AttendanceStatusKind): Int? = when (kind) {
    AttendanceStatusKind.PERMISSION_REQUIRED,
    AttendanceStatusKind.PERMISSION_BLOCKED -> R.drawable.ic_lock

    AttendanceStatusKind.PRECISE_REQUIRED,
    AttendanceStatusKind.PRECISE_BLOCKED -> R.drawable.ic_crosshair

    AttendanceStatusKind.SERVICES_DISABLED -> R.drawable.ic_crosshair_off

    // The spinner takes the icon slot instead.
    AttendanceStatusKind.ACQUIRING_FIX -> null

    AttendanceStatusKind.LOCATION_UNAVAILABLE_NO_FIX,
    AttendanceStatusKind.LOCATION_UNAVAILABLE_PROVIDER -> R.drawable.ic_alert

    AttendanceStatusKind.OFFICE_NOT_SET,
    AttendanceStatusKind.OUT_OF_RANGE -> R.drawable.ic_pin

    AttendanceStatusKind.READY_TO_MARK,
    AttendanceStatusKind.ATTENDANCE_MARKED -> R.drawable.ic_check_circle
}

/**
 * The action's label is the action *plus* what it is for: re-prompting after an
 * approximate-only grant asks for precise location, not for access the user has already given.
 */
@Composable
private fun statusActionLabel(kind: AttendanceStatusKind, action: StatusAction): String =
    when (action) {
        StatusAction.REQUEST_PERMISSION -> if (kind == AttendanceStatusKind.PRECISE_REQUIRED) {
            stringResource(R.string.status_precise_action)
        } else {
            stringResource(R.string.status_permission_action)
        }

        StatusAction.OPEN_APPLICATION_SETTINGS ->
            stringResource(R.string.status_permission_action_settings)

        StatusAction.OPEN_LOCATION_SETTINGS -> stringResource(R.string.status_services_action)
    }

/** Container/on-container pair for a tone, so contrast is guaranteed in both themes. */
private data class ToneColors(val container: Color, val onContainer: Color)

@Composable
private fun statusToneColors(tone: StatusTone): ToneColors {
    val colorScheme = MaterialTheme.colorScheme
    val statusColors = AttendanceTheme.statusColors
    return when (tone) {
        StatusTone.INFO -> ToneColors(
            colorScheme.primaryContainer,
            colorScheme.onPrimaryContainer
        )

        StatusTone.PROGRESS -> ToneColors(
            colorScheme.secondaryContainer,
            colorScheme.onSecondaryContainer
        )

        StatusTone.ATTENTION -> ToneColors(
            statusColors.warningContainer,
            statusColors.onWarningContainer
        )

        StatusTone.BLOCKED -> ToneColors(
            colorScheme.errorContainer,
            colorScheme.onErrorContainer
        )

        StatusTone.SUCCESS -> ToneColors(
            statusColors.successContainer,
            statusColors.onSuccessContainer
        )
    }
}

private const val TONE_TRANSITION_MILLIS = 400
