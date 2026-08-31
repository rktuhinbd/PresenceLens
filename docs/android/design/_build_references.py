"""Post-implementation UI reference generator - Native Android (Gate B2).

Renders docs/android/design/*.html directly from the shipped Compose source:

  android-attendance/app/src/main/java/.../attendance/presentation/attendance/**
  android-attendance/app/src/main/java/.../attendance/ui/theme/**
  android-attendance/app/src/main/res/values/strings.xml
  android-attendance/app/src/main/res/drawable/*.xml

Authority order for every value this script emits (highest first):

  1. the shipped Compose source (read at generation time where practical -
     strings.xml and the vector drawables are parsed, not retyped)
  2. the verified v1.0.0 runtime screenshot, docs/assets/android/attendance-ready.png
  3. docs/android/UX_SPEC.md
  4. this generated HTML

The application is never edited to match this file. This file is edited to match the
application. Regenerate with:

    python docs/android/design/_build_references.py

Nothing in the Android build depends on this script's output existing; it is
optional tooling for reviewers, exactly like the historical Flutter prototype
generator it accompanies.
"""

from __future__ import annotations

import hashlib
import math
import pathlib
import re
import xml.etree.ElementTree as ET

HERE = pathlib.Path(__file__).resolve().parent
REPO_ROOT = HERE.parents[2]
APP_SRC = REPO_ROOT / "android-attendance" / "app" / "src" / "main"
STRINGS_XML = APP_SRC / "res" / "values" / "strings.xml"
DRAWABLE_DIR = APP_SRC / "res" / "drawable"

ANDROID_NS = "{http://schemas.android.com/apk/res/android}"

# =============================================================================================
# 1. DEVICE / VIEWPORT GEOMETRY - measured from the six committed v1.0.0 screenshots
# =============================================================================================
# All six PNGs under docs/assets/{android,flutter}/*.png are 1280x2800 physical px at a
# measured density of 3.5 (derived from Android's 18dp screen padding landing at physical
# x=63 on both card edges). That yields a *release-evidence* logical viewport of
# 365.7142857 x 800 CSS px - this is the primary fidelity/validation frame (architect
# correction, Gate B2 section 2). It is deliberately NOT the historical 390x844 frame.
DENSITY = 3.5
RELEASE_WIDTH = 1280 / DENSITY          # 365.7142857...
RELEASE_HEIGHT = 2800 / DENSITY         # 800.0
SAFE_TOP = 141 / DENSITY                # 40.2857... - status bar band, measured
SAFE_BOTTOM = 78 / DENSITY              # 22.2857... - gesture-nav band, measured

# Secondary responsive review frame (historical, retained only as an alternate width for
# eyeballing reflow - never the screenshot-comparison target).
RESPONSIVE_WIDTH = 390
RESPONSIVE_HEIGHT = 844

SCREEN_PAD_H = 18
CARD_PAD_H = 18
CARD_PAD_V = 16
SECTION_GAP = 12
SURFACE_HEIGHT = 190
SURFACE_WIDTH = RELEASE_WIDTH - 2 * SCREEN_PAD_H - 2 * CARD_PAD_H   # 293.7142857..., matches
                                                                     # the measured screenshot
                                                                     # width exactly (293.71dp)
GAUGE_SIZE = 136
GAUGE_STROKE = 10
PRIMARY_BUTTON_HEIGHT = 56
MIN_TOUCH_TARGET = 48
CONFIRMATION_BADGE = 32
BADGE_SIZE = 36
RADIUS_METERS = 50  # AttendanceRule.ELIGIBLE_RADIUS_METERS.toInt()

# =============================================================================================
# 2. STRINGS - parsed from strings.xml, never hand-transcribed
# =============================================================================================


def parse_strings(path: pathlib.Path) -> dict[str, str]:
    tree = ET.parse(path)
    out: dict[str, str] = {}
    for node in tree.getroot().findall("string"):
        name = node.get("name")
        text = "".join(node.itertext())
        # Android XML escapes an apostrophe/quote as \' / \" inside a <string>; XML entities
        # (&amp; etc.) are already resolved by ElementTree.
        text = text.replace("\\'", "’" if False else "'").replace('\\"', '"')
        out[name] = text
    return out


STRINGS = parse_strings(STRINGS_XML)


def S(key: str, *args) -> str:
    """Android string-resource substitution: %1$s, %2$d, ... in declaration order."""
    template = STRINGS[key]

    def repl(match: re.Match) -> str:
        idx = int(match.group(1)) - 1
        return str(args[idx])

    return re.sub(r"%(\d)\$[sd]", repl, template)


def esc(text: str) -> str:
    return (
        text.replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
        .replace('"', "&quot;")
    )


# =============================================================================================
# 3. ICONS - the project's own stroked vector drawables, converted verbatim
# =============================================================================================


def parse_vector(name: str) -> dict:
    tree = ET.parse(DRAWABLE_DIR / f"{name}.xml")
    root = tree.getroot()
    path = root.find("path")
    return {
        "vw": float(root.get(f"{ANDROID_NS}viewportWidth")),
        "vh": float(root.get(f"{ANDROID_NS}viewportHeight")),
        "d": path.get(f"{ANDROID_NS}pathData"),
        "stroke_width": path.get(f"{ANDROID_NS}strokeWidth"),
        "cap": path.get(f"{ANDROID_NS}strokeLineCap"),
        "join": path.get(f"{ANDROID_NS}strokeLineJoin"),
    }


ICON_NAMES = [
    "ic_alert", "ic_arrow_back", "ic_check_circle", "ic_clock", "ic_crosshair",
    "ic_crosshair_off", "ic_device_lock", "ic_help", "ic_info", "ic_lock",
    "ic_open_in_new", "ic_pin", "ic_swap",
]
ICONS = {name: parse_vector(name) for name in ICON_NAMES}


def icon_svg(name: str, size: float = 24, color_var: str = "currentColor") -> str:
    ic = ICONS[name]
    color = color_var if color_var == "currentColor" else f"var({color_var})"
    return (
        f'<svg width="{size:g}" height="{size:g}" viewBox="0 0 {ic["vw"]:g} {ic["vh"]:g}" '
        f'fill="none" aria-hidden="true" focusable="false">'
        f'<path d="{ic["d"]}" style="stroke:{color};stroke-width:{ic["stroke_width"]};'
        f'stroke-linecap:{ic["cap"]};stroke-linejoin:{ic["join"]}"/></svg>'
    )


# =============================================================================================
# 4. COLOUR TOKENS - Color.kt + StatusColors.kt, transcribed literal-for-literal
# =============================================================================================

COLORS_LIGHT = {
    "primary": "#2E4FC4", "on-primary": "#FFFFFF",
    "primary-container": "#DDE1FF", "on-primary-container": "#001551",
    "secondary": "#5A5D72", "on-secondary": "#FFFFFF",
    "secondary-container": "#DFE1F9", "on-secondary-container": "#171B2C",
    "tertiary": "#00696B", "on-tertiary": "#FFFFFF",
    "tertiary-container": "#B2ECEC", "on-tertiary-container": "#002020",
    "error": "#BA1A1A", "on-error": "#FFFFFF",
    "error-container": "#FFDAD6", "on-error-container": "#410002",
    "background": "#FBF8FF", "on-background": "#1A1B21",
    "surface": "#FBF8FF", "on-surface": "#1A1B21",
    "surface-variant": "#E2E1EC", "on-surface-variant": "#45464F",
    "outline": "#767680", "outline-variant": "#C6C5D0",
    "surface-container-lowest": "#FFFFFF", "surface-container-low": "#F5F2FA",
    "surface-container": "#EFEDF4", "surface-container-high": "#E9E7EF",
    "surface-container-highest": "#E3E2E9",
    "inverse-surface": "#2F3036", "inverse-on-surface": "#F2F0F7",
    "inverse-primary": "#B9C3FF",
    # StatusColors.kt LightStatusColors
    "success": "#146C43", "on-success": "#FFFFFF",
    "success-container": "#C5F0D4", "on-success-container": "#00210E",
    "warning": "#8B5000", "on-warning": "#FFFFFF",
    "warning-container": "#FFDDB8", "on-warning-container": "#2C1600",
}

COLORS_DARK = {
    "primary": "#B9C3FF", "on-primary": "#002585",
    "primary-container": "#1739AC", "on-primary-container": "#DDE1FF",
    "secondary": "#C3C5DD", "on-secondary": "#2C2F42",
    "secondary-container": "#424659", "on-secondary-container": "#DFE1F9",
    "tertiary": "#4CD9DB", "on-tertiary": "#003737",
    "tertiary-container": "#004F51", "on-tertiary-container": "#B2ECEC",
    "error": "#FFB4AB", "on-error": "#690005",
    # NOT the Material baseline #93000A - Color.kt:69 deliberately deepens this so "out of
    # range" (a routine condition here, not a fault) does not read as an alarm on a dark
    # surface. Reproduced exactly.
    "error-container": "#5B1216", "on-error-container": "#FFDAD6",
    "background": "#121318", "on-background": "#E3E1E9",
    "surface": "#121318", "on-surface": "#E3E1E9",
    "surface-variant": "#45464F", "on-surface-variant": "#C6C5D0",
    "outline": "#90909A", "outline-variant": "#45464F",
    "surface-container-lowest": "#0D0E13", "surface-container-low": "#1A1B21",
    "surface-container": "#1E1F25", "surface-container-high": "#292A2F",
    "surface-container-highest": "#34343A",
    "inverse-surface": "#E3E1E9", "inverse-on-surface": "#2F3036",
    "inverse-primary": "#2E4FC4",
    # StatusColors.kt DarkStatusColors
    "success": "#7FD8A0", "on-success": "#00391C",
    "success-container": "#005329", "on-success-container": "#C5F0D4",
    "warning": "#FFB871", "on-warning": "#4A2800",
    "warning-container": "#6A3C00", "on-warning-container": "#FFDDB8",
}

