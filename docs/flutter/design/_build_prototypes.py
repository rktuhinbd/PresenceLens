"""Regenerates the static visual prototypes in this directory.

OPTIONAL TOOLING. Nothing in the Flutter build depends on this script, and a
reviewer never needs to run it - the .html files beside it are self-contained
and open directly in any browser.

It exists because the seven screens share one token set and one component
vocabulary. Hand-maintaining seven copies of that would guarantee they drift,
and the whole point of the artefacts is that they show a consistent system.

    python docs/flutter/design/_build_prototypes.py

Authority for the design itself is docs/flutter/UX_SPEC.md; this renders it.
"""

import pathlib

OUT = pathlib.Path(__file__).resolve().parent

# ---------------------------------------------------------------- tokens.css
TOKENS = """/* PresenceLens Capture - design tokens.
   Generated artefact. The authority is docs/flutter/UX_SPEC.md section 2.

   Two palettes live here on purpose:
   - Application surfaces follow the Material 3 scheme and respond to
     prefers-color-scheme (FLT-UX-008).
   - Camera surfaces are FIXED DARK and deliberately ignore the system theme
     (ADR-F07), because the content behind them is always a live image. */

:root {
  /* --- seed ------------------------------------------------------------ */
  --seed: #00A884;

  /* --- application surfaces, light ------------------------------------- */
  --primary:            #006B58;
  --on-primary:         #FFFFFF;
  --primary-container:  #82F8D8;
  --on-primary-container:#002019;
  --tertiary:           #3F6375;
  --on-tertiary:        #FFFFFF;
  --error:              #BA1A1A;
  --on-error:           #FFFFFF;
  --error-container:    #FFDAD6;
  --surface:            #F5FBF7;
  --surface-container:  #E9EFEB;
  --surface-container-high:#E3E9E5;
  --on-surface:         #171D1B;
  --on-surface-variant: #3F4945;
  --outline-variant:    #BFC9C4;
  --scrim-page:         rgba(0,0,0,.06);

  /* --- camera surfaces, FIXED (never themed) --------------------------- */
  --cam-control:        rgba(255,255,255,.92);
  --cam-control-dim:    rgba(255,255,255,.62);
  --cam-control-bg:     rgba(0,0,0,.45);
  /* Active state is the ACCENT on a darker pill, not white-on-translucent-white.
     The prototype showed the latter washing out over a bright document. */
  --cam-control-active: #00E5A8;
  --cam-control-active-bg: rgba(0,0,0,.62);
  --cam-shutter:        #FFFFFF;
  --cam-accent:         #00E5A8;
  --cam-warning:        #FFB74D;

  /* --- spacing (4dp grid) ---------------------------------------------- */
  --s1: 4px; --s2: 8px; --s3: 12px; --s4: 16px; --s6: 24px; --s8: 32px; --s12: 48px;

  /* --- shape ------------------------------------------------------------ */
  --r-card: 16px; --r-row: 12px; --r-thumb: 8px; --r-full: 999px;

  /* --- type ------------------------------------------------------------- */
  --font: "Inter", "Roboto", -apple-system, "Segoe UI", system-ui, sans-serif;
}

@media (prefers-color-scheme: dark) {
  :root {
    --primary:            #65DBBB;
    --on-primary:         #00382C;
    --primary-container:  #005140;
    --on-primary-container:#82F8D8;
    --tertiary:           #A7CBE0;
    --on-tertiary:        #0B3446;
    --error:              #FFB4AB;
    --on-error:           #690005;
    --error-container:    #93000A;
    --surface:            #0E1513;
    --surface-container:  #1A211F;
    --surface-container-high:#242B29;
    --on-surface:         #DDE4E0;
    --on-surface-variant: #BFC9C4;
    --outline-variant:    #3F4945;
    --scrim-page:         rgba(0,0,0,.5);
  }
}
"""

