# Research

Three strictly separated sections. The separation is the point: a claim in the wrong
section becomes a bug later.

- **Verified findings** — observed directly in this environment during this session.
- **External research required** — must be confirmed against authoritative
  documentation before the dependent decision can move to `ACCEPTED`.
- **Assumptions requiring device/emulator validation** — cannot be settled by reading;
  only hardware answers them.

**Sourcing rule.** Findings marked *(G0.1 human review)* were verified by the human
reviewer against **official Android Developers documentation** on 2026-08-28 and are
attributed to that review rather than to a fabricated citation, since no agent had web
access at that time. From G1 onward, the agent session had live web access; findings
marked "live web research this session" name the pages actually fetched. No finding is
ever cited to a URL that was not fetched during the session doing the citing. Items in
section 2 remain open questions, not findings.

---

## 1. Verified findings

Each was observed directly in this environment on 2026-08-28.

| ID | Finding | How it was verified |
| --- | --- | --- |
| RF-01 | The assessment PDF is 4 pages with 3 embedded screenshots (p2: one 237x588 Android reference; p3: two 138x312 Flutter references). | `pdfplumber` page/image enumeration. |
| RF-02 | Text extraction is consistent across three independent methods, so the requirement text is trustworthy. | `pdftotext -layout`, `pdftotext -raw`, and `pdfplumber` produce matching content. |
| RF-03 | **Source text is genuinely lost across the p2/p3 boundary.** Page 2's last text run ends at the literal token `..` (x=490.3, top=778.1, page height 792); page 3 opens with `available back cameras).` No hidden or clipped run exists. | Character-level dump of every word on p2 with coordinates. Basis for AMB-01. |
| RF-04 | The p2 Android screenshot is prescriptive ("Please refer to the following screenshot for building the UI"), whereas the p3 Flutter screenshots are advisory ("Suggested UI:"). | Direct reading of both captions. Basis for the split treatment in the matrix. |
| RF-05 | The p2 reference contains "AVAILABLE 09:00 AM - 10:30 AM", which appears in **no** sentence of the assessment. | Rendered p2 at 8x and read; full text search of all 4 pages. Basis for AMB-02 / ADR-011. |
| RF-06 | The p3 Upload Manager reference shows five distinct per-item states: waiting for connection, retrying with an attempt counter, uploading with a percentage, synced, and in queue. | Rendered and read the p3 right screenshot at 8x. Basis for FLT-18. |
| RF-07 | Android baseline: AGP 9.3.2, Gradle 9.5.0, Kotlin 2.2.10, Compose BOM 2026.02.01, `compileSdk`/`targetSdk` 37, `minSdk` 24, namespace `io.github.rktuhinbd.presencelens.attendance`. | Read `gradle/libs.versions.toml`, `app/build.gradle.kts`, `gradle-wrapper.properties`. |
| RF-08 | `app/build.gradle.kts` applies only `com.android.application` and `org.jetbrains.kotlin.plugin.compose` — **no explicit `org.jetbrains.kotlin.android`** — yet Kotlin sources compile and `assembleDebug` passes (per the human's verified baseline). | Read the build file; build result reported by the human. Explained by `RF-17`. |
| RF-09 | **The release build type defines no `signingConfig`, and `optimization.enable = false`.** An `assembleRelease` today would produce an unsigned APK. | Read `app/build.gradle.kts`. Directly blocks SUB-03; basis for ADR-010. |
| RF-10 | No feature dependencies are present yet: no location services, DataStore, Room, navigation, or DI entries in the version catalog. | Read `gradle/libs.versions.toml`. |
| RF-11 | The Gradle daemon targets JDK 25 via toolchain auto-provisioning, while the `java` on PATH is 1.8.0_501. | Read `gradle/gradle-daemon-jvm.properties`; `java -version`. Superseded in practice by `RF-20`. |
| RF-12 | Flutter 3.41.2 stable with Dart 3.11.0 is installed at `C:\flutter`. | `flutter --version --machine`. |
| RF-13 | `adb` is not on PATH in this shell. Device verification will need Android Studio or an explicit platform-tools path. | Command lookup. Affects G7 procedure. |
| RF-14 | `.gitignore` already excludes `*.apk`, `*.aab`, `local.properties`, `*.jks`, `*.keystore`, `key.properties`, and `google-services.json`. | Read `.gitignore`. Satisfies the AGENTS.md commit prohibitions. |
| RF-15 | The working tree is clean and only the Android baseline plus governance docs are tracked. No Flutter project exists. | `git status --porcelain`, `git ls-files`. |
| RF-16 | Gradle configuration cache is enabled (`org.gradle.configuration-cache=true`). | Read `gradle.properties`. Relevant if build scripts change in G8. |
| RF-17 | **Android Gradle Plugin 9+ provides built-in Kotlin support, enabled by default.** The absence of `org.jetbrains.kotlin.android` in this AGP 9 project is therefore expected, not a defect. Explains RF-08. | Official Android Developers documentation *(G0.1 human review)*. Closes `ER-01`. |
| RF-18 | **Android recommends a minimum geofence radius of roughly 100–150 m for best results.** A 50 m eligibility rule sits well below that, making `GeofencingClient` a poor semantic and technical fit for immediate on-screen validation. | Official Android Developers documentation *(G0.1 human review)*. Closes `ER-03`; promotes ADR-001 to `ACCEPTED`. |
| RF-19 | **DataStore is intended for small, simple datasets; Room is preferred for complex datasets, partial updates, or referential integrity.** A single office coordinate pair falls squarely in DataStore's intended range. | Official Android Developers documentation *(G0.1 human review)*. Confirms ADR-002. |
| RF-20 | **Command-line builds are viable.** The human verified from PowerShell: Gradle sync PASS, clean PASS, `assembleDebug` PASS, emulator launch PASS. PowerShell with the Gradle wrapper is therefore the documented CLI build path. | Manual verification by the human reviewer, 2026-08-28 *(G0.1 human review)*. Resolves `DA-07`. |
| RF-21 | **`FusedLocationProviderClient` ships in `com.google.android.gms:play-services-location`, current stable `21.4.0`.** No API redesign at this version affects the streaming-updates-plus-one-shot-current-location shape ADR-001 already specifies. | Live web research this session (`developers.google.com/android/guides/releases`, cross-checked against `mvnrepository.com`), 2026-08-28. Closes `ER-02`. Unlike G0.1, this session had live web access, so the coordinate is cited directly rather than attributed to human review. |
| RF-22 | **Preferences DataStore's current stable artifact is `androidx.datastore:datastore-preferences:1.2.1`.** `datastore-preferences-core` is the Android-free variant; not needed here since the app is Android-only. No Proto DataStore is warranted — the stored shape (two doubles plus a timestamp) has no schema-evolution need Proto solves and Preferences already satisfies ADR-002. | Live web research this session (`developer.android.com/jetpack/androidx/releases/datastore`, cross-checked against `mvnrepository.com`), 2026-08-28. Closes `ER-04`. |
| RF-23 | **Current stable coordinates for the Compose-facing lifecycle libraries are `androidx.lifecycle:lifecycle-viewmodel-compose:2.11.0` and `androidx.lifecycle:lifecycle-runtime-compose:2.11.0`** (released 2026-06-17), matching the already-pinned Kotlin 2.2.10 / Compose BOM 2026.02.01 baseline. `lifecycle-runtime-ktx` bumped from `2.6.1` to `2.11.0` for one consistent lifecycle version across the catalog. | Live web research this session (`developer.android.com/jetpack/androidx/releases/lifecycle`), 2026-08-28. Supports ADR-006 (`AND-12`); not a numbered `ER` item, recorded for traceability. |
| RF-24 | **Current stable `org.jetbrains.kotlinx:kotlinx-coroutines-android` is `1.11.0`**, compatible with Kotlin 2.2.10. Declared explicitly rather than relied on transitively from `lifecycle-runtime-ktx`, since `domain`/`data` use `Flow`/`callbackFlow` directly (ADR-006, ADR-001). | Live web research this session (`mvnrepository.com`, `github.com/Kotlin/kotlinx.coroutines`), 2026-08-28. |

---

## 2. External research required

Open questions. Each names the decision it gates. **None of these may be answered from
memory** — the toolchain versions in this project are recent enough that recalled
details are a poor substitute for current documentation.

| ID | Question | Gates | Why it matters |
| --- | --- | --- | --- |
| ER-05 | **CLOSED at F0 — the answer is no.** `camera_android_camerax` never populates `lensType`; only iOS does. See [docs/flutter/RESEARCH.md](flutter/RESEARCH.md) `FR-04` and `ADR-F03`. Original question: `camera` plugin capability matrix: zoom range and set-zoom, focus-point and exposure-point support, and **whether an ultra-wide 0.5x lens is exposed as a separate camera or as a zoom level below 1.0**. | G5, FLT-03 to FLT-07 | Decides whether 0.5x is a zoom value or a camera switch — a structural difference in `CameraDataSource`. Compounded by AMB-01, where the source text for this very bullet is lost. |
| ER-06 | **CLOSED at F0** — see [docs/flutter/RESEARCH.md](flutter/RESEARCH.md) `FR-07`. `workmanager` 0.10.9 resolves and builds against Flutter 3.47.2 / Dart 3.13.2. Original question: `workmanager` status and compatibility, and its behaviour under current Android background-execution limits at `targetSdk` 37. | G6, FLT-10 | The assessment names `workmanager` only as an example. If it is unmaintained or incompatible at this SDK level, an equivalent must be chosen deliberately and recorded as an ADR. |
| ER-07 | **CLOSED at F0 — link presence only.** `connectivity_plus` states it does not guarantee internet access; see `FR-05` and `ADR-F05`. Original question: whether the library reports **reachability** or only link presence, and how to detect a genuinely usable connection. | G6, FLT-12, AMB-15 | "Once a **stable** connection is detected" is the mandated trigger. Link-present-but-unusable is exactly the low-bandwidth case FLT-11 calls out, so getting this wrong defeats the requirement. |
| ER-08 | Android 14/15/16 and `targetSdk` 37 behaviour changes affecting background work, foreground services, and location access. | G2, G6 | `targetSdk` 37 is aggressive. Background retry (FLT-12) is the most likely casualty of a behaviour change. |
| ER-09 | Whether release-signing config can be made conditional so a clean clone without a keystore still builds. | G8, ADR-010 | ADR-010 depends on this being achievable; otherwise the fallback is debug-signing. |
| ER-10 | Material 3 component availability in Compose BOM 2026.02.01 for the p2 reference elements (chip, dashed container, custom arc gauge). | G3, AND-13 to AND-21 | Determines what must be hand-drawn on `Canvas` versus composed from library components. |

### Closed at G0.1 human review (2026-08-28)

Retained with their original IDs so existing references stay valid.

| ID | Question | Outcome |
| --- | --- | --- |
| ER-01 | Does AGP 9.x provide built-in Kotlin support, making a separate `org.jetbrains.kotlin.android` plugin unnecessary? | **CLOSED — yes.** AGP 9+ enables built-in Kotlin support by default, so RF-08 is expected behaviour. See `RF-17`. |
| ER-03 | Official guidance on minimum reliable geofence radius and transition latency. | **CLOSED.** Android recommends roughly 100–150 m minimum radius for best results, well above this feature's 50 m rule. See `RF-18`; ADR-001 is now `ACCEPTED`. |
| ER-02 | Current recommended `FusedLocationProviderClient` API surface and the correct dependency coordinate for Play Services Location. | **CLOSED at G1 (2026-08-28).** `com.google.android.gms:play-services-location:21.4.0`; no API-shape change affecting ADR-001's design. See `RF-21`. |
| ER-04 | Preferences DataStore vs Proto DataStore, and the correct artifact coordinate. | **CLOSED at G1 (2026-08-28).** `androidx.datastore:datastore-preferences:1.2.1`; Preferences confirmed sufficient, no schema-evolution need for Proto. See `RF-22`. |

---

## 3. Assumptions requiring device or emulator validation

Reading cannot settle these. Each is currently an assumption; the "If false" column
says what breaks, so a failure is recognised rather than absorbed.

| ID | Assumption | Validates | If false |
| --- | --- | --- | --- |
| DA-01 | The emulator's mock-location controls can move a device across the 50 m boundary in both directions, precisely enough to test the edge. | AND-08, AND-09 | Boundary verification needs a physical device and real movement, which costs significantly more time in G7. |
| DA-02 | Reported location accuracy on the emulator is realistic enough to exercise the low-quality-fix state. | GEN-04, AMB-14 | The quality state must be verified on a physical device instead. |
| DA-03 | Location-services-off and permission-denied states are reachable and recover correctly on the emulator. | GEN-04 | Manual device testing required. |
| DA-04 | **Pinch-to-zoom and tap-to-focus need a physical device** — the emulator camera does not meaningfully exercise them. | FLT-03 to FLT-07 | A physical Android device is mandatory for G5, not optional. Treated as likely true. |
| DA-05 | The test device exposes multiple back cameras including an ultra-wide, so 0.5x is demonstrable. | FLT-05 | Presets must degrade gracefully to the device's real range — which the FLT-05 design already requires, so this degrades rather than breaks. |
| DA-06 | Airplane-mode off→on transitions reliably wake the background worker while the app is backgrounded. | FLT-10, FLT-12 | The core resilience demo fails; may need a foreground-service approach, which is a design change, not a tweak. |
| DA-07 | ~~CLI build viability~~ — **RESOLVED, not an assumption.** The human verified sync, clean, `assembleDebug`, and emulator launch from PowerShell. PowerShell plus the Gradle wrapper is the documented CLI build path; Git Bash with Java 8 on PATH was never required. | — | See `RF-20`. No further action. |
| DA-08 | A release APK built here installs from a shared link on a clean device (unknown-sources flow). | SUB-03 | The submission's final step fails at the point where it is hardest to fix. Must be tested for real, not assumed. |
| DA-09 | Both apps' release APKs install side by side without applicationId collision. | SUB-03, AMB-09 | Application IDs must be deconflicted before G8. |
| DA-10 | Screen recording of the 50 m boundary crossing and the offline→online retry is capturable at usable quality for DOC-08. | DOC-08 | GIF evidence falls back to annotated stills, which is weaker evidence for behaviour that only motion proves. |

---

## Research discipline

- Anything moved into section 1 must name how it was verified.
- An ADR may not become `ACCEPTED` while an `ER-` item it depends on is open.
- If an assumption in section 3 is disproved, update the matrix and PROJECT_STATE.md
  in the same session — a stale assumption is worse than an open question.
