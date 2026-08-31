import os
import re
import sys

def build():
    css_dir = os.path.dirname(__file__)

    tokens = """:root {
  --palette-control: #FFFFFFEB;
  --palette-control-background: #00000073;
  --palette-control-active: #00E5A8;
  --palette-control-active-background: #0000009E;
  --palette-shutter: #FFFFFF;
  --palette-accent: #00E5A8;
  --palette-warning: #FFB74D;
  --palette-panel: #101416;
  --palette-placeholder: #0B0F11;
  --palette-on-accent: #06231B;

  --scrim-top: linear-gradient(to bottom, #000000B3, transparent);
  --scrim-bottom: linear-gradient(to top, #000000E0, transparent);

  --release-width: 365.7142857px;
  --release-height: 800px;
  --safe-top: 40.29px;
  --safe-bottom: 22.29px;

  --um-primary: #88D6BA;
  --um-primary-container: #00513E;
  --um-on-primary-container: #A4F2D5;
  --um-on-surface: #DEE4DF;
  --um-on-surface-variant: #BFC9C3;
  --um-surface: #0F1512;
  --um-surface-container: #1B211E;
  --um-surface-container-low: #171D1A;
  --um-surface-container-highest: #303633;
  --um-outline: #89938E;
  --um-tertiary: #A7CCE1;
  --um-error: #FFB4AB;
}
"""
    with open(os.path.join(css_dir, "tokens.css"), "w", newline='\n') as f:
        f.write(tokens)

    screens = """@import 'tokens.css';

body {
  margin: 0;
  padding: 0;
  background-color: #333;
  display: flex;
  justify-content: center;
  align-items: center;
  min-height: 100vh;
  font-family: system-ui, -apple-system, sans-serif;
}

.device-frame {
  width: var(--release-width);
  height: var(--release-height);
  background-color: var(--palette-panel);
  position: relative;
  overflow: hidden;
}

.preview-placeholder {
  position: absolute;
  inset: 0;
  background-color: var(--palette-placeholder);
}

.top-chrome {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  background: var(--scrim-top);
  padding: calc(var(--safe-top) + 8px) 12px 24px 12px;
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  pointer-events: none;
}

.offline-placeholder {
  height: 48px;
}

.uploads-entry {
  height: 48px;
  padding: 0 14px;
  background-color: var(--palette-control-background);
  border-radius: 24px;
  display: flex;
  align-items: center;
  color: var(--palette-control);
  font-size: 14px;
  font-weight: 600;
  pointer-events: auto;
}

.uploads-entry svg {
  width: 20px;
  height: 20px;
  fill: currentColor;
  margin-left: 2px;
}

.zoom-slider {
  position: absolute;
  right: 4px;
  bottom: 260px;
  width: 48px;
  height: 248px;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: space-between;
}

.zoom-slider-label {
  color: var(--palette-control);
  font-size: 11px;
  font-variant-numeric: tabular-nums;
  line-height: 24px;
}

.zoom-slider-track-container {
  height: 200px;
  width: 100%;
  position: relative;
  display: flex;
  justify-content: center;
}

.zoom-slider-track {
  width: 3px;
  height: 200px;
  background-color: rgba(255, 255, 255, 0.28);
  border-radius: 1.5px;
  position: relative;
}

.zoom-slider-track-active {
  position: absolute;
  bottom: 0;
  left: 0;
  right: 0;
  background-color: var(--palette-accent);
  border-radius: 1.5px;
}

.zoom-slider-thumb {
  position: absolute;
  width: 20px;
  height: 20px;
  border-radius: 10px;
  background-color: var(--palette-shutter);
  left: 50%;
  transform: translate(-50%, 50%);
}

.bottom-chrome {
  position: absolute;
  left: 0;
  right: 0;
  bottom: 0;
  background: var(--scrim-bottom);
  padding-bottom: var(--safe-bottom);
  display: flex;
  flex-direction: column;
  align-items: center;
}

.bottom-chrome-content {
  padding: 24px 0 16px 0;
  width: 100%;
  display: flex;
  flex-direction: column;
  align-items: center;
}

.zoom-preset-row {
  height: 48px;
  display: flex;
  gap: 8px;
}

.zoom-preset {
  min-width: 48px;
  height: 48px;
  border-radius: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: var(--palette-control-background);
  color: var(--palette-control);
  font-size: 13px;
  font-weight: 600;
  font-variant-numeric: tabular-nums;
  box-sizing: border-box;
}

.zoom-preset.active {
  background-color: var(--palette-control-active-background);
  color: var(--palette-control-active);
  border: 1.5px solid var(--palette-control-active);
}

.finish-batch-row {
  margin-top: 12px;
}

.finish-batch-btn {
  height: 48px;
  padding: 0 24px;
  border-radius: 24px;
  background-color: var(--palette-accent);
  color: var(--palette-on-accent);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 600;
  gap: 8px;
}

.finish-batch-btn svg {
  width: 20px;
  height: 20px;
  fill: currentColor;
}

.bottom-actions {
  display: flex;
  justify-content: space-between;
  align-items: center;
  width: 100%;
  padding: 0 24px;
  margin-top: 12px;
  box-sizing: border-box;
}

.action-slot-left {
  width: 52px;
  height: 52px;
  position: relative;
}

.batch-thumbnail {
  width: 52px;
  height: 52px;
  border-radius: 8px;
  background-color: var(--palette-control-background);
  border: 1px solid rgba(255, 255, 255, 0.5);
  box-sizing: border-box;
  overflow: hidden;
}

.batch-thumbnail-img {
  width: 100%;
  height: 100%;
  background-color: var(--palette-placeholder);
  display: flex;
  align-items: center;
  justify-content: center;
}

.batch-badge {
  position: absolute;
  top: -6px;
  right: -6px;
  min-width: 22px;
  height: 22px;
  border-radius: 11px;
  background-color: var(--palette-accent);
  color: var(--palette-on-accent);
  font-size: 12px;
  font-weight: 700;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 0 6px;
  box-sizing: border-box;
}

.action-slot-right {
  width: 48px;
  height: 48px;
}

.shutter {
  width: 72px;
  height: 72px;
  border: 3px solid var(--palette-shutter);
  border-radius: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  box-sizing: border-box;
}

.shutter-inner {
  width: 56px;
  height: 56px;
  background-color: var(--palette-shutter);
  border-radius: 28px;
}

.focus-reticle {
  position: absolute;
  width: 72px;
  height: 72px;
  border-radius: 36px;
  border: 1.6px solid var(--palette-accent);
  display: flex;
  align-items: center;
  justify-content: center;
  transform: translate(-50%, -50%);
  box-sizing: border-box;
}

.focus-reticle-dot {
  width: 6px;
  height: 6px;
  border-radius: 3px;
  background-color: var(--palette-accent);
}
/* ==========================================================================
   Upload Manager (M3)
   ========================================================================== */
.upload-manager {
  background-color: var(--um-surface);
  color: var(--um-on-surface);
  font-family: 'Roboto', sans-serif;
  display: flex;
  flex-direction: column;
}

.um-appbar {
  display: flex;
  align-items: center;
  height: 56px;
  padding: var(--safe-top) 4px 0 4px;
  background-color: var(--um-surface);
}

.um-appbar-title {
  flex: 1;
  font-size: 22px;
  font-weight: 400;
  margin-left: 16px;
}

.um-icon-btn {
  width: 48px;
  height: 48px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  color: var(--um-on-surface);
}

.um-body {
  flex: 1;
  overflow: hidden;
  display: flex;
  justify-content: center;
}

.um-list {
  width: 100%;
  max-width: 640px;
  padding: 16px 16px 32px 16px;
  box-sizing: border-box;
  display: flex;
  flex-direction: column;
}

.um-chip {
  width: 100%;
  box-sizing: border-box;
  padding: 12px 16px;
  border-radius: 12px;
  display: flex;
  align-items: center;
  gap: 10px;
}

.um-chip.offline {
  background-color: var(--um-surface-container-highest);
  color: var(--um-on-surface-variant);
}

.um-chip-text {
  font-size: 14px;
  font-weight: 600;
  letter-spacing: 0.1px;
}

.um-batch {
  display: flex;
  flex-direction: column;
}

.um-batch-header {
  display: flex;
  align-items: center;
  padding: 0 4px 8px 4px;
}

.um-batch-title {
  flex: 1;
  font-size: 11px;
  font-weight: 500;
  letter-spacing: 0.5px;
  color: var(--um-on-surface-variant);
}

.um-batch-count {
  font-size: 11px;
  font-weight: 500;
  letter-spacing: 0.5px;
  color: var(--um-on-surface-variant);
  font-variant-numeric: tabular-nums;
}

.um-progress-container {
  width: 48px;
  height: 4px;
  border-radius: 2px;
  background-color: var(--um-surface-container-highest);
  margin-left: 8px;
  overflow: hidden;
}

.um-progress-fill {
  height: 100%;
  background-color: var(--um-primary);
}

.um-card {
  background-color: var(--um-surface-container-low);
  border-radius: 16px;
  display: flex;
  flex-direction: column;
}

.um-row {
  display: flex;
  align-items: center;
  padding: 10px 12px;
}

.um-thumb {
  width: 40px;
  height: 40px;
  border-radius: 8px;
  background-color: var(--um-surface-container-highest);
  overflow: hidden;
  flex-shrink: 0;
}

.um-thumb img {
  width: 100%;
  height: 100%;
  object-fit: cover;
}

.um-filename {
  flex: 1;
  font-size: 14px;
  font-weight: 400;
  letter-spacing: 0.25px;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  margin-left: 12px;
}

.um-status-icon {
  margin-left: 12px;
  display: flex;
}

.um-status-text {
  max-width: 168px;
  text-align: right;
  font-size: 12px;
  font-weight: 400;
  letter-spacing: 0.4px;
  margin-left: 6px;
}

.um-reassurance {
  text-align: center;
  font-size: 14px;
  font-weight: 400;
  letter-spacing: 0.25px;
  color: var(--um-on-surface-variant);
  margin-top: 8px;
  padding: 0 16px;
}

.um-btn-container {
  display: flex;
  justify-content: center;
  margin-top: 24px;
}

.um-outlined-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  min-height: 48px;
  padding: 0 24px;
  border: 1px solid var(--um-outline);
  border-radius: 24px;
  color: var(--um-primary);
  font-size: 14px;
  font-weight: 500;
  letter-spacing: 0.1px;
}

.um-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 32px;
  height: 100%;
}

.um-empty-title {
  font-size: 16px;
  font-weight: 500;
  letter-spacing: 0.15px;
  margin-top: 16px;
}

.um-empty-body {
  font-size: 14px;
  font-weight: 400;
  letter-spacing: 0.25px;
  color: var(--um-on-surface-variant);
  text-align: center;
  margin-top: 8px;
}

.um-filled-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  min-height: 48px;
  padding: 0 24px;
  border-radius: 24px;
  background-color: var(--um-primary);
  color: var(--um-on-primary, #00382A);
  font-size: 14px;
  font-weight: 500;
  letter-spacing: 0.1px;
  margin-top: 24px;

/* CAMERA STATUS PANEL */
.camera-status-panel {
  position: absolute;
  inset: 0;
  background-color: var(--palette-panel);
  display: flex;
  flex-direction: column;
  align-items: center;
  padding: 96px 32px 32px 32px;
  box-sizing: border-box;
  text-align: center;
}

.status-icon {
  margin-bottom: 20px;
}
.status-icon svg {
  fill: var(--palette-control);
}

.status-title {
  color: var(--palette-control);
  font-size: 20px;
  font-weight: 600;
  margin-bottom: 8px;
}

.status-message {
  color: rgba(255, 255, 255, 0.66);
  font-size: 14px;
  line-height: 1.4;
  max-width: 420px;
}

.status-primary-action {
  margin-top: 24px;
  height: 48px;
  padding: 0 24px;
  border-radius: 24px;
  background-color: var(--palette-accent);
  color: var(--palette-on-accent);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 500;
  gap: 8px;
}
.status-primary-action svg {
  fill: currentColor;
}

.status-secondary-action {
  margin-top: 8px;
  height: 48px;
  padding: 0 24px;
  border-radius: 24px;
  background-color: transparent;
  color: var(--palette-control);
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 14px;
  font-weight: 500;
}

.status-reassurance {
  margin-top: 32px;
  color: var(--palette-accent);
  font-size: 13px;
  font-weight: 600;
}

.spinner {
  width: 32px;
  height: 32px;
  border: 2.5px solid rgba(0, 229, 168, 0.2);
  border-top: 2.5px solid var(--palette-accent);
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 20px;
}
@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.phone-grid {
  display: flex;
  flex-wrap: wrap;
  gap: 32px;
  padding: 32px;
  justify-content: center;
  font-family: system-ui, -apple-system, sans-serif;
  color: #fff;
}
.phone-col {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}
.phone-label {
  font-size: 13px;
  color: #999;
  text-align: center;
  max-width: 365px;
}
}
"""
    with open(os.path.join(css_dir, "screens.css"), "w", newline='\n') as f:
        f.write(screens)

    def render_frame(name, title, active_zoom, reticle_visible, reticle_x, reticle_y, batch_count):
        # Math for zoom slider (linear map 1x to 8x onto 0 to 100% of 200px track)
        track_height = 200
        min_z = 1.0
        max_z = 8.0
        pct = (active_zoom - min_z) / (max_z - min_z)
        thumb_bottom = pct * track_height

        has_batch = batch_count > 0

        reticle_html = f'''
    <div class="focus-reticle" style="left: {reticle_x}px; top: {reticle_y}px;">
      <div class="focus-reticle-dot"></div>
    </div>''' if reticle_visible else ''

        finish_batch_html = f'''
        <div class="finish-batch-row">
          <div class="finish-batch-btn">
            <svg viewBox="0 0 24 24"><path d="M9 16.17L4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>
            Finish batch ({batch_count})
          </div>
        </div>''' if has_batch else ''

        thumbnail_html = f'''
            <div class="batch-thumbnail">
              <div class="batch-thumbnail-img">
                <svg viewBox="0 0 24 24" width="20" height="20" fill="#FFFFFFEB"><path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/></svg>
              </div>
            </div>
            <div class="batch-badge">{batch_count}</div>
''' if has_batch else ''

        active_preset = 1.0
        if active_zoom >= 5.0:
            active_preset = 5.0
        elif active_zoom >= 2.0:
            active_preset = 2.0

        zoom_1_active = ' active' if active_preset == 1.0 else ''
        zoom_2_active = ' active' if active_preset == 2.0 else ''
        zoom_5_active = ' active' if active_preset == 5.0 else ''

        html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>{title}</title>
  <link rel="stylesheet" href="screens.css">
