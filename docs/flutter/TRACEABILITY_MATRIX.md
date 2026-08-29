# Flutter Task — Traceability Matrix

**What this document is for:** it is the audit trail from a sentence in the
assessment PDF to the evidence that the sentence was satisfied. At submission it
is the document that answers "show me where you did this" in one lookup.

Chain: **assessment statement → requirement ID → component → implementation →
automated test → device evidence → submission evidence.**

`TBC` means "planned, not yet produced". At this gate almost everything is `TBC`
by design — this phase produced requirements, architecture and design, not
feature code. A row is only allowed to leave `TBC` when the artefact actually
exists.

---

## 1. Mandatory assessment statements

Every MANDATORY row traced from its literal source sentence.

| Assessment statement (source) | Req ID | Component | Impl | Auto test | Device | Submission |
| --- | --- | --- | --- | --- | --- | --- |
| "Use a robust solution (BLoC/Cubit)" (p1) | FLT-GEN-001 | `CameraCubit`, `BatchCubit`, `SyncBloc` | TBC | `BLOC` suite | — | README §2 names them (`DOC-04`) |
| "Any Layered Architecture for Flutter (MVVM/MVI)" (p1) | FLT-GEN-002 | `presentation`/`domain`/`data` | TBC | purity test (`FLT-TEST-008`) | — | README §2 + ARCHITECTURE.md |
| "Any local data persistence" (p1) | FLT-GEN-003 | `AppDatabase`, `FileSystemCaptureStore` | TBC | `DATA` suite | kill-and-relaunch | README §2 |
| "Graceful handling of permissions and hardware failures" (p1) | FLT-GEN-004 | `CameraCubit` states | TBC | `BLOC` + `WIDGET` | failure-injection matrix | Screenshots of error states |
| "Task 2 … (Flutter)" (p2) | FLT-GEN-005 | project | **DONE** — builds | `flutter build apk --debug` **PASS** | — | APK link (`FLT-DEL-003`) |
| "Build a camera preview screen `CameraPreviewScreen`" (p2) | FLT-CAM-001 | `CameraPreviewScreen` | TBC | `WIDGET` | preview renders | Screenshot |
| *(same)* — live custom preview | FLT-CAM-002 | `CameraXAdapter` | TBC | — | device check 1 | Screenshot |
| "Implement pinch-to-zoom" (p2) | FLT-CAM-003 | `ZoomPolicy` | TBC | `UNIT` (mapping) | device check 4 | GIF |
| "…a slider…" (p2) | FLT-CAM-004 | `ZoomSlider` | TBC | `WIDGET` | device check 5 | Screenshot |
| "…and rounded buttons (0.5x, 1x, .. available back cameras)" (p2/p3, **truncated**) | FLT-CAM-005, FLT-CAM-016 | `ZoomPresetPolicy` | TBC | `UNIT` | device checks 2, 3, 6 | README limitation note + `ADR-F03` |
| "Tap-to-focus functionality" (p3) | FLT-CAM-008 | `FocusPointMapper` | TBC | `UNIT` | device check 7 | GIF |
| "…with a visual indicator at the tap point" (p3) | FLT-CAM-009 | `FocusReticle` | TBC | `WIDGET` (position) | device check 7 | GIF |
| *(entailed by queue durability)* | FLT-CAM-015 | `CaptureStore` | TBC | `UNIT` + `DATA` | — | — |
| *(entailed by "available back cameras")* | FLT-CAM-011 | `CameraXAdapter` | TBC | `UNIT` | device check 2 | — |
| *(entailed by GR-4; plugin owns no lifecycle)* | FLT-CAM-012 | `CameraPreviewScreen` | TBC | `WIDGET` | device check 11 | — |
| "Capture multiple batches of images" (p3) | FLT-BAT-001, FLT-BAT-002 | `BatchCubit`, `BatchRepository` | TBC | `BLOC` + `DATA` | multi-batch run | Screenshot |
| "Show a list of 'Pending Uploads.'" (p3) | FLT-BAT-003 | `UploadManagerScreen` | TBC | `WIDGET` | visual check | Screenshot |
| "Implement a background worker (e.g., workmanager)" (p3) | FLT-SYNC-002 | `SyncWorker`, `WorkManagerSyncScheduler` | TBC | — (OS-owned) | sync check 2 | README §2 |
| "…the images must remain in the local queue" (p3) | FLT-SYNC-003 | `QueueProcessor` | TBC | `UNIT` + `DATA` (I6) | sync checks 1, 6 | GIF |
| "Automatically retry … without user intervention" (p3) | FLT-SYNC-004, FLT-SYNC-014 | `SyncScheduler` | TBC | `UNIT` | **sync check 2** | GIF (offline→online) |
| "use mock API Responses for Success and Failed" (p3 Note) | FLT-SYNC-005 | `MockUploadApi` | TBC | `UNIT` | — | README (how to switch) |
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
| FLT-SYNC-006 | FLT-SYNC-003/004 | A permanent failure retried forever, blocking the queue |
| FLT-SYNC-007 | FLT-SYNC-004 | An app timer fighting the OS scheduler |
| **FLT-SYNC-008** | **FLT-SYNC-003** | **Two isolates uploading one item — `RD-02`** |
| **FLT-SYNC-009** | **FLT-SYNC-004** | **A queue permanently stuck after process death — `RD-03`** |
| FLT-SYNC-010 | FLT-SYNC-003 | Corrupt state from a repeated completion |
| **FLT-SYNC-011** | **FLT-SYNC-004** | **`if (wifi) upload()` — fails the low-bandwidth case — `RS-01`** |
| FLT-SYNC-012 | FLT-SYNC-004 | Stale UI, and a missed chance to retry on resume |
| FLT-SYNC-013 | FLT-BAT-002 | Nondeterministic order across batches |
| FLT-ERR-005 | FLT-SYNC-003 | A queue row pointing at a file that does not exist |
| FLT-ERR-006 | FLT-GEN-003 | A partially-applied transaction |
| FLT-ERR-007 | FLT-SYNC-004 | A queue that can never drain |
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
| `FQ-01` | Real back-camera count and zoom ranges | Final preset labels | **No** — policy is correct for any n |
| `FQ-02` | Real WorkManager latency | README expectation-setting | No |
| `FQ-03` | iOS `BGTaskScheduler` behaviour | iOS claims only | No — none will be made |
| `FQ-04` | `pausePreview()` vs full dispose | `FLT-CAM-012` detail | No — safe path chosen |

## 5. Gate status

| Category | Total | DONE | TODO |
| --- | --- | --- | --- |
| FLT-GEN | 7 | 0 | 7 |
| FLT-CAM | 18 | 0 | 18 |
| FLT-BAT | 8 | 0 | 8 |
| FLT-SYNC | 16 | 1 (`FLT-SYNC-015`) | 15 |
| FLT-ERR | 8 | 0 | 8 |
| FLT-UX | 13 | 0 | 13 |
| FLT-TEST | 9 | 0 | 9 |
| FLT-DEL | 5 | 0 | 5 |
| **Total** | **84** | **1** | **83** |

`FLT-GEN-005` (the app is a Flutter app that builds) is evidenced by this gate's
`flutter build apk --debug` PASS but is held at `TODO` until it builds *with the
feature implementation*, since a placeholder shell building is not evidence for the
task.
