# Flutter Task — Traceability Matrix

**What this document is for:** it is the audit trail from a sentence in the
assessment PDF to the evidence that the sentence was satisfied. At submission it
is the document that answers "show me where you did this" in one lookup.

Chain: **assessment statement → requirement ID → component → implementation →
automated test → device evidence → submission evidence.**

`TBC` means "planned, not yet produced". A row is only allowed to leave `TBC`
when the artefact actually exists.

**Updated at gate F3 (2026-08-30).** The camera **engine** is now built and
evidenced; the two screens are not started. The rule about device evidence is
unchanged and now applies to the camera as well: **445 host tests say nothing about
whether a real lens focused**, so every row whose evidence is a device run stays
`TBC` however complete the code is.

---

## 1. Mandatory assessment statements

Every MANDATORY row traced from its literal source sentence.

| Assessment statement (source) | Req ID | Component | Impl | Auto test | Device | Submission |
| --- | --- | --- | --- | --- | --- | --- |
| "Use a robust solution (BLoC/Cubit)" (p1) | FLT-GEN-001 | `CameraCubit`, `BatchCubit`, `SyncBloc` | **CameraCubit BUILT** — sealed state, generation guard, capture guard, zoom pump; `BatchCubit`/`SyncBloc` are F4/F5 | `BLOC` **PASS** (109) | — | README §2 names them (`DOC-04`) |
| "Any Layered Architecture for Flutter (MVVM/MVI)" (p1) | FLT-GEN-002 | `presentation`/`domain`/`data` | **BUILT** — `domain` (entities, policies, ports, one use case), `data` (database, storage, api, sync, identity, composition) | `domain_purity_test` **PASS** (5) | — | README §2 + ARCHITECTURE.md |
| "Any local data persistence" (p1) | FLT-GEN-003 | `AppDatabase`, `FileSystemCaptureStore` | **BUILT** — schema v1, two tables, two indices, FK cascade, migration hook | `DATA` suite **PASS** (58) | kill-and-relaunch `TBC` | README §2 |
| "Graceful handling of permissions and hardware failures" (p1) | FLT-GEN-004 | `CameraCubit` states | **BUILT** — 12 classified error kinds; enumeration throw, no camera, no back camera, refusal, restriction, init failure, and capture/focus/zoom failures each reach their own state | `BLOC` **PASS**; `WIDGET` needs the F5 screen | failure-injection matrix `TBC` | Screenshots of error states |
| "Task 2 … (Flutter)" (p2) | FLT-GEN-005 | project | **DONE** — builds | `flutter build apk --debug` **PASS** | — | APK link (`FLT-DEL-003`) |
| "Build a camera preview screen `CameraPreviewScreen`" (p2) | FLT-CAM-001 | `CameraPreviewScreen` | **TBC — gate F5.** The engine beneath it is complete; no screen exists and none is claimed | `WIDGET` | preview renders | Screenshot |
| *(same)* — live custom preview | FLT-CAM-002 | `CameraXAdapter`, `buildCameraPreview` | **ADAPTER BUILT** — `enableAudio: false`, capabilities read back from the controller, preview seam is one getter (`ADR-F23`) | import-confinement test **PASS** | device check 1 `TBC` | Screenshot |
| "Implement pinch-to-zoom" (p2) | FLT-CAM-003 | `ZoomPolicy` | **BUILT** — anchored to the zoom at gesture start, not accumulated per frame | `UNIT` **PASS** (23), including an assertion that the compounding alternative drifts | device check 6 `TBC` | GIF |
| "…a slider…" (p2) | FLT-CAM-004 | `ZoomSlider` | **TBC — gate F5.** The single `currentZoom` it will write to exists and is proven shared | `WIDGET` | device check 7 | Screenshot |
| "…and rounded buttons (0.5x, 1x, .. available back cameras)" (p2/p3, **truncated**) | FLT-CAM-005, FLT-CAM-016 | `ZoomPresetPolicy` | **BUILT** — presets derived from the reported range; every preset carries its provenance | `UNIT` **PASS** (15) — *no* preset claims an optical identity the platform did not report | device checks 2–4, 8 `TBC` | README limitation note + `ADR-F03` |
| "Tap-to-focus functionality" (p3) | FLT-CAM-008 | `FocusPointMapper`, `CameraCubit` | **BUILT** — both `contain` and `cover` fits, mapped through the displayed image rect, never the widget rect (`ADR-F23`) | `UNIT` **PASS** (19) + `BLOC` (16) | device checks 9–10 `TBC` | GIF |
| "…with a visual indicator at the tap point" (p3) | FLT-CAM-009 | `FocusReticle` | **TBC — gate F5.** The engine publishes the tap point, a sequence number so a repeat tap is distinguishable, and the outcome; it owns no animation | `WIDGET` (position) | device check 9 | GIF |
| *(entailed by queue durability)* | FLT-CAM-015 | `CaptureStore`, `CaptureIntoBatch` | **BUILT, AND NOW CALLED** — the camera's temporary `XFile` path goes `takePicture()` → `CaptureIntoBatch` → `RecordCapture` → durable file → row | `file_system_capture_store_test` (14) + `record_capture_test` (7) + `capture_into_batch_test` (10) + `camera_cubit_capture_test` (22) **PASS** | device check 12 — a *real* plugin `XFile` — `TBC` | — |
| *(entailed by "available back cameras")* | FLT-CAM-011 | `CameraSelectionPolicy`, `CameraXAdapter` | **BUILT** — front and external filtered out; ordinals re-stamped over back cameras only | `UNIT` **PASS** (16) + `BLOC` | device check 3 `TBC` | — |
| *(entailed by GR-4; plugin owns no lifecycle)* | FLT-CAM-012 | `CameraCubit.handleLifecycle` | **BUILT** — release on `paused`/`detached`, restore the *selected* camera on `resumed`, `inactive` deliberately ignored | `BLOC` **PASS** (20), including a pre-pause init that must not overwrite the resumed state | device check 14 `TBC` | — |
| "Capture multiple batches of images" (p3) | FLT-BAT-001, FLT-BAT-002 | `CaptureIntoBatch`, `BatchCubit` (F4), `UploadQueueDao` | **CAPTURE PATH BUILT** — the first shutter press opens a draft batch, later presses join it, and a new batch opens once the previous is finished; the Cubit and its UI are F4 | `DATA` + `BLOC` **PASS** — repeated captures join one batch, counts read back from the database | multi-batch run `TBC` | Screenshot |
| "Show a list of 'Pending Uploads.'" (p3) | FLT-BAT-003 | `UploadManagerScreen` | TBC | `WIDGET` | visual check | Screenshot |
| "Implement a background worker (e.g., workmanager)" (p3) | FLT-SYNC-002 | `sync_worker_entrypoint.dart`, `WorkManagerSyncScheduler` | **BUILT** — entry-point dispatcher, isolate-local composition root, **one serial unique chain with `append` for every request** (`ADR-F21`), connected constraint, exponential backoff (15 s initial; Android floor 10 s) | `work_manager_sync_scheduler_test` (17) + `sync_worker_entrypoint_test` (14) + `finish_batch_test` (10) **PASS** — *policy, call sites and result mapping only* | **sync check 2 `TBC` — whether Android runs it is not claimed** | README §2 |
| "…the images must remain in the local queue" (p3) | FLT-SYNC-003 | `QueueProcessor` | **BUILT** — a retryable failure returns the row to `PENDING`, attempt + 1, row and file untouched | `UNIT` + `DATA` (I6) **PASS**; seven consecutive failures discard nothing | sync checks 1, 6 `TBC` | GIF |
| "Automatically retry … without user intervention" (p3) | FLT-SYNC-004, FLT-SYNC-014 | `SyncScheduler`, `QueueProcessor`, `FinishBatch`, `ConnectivityDrainTrigger` | **BUILT** for `-004` — including that a request made while a worker is running cannot be discarded (`ADR-F21`); `-014` needs the UI (F5) | `UNIT` **PASS** — fail-then-succeed proven through the processor and again across two worker invocations, no user action in the path | **sync check 2 `TBC`** | GIF (offline→online) |
| "use mock API Responses for Success and Failed" (p3 Note) | FLT-SYNC-005 | `MockUploadApi` | **BUILT** — five deterministic scenarios behind a real `UploadApi` seam | `UNIT` **PASS** (12); no randomness anywhere | — | README (how to switch) |
| *(entailed by release deliverable)* | FLT-SYNC-015 | `AndroidManifest.xml` | **DONE** | `REVIEW` — declared in `main` | — | `ADR-F11` |
| "public GitHub repository" (p3 D1) | FLT-DEL-001 | repo | private for now | — | — | Human publishes |
| "well-structured README.md" (p3 D2) | FLT-DEL-002 | `README.md` | TBC | — | — | README |
| "link to the built release APK" (p3 D3) | FLT-DEL-003 | release build | TBC | `flutter build apk --release` | install check | Shared link |
| "Screenshots … of the running application" (p4 G5) | FLT-DEL-004 | assets | TBC | — | capture on device | README §5 |
| "Generative AI Usage … essential prompts" (p4 G3) | FLT-DEL-005 | `AI_USAGE.md` | in progress | — | — | README §3 |

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