# Shape.kt
SHAPES = {"extra-small": 8, "small": 12, "medium": 16, "large": 24, "extra-large": 32}

# Type.kt - (size-px, line-height-px, weight, letter-spacing-px). Compose sp == CSS px at the
# device's default font scale, which is what a review reference should assume.
TYPE = {
    "display-small": (36, 44, 500, -0.5),
    "headline-small": (24, 32, 600, -0.2),
    "title-large": (20, 28, 600, 0.0),
    "title-medium": (16, 24, 600, 0.1),
    "title-small": (14, 20, 500, 0.1),
    "body-medium": (14, 21, 400, 0.2),
    "body-small": (12, 18, 400, 0.3),
    "label-large": (14, 20, 600, 0.3),
    "label-medium": (12, 16, 600, 0.6),
    "overline": (11, 16, 700, 1.4),
}

TONE_ROLES = {
    "INFO": ("primary-container", "on-primary-container"),
    "PROGRESS": ("secondary-container", "on-secondary-container"),
    "ATTENTION": ("warning-container", "on-warning-container"),
    "BLOCKED": ("error-container", "on-error-container"),
    "SUCCESS": ("success-container", "on-success-container"),
}

# =============================================================================================
# 5. GEOMETRY HELPERS - mirror ProximityGeometry.kt and DistanceGauge.kt's arc maths exactly
# =============================================================================================


def radius_usage_fraction(distance_m: float | None, radius_m: float = RADIUS_METERS) -> float:
    """ProximityGeometry.radiusUsageFraction - the gauge's arc fraction, clamped to [0,1]."""
    if distance_m is None or radius_m <= 0 or distance_m <= 0:
        return 0.0
    return max(0.0, min(1.0, distance_m / radius_m))


def surface_radius_fraction(distance_m: float | None, radius_m: float = RADIUS_METERS) -> float:
    """ProximityGeometry.surfaceRadiusFraction - the plan-view marker's radial fraction,
    which compresses smoothly past 1.0 rather than clamping."""
    if distance_m is None or radius_m <= 0 or distance_m <= 0:
        return 0.0
    ratio = distance_m / radius_m
    if ratio <= 1.0:
        return ratio
    max_outside = 2.25
    falloff = 1.5
    overshoot = (ratio - 1.0) / falloff
    compressed = 1 - math.exp(-overshoot)
    return 1 + compressed * (max_outside - 1)


def format_distance(distance_m: float | None) -> str:
    """DistanceFormatter.format, meters branch only (every reference distance here is < 1km)."""
    if distance_m is None or distance_m <= 0:
        return "0 m"
    return f"{round(distance_m)} m"


def polar(cx: float, cy: float, r: float, angle_deg: float) -> tuple[float, float]:
    rad = math.radians(angle_deg)
    return (cx + r * math.cos(rad), cy + r * math.sin(rad))


def describe_arc(cx: float, cy: float, r: float, start_deg: float, sweep_deg: float) -> str:
    """SVG path for an arc matching Compose's Canvas.drawArc(startAngle, sweepAngle):
    0 degrees = 3 o'clock, positive = clockwise. Capped just under 360 to avoid the
    degenerate zero-length-arc case."""
    sweep_deg = max(-359.9, min(359.9, sweep_deg))
    if abs(sweep_deg) < 0.01:
        return ""
    end_deg = start_deg + sweep_deg
    x1, y1 = polar(cx, cy, r, start_deg)
    x2, y2 = polar(cx, cy, r, end_deg)
    large_arc = 1 if abs(sweep_deg) > 180 else 0
    sweep_flag = 1 if sweep_deg > 0 else 0
    return f"M {x1:.3f} {y1:.3f} A {r:.3f} {r:.3f} 0 {large_arc} {sweep_flag} {x2:.3f} {y2:.3f}"


# =============================================================================================
# 6. SVG COMPONENTS - LocationSurface and DistanceGauge, drawn in production's own order
# =============================================================================================

BOUNDARY_RADIUS_FRACTION = 0.40
GUIDE_RING_MULTIPLES = (0.5, 1.6, 2.25)


def distance_gauge_svg(distance_m: float | None, accent_var: str) -> str:
    """DistanceGauge.kt: a 136x136 ring, 10dp stroke, round caps, starting at -90 degrees."""
    size = GAUGE_SIZE
    stroke = GAUGE_STROKE
    r = (size - stroke) / 2
    c = size / 2
    fraction = radius_usage_fraction(distance_m)
    arc_d = describe_arc(c, c, r, -90, 360 * fraction)
    readout = format_distance(distance_m).split(" ")[0] if distance_m is not None else "—"
    unit = "m" if distance_m is not None else ""
    return f"""<div class="gauge">
  <svg width="{size}" height="{size}" viewBox="0 0 {size} {size}" aria-hidden="true">
    <circle cx="{c}" cy="{c}" r="{r}" style="fill:none;stroke:var(--surface-container-highest);stroke-width:{stroke};stroke-linecap:round"/>
    {f'<path d="{arc_d}" style="fill:none;stroke:var({accent_var});stroke-width:{stroke};stroke-linecap:round"/>' if arc_d else ''}
  </svg>
  <div class="gauge__readout">
    <span class="gauge__value display-small">{esc(readout)}</span><span class="gauge__unit title-medium">{esc(unit)}</span>
  </div>
  <div class="gauge__caption overline">{esc(S("distance_away_caption"))}</div>
</div>"""


def _live_marker_svg(cx: float, cy: float, color_var: str) -> str:
    """drawLiveMarker at pulseProgress = 0 (resting frame) - a static reference cannot
    reproduce the 2.4s breathing loop deterministically, so the resting halo is used."""
    return f"""<circle cx="{cx:.2f}" cy="{cy:.2f}" r="13" style="fill:var({color_var});opacity:0.10"/>
    <circle cx="{cx:.2f}" cy="{cy:.2f}" r="8.5" style="fill:var(--surface-container-lowest)"/>
    <circle cx="{cx:.2f}" cy="{cy:.2f}" r="5.5" style="fill:var({color_var})"/>"""


def location_surface_plan_svg(
    has_office: bool,
    has_current: bool,
    distance_m: float | None,
    bearing_deg: float,
    boundary_var: str,
) -> str:
    """LocationSurface.kt drawLocationPlan, reproduced in the same drawing order:
    wash -> guide rings -> cross axes -> (no-office preview ring | boundary + connector +
    live marker) -> office marker last."""
    w, h = SURFACE_WIDTH, SURFACE_HEIGHT
    cx, cy = w / 2, h / 2
    extent = min(w, h) / 2 * 0.86
    boundary_r = extent * BOUNDARY_RADIUS_FRACTION
    outer_guide_r = boundary_r * GUIDE_RING_MULTIPLES[-1]

    parts: list[str] = []
    parts.append(
        f'<circle cx="{cx}" cy="{cy}" r="{outer_guide_r * 1.25:.2f}" '
        f'style="fill:url(#wash)"/>'
    )
    for i, mult in enumerate(GUIDE_RING_MULTIPLES):
        parts.append(
            f'<circle cx="{cx}" cy="{cy}" r="{boundary_r * mult:.2f}" '
            f'style="fill:none;stroke:var(--outline-variant);stroke-width:1;'
            f'opacity:{0.34 - i * 0.08:.2f}"/>'
        )
    parts.append(
        f'<line x1="{cx}" y1="{cy - outer_guide_r:.2f}" x2="{cx}" y2="{cy + outer_guide_r:.2f}" '
        f'style="stroke:var(--outline-variant);stroke-width:1;stroke-dasharray:3,5;opacity:0.26"/>'
    )
    parts.append(
        f'<line x1="{cx - outer_guide_r:.2f}" y1="{cy}" x2="{cx + outer_guide_r:.2f}" y2="{cy}" '
        f'style="stroke:var(--outline-variant);stroke-width:1;stroke-dasharray:3,5;opacity:0.26"/>'
    )

    if not has_office:
        parts.append(
            f'<circle cx="{cx}" cy="{cy}" r="{boundary_r:.2f}" '
            f'style="fill:none;stroke:var(--outline-variant);stroke-width:2;'
            f'stroke-dasharray:6,8;opacity:0.55"/>'
        )
        if has_current:
            # LocationSurface.kt: boundaryColor is colorScheme.outline whenever proximity is
            # null (always true here, since there is no office to be Tracking against yet),
            # and drawLiveMarker at centre uses that same boundaryColor - not an accent.
            parts.append(_live_marker_svg(cx, cy, boundary_var))
    else:
        parts.append(
            f'<circle cx="{cx}" cy="{cy}" r="{boundary_r:.2f}" style="fill:url(#boundary-fill)"/>'
        )
        parts.append(
            f'<circle cx="{cx}" cy="{cy}" r="{boundary_r:.2f}" '
            f'style="fill:none;stroke:var({boundary_var});stroke-width:2.5;'
            f'stroke-dasharray:11,7;opacity:0.9"/>'
        )
        if has_current:
            radius_frac = surface_radius_fraction(distance_m)
            bearing_rad = math.radians(bearing_deg)
            mx = radius_frac * math.sin(bearing_rad)
            my = -radius_frac * math.cos(bearing_rad)
            marker_x = cx + mx * boundary_r
            marker_y = cy + my * boundary_r
            parts.append(
                f'<line x1="{cx}" y1="{cy}" x2="{marker_x:.2f}" y2="{marker_y:.2f}" '
                f'style="stroke:var(--on-surface-variant);stroke-width:1.5;'
                f'stroke-dasharray:4,5;opacity:0.45"/>'
            )
            parts.append(_live_marker_svg(marker_x, marker_y, boundary_var))
        parts.append(f'<circle cx="{cx}" cy="{cy}" r="16" style="fill:var(--tertiary);opacity:0.14"/>')
        parts.append(f'<circle cx="{cx}" cy="{cy}" r="10" style="fill:var(--surface-container-lowest)"/>')
        parts.append(f'<circle cx="{cx}" cy="{cy}" r="6.5" style="fill:var(--tertiary)"/>')
        parts.append(f'<circle cx="{cx}" cy="{cy}" r="2.4" style="fill:var(--surface-container-lowest)"/>')

    defs = f"""<defs>
    <radialGradient id="wash" cx="50%" cy="50%" r="50%">
      <stop offset="0" style="stop-color:var(--outline-variant);stop-opacity:0.22"/>
      <stop offset="1" style="stop-color:var(--outline-variant);stop-opacity:0"/>
    </radialGradient>
    <radialGradient id="boundary-fill" cx="50%" cy="50%" r="50%">
      <stop offset="0" style="stop-color:var({boundary_var});stop-opacity:0.04"/>
      <stop offset="1" style="stop-color:var({boundary_var});stop-opacity:0.18"/>
    </radialGradient>
  </defs>"""
    return (
        f'<svg class="location-surface__plan" width="{w:.4f}" height="{h}" '
        f'viewBox="0 0 {w:.4f} {h}" aria-hidden="true">{defs}{"".join(parts)}</svg>'
    )


