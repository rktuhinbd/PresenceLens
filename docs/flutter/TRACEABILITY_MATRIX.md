# Flutter Task — Traceability Matrix

**What this document is for:** it is the audit trail from a sentence in the
assessment PDF to the evidence that the sentence was satisfied. At submission it
is the document that answers "show me where you did this" in one lookup.

Chain: **assessment statement → requirement ID → component → implementation →
automated test → device evidence → submission evidence.**

`TBC` meant "planned, not yet produced" during implementation. **As of gate F7
(2026-08-30, submission), no row in this document reads `TBC`.** Every Device-column
entry below states what was actually confirmed on physical hardware, or — where a
specific supplemental check genuinely was not separately run — says so explicitly
rather than being marked done.

**Final state (submission, F7 complete, 2026-08-30).** Both screens are built,
evidenced by 521 host tests, and **physically verified on a HONOR DNP-NX9 (Android
16)**: live preview, pinch and slider zoom, capability-derived presets, tap-to-focus
with the reticle, capture, the double-shutter guard, camera lifecycle across
background/resume, multiple batches, Pending Uploads, and — the row every earlier
gate left open — **Android actually running the WorkManager worker and draining a
real offline-built queue with the app backgrounded and no retry press.** That last
path required first clearing a Honor-specific `HN_USER_EXPERIENCE` OEM
background-launch restriction in device Settings; no code-level fix exists or was
needed. Physical two-finger pinch is recorded as a **manual-user check** rather than
an automated one — `adb shell input` cannot produce trustworthy multi-touch — and is
corroborated by a second, independent physical pinch-to-zoom acceptance on a Samsung
Galaxy S25. Full account: [PROJECT_STATE.md §F7](../PROJECT_STATE.md) and
[AI_USAGE.md §F7](../AI_USAGE.md).

---

## 1. Mandatory assessment statements

Every MANDATORY row traced from its literal source sentence.

