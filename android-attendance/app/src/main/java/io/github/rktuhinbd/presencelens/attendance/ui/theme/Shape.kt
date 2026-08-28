package io.github.rktuhinbd.presencelens.attendance.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Shapes
import androidx.compose.ui.unit.dp

/**
 * A slightly more generous corner scale than the Material defaults (ADR-012).
 *
 * The screen stacks several large containers - location surface, distance panel, locked
 * attendance region - and at default radii those read as boxes. The larger `large` and
 * `extraLarge` steps let the cards sit as soft panels while the small steps stay tight
 * enough for chips and pills to keep their shape.
 */
val Shapes = Shapes(
    extraSmall = RoundedCornerShape(8.dp),
    small = RoundedCornerShape(12.dp),
    medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(24.dp),
    extraLarge = RoundedCornerShape(32.dp)
)
