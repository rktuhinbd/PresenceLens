package io.github.rktuhinbd.presencelens.attendance.presentation.attendance

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import io.github.rktuhinbd.presencelens.attendance.AttendanceComponent
import io.github.rktuhinbd.presencelens.attendance.R
import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationQuality
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components.AttendanceActionPanel
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components.AttendanceStatusCard
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components.ChangeOfficeLocationDialog
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components.DistanceGauge
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components.HowAttendanceWorksSheet
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components.OfficeContextCard
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components.RangeStatusChip
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components.StatusBanner
import io.github.rktuhinbd.presencelens.attendance.presentation.permission.openLocationSettings
import io.github.rktuhinbd.presencelens.attendance.presentation.permission.rememberLocationPermissionController
import io.github.rktuhinbd.presencelens.attendance.ui.theme.AttendanceTheme

/**
 * Stateful entry point: owns the ViewModel and the permission plumbing, and hands
 * [AttendanceScreen] a plain state value plus callbacks.
 *
 * The split exists so the screen itself can be composed in a test or a preview with any
 * state, without Play Services, a permission grant, or a live GPS fix.
 */
@Composable
fun AttendanceRoute(
    modifier: Modifier = Modifier,
    onNavigateBack: () -> Unit = {}
) {
    val context = LocalContext.current
    val viewModel: AttendanceViewModel = viewModel(
        factory = remember(context) { AttendanceComponent.viewModelFactory(context) }
    )

    // collectAsStateWithLifecycle is what makes observation lifecycle-aware end to end:
    // collection stops below STARTED, which cancels the ViewModel's WhileSubscribed sharing,
    // which removes the Fused Location callback and the location-mode receiver.
    val state by viewModel.uiState.collectAsStateWithLifecycle()

    val permissionController = rememberLocationPermissionController(
        onStatusChanged = viewModel::onPermissionStatusChanged
    )

    AttendanceScreen(
        state = state,
        canRequestPermissionInApp = permissionController.canRequestInApp,
        onRequestPermission = permissionController::request,
        onOpenApplicationSettings = permissionController::openApplicationSettings,
        onOpenLocationSettings = { context.openLocationSettings() },
        onSetOfficeLocation = viewModel::onSetOfficeLocationClicked,
        onMarkAttendance = viewModel::onMarkAttendanceClicked,
        onMessageShown = viewModel::onMessageShown,
        onNavigateBack = onNavigateBack,
        modifier = modifier
    )
}