# ---------------------------------------------------------------- screens.css
SCREENS = """/* PresenceLens Capture - prototype layout.
   These styles exist to render STATIC review artefacts. They are not the
   production implementation and are not ported to Flutter verbatim; the
   production source of truth is docs/flutter/UX_SPEC.md. */

* { box-sizing: border-box; }

body {
  margin: 0;
  font-family: var(--font);
  background: var(--surface);
  color: var(--on-surface);
  -webkit-font-smoothing: antialiased;
}

/* ---------- gallery chrome ---------- */
.page-head { max-width: 1180px; margin: 0 auto; padding: 40px 24px 8px; }
.page-head h1 { font-size: 26px; font-weight: 650; margin: 0 0 6px; letter-spacing: -.01em; }
.page-head p  { margin: 0 0 4px; color: var(--on-surface-variant); font-size: 14.5px; line-height: 1.55; max-width: 68ch; }
.gate {
  display:inline-block; margin-top:14px; padding:8px 14px; border-radius: var(--r-full);
  background: var(--primary-container); color: var(--on-primary-container);
  font-size: 12.5px; font-weight: 650; letter-spacing: .02em;
}

.stage {
  max-width: 1320px; margin: 0 auto; padding: 24px;
  display: grid; gap: 44px 36px;
  grid-template-columns: repeat(auto-fit, 390px);
  justify-content: center;
}
body.standalone .stage { grid-template-columns: 390px; padding-top: 40px; }

.screen-card { margin: 0; width: 390px; display: flex; flex-direction: column; gap: 14px; }
.screen-card figcaption { font-size: 13px; line-height: 1.5; color: var(--on-surface-variant); }
.screen-card figcaption b { display:block; color: var(--on-surface); font-size: 14px; font-weight: 650; margin-bottom: 3px; }
.screen-card figcaption code {
  font-family: ui-monospace, "Cascadia Code", Consolas, monospace; font-size: 11.5px;
  background: var(--surface-container); padding: 1px 5px; border-radius: 5px;
}

/* ---------- phone frame ----------
   Fixed 390x844 (a common Android logical viewport). Everything inside is
   authored against that box: percentages for layout, em for type off a 16px
   root. Fixed rather than fluid so the proportions a reviewer signs off on are
   the proportions that were designed. */
.phone {
  position: relative; width: 390px; height: 844px; flex: none;
  font-size: 16px; line-height: 1.35;
  border-radius: 40px; overflow: hidden; background: #000;
  box-shadow: 0 1px 2px rgba(0,0,0,.18), 0 18px 40px -12px rgba(0,0,0,.34);
}
.phone > .layer { position: absolute; inset: 0; width: 100%; height: 100%; }

/* ---------- camera ---------- */
.cam-scrim-top {
  position:absolute; left:0; right:0; top:0; height: 24%;
  background: linear-gradient(to bottom, rgba(0,0,0,.72), rgba(0,0,0,.34) 48%, rgba(0,0,0,0));
  pointer-events:none;
}
/* Deliberately strong. The subject may be a bright document in daylight, and
   every control below sits on top of it (RU-02, contrast >= 4.5:1). */
.cam-scrim-bottom {
  position:absolute; left:0; right:0; bottom:0; height: 42%;
  background: linear-gradient(to top, rgba(0,0,0,.88), rgba(0,0,0,.66) 34%, rgba(0,0,0,.30) 66%, rgba(0,0,0,0));
  pointer-events:none;
}

.cam-topbar {
  position:absolute; left:0; right:0; top: 5.6%;
  display:flex; align-items:center; justify-content:space-between;
  padding: 0 4.1%;
}
.cbtn {
  width: 48px; height: 48px; flex: none; border-radius: var(--r-full);
  background: var(--cam-control-bg);
  display:grid; place-items:center; color: var(--cam-control);
  backdrop-filter: blur(6px);
}
.cbtn svg { width: 52%; height: 52%; }

.chip-offline {
  display:flex; align-items:center; gap: .45em; min-height: 36px;
  padding: 0 12px; border-radius: var(--r-full);
  background: rgba(0,0,0,.42); backdrop-filter: blur(6px);
  color: var(--cam-warning); font-size: .72em; font-weight: 600; letter-spacing:.01em;
  white-space: nowrap;
}
.chip-offline svg { width: 1.05em; height: 1.05em; }

.uploads-entry {
  display:flex; align-items:center; gap: .4em; min-height: 48px;
  padding: 0 10px 0 14px; border-radius: var(--r-full);
  background: rgba(0,0,0,.42); backdrop-filter: blur(6px);
  color: var(--cam-control); font-size: .74em; font-weight: 600;
}
.uploads-entry .n {
  min-width: 1.55em; height: 1.55em; padding: 0 .3em; border-radius: var(--r-full);
  background: var(--cam-accent); color: #00281E;
  display:grid; place-items:center; font-size: .82em; font-weight: 700;
}
.uploads-entry svg { width: .9em; height: .9em; opacity:.75; }

/* focus reticle */
.reticle { position:absolute; width: 18.5%; aspect-ratio:1; transform: translate(-50%,-50%); }
.reticle .ring {
  position:absolute; inset:0; border: 1.6px solid var(--cam-accent); border-radius: var(--r-full);
  box-shadow: 0 0 0 1px rgba(0,0,0,.28), 0 0 14px rgba(0,229,168,.45);
}
.reticle .tick { position:absolute; background: var(--cam-accent); }
.reticle .t1 { left:50%; top:-9%; width:1.6px; height:11%; transform:translateX(-50%); }
.reticle .t2 { left:50%; bottom:-9%; width:1.6px; height:11%; transform:translateX(-50%); }
.reticle .t3 { top:50%; left:-9%; height:1.6px; width:11%; transform:translateY(-50%); }
.reticle .t4 { top:50%; right:-9%; height:1.6px; width:11%; transform:translateY(-50%); }

/* zoom slider */
.zoom {
  position:absolute; right: 4.1%; top: 44%; transform: translateY(-50%);
  width: 10.3%; height: 30%;
  border-radius: var(--r-full); background: rgba(0,0,0,.48); backdrop-filter: blur(6px);
  display:flex; flex-direction:column; align-items:center; justify-content:space-between;
  padding: .55em 0; color: var(--cam-control-dim); font-size: .62em; font-weight:600;
}
.zoom .track {
  position:relative; flex:1; width: 2.5px; margin: .5em 0;
  background: rgba(255,255,255,.28); border-radius: var(--r-full);
}
.zoom .fill { position:absolute; left:0; right:0; bottom:0; background: var(--cam-control); border-radius: var(--r-full); }
.zoom .thumb {
  position:absolute; left:50%; width: 1.05em; height: 1.05em; border-radius: var(--r-full);
  background: var(--cam-shutter); transform: translate(-50%, 50%);
  box-shadow: 0 1px 4px rgba(0,0,0,.5);
}
.zoom-readout {
  position:absolute; right: 17%; top: 44%; transform: translateY(-50%);
  background: rgba(0,0,0,.5); backdrop-filter: blur(6px);
  color: var(--cam-control-active); font-size:.72em; font-weight:700;
  padding: .3em .6em; border-radius: var(--r-full);
}

/* zoom presets */
.presets {
  position:absolute; left:0; right:0; bottom: 25.5%;
  display:flex; justify-content:center; gap: .6em;
}
.preset {
  min-width: 48px; height: 48px; padding: 0 10px; border-radius: var(--r-full);
  background: var(--cam-control-bg); backdrop-filter: blur(6px);
  color: rgba(255,255,255,.80); font-size: .8em; font-weight: 650;
  display:grid; place-items:center; font-variant-numeric: tabular-nums;
}
.preset.on {
  background: var(--cam-control-active-bg); color: var(--cam-control-active);
  font-weight: 750; box-shadow: inset 0 0 0 1.5px rgba(0,229,168,.55);
}

/* bottom bar */
.cam-bottom {
  position:absolute; left:0; right:0; bottom: 10.5%;
  display:flex; align-items:center; justify-content:space-between; padding: 0 8%;
}
.shutter {
  width: 72px; height: 72px; flex: none; border-radius: var(--r-full);
  border: 3px solid var(--cam-shutter); display:grid; place-items:center;
}
.shutter i { display:block; width: 84%; height: 84%; border-radius: var(--r-full); background: var(--cam-shutter); }
.thumbstack { position:relative; width: 56px; height: 56px; flex: none; }
.thumbstack .sheet {
  position:absolute; inset:0; border-radius: var(--r-thumb); overflow:hidden;
  border: 1.5px solid rgba(255,255,255,.55); background:#2A3330;
}
.thumbstack .sheet.b2 { transform: translate(-5%, -5%) rotate(-5deg); opacity:.55; }
.thumbstack .sheet.b1 { transform: translate(-2.5%, -2.5%) rotate(-2.5deg); opacity:.8; }
.thumbstack .count {
  position:absolute; right:-18%; top:-18%;
  min-width: 1.5em; height: 1.5em; padding: 0 .25em; border-radius: var(--r-full);
  background: var(--cam-accent); color:#00281E; font-size:.72em; font-weight:750;
  display:grid; place-items:center; border: 1.5px solid rgba(0,0,0,.35);
}
.flip { width: 48px; height: 48px; flex: none; border-radius: var(--r-full);
  background: var(--cam-control-bg); backdrop-filter: blur(6px);
  display:grid; place-items:center; color: var(--cam-control); }
.flip svg { width:52%; height:52%; }

.batch-cta {
  position:absolute; left:50%; transform:translateX(-50%); bottom: 4.2%;
  display:flex; align-items:center; gap:.5em; min-height: 48px;
  padding: 0 22px; border-radius: var(--r-full);
  background: var(--cam-accent); color:#00281E;
  font-size:.82em; font-weight:700; letter-spacing:.005em;
  box-shadow: 0 4px 16px rgba(0,229,168,.28);
}
.batch-cta svg { width:1.05em; height:1.05em; }

/* camera error panel */
.cam-error {
  position:absolute; inset:0; background: #0B0F0E;
  display:flex; flex-direction:column; align-items:center; justify-content:center;
  text-align:center; padding: 0 12%;
}
.cam-error .ic {
  width: 20%; aspect-ratio:1; border-radius: var(--r-full);
  background: rgba(255,255,255,.07); display:grid; place-items:center;
  color: var(--cam-warning); margin-bottom: 1.4em;
}
.cam-error .ic svg { width:48%; height:48%; }
.cam-error h2 { margin:0 0 .5em; font-size:1.18em; font-weight:650; color: rgba(255,255,255,.95); }
.cam-error p  { margin:0 0 1.9em; font-size:.87em; line-height:1.55; color: rgba(255,255,255,.62); }
.cam-error .act {
  min-height: 48px; display:grid; place-items:center;
  padding: 0 26px; border-radius: var(--r-full);
  background: var(--cam-accent); color:#00281E; font-size:.85em; font-weight:700;
}
.cam-error .act2 { margin-top:1.1em; min-height:44px; display:grid; place-items:center; font-size:.82em; font-weight:600; color: rgba(255,255,255,.72); }

/* ---------- upload manager ---------- */
.um { position:absolute; inset:0; background: var(--surface); display:flex; flex-direction:column; }
.um-top {
  display:flex; align-items:center; gap:.7em; padding: 4.4em 4.6% 1.1em;
  font-size:1em;
}
.um-top .back { width:48px; height:48px; margin-left:-12px; flex:none;
  display:grid; place-items:center; color: var(--on-surface); }
.um-top .back svg { width:26px; height:26px; }
.um-top h2 { margin:0; font-size:1.28em; font-weight:640; letter-spacing:-.01em; }

.um-body { flex: 1 1 auto; min-height: 0; overflow: hidden; padding: 0 4.6%; }

.link-chip {
  display:flex; align-items:center; gap:.6em;
  padding: .85em 1em; border-radius: var(--r-row);
  background: var(--surface-container); color: var(--on-surface-variant);
  font-size:.85em; font-weight:600; margin-bottom: 1.7em;
}
.link-chip svg { width:1.15em; height:1.15em; flex:none; }
.link-chip.ok  { color: var(--primary); }
.link-chip.off { color: var(--on-surface-variant); }

.batch-head {
  display:flex; align-items:baseline; justify-content:space-between;
  margin: 0 0 .8em; font-size:.75em;
}
.batch-head .ttl { font-weight:700; letter-spacing:.09em; text-transform:uppercase; color: var(--on-surface-variant); }
.batch-head .cnt { font-weight:650; color: var(--on-surface-variant); font-variant-numeric: tabular-nums; }
.bar { height:4px; border-radius: var(--r-full); background: var(--outline-variant); margin: 0 0 1.05em; overflow:hidden; }
.bar i { display:block; height:100%; border-radius: var(--r-full); background: var(--primary); }

.rows { border-radius: var(--r-card); background: var(--surface-container); overflow:hidden; margin-bottom:2.15em; }
.row { display:flex; align-items:center; gap:.9em; padding:.95em 1em; }
.row + .row { border-top: 1px solid var(--outline-variant); }
.row .th { width:2.6em; height:2.6em; border-radius: var(--r-thumb); overflow:hidden; flex:none; background:#2A3330; }
.row .meta { flex:1; min-width:0; }
.row .nm { font-size:.88em; font-weight:600; color: var(--on-surface); margin-bottom:.26em; letter-spacing:.005em; }
.row .st { display:flex; align-items:center; gap:.42em; font-size:.8em; font-weight:600; }
.row .st svg { width:1.05em; height:1.05em; flex:none; }
.st.queued   { color: var(--on-surface-variant); }
.st.waiting  { color: var(--on-surface-variant); }
.st.uploading{ color: var(--primary); }
.st.retrying { color: var(--tertiary); }
.st.synced   { color: var(--primary); }
.st.failed   { color: var(--error); }

.reassure {
  flex: 0 0 auto;
  display:flex; gap:.65em; align-items:flex-start;
  font-size:.8em; line-height:1.5; color: var(--on-surface-variant);
  padding: 0 .2em; margin-bottom: 1.35em;
}
.reassure svg { width:1.15em; height:1.15em; flex:none; margin-top:.12em; color: var(--primary); }

.um-foot { flex: 0 0 auto; padding: 0 4.6% 3.6em; }
.cta {
  display:flex; align-items:center; justify-content:center; gap:.5em;
  min-height: 52px; padding: 0 16px; border-radius: var(--r-full);
  background: var(--primary); color: var(--on-primary);
  font-size:.87em; font-weight:680;
}
.cta svg { width:1.15em; height:1.15em; }

/* empty state */
.empty { flex:1; display:flex; flex-direction:column; align-items:center; justify-content:center; text-align:center; padding: 0 12%; }
.empty .ic {
  width:22%; aspect-ratio:1; border-radius: var(--r-full);
  background: var(--primary-container); color: var(--on-primary-container);
  display:grid; place-items:center; margin-bottom:1.5em;
}
.empty .ic svg { width:46%; height:46%; }
.empty h3 { margin:0 0 .55em; font-size:1.12em; font-weight:650; }
.empty p { margin:0; font-size:.85em; line-height:1.55; color: var(--on-surface-variant); }
"""