def location_surface(
    *, has_office: bool, has_current: bool, distance_m: float | None, bearing_deg: float,
    boundary_var: str, office_coords: tuple[float, float] | None,
    current_coords: tuple[float, float] | None = None,
) -> str:
    # OfficeContextCard.kt coordinateLabel/coordinateValue: office wins when set; otherwise
    # the current fix (if any) is shown as a preview of what a capture would record.
    if office_coords is not None:
        coord_label = S("location_surface_legend_office")
        coord_value = S("location_surface_coordinates", f"{office_coords[0]:.6f}", f"{office_coords[1]:.6f}")
    elif current_coords is not None:
        coord_label = S("location_surface_legend_you")
        coord_value = S("location_surface_coordinates", f"{current_coords[0]:.6f}", f"{current_coords[1]:.6f}")
    else:
        coord_label = S("location_surface_legend_you")
        coord_value = S("location_surface_no_coordinates")

    legend = ""
    if has_office:
        legend += (
            f'<div class="surface-legend__entry"><span class="dot" style="background:var(--tertiary)"></span>'
            f'<span class="label-medium">{esc(S("location_surface_legend_office"))}</span></div>'
        )
    if has_current:
        legend += (
            f'<div class="surface-legend__entry"><span class="dot" style="background:var({boundary_var})"></span>'
            f'<span class="label-medium">{esc(S("location_surface_legend_you"))}</span></div>'
        )

    plan = location_surface_plan_svg(has_office, has_current, distance_m, bearing_deg, boundary_var)
    return f"""<div class="location-surface" style="width:{SURFACE_WIDTH:.4f}px;height:{SURFACE_HEIGHT}px">
  {plan}
  <div class="surface-legend">{legend}</div>
  <div class="surface-pill surface-pill--radius overline">{esc(S("location_surface_legend", RADIUS_METERS))}</div>
  <div class="surface-pill surface-pill--coord">
    <span class="dot" style="background:var(--primary)"></span>
    <div><div class="overline">{esc(coord_label)}</div><div class="label-large">{esc(coord_value)}</div></div>
  </div>
</div>"""


def range_status_chip(eligible: bool) -> str:
    label_key = "range_status_in" if eligible else "range_status_out"
    tone = "success" if eligible else "error"
    container = "success-container" if eligible else "error-container"
    on = "on-success-container" if eligible else "on-error-container"
    return (
        f'<div class="range-chip" style="background:var(--{container});color:var(--{on})">'
        f'<span class="dot" style="background:var(--{on})"></span>'
        f'<span class="overline">{esc(S(label_key))}</span></div>'
    )


def status_dot(is_set: bool) -> str:
    color = "var(--success)" if is_set else "var(--outline)"
    return f'<span class="status-dot" style="background:{color}"></span>'


def spinner_svg(size: int = 18, color_var: str = "currentColor") -> str:
    color = color_var if color_var == "currentColor" else f"var({color_var})"
    return f'<span class="spinner" style="width:{size}px;height:{size}px;color:{color}"></span>'


# =============================================================================================
# 7. STATUS BANNER - the one shape every AttendanceStatusKind renders in (StatusBanner.kt)
# =============================================================================================


def status_banner(
    *, title: str, body: str, tone: str, icon: str | None, progress: bool,
    action_label: str | None = None, action_icon: str | None = None,
    extra_class: str = "",
) -> str:
    container, on_container = TONE_ROLES[tone]
    has_action = action_label is not None
    badge = spinner_svg() if progress else (icon_svg(icon, 20, "currentColor") if icon else "")
    action_html = ""
    if has_action:
        action_icon_html = icon_svg(action_icon, 18, "currentColor") if action_icon else ""
        action_html = (
            f'<button type="button" class="status-banner__action label-large">{action_icon_html}'
            f'<span>{esc(action_label)}</span></button>'
        )
    return f"""<div class="status-banner{' ' + extra_class if extra_class else ''}{' has-action' if has_action else ''}"
     style="background:var(--{container});color:var(--{on_container})">
  <div class="status-banner__badge" style="background:color-mix(in srgb, currentColor 12%, transparent)">{badge}</div>
  <div class="status-banner__text">
    <p class="status-banner__title title-medium">{esc(title)}</p>
    <p class="status-banner__body body-medium" style="color:color-mix(in srgb, currentColor 82%, transparent)">{esc(body)}</p>
    {action_html}
  </div>
</div>"""


# =============================================================================================
# 8. KIND TABLE - AttendanceStatusPresenter + AttendanceStatusCard, transcribed exactly
# =============================================================================================

KIND_TABLE: dict[str, dict] = {
    "PERMISSION_REQUIRED": dict(
        title_key="status_permission_title", body_key="status_permission_body", body_args=(),
        tone="ATTENTION", icon="ic_lock", progress=False,
        action_label_key="status_permission_action", action_icon=None,
        mark_action="BLOCKED", blocker_key="blocked_reason_permission",
    ),
    "PERMISSION_BLOCKED": dict(
        title_key="status_permission_title", body_key="status_permission_body_settings", body_args=(),
        tone="ATTENTION", icon="ic_lock", progress=False,
        action_label_key="status_permission_action_settings", action_icon="ic_open_in_new",
        mark_action="BLOCKED", blocker_key="blocked_reason_permission",
    ),
    "PRECISE_REQUIRED": dict(
        title_key="status_precise_title", body_key="status_precise_body", body_args=(RADIUS_METERS,),
        tone="ATTENTION", icon="ic_crosshair", progress=False,
        action_label_key="status_precise_action", action_icon=None,
        mark_action="BLOCKED", blocker_key="blocked_reason_precise",
    ),
    "PRECISE_BLOCKED": dict(
        title_key="status_precise_title", body_key="status_precise_body", body_args=(RADIUS_METERS,),
        tone="ATTENTION", icon="ic_crosshair", progress=False,
        action_label_key="status_permission_action_settings", action_icon="ic_open_in_new",
        mark_action="BLOCKED", blocker_key="blocked_reason_precise",
    ),
    "SERVICES_DISABLED": dict(
        title_key="status_services_title", body_key="status_services_body", body_args=(),
        tone="ATTENTION", icon="ic_crosshair_off", progress=False,
        action_label_key="status_services_action", action_icon="ic_open_in_new",
        mark_action="BLOCKED", blocker_key="blocked_reason_services_off",
    ),
    "ACQUIRING_FIX": dict(
        title_key="status_acquiring_title", body_key="status_acquiring_body", body_args=(),
        tone="PROGRESS", icon=None, progress=True,
        action_label_key=None, action_icon=None,
        mark_action="BLOCKED", blocker_key="blocked_reason_no_fix",
    ),
    "REFRESHING_FIX": dict(
        title_key="status_refreshing_title", body_key="status_refreshing_body", body_args=(),
        tone="PROGRESS", icon=None, progress=True,
        action_label_key=None, action_icon=None,
        mark_action="BLOCKED", blocker_key="blocked_reason_stale_fix",
    ),
    "IMPROVING_ACCURACY": dict(
        title_key="status_improving_accuracy_title", body_key="status_improving_accuracy_body", body_args=(),
        tone="PROGRESS", icon=None, progress=True,
        action_label_key=None, action_icon=None,
        mark_action="BLOCKED", blocker_key="blocked_reason_imprecise_fix",
    ),
    "LOCATION_UNAVAILABLE_NO_FIX": dict(
        title_key="status_unavailable_title", body_key="status_unavailable_body_no_fix", body_args=(),
        tone="BLOCKED", icon="ic_alert", progress=False,
        action_label_key=None, action_icon=None,
        mark_action="BLOCKED", blocker_key="blocked_reason_no_fix",
    ),
    "LOCATION_UNAVAILABLE_PROVIDER": dict(
        title_key="status_unavailable_title", body_key="status_unavailable_body_provider", body_args=(),
        tone="BLOCKED", icon="ic_alert", progress=False,
        action_label_key=None, action_icon=None,
        mark_action="BLOCKED", blocker_key="blocked_reason_no_fix",
    ),
    "OFFICE_NOT_SET": dict(
        title_key="status_office_not_set_title", body_key="status_office_not_set_body", body_args=(),
        tone="INFO", icon="ic_pin", progress=False,
        action_label_key=None, action_icon=None,
        mark_action="BLOCKED", blocker_key="blocked_reason_office_not_set",
    ),
    "OUT_OF_RANGE": dict(
        title_key="status_out_of_range_title", body_key="status_out_of_range_body", body_args="DISTANCE_RADIUS",
        tone="BLOCKED", icon="ic_pin", progress=False,
        action_label_key=None, action_icon=None,
        mark_action="BLOCKED", blocker_key="blocked_reason_out_of_range",
    ),
    "READY_TO_MARK": dict(
        title_key="status_ready_title", body_key="status_ready_body", body_args="DISTANCE_RADIUS",
        tone="SUCCESS", icon="ic_check_circle", progress=False,
        action_label_key=None, action_icon=None,
        mark_action="AVAILABLE", blocker_key=None,
    ),
    "ATTENDANCE_MARKED": dict(
        title_key="status_marked_title", body_key="status_marked_body", body_args="MARKED_AT",
        tone="SUCCESS", icon="ic_check_circle", progress=False,
        action_label_key=None, action_icon=None,
        mark_action="COMPLETED", blocker_key=None,
    ),
}


