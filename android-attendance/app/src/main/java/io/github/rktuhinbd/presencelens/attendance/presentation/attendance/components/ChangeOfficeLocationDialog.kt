package io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components

import androidx.compose.foundation.layout.size
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import io.github.rktuhinbd.presencelens.attendance.R

/**
 * Guards the one destructive action on this screen.
 *
 * Capturing an office location the first time is additive and needs no ceremony. Capturing it
 * *again* silently discards a saved coordinate the user may have walked to the office to
 * record, and every later distance is measured from the new point - so the dialog states the
 * coordinates being replaced rather than asking an abstract "are you sure?".
 *
 * The confirm action is worded as what it does ("Replace with current location"), and the
 * dismiss action as what it preserves, so neither button can be pressed by reflex.
 */
@Composable
fun ChangeOfficeLocationDialog(
    currentOfficeCoordinates: String,
    onConfirm: () -> Unit,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        modifier = modifier,
        icon = {
            Icon(
                painter = painterResource(R.drawable.ic_swap),
                contentDescription = null,
                modifier = Modifier.size(24.dp)
            )
        },
        title = {
            Text(
                text = stringResource(R.string.change_office_dialog_title),
                style = MaterialTheme.typography.headlineSmall
            )
        },
        text = {
            Text(
                text = stringResource(
                    R.string.change_office_dialog_body,
                    currentOfficeCoordinates
                ),
                style = MaterialTheme.typography.bodyMedium
            )
        },
        confirmButton = {
            TextButton(onClick = onConfirm) {
                Text(
                    text = stringResource(R.string.change_office_dialog_confirm),
                    style = MaterialTheme.typography.labelLarge
                )
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(
                    text = stringResource(R.string.change_office_dialog_cancel),
                    style = MaterialTheme.typography.labelLarge
                )
            }
        },
        shape = MaterialTheme.shapes.large,
        containerColor = MaterialTheme.colorScheme.surfaceContainerHigh
    )
}