# ---------------------------------------------------------------- icons
def icon(name):
    p = {
      "close":  '<path d="M6 6l12 12M18 6L6 18" stroke="currentColor" stroke-width="2" stroke-linecap="round" fill="none"/>',
      "flip":   '<path d="M4 8a8 8 0 0 1 13-3M20 16a8 8 0 0 1-13 3" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round"/><path d="M17 2v4h-4M7 22v-4h4" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
      "chev":   '<path d="M9 5l7 7-7 7" stroke="currentColor" stroke-width="2.2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
      "back":   '<path d="M15 5l-7 7 7 7" stroke="currentColor" stroke-width="2.2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
      "cloudoff":'<path d="M3 3l18 18" stroke="currentColor" stroke-width="2" stroke-linecap="round" fill="none"/><path d="M7.5 18h9a4 4 0 0 0 .8-7.9A6 6 0 0 0 8.6 7.4" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round"/><path d="M6.5 9.2A4.5 4.5 0 0 0 7.5 18" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round"/>',
      "bolt":   '<path d="M13 2L4.5 13.5H11l-1 8.5 8.5-11.5H12l1-8.5z" fill="currentColor"/>',
      "clock":  '<circle cx="12" cy="12" r="8.5" stroke="currentColor" stroke-width="2" fill="none"/><path d="M12 7.5V12l3 2" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
      "up":     '<path d="M12 19V5M6 11l6-6 6 6" stroke="currentColor" stroke-width="2.2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
      "refresh":'<path d="M20 12a8 8 0 1 1-2.4-5.7" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round"/><path d="M20 3.5V9h-5.5" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
      "check":  '<circle cx="12" cy="12" r="8.5" stroke="currentColor" stroke-width="2" fill="none"/><path d="M8.2 12.4l2.6 2.6 5-5.4" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
      "err":    '<circle cx="12" cy="12" r="8.5" stroke="currentColor" stroke-width="2" fill="none"/><path d="M12 7.6v5.2" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><circle cx="12" cy="16.4" r="1.15" fill="currentColor"/>',
      "shield": '<path d="M12 3l7 3v5.5c0 4.3-2.9 8.1-7 9.5-4.1-1.4-7-5.2-7-9.5V6l7-3z" stroke="currentColor" stroke-width="1.9" fill="none" stroke-linejoin="round"/><path d="M8.8 12.2l2.3 2.3 4.1-4.4" stroke="currentColor" stroke-width="1.9" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
      "camoff": '<path d="M3 3l18 18" stroke="currentColor" stroke-width="2" stroke-linecap="round" fill="none"/><path d="M8.4 5.5h4.1l1.4 2H19a2 2 0 0 1 2 2v8.1M18 20H5a2 2 0 0 1-2-2V9.5a2 2 0 0 1 2-2h1.4" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round" stroke-linejoin="round"/><path d="M14.4 14.7a3.4 3.4 0 0 1-4.6-4.6" stroke="currentColor" stroke-width="2" fill="none" stroke-linecap="round"/>',
      "cam":    '<path d="M4 7.5h3.2l1.4-2h6.8l1.4 2H20a1.8 1.8 0 0 1 1.8 1.8V18A1.8 1.8 0 0 1 20 19.8H4A1.8 1.8 0 0 1 2.2 18V9.3A1.8 1.8 0 0 1 4 7.5z" stroke="currentColor" stroke-width="1.9" fill="none" stroke-linejoin="round"/><circle cx="12" cy="13.4" r="3.4" stroke="currentColor" stroke-width="1.9" fill="none"/>',
      "plus":   '<path d="M12 5.5v13M5.5 12h13" stroke="currentColor" stroke-width="2.2" fill="none" stroke-linecap="round"/>',
      # "Finish batch" is a local durable action, so it takes a completion mark,
      # not a paper plane. A send glyph would repeat the same wrong promise the
      # old "Upload batch" label made.
      "done":   '<path d="M4.5 12.5l5 5 10-11" stroke="currentColor" stroke-width="2.4" fill="none" stroke-linecap="round" stroke-linejoin="round"/>',
    }[name]
    return '<svg viewBox="0 0 24 24" aria-hidden="true">' + p + '</svg>'

