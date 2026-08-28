package io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.windowInsetsBottomHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import io.github.rktuhinbd.presencelens.attendance.R

/**
 * Progressive disclosure for the questions this screen otherwise leaves unanswered: where the
 * office coordinates go, when location is read, what the radius actually gates, and whether
 * anything runs in the background.
 *
 * A bottom sheet rather than a second destination, deliberately. The assessment specifies one
 * screen (AND-04); this is a surface over that screen, not a place the user navigates to, and
 * it can be dismissed straight back to where they were.
 *
 * The claims here are load-bearing, not marketing. Each one is a property the implementation
 * actually has - foreground-only updates bound to the resumed lifecycle (ADR-001), DataStore
 * on the device with no network layer (ADR-002), distance as the sole gate (ADR-011). If one
 * ever stops being true, the sentence has to change with it.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HowAttendanceWorksSheet(
    radiusMeters: Int,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    ModalBottomSheet(
        onDismissRequest = onDismiss,
        modifier = modifier,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = MaterialTheme.colorScheme.surfaceContainerLow
    ) {
        HowAttendanceWorksContent(radiusMeters = radiusMeters, onDismiss = onDismiss)
    }
}

/** The sheet's body, split out so it can be previewed and read without a sheet host. */
@Composable
fun HowAttendanceWorksContent(
    radiusMeters: Int,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 24.dp)
    ) {
        Text(
            text = stringResource(R.string.how_it_works_title),
            style = MaterialTheme.typography.headlineSmall,
            color = MaterialTheme.colorScheme.onSurface
        )
        Text(
            text = stringResource(R.string.how_it_works_subtitle),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 6.dp)
        )

        Column(
            modifier = Modifier.padding(top = 24.dp),
            verticalArrangement = Arrangement.spacedBy(20.dp)
        ) {
            DisclosureRow(
                iconResId = R.drawable.ic_device_lock,
                title = stringResource(R.string.how_it_works_storage_title),
                body = stringResource(R.string.how_it_works_storage_body)
            )
            DisclosureRow(
                iconResId = R.drawable.ic_crosshair,
                title = stringResource(R.string.how_it_works_tracking_title),
                body = stringResource(R.string.how_it_works_tracking_body)
            )
            DisclosureRow(
                iconResId = R.drawable.ic_pin,
                title = stringResource(R.string.how_it_works_radius_title, radiusMeters),
                body = stringResource(R.string.how_it_works_radius_body, radiusMeters)
            )
            DisclosureRow(
                iconResId = R.drawable.ic_lock,
                title = stringResource(R.string.how_it_works_background_title),
                body = stringResource(R.string.how_it_works_background_body)
            )
        }

        HorizontalDivider(
            modifier = Modifier.padding(top = 24.dp),
            color = MaterialTheme.colorScheme.outlineVariant
        )

        Text(
            text = stringResource(R.string.how_it_works_footnote),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 16.dp)
        )

        TextButton(
            onClick = onDismiss,
            modifier = Modifier
                .align(Alignment.End)
                .padding(top = 8.dp)
                .heightIn(min = MIN_TOUCH_TARGET_DP.dp)
        ) {
            Text(
                text = stringResource(R.string.how_it_works_dismiss),
                style = MaterialTheme.typography.labelLarge
            )
        }

        Box(modifier = Modifier.windowInsetsBottomHeight(WindowInsets.navigationBars))
    }
}

@Composable
private fun DisclosureRow(
    iconResId: Int,
    title: String,
    body: String,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Box(
            modifier = Modifier
                .size(BADGE_SIZE_DP.dp)
                .background(MaterialTheme.colorScheme.secondaryContainer, CircleShape),
            contentAlignment = Alignment.Center
        ) {
            Icon(
                painter = painterResource(iconResId),
                // The title beside it carries the meaning; the badge is decoration.
                contentDescription = null,
                tint = MaterialTheme.colorScheme.onSecondaryContainer,
                modifier = Modifier.size(20.dp)
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleSmall,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = body,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

private const val BADGE_SIZE_DP = 40
private const val MIN_TOUCH_TARGET_DP = 48