| Assessment statement (source) | Req ID | Component | Impl | Auto test | Device | Submission |
| --- | --- | --- | --- | --- | --- | --- |
| "Use a robust solution (BLoC/Cubit)" (p1) | FLT-GEN-001 | `CameraCubit`, `BatchCubit`, `SyncBloc` | **ALL THREE BUILT** — `CameraCubit` (sequencer, sealed state, generation guard), `BatchCubit` (the open batch and the finish action), `SyncBloc` (four fan-in sources, sealed events). Cubit vs Bloc decided per feature, not applied uniformly (`ARCHITECTURE.md` §3) | `BLOC` **PASS** (109 + 7) and 14 integration cases over real SQLite | — | README §2 names them (`DOC-04`) |
| "Any Layered Architecture for Flutter (MVVM/MVI)" (p1) | FLT-GEN-002 | `presentation`/`domain`/`data` | **BUILT** — `domain` (entities, policies, ports, one use case), `data` (database, storage, api, sync, identity, composition) | `domain_purity_test` **PASS** (5) | — | README §2 + ARCHITECTURE.md |
| "Any local data persistence" (p1) | FLT-GEN-003 | `AppDatabase`, `FileSystemCaptureStore` | **BUILT** — schema v1, two tables, two indices, FK cascade, migration hook | `DATA` suite **PASS** (58) | kill-and-relaunch **PASS (F7)** — queue survived force-stop and reboot with items pending | README §2 |
| "Graceful handling of permissions and hardware failures" (p1) | FLT-GEN-004 | `CameraCubit` states | **BUILT** — 12 classified error kinds; enumeration throw, no camera, no back camera, refusal, restriction, init failure, and capture/focus/zoom failures each reach their own state | `BLOC` **PASS**; `WIDGET` **PASS** (8) — every failure state renders its panel and keeps the Pending Uploads route | **PASS (F7)** — CAMERA-revoke/recovery and permission-recovery panels confirmed live, each keeping Pending Uploads reachable | Screenshots of error states |
| "Task 2 … (Flutter)" (p2) | FLT-GEN-005 | project | **DONE** — builds | `flutter build apk --debug` **PASS** | — | APK link (`FLT-DEL-003`) |
| "Build a camera preview screen `CameraPreviewScreen`" (p2) | FLT-CAM-001 | `CameraPreviewScreen` | **BUILT** — `CameraPreviewScreen`, the app’s home route, full-bleed over `buildCameraPreview`, with no close control (`ADR-F13`) | `WIDGET` **PASS** (33 cases mount it) | preview renders | Screenshot |
| *(same)* — live custom preview | FLT-CAM-002 | `CameraXAdapter`, `buildCameraPreview` | **ADAPTER BUILT AND NOW RENDERED** — `enableAudio: false`, capabilities read back from the controller, preview seam is one getter, and the screen renders it edge-to-edge | `WIDGET` **PASS** — the fake session degrades to the placeholder by design, which is *not* evidence a preview works | **PASS (F7)** — a real preview rendered and visibly tracked a moving physical scene | Screenshot |
| "Implement pinch-to-zoom" (p2) | FLT-CAM-003 | `ZoomPolicy` | **BUILT** — anchored to the zoom at gesture start, not accumulated per frame | `UNIT` **PASS** (23), including an assertion that the compounding alternative drifts | **manual-user check (F7 + Samsung Galaxy S25)** — not ADB-automated (`adb shell input` cannot produce trustworthy multi-touch); physically confirmed by direct two-finger pinch on both devices | GIF |
| "…a slider…" (p2) | FLT-CAM-004 | `ZoomSlider` | **BUILT** — `ZoomSlider`, vertical on the trailing edge, bounded by the reported min/max, writing the one shared `currentZoom` | `WIDGET` **PASS** — bounds, shared value, and the accessible read-out | **PASS (F7)** — the slider and all three presets round-tripped 1x-8x with the readout always matching the requested state | Screenshot |
| "…and rounded buttons (0.5x, 1x, .. available back cameras)" (p2/p3, **truncated**) | FLT-CAM-005, FLT-CAM-016 | `ZoomPresetPolicy` | **BUILT** — presets derived from the reported range; every preset carries its provenance | `UNIT` **PASS** (15) — *no* preset claims an optical identity the platform did not report | **PASS (F7)** — `FQ-01` recorded: HONOR DNP-NX9 reports one back camera, 1x–8x; presets matched the reported range | README limitation note + `ADR-F03` |
| "Tap-to-focus functionality" (p3) | FLT-CAM-008 | `FocusPointMapper`, `CameraCubit` | **BUILT** — both `contain` and `cover` fits, mapped through the displayed image rect, never the widget rect (`ADR-F23`) | `UNIT` **PASS** (19) + `BLOC` (16) | **PASS (F7)** — tap-to-focus landed correctly at centre, both far corners, and at 8x zoom | GIF |
| "…with a visual indicator at the tap point" (p3) | FLT-CAM-009 | `FocusReticle` | **BUILT** — `FocusReticle` at the tap, in widget coordinates, with an appear/hold/dismiss lifecycle keyed on the request sequence | `WIDGET` **PASS** — rendered centre within 2 dp of the tap; still appears under reduced motion | **PASS (F7)** — reticle held mid-tap at the tap point, re-confirmed in the submission screenshot (`docs/assets/flutter/focus-zoom.png`) at 2x zoom | GIF |
| *(entailed by queue durability)* | FLT-CAM-015 | `CaptureStore`, `CaptureIntoBatch` | **BUILT, AND NOW CALLED** — the camera's temporary `XFile` path goes `takePicture()` → `CaptureIntoBatch` → `RecordCapture` → durable file → row | `file_system_capture_store_test` (14) + `record_capture_test` (7) + `capture_into_batch_test` (10) + `camera_cubit_capture_test` (22) **PASS** | **PASS (F7)** — real captures from the physical camera were written durably and appeared in the batch thumbnail/count and later in Pending Uploads | — |
| *(entailed by "available back cameras")* | FLT-CAM-011 | `CameraSelectionPolicy`, `CameraXAdapter` | **BUILT** — front and external filtered out; ordinals re-stamped over back cameras only | `UNIT` **PASS** (16) + `BLOC` | **PASS (F7)** — `FQ-01`: one back camera reported, selector correctly absent | — |
| *(entailed by GR-4; plugin owns no lifecycle)* | FLT-CAM-012 | `CameraCubit.handleLifecycle` | **BUILT** — release on `paused`/`detached`, restore the *selected* camera on `resumed`, `inactive` deliberately ignored | `BLOC` **PASS** (20), including a pre-pause init that must not overwrite the resumed state | **PASS (F7)** — camera released and reacquired cleanly across background and resume | — |
| "Capture multiple batches of images" (p3) | FLT-BAT-001, FLT-BAT-002 | `CaptureIntoBatch`, `BatchCubit` (F4), `UploadQueueDao` | **BUILT END TO END** — the first shutter press opens a draft batch, later presses join it, `BatchCubit` closes it, and a new batch opens on the next press; the camera shows the count and “Finish batch (n)” | `DATA` + `BLOC` + `WIDGET` **PASS** — repeated captures join one batch, and the count on screen is read back from the queue rather than tallied in the widget | **PASS (F7)** — multiple batches captured and enqueued independently on the physical device; re-confirmed at the documentation-reconciliation session (a 3-image draft batch, then a separate 5-image offline batch) | Screenshot |
| "Show a list of 'Pending Uploads.'" (p3) | FLT-BAT-003 | `UploadManagerScreen` | **BUILT** — `UploadManagerScreen`: batch sections, count-based `n of m` progress, six item states, connectivity hint, reassurance line, empty state | `WIDGET` **PASS** (8) + `UNIT` **PASS** (9) over the pure status vocabulary | **PASS (F7)** — confirmed live and again in the submission screenshots (`uploads-offline.png`, `uploads-success.png`) | Screenshot |
| "Implement a background worker (e.g., workmanager)" (p3) | FLT-SYNC-002 | `sync_worker_entrypoint.dart`, `WorkManagerSyncScheduler` | **BUILT** — entry-point dispatcher, isolate-local composition root, **one serial unique chain with `append` for every request** (`ADR-F21`), connected constraint, exponential backoff (15 s initial; Android floor 10 s) | `work_manager_sync_scheduler_test` (17) + `sync_worker_entrypoint_test` (14) + `finish_batch_test` (10) **PASS** — *policy, call sites and result mapping only* | **PASS (F7)** — Android genuinely ran the worker and drained a real offline-built queue with the app backgrounded, no retry press, after clearing the Honor `HN_USER_EXPERIENCE` OEM restriction in device Settings; re-confirmed at the documentation-reconciliation session with a fresh v1.0.0 install | README §2 |
| "…the images must remain in the local queue" (p3) | FLT-SYNC-003 | `QueueProcessor` | **BUILT** — a retryable failure returns the row to `PENDING`, attempt + 1, row and file untouched | `UNIT` + `DATA` (I6) **PASS**; seven consecutive failures discard nothing | **PASS (F7)** — a retryable failure returned the row to `PENDING` on the live device queue; nothing was discarded | GIF |
| "Automatically retry … without user intervention" (p3) | FLT-SYNC-004, FLT-SYNC-014 | `SyncScheduler`, `QueueProcessor`, `FinishBatch`, `ConnectivityDrainTrigger` | **BUILT** for `-004` — including that a request made while a worker is running cannot be discarded (`ADR-F21`); `-014` needs the UI (F5) | `UNIT` **PASS** — fail-then-succeed proven through the processor and again across two worker invocations, no user action in the path | **PASS (F7)** — airplane mode on then off with the app backgrounded and items queued; upload completed untouched | GIF (offline→online) |
| "use mock API Responses for Success and Failed" (p3 Note) | FLT-SYNC-005 | `MockUploadApi` | **BUILT** — five deterministic scenarios behind a real `UploadApi` seam | `UNIT` **PASS** (12); no randomness anywhere | — | README (how to switch) |
| *(entailed by release deliverable)* | FLT-SYNC-015 | `AndroidManifest.xml` | **DONE** | `REVIEW` — declared in `main` | — | `ADR-F11` |
| "public GitHub repository" (p3 D1) | FLT-DEL-001 | repo | **PUBLIC** — [github.com/rktuhinbd/PresenceLens](https://github.com/rktuhinbd/PresenceLens) | — | loads while signed out **PASS** | Repository URL |
| "well-structured README.md" (p3 D2) | FLT-DEL-002 | `README.md` | **DONE** — root README with the five mandated sections, plus dedicated per-app READMEs | — | renders correctly on GitHub | [README.md](../../README.md) |
| "link to the built release APK" (p3 D3) | FLT-DEL-003 | release build | **DONE** — `PresenceLens-Capture-v1.0.0.apk`, 50,528,476 bytes | `flutter build apk --release` **PASS** | downloaded fresh and installed/run on a physical device (F7 and again at the documentation-reconciliation session) | [v1.0.0 release](https://github.com/rktuhinbd/PresenceLens/releases/tag/v1.0.0) |
| "Screenshots … of the running application" (p4 G5) | FLT-DEL-004 | assets | **DONE** — five Flutter states (camera ready, focus + zoom, active batch, offline queue, synced) | — | captured on a physical HONOR DNP-NX9 from the published v1.0.0 APK, each navigated deliberately and confirmed against accessibility semantics before capture, then visually inspected | `docs/assets/flutter/*.png`, rendering in the README |
| "Generative AI Usage … essential prompts" (p4 G3) | FLT-DEL-005 | `AI_USAGE.md` | **DONE** — every gate through submission logged with tool/model/purpose/result/human-verification | — | — | [AI_USAGE.md](../AI_USAGE.md) + README §"Generative AI usage" |

## 2. Quality requirements → the mandatory row each protects

Every QUALITY row exists to protect a MANDATORY one. This column is the
justification for its existence.

| Req ID | Protects | Failure it prevents |
| --- | --- | --- |
| FLT-GEN-006 | FLT-GEN-001/002 | Rules leaking into widgets, making them untestable |
| FLT-GEN-007 | FLT-GEN-002 | Layering that is claimed but not real |
| FLT-CAM-006 | FLT-CAM-003/004/005 | Three zoom controls disagreeing |
| FLT-CAM-007 | FLT-CAM-003 | Zoom driven past what the device supports |
| FLT-CAM-010 | FLT-CAM-009 | An indicator that never resolves, reading as a freeze |
| FLT-CAM-013 | FLT-CAM-002 | Rendering a disposed controller after a fast switch |
| FLT-CAM-014 | FLT-BAT-001 | Double-capture corrupting the batch count |
| FLT-CAM-016 | FLT-CAM-005 | Fabricated optical claims (`ADR-F03`) |
| FLT-CAM-017 | FLT-GEN-004 | Requesting a microphone permission the app never needs |
| FLT-BAT-004 | FLT-BAT-002 | An undefined batch boundary (root `AMB-10`) |
| FLT-BAT-005 | FLT-SYNC-001 | A half-enqueued batch after a crash |
| FLT-BAT-006 | FLT-BAT-001 | An empty batch occupying the queue |
| FLT-SYNC-006 ✅ | FLT-SYNC-003/004 | A permanent failure retried forever, blocking the queue |
| FLT-SYNC-007 | FLT-SYNC-004 | An app timer fighting the OS scheduler |
| **FLT-SYNC-008 ✅** | **FLT-SYNC-003** | **Two isolates uploading one item — `RD-02`.** Verified: two, then eight, independent connections race one row; one winner |
| **FLT-SYNC-009 ✅** | **FLT-SYNC-004** | **A queue permanently stuck after process death — `RD-03`.** Verified: a fresh lease is safe, an expired one is reclaimed once, a contended stale row yields one winner |
| FLT-SYNC-010 | FLT-SYNC-003 | Corrupt state from a repeated completion |
| **FLT-SYNC-011 ✅** | **FLT-SYNC-004** | **`if (wifi) upload()` — fails the low-bandwidth case — `RS-01`.** `QueueProcessor` takes no `ConnectivityPort`, so it cannot make this mistake |
| FLT-SYNC-012 | FLT-SYNC-004 | Stale UI, and a missed chance to retry on resume |
| FLT-SYNC-013 | FLT-BAT-002 | Nondeterministic order across batches |
| FLT-ERR-005 ✅ | FLT-SYNC-003 | A queue row pointing at a file that does not exist |
| FLT-ERR-006 ✅ | FLT-GEN-003 | A partially-applied transaction |
| FLT-ERR-007 ✅ | FLT-SYNC-004 | A queue that can never drain |
| FLT-ERR-008 | FLT-SYNC-006 | A timeout misread as a rejection, discarding an image |
| FLT-UX-004 | FLT-CAM-009 | Reduced motion silently removing required feedback — `RU-03` |
| FLT-UX-005 | FLT-BAT-003 | State legible only to users who perceive colour |
| FLT-UX-007 | FLT-SYNC-003 | The user believing their photos were lost. Copy leads with the data ("Offline · captures are safe"), never the network (`ADR-F14`) |
| FLT-UX-012 | FLT-BAT-003 | The queue becoming unreachable, and an ambiguous close control destroying an open batch (`ADR-F13`) |
| FLT-UX-013 | FLT-CAM-003 | Zoom reachable only by a gesture some users cannot perform |

## 3. Ambiguities → resolution

| Ambiguity | Resolution | Where |
| --- | --- | --- |
| Does "Upload batch" promise a network transfer? | No — it is a local durable act. Relabelled **"Finish batch (n)"** with a completion mark | `ADR-F14`, `UX_SPEC.md` §3.2 |
| Does an X over the viewfinder mean discard, close, cancel or quit? | Unanswerable, so the control is removed. Navigation is one-way outward | `ADR-F13`, `UX_SPEC.md` §3.1 |
| Root `AMB-01` — zoom preset text truncated in the PDF | Device-derived presets, correct under any completion | `ADR-F03`, `FLT-CAM-005` |
| Root `AMB-10` — "batch" never defined | Defined explicitly: opens on first capture after the previous enqueue, closes on enqueue | `FLT-BAT-004` |
| Root `AMB-11` — screenshot shows non-image files | Text wins; the queue holds images | `REQUIREMENTS_SPEC.md` §"not carried forward" |
| Root `AMB-12` — target platforms unstated | Android is the deliverable; iOS configured, never claimed | `RS-08`, `ADR-F11` |
| Root `AMB-15` — "stable connection" undefined | Reachability is unknowable in advance; the attempt is authoritative | `ADR-F05` |
| p3 "ATTEMPT 3/5" implies a cap | No cap; count shown without a denominator. **Human-approved 2026-08-29** | `ADR-F12` |

## 4. Open research → what it gates

| ID | Question | Gates | Blocking? |
| --- | --- | --- | --- |
| `FQ-01` | Real back-camera count, lens types and zoom ranges | Final preset labels | **No** — the policy is correct for any n, and `CameraDiagnostics.report()` now emits the answer as one copyable block |
| `FQ-05` | Whether any shipping Android device reports a non-`unknown` `lensType` | Whether the README's limitation note needs correcting | **No** — the preset policy already upgrades labels if one does |
| `FQ-02` | Real WorkManager latency | README expectation-setting | No |
| `FQ-03` | iOS `BGTaskScheduler` behaviour | iOS claims only | No — none will be made |
| `FQ-04` | `pausePreview()` vs full dispose | `FLT-CAM-012` detail | No — safe path chosen |

## 5. Gate status

**Final (submission, F7 complete, 2026-08-30):**

| Category | Total | DONE | OPTIONAL — NOT DELIVERED | PARTIAL | TODO |
| --- | --- | --- | --- | --- | --- |
| FLT-GEN | 7 | **7** | 0 | 0 | 0 |
| FLT-CAM | 18 | **18** | 0 | 0 | 0 |
| FLT-BAT | 8 | **8** | 0 | 0 | 0 |
| FLT-SYNC | 16 | **15** | **1** | 0 | 0 |
| FLT-ERR | 8 | **8** | 0 | 0 | 0 |
| FLT-UX | 13 | **13** | 0 | 0 | 0 |
| FLT-TEST | 9 | **9** | 0 | 0 | 0 |
| FLT-DEL | 5 | **5** | 0 | 0 | 0 |
| **Total** | **84** | **83** | **1** | **0** | **0** |

The one `OPTIONAL — NOT DELIVERED` row is `FLT-SYNC-016` (BONUS): post-upload
file deletion is implemented and tested but deliberately ships **off** by default
(`ADR-F16`) — not a gap, a disclosed design choice; see
[REQUIREMENTS_SPEC.md](REQUIREMENTS_SPEC.md).

**Historical progression, preserved as provenance:** F1 read 24/9/51, F3 read
32/21/31, F4/F5 read 57/21/6. Every row that was `TODO` at F5 was `FLT-DEL`
(the submission package, closed at F8) or `FLT-TEST-009` (the device checklist,
closed at F7). Every row that was `PARTIAL` at F5 was implemented and
host-verified, waiting only on the physical device that F7 supplied.

### Device QA — final disposition (F7, 2026-08-30, HONOR DNP-NX9 + Samsung Galaxy S25)

Every row below was implemented and host-verified before F7; this table records
what F7 actually confirmed on hardware. Nothing here claims more than was executed.

| Req ID | What a device had to show | F7 result |
| --- | --- | --- |
| FLT-GEN-003 | The queue survives a force-stop and relaunch | **PASS** — force-stop and reboot with items pending |
| FLT-SYNC-001 | Same, with items mid-flight | **PASS** |
| **FLT-SYNC-002** | **Android actually runs the worker, and it drains the queue** | **PASS** — confirmed after clearing the Honor `HN_USER_EXPERIENCE` OEM restriction in device Settings; no code-level fix needed |
| **FLT-SYNC-004** | **Airplane mode → enqueue → restore, app backgrounded, no user action** | **PASS** |
| FLT-SYNC-007 | Observed backoff between real invocations | **Not separately stopwatched** — a supplemental timing measurement beyond this QUALITY row's `REVIEW` evidence; the drain was observed to be WorkManager-governed, consistent with the reviewed policy |
| FLT-CAM-015 | A real camera-plugin temporary file reaching durable storage | **PASS** |
| **FLT-CAM-005/-016** | **What `availableCameras()` actually returns, confirming or overturning `FR-04`** | **CONFIRMED — `FR-04` holds.** The HONOR DNP-NX9 reports one back camera over 1x–8x; `ADR-F03`'s honest-label policy was exercised as designed, no fabricated optical identity |
| FLT-CAM-003 | Pinch tracking real fingers on real hardware, with no drift | **Manual-user check, PASS** — not ADB-automated; confirmed on HONOR and independently on Samsung Galaxy S25 |
| FLT-CAM-008 | A tap visibly changing focus, with the point landing where the finger did | **PASS** — centre, both far corners, and at 8x zoom |
| FLT-CAM-011 | The real back-camera count on the test device | **PASS** — one, recorded as `FQ-01` |
| FLT-CAM-012 | Background/foreground genuinely releasing and restoring the hardware | **PASS** |
| FLT-CAM-018 | Whether exposure-point pairing is supported, and whether it helps | **PASS** — supported and paired without disturbing focus |
| FLT-ERR-001/-002 | Both denial paths, and the Settings round trip (`ADR-F22`) | **PASS** — permission recovery confirmed live |
