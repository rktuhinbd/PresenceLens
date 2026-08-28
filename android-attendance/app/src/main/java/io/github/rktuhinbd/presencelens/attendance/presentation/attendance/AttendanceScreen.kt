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
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import io.github.rktuhinbd.presencelens.attendance.AttendanceComponent
import io.github.rktuhinbd.presencelens.attendance.R
import io.github.rktuhinbd.presencelens.attendance.domain.attendance.AttendanceRule
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationFailureCause
import io.github.rktuhinbd.presencelens.attendance.domain.location.LocationQuality
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components.AttendanceActionPanel
import io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components.DistanceGauge
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
    val messageText = messageText(state.message)

    LaunchedEffect(state.message) {
        if (state.message != null && messageText != null) {
            snackbarHostState.showSnackbar(message = messageText)
            onMessageShown()
        }
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
                .padding(horizontal = 20.dp)
                .padding(top = 4.dp, bottom = 32.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            AttendanceStatusBanner(
                state = state,
                canRequestPermissionInApp = canRequestPermissionInApp,
                onRequestPermission = onRequestPermission,
                onOpenApplicationSettings = onOpenApplicationSettings,
                onOpenLocationSettings = onOpenLocationSettings
            )

            OfficeContextCard(
                state = state,
                onSetOfficeLocation = onSetOfficeLocation
            )

            ProximityCard(state = state)

            AttendanceActionPanel(
                enabled = state.canMarkAttendance,
                onMarkAttendance = onMarkAttendance
            )
        }
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
                .padding(horizontal = 20.dp, vertical = 24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp)
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
                    verticalArrangement = Arrangement.spacedBy(14.dp)
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
 * One banner per condition (GEN-04). Every branch of [AttendanceStatus] is handled, and the
 * only one that renders nothing is a healthy [AttendanceStatus.Tracking] with a trustworthy
 * fix - which is exactly the case where the screen already says everything on its own.
 */
@Composable
private fun AttendanceStatusBanner(
    state: AttendanceUiState,
    canRequestPermissionInApp: Boolean,
    onRequestPermission: () -> Unit,
    onOpenApplicationSettings: () -> Unit,
    onOpenLocationSettings: () -> Unit,
    modifier: Modifier = Modifier
) {
    val colorScheme = MaterialTheme.colorScheme
    val statusColors = AttendanceTheme.statusColors
    val radiusMeters = AttendanceRule.ELIGIBLE_RADIUS_METERS.toInt()

    when (val status = state.status) {
        AttendanceStatus.PermissionRequired -> StatusBanner(
            modifier = modifier.fillMaxWidth(),
            title = stringResource(R.string.status_permission_title),
            body = stringResource(
                if (canRequestPermissionInApp) {
                    R.string.status_permission_body
                } else {
                    R.string.status_permission_body_settings
                }
            ),
            containerColor = statusColors.warningContainer,
            contentColor = statusColors.onWarningContainer,
            iconResId = R.drawable.ic_lock,
            actionLabel = stringResource(
                if (canRequestPermissionInApp) {
                    R.string.status_permission_action
                } else {
                    R.string.status_permission_action_settings
                }
            ),
            actionIconResId = if (canRequestPermissionInApp) null else R.drawable.ic_open_in_new,
            onAction = if (canRequestPermissionInApp) onRequestPermission else onOpenApplicationSettings
        )

        AttendanceStatus.PreciseLocationRequired -> StatusBanner(
            modifier = modifier.fillMaxWidth(),
            title = stringResource(R.string.status_precise_title),
            body = stringResource(R.string.status_precise_body, radiusMeters),
            containerColor = statusColors.warningContainer,
            contentColor = statusColors.onWarningContainer,
            iconResId = R.drawable.ic_crosshair,
            actionLabel = stringResource(
                if (canRequestPermissionInApp) {
                    R.string.status_precise_action
                } else {
                    R.string.status_permission_action_settings
                }
            ),
            actionIconResId = if (canRequestPermissionInApp) null else R.drawable.ic_open_in_new,
            onAction = if (canRequestPermissionInApp) onRequestPermission else onOpenApplicationSettings
        )

        AttendanceStatus.LocationServicesDisabled -> StatusBanner(
            modifier = modifier.fillMaxWidth(),
            title = stringResource(R.string.status_services_title),
            body = stringResource(R.string.status_services_body),
            containerColor = statusColors.warningContainer,
            contentColor = statusColors.onWarningContainer,
            iconResId = R.drawable.ic_crosshair_off,
            actionLabel = stringResource(R.string.status_services_action),
            actionIconResId = R.drawable.ic_open_in_new,
            onAction = onOpenLocationSettings
        )

        AttendanceStatus.AcquiringFix -> StatusBanner(
            modifier = modifier.fillMaxWidth(),
            title = stringResource(R.string.status_acquiring_title),
            body = stringResource(R.string.status_acquiring_body),
            containerColor = colorScheme.secondaryContainer,
            contentColor = colorScheme.onSecondaryContainer,
            showProgress = true
        )

        is AttendanceStatus.LocationUnavailable -> StatusBanner(
            modifier = modifier.fillMaxWidth(),
            title = stringResource(R.string.status_unavailable_title),
            body = stringResource(
                when (status.cause) {
                    LocationFailureCause.NO_FIX_AVAILABLE -> R.string.status_unavailable_body_no_fix
                    LocationFailureCause.PROVIDER_ERROR -> R.string.status_unavailable_body_provider
                }
            ),
            containerColor = colorScheme.errorContainer,
            contentColor = colorScheme.onErrorContainer,
            iconResId = R.drawable.ic_alert
        )

        AttendanceStatus.OfficeNotSet -> StatusBanner(
            modifier = modifier.fillMaxWidth(),
            title = stringResource(R.string.status_office_not_set_title),
            body = stringResource(R.string.status_office_not_set_body),
            containerColor = colorScheme.primaryContainer,
            contentColor = colorScheme.onPrimaryContainer,
            iconResId = R.drawable.ic_pin
        )

        is AttendanceStatus.Tracking -> DegradedAccuracyNotice(
            state = state,
            modifier = modifier.fillMaxWidth()
        )
    }
}

/**
 * A caution, never a refusal (AMB-14). A wide error radius means the distance on screen could
 * be wrong by roughly that much, which the user deserves to know - but AND-08 names distance
 * as the only condition for marking attendance, so this never disables anything.
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
            modifier = modifier,
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

/** Resolves the one-shot message to display text while still in composition. */
@Composable
private fun messageText(message: AttendanceMessage?): String? = when (message) {
    null -> null
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

    is AttendanceMessage.AttendanceMarked -> stringResource(
        R.string.snackbar_attendance_marked,
        DistanceFormatter.format(message.distanceMeters)
    )
}
