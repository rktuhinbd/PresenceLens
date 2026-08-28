# Submission Checklist

Binary and auditable. Every line is either objectively true or it is not — no
"mostly", no "in progress". Anything not ticked is not delivered.

Walked end to end at gate G9. Each item names the requirement it discharges.

---

## 1. Repository — public GitHub

| # | Check | Req |
| --- | --- | --- |
| 1.1 | [ ] Repository exists on GitHub. | SUB-01 |
| 1.2 | [ ] Repository visibility is **Public**. | SUB-01 |
| 1.3 | [ ] Repository URL loads **while signed out of GitHub** (verified in a private window, not assumed from the settings page). | SUB-01 |
| 1.4 | [ ] Default branch contains the final submitted state. | SUB-01 |
| 1.5 | [ ] Repository has a description and is not named as a throwaway. | GEN-05 |

## 2. Source code — complete and functioning

| # | Check | Req |
| --- | --- | --- |
| 2.1 | [ ] Native Android application source is committed. | AND-01, SUB-01 |
| 2.2 | [ ] Flutter application source is committed. | FLT-01, SUB-01 |
| 2.3 | [ ] Clean clone into an empty directory succeeds. | SUB-01, DOC-07 |
| 2.4 | [ ] Android `assembleDebug` passes **on the clean clone**. | SUB-01 |
| 2.5 | [ ] `flutter build apk --debug` passes **on the clean clone**. | SUB-01 |
| 2.6 | [ ] Android unit tests pass. | GEN-08 |
| 2.7 | [ ] `flutter test` passes. | GEN-08 |
| 2.8 | [ ] `flutter analyze` reports no issues. | GEN-08 |
| 2.9 | [ ] Android lint/format clean. | GEN-08 |
| 2.10 | [ ] No `TODO`, placeholder, or dead scaffold left in shipped code. | EXP-04 |

## 3. Repository hygiene

| # | Check | Req |
| --- | --- | --- |
| 3.1 | [ ] No secrets or API keys in the working tree **or in Git history**. | AGENTS.md |
| 3.2 | [ ] No signing keystore (`*.jks`, `*.keystore`, `key.properties`) committed. | AGENTS.md |
| 3.3 | [ ] No `local.properties` or machine-specific SDK path committed. | AGENTS.md |
| 3.4 | [ ] No `build/`, `.gradle/`, `.dart_tool/` directories committed. | AGENTS.md |
| 3.5 | [ ] No `.apk` or `.aab` binaries committed. | AGENTS.md |
| 3.6 | [ ] **The assessment source PDF is not committed.** | AGENTS.md |
| 3.7 | [ ] No personal documents (e.g. résumé) committed. | AGENTS.md |
| 3.8 | [ ] Commit history is meaningful; no "wip"/"fix" noise as the final state. | GEN-08 |
| 3.9 | [ ] No force-push or rewritten history. | AGENTS.md |

## 4. README — mandated sections

The assessment specifies five sections. All five, in order, none a placeholder.