def render_status_card(kind: str, *, distance_m: float | None = None, marked_at: str | None = None) -> str:
    row = KIND_TABLE[kind]
    if row["body_args"] == "DISTANCE_RADIUS":
        body = S(row["body_key"], format_distance(distance_m), RADIUS_METERS)
    elif row["body_args"] == "MARKED_AT":
        body = S(row["body_key"], marked_at or "")
    else:
        body = S(row["body_key"], *row["body_args"])
    action_label = S(row["action_label_key"]) if row["action_label_key"] else None
    return status_banner(
        title=S(row["title_key"]), body=body, tone=row["tone"], icon=row["icon"],
        progress=row["progress"], action_label=action_label, action_icon=row["action_icon"],
    )


# AttendanceUiState.canSetOfficeLocation: false while the one-shot capture cannot possibly
# succeed - no permission, approximate-only, or the OS location toggle is off.
OFFICE_BUTTON_DISABLED_KINDS = {
    "PERMISSION_REQUIRED", "PERMISSION_BLOCKED",
    "PRECISE_REQUIRED", "PRECISE_BLOCKED",
    "SERVICES_DISABLED",
}


def blocked_reason_text(kind: str) -> str | None:
    row = KIND_TABLE[kind]
    key = row["blocker_key"]
    if key is None:
        return None
    if key == "blocked_reason_out_of_range":
        return S(key, RADIUS_METERS)
    return S(key)


# =============================================================================================
# 9. DEGRADED ACCURACY NOTICE - the modifier, canonical preview accuracy = 40m
# =============================================================================================


def degraded_accuracy_notice(accuracy_m: float = 40.0) -> str:
    return status_banner(
        title=S("status_degraded_accuracy_title"),
        body=S("status_degraded_accuracy", format_distance(accuracy_m)),
        tone="ATTENTION", icon="ic_alert", progress=False,
        extra_class="status-banner--degraded",
    )


# =============================================================================================
# 10. OFFICE CONTEXT CARD
# =============================================================================================


def office_context_card(
    *, has_office: bool, has_current: bool, distance_m: float | None, bearing_deg: float,
    boundary_var: str, office_coords: tuple[float, float] | None, captured_at: str | None,
    is_capturing: bool, enabled: bool, current_coords: tuple[float, float] | None = None,
) -> str:
    surface = location_surface(
        has_office=has_office, has_current=has_current, distance_m=distance_m,
        bearing_deg=bearing_deg, boundary_var=boundary_var, office_coords=office_coords,
        current_coords=current_coords,
    )
    state_label = S("office_context_set") if has_office else S("office_context_not_set")

    if has_office:
        capturing_note = (
            f'<p class="capturing-note body-small">{esc(S("set_office_location_capturing_note"))}</p>'
            if is_capturing else ""
        )
        face = f"""<div class="office-face">
      <p class="title-small">{esc(S("office_context_helper"))}</p>
      <p class="body-small" style="color:var(--on-surface-variant)">{esc(S("office_context_captured_at", captured_at or ""))}</p>
      <button type="button" class="text-button label-large" {"disabled" if not enabled else ""}>
        {icon_svg("ic_swap", 18)}<span>{esc(S("change_office_location"))}</span>
      </button>
      {capturing_note}
    </div>"""
    else:
        # The idle icon dims with the button's own disabled-state colour (currentColor); the
        # capturing spinner does not - OfficeContextCard.kt hardcodes
        # color = MaterialTheme.colorScheme.onPrimary regardless of the button's enabled state.
        button_lead = spinner_svg(color_var="--on-primary") if is_capturing else icon_svg("ic_crosshair", 18)
        capturing_note = (
            f'<p class="capturing-note body-small">{esc(S("set_office_location_capturing_note"))}</p>'
            if is_capturing else ""
        )
        face = f"""<div class="office-face">
      <p class="title-medium">{esc(S("office_context_setup_title"))}</p>
      <p class="body-medium" style="color:var(--on-surface-variant)">{esc(S("office_context_setup_body"))}</p>
      <button type="button" class="filled-button label-large" {"disabled" if not enabled else ""}>
        {button_lead}<span>{esc(S("set_office_location"))}</span>
      </button>
      {capturing_note}
    </div>"""

    return f"""<div class="office-card">
  <div class="office-card__header">
    <span class="overline" style="color:var(--on-surface-variant)">{esc(S("office_context_overline"))}</span>
    {status_dot(has_office)}
    <span class="label-medium" style="color:var(--on-surface-variant)">{esc(state_label)}</span>
  </div>
  {surface}
  {face}
</div>"""


# =============================================================================================
# 11. PROXIMITY CARD
# =============================================================================================


def proximity_card(*, distance_m: float | None, eligible: bool | None) -> str:
    if eligible is None:
        accent_var = "--outline-variant"
    elif eligible:
        accent_var = "--success"
    else:
        accent_var = "--error"
    gauge = distance_gauge_svg(distance_m, accent_var)
    readout = ""
    if distance_m is not None and eligible is not None:
        chip = range_status_chip(eligible)
        guidance = S("range_guidance_in") if eligible else S("range_guidance_out", RADIUS_METERS)
        readout = f"""<div class="proximity-readout">
      {chip}
      <p class="title-medium" style="text-align:center">{esc(S("distance_live_readout", format_distance(distance_m)))}</p>
      <p class="body-medium" style="text-align:center;color:var(--on-surface-variant)">{esc(guidance)}</p>
    </div>"""
    return f"""<div class="proximity-card">
  {gauge}
  {readout}
</div>"""


# =============================================================================================
# 12. ATTENDANCE ACTION PANEL
# =============================================================================================


def attendance_action_panel(
    *, mark_action: str, blocker_text: str | None, marked_at: str | None, verified_distance: str | None,
) -> str:
    if mark_action == "COMPLETED":
        confirmation_detail = S("attendance_confirmation_detail", verified_distance or "")
        return f"""<div class="action-panel action-panel--completed">
  <div class="confirmation-row">
    <div class="confirmation-badge">{icon_svg("ic_check_circle", 18, "--on-success-container")}</div>
    <div class="confirmation-text">
      <p class="title-small">{esc(S("attendance_confirmation_title"))}</p>
      <p class="body-small" style="color:var(--on-surface-variant)">{esc(confirmation_detail)}</p>
    </div>
    <p class="label-large">{esc(marked_at or "")}</p>
  </div>
  <div class="divider"></div>
  {office_hours_row()}
</div>"""

    enabled = mark_action == "AVAILABLE"
    header_color = "--success" if enabled else "--on-surface-variant"
    header_icon = "ic_check_circle" if enabled else "ic_lock"
    header_label = S("mark_attendance_ready") if enabled else S("mark_attendance_locked")
    blocker_html = (
        f'<div class="inline-note body-medium" style="color:var(--on-surface-variant)">'
        f'{icon_svg("ic_info", 16, "--on-surface-variant")}<span>{esc(blocker_text)}</span></div>'
        if blocker_text else ""
    )
    return f"""<div class="action-panel {'action-panel--enabled' if enabled else 'action-panel--blocked'}">
  <div class="action-panel__header" style="color:var(--{header_color[2:]})">
    {icon_svg(header_icon, 20, header_color)}
    <span class="overline">{esc(header_label)}</span>
  </div>
  <button type="button" class="mark-button label-large" {'' if enabled else 'disabled'}>{esc(S("mark_attendance"))}</button>
  {blocker_html}
  <div class="divider"></div>
  {office_hours_row()}
</div>"""


def office_hours_row() -> str:
    return f"""<div class="office-hours">
  {icon_svg("ic_clock", 15, "--on-surface-variant")}
  <span class="label-medium" style="color:var(--on-surface-variant)">{esc(S("office_hours_label"))}</span>
  <span class="label-medium" style="color:var(--on-surface)">{esc(S("office_hours_value"))}</span>
</div>"""


# =============================================================================================
# 13. OVERLAY / MODIFIER COMPONENTS - gallery only, never a standalone page (brief section 5)
# =============================================================================================


def how_attendance_works_content() -> str:
    rows = [
        ("ic_device_lock", S("how_it_works_storage_title"), S("how_it_works_storage_body")),
        ("ic_crosshair", S("how_it_works_tracking_title"), S("how_it_works_tracking_body")),
        ("ic_pin", S("how_it_works_radius_title", RADIUS_METERS), S("how_it_works_radius_body", RADIUS_METERS)),
        ("ic_lock", S("how_it_works_background_title"), S("how_it_works_background_body")),
    ]
    rows_html = "".join(
        f"""<div class="disclosure-row">
      <div class="disclosure-row__badge">{icon_svg(icon, 20, "--on-secondary-container")}</div>
      <div><p class="title-small">{esc(title)}</p><p class="body-medium" style="color:var(--on-surface-variant)">{esc(body)}</p></div>
    </div>"""
        for icon, title, body in rows
    )
    return f"""<div class="sheet">
  <p class="headline-small">{esc(S("how_it_works_title"))}</p>
  <p class="body-medium" style="color:var(--on-surface-variant)">{esc(S("how_it_works_subtitle"))}</p>
  <div class="disclosure-list">{rows_html}</div>
  <div class="divider"></div>
  <p class="body-small" style="color:var(--on-surface-variant)">{esc(S("how_it_works_footnote"))}</p>
  <button type="button" class="text-button label-large" style="align-self:flex-end">{esc(S("how_it_works_dismiss"))}</button>
</div>"""