After gate **F3** (2026-08-30):

| Category | Total | DONE | PARTIAL | TODO |
| --- | --- | --- | --- | --- |
| FLT-GEN | 7 | 2 | 5 | 0 |
| FLT-CAM | 18 | 6 | 7 | 5 |
| FLT-BAT | 8 | 3 | 2 | 3 |
| FLT-SYNC | 16 | 9 | 5 | 2 |
| FLT-ERR | 8 | 6 | 1 | 1 |
| FLT-UX | 13 | 0 | 0 | 13 |
| FLT-TEST | 9 | 6 | 1 | 2 |
| FLT-DEL | 5 | 0 | 0 | 5 |
| **Total** | **84** | **32** | **21** | **31** |

At F1 this table read 24 / 9 / 51. The eight rows that moved to `DONE` are
`FLT-CAM-006`, `-007`, `-013`, `-014`, `-016`, `-017`, `FLT-ERR-003` and `-004` —
every one a rule the engine settles by itself. **The thirteen `FLT-UX` rows and
`FLT-CAM-001`/`-002`/`-004`/`-009`/`-010` did not move**, because an engine API is
not a screen and this gate built no UI.

`FLT-GEN-005` (the app is a Flutter app that builds) is now `PARTIAL`: the debug
APK builds with the whole durable queue and sync engine compiled in, which is real
evidence, but the row is held short of `DONE` until the camera task itself builds
at F3.