</head>
<body>
  <div class="device-frame">
    <div class="preview-placeholder">
      <svg viewBox="0 0 100 100" preserveAspectRatio="none" style="width:100%;height:100%;opacity:0.05">
        <circle cx="50" cy="50" r="40" stroke="#FFF" stroke-width="2" fill="none" />
      </svg>
    </div>
{reticle_html}
    <div class="top-chrome">
      <div class="offline-placeholder"></div>
      <div class="uploads-entry">
        Uploads
        <svg viewBox="0 0 24 24"><path d="M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z"/></svg>
      </div>
    </div>

    <div class="zoom-slider">
      <div class="zoom-slider-label">8x</div>
      <div class="zoom-slider-track-container">
        <div class="zoom-slider-track">
          <div class="zoom-slider-track-active" style="height: {thumb_bottom}px;"></div>
        </div>
        <div class="zoom-slider-thumb" style="bottom: {thumb_bottom}px;"></div>
      </div>
      <div class="zoom-slider-label">1x</div>
    </div>

    <div class="bottom-chrome">
      <div class="bottom-chrome-content">
        <div class="zoom-preset-row">
          <div class="zoom-preset{zoom_1_active}">1x</div>
          <div class="zoom-preset{zoom_2_active}">2x</div>
          <div class="zoom-preset{zoom_5_active}">5x</div>
        </div>{finish_batch_html}
        <div class="bottom-actions">
          <div class="action-slot-left">{thumbnail_html}</div>
          <div class="shutter">
            <div class="shutter-inner"></div>
          </div>
          <div class="action-slot-right"></div>
        </div>
      </div>
    </div>
  </div>