def change_office_dialog_content(coords_text: str) -> str:
    return f"""<div class="dialog">
  {icon_svg("ic_swap", 24)}
  <p class="headline-small">{esc(S("change_office_dialog_title"))}</p>
  <p class="body-medium">{esc(S("change_office_dialog_body", coords_text))}</p>
  <div class="dialog__actions">
    <button type="button" class="text-button label-large">{esc(S("change_office_dialog_cancel"))}</button>
    <button type="button" class="text-button label-large">{esc(S("change_office_dialog_confirm"))}</button>
  </div>
</div>"""


def snackbar_content() -> str:
    text = S("snackbar_office_saved", "24.885400", "91.885777")
    return f'<div class="snackbar body-medium">{esc(text)}</div>'


def capturing_office_variant() -> str:
    return office_context_card(
        has_office=False, has_current=True, distance_m=None, bearing_deg=0,
        boundary_var="--outline", office_coords=None, captured_at=None,
        is_capturing=True, enabled=False, current_coords=(23.780636, 90.279372),
    )


# =============================================================================================
# 14. PAGE TEMPLATE
# =============================================================================================


def phone_frame(body_html: str, *, full_bleed_bg: str | None = None) -> str:
    bg = f' style="background:{full_bleed_bg}"' if full_bleed_bg else ""
    return f"""<div class="phone"{bg}>
  <div class="system-inset system-inset--top"></div>
  <div class="app-content">{body_html}</div>
  <div class="system-inset system-inset--bottom"></div>
</div>"""


def app_bar(title_key: str = "attendance_title") -> str:
    return f"""<div class="topbar">
  <button type="button" class="icon-button" aria-label="{esc(S('content_description_back'))}">{icon_svg("ic_arrow_back", 24)}</button>
  <span class="title-large">{esc(S(title_key))}</span>
  <button type="button" class="icon-button" aria-label="{esc(S('content_description_how_it_works'))}">{icon_svg("ic_help", 24)}</button>
</div>"""


def attendance_screen_body(
    *, kind: str, has_office: bool, has_current: bool, distance_m: float | None,
    eligible: bool | None, bearing_deg: float, office_coords: tuple[float, float] | None,
    captured_at: str | None, marked_at: str | None, degraded: bool = False,
    accuracy_m: float | None = None, current_coords: tuple[float, float] | None = None,
) -> str:
    row = KIND_TABLE[kind]
    # LocationSurface.kt boundaryColor: colorScheme.outline when proximity is null,
    # statusColors.success when eligible, colorScheme.error otherwise.
    boundary_var = "--outline" if eligible is None else ("--success" if eligible else "--error")
    status_html = render_status_card(kind, distance_m=distance_m, marked_at=marked_at)
    degraded_html = degraded_accuracy_notice(accuracy_m or 40.0) if degraded else ""
    office_html = office_context_card(
        has_office=has_office, has_current=has_current, distance_m=distance_m,
        bearing_deg=bearing_deg, boundary_var=boundary_var, office_coords=office_coords,
        captured_at=captured_at, is_capturing=False,
        enabled=kind not in OFFICE_BUTTON_DISABLED_KINDS, current_coords=current_coords,
    )
    proximity_html = ""
    if has_office:
        proximity_html = f'<div class="section-gap">{proximity_card(distance_m=distance_m, eligible=eligible)}</div>'
    blocker = blocked_reason_text(kind)
    verified_distance = format_distance(distance_m) if distance_m is not None else None
    action_html = attendance_action_panel(
        mark_action=row["mark_action"], blocker_text=blocker, marked_at=marked_at,
        verified_distance=verified_distance,
    )
    return f"""{app_bar()}
<div class="content">
  {status_html}
  {f'<div class="section-gap">{degraded_html}</div>' if degraded_html else ''}
  <div class="section-gap">{office_html}</div>
  {proximity_html}
  <div class="section-gap">{action_html}</div>
</div>"""


PAGE_HEAD = """<!doctype html>
<html lang="en" data-theme="{default_theme}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<link rel="stylesheet" href="tokens.css">
<link rel="stylesheet" href="screens.css">
<script>
(function () {{
  var params = new URLSearchParams(location.search);
  var theme = params.get('theme');
  if (theme === 'light' || theme === 'dark') {{
    document.documentElement.setAttribute('data-theme', theme);
  }}
  if (params.get('bare') === '1') {{
    document.documentElement.classList.add('bare');
  }}
  if (params.get('tall') === '1') {{
    document.documentElement.classList.add('tall');
  }}
}})();
</script>
</head>
<body class="{body_class}">
"""

PAGE_FOOT = "</body>\n</html>\n"


def theme_toggle(current_default: str) -> str:
    return f"""<div class="theme-toggle">
  <a href="?theme=dark">dark</a> &middot; <a href="?theme=light">light</a>
  <span class="theme-toggle__default">(default: {current_default})</span>
</div>"""


def page_wrapper(*, title: str, default_theme: str, breadcrumb_extra: str, body: str) -> str:
    head = PAGE_HEAD.format(title=esc(title), default_theme=default_theme, body_class="standalone")
    nav = f'<p class="breadcrumb"><a href="index.html">&larr; Android UI reference index</a></p>'
    return head + nav + theme_toggle(default_theme) + body + PAGE_FOOT


def family_card(*, slug: str, heading: str, evidence: str, precondition: str, phone_html: str, notes: str) -> str:
    return f"""<figure class="screen-card">
  {phone_html}
  <figcaption>
    <b>{esc(heading)}</b>
    <p class="evidence">{esc(evidence)}</p>
    <p class="precondition">{esc(precondition)}</p>
    <p class="notes">{notes}</p>
  </figcaption>
</figure>"""


# =============================================================================================
# 15. FAMILY DEFINITIONS - the canonical (kind x office-state) fixture per page (brief section 12)
# =============================================================================================

# Coordinates shown on the runtime-backed page come from the actual v1.0.0 screenshot
# (docs/assets/android/attendance-ready.png); the preview-fixture coordinates come from
# AttendanceScreenPreviews.kt's OFFICE constant. Timestamps: the runtime screenshot shows
# "Aug 30, 2026 10:38 PM"; the preview fixture's MARKED_AT_EPOCH_MILLIS = 1_756_000_000_000L
# renders (UTC) as "Aug 24, 2025, 1:46 AM" - both are representative, not computed by this
# script, because DateFormat output is locale/timezone-dependent and cannot be reproduced
# deterministically in a static page.
RUNTIME_OFFICE_COORDS = (24.885400, 91.885777)
RUNTIME_CAPTURED_AT = "Aug 30, 2026 10:38 PM"
PREVIEW_OFFICE_COORDS = (23.780636, 90.279372)
PREVIEW_CAPTURED_AT = "Aug 24, 2025, 1:46 AM"
# TimestampFormatter.time() (used for markedAtText, both in the status card body and the
# receipt) renders SHORT time only, not the full date - distinct from
# TimestampFormatter.format() (used for office_context_captured_at) above.
PREVIEW_MARKED_TIME = "1:46 AM"