# ---------------------------------------------------------------- preview art
# Abstract original scene: documents on a work surface under directional light.
# Deliberately not a photograph and not derived from any existing application.
def preview(blurred=False):
    b = ' filter="url(#dof)"' if blurred else ''
    return '''<svg class="layer" viewBox="0 0 390 844" preserveAspectRatio="xMidYMid slice" aria-label="Simulated camera viewfinder">
  <defs>
    <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#2C3A44"/><stop offset="1" stop-color="#151E24"/>
    </linearGradient>
    <linearGradient id="desk" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#6E5B45"/><stop offset="55%" stop-color="#4A3D2E"/><stop offset="1" stop-color="#241D15"/>
    </linearGradient>
    <linearGradient id="paper" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#F4EFE4"/><stop offset="1" stop-color="#CFC7B6"/>
    </linearGradient>
    <radialGradient id="light" cx="28%" cy="16%" r="82%">
      <stop offset="0" stop-color="#FFF6E0" stop-opacity=".34"/>
      <stop offset="1" stop-color="#000" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="vig" cx="50%" cy="46%" r="72%">
      <stop offset="55%" stop-color="#000" stop-opacity="0"/>
      <stop offset="100%" stop-color="#000" stop-opacity=".55"/>
    </radialGradient>
    <filter id="dof"><feGaussianBlur stdDeviation="5"/></filter>
  </defs>

  <rect width="390" height="844" fill="url(#sky)"/>
  <g''' + b + '''>
    <rect y="120" width="390" height="150" fill="#22303A"/>
    <rect x="24"  y="150" width="104" height="96" rx="4" fill="#33444F"/>
    <rect x="140" y="138" width="104" height="108" rx="4" fill="#2B3A44"/>
    <rect x="256" y="156" width="110" height="90" rx="4" fill="#374A56"/>
    <rect x="34"  y="164" width="60" height="9" rx="4" fill="#4A5F6C"/>
    <rect x="150" y="152" width="72" height="9" rx="4" fill="#42565F"/>
    <rect x="266" y="170" width="56" height="9" rx="4" fill="#4E6472"/>
  </g>
  <rect y="270" width="390" height="574" fill="url(#desk)"/>
  <g transform="rotate(-4 195 470)">
    <rect x="58" y="352" width="252" height="316" rx="6" fill="#0B0A08" opacity=".34"/>
    <rect x="52" y="344" width="252" height="316" rx="6" fill="url(#paper)"/>
    <rect x="76" y="378" width="150" height="13" rx="6" fill="#7C7364"/>
    <rect x="76" y="410" width="204" height="8"  rx="4" fill="#A79E8D"/>
    <rect x="76" y="428" width="188" height="8"  rx="4" fill="#A79E8D"/>
    <rect x="76" y="446" width="196" height="8"  rx="4" fill="#A79E8D"/>
    <rect x="76" y="478" width="96"  height="8"  rx="4" fill="#B8AF9E"/>
    <rect x="76" y="510" width="204" height="8"  rx="4" fill="#A79E8D"/>
    <rect x="76" y="528" width="164" height="8"  rx="4" fill="#A79E8D"/>
    <rect x="76" y="574" width="112" height="30" rx="5" fill="#8E9E7E" opacity=".85"/>
    <rect x="206" y="574" width="74" height="30" rx="5" fill="#C0B7A5"/>
  </g>
  <ellipse cx="322" cy="742" rx="86" ry="54" fill="#2A2119" opacity=".7"/>
  <rect width="390" height="844" fill="url(#light)"/>
  <rect width="390" height="844" fill="url(#vig)"/>
</svg>'''

