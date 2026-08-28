package io.github.rktuhinbd.presencelens.attendance.presentation.attendance.components

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * The one shape every condition is rendered in: a tinted badge, a title, an explanation, and
 * at most one action (GEN-04).
 *
 * A single banner rather than a per-state layout is deliberate - it means "location is off",
 * "you are 220 m away", and "attendance marked" arrive with identical weight and structure, so
 * the user reads the difference in the words and the tone instead of re-learning the screen
 * each time.
 */
@Composable
fun StatusBanner(
    title: String,
    body: String,
    containerColor: Color,
    contentColor: Color,
    modifier: Modifier = Modifier,
    iconResId: Int? = null,
    showProgress: Boolean = false,
    actionLabel: String? = null,
    actionIconResId: Int? = null,
    onAction: (() -> Unit)? = null
) {
    val hasAction = actionLabel != null && onAction != null

    Surface(
        modifier = modifier,
        shape = MaterialTheme.shapes.large,
        color = containerColor,
        contentColor = contentColor
    ) {
        Row(
            modifier = Modifier.padding(
                start = 16.dp,
                top = 16.dp,
                end = 16.dp,
                // A TextButton carries its own 48 dp touch target, which already supplies the
                // bottom breathing room; without one the padding has to be drawn here.
                bottom = if (hasAction) 6.dp else 16.dp
            ),
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            // The badge is what lifts this above a flat coloured strip: the icon sits on its
            // own tonal disc, so the leading edge reads as a considered element rather than a
            // glyph floating in a box.
            Box(
                modifier = Modifier
                    .size(BADGE_SIZE_DP.dp)
                    .background(contentColor.copy(alpha = 0.12f), CircleShape),
                contentAlignment = Alignment.Center
            ) {
                when {
                    showProgress -> CircularProgressIndicator(
                        modifier = Modifier.size(18.dp),
                        color = contentColor,
                        strokeWidth = 2.dp
                    )

                    iconResId != null -> Icon(
                        painter = painterResource(iconResId),
                        // The title immediately beside it says the same thing; announcing the
                        // icon as well would just read the state twice.
                        contentDescription = null,
                        modifier = Modifier.size(20.dp)
                    )
                }
            }

            Column(
                modifier = Modifier.padding(top = 2.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text(text = title, style = MaterialTheme.typography.titleMedium)
                Text(
                    text = body,
                    style = MaterialTheme.typography.bodyMedium,
                    color = contentColor.copy(alpha = 0.82f)
                )

                if (hasAction) {
                    TextButton(
                        onClick = onAction,
                        // Keeps the tap target at the 48 dp minimum even though the label sits
                        // flush with the body text above it.
                        modifier = Modifier.defaultMinSize(minHeight = 48.dp),
                        contentPadding = ButtonDefaults.TextButtonContentPadding,
                        colors = ButtonDefaults.textButtonColors(contentColor = contentColor)
                    ) {
                        if (actionIconResId != null) {
                            Icon(
                                painter = painterResource(actionIconResId),
                                contentDescription = null,
                                modifier = Modifier
                                    .size(18.dp)
                                    .clearAndSetSemantics { }
                            )
                        }
                        Text(
                            text = actionLabel,
                            modifier = Modifier.padding(
                                start = if (actionIconResId != null) 8.dp else 0.dp
                            ),
                            style = MaterialTheme.typography.labelLarge
                        )
                    }
                }
            }
        }
    }
}

/**
 * A small filled dot signalling a binary state (AND-14).
 *
 * It carries its own [contentDescription] because colour is the only thing distinguishing set
 * from not-set, and colour alone is not an accessible signal.
 */
@Composable
fun StatusDot(
    color: Color,
    contentDescription: String,
    modifier: Modifier = Modifier,
    size: Dp = 8.dp
) {
    val animatedColor by animateColorAsState(targetValue = color, label = "statusDotColor")
    Box(
        modifier = modifier
            .size(size)
            .background(color = animatedColor, shape = CircleShape)
            .semantics { this.contentDescription = contentDescription }
    )
}

private const val BADGE_SIZE_DP = 36