def build_families() -> list[dict]:
    fam = []

    # 01 - OFFICE_NOT_SET. Preview: "First use - setup". office=null, currentLocation set
    # (deviceLocation() defaults coordinates to the OFFICE preview-fixture constant).
    body = attendance_screen_body(
        kind="OFFICE_NOT_SET", has_office=False, has_current=True, distance_m=None,
        eligible=None, bearing_deg=0, office_coords=None, captured_at=None, marked_at=None,
        current_coords=PREVIEW_OFFICE_COORDS,
    )
    fam.append(dict(
        slug="01-setup", title="Setup - office not set", kinds=["OFFICE_NOT_SET"],
        evidence="Deterministic Compose preview: “First use - setup”",
        precondition="office = null, currentLocation set (a fix exists; no office is anchored yet)",
        default_theme="dark", body=body,
    ))

    # 02 - READY_TO_MARK. RUNTIME default = 2m (screenshot); preview variant = 32m.
    body_runtime = attendance_screen_body(
        kind="READY_TO_MARK", has_office=True, has_current=True, distance_m=2.0, eligible=True,
        bearing_deg=15, office_coords=RUNTIME_OFFICE_COORDS, captured_at=RUNTIME_CAPTURED_AT,
        marked_at=None,
    )
    body_preview = attendance_screen_body(
        kind="READY_TO_MARK", has_office=True, has_current=True, distance_m=32.0, eligible=True,
        bearing_deg=15, office_coords=PREVIEW_OFFICE_COORDS, captured_at=PREVIEW_CAPTURED_AT,
        marked_at=None,
    )
    fam.append(dict(
        slug="02-tracking-ready", title="Tracking - ready to mark", kinds=["READY_TO_MARK"],
        evidence="Runtime screenshot docs/assets/android/attendance-ready.png (primary frame, 2m) "
                 "+ Compose preview “Ready to mark” (32m variant, below)",
        precondition="office set, proximity.isEligible = true",
        default_theme="dark", body=body_runtime, variant_body=body_preview,
        variant_label="Preview-fixture variant: 32 m (“Ready to mark” preview)",
    ))

    # 03 - OUT_OF_RANGE. Preview: "Out of range", 120m.
    body = attendance_screen_body(
        kind="OUT_OF_RANGE", has_office=True, has_current=True, distance_m=120.0, eligible=False,
        bearing_deg=15, office_coords=PREVIEW_OFFICE_COORDS, captured_at=PREVIEW_CAPTURED_AT,
        marked_at=None,
    )
    fam.append(dict(
        slug="03-tracking-out-of-range", title="Tracking - out of range", kinds=["OUT_OF_RANGE"],
        evidence="Deterministic Compose preview: “Out of range”",
        precondition="office set, proximity.isEligible = false",
        default_theme="dark", body=body,
    ))

    # 04 - ATTENDANCE_MARKED. Preview: "Attendance marked", 32m.
    body = attendance_screen_body(
        kind="ATTENDANCE_MARKED", has_office=True, has_current=True, distance_m=32.0, eligible=True,
        bearing_deg=15, office_coords=PREVIEW_OFFICE_COORDS, captured_at=PREVIEW_CAPTURED_AT,
        marked_at=PREVIEW_MARKED_TIME,
    )
    fam.append(dict(
        slug="04-attendance-marked", title="Attendance marked", kinds=["ATTENDANCE_MARKED"],
        evidence="Deterministic Compose preview: “Attendance marked”",
        precondition="office set, proximity.isEligible = true, isAttendanceConfirmed = true "
                     "(the action panel is replaced by a receipt; ADR-016)",
        default_theme="dark", body=body,
    ))

    # 05 - PERMISSION_REQUIRED / PERMISSION_BLOCKED. office=null, currentLocation=null.
    body_req = attendance_screen_body(
        kind="PERMISSION_REQUIRED", has_office=False, has_current=False, distance_m=None,
        eligible=None, bearing_deg=0, office_coords=None, captured_at=None, marked_at=None,
    )
    body_blocked = attendance_screen_body(
        kind="PERMISSION_BLOCKED", has_office=False, has_current=False, distance_m=None,
        eligible=None, bearing_deg=0, office_coords=None, captured_at=None, marked_at=None,
    )
    fam.append(dict(
        slug="05-location-permission", title="Location permission", kinds=["PERMISSION_REQUIRED", "PERMISSION_BLOCKED"],
        evidence="Deterministic Compose previews: “Permission required”, “Permission permanently denied”",
        precondition="office = null, currentLocation = null (no fix exists before permission is granted)",
        default_theme="dark", body=body_req, variant_body=body_blocked,
        variant_label="Repeated-denial variant: canRequestPermissionInApp = false",
    ))

    # 06 - PRECISE_REQUIRED / PRECISE_BLOCKED. office=null, currentLocation=null.
    body_req = attendance_screen_body(
        kind="PRECISE_REQUIRED", has_office=False, has_current=False, distance_m=None,
        eligible=None, bearing_deg=0, office_coords=None, captured_at=None, marked_at=None,
    )
    body_blocked = attendance_screen_body(
        kind="PRECISE_BLOCKED", has_office=False, has_current=False, distance_m=None,
        eligible=None, bearing_deg=0, office_coords=None, captured_at=None, marked_at=None,
    )
    fam.append(dict(
        slug="06-precise-location", title="Precise location required", kinds=["PRECISE_REQUIRED", "PRECISE_BLOCKED"],
        evidence="Deterministic Compose preview “Approximate location only”; PRECISE_BLOCKED has "
                 "no preview and no screenshot - derived from source (PRECISE_REQUIRED's copy + "
                 "PERMISSION_BLOCKED's action)",
        precondition="office = null, currentLocation = null",
        default_theme="dark", body=body_req, variant_body=body_blocked,
        variant_label="No-preview variant: canRequestPermissionInApp = false (source-derived)",
    ))

    # 07 - SERVICES_DISABLED. office SET, ProximityCard present, empty gauge.
    body = attendance_screen_body(
        kind="SERVICES_DISABLED", has_office=True, has_current=False, distance_m=None,
        eligible=None, bearing_deg=0, office_coords=PREVIEW_OFFICE_COORDS,
        captured_at=PREVIEW_CAPTURED_AT, marked_at=None,
    )
    fam.append(dict(
        slug="07-location-services-disabled", title="Location services disabled", kinds=["SERVICES_DISABLED"],
        evidence="Deterministic Compose preview: “Location services off”",
        precondition="office SET (ProximityCard is present; the gauge is empty because no Tracking "
                     "proximity exists while services are off)",
        default_theme="dark", body=body,
    ))

    # 08 - ACQUIRING_FIX / REFRESHING_FIX / IMPROVING_ACCURACY. office SET.
    body_acq = attendance_screen_body(
        kind="ACQUIRING_FIX", has_office=True, has_current=False, distance_m=None,
        eligible=None, bearing_deg=0, office_coords=PREVIEW_OFFICE_COORDS,
        captured_at=PREVIEW_CAPTURED_AT, marked_at=None,
    )
    body_ref = attendance_screen_body(
        kind="REFRESHING_FIX", has_office=True, has_current=True, distance_m=None,
        eligible=None, bearing_deg=15, office_coords=PREVIEW_OFFICE_COORDS,
        captured_at=PREVIEW_CAPTURED_AT, marked_at=None,
    )
    body_imp = attendance_screen_body(
        kind="IMPROVING_ACCURACY", has_office=True, has_current=True, distance_m=None,
        eligible=None, bearing_deg=15, office_coords=PREVIEW_OFFICE_COORDS,
        captured_at=PREVIEW_CAPTURED_AT, marked_at=None,
    )
    fam.append(dict(
        slug="08-location-progress", title="Acquiring / refreshing / improving accuracy",
        kinds=["ACQUIRING_FIX", "REFRESHING_FIX", "IMPROVING_ACCURACY"],
        evidence="Deterministic Compose previews: “Acquiring fix”, “Refreshing a stale fix”, "
                 "“Improving accuracy” - geometrically identical, three distinct banners",
        precondition="office SET in all three; REFRESHING_FIX and IMPROVING_ACCURACY additionally hold a "
                     "stale/imprecise currentLocation (the last position stays on the plan view)",
        default_theme="dark", body=body_acq, variant_body=body_ref, variant_body2=body_imp,
        variant_label="REFRESHING_FIX", variant_label2="IMPROVING_ACCURACY",
    ))

    # 09 - LOCATION_UNAVAILABLE_NO_FIX / PROVIDER. office SET.
    body_no_fix = attendance_screen_body(
        kind="LOCATION_UNAVAILABLE_NO_FIX", has_office=True, has_current=False, distance_m=None,
        eligible=None, bearing_deg=0, office_coords=PREVIEW_OFFICE_COORDS,
        captured_at=PREVIEW_CAPTURED_AT, marked_at=None,
    )
    body_provider = attendance_screen_body(
        kind="LOCATION_UNAVAILABLE_PROVIDER", has_office=True, has_current=False, distance_m=None,
        eligible=None, bearing_deg=0, office_coords=PREVIEW_OFFICE_COORDS,
        captured_at=PREVIEW_CAPTURED_AT, marked_at=None,
    )
    fam.append(dict(
        slug="09-location-unavailable", title="Location unavailable",
        kinds=["LOCATION_UNAVAILABLE_NO_FIX", "LOCATION_UNAVAILABLE_PROVIDER"],
        evidence="Deterministic Compose preview “Location unavailable” (NO_FIX_AVAILABLE); "
                 "PROVIDER_ERROR has no preview and no screenshot - derived from source "
                 "(identical geometry, body swapped to status_unavailable_body_provider)",
        precondition="office SET",
        default_theme="dark", body=body_no_fix, variant_body=body_provider,
        variant_label="No-preview variant: PROVIDER_ERROR (source-derived)",
    ))

    return fam


FAMILIES = build_families()

# =============================================================================================
# 16. EMISSION
# =============================================================================================


def render_family_page(fam: dict) -> str:
    parts = [family_card(
        slug=fam["slug"], heading=fam["title"], evidence=fam["evidence"],
        precondition=fam["precondition"], phone_html=phone_frame(fam["body"]),
        notes="Primary state for this page.",
    )]
    if "variant_body" in fam:
        parts.append(family_card(
            slug=fam["slug"] + "-variant", heading=fam.get("variant_label", "Variant"),
            evidence=fam["evidence"], precondition=fam["precondition"],
            phone_html=phone_frame(fam["variant_body"]), notes="",
        ))
    if "variant_body2" in fam:
        parts.append(family_card(
            slug=fam["slug"] + "-variant2", heading=fam.get("variant_label2", "Variant"),
            evidence=fam["evidence"], precondition=fam["precondition"],
            phone_html=phone_frame(fam["variant_body2"]), notes="",
        ))
    kinds_list = "".join(f"<li><code>{k}</code></li>" for k in fam["kinds"])
    body = f"""<div class="stage stage--standalone">
{''.join(parts)}
</div>
<section class="page-notes">
  <h2>Source kinds covered</h2>
  <ul class="kind-list">{kinds_list}</ul>
</section>"""
    return page_wrapper(
        title=f"PresenceLens Attendance - {fam['title']} - post-implementation UI reference",
        default_theme=fam["default_theme"], breadcrumb_extra="", body=body,
    )


def render_gallery_component(title: str, evidence: str, html: str, frame_class: str = "gallery-frame") -> str:
    return f"""<figure class="screen-card screen-card--gallery">
  <div class="{frame_class}">{html}</div>
  <figcaption><b>{esc(title)}</b><p class="evidence">{esc(evidence)}</p></figcaption>
</figure>"""