</body>
</html>
"""
        with open(os.path.join(css_dir, f"{name}.html"), "w", newline='\n') as f:
            f.write(re.sub(r'^[ \\t]+$', '', html, flags=re.MULTILINE))

    def render_upload_manager(name, title, is_empty, has_pending, is_offline, batch_time, batch_count, progress_pct, rows_html, extra_html=''):
        if is_empty:
            html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{title}</title>
  <link rel="stylesheet" href="tokens.css">
  <link rel="stylesheet" href="screens.css">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Roboto:wght@400;500;600&display=swap" rel="stylesheet">
</head>
<body>
  <div class="device-frame">
    <div class="screen upload-manager">
      <div class="um-appbar">
        <div class="um-icon-btn" style="margin-left: 4px;">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"/></svg>
        </div>
        <div class="um-appbar-title">Pending uploads</div>
      </div>
      <div class="um-body">
        <div class="um-empty">
          <svg width="48" height="48" viewBox="0 0 24 24" fill="var(--um-primary)"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4c-1.48 0-2.85.43-4.01 1.17l1.46 1.46C10.21 5.9 11.08 5.5 12 5.5c2.88 0 5.28 2.08 5.89 4.88l.27 1.25H19c2.21 0 4 1.79 4 4 0 1.21-.55 2.29-1.4 3.01l1.43 1.43c1.23-1.1 2.02-2.71 2.02-4.5-.01-3.13-2.45-5.74-5.7-6.03zM3.41 4.86L2 6.27l4.89 4.89C5.1 12.13 4 13.94 4 16c0 3.31 2.69 6 6 6h9.73l2 2 1.41-1.41L3.41 4.86zM10 19.98c-2.21 0-4-1.79-4-4 0-1.89 1.34-3.48 3.12-3.88l4.85 4.85c-.41 1.83-2.04 3.03-3.97 3.03z"/><path d="M10 10.5l-2.5 2.5-1.5-1.5-1.5 1.5 3 3 4-4-1.5-1.5z" fill="var(--um-primary)"/></svg>
          <div class="um-empty-title">Everything's uploaded</div>
          <div class="um-empty-body">Photos you capture will appear here until they're safely uploaded.</div>
          <div class="um-filled-btn">
            <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M14.12 4l1.83 2H20v12H4V6h4.05l1.83-2h4.24M15 2H9L7.17 4H4c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h16c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2h-3.17L15 2zM12 17c-2.76 0-5-2.24-5-5s2.24-5 5-5 5 2.24 5 5-2.24 5-5 5zm0-8c-1.65 0-3 1.35-3 3s1.35 3 3 3 3-1.35 3-3-1.35-3-3-3z"/></svg>
            Open camera
          </div>
        </div>
      </div>
    </div>
  </div>
{extra_html}
</body>
</html>
"""
        else:
            appbar_actions = '''
          <div class="um-icon-btn">
            <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M12 8c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zm0 2c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2zm0 6c-1.1 0-2 .9-2 2s.9 2 2 2 2-.9 2-2-.9-2-2-2z"/></svg>
          </div>''' if has_pending else ''

            if has_pending:
                if is_offline:
                    chip_html = '''
            <div class="um-chip offline">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M19.35 10.04C18.67 6.59 15.64 4 12 4c-1.48 0-2.85.43-4.01 1.17l1.46 1.46C10.21 5.9 11.08 5.5 12 5.5c2.88 0 5.28 2.08 5.89 4.88l.27 1.25H19c2.21 0 4 1.79 4 4 0 1.21-.55 2.29-1.4 3.01l1.43 1.43c1.23-1.1 2.02-2.71 2.02-4.5-.01-3.13-2.45-5.74-5.7-6.03zM3.41 4.86L2 6.27l4.89 4.89C5.1 12.13 4 13.94 4 16c0 3.31 2.69 6 6 6h9.73l2 2 1.41-1.41L3.41 4.86zM10 19.98c-2.21 0-4-1.79-4-4 0-1.89 1.34-3.48 3.12-3.88l4.85 4.85c-.41 1.83-2.04 3.03-3.97 3.03z"/></svg>
              <div class="um-chip-text">Offline &middot; captures are safe</div>
            </div>
            <div style="height: 20px;"></div>'''
                else:
                    chip_html = '''
            <div class="um-chip" style="background-color: var(--um-primary-container, #00513E); color: var(--um-on-primary-container, #A4F3D6);">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M11 21h-1l1-7H7.5c-.58 0-.57-.32-.38-.66.19-.34.05-.08.16-.28L11.75 4h1l-1 7h3.5c.49 0 .56.33.47.51l-.07.15C12.96 17.55 11 21 11 21z"/></svg>
              <div class="um-chip-text">Connected &middot; uploading automatically</div>
            </div>
            <div style="height: 20px;"></div>'''
            else:
                chip_html = ''

            reassurance = f'''
            <div style="height: 8px;"></div>
            <div class="um-reassurance">Saved on this device. Uploads resume automatically when you're connected.</div>''' if has_pending else ''

            html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>{title}</title>
  <link rel="stylesheet" href="tokens.css">
  <link rel="stylesheet" href="screens.css">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&family=Roboto:wght@400;500;600&display=swap" rel="stylesheet">
