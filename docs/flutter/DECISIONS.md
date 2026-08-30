# Flutter Task — Architecture Decision Records

**What this document is for:** it records the choices that a reviewer is likely to
question, with the reasoning and the rejected alternatives, so the answer in an
interview is a decision rather than a rationalisation.

Flutter-scoped ADRs are numbered `ADR-F0xx` to keep them distinct from the
repository-wide records in [../DECISIONS.md](../DECISIONS.md) (ADR-001 … ADR-017),
which remain in force where they apply.

Status vocabulary: `PROPOSED` / `ACCEPTED` / `SUPERSEDED`.

---

## ADR-F01 — Pragmatic layered architecture, not Clean Architecture

**Status:** ACCEPTED · **Requirements:** FLT-GEN-002, FLT-GEN-006, FLT-GEN-007

**Context.** The assessment requires "any Layered Architecture for Flutter
(MVVM/MVI)". Clean Architecture is the fashionable answer and would look
impressive in a directory listing.

**Decision.** Three layers — `presentation`, `domain`, `data` — with unidirectional
data flow and dependencies pointing at interfaces declared in `domain`. Use cases
appear **only** where they orchestrate more than one port. This is not called
Clean Architecture, because it is not.

**Reasoning.** A full Clean ring at this scale means one use-case class per
repository method, each forwarding a single call. That is cost with no
corresponding benefit, and a reviewer who knows the pattern recognises the
padding. The property that actually matters — business rules testable without
Flutter — is delivered by the pure policies in `domain/policies` and enforced by an
automated purity test.

**Rejected.** Strict Clean Architecture (ceremony without benefit at this size);
a single-layer app (untestable rules, fails FLT-GEN-002).