def render_index() -> str:
    cards = []
    for fam in FAMILIES:
        variants = [k for k in fam["kinds"]]
        variant_note = ""
        if len(variants) > 1:
            variant_note = f" Covers {len(variants)} kinds on this page: " + ", ".join(f"<code>{v}</code>" for v in variants) + "."
        cards.append(f"""<figure class="screen-card">
  <a href="{fam['slug']}.html">{phone_frame(fam['body'])}</a>
  <figcaption>
    <b><a href="{fam['slug']}.html">{esc(fam['title'])}</a></b>
    <p class="evidence">{esc(fam['evidence'])}</p>
    <p class="precondition">{esc(fam['precondition'])}{variant_note}</p>
  </figcaption>
</figure>""")

    overlay_cards = [
        render_gallery_component(
            "Modifier: capturing office location", "Source-derived (isCapturingOfficeLocation = true)",
            capturing_office_variant(),
        ),
        render_gallery_component(
            "Modifier: degraded accuracy notice", "Deterministic Compose preview “Degraded fix” (accuracy = 40m)",
            degraded_accuracy_notice(40.0),
        ),
        render_gallery_component(
            "Overlay: How attendance works sheet", "Deterministic Compose preview “How attendance works”",
            how_attendance_works_content(), frame_class="gallery-frame gallery-frame--sheet",
        ),
        render_gallery_component(
            "Overlay: Change office location dialog", "Deterministic Compose preview “Change office confirmation”",
            change_office_dialog_content(S("location_surface_coordinates", "23.780636", "90.279372")),
            frame_class="gallery-frame gallery-frame--dialog",
        ),
        render_gallery_component(
            "Snackbar: office location saved", "Source-derived - no deterministic preview exists for any Snackbar",
            snackbar_content(),
        ),
    ]

    body = f"""<header class="page-head">
  <h1>PresenceLens Attendance &mdash; post-implementation UI reference</h1>
  <p>Rendered directly from the shipped Compose source
  (<code>android-attendance/app/src/main/java/.../presentation/attendance/</code>), parsed
  <code>strings.xml</code> copy, and the project's own vector icons. Authority order: shipped
  source &gt; the verified v1.0.0 runtime screenshot &gt; <code>docs/android/UX_SPEC.md</code> &gt;
  this HTML. <b>The application is never modified to match this reference; this reference is
  modified to match the application.</b></p>
  <p>Only <b>02-tracking-ready</b> has committed Native runtime screenshot evidence
  (<code>docs/assets/android/attendance-ready.png</code>), captured at 2 m and shown here as
  that page's primary frame. Every other family is deterministic-preview-backed or, for two
  kinds with no preview (<code>PRECISE_BLOCKED</code>, <code>LOCATION_UNAVAILABLE_PROVIDER</code>),
  derived directly from source and labelled as such.</p>
  <p>Primary viewport: <b>{RELEASE_WIDTH:.4f} &times; {RELEASE_HEIGHT:.0f} CSS px</b> (the release-evidence
  frame, measured from the six committed v1.0.0 screenshots at 1280&times;2800 physical px,
  density 3.5). This is a review frame, not a claim about the capture device's own logical
  resolution. Toggle theme per page with <code>?theme=dark</code> / <code>?theme=light</code>;
  screenshot-backed pages default to dark.</p>
  <div class="gate">Post-implementation UI reference &mdash; Gate B2</div>
</header>
<div class="stage">
{''.join(cards)}
</div>
<section class="page-notes">
  <h2>Modifier / overlay gallery</h2>
  <p>These are variants of components already on the nine pages above, not standalone
  reference pages (there is no tenth family).</p>
  <div class="stage stage--gallery">
  {''.join(overlay_cards)}
  </div>
</section>"""
    return page_wrapper(
        title="PresenceLens Attendance - post-implementation UI reference index",
        default_theme="dark", breadcrumb_extra="", body=body,
    )


TOKENS_CSS_TEMPLATE = """/* PresenceLens Attendance - design tokens.
   GENERATED by _build_references.py from Color.kt, StatusColors.kt, Shape.kt and Type.kt.
   Do not hand-edit; regenerate instead.

   Light is the bare :root definition; dark is layered on top under both
   prefers-color-scheme and an explicit [data-theme] override so the ?theme= query
   parameter always wins. */

:root {{
  /* release-evidence viewport (measured from the six v1.0.0 screenshots: 1280x2800
     physical px @ density 3.5) - the PRIMARY fidelity/validation frame */
  --release-width: {release_width}px;
  --release-height: {release_height}px;
  --safe-top: {safe_top}px;
  --safe-bottom: {safe_bottom}px;

  /* secondary responsive review frame (historical 390x844) - never the comparison target */
  --responsive-width: {responsive_width}px;
  --responsive-height: {responsive_height}px;

{light_vars}
}}

:root[data-theme="dark"] {{
{dark_vars}
}}

@media (prefers-color-scheme: dark) {{
  :root:not([data-theme="light"]) {{
{dark_vars}
  }}
}}
"""


def _css_vars(colors: dict) -> str:
    return "\n".join(f"  --{name}: {value};" for name, value in colors.items())


def write_tokens_css() -> str:
    return TOKENS_CSS_TEMPLATE.format(
        release_width=f"{RELEASE_WIDTH:.7f}", release_height=f"{RELEASE_HEIGHT:.0f}",
        safe_top=f"{SAFE_TOP:.7f}", safe_bottom=f"{SAFE_BOTTOM:.7f}",
        responsive_width=RESPONSIVE_WIDTH, responsive_height=RESPONSIVE_HEIGHT,
        light_vars=_css_vars(COLORS_LIGHT), dark_vars=_css_vars(COLORS_DARK),
    )


def _type_css(name: str) -> str:
    size, line_height, weight, tracking = TYPE[name]
    return f".{name} {{ font-size:{size}px; line-height:{line_height}px; font-weight:{weight}; letter-spacing:{tracking}px; }}"