| # | Check | Req |
| --- | --- | --- |
| 4.1 | [ ] `README.md` exists at the repository root. | DOC-01 |
| 4.2 | [ ] **§1 Project Title and Description** present. | DOC-02 |
| 4.3 | [ ] Title reflects a deliberately chosen project name. | GEN-05 |
| 4.4 | [ ] Description covers **both** applications. | GEN-06 |
| 4.5 | [ ] **§2 Project Structure / Approaches** present. | DOC-03 |
| 4.6 | [ ] §2 explains the architectural approach (Layered Architecture, BLoC pattern). | DOC-03 |
| 4.7 | [ ] §2 **names the main BLoC/Cubit classes**, in 1–2 sentences. | DOC-04 |
| 4.8 | [ ] Every class named in §2 **actually exists in source** (each one checked). | DOC-04, EXP-04 |
| 4.9 | [ ] **§3 Generative AI Usage** present — explicitly mandatory. | DOC-05 |
| 4.10 | [ ] §3 explains how AI was used on this project. | DOC-05 |
| 4.11 | [ ] §3 includes **some of the essential prompts** actually entered. | DOC-06 |
| 4.12 | [ ] **§4 How to Run** present. | DOC-07 |
| 4.13 | [ ] §4 includes clone steps. | DOC-07 |
| 4.14 | [ ] §4 includes prerequisites (JDK, Android SDK, Flutter/Dart versions). | DOC-07 |
| 4.15 | [ ] §4 includes run steps for **both** apps. | DOC-07 |
| 4.16 | [ ] §4 states the runtime permissions each app requires. | GEN-04 |
| 4.17 | [ ] **§4 steps executed verbatim on a clean clone by following only the README.** | DOC-07 |
| 4.18 | [ ] **§5 Screenshots** present. | DOC-08 |
| 4.19 | [ ] Screenshots of the Android attendance screen included. | DOC-08 |
| 4.20 | [ ] Screenshots of the Flutter camera and Upload Manager screens included. | DOC-08 |
| 4.21 | [ ] GIF: crossing the 50 m boundary with the live distance updating. | DOC-08, AND-09 |
| 4.22 | [ ] GIF: offline → online automatic retry with no user interaction. | DOC-08, FLT-12 |
| 4.23 | [ ] All media renders correctly **on github.com**, not just locally. | DOC-08 |

## 5. Architecture documentation

| # | Check | Req |
| --- | --- | --- |
| 5.1 | [ ] Architectural approach documented for both apps. | DOC-03 |
| 5.2 | [ ] Documented structure matches the shipped code. | DOC-03, EXP-04 |
| 5.3 | [ ] Android state management via Kotlin Flow is explained. | AND-12 |
| 5.4 | [ ] Flutter BLoC/Cubit usage is explained. | FLT-14 |
| 5.5 | [ ] Local persistence choices explained for both apps. | GEN-03 |
| 5.6 | [ ] Deliberate trade-offs disclosed (ADR-003 map, ADR-011 window, ADR-004 single module). | EXP-03 |

## 6. AI usage disclosure

| # | Check | Req |
| --- | --- | --- |
| 6.1 | [ ] `docs/AI_USAGE.md` maintained. | EXP-02 |
| 6.2 | [ ] README §3 is consistent with `AI_USAGE.md`. | DOC-05 |
| 6.3 | [ ] Essential prompts included and genuinely representative — not reconstructed. | DOC-06 |
| 6.4 | [ ] Tools and models named. | DOC-05 |
| 6.5 | [ ] **Every retained AI-assisted implementation can be explained by the author.** | EXP-02, AGENTS.md |

## 7. Android functional verification

| # | Check | Req |
| --- | --- | --- |
| 7.1 | [ ] Screen is named `AttendanceScreen`. | AND-03 |
| 7.2 | [ ] Setting the office location and marking attendance happen on the **same screen**. | AND-04 |
| 7.3 | [ ] A "Set Office Location" button exists. | AND-05 |
| 7.4 | [ ] It fetches the **current GPS coordinates**. | AND-06 |
| 7.5 | [ ] Coordinates persist across force-stop and relaunch. | AND-07 |
| 7.6 | [ ] "Mark Attendance" is disabled outside 50 m. | AND-08 |
| 7.7 | [ ] "Mark Attendance" is enabled and functional within 50 m. | AND-08 |
| 7.8 | [ ] Boundary behaviour unit-tested at 49.9 / 50.0 / 50.1 m. | AND-08 |
| 7.9 | [ ] Distance indicator updates in real time without user action. | AND-09 |
| 7.10 | [ ] UI matches the p2 reference screenshot (compared side by side). | AND-10 |
| 7.11 | [ ] Built with Jetpack Compose. | AND-11 |
| 7.12 | [ ] Permission-denied, permanently-denied, and services-off states handled. | GEN-04 |
| 7.13 | [ ] Location updates stop when the screen is not resumed. | ADR-001 |