def thumb_art():
    return ('<svg viewBox="0 0 40 40" preserveAspectRatio="xMidYMid slice" aria-hidden="true">'
            '<rect width="40" height="40" fill="#3B3226"/>'
            '<rect x="7" y="9" width="26" height="24" rx="2" fill="#DDD5C4"/>'
            '<rect x="11" y="14" width="15" height="2.4" rx="1.2" fill="#9A9080"/>'
            '<rect x="11" y="19" width="18" height="2.4" rx="1.2" fill="#B3A996"/>'
            '<rect x="11" y="24" width="12" height="2.4" rx="1.2" fill="#B3A996"/></svg>')

# ---------------------------------------------------------------- camera builder
def camera(reticle=None, zoom_pct=0, zoom_label="1.0x", presets=None, active_preset="1x",
           thumb_count=None, batch_cta=None, offline=False, uploads_badge=None,
           readout=None, error=None):
    if error:
        inner = ('<div class="cam-error">'
                 '<div class="ic">' + icon("camoff") + '</div>'
                 '<h2>' + error["title"] + '</h2>'
                 '<p>' + error["body"] + '</p>'
                 '<div class="act">' + error["action"] + '</div>'
                 + ('<div class="act2">' + error["action2"] + '</div>' if error.get("action2") else '')
                 + '</div>')
        art = ''
    else:
        art = preview()
        inner = ''

    presets = presets or []
    bits = []
    bits.append('<div class="phone">')
    bits.append(art)
    bits.append(inner)
    if not error:
        bits.append('<div class="cam-scrim-top"></div>')
        bits.append('<div class="cam-scrim-bottom"></div>')

    # Top bar. Present in every camera state, including the error state - the
    # queue must stay reachable when the camera is not.
    #
    # There is deliberately NO close/X control here. The camera is the app's
    # primary surface, so there is nothing to close it *to*, and an X over a
    # viewfinder reads ambiguously as "discard this batch" as easily as
    # "leave". Navigation is one-way outward to Pending Uploads, which carries
    # its own back affordance. See UX_SPEC section 3.1.
    ue = ''
    if uploads_badge is not None:
        ue = ('<div class="uploads-entry">Uploads<span class="n">' + str(uploads_badge) + '</span>'
              + icon("chev") + '</div>')
    else:
        ue = '<div class="uploads-entry">Uploads' + icon("chev") + '</div>'
    off = ('<div class="chip-offline">' + icon("cloudoff") + 'Offline</div>') if offline else '<div></div>'
    bits.append('<div class="cam-topbar">' + off + ue + '</div>')

    if not error:
        if reticle:
            bits.append('<div class="reticle" style="left:' + str(reticle[0]) + '%;top:' + str(reticle[1]) + '%">'
                        '<div class="ring"></div><i class="tick t1"></i><i class="tick t2"></i>'
                        '<i class="tick t3"></i><i class="tick t4"></i></div>')
        if readout:
            bits.append('<div class="zoom-readout">' + readout + '</div>')
        # zoom slider
        bits.append('<div class="zoom"><span>' + zoom_label.split("|")[1] + '</span>'
                    '<div class="track"><i class="fill" style="height:' + str(zoom_pct) + '%"></i>'
                    '<i class="thumb" style="bottom:' + str(zoom_pct) + '%"></i></div>'
                    '<span>' + zoom_label.split("|")[0] + '</span></div>')
        # presets
        pr = ''.join('<div class="preset' + (' on' if p == active_preset else '') + '">' + p + '</div>'
                     for p in presets)
        if pr:
            bits.append('<div class="presets">' + pr + '</div>')
        # bottom bar
        if thumb_count:
            ts = ('<div class="thumbstack"><div class="sheet b2"></div><div class="sheet b1"></div>'
                  '<div class="sheet">' + thumb_art() + '</div>'
                  '<div class="count">' + str(thumb_count) + '</div></div>')
        else:
            ts = '<div class="thumbstack" style="visibility:hidden"></div>'
        bits.append('<div class="cam-bottom">' + ts +
                    '<div class="shutter"><i></i></div>'
                    '<div class="flip">' + icon("flip") + '</div></div>')
        if batch_cta:
            bits.append('<div class="batch-cta">' + icon("done") + batch_cta + '</div>')
    bits.append('</div>')
    return ''.join(bits)