SCREENS_CSS_TEMPLATE = """/* PresenceLens Attendance - post-implementation UI reference layout.
   GENERATED by _build_references.py. Renders the shipped AttendanceScreen composition at
   the release-evidence viewport. Not the production implementation - the production source
   of truth remains the Compose source under android-attendance/. */

* {{ box-sizing: border-box; }}

body {{
  margin: 0;
  font-family: "Roboto", "Segoe UI", system-ui, -apple-system, sans-serif;
  background: var(--surface);
  color: var(--on-surface);
  -webkit-font-smoothing: antialiased;
}}

{type_rules}

.breadcrumb {{ max-width: 1180px; margin: 16px auto 0; padding: 0 24px; }}
.breadcrumb a {{ color: var(--primary); text-decoration: none; font-size: 14px; }}

.theme-toggle {{ max-width: 1180px; margin: 6px auto 0; padding: 0 24px; font-size: 13px; color: var(--on-surface-variant); }}
.theme-toggle a {{ color: var(--primary); text-decoration: none; }}
.theme-toggle__default {{ margin-left: 6px; }}

.page-head {{ max-width: 1180px; margin: 0 auto; padding: 24px 24px 8px; }}
.page-head h1 {{ font-size: 26px; font-weight: 650; margin: 0 0 10px; letter-spacing: -.01em; }}
.page-head p {{ margin: 0 0 10px; color: var(--on-surface-variant); font-size: 14.5px; line-height: 1.55; max-width: 76ch; }}
.gate {{
  display: inline-block; margin-top: 6px; padding: 8px 14px; border-radius: 999px;
  background: var(--primary-container); color: var(--on-primary-container);
  font-size: 12.5px; font-weight: 650; letter-spacing: .02em;
}}

.stage {{
  max-width: 1400px; margin: 0 auto; padding: 24px;
  display: grid; gap: 44px 36px;
  grid-template-columns: repeat(auto-fit, {release_width}px);
  justify-content: center;
}}
.stage--standalone {{ grid-template-columns: repeat(auto-fit, {release_width}px); padding-top: 32px; }}
.stage--gallery {{ grid-template-columns: repeat(auto-fit, minmax(260px, 340px)); }}

.screen-card {{ margin: 0; width: {release_width}px; display: flex; flex-direction: column; gap: 12px; }}
.screen-card--gallery {{ width: auto; }}
.screen-card figcaption b {{ display: block; font-size: 14px; font-weight: 650; margin-bottom: 3px; }}
.screen-card figcaption a {{ color: var(--on-surface); text-decoration: none; }}
.screen-card figcaption .evidence {{ font-size: 12px; color: var(--on-surface-variant); margin: 0 0 3px; line-height: 1.5; }}
.screen-card figcaption .precondition {{ font-size: 12px; color: var(--on-surface-variant); margin: 0; line-height: 1.5; font-style: italic; }}
.screen-card figcaption .notes {{ font-size: 12px; color: var(--on-surface-variant); margin: 3px 0 0; }}

.page-notes {{ max-width: 1180px; margin: 8px auto 48px; padding: 0 24px; color: var(--on-surface-variant); }}
.page-notes h2 {{ font-size: 16px; color: var(--on-surface); }}
.kind-list {{ font-size: 13px; line-height: 1.9; }}
.kind-list code {{ background: var(--surface-container); padding: 1px 6px; border-radius: 5px; }}

.gallery-frame {{ background: var(--surface-container-low); border-radius: 24px; padding: 16px; max-width: 340px; }}
.gallery-frame--sheet {{ background: var(--surface-container-low); }}
.gallery-frame--dialog {{ background: var(--surface-container-high); }}

/* ---------------- phone frame: the release-evidence viewport ---------------- */
.phone {{
  position: relative; width: var(--release-width); height: var(--release-height); flex: none;
  border-radius: 32px; overflow: hidden; background: var(--background);
  box-shadow: 0 1px 2px rgba(0,0,0,.18), 0 18px 40px -12px rgba(0,0,0,.30);
}}
.system-inset {{ position: absolute; left: 0; right: 0; background: var(--background); z-index: 2; pointer-events: none; }}
.system-inset--top {{ top: 0; height: var(--safe-top); }}
.system-inset--bottom {{ bottom: 0; height: var(--safe-bottom); }}
.app-content {{
  position: absolute; left: 0; right: 0; top: var(--safe-top); bottom: var(--safe-bottom);
  overflow-y: auto; display: flex; flex-direction: column; background: var(--background);
}}

/* ---------------- top app bar ---------------- */
.topbar {{
  display: flex; align-items: center; justify-content: space-between;
  min-height: 64px; padding: 0 4px; flex: none; background: var(--background); color: var(--on-background);
}}
.topbar .title-large {{ flex: 1; }}
.icon-button {{
  width: 48px; height: 48px; border: none; background: none; color: inherit;
  display: grid; place-items: center; cursor: pointer; padding: 0;
}}

/* ---------------- content column ---------------- */
.content {{
  flex: 1; display: flex; flex-direction: column;
  padding: 2px {screen_pad}px 24px;
}}
.section-gap {{ margin-top: {section_gap}px; }}

/* ---------------- status banner ---------------- */
.status-banner {{
  display: flex; gap: 14px; border-radius: 24px; padding: 16px; padding-bottom: 16px;
}}
.status-banner.has-action {{ padding-bottom: 6px; }}
.status-banner__badge {{
  width: {badge}px; height: {badge}px; border-radius: 50%; flex: none;
  display: grid; place-items: center;
}}
.status-banner__text {{ display: flex; flex-direction: column; gap: 4px; padding-top: 2px; }}
.status-banner__title {{ margin: 0; }}
.status-banner__body {{ margin: 0; }}
.status-banner__action {{
  border: none; background: none; display: inline-flex; align-items: center; gap: 8px;
  min-height: 48px; padding: 0; color: inherit; cursor: pointer; align-self: flex-start;
}}
.status-banner--degraded {{ margin: 0; }}

.spinner {{
  border: 2px solid color-mix(in srgb, currentColor 24%, transparent);
  border-top-color: currentColor; border-radius: 50%; animation: spin .8s linear infinite;
}}
@keyframes spin {{ to {{ transform: rotate(360deg); }} }}

/* ---------------- office context card ---------------- */
.office-card {{
  background: var(--surface-container-low); border-radius: 32px; padding: {card_pad_v}px {card_pad_h}px;
}}
.office-card__header {{ display: flex; align-items: center; gap: 0; margin-bottom: 12px; }}
.office-card__header .overline {{ flex: 1; }}
.status-dot {{ width: 8px; height: 8px; border-radius: 50%; display: inline-block; margin-right: 8px; }}
.office-face {{ display: flex; flex-direction: column; gap: 6px; margin-top: 14px; }}
.office-face p {{ margin: 0; }}
.capturing-note {{ margin: 6px 0 0; color: var(--on-surface-variant); }}

.filled-button, .mark-button {{
  min-height: {primary_button}px; border-radius: 16px; border: none; cursor: pointer;
  display: inline-flex; align-items: center; justify-content: center; gap: 10px;
  width: 100%; margin-top: 4px;
}}
/* OfficeSetup's Button (OfficeContextCard.kt) takes no explicit colours, so it renders
   Material 3's own ButtonDefaults - primary/onPrimary enabled, onSurface@12%/onSurface@38%
   disabled. */
.filled-button {{ background: var(--primary); color: var(--on-primary); }}
.filled-button:disabled {{
  background: color-mix(in srgb, var(--on-surface) 12%, transparent);
  color: color-mix(in srgb, var(--on-surface) 38%, transparent);
  cursor: default;
}}
/* PendingAttendancePanel's Mark Attendance button explicitly overrides ButtonDefaults with
   statusColors.success/onSuccess, and a distinct disabled pair
   (surfaceContainerHighest / onSurfaceVariant@62%) - AttendanceActionPanel.kt:191-196. */
.mark-button {{ background: var(--success); color: var(--on-success); }}
.mark-button:disabled {{
  background: var(--surface-container-highest);
  color: color-mix(in srgb, var(--on-surface-variant) 62%, transparent);
  cursor: default;
}}
.text-button {{
  min-height: {min_touch}px; border: none; background: none; color: var(--primary);
  display: inline-flex; align-items: center; gap: 8px; cursor: pointer; padding: 0; width: fit-content;
}}
/* "Change office location" takes no explicit colours (OfficeContextCard.kt), so its disabled
   state is plain Material 3 ButtonDefaults.textButtonColors() - onSurface@38% - not the
   Mark Attendance button's explicit onSurfaceVariant@62% override. */
.text-button:disabled {{ color: color-mix(in srgb, var(--on-surface) 38%, transparent); cursor: default; }}

/* ---------------- location surface (plan view) ---------------- */
.location-surface {{
  position: relative; border-radius: 24px; overflow: hidden;
  background: linear-gradient(var(--surface-container-high), var(--surface-container-low));
}}
.location-surface__plan {{ display: block; }}
.surface-legend {{ position: absolute; top: 12px; left: 12px; display: flex; flex-direction: column; gap: 6px; }}
.surface-legend__entry {{ display: flex; align-items: center; gap: 7px; color: var(--on-surface-variant); }}
.dot {{ width: 8px; height: 8px; border-radius: 50%; display: inline-block; flex: none; }}
.surface-pill {{
  position: absolute; background: color-mix(in srgb, var(--surface-container-lowest) 86%, transparent);
  color: var(--on-surface-variant); border-radius: 999px; padding: 5px 10px;
}}
.surface-pill--radius {{ top: 12px; right: 12px; }}
.surface-pill--coord {{
  bottom: 12px; left: 12px; display: flex; align-items: center; gap: 10px; padding: 9px 14px;
  border-radius: 12px; background: color-mix(in srgb, var(--surface-container-lowest) 92%, transparent);
  color: var(--on-surface);
}}
.surface-pill--coord .dot {{ background: var(--primary); }}

/* ---------------- proximity card / distance gauge ---------------- */
.proximity-card {{
  background: var(--surface-container-low); border-radius: 32px; padding: {card_pad_v}px {card_pad_h}px;
  display: flex; flex-direction: column; align-items: center; gap: 12px;
}}
.gauge {{ position: relative; width: {gauge}px; height: {gauge}px; display: grid; place-items: center; }}
.gauge svg {{ position: absolute; inset: 0; }}
.gauge__readout {{ display: flex; align-items: baseline; }}
.gauge__value {{ color: var(--on-surface); }}
.gauge__unit {{ color: var(--on-surface-variant); margin-left: 2px; }}
.gauge__caption {{ position: absolute; bottom: 30px; color: var(--on-surface-variant); }}
.proximity-readout {{ display: flex; flex-direction: column; align-items: center; gap: 8px; }}
.proximity-readout p {{ margin: 0; }}
.range-chip {{ display: inline-flex; align-items: center; gap: 8px; border-radius: 999px; padding: 9px 16px; }}

/* ---------------- attendance action panel ---------------- */
.action-panel {{
  border-radius: 24px; padding: {card_pad_v}px {card_pad_h}px;
  display: flex; flex-direction: column; align-items: center; gap: 10px;
}}
.action-panel--enabled {{ border: 1.5px solid var(--success); }}
.action-panel--blocked {{ border: 1.5px dashed var(--outline-variant); }}
.action-panel__header {{ display: flex; align-items: center; gap: 10px; }}
.inline-note {{ display: flex; align-items: center; gap: 8px; justify-content: center; margin: 0; }}
.divider {{ width: 100%; height: 1px; background: color-mix(in srgb, var(--outline-variant) 70%, transparent); margin-top: 2px; }}
.office-hours {{ display: flex; align-items: center; gap: 8px; }}
.office-hours span {{ margin: 0; }}

.action-panel--completed {{ align-items: stretch; }}
.confirmation-row {{
  display: flex; align-items: center; gap: 14px; padding: 14px 16px; border-radius: 24px;
  background: var(--surface-container-low); color: var(--on-surface);
}}
.confirmation-badge {{
  width: {confirmation_badge}px; height: {confirmation_badge}px; border-radius: 50%;
  background: var(--success-container); display: grid; place-items: center; flex: none;
}}
.confirmation-text {{ flex: 1; min-width: 0; }}
.confirmation-text p {{ margin: 0; }}

/* ---------------- overlays: sheet / dialog / snackbar ---------------- */
.sheet {{ display: flex; flex-direction: column; gap: 6px; padding: 8px 4px; }}
.sheet p {{ margin: 0; }}
.disclosure-list {{ display: flex; flex-direction: column; gap: 20px; margin-top: 18px; }}
.disclosure-row {{ display: flex; gap: 16px; }}
.disclosure-row__badge {{
  width: 40px; height: 40px; border-radius: 50%; background: var(--secondary-container);
  display: grid; place-items: center; flex: none;
}}
.dialog {{ display: flex; flex-direction: column; gap: 10px; }}
.dialog__actions {{ display: flex; justify-content: flex-end; gap: 8px; margin-top: 8px; }}
.snackbar {{
  background: var(--inverse-surface); color: var(--inverse-on-surface); border-radius: 12px;
  padding: 14px 16px; max-width: 340px;
}}

/* ---------------- bare mode: isolates one phone frame for pixel-diff tooling ----------------
   Review/validation affordance only (?bare=1), analogous to the historical prototypes'
   body.standalone class. Never part of the fidelity claim itself. */
html.bare body {{ margin: 0; background: var(--background); }}
html.bare .breadcrumb, html.bare .theme-toggle, html.bare .page-notes,
html.bare figcaption, html.bare .page-head {{ display: none; }}
html.bare .stage {{ display: block; padding: 0; margin: 0; max-width: none; }}
html.bare .screen-card {{ width: auto; }}
html.bare .screen-card ~ .screen-card {{ display: none; }}
html.bare .phone {{ border-radius: 0; box-shadow: none; }}
html.tall .phone {{ height: auto; }}
html.tall .app-content {{ position: static; overflow: visible; height: auto; }}
html.tall .system-inset--bottom {{ position: static; height: var(--safe-bottom); }}
"""


def write_screens_css() -> str:
    return SCREENS_CSS_TEMPLATE.format(
        type_rules="\n".join(_type_css(name) for name in TYPE),
        release_width=f"{RELEASE_WIDTH:.4f}",
        screen_pad=SCREEN_PAD_H, section_gap=SECTION_GAP, badge=BADGE_SIZE,
        card_pad_v=CARD_PAD_V, card_pad_h=CARD_PAD_H, primary_button=PRIMARY_BUTTON_HEIGHT,
        min_touch=MIN_TOUCH_TARGET, gauge=GAUGE_SIZE, confirmation_badge=CONFIRMATION_BADGE,
    )


def main() -> None:
    (HERE / "tokens.css").write_text(write_tokens_css(), encoding="utf-8")
    (HERE / "screens.css").write_text(write_screens_css(), encoding="utf-8")
    for fam in FAMILIES:
        (HERE / f"{fam['slug']}.html").write_text(render_family_page(fam), encoding="utf-8")
    (HERE / "index.html").write_text(render_index(), encoding="utf-8")

    print("wrote:")
    for f in sorted(HERE.glob("*.css")) + sorted(HERE.glob("*.html")):
        digest = hashlib.sha256(f.read_bytes()).hexdigest()[:12]
        print(f"  {f.name:40s} {f.stat().st_size:6d}B  sha256:{digest}")


if __name__ == "__main__":
    main()
