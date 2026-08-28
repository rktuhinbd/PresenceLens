package io.github.rktuhinbd.presencelens.attendance.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * A deliberate Material 3 palette rather than the project-template purple (ADR-012).
 *
 * A restrained indigo carries the primary actions, a teal accent marks "captured office
 * context", and the neutral family is kept close to true grey so the tonal surfaces read as
 * depth rather than as tint. Status colour is defined separately in [StatusColors] because
 * Material 3 has no success or warning role.
 */

// ---------------------------------------------------------------- light
internal val PrimaryLight = Color(0xFF2E4FC4)
internal val OnPrimaryLight = Color(0xFFFFFFFF)
internal val PrimaryContainerLight = Color(0xFFDDE1FF)
internal val OnPrimaryContainerLight = Color(0xFF001551)
internal val SecondaryLight = Color(0xFF5A5D72)
internal val OnSecondaryLight = Color(0xFFFFFFFF)
internal val SecondaryContainerLight = Color(0xFFDFE1F9)
internal val OnSecondaryContainerLight = Color(0xFF171B2C)
internal val TertiaryLight = Color(0xFF00696B)
internal val OnTertiaryLight = Color(0xFFFFFFFF)
internal val TertiaryContainerLight = Color(0xFFB2ECEC)
internal val OnTertiaryContainerLight = Color(0xFF002020)
internal val ErrorLight = Color(0xFFBA1A1A)
internal val OnErrorLight = Color(0xFFFFFFFF)
internal val ErrorContainerLight = Color(0xFFFFDAD6)
internal val OnErrorContainerLight = Color(0xFF410002)
internal val BackgroundLight = Color(0xFFFBF8FF)
internal val OnBackgroundLight = Color(0xFF1A1B21)
internal val SurfaceLight = Color(0xFFFBF8FF)
internal val OnSurfaceLight = Color(0xFF1A1B21)
internal val SurfaceVariantLight = Color(0xFFE2E1EC)
internal val OnSurfaceVariantLight = Color(0xFF45464F)
internal val OutlineLight = Color(0xFF767680)
internal val OutlineVariantLight = Color(0xFFC6C5D0)
internal val SurfaceContainerLowestLight = Color(0xFFFFFFFF)
internal val SurfaceContainerLowLight = Color(0xFFF5F2FA)
internal val SurfaceContainerLight = Color(0xFFEFEDF4)
internal val SurfaceContainerHighLight = Color(0xFFE9E7EF)
internal val SurfaceContainerHighestLight = Color(0xFFE3E2E9)
internal val InverseSurfaceLight = Color(0xFF2F3036)
internal val InverseOnSurfaceLight = Color(0xFFF2F0F7)
internal val InversePrimaryLight = Color(0xFFB9C3FF)

// ---------------------------------------------------------------- dark
internal val PrimaryDark = Color(0xFFB9C3FF)
internal val OnPrimaryDark = Color(0xFF002585)
internal val PrimaryContainerDark = Color(0xFF1739AC)
internal val OnPrimaryContainerDark = Color(0xFFDDE1FF)
internal val SecondaryDark = Color(0xFFC3C5DD)
internal val OnSecondaryDark = Color(0xFF2C2F42)
internal val SecondaryContainerDark = Color(0xFF424659)
internal val OnSecondaryContainerDark = Color(0xFFDFE1F9)
internal val TertiaryDark = Color(0xFF4CD9DB)
internal val OnTertiaryDark = Color(0xFF003737)
internal val TertiaryContainerDark = Color(0xFF004F51)
internal val OnTertiaryContainerDark = Color(0xFFB2ECEC)
internal val ErrorDark = Color(0xFFFFB4AB)
internal val OnErrorDark = Color(0xFF690005)
/**
 * Deeper and less saturated than the Material baseline dark `errorContainer` (`0xFF93000A`).
 * "Out of range" is a routine condition on this screen, not a fault, and at baseline saturation
 * a full-width card in that role reads as an alarm every time the user is simply not at the
 * office yet. This keeps the role unmistakably red while letting it sit on a dark surface.
 */
internal val ErrorContainerDark = Color(0xFF5B1216)
internal val OnErrorContainerDark = Color(0xFFFFDAD6)
internal val BackgroundDark = Color(0xFF121318)
internal val OnBackgroundDark = Color(0xFFE3E1E9)
internal val SurfaceDark = Color(0xFF121318)
internal val OnSurfaceDark = Color(0xFFE3E1E9)
internal val SurfaceVariantDark = Color(0xFF45464F)
internal val OnSurfaceVariantDark = Color(0xFFC6C5D0)
internal val OutlineDark = Color(0xFF90909A)
internal val OutlineVariantDark = Color(0xFF45464F)
internal val SurfaceContainerLowestDark = Color(0xFF0D0E13)
internal val SurfaceContainerLowDark = Color(0xFF1A1B21)
internal val SurfaceContainerDark = Color(0xFF1E1F25)
internal val SurfaceContainerHighDark = Color(0xFF292A2F)
internal val SurfaceContainerHighestDark = Color(0xFF34343A)
internal val InverseSurfaceDark = Color(0xFFE3E1E9)
internal val InverseOnSurfaceDark = Color(0xFF2F3036)
internal val InversePrimaryDark = Color(0xFF2E4FC4)