# ---------------------------------------------------------------- upload manager
STATE_ICON = {"queued":"clock","waiting":"cloudoff","uploading":"up","retrying":"refresh",
              "synced":"check","failed":"err"}

def um(chip=None, batches=None, reassure=None, empty=False, cta="Start new batch"):
    b = ['<div class="phone"><div class="um">']
    b.append('<div class="um-top"><span class="back">' + icon("back") + '</span>'
             '<h2>Pending uploads</h2></div>')
    if empty:
        b.append('<div class="empty"><div class="ic">' + icon("shield") + '</div>'
                 '<h3>Everything&rsquo;s uploaded</h3>'
                 '<p>Photos you capture will appear here until they&rsquo;re safely uploaded.</p></div>')
        b.append('<div class="um-foot"><div class="cta">' + icon("cam") + 'Open camera</div></div>')
    else:
        b.append('<div class="um-body">')
        if chip:
            b.append('<div class="link-chip ' + chip["tone"] + '">' + icon(chip["icon"]) + chip["text"] + '</div>')
        for bt in (batches or []):
            b.append('<div class="batch-head"><span class="ttl">' + bt["title"] + '</span>'
                     '<span class="cnt">' + bt["count"] + '</span></div>')
            b.append('<div class="bar"><i style="width:' + str(bt["pct"]) + '%"></i></div>')
            b.append('<div class="rows">')
            for it in bt["items"]:
                b.append('<div class="row"><div class="th">' + thumb_art() + '</div>'
                         '<div class="meta"><div class="nm">' + it["name"] + '</div>'
                         '<div class="st ' + it["state"] + '">' + icon(STATE_ICON[it["state"]])
                         + '<span>' + it["label"] + '</span></div></div></div>')
            b.append('</div>')
        b.append('</div>')
        if reassure:
            b.append('<div class="reassure">' + icon("shield") + '<span>' + reassure + '</span></div>')
        b.append('<div class="um-foot"><div class="cta">' + icon("plus") + cta + '</div></div>')
    b.append('</div></div>')
    return ''.join(b)