/**
 * The attendance screen (AND-03).
 *
 * It hosts both stages on one surface (AND-04): the office setup card, then the attendance
 * status and action. It renders [state] and emits events - it computes no distance, decides
 * no eligibility, and reads no clock.
 *
 * The screen is state-driven rather than uniform. Before an office exists it presents itself
 * as setup: the status card explains what is missing, the office card carries a heading and
 * the one prominent action, and the distance panel - which would be measuring against nothing
 * - is not drawn. Once an office exists the emphasis inverts, and the screen becomes the
 * tracking surface the p2 reference depicts.
 *
 * Layout follows the p2 reference (AND-10, AND-13 to AND-21); the execution quality above
 * that layout is governed by ADR-012.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun AttendanceScreen(
    state: AttendanceUiState,
    canRequestPermissionInApp: Boolean,
    onRequestPermission: () -> Unit,
    onOpenApplicationSettings: () -> Unit,
    onOpenLocationSettings: () -> Unit,
    onSetOfficeLocation: () -> Unit,
    onMarkAttendance: () -> Unit,
    onMessageShown: () -> Unit,
    modifier: Modifier = Modifier,
    onNavigateBack: () -> Unit = {}
) {
    val snackbarHostState = remember { SnackbarHostState() }
    val haptics = LocalHapticFeedback.current
    val messageText = messageText(state.message)
    val radiusMeters = AttendanceRule.ELIGIBLE_RADIUS_METERS

    // Whether a sheet or a dialog is open is ephemeral view state, not application state: it
    // survives rotation through rememberSaveable and dies with the screen, so it has no
    // business in the ViewModel's single source of truth (ADR-006).
    var showHowItWorks by rememberSaveable { mutableStateOf(false) }
    var showChangeOfficeConfirmation by rememberSaveable { mutableStateOf(false) }

    LaunchedEffect(state.message) {
        val message = state.message ?: return@LaunchedEffect
        if (message is AttendanceMessage.AttendanceMarked) {
            // The success is already shown in place, so the confirmation here is physical
            // rather than another surface competing for the same moment.
            haptics.performHapticFeedback(HapticFeedbackType.LongPress)
        } else if (messageText != null) {
            snackbarHostState.showSnackbar(message = messageText)
        }
        onMessageShown()
    }

    Scaffold(
        modifier = modifier,
        containerColor = MaterialTheme.colorScheme.background,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.attendance_title),
                        style = MaterialTheme.typography.titleLarge
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(
                            painter = painterResource(R.drawable.ic_arrow_back),
                            contentDescription = stringResource(R.string.content_description_back)
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { showHowItWorks = true }) {
                        Icon(
                            painter = painterResource(R.drawable.ic_help),
                            contentDescription = stringResource(
                                R.string.content_description_how_it_works
                            )
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.background,
                    titleContentColor = MaterialTheme.colorScheme.onBackground
                )
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp)
                .padding(top = 2.dp, bottom = 24.dp)
        ) {
            // Section spacing is carried by each section's own bottom padding rather than by
            // Arrangement.spacedBy: two of the sections come and go, and spacedBy would leave
            // their gap behind after they collapse.
            AttendanceStatusCard(
                presentation = AttendanceStatusPresenter.present(state, canRequestPermissionInApp),
                radiusMeters = radiusMeters.toInt(),
                modifier = Modifier.padding(bottom = SECTION_GAP_DP.dp),
                distanceText = state.proximity?.let { DistanceFormatter.format(it.distanceMeters) },
                markedAtText = state.attendanceMarkedAtEpochMillis?.let(TimestampFormatter::time),
                onRequestPermission = onRequestPermission,
                onOpenApplicationSettings = onOpenApplicationSettings,
                onOpenLocationSettings = onOpenLocationSettings
            )

            DegradedAccuracyNotice(state = state)

            OfficeContextCard(
                state = state,
                onSetOfficeLocation = onSetOfficeLocation,
                onChangeOfficeLocation = { showChangeOfficeConfirmation = true },
                modifier = Modifier.padding(bottom = SECTION_GAP_DP.dp)
            )

            // A gauge with no office to measure from would be an empty dial the user has to
            // learn to ignore. It arrives with the thing it measures.
            AnimatedVisibility(
                visible = state.office != null,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically()
            ) {
                ProximityCard(state = state, modifier = Modifier.padding(bottom = SECTION_GAP_DP.dp))
            }

            AttendanceActionPanel(
                enabled = state.canMarkAttendance,
                onMarkAttendance = onMarkAttendance,
                blockedReasonText = blockedReasonText(
                    AttendanceStatusPresenter.markAttendanceBlocker(state),
                    radiusMeters.toInt()
                ),
                isMarked = state.attendanceMarkedAtEpochMillis != null
            )
        }
    }

    if (showHowItWorks) {
        HowAttendanceWorksSheet(
            radiusMeters = radiusMeters.toInt(),
            onDismiss = { showHowItWorks = false }
        )
    }

    if (showChangeOfficeConfirmation && state.office != null) {
        val coordinates = state.office.coordinates
        ChangeOfficeLocationDialog(
            currentOfficeCoordinates = stringResource(
                R.string.location_surface_coordinates,
                CoordinateFormatter.latitude(coordinates),
                CoordinateFormatter.longitude(coordinates)
            ),
            onConfirm = {
                showChangeOfficeConfirmation = false
                onSetOfficeLocation()
            },
            onDismiss = { showChangeOfficeConfirmation = false }
        )
    }
}

/** The distance gauge, range chip, live readout, and guidance copy (AND-09, AND-17 to AND-19). */
@Composable
private fun ProximityCard(
    state: AttendanceUiState,
    modifier: Modifier = Modifier
) {
    val colorScheme = MaterialTheme.colorScheme
    val statusColors = AttendanceTheme.statusColors
    val proximity = state.proximity
    val radiusMeters = AttendanceRule.ELIGIBLE_RADIUS_METERS
    val isEligible = state.canMarkAttendance

    Card(
        modifier = modifier.fillMaxWidth(),
        shape = MaterialTheme.shapes.extraLarge,
        colors = CardDefaults.cardColors(containerColor = colorScheme.surfaceContainerLow)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 18.dp, vertical = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            DistanceGauge(
                distanceMeters = proximity?.distanceMeters,
                usageFraction = proximity
                    ?.let { ProximityGeometry.radiusUsageFraction(it.distanceMeters, radiusMeters) }
                    ?: 0f,
                gaugeContentDescription = gaugeContentDescription(proximity?.distanceMeters, radiusMeters),
                awayCaption = stringResource(R.string.distance_away_caption),
                accentColor = when {
                    proximity == null -> colorScheme.outlineVariant
                    isEligible -> statusColors.success
                    else -> colorScheme.error
                }
            )

            AnimatedVisibility(
                visible = proximity != null,
                enter = fadeIn() + expandVertically(),
                exit = fadeOut() + shrinkVertically()
            ) {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    RangeStatusChip(
                        label = stringResource(
                            if (isEligible) R.string.range_status_in else R.string.range_status_out
                        ),
                        containerColor = if (isEligible) {
                            statusColors.successContainer
                        } else {
                            colorScheme.errorContainer
                        },
                        contentColor = if (isEligible) {
                            statusColors.onSuccessContainer
                        } else {
                            colorScheme.onErrorContainer
                        }
                    )

                    // AND-09: the live distance sentence, recomputed on every emission.
                    // Where you are and what to do about it are two short lines rather than
                    // one long one, so neither has to be read to reach the other.
                    Text(
                        text = stringResource(
                            R.string.distance_live_readout,
                            DistanceFormatter.format(proximity?.distanceMeters ?: 0.0)
                        ),
                        style = MaterialTheme.typography.titleMedium,
                        color = colorScheme.onSurface,
                        textAlign = TextAlign.Center
                    )

                    Text(
                        text = if (isEligible) {
                            stringResource(R.string.range_guidance_in)
                        } else {
                            stringResource(R.string.range_guidance_out, radiusMeters.toInt())
                        },
                        style = MaterialTheme.typography.bodyMedium,
                        color = colorScheme.onSurfaceVariant,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
    }
}

/**
 * A caution, never a refusal (AMB-14). A wide error radius means the distance on screen could
 * be wrong by roughly that much, which the user deserves to know - but AND-08 names distance
 * as the only condition for marking attendance, so this never disables anything.
 *
 * It sits below the status card rather than replacing it: accuracy is a qualifier on whatever
 * the screen is already saying, not a state of its own.
 */
@Composable
private fun DegradedAccuracyNotice(
    state: AttendanceUiState,
    modifier: Modifier = Modifier
) {
    val accuracy = state.currentLocation?.accuracyMeters
    val statusColors = AttendanceTheme.statusColors

    AnimatedVisibility(
        visible = state.currentLocation?.quality == LocationQuality.DEGRADED && accuracy != null,
        enter = fadeIn() + expandVertically(),
        exit = fadeOut() + shrinkVertically()
    ) {
        StatusBanner(
            modifier = modifier
                .fillMaxWidth()
                .padding(bottom = SECTION_GAP_DP.dp),
            title = stringResource(R.string.status_degraded_accuracy_title),
            body = stringResource(
                R.string.status_degraded_accuracy,
                DistanceFormatter.format(accuracy ?: 0.0)
            ),
            containerColor = statusColors.warningContainer,
            contentColor = statusColors.onWarningContainer,
            iconResId = R.drawable.ic_alert
        )
    }
}

/** The one-line reason shown beside a disabled Mark Attendance button (AND-20). */
@Composable
private fun blockedReasonText(blocker: MarkAttendanceBlocker?, radiusMeters: Int): String? =
    when (blocker) {
        null -> null
        MarkAttendanceBlocker.OFFICE_NOT_SET ->
            stringResource(R.string.blocked_reason_office_not_set)

        MarkAttendanceBlocker.PERMISSION -> stringResource(R.string.blocked_reason_permission)
        MarkAttendanceBlocker.PRECISE_LOCATION -> stringResource(R.string.blocked_reason_precise)
        MarkAttendanceBlocker.SERVICES_OFF -> stringResource(R.string.blocked_reason_services_off)
        MarkAttendanceBlocker.NO_FIX -> stringResource(R.string.blocked_reason_no_fix)
        MarkAttendanceBlocker.STALE_FIX -> stringResource(R.string.blocked_reason_stale_fix)
        MarkAttendanceBlocker.OUT_OF_RANGE ->
            stringResource(R.string.blocked_reason_out_of_range, radiusMeters)
    }

@Composable
private fun gaugeContentDescription(distanceMeters: Double?, radiusMeters: Double): String =
    if (distanceMeters == null) {
        stringResource(R.string.content_description_distance_gauge_pending)
    } else {
        stringResource(
            R.string.content_description_distance_gauge,
            DistanceFormatter.format(distanceMeters),
            radiusMeters.toInt()
        )
    }

/**
 * Resolves the one-shot message to display text while still in composition.
 *
 * [AttendanceMessage.AttendanceMarked] deliberately has no text: the success is shown in
 * place, on the panel the user just pressed, so a snackbar would be a third confirmation of
 * the same event.
 */
@Composable
private fun messageText(message: AttendanceMessage?): String? = when (message) {
    null, is AttendanceMessage.AttendanceMarked -> null

    is AttendanceMessage.OfficeLocationSaved -> stringResource(
        R.string.snackbar_office_saved,
        CoordinateFormatter.latitude(message.coordinates),
        CoordinateFormatter.longitude(message.coordinates)
    )

    AttendanceMessage.OfficeLocationSaveFailed ->
        stringResource(R.string.snackbar_office_save_failed)

    AttendanceMessage.OfficeLocationCaptureFailed ->
        stringResource(R.string.snackbar_office_capture_failed)

    AttendanceMessage.LocationPermissionMissing ->
        stringResource(R.string.snackbar_permission_missing)
}

/** The vertical rhythm between the screen's four sections. */
private const val SECTION_GAP_DP = 12
