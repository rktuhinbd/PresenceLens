# Native Android — post-implementation UI reference

**Purpose.** These nine HTML pages let a reviewer place the shipped Compose UI beside a browser rendering derived directly from that same source, without an emulator or a physical device. They are generated, not hand-authored: run `python docs/android/design/_build_references.py` to reproduce them from the current source tree.

## Authority order

1. **Shipped Compose source** — `android-attendance/app/src/main/java/.../attendance/presentation/attendance/**`, `.../attendance/ui/theme/**`, `android-attendance/app/src/main/res/values/strings.xml`, `android-attendance/app/src/main/res/drawable/*.xml`.
2. **The verified v1.0.0 runtime screenshot** — `docs/assets/android/attendance-ready.png`.
3. **[docs/android/UX_SPEC.md](../UX_SPEC.md)**.
4. **This generated HTML.**

**The application is never modified to match these references. These references are modified to match the application.** If a page and the app ever disagree, the app is right and the generator has a bug.

## Release-evidence viewport

The primary fidelity/validation frame is **365.7142857 × 800 CSS px** (`--release-width` / `--release-height`), measured from the six committed v1.0.0 screenshots (1280×2800 physical px at a derived density of 3.5). This is a *review* frame, not a claim about the capture device's own reported logical resolution. System bars are not drawn as fake chrome — `--safe-top` (40.2857px) and `--safe-bottom` (22.2857px) reserve their layout space as blank bands of the screen's own background colour, and the actual app content (`TopAppBar` onward) begins exactly where it begins in the screenshot.

A **secondary responsive review mode** exists as CSS variables (`--responsive-width`/`--responsive-height`, 390×844, the historical frame) but is not wired into the page layout and is never the comparison target — it is retained only in case a reviewer wants an alternate width to eyeball reflow.

Every page accepts `?theme=dark` / `?theme=light` to force a theme regardless of the browser's own preference; all nine default to **dark**, matching the only committed runtime evidence. Light rendering is entirely source-derived (`Color.kt`'s light block, `LightStatusColors`) — no light screenshot exists, and no page claims one.

Two additional query parameters exist purely as review/validation tooling, analogous to the historical prototypes' `body.standalone` class — neither is part of the fidelity claim: `?bare=1` isolates a single phone frame (drops the breadcrumb, theme toggle, and figcaption) for pixel-diff tooling, and `?tall=1` lets the phone's internal scrolling content column render to its natural height instead of clipping at 800px, for reviewing content below the fold.

## Source-backed vs. screenshot-backed states

Only **`02-tracking-ready.html`** has committed Native runtime screenshot evidence (`docs/assets/android/attendance-ready.png`, captured at 2 m; shown as that page's primary frame, with the 32 m `@Preview` fixture as a secondary variant). Every other page is backed by a deterministic Compose `@Preview` in `AttendanceScreenPreviews.kt`. Two kinds have neither a preview nor a screenshot — `PRECISE_BLOCKED` and `LOCATION_UNAVAILABLE_PROVIDER` — and are derived directly from source (their sibling kind's geometry, with the one differing string substituted); both are labelled "no-preview variant" on their pages. See [UX_SPEC.md §4](../UX_SPEC.md#4-reference-family-mapping-gate-b2) for the full kind → page mapping.

## Renderer limitations (stated, not hidden)

- **Fonts.** Neither app bundles a typeface (`FontFamily.Default`); the reference uses a system stack that prefers Roboto where available, falling back to the platform default. Line-breaking and glyph rendering will not match Compose's own text layout exactly.
- **Dashed outline pitch.** `AttendanceActionPanel`'s locked/unlocked border is drawn in Compose with an exact `(9, 7)` dash pattern via `PathEffect.dashPathEffect`. The reference uses a plain CSS `border: dashed`, which is geometrically identical (width, colour, 24px radius, solid-vs-dashed) but not identical in dash segment length, since browsers compute their own dash spacing for rounded borders.
- **The "you are here" marker's breathing halo** is rendered at rest (a single static frame) rather than mid-animation; the live device's 2.4s pulse has no single "correct" phase to reproduce statically.
- **Representative timestamps.** `TimestampFormatter` output is locale/timezone-dependent and cannot be reproduced deterministically by a static page. The runtime-backed page uses the exact string visible in the release screenshot ("Aug 30, 2026 10:38 PM"); preview-backed pages render the preview fixture's `MARKED_AT_EPOCH_MILLIS` constant in UTC. Neither is computed live.
- **No claim of pixel identity.** Browser and Compose are different rendering engines; anti-aliasing, sub-pixel text metrics, and platform chrome are expected to differ.

No CDN or network dependency exists anywhere in the generated output; every icon is inlined SVG built from the project's own vector drawables.