# ---------------------------------------------------------------- screens
SCREENS_DEF = []

SCREENS_DEF.append(dict(
  slug="01-camera-ready", title="Camera &mdash; ready, empty batch",
  reqs="FLT-CAM-001 &middot; FLT-CAM-004 &middot; FLT-CAM-005 &middot; FLT-UX-001",
  note=("Default state. The preview is the interface: chrome sits on gradient scrims, not panels, "
        "and nothing occupies the optical centre. <b style='display:inline;font-weight:650'>There is no close "
        "control</b> &mdash; the camera is the primary surface, and an X over a viewfinder reads as "
        "&ldquo;discard this batch&rdquo; as readily as &ldquo;leave&rdquo;. No thumbnail and no "
        "<b style='display:inline;font-weight:650'>Finish batch</b> action either, because the batch is "
        "empty; contextual controls appear only when they mean something."),
  html=camera(zoom_pct=8, zoom_label="1x|8x", presets=["1x","2x"], active_preset="1x",
              readout=None, uploads_badge=None)))

SCREENS_DEF.append(dict(
  slug="02-camera-focus-zoom", title="Camera &mdash; tap-to-focus and zoom engaged",
  reqs="FLT-CAM-003 &middot; FLT-CAM-005 &middot; FLT-CAM-008 &middot; FLT-CAM-009",
  note=("The reticle sits <b style='display:inline;font-weight:650'>exactly where the finger landed</b>, "
        "not in the centre. Zoom is at 2.0&times;: the slider fill, the readout and the active preset all "
        "render from one shared value, so no two controls can disagree (FLT-CAM-006)."),
  html=camera(reticle=(63, 41), zoom_pct=32, zoom_label="1x|8x", presets=["1x","2x"],
              active_preset="2x", readout="2.0x", uploads_badge=None)))

SCREENS_DEF.append(dict(
  slug="03-camera-active-batch", title="Camera &mdash; active batch, offline",
  reqs="FLT-BAT-001 &middot; FLT-BAT-007 &middot; FLT-UX-012 &middot; FLT-SYNC-011",
  note=("Four captures held in the open batch. The thumbnail stack and count answer "
        "&ldquo;did that register?&rdquo; without a second screen, and the "
        "<b style='display:inline;font-weight:650'>Finish batch (4)</b> action has appeared. "
        "<b style='display:inline;font-weight:650'>Finish, not Upload:</b> the button closes the batch "
        "and hands it to the sync engine durably &mdash; a purely local act, which is why it is "
        "unremarkable that the device is offline while it is offered. Pressing it never performs a "
        "network operation, so the label must not promise one."),
  html=camera(zoom_pct=8, zoom_label="1x|8x", presets=["1x","2x"], active_preset="1x",
              thumb_count=4, batch_cta="Finish batch (4)", offline=True, uploads_badge=12)))

SCREENS_DEF.append(dict(
  slug="04-upload-manager-pending", title="Pending uploads &mdash; draining",
  reqs="FLT-BAT-003 &middot; FLT-UX-010 &middot; FLT-UX-011 &middot; FLT-SYNC-013",
  note=("Two batches, oldest processed first. Progress is <b style='display:inline;font-weight:650'>count-based</b> "
        "(&ldquo;3 of 5&rdquo;), never a fabricated byte percentage. Every state carries an icon "
        "<i>and</i> a word, so nothing depends on colour alone. The chip says "
        "<i>uploading</i> automatically rather than <i>retrying</i> &mdash; retry is what happens after "
        "a failure, and nothing here has failed."),
  html=um(chip=dict(tone="ok", icon="bolt", text="Connected &middot; uploading automatically"),
          batches=[
            dict(title="Batch &middot; 2 min ago", count="3 of 5", pct=60, items=[
              dict(name="IMG_0031", state="synced",    label="Synced"),
              dict(name="IMG_0032", state="uploading", label="Uploading"),
              dict(name="IMG_0033", state="queued",    label="In queue"),
            ]),
            dict(title="Batch &middot; 1 hr ago", count="0 of 2", pct=0, items=[
              dict(name="IMG_0028", state="queued", label="In queue"),
              dict(name="IMG_0029", state="queued", label="In queue"),
            ]),
          ],
          reassure="Saved on this device. Uploads resume automatically when you&rsquo;re connected.")))