</head>
<body>
  <div class="device-frame">
    <div class="screen upload-manager">
      <div class="um-appbar">
        <div class="um-icon-btn" style="margin-left: 4px;">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor"><path d="M20 11H7.83l5.59-5.59L12 4l-8 8 8 8 1.41-1.41L7.83 13H20v-2z"/></svg>
        </div>
        <div class="um-appbar-title">Pending uploads</div>
{appbar_actions}
      </div>

      <div class="um-body">
        <div class="um-list">
{chip_html}
          <div class="um-batch">
            <div class="um-batch-header">
              <div class="um-batch-title">{batch_time}</div>
              <div class="um-batch-count">{batch_count} of 5</div>
              <div class="um-progress-container">
                <div class="um-progress-fill" style="width: {progress_pct}%;"></div>
              </div>
            </div>
            <div class="um-card">
{rows_html}
            </div>
          </div>
{reassurance}
          <div class="um-btn-container">
            <div class="um-outlined-btn">
              <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/></svg>
              Start new batch
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
{extra_html}
</body>
</html>
"""
        with open(os.path.join(css_dir, f"{name}.html"), "w", newline='\n') as f:
            f.write(re.sub(r'^[ \\t]+$', '', html, flags=re.MULTILINE))

    def build_um_row(filename, tone, extra_label='', evidence_transcription=False):
        if tone == 'awaitingLink':
            color = 'var(--um-on-surface-variant)'
            text = 'Waiting for connection'
            icon = '<path d="M19.35 10.04C18.67 6.59 15.64 4 12 4c-1.48 0-2.85.43-4.01 1.17l1.46 1.46C10.21 5.9 11.08 5.5 12 5.5c2.88 0 5.28 2.08 5.89 4.88l.27 1.25H19c2.21 0 4 1.79 4 4 0 1.21-.55 2.29-1.4 3.01l1.43 1.43c1.23-1.1 2.02-2.71 2.02-4.5-.01-3.13-2.45-5.74-5.7-6.03zM3.41 4.86L2 6.27l4.89 4.89C5.1 12.13 4 13.94 4 16c0 3.31 2.69 6 6 6h9.73l2 2 1.41-1.41L3.41 4.86zM10 19.98c-2.21 0-4-1.79-4-4 0-1.89 1.34-3.48 3.12-3.88l4.85 4.85c-.41 1.83-2.04 3.03-3.97 3.03z"/>'
        elif tone == 'queued':
            color = 'var(--um-on-surface-variant)'
            text = 'In queue'
            icon = '<path d="M11.99 2C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8zm.5-13H11v6l5.25 3.15.75-1.23-4.5-2.67z"/>'
        elif tone == 'uploading':
            color = 'var(--um-primary)'
            text = 'Uploading'
            icon = '<path d="M4 12l1.41 1.41L11 7.83V20h2V7.83l5.58 5.59L20 12l-8-8-8 8z"/>'
        elif tone == 'retrying':
            color = 'var(--um-tertiary)'
            text = 'Retrying &middot; attempt 3'
            icon = '<path d="M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z"/>'
        elif tone == 'failed':
            color = 'var(--um-error)'
            text = 'Can\'t upload &middot; file missing'
            icon = '<path d="M11 15h2v2h-2zm0-8h2v6h-2zm.99-5C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z"/>'
        else:
            color = 'var(--um-primary)'
            text = 'Synced'
            icon = '<path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/>'

        filename_tag = f'<div class="um-filename" style="text-overflow: clip;" title="Screenshot-visible filename transcription only; unseen UUID suffix intentionally unreconstructed.">{filename}</div>' if evidence_transcription else f'<div class="um-filename">{filename}</div>'

        return f'''              <div class="um-row"{extra_label}>
                <div class="um-thumb"></div>
                {filename_tag}
                <div class="um-status-icon" style="color: {color};">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="currentColor">{icon}</svg>
                </div>
                <div class="um-status-text" style="color: {color};">{text}</div>
              </div>'''

    render_frame("01-camera-ready", "01 Camera Ready", 1.0, False, 0, 0, 0)
    render_frame("02-camera-focus-zoom", "02 Camera Focus Zoom", 2.4049, True, 142.69, 342.70, 0)
    render_frame("03-camera-active-batch", "03 Camera Active Batch", 1.0, False, 0, 0, 3)

    # 04 Connected Pending
    pending_rows = [
        build_um_row("IMG_0031.jpg", "uploading"),
        build_um_row("IMG_0032.jpg", "uploading"),
        build_um_row("IMG_0033.jpg", "queued"),
        build_um_row("IMG_0034.jpg", "queued"),
        build_um_row("IMG_0035.jpg", "queued"),
    ]
    render_upload_manager("04-upload-manager-pending", "04 Upload Manager Pending", False, True, False, "BATCH &middot; just now", "0", 0, chr(10).join(pending_rows))

    # 05 Offline Retrying (Primary) + Source-derived retrying/failed variants
    offline_rows = [
        # EVIDENCE-BOUNDED: UUID suffixes unknown. Only verified screenshot prefixes used.
        build_um_row("95ca5e7c-…", "awaitingLink", evidence_transcription=True),
        build_um_row("99d2c191-…", "awaitingLink", evidence_transcription=True),
        build_um_row("3c5080bf-…", "awaitingLink", evidence_transcription=True),
        build_um_row("4bc0f074-…", "awaitingLink", evidence_transcription=True),
        build_um_row("61f41a2c-…", "awaitingLink", evidence_transcription=True),
    ]
    extra_html = '''
  <!-- EVIDENCE-BOUNDED: UUID suffixes unknown. Only verified screenshot prefixes used. -->
  <div style="margin-top: 32px; max-width: var(--release-width); font-family: system-ui, -apple-system, sans-serif; display: flex; flex-direction: column; align-items: center; justify-content: center;">
    <div style="color: #FFF; font-size: 14px; margin-bottom: 8px;">Source-derived row variants; no committed runtime screenshot evidence.</div>
    <div class="um-card" style="background-color: var(--um-surface-container, #1E1E1E); width: 100%; border-radius: 12px; overflow: hidden;">
''' + build_um_row("IMG_0036.jpg", "retrying") + chr(10) + build_um_row("IMG_0037.jpg", "failed") + '''
    </div>
  </div>'''
    render_upload_manager("05-upload-manager-retrying", "05 Upload Manager Retrying", False, True, True, "BATCH &middot; just now", "0", 0, chr(10).join(offline_rows), extra_html=extra_html)

    # 06 Empty
    render_upload_manager("06-upload-manager-empty", "06 Upload Manager Empty", True, False, False, "", "0", 0, "")

    # 08 Success
    success_rows = [
        # EVIDENCE-BOUNDED: UUID suffixes unknown. Only verified screenshot prefixes used.
        build_um_row("95ca5e7c-5174-4074-93…", "synced", evidence_transcription=True),
        build_um_row("99d2c191-66c2-4038-8…", "synced", evidence_transcription=True),
        build_um_row("3c5080bf-554d-4d5f-b1…", "synced", evidence_transcription=True),
        build_um_row("4bc0f074-d9bc-4b8d-86…", "synced", evidence_transcription=True),
        build_um_row("61f41a2c-587d-4456-b8…", "synced", evidence_transcription=True),
    ]
    render_upload_manager("08-upload-manager-success", "08 Upload Manager Success", False, False, False, "BATCH &middot; just now", "5", 100, chr(10).join(success_rows), extra_html='<!-- EVIDENCE-BOUNDED: UUID suffixes unknown. Only verified screenshot prefixes used. -->')
    # We also render 07 and 09 via their explicit function calls within the block, wait they are called at definition. Wait, no they are in the render_status_code string.


    def render_status_panel(title, msg, is_busy=False, icon_svg='', primary_txt='', primary_svg='', secondary_txt='', reassurance=''):
        busy_html = '<div class="spinner"></div>' if is_busy else f'''<div class="status-icon">
          <svg width="44" height="44" viewBox="0 0 24 24">{icon_svg}</svg>
        </div>'''

        primary_html = f'''<div class="status-primary-action">
          {f'<svg width="18" height="18" viewBox="0 0 24 24">{primary_svg}</svg>' if primary_svg else ''}
          {primary_txt}
        </div>''' if primary_txt else ''

        secondary_html = f'''<div class="status-secondary-action">
          {secondary_txt}
        </div>''' if secondary_txt else ''

        reassure_html = f'''<div class="status-reassurance">{reassurance}</div>''' if reassurance else ''

        lines = [
            '<div class="device-frame">',
            '  <div class="camera-status-panel">',
            f'    {busy_html}',
            f'    <div class="status-title">{title}</div>',
            f'    <div class="status-message">{msg}</div>'
        ]
        if primary_html: lines.append(f'    {primary_html}')
        if secondary_html: lines.append(f'    {secondary_html}')
        if reassure_html: lines.append(f'    {reassure_html}')
        lines.extend([
            '  </div>',
            '  <div class="top-chrome" style="pointer-events: auto;">',
            '    <div class="offline-placeholder"></div>',
            '    <div class="uploads-entry">',
            '      Uploads',
            '      <svg viewBox="0 0 24 24"><path d="M10 6L8.59 7.41 13.17 12l-4.58 4.59L10 18l6-6z"/></svg>',
            '    </div>',
            '  </div>',
            '</div>'
        ])

        html = '\\n'.join(lines)
        html = re.sub(r'^[ \\t]+$', '', html, flags=re.MULTILINE)
        return html


    def render_gallery(filename, title, phones, subtitle=""):
        phones_html = '\n'.join([f'''<div class="phone-col"><div class="phone-label">{label}</div>{panel}</div>''' for label, panel in phones])
        html = f'''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>{title}</title>
  <link rel="stylesheet" href="screens.css">
  <style>body {{ background: #222; align-items: flex-start; }}</style>
</head>
<body>
  <div style="padding: 32px; font-family: system-ui, sans-serif; color: #fff;">
    <h1 style="margin: 0 0 8px 0;">{title}</h1>
    <div style="color: #bbb; max-width: 800px; line-height: 1.5;">{subtitle}</div>
    <div class="phone-grid">
      {phones_html}
    </div>
  </div>
</body>
</html>'''
        with open(os.path.join(css_dir, filename), "w", newline='\n') as f:
            f.write(re.sub(r'^[ \\t]+$', '', html, flags=re.MULTILINE))

    # Icons
    icon_photo = '<path d="M19 8h-1V6c0-1.1-.9-2-2-2H8c-1.1 0-2 .9-2 2v2H5c-1.1 0-2 .9-2 2v10c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V10c0-1.1-.9-2-2-2zm-3-2v2H8V6h8v2zm3 14H5V10h14v12zm-7-9c-1.65 0-3 1.35-3 3s1.35 3 3 3 3-1.35 3-3-1.35-3-3-3z"/>'
    icon_no_photo = '<path d="M20.49 21.9L2.1 3.51 3.51 2.1l18.39 18.39-1.41 1.41zM12 16.5c-2.49 0-4.5-2.01-4.5-4.5 0-.74.19-1.44.5-2.07l6.07 6.07c-.63.31-1.33.5-2.07.5zM21 9v11.17l-2-2V9.83L17.17 8H13.4L11.4 6h3.42l2.06 2H21zM9.54 4l-2.06-2h3.42l2.06 2zM3.46 7.74L5 9.28V20h10.72l2 2H5c-1.1 0-2-.9-2-2V9.28c0-.58.26-1.12.7-1.49L3.46 7.74z"/>'
    icon_settings = '<path d="M19.43 12.98c.04-.32.07-.64.07-.98 0-.34-.03-.66-.07-.98l2.11-1.65c.19-.15.24-.42.12-.64l-2-3.46c-.12-.22-.39-.3-.61-.22l-2.49 1c-.52-.4-1.08-.73-1.69-.98l-.38-2.65C14.46 2.18 14.25 2 14 2h-4c-.25 0-.46.18-.49.42l-.38 2.65c-.61.25-1.17.59-1.69.98l-2.49-1c-.23-.09-.49 0-.61.22l-2 3.46c-.13.22-.07.49.12.64l2.11 1.65c-.04.32-.07.65-.07.98 0 .33.03.66.07.98l-2.11 1.65c-.19.15-.24.42-.12.64l2 3.46c.12.22.39.3.61.22l2.49-1c.52.4 1.08.73 1.69.98l.38 2.65c.03.24.24.42.49.42h4c.25 0 .46-.18.49-.42l.38-2.65c.61-.25 1.17-.59 1.69-.98l2.49 1c.23.09.49 0 .61-.22l2-3.46c.12-.22.07-.49-.12-.64l-2.11-1.65zM12 15.5c-1.93 0-3.5-1.57-3.5-3.5s1.57-3.5 3.5-3.5 3.5 1.57 3.5 3.5-1.57 3.5-3.5 3.5z"/>'
    icon_video_off = '<path d="M21 6.5l-4 4V7c0-.55-.45-1-1-1H9.82L21 17.18V6.5zM3.27 2L2 3.27 4.73 6H4c-.55 0-1 .45-1 1v10c0 .55.45 1 1 1h12c.21 0 .39-.08.54-.18L19.73 21 21 19.73 3.27 2z"/>'
    icon_error = '<path d="M11 15h2v2h-2zm0-8h2v6h-2zm.99-5C6.47 2 2 6.48 2 12s4.47 10 9.99 10C17.52 22 22 17.52 22 12S17.52 2 11.99 2zM12 20c-4.42 0-8-3.58-8-8s3.58-8 8-8 8 3.58 8 8-3.58 8-8 8z"/>'
    icon_refresh = '<path d="M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z"/>'

    # 07 Permissions
    phone_a = render_status_panel('Camera access is off', 'PresenceLens needs the camera to take photos.', False, icon_no_photo, 'Allow camera', icon_photo)
    phone_b = render_status_panel('Camera access is off', 'PresenceLens needs the camera to take photos.', False, icon_no_photo, 'Allow camera', icon_photo, 'Open settings', 'Your 3 queued photos are safe')
    phone_c = render_status_panel('Camera access is off', 'PresenceLens needs the camera to take photos. You can turn access back on in Settings.', False, icon_no_photo, 'Open settings', icon_settings)

    render_gallery('07-camera-permission-error.html', '07 Camera Permission Error Variants', [
        ('<b>Variant A: Retryable first refusal</b><br>canRetry=true, denials<2', phone_a),
        ('<b>Variant B: Retryable repeated refusal</b><br>canRetry=true, denials>=2<br><i>Representative queued count; source-derived behavior, no committed runtime screenshot evidence.</i>', phone_b),
        ('<b>Variant C: Non-retryable</b><br>canRetry=false', phone_c),
    ], "Source-derived from shipped camera state/presentation code; no committed runtime screenshot evidence for this state.<br><br>Repeated Android denial broadens offered recovery actions; it is not itself a permanent-denial verdict.")

    # 09 Status Family
    busy1 = render_status_panel('Finding your cameras', 'One moment.', True)
    busy2 = render_status_panel('Starting the camera', 'One moment.', True)
    busy3 = render_status_panel('Switching camera', 'One moment.', True)
    busy4 = render_status_panel('Reopening the camera', 'One moment.', True)

    unavail1 = render_status_panel('No rear camera', 'This device has no rear-facing camera, so captures are not possible here.', False, icon_video_off)
    unavail2 = render_status_panel('No camera found', 'This device did not report a usable camera.', False, icon_video_off)

    fail1 = render_status_panel("Camera isn't available", 'Another app may be using the camera. Try again.', False, icon_error, 'Try again', icon_refresh)
    fail2 = render_status_panel("Camera didn't start", 'Another app may be using the camera. Try again.', False, icon_error, 'Try again', icon_refresh)

    render_gallery('09-camera-status.html', '09 Camera Status Non-Ready Family', [
        ('CameraPreparing(discovering)', busy1),
        ('CameraPreparing(initializing)', busy2),
        ('CameraPreparing(switching)', busy3),
        ('CameraInitial<br>CameraReleased<br>CameraPreparing(restoring)', busy4),
        ('CameraPermissionDenied (Variant A)<br>See 07 for full variants', phone_a),
        ('CameraUnavailable(noBackCamera)', unavail1),
        ('CameraUnavailable(noCameras)', unavail2),
        ('CameraFailed(cameraUnavailable)', fail1),
        ('CameraFailed(other)', fail2),
    ], "Source-derived from shipped camera state/presentation code; no committed runtime screenshot evidence for this state.<br><br>13/13 source situations covered.")

if __name__ == "__main__":
    build()