### Still pending device QA

These are implemented and host-verified, and their remaining evidence is hardware
only. Nothing in this repository claims any of them has been observed on a device.

| Req ID | What a device must show |
| --- | --- |
| FLT-GEN-003 | The queue survives a force-stop and relaunch |
| FLT-SYNC-001 | Same, with items mid-flight |
| **FLT-SYNC-002** | **Android actually runs the worker, and it drains the queue** |
| **FLT-SYNC-004** | **Airplane mode → enqueue → restore, app backgrounded, no user action** |
| FLT-SYNC-007 | Observed backoff between real invocations |
| FLT-CAM-015 | A real camera-plugin temporary file reaching durable storage |
| **FLT-CAM-005/-016** | **What `availableCameras()` actually returns — the check that confirms or overturns `FR-04`, and with it the honest-label policy (`ADR-F03`)** |
| FLT-CAM-003 | Pinch tracking real fingers on real hardware, with no drift |
| FLT-CAM-008 | A tap visibly changing focus, with the point landing where the finger did |
| FLT-CAM-011 | The real back-camera count on the test device |
| FLT-CAM-012 | Background/foreground genuinely releasing and restoring the hardware |
| FLT-CAM-018 | Whether exposure-point pairing is supported, and whether it helps |
| FLT-ERR-001/-002 | Both denial paths, and the Settings round trip (`ADR-F22`) |