SCREENS_DEF.append(dict(
  slug="05-upload-manager-retrying", title="Pending uploads &mdash; offline and retrying",
  reqs="FLT-SYNC-003 &middot; FLT-SYNC-004 &middot; FLT-UX-007 &middot; FLT-UX-009 &middot; ADR-F12",
  note=("The state the whole engine exists for. Nothing is lost and nothing needs pressing. "
        "The attempt count is shown <b style='display:inline;font-weight:650'>without a denominator</b> "
        "because no cap exists (ADR-F12, approved) &mdash; &ldquo;3/5&rdquo; would promise an abandonment "
        "that never comes. The chip leads with the reassurance (&ldquo;captures are safe&rdquo;) rather "
        "than the problem. One item is permanently failed (its file is gone) and is visibly distinct "
        "from the ones still waiting."),
  html=um(chip=dict(tone="off", icon="cloudoff", text="Offline &middot; captures are safe"),
          batches=[
            dict(title="Batch &middot; 6 min ago", count="1 of 4", pct=25, items=[
              dict(name="IMG_0044", state="synced",   label="Synced"),
              dict(name="IMG_0045", state="retrying", label="Retrying &middot; attempt 3"),
              dict(name="IMG_0046", state="waiting",  label="Waiting for connection"),
              dict(name="IMG_0047", state="failed",   label="Can&rsquo;t upload &middot; file missing"),
            ]),
          ],
          reassure="Saved on this device. Uploads resume automatically when you&rsquo;re connected.")))

SCREENS_DEF.append(dict(
  slug="06-upload-manager-empty", title="Pending uploads &mdash; empty",
  reqs="FLT-UX-006",
  note=("Not an error, and not styled like one. The queue being empty is the good outcome, "
        "so the state is reassuring and offers the obvious next action."),
  html=um(empty=True)))

SCREENS_DEF.append(dict(
  slug="07-camera-permission-error", title="Camera &mdash; permission permanently denied",
  reqs="FLT-ERR-001 &middot; FLT-ERR-002 &middot; FLT-GEN-004",
  note=("A designed state, not a crash or a blank preview. The single most important detail: "
        "<b style='display:inline;font-weight:650'>the Uploads entry is still in the top bar</b>. "
        "Twelve captures are queued, and they must never be trapped behind a camera the user cannot open."),
  html=camera(uploads_badge=12, error=dict(
      title="Camera access is off",
      body="PresenceLens needs the camera to take photos. You can turn access back on in Settings.",
      action="Open settings",
      action2="Your 12 queued photos are safe"))))

# ---------------------------------------------------------------- emit
HEAD = ('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        '<title>{title}</title>\n'
        '<style>\n' + TOKENS + '\n' + SCREENS + '\n</style>\n</head>\n')

(OUT / "tokens.css").write_text(TOKENS, encoding="utf-8")
(OUT / "screens.css").write_text(SCREENS, encoding="utf-8")

def card(s, standalone=False):
    return ('<figure class="screen-card">\n' + s["html"] +
            '\n<figcaption><b>' + s["title"] + '</b>' + s["note"] +
            '<div style="margin-top:8px"><code>' + s["reqs"] + '</code></div>'
            '</figcaption>\n</figure>\n')

for s in SCREENS_DEF:
    body = (HEAD.replace("{title}", s["title"].replace("&mdash;", "-")) +
            '<body class="standalone">\n<div class="stage">\n' + card(s, True) +
            '</div>\n</body>\n</html>\n')
    (OUT / (s["slug"] + ".html")).write_text(body, encoding="utf-8")

index = (HEAD.replace("{title}", "PresenceLens Capture - visual prototypes") +
 '<body>\n<header class="page-head">\n'
 '<h1>PresenceLens Capture &mdash; visual prototypes</h1>\n'
 '<p>Static review artefacts for Task 2 of the Intelligent Machines assessment. These are '
 '<b>not</b> the production Flutter UI &mdash; they exist so the layout, hierarchy, colour and state '
 'messaging can be judged before any widget is written. The written intent they implement is '
 '<code>docs/flutter/UX_SPEC.md</code>.</p>\n'
 '<p style="margin-top:10px">Two palettes are in play, and the difference is deliberate. The '
 '<b>camera screens are fixed dark</b> and ignore your system theme, because the content behind the '
 'controls is always a live image (<code>ADR-F07</code>). The <b>upload screens follow your system '
 'light/dark setting</b> &mdash; switch it and this page follows (<code>FLT-UX-008</code>).</p>\n'
 '<p style="margin-top:10px">Scenes in the viewfinder are original abstract artwork drawn in SVG, not '
 'photographs and not derived from any existing application.</p>\n'
 '<p style="margin-top:10px">These states were reviewed and <b>approved on 2026-08-29</b>, and the '
 'decisions they carry are frozen as the production design direction &mdash; notably the absence of a '
 'close control on the camera (<code>ADR-F13</code>) and <b>Finish batch</b> as a local durable action '
 'rather than a network one (<code>ADR-F14</code>). <b>No production Flutter UI exists yet;</b> these '
 'remain static artefacts, and they are the reference the real widgets are built against.</p>\n'
 '<div class="gate">&check; VISUAL DIRECTION APPROVED &mdash; 2026-08-29</div>\n'
 '</header>\n<div class="stage">\n' +
 ''.join(card(s) for s in SCREENS_DEF) +
 '</div>\n</body>\n</html>\n')
(OUT / "index.html").write_text(index, encoding="utf-8")

print("wrote:")
for f in sorted(OUT.iterdir()):
    print("  ", f.name, f.stat().st_size)
