package io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.unit.dp
import io.github.rktuhinbd.presencelens.attendance.ui.theme.OverlineTextStyle

/**
 * The range status chip from the reference (AND-18): "OUT OF RANGE" in error tones, with an
 * in-range counterpart in success tones.
 *
 * It is bound to the same `AttendanceUiState` value as the Mark Attendance button, so it can
 * never contradict what the button is doing. The leading dot is decorative - the label alone
 * carries the meaning, so colour is never the only signal.
 */
@Composable
fun RangeStatusChip(
    label: String,
    containerColor: Color,
    contentColor: Color,
    modifier: Modifier = Modifier
) {
    val animatedContainer by animateColorAsState(
        targetValue = containerColor,
        animationSpec = tween(durationMillis = 400),
        label = "rangeChipContainer"
    )
    val animatedContent by animateColorAsState(
        targetValue = contentColor,
        animationSpec = tween(durationMillis = 400),
        label = "rangeChipContent"
    )

    Surface(
        modifier = modifier,
        shape = CircleShape,
        color = animatedContainer,
        contentColor = animatedContent
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 9.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(7.dp)
                    .background(animatedContent, CircleShape)
                    .clearAndSetSemantics { }
            )
            Text(text = label, style = OverlineTextStyle)
        }
    }
}