**Consistency.** Mirrors the judgement already made on the Android side in
[root ADR-017](../DECISIONS.md#adr-017).

---

## ADR-F02 — Image bytes on the filesystem, metadata in SQLite

**Status:** ACCEPTED · **Requirements:** FLT-GEN-003, FLT-SYNC-001, FLT-CAM-015

**Context.** Queued images must survive process death.

**Decision.** JPEG bytes go to an app-owned directory
(`<app documents>/captures/<batchId>/<imageId>.jpg`); SQLite holds the metadata
and the path. The file is written **before** the row exists.

**Reasoning.** Blobs would inflate the database, make every queue read expensive,
and collide with sqflite's exclusive-transaction model. The write ordering is the
important half: a crash between the two leaves an orphan *file* (invisible,
bounded, reclaimable) rather than a *row pointing at nothing* (a queue item that
can never succeed).

**Rejected.** Blobs in SQLite; leaving captures in the plugin's temporary
directory — the OS may clear it at any time, which is the single most likely way
to lose a queued image.

**Confirms** [root ADR-005](../DECISIONS.md#adr-005).

---

## ADR-F03 — Zoom presets are derived from device-reported capability, never from fabricated optical labels

**Status:** ACCEPTED · **Requirements:** FLT-CAM-005, FLT-CAM-016 · **Closes:** root `ER-05`, informs root `AMB-01`

**Context.** The assessment asks for "rounded buttons (0.5x, 1x, .. available back
cameras)" — and the sentence is **truncated in the source PDF**, so the intended
set is unknowable (root `AMB-01`).

**Evidence.** Verified in the resolved package source this session
(`RESEARCH.md` `FR-04`): `CameraDescription.lensType` exists, but
`camera_android_camerax` 0.7.4+7 **never populates it** — the identifier does not
appear anywhere in the package. Every Android camera reports
`CameraLensType.unknown`, named by its raw Camera2 ID. `camera_avfoundation`
(iOS) does populate it. Android is the only mandated platform (root `AMB-12`).

**Decision.** `ZoomPresetPolicy` derives presets from the active camera's reported
`[min, max]` zoom range: `1.0x` always; a sub-1 preset **only if `min < 1.0`**,
labelled with the actual minimum; higher stops from `{2, 5, 10}` while within
range. Multiple back cameras are offered when they exist, labelled neutrally.
Where `lensType` *is* available, labels are upgraded to true optical names.

**Reasoning.** Printing "0.5x" beside a camera the platform cannot identify is
inventing a hardware claim. A device-derived set is correct under every plausible
completion of the truncated sentence, and it degrades honestly on a single-camera
device.

**Rejected.** Hard-coding `0.5x / 1x / 2x` (lies on most hardware, and would be
caught); dropping presets entirely (fails a mandatory requirement); parsing
Camera2 IDs to guess lens identity (undocumented, OEM-specific, fragile).

**Consequence.** The limitation is stated in the README with its evidence. This is
a *feature* of the submission: it demonstrates verification over assumption.

---

## ADR-F04 — Concurrency is enforced in SQLite, not in Dart

**Status:** ACCEPTED · **Requirements:** FLT-SYNC-008, FLT-SYNC-009, FLT-SYNC-010

**Context.** The WorkManager callback runs in a **separate Flutter isolate** with
its own plugin channels, and therefore its own database connection. sqflite's
documented synchronisation — *"All calls are currently synchronized and
transactions block are exclusive"* — is per-instance, and its cross-isolate support
is described as *"initial"* (`RESEARCH.md` `FR-08`).

**Decision.** Mutual exclusion between the UI isolate and the worker isolate is
enforced by an **atomic conditional `UPDATE`** that claims a row, with the
precondition re-tested inside the same statement. A claim succeeds only if it
affected exactly one row. Stale claims are reclaimed by folding a lease expiry
(10 minutes) into the same `WHERE` clause.

**Reasoning.** No Dart-level lock, mutex or singleton can span isolates — they
share no memory. Any in-process solution would appear to work in tests and fail in
production, which is the worst possible failure mode. Delegating to SQLite's
statement atomicity is the only mechanism both isolates genuinely share.

Folding recovery into the claim (rather than a startup sweep) means there is no
separate code path that can be forgotten, and recovery works identically wherever
a drain runs.

**Rejected.** A Dart `Mutex` (does not span isolates); an `IsolateNameServer`
port to funnel all access through one isolate (adds a live-liveness dependency
between isolates and fails when the UI isolate is dead — which is exactly when the
worker runs); a startup-only sweep (does not help a *second* process death, and is
a forgettable path).

---

## ADR-F05 — Connectivity is advisory; the upload outcome is authoritative

**Status:** ACCEPTED · **Requirements:** FLT-SYNC-004, FLT-SYNC-011 · **Closes:** root `AMB-15`, root `ER-07`

**Context.** The assessment says to retry "once a stable connection is detected".
"Stable" is undefined, and `connectivity_plus` states plainly that connection type
*"does not guarantee that there is an Internet access"* (`FR-05`).

**Decision.** Connectivity is used for exactly three things: a WorkManager
`NetworkType.connected` constraint, an opportunistic reschedule on a
none→connected transition, and UX copy worded as a hint. **Whether an upload
succeeded is decided only by attempting it.**

**Reasoning.** `if (wifi) upload()` fails precisely on the case the assessment
names — low bandwidth, where the link is present and the transfer still fails.
Treating link state as truth would defeat the requirement it appears to serve.

**Rejected.** Gating uploads on connectivity type (wrong, as above); a reachability
ping before each upload (a second network round-trip that proves only that *the
ping* worked, and doubles the failure surface).

---

## ADR-F06 — Deterministic mock API behind a real client seam

**Status:** ACCEPTED · **Requirements:** FLT-SYNC-005, GEN-07

**Context.** No API is provided; the PDF permits commented-out calls or hard-coded
mock responses.

**Decision.** A real `UploadApi` interface with `MockUploadApi` driven by an
explicit, selectable scenario. Default `offlineAware`: fails as retryable when
there is no link, succeeds otherwise. No HTTP client dependency is added.

**Reasoning.** Commenting out code, as the PDF permits, would leave no
demonstrable sync engine at all — and the sync engine is the substance of this
task. A deterministic mock makes every path reproducible on demand; a *random*
mock makes the most important behaviour unreproducible. `offlineAware` makes the
mandated airplane-mode demo work naturally on a device with no code change.

Note the direction of the dependency: connectivity here stands in for *the
server's* reachability inside a fake transport. It is not the app deciding whether
to try — that would violate `ADR-F05`.

**Rejected.** Random success/failure (undemonstrable); commenting out the API
(no engine to show); a real HTTP client against a public echo service (an external
dependency that could fail during review, and a fabricated integration).

**Confirms** [root ADR-008](../DECISIONS.md#adr-008).

---

## ADR-F07 — The camera route uses a fixed dark palette, independent of system theme

**Status:** ACCEPTED · **Requirements:** FLT-UX-001, FLT-UX-008, RU-02

**Context.** The rest of the app follows the Material 3 light/dark scheme derived
from the seed.

**Decision.** `CameraPreviewScreen` uses a fixed dark control palette that does
**not** follow the system setting. Every other surface is fully theme-responsive.

**Reasoning.** The content behind camera chrome is a live image, not a themed
surface. A light-mode camera UI is unreadable outdoors and washes out the preview.
Every serious camera application makes this same choice. Applying default Material
container colours over a viewfinder would destroy the thing the user is trying to
look at.

**Rejected.** Full theme responsiveness on the camera screen (unreadable in light
mode over a bright scene); a dark app throughout (wrong for the Upload Manager,
which is ordinary content and should respect the user's preference).

---

## ADR-F08 — Cubit for camera and batch, Bloc for sync

**Status:** ACCEPTED · **Requirements:** FLT-GEN-001, FLT-TEST-005

**Context.** The assessment mandates "BLoC/Cubit" without saying which, where.

**Decision.** `CameraCubit` and `BatchCubit` are Cubits. `SyncBloc` is a Bloc.

**Reasoning.** Camera and batch interactions are direct imperative commands —
initialise, zoom, focus, capture, append, enqueue. There is no event stream worth
replaying and no cross-event transformation; a Bloc there would add an event class
per method call for nothing.

`SyncBloc` genuinely earns the event model: it fans **three independent
asynchronous sources** into one state — queue changes, connectivity transitions,
and app-lifecycle resume — and must behave differently depending on which arrived.
A sealed event type makes that explicit and independently testable, and Bloc's
transformers debounce connectivity chatter without a hand-rolled timer.

**Reasoning for the mix itself:** applying one uniformly would show the library
was used; applying each where it fits shows the distinction is understood.

**Rejected.** All Bloc (ceremony on the camera path); all Cubit (loses the
event-source distinction exactly where it carries weight).

---

## ADR-F09 — Bonus features: three accepted, five rejected

**Status:** ACCEPTED · **Requirements:** EXP-03, RR-03

**Context.** Extra features can demonstrate judgement or expose it. The assessment
explicitly welcomes better approaches (p4 Expectations 3).

**Decision — accepted (3):**

| Feature | Requirement | Why |
| --- | --- | --- |
| Last-capture thumbnail with count badge | `FLT-BAT-008` | Answers "did that photo register?" without a second screen. Appears in the p3 reference. Cheap. |
| Post-upload file deletion, row retained as history | `FLT-SYNC-016` | Shows the disk-lifecycle question was considered. One pure policy, one call site. |
| Exposure point set with focus | `FLT-CAM-018` | On most hardware, tapping a subject that then stays dark is worse than no focus at all. One extra plugin call. |

**Decision — rejected (5):**

| Feature | Why not |
| --- | --- |
| **"PAUSE ALL"** (shown in the p3 reference) | In direct tension with `FLT-SYNC-004`'s "without user intervention", and creates a state where the queue is stopped and the user may not remember why. Rejected on requirement grounds, not effort. |
| Aggregate byte-level progress bar | A single mock upload has no meaningful byte progress. A fabricated percentage is dishonest; count-based progress is delivered instead. |
| Demo-mode scenario switcher in the UI | The scenario is already selectable for review; a UI toggle adds a surface that ships to users for a reviewer's benefit. |
| Camera capability inspection sheet | A debug dashboard. Directly contradicts the camera-first UI principle (`FLT-UX-001`). |
| Flash and settings controls | Advisory decoration only; no requirement. Reconsidered only if all mandatory work is complete and verified. |

**Reasoning.** Each accepted item is small, independently removable, and answers a
question a reviewer would actually ask. Each rejected item either fights a
mandatory requirement, adds noise to the camera UI, or fabricates information.

**Rule.** No bonus is implemented until every MANDATORY row it could affect is
`DONE`. The execution plan sequences them last.

---

## ADR-F10 — Dart package renamed to `presence_lens_capture`

**Status:** ACCEPTED · **Requirements:** GEN-05, FLT-DEL-002

**Context.** The scaffolded project used `flutter_camera_sync` for the Dart
package, the Android namespace/applicationId, and both display names — Flutter's
defaults, not decisions.

**Decision.** Dart package → `presence_lens_capture`. Android namespace and
`applicationId` → `io.github.rktuhinbd.presencelens.capture`. Display name →
"PresenceLens Capture" on both platforms. **The directory stays
`flutter_camera_sync/`.**

**Reasoning.** The product is PresenceLens; the identifier should say so, matching
the native app's `io.github.rktuhinbd.presencelens.attendance`. The rename is
almost free now (two Dart files) and expensive later. The directory name is left
alone because it is referenced in existing project documentation and carries no
runtime meaning.

**Note.** The instruction for this phase described the Dart package as *remaining*
`presence_lens_capture`; it was in fact still `flutter_camera_sync`. Treated as
identity normalisation, which this phase explicitly permits, and recorded here so
the discrepancy is visible rather than silently resolved.

---

## ADR-F11 — `INTERNET` declared in the main Android manifest

**Status:** ACCEPTED · **Requirements:** FLT-SYNC-015

**Context.** Flutter's generated project declares `INTERNET` only in the `debug`
and `profile` source sets, where the tool needs it for hot reload.

**Decision.** Declare `INTERNET` (and `ACCESS_NETWORK_STATE`) in the `main`
manifest.

**Reasoning.** Without it, **the release APK — the actual deliverable (`SUB-03`) —
would have no network permission**, and every upload would fail on a permission
error rather than on a network condition. The failure would be invisible in debug
and total in release. This is a real defect found while reading the generated
project, not a precaution.

`CAMERA` and the two `uses-feature` entries are declared explicitly for
readability; `camera` merges its own. Hardware features are marked
`required="false"` so the app still installs and degrades gracefully
(`FLT-ERR-003`).

---

## ADR-F12 — No attempt ceiling that discards an image

**Status:** ACCEPTED — **approved at human visual review, 2026-08-29.** ·
**Requirements:** FLT-SYNC-003, FLT-UX-009

**Context.** The p3 reference shows "ATTEMPT 3/5", implying a maximum of five.

**Decision.** `attempt_count` is recorded and displayed, but is **not** a give-up
threshold. Only a `permanent` classification removes an item from the work set.
The UI shows the attempt count without a denominator.

**Reasoning.** `FLT-SYNC-003` requires images to *remain in the local queue* until
uploaded. Discarding an image after five attempts would violate the central
requirement in order to match a decorative element of an advisory screenshot. A
device offline for a week must still have its photos.

Showing "3/5" while no cap exists would be a lie in the UI; showing "attempt 3"
is true.

**Approved.** The human ruled on this explicitly at the visual review: no fake
denominator, because retry is not capped at five and abandoning images would
violate the resilient-queue requirement. The UI shows "Retrying · attempt 3" or
equivalent, and never a fraction.

**Rejected.** A hard cap into `FAILED_PERMANENT` (loses user data, violates the
requirement); a cap that pauses rather than drops (re-introduces the `PAUSE ALL`
problem — a stopped queue with no obvious cause).

---

## ADR-F13 — The camera route has no close control

**Status:** ACCEPTED — decided at the visual polish pass, 2026-08-29 ·
**Requirements:** FLT-UX-001, FLT-UX-012, FLT-BAT-004

**Context.** The first prototype placed an X in the camera's top-left corner,
following the convention of a modal camera sheet.

**Decision.** Remove it. `CameraPreviewScreen` has no X, no back arrow and no
exit affordance. Navigation is one-way outward to the Upload Manager, which
carries the only back control in the app.

**Reasoning.** An X over a live viewfinder, sitting beside a batch of captures the
user has not yet finished, is genuinely ambiguous: *discard this batch*, *close
the camera*, *cancel this capture*, or *quit the app*. Three of those four
readings are destructive and the control cannot distinguish them. Putting a
destructive-looking affordance next to unsaved work is a defect.

It is also unnecessary. The camera is the launch destination and the primary
surface — there is nothing behind it — and an app-authored "exit" is not
something an Android application should offer.

**Consequence — an invariant this makes explicit.** Leaving the camera by any
route must never discard the open batch. Backgrounding, navigating to Pending
Uploads, process death and permission revocation all preserve it, because a
capture is durable on disk before it is counted (`FLT-CAM-015`) and the batch is
rebuilt from SQLite as `DRAFT`. There is deliberately no gesture or control that
destroys a batch as a side effect; an explicit, separately confirmed discard is
out of scope for this submission. Documented in `UX_SPEC.md` §3.1.

**Rejected.** Keeping the X with a confirmation dialog (a dialog to protect
against a control that did not need to exist); relabelling it "Done" (that is the
batch action's job, and a top-left Done next to a bottom Finish is two ways to
say one thing).

---

## ADR-F14 — "Finish batch", not "Upload batch"

**Status:** ACCEPTED — decided at the visual polish pass, 2026-08-29 ·
**Requirements:** FLT-BAT-005, FLT-SYNC-004, FLT-SYNC-011, FLT-UX-007

**Context.** The primary batch control was originally labelled "Upload batch (n)"
with a send icon.

**Decision.** It reads **"Finish batch (n)"** with a completion mark. Status copy
follows the same rule: "Offline · captures are safe" and "Connected · uploading
automatically".

**Reasoning.** Pressing the control is a **local, durable act** — close the batch,
move its images to `PENDING` in one transaction, ask the OS to schedule a drain.
No network operation happens, and none is guaranteed to happen soon
(`SYNC_ENGINE.md` §9).

"Upload batch" made two false promises. It implied the press performs a transfer,
and it made the offline case self-contradictory: the prototype showed **Offline**
in the top bar directly above **Upload batch**, which invites the user to think
the button is broken. Finishing a batch while offline is not an edge case — it is
the primary scenario the resilient queue exists for, and the label should read as
unremarkable there.

This also protects `FLT-SYNC-011`. A label promising a transfer is the interface
equivalent of `if (wifi) upload()`: it tells the user the app knows something
about the network that it does not.

**Consequence for status copy.** The app states what is true of the *data* before
anything about the network. "Offline · captures are safe" leads with the answer to
the user's actual question. "Connected · uploading automatically" replaces
"retrying automatically", because retry follows a failure and nothing has failed
on the happy path. Never *immediate*, never *continuous* — the OS owns the
schedule. Full table in `UX_SPEC.md` §4.1.

**Rejected.** "Queue batch" (accurate but jargon); "Done" (too generic beside a
count); keeping "Upload" and hiding the offline chip (hiding true information to
protect a wrong label).

---

## ADR-F15 — Identifiers are generated in-app, not by a `uuid` dependency

**Status:** ACCEPTED — F1 · **Requirements:** FLT-SYNC-010, FLT-CAM-015

**Context.** Every batch and image needs an identifier. Image ids are load-bearing
three times over: primary key, on-disk file name, and the upload's idempotency key
(`DATA_MODEL.md` §2). They are created independently in two isolates with no
coordination between them, so they must be unique without a sequence.

**Decision.** An `IdGenerator` port in `domain`, implemented by `UuidV4Generator`
in `data`: RFC 4122 version 4 over `Random.secure()`, with the version nibble and
variant bits set explicitly. No package is added.

**Reasoning.** The port has to exist regardless — tests need deterministic ids to
assert file paths and idempotency keys, and that means injection, not a static
call. Given the port, the implementation behind it is about fifteen lines of
`dart:math`, and the project's standing rule is that a dependency needs a concrete
need. "Generate 122 random bits and set six of them" is not one.

The risk of a hand-written UUID is getting the version and variant bits wrong, so
the format is asserted by a test over 200 samples rather than assumed, along with
collision-freedom over 5 000 and file-name safety. If a future requirement needs
UUIDv7 or a namespaced identifier, the port is already the seam to change behind.

**Rejected.** `package:uuid` (a dependency for fifteen lines, when the injection
seam was needed anyway); an autoincrement integer primary key (cannot be generated
in two isolates without coordination, and is not usable as an idempotency key);
`DateTime.now().microsecondsSinceEpoch` (collides under a fast shutter, and leaks
capture time into a filename).

---

## ADR-F16 — Post-upload file deletion is implemented but disabled by default

**Status:** ACCEPTED — F1 · **Requirements:** FLT-SYNC-016 (BONUS), FLT-BAT-003

**Context.** `FLT-SYNC-016` is a bonus row: delete a confirmed-uploaded image's
file, keep its row as history (`ADR-F09`). Implementing it in F1 surfaced a
conflict the planning phase had not: the approved Upload Manager renders a
thumbnail on **every** queue row, synced ones included (`UX_SPEC.md` §3.3). If the
file is deleted the moment an upload is confirmed, those rows have nothing to show.

**Decision.** `RetentionPolicy` is implemented, the processor honours it, and the
ordering it depends on is tested — but `deleteAfterUpload` defaults to **`false`**.
The bonus row stays `PARTIAL`: the mechanism exists and is verified; the app does
not switch it on.

**Reasoning.** The ordering rule is the part with real engineering content, and it
is delivered and tested: `UPLOADED` is persisted **first**, deletion is attempted
only afterwards, and a failed deletion leaves the item `UPLOADED` rather than
returning it to the queue — housekeeping is never confused with delivery. Turning
deletion on would silently degrade an approved screen, and the visual direction is
frozen; changing it needs an evidenced problem and its own decision, not a bonus
feature's side effect.

Leaving the default off also keeps the bonus honestly subordinate to mandatory
work, which is what `ADR-F09` asked for. F6 either enables the flag together with
a designed placeholder for a released file, or records that it was not worth the
regression.

**Rejected.** Enabling deletion and letting synced rows render a broken thumbnail
(degrades an approved screen); dropping the policy entirely (the success/cleanup
ordering is worth having and worth showing); keeping a downscaled thumbnail after
deleting the original (a second image pipeline, for a bonus row).

---

## ADR-F17 — The claim selects a candidate, then guards the update by id

**Status:** ACCEPTED — F1 · **Refines** the SQL sketch in `DATA_MODEL.md` §4 ·
**Requirements:** FLT-SYNC-008, FLT-SYNC-009, FLT-SYNC-013

**Context.** The design specified the claim as one statement with the candidate
chosen by an inline subquery. Implementing it exposed a problem the sketch could
not show: **the caller cannot learn which row it claimed.** `UPDATE … RETURNING`
would solve that, but `RETURNING` needs SQLite 3.35 (2021), and `sqflite` uses the
platform's own SQLite on Android, which on older supported API levels predates it.

**Decision.** `claimNext` reads the oldest claimable id, then issues the
conditional `UPDATE … WHERE id = ? AND (status = 'PENDING' OR (status =
'UPLOADING' AND claimed_at < ?))`. A claim succeeded only if that statement
affected exactly one row. A losing claimant retries with the next candidate, up to
a small bound.

**Reasoning.** The atomicity is unchanged, and it was never in the subquery. It is
in the `WHERE` clause of the write: the precondition is re-tested inside the same
statement, so two claimants that picked the same row cannot both match. The
candidate read is only a hint — if it is stale, the guarded update simply affects
zero rows, which is the losing case the design already accounted for.

The statement is deliberately **not** wrapped in a further transaction. It already
is one, and a deferred read-then-write transaction held across two connections
would add a lock-upgrade deadlock to defend against without making anything safer
(`DATA_MODEL.md` §6 says the same).

Verified by `upload_queue_claim_test.dart`, which races two — and then eight —
**independent database connections** to one file and asserts exactly one winner,
including on a stale lease.

**Also decided here: `recordSuccess` is guarded on `UPLOADING`,** not on
`status != 'UPLOADED'` as originally sketched. The stricter guard gives the same
idempotency (a repeat affects zero rows, invariant I7) and additionally refuses a
success written by a caller that does not hold the claim, and refuses to overwrite
a terminal `FAILED_PERMANENT` row.

**Rejected.** `UPDATE … RETURNING` (not available on the oldest supported Android
SQLite); claiming inside an explicit transaction (deadlock surface, no added
safety); returning the whole claimable set and filtering in Dart (moves exclusion
out of the database, which is the mistake `ADR-F04` exists to prevent).

---

## ADR-F18 — A drain pass does not retry an item it has already tried

**Status:** ACCEPTED — F1 · **Requirements:** FLT-SYNC-004, FLT-SYNC-007

**Context.** Found by a test, not by inspection. A retryable failure returns a row
to `PENDING`, which makes it immediately claimable — so the first `QueueProcessor`
implementation re-claimed the item it had just failed, on the very next iteration,
until it hit the per-invocation bound. One offline image produced twenty-five
upload attempts in a fraction of a second.

**Decision.** `QueueProcessor.drain` keeps a set of ids it has returned to the
queue during this pass and passes it to `UploadQueue.claimNext(skip: …)`, which
excludes them from candidate selection. Those items stay `PENDING` and are picked
up by a **later** invocation.

**Reasoning.** That tight loop is the app running its own retry schedule — the
exact thing `RS-04` and `FLT-SYNC-007` say must not happen, because it competes
with the backoff WorkManager already provides and burns a background execution
window achieving nothing. Excluding the item from *candidate selection*, rather
than claiming and then releasing it, also avoids stamping a lease on a row the
processor has decided not to work on, which would strand it for the full lease
period.

The set is bounded by the per-invocation item limit, so the generated `NOT IN`
clause stays small.

**Rejected.** Stopping the whole pass at the first retryable failure (one bad item
would block unrelated batches from draining); claiming then releasing the item
(a pointless write, and a crash between the two strands it for ten minutes); a
`Future.delayed` between attempts (an app-side retry timer by another name).

---

## ADR-F19 — A bounded slice asks for a continuation; only failure asks for a retry

**Status:** ACCEPTED — F1 post-audit · **Requirements:** FLT-SYNC-002,
FLT-SYNC-004, FLT-SYNC-007 · **Raised by:** the F1 architecture audit

**Context.** `QueueProcessor.drain` is bounded at 25 items, and the worker
returned `false` whenever anything was still outstanding. On Android `false`
means *retry with backoff*, so the platform could not tell these two apart:

* **the transport is failing** — nothing uploaded, come back later;
* **the slice worked and there is more** — 25 photos delivered, come back now.

A hundred healthy queued photos therefore drained under an escalating backoff
curve — 15 s, 30 s, 60 s — growing precisely *because* each slice succeeded. No
data was at risk; the scheduling semantics were simply wrong, and wrong in the
direction that gets slower the better the app is working.

**Decision.** Four explicit dispositions, computed from what the pass achieved:

| Disposition | When | Worker returns |
| --- | --- | --- |
| `idle` | Nothing eligible, nothing outstanding | `true` |
| `drained` | Everything outstanding resolved | `true` |
| `continuationRequired` | **Progress made** and work remains | `true`, after enqueuing a successor |
| `retryLater` | No progress was possible | `false` |

A continuation is `registerOneOffTask` under the **same** unique name with
`ExistingWorkPolicy.append`, enqueued from inside the running worker.

**Reasoning.**

*Why progress is the criterion.* "Progress" means at least one item left the work
set — an upload, or a permanent classification. Requiring it is what makes the
continuation chain provably finite: every link must have moved something, so the
chain is bounded by the size of the queue and cannot become a hot loop. A
condition like "outstanding > 0" would have allowed an endless chain of
zero-work continuations whenever another processor held every claimable item.

*Why the same unique name.* A pending continuation **is** a scheduled drain, so
every request stays on one serial chain rather than starting a second one. The
duplicate-work protection from `RS-03` is preserved.

> **Amended by `ADR-F21`.** This ADR left *entry* work on
> `ExistingWorkPolicy.keep`. That turned out to open a liveness race of its own —
> `KEEP` discards a request made while a worker is still running. Entry work now
> uses `append` as well, and both paths share one constant.

*Why `append` and specifically not `keep`.* Verified in `workmanager_android`
0.10.8's own Kotlin (`FR-06a`): Dart's `append` maps to Android's
**`APPEND_OR_REPLACE`**, which runs the successor after the current work and
starts a fresh chain if the predecessor was cancelled or failed rather than
inheriting that state. `keep` would have been silently wrong — a worker asking
for its own successor is itself uncompleted work under that unique name, so
`KEEP` discards the request and the backlog sits until something unrelated wakes
it. That is a defect that reads as correct and never fires in a test.

*Why the worker still cannot ask for entry work.* `BackgroundSyncScheduler`
suppresses `scheduleDrain` and forwards only `scheduleContinuation`. `RS-04` —
"an app-side scheduler fighting WorkManager's backoff" — remains prevented, but
now by a type rather than by a comment.

*Why the fallback is `false`.* If the continuation cannot be enqueued the worker
returns `false`, accepting backoff. A backlog delayed by backoff is recoverable;
a backlog nobody is coming back for is not.

*Why a time budget was added alongside the item budget.* Android stops a worker
at roughly ten minutes, and 25 slow uploads can exceed that. A worker killed
mid-item reports nothing at all — the pass is cut off rather than finishing and
asking for a continuation, which is the failure mode the whole ADR exists to
avoid. Eight minutes leaves headroom for the item in flight. It is checked
between items, never inside one: abandoning an upload half-way would leave a
claim to expire instead of a clean result.

**Rejected.** Removing the bound (a worker must stay bounded; the platform will
kill an unbounded one mid-item); a periodic worker (15-minute minimum period,
and it is polling by another name); `ExistingWorkPolicy.replace` for the
continuation (it would cancel the very worker enqueuing it); a second unique name
for continuations (splits the duplicate-work protection in two and re-creates the
same `KEEP`-while-running trap one level down); an app-side `Future.delayed`
chain (an app-side scheduler, which is exactly `RS-04`).

**Preserved unchanged.** The atomic claim remains the correctness boundary
between slices — a continuation is just another claimant, and nothing about
hand-over between bounded slices relies on the scheduler being correct.

---

## ADR-F20 — One draft batch is an application rule, not a database constraint

**Status:** ACCEPTED — F1 post-audit · **Requirements:** FLT-BAT-004 ·
**Raised by:** the F1 architecture audit

**Context.** Invariant I3 said "at most one `DRAFT` batch exists", listed beside
invariants that SQLite genuinely enforces. The schema has no `UNIQUE` index for
it, and `createDraftBatch` implements it as a read followed by an insert — which
is not atomic across connections. The claim and the mechanism did not match.

**Decision.** I3 is an **application-level capture-workflow rule**, enforced
where batches are created, and the documents now say so. No `UNIQUE` index or
partial index is added.

**Reasoning.** Draft batches have exactly **one** creator: the foreground capture
flow. The background worker drains a queue; it never creates a batch, and
nothing else does either. A cross-isolate guarantee protects against a second
writer that does not exist, and the cost is not zero — a partial unique index on
`status = 'DRAFT'`, an insert path that has to handle a constraint violation as
a normal outcome, and a migration to add it later if the shape changes.

The contrast with I4 is the point, and it is the useful thing for a reviewer to
see. The *claim* has two writers by design, so exclusion lives in SQL and is
proven with independent connections. Batch creation has one writer, so it does
not. Applying the heavier mechanism uniformly would look rigorous and would in
fact be architecture theatre — the same judgement `ADR-F01` and root `ADR-009`
already applied elsewhere.

What is not acceptable is the previous state: describing an application policy in
language that implies database enforcement. A test now asserts the *limit* of the
guarantee — a direct insert bypasses the policy — so nobody later reads I3 as
cross-isolate protection.

**Revisit if** a second creator of draft batches ever appears (a share-sheet
import, a background restore). At that point the single-writer assumption is gone
and the index becomes the right answer.

**Rejected.** A partial `UNIQUE` index (complexity for a race with no second
writer); wrapping the read-then-insert in a transaction (does not help across
connections, and would suggest a guarantee it still could not make); leaving the
wording as it was (the specific thing the audit objected to).

---

## ADR-F21 — One serial chain: every drain request uses `append`, never `keep`

**Status:** ACCEPTED — F1 final acceptance · **Requirements:** FLT-SYNC-002,
FLT-SYNC-004 · **Amends** `ADR-F19` (which changed only the continuation) ·
**Raised by:** the F1 final scheduling audit

**Context.** `ADR-F19` gave the continuation `ExistingWorkPolicy.append` but left
entry work on `keep`. `KEEP` reads well — "a drain is already scheduled, don't add
another" — and is wrong inside one window, because it discards a request while
*uncompleted* work exists under that unique name, and a **running** worker is
uncompleted:

```
worker: takes its final outstanding-count reading      → sees 0
                             app: finishes a batch, images → PENDING (committed)
                             app: scheduleDrain()
                             OS:  KEEP → request discarded
worker: returns success — it never saw those rows
result: durable PENDING work, and nothing scheduled to collect it
```

No data is lost, and every component reports success. It is a **liveness** gap in
"retries automatically, without user intervention", and it is invisible.

**Decision.** Both `scheduleDrain` and `scheduleContinuation` enqueue onto **one
serial unique chain** with `ExistingWorkPolicy.append`, expressed as a single
`WorkManagerSyncScheduler.conflictPolicy` constant so the two paths cannot drift
into one safe and one racy.

**Reasoning.**

*Why it closes the race.* `append` maps to Android's `APPEND_OR_REPLACE` —
verified verbatim in the resolved `workmanager_android` 0.10.8
`WorkManagerUtils.toAndroidWorkPolicy`, not from the Dart doc comment, which
describes plain `APPEND`. With no chain it starts one; with a running worker it
enqueues a successor. **The request cannot vanish**, whatever the worker is doing
when it arrives. It also starts a fresh chain rather than inheriting a cancelled
or failed predecessor.

*What it costs, stated plainly.* The opposite failure. Redundant requests now
accumulate as extra nodes instead of collapsing into one. That is the cheaper
mistake by a wide margin: a redundant node opens the database, finds nothing
claimable, returns `idle`, and is gone in milliseconds — whereas a discarded
request is a queue that stops draining with nothing to indicate it. One wastes a
wake-up; the other loses the feature.

*Why accumulation stays small.* Because the app asks only when durable
*uploadable* work appears — a finished batch, or a regained link. It does **not**
ask on capture: a `DRAFT` image is not uploadable, so a worker woken by the
shutter has nothing to do. `RecordCapture` takes no scheduler at all, so a
twenty-photo session produces one request rather than twenty. This mattered less
under `keep`, where the extras collapsed; under `append` it is what keeps the
chain short.

*What is preserved.* One unique name still means one **serial chain** —
WorkManager runs it a node at a time, so the scheduler never asks for two
parallel drains, and ordering holds (`RS-03`). And correctness never rested on
that: if two drains ever do overlap, the atomic claim is the boundary. That is
now proven directly, by two processors on **independent database connections**
draining one queue concurrently with no image uploaded twice.

**Rejected.** Keeping `keep` and adding a post-commit re-check inside the worker
(narrows the window, cannot close it — there is always a last read); `replace`
(cancels the very worker that may be mid-upload); a second unique name for entry
work (two chains that can run in parallel, splitting `RS-03` for no gain);
`cancelByUniqueName` before enqueuing (a cancel-then-enqueue race, and it can
kill a working drain).

**Also decided here: a locked database ends a pass rather than escaping it.**
Proving the concurrent-drain property exposed that `SQLITE_BUSY` propagated out
of `QueueProcessor.drain`, which documents that it does not throw for an ordinary
failure — and contention between the app's own two isolates is ordinary by
design. It now ends the pass with `DrainStop.databaseBusy` and whatever the pass
achieved. Nothing is stranded: a claim that lost never happened, and an item
already claimed is released by its lease. Deliberately not retried in a loop —
that would be an app-side retry schedule, which is `RS-04`.

---

## ADR-F22 — Permanent camera denial is reported only where the platform reports it; elsewhere the app counts refusals instead

**Status:** ACCEPTED · **Requirements:** FLT-ERR-001, FLT-ERR-002, FLT-GEN-004 ·
**Closes:** the `FLT-ERR-002` platform question raised at F3

**Context.** `CAMERA_ENGINE.md` §7 specifies two permission states — denied, and
permanently denied with an "Open settings" route. That table was written from the
`camera` plugin's example app, which branches on `CameraAccessDenied` and
`CameraAccessDeniedWithoutPrompt`.

**Evidence.** Verified in the resolved plugin sources this gate
(`RESEARCH.md` `FR-12`): `camera_android_camerax` 0.7.4+7 emits **only**
`CameraAccessDenied`. `CameraPermissionsManager.java` declares two error
constants, and every refusal — including an interrupted request with empty
`grantResults` — produces the same one. `CameraAccessDeniedWithoutPrompt` and
`CameraAccessRestricted` exist solely in `camera_avfoundation`.

So on Android, the mandated platform, the second state of that table is
**unreachable**. The design as specified could not be implemented truthfully.

**Decision.** Split the two facts that were conflated:

* `CameraPermissionDenied.isPermanentPerPlatform` — true **only** when the
  platform actually said so. Always `false` on Android. Nothing else may set it.
* `CameraPermissionDenied.consecutiveDenials` — how many times in a row this
  session has been refused. A count, not a verdict.

The later UI (gate F5) offers "Try again" on the first refusal and *adds* "Open
settings" once refusals repeat. That is an escalation of what is **offered**, and
it is never worded as a claim about what the OS decided.

**Reasoning.** This is the same rule as `ADR-F03`, applied to a second platform
gap found the same way. The app may act on a suspicion; it may not state one as
fact. Offering a settings shortcut after two refusals is helpful and true —
"Camera access is permanently denied" would be neither, since the user may simply
have dismissed the dialog twice.

**Rejected.**

* *Adding `permission_handler`* to reach Android's
  `shouldShowRequestPermissionRationale`. A second permission library for one
  permission, rejected at `RESEARCH.md` §2 and no more justified now. Its signal
  is also only meaningful immediately after a request, which is not where the app
  needs it.
* *Treating the second `CameraAccessDenied` as permanent.* Indistinguishable from
  a user who dismissed the dialog twice, and it would put a dead-end screen in
  front of someone one tap from granting.
* *Timing the refusal* — a permanently-denied request returns without showing a
  dialog, so it comes back faster. Inferring permission state from a stopwatch is
  exactly the kind of undocumented heuristic `ADR-F03` refused for lens identity.

**Consequence for the UI sprint.** "Open settings" needs a platform call Flutter
does not provide. The cheapest correct route is a `MethodChannel` in this app's
own `MainActivity` firing
`Settings.ACTION_APPLICATION_DETAILS_SETTINGS` with a `package:` URI — no new
dependency, about fifteen lines, and it is Android-only, which matches the
declared scope. **Not built at F3**: it is UI recovery plumbing with no engine
caller yet, and building it now would ship an untested code path. Recorded here
so F5 does not have to rediscover it.

---

## ADR-F23 — The preview seam is one getter, and the coordinate mapper supports both fits

**Status:** ACCEPTED · **Requirements:** FLT-CAM-002, FLT-CAM-008, FLT-GEN-007

**Context.** Two questions the camera engine had to answer before any UI exists:
how a widget reaches a live `CameraController` without dragging the plugin into
the domain, and which preview fit the tap-to-focus mapping is written against.

**Decision, part one — the preview.** `CameraSession` (domain) stays pure Dart.
`CameraPreviewSource` — a single `CameraController get previewController` — is
declared in `data/camera`, implemented by `CameraXSession`, and consumed by one
top-level function, `buildCameraPreview(session)`. A session that does not
implement it renders a placeholder.

*Reasoning.* `CameraPreview` needs a controller and there is no pure substitute.
An abstraction whose only implementation hands the controller back regardless
would be theatre that makes the real integration worse. One getter and one type
test is the smallest thing that keeps the domain clean, keeps every cubit test
binding-free, and lets a fake session render as a placeholder in a widget test.
An automated test now confines `package:camera/` imports to `lib/data/camera/`,
so the seam cannot quietly widen.

**Decision, part two — the fit.** `FocusPointMapper` takes a `PreviewLayout`
carrying the widget box, the preview aspect ratio, and a `PreviewFit` of
`contain` or `cover`, and implements both.

*Reasoning.* `CAMERA_ENGINE.md` §5 described letterboxing (`contain`, where a tap
on a band correctly returns `null`); `UX_SPEC.md` §4 specifies a **full-bleed**
viewfinder (`cover`, where every tap is on image but part of the image is
cropped away). Both documents are approved and neither is wrong — they describe
different renderings. Implementing only one would force the UI sprint to either
change an approved layout or ship a mapping that is subtly wrong everywhere the
sensor and the screen disagree, which is most devices. Supporting both costs one
branch and is unit-tested at the aspect-ratio boundaries either way. The UI
supplies the fit; the engine never guesses it, and no prototype geometry is
hard-coded.