## 8. Flutter functional verification

| # | Check | Req |
| --- | --- | --- |
| 8.1 | [ ] Screen is named `CameraPreviewScreen`. | FLT-02 |
| 8.2 | [ ] Pinch-to-zoom works on a physical device. | FLT-03 |
| 8.3 | [ ] Zoom slider works. | FLT-04 |
| 8.4 | [ ] Rounded zoom preset buttons work. | FLT-05 |
| 8.5 | [ ] Tap-to-focus works. | FLT-06 |
| 8.6 | [ ] A visual focus indicator appears **at the tap point**. | FLT-07 |
| 8.7 | [ ] Multiple batches can be captured. | FLT-08 |
| 8.8 | [ ] A "Pending Uploads" list is shown. | FLT-09 |
| 8.9 | [ ] A background worker monitors connectivity. | FLT-10 |
| 8.10 | [ ] On no-internet failure, **row and file both remain** in the queue. | FLT-11 |
| 8.11 | [ ] On low-bandwidth failure, **row and file both remain** in the queue. | FLT-11 |
| 8.12 | [ ] Upload retries automatically on reconnect with **zero user interaction**. | FLT-12 |
| 8.13 | [ ] Queue survives app kill and device reboot. | FLT-16 |
| 8.14 | [ ] Mock API returns deterministic Success and Failed, toggleable at runtime. | FLT-13 |
| 8.15 | [ ] All five per-item upload states render. | FLT-18 |
| 8.16 | [ ] Camera-permission-denied and camera-unavailable handled gracefully. | GEN-04 |

## 9. Release APK

| # | Check | Req |
| --- | --- | --- |
| 9.1 | [x] Android `assembleRelease` succeeds. **2026-08-28**, signed via ADR-010, `apksigner`-verified. | SUB-03 |
| 9.2 | [ ] `flutter build apk --release` succeeds. | SUB-03 |
| 9.3 | [ ] **Both release APKs are signed and installable** (not unsigned — see B-01). Android half done (B-01 resolved); Flutter APK does not exist yet. | SUB-03 |
| 9.4 | [ ] Both APKs uploaded to a file-sharing service. | SUB-03 |
| 9.5 | [ ] **Share links accessible to anyone with the link** (verified signed out). | SUB-03 |
| 9.6 | [ ] Links included in the README. | SUB-03 |
| 9.7 | [ ] Both APKs install on a device that has never had them. | SUB-03, DA-08 |
| 9.8 | [ ] Both apps launch and run from the installed release build. | SUB-03 |
| 9.9 | [ ] Application IDs do not collide; both install side by side. | DA-09 |
| 9.10 | [ ] APK filenames identify which app each is. | AMB-09, EXP-04 |

## 10. Final audit (G9)

| # | Check | Req |
| --- | --- | --- |
| 10.1 | [ ] **All 4 PDF pages re-read**, including all 3 screenshots. | EXP-01 |
| 10.2 | [ ] Every explicit requirement reconciled against the matrix — **audited against the PDF, not against the matrix**. | EXP-01 |
| 10.3 | [ ] No mandatory requirement was downgraded to optional. | EXP-04 |
| 10.4 | [ ] No invented feature was promoted to mandatory. | EXP-03 |
| 10.5 | [ ] Every matrix row is `DONE` with real evidence, or knowingly deferred and recorded. | EXP-04 |
| 10.6 | [ ] All open ambiguities either resolved in an ADR or disclosed in the README. | EXP-03 |
| 10.7 | [ ] All ADRs are `ACCEPTED` or `SUPERSEDED` — none left dangling as `PROPOSED`. | EXP-03 |
| 10.8 | [ ] Documents are mutually consistent (matrix, architecture, decisions, state). | EXP-04 |
| 10.9 | [ ] Delivered within the 48–72 hour window. | GEN-09 |
| 10.10 | [ ] Final submission message includes the repository URL and both APK links. | SUB-01, SUB-03 |
