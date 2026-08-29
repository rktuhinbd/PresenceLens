# Flutter Task — Data Model

**What this document is for:** it defines the durable shape of the queue, the
legal state transitions, and the invariants that must hold after a crash. It is
the specification the DAO tests are written against.

Covers `FLT-GEN-003`, `FLT-BAT-*`, `FLT-SYNC-001`, `FLT-SYNC-008` … `FLT-SYNC-013`,
`FLT-ERR-005` … `FLT-ERR-007`.

---

## 1. Storage split

Two stores, with a strict division of labour ([root ADR-005](../DECISIONS.md#adr-005),
confirmed by `RESEARCH.md` `FR-09`):

| Store | Holds | Why |
| --- | --- | --- |
| **Filesystem** — an app-owned directory under `getApplicationDocumentsDirectory()` | The captured JPEG bytes | Image blobs in SQLite bloat the database, make every queue read expensive, and collide with sqflite's exclusive-transaction model. |
| **SQLite** (`sqflite`) | Batch and queue metadata, including the file path | Needs transactions, ordering, and atomic conditional updates. |

Layout on disk:

```
<app documents>/captures/<batchId>/<imageId>.jpg
```

Grouping by batch means a discarded batch is one directory removal, and an orphan
scan is a directory listing rather than a full-table join.

**These two stores can disagree** — a file can exist with no row (crash between
write and insert) or a row can point at a missing file (external deletion,
restore-from-backup). Both directions are handled explicitly in §6.

---

## 2. Schema

```sql
CREATE TABLE capture_batches (
  id             TEXT    PRIMARY KEY,          -- UUIDv4
  created_at     INTEGER NOT NULL,             -- epoch ms, UTC
  queued_at      INTEGER,                      -- NULL while still DRAFT
  status         TEXT    NOT NULL,             -- BatchStatus
  image_count    INTEGER NOT NULL DEFAULT 0    -- denormalised; see §5
);

CREATE TABLE queued_images (
  id             TEXT    PRIMARY KEY,          -- UUIDv4; also the idempotency key
  batch_id       TEXT    NOT NULL,
  local_path     TEXT    NOT NULL,             -- absolute, durable
  captured_at    INTEGER NOT NULL,
  status         TEXT    NOT NULL,             -- ImageStatus
  attempt_count  INTEGER NOT NULL DEFAULT 0,
  last_attempt_at INTEGER,
  claimed_at     INTEGER,                      -- lease stamp; NULL unless UPLOADING
  last_failure   TEXT,                         -- FailureCategory, nullable
  FOREIGN KEY (batch_id) REFERENCES capture_batches (id) ON DELETE CASCADE
);

-- Drives the claim query in §4. Without this the drain does a table scan
-- every time the worker wakes.
CREATE INDEX idx_queued_images_work
  ON queued_images (status, captured_at);

CREATE INDEX idx_queued_images_batch
  ON queued_images (batch_id);
```

Notes on specific columns:

- **`id` is a client-generated UUID, not an autoincrement integer.** It is
  generated at capture time and sent as the upload's idempotency key
  (`FLT-SYNC-010`), so a retry after an ambiguous failure is recognisable as the
  same image by a real server later.
- **`claimed_at` is separate from `last_attempt_at`.** The first is a *lease*; the
  second is *history*. Conflating them makes stale-claim recovery ambiguous.
- **Times are epoch milliseconds UTC.** No local time is stored.
- **`local_path` is absolute.** On Android the app documents directory is stable
  for the install; a reinstall clears both stores together, so there is no
  rebased-path case to handle. Recorded as a known limitation rather than
  pre-solved.

---

## 3. States and legal transitions

### `BatchStatus`

```
DRAFT ──enqueue()──▶ QUEUED ──all images UPLOADED──▶ COMPLETED
  │
  └──discard()──▶ (row + directory deleted)
```

- `DRAFT` — open, accepting captures. **At most one `DRAFT` batch exists at any
  time** (`FLT-BAT-004`) — a workflow rule enforced where batches are created,
  not a database constraint (`ADR-F20`).
- `QUEUED` — closed and handed to the sync engine. Accepts no further captures.
- `COMPLETED` — every image uploaded. Terminal.

### `ImageStatus`

```
                    ┌──────────────────────────────┐
                    │                              │ (lease expired)
                    ▼                              │
  DRAFT ─enqueue─▶ PENDING ─claim─▶ UPLOADING ──────┘
                    ▲                  │
                    │                  ├─ success ─────▶ UPLOADED   (terminal)
                    │                  │
                    └─ retryable ──────┤
                       failure         │
                                       └─ permanent ───▶ FAILED_PERMANENT (terminal)
```

| State | Meaning |
| --- | --- |
| `DRAFT` | Captured, file on disk, batch not yet enqueued. |
| `PENDING` | Eligible for upload. The only state a worker may claim. |
| `UPLOADING` | Claimed by a processor; `claimed_at` set. |
| `UPLOADED` | Confirmed by the API. Terminal. |
| `FAILED_PERMANENT` | Will not be retried. Terminal. |

**There is no `RETRYABLE_FAILURE` state, by design.** A retryable failure returns
the row to `PENDING` and increments `attempt_count`, recording the reason in
`last_failure`. Adding a distinct state would create a second resting place that
the claim query must also scan, and would need its own recovery path — two ways to
say "waiting", which is exactly how queues develop stuck items. "Retrying" is a
*presentation* concept, derived as `status == PENDING && attempt_count > 0`
(`FLT-UX-009`), not a stored one.

`FAILED_PERMANENT` **does** earn its place, because a genuinely unprocessable item
(missing local file, `FLT-ERR-007`) must leave the work set or the queue never
drains. It is entered only from the classifier's `permanent` verdict.

---

## 4. The claim: how concurrency is actually prevented

This is the load-bearing mechanism (`FLT-SYNC-008`). From `RESEARCH.md` `FR-08`,
the UI isolate and the worker isolate hold **separate** database connections, so no
Dart-level lock spans them. Exclusion is therefore delegated to SQLite:

**As implemented** (`UploadQueueDao.claimNext`, `ADR-F17`). Two statements: a
candidate read, then the claim itself.

```sql
-- 1. Which row would we like? A hint, nothing more.
SELECT id FROM queued_images
 WHERE (status = 'PENDING'
        OR (status = 'UPLOADING' AND claimed_at < :leaseCutoff))  -- reclaim stale
   AND id NOT IN (:alreadyTriedThisPass)                          -- ADR-F18
 ORDER BY captured_at ASC, id ASC
 LIMIT 1;

-- 2. THE claim. Atomic: this statement's WHERE clause is the lock.
UPDATE queued_images
   SET status = 'UPLOADING',
       claimed_at = :now
 WHERE id = :candidate
   AND (status = 'PENDING'
        OR (status = 'UPLOADING' AND claimed_at < :leaseCutoff));  -- re-checked
```

The design originally wrote this as a single statement with the candidate chosen
by an inline subquery. It is two statements because the caller must learn *which*
row it claimed, and `UPDATE … RETURNING` needs SQLite 3.35 — newer than the
platform SQLite on the oldest Android version this app supports (`ADR-F17`).

**The atomicity is unaffected, because it was never in the subquery.** It is in
the `WHERE` clause of the write. The trailing `AND` re-tests the precondition
*inside* the atomic `UPDATE`, so if two processors pick the same row, only the
first matches; the second affects **zero rows** and moves on to the next
candidate. The DAO returns a row only when the update affected exactly one, and
retries with the next candidate up to `maxClaimAttempts` (5) so a loser that still
has other work to do does not report an empty queue.

The claim is deliberately **not** wrapped in a further transaction: the statement
already is one, and a deferred read-then-write transaction held across two
connections would add a lock-upgrade deadlock to defend against without making
anything safer.

`ORDER BY captured_at ASC, id ASC` gives the deterministic cross-batch ordering
required by `FLT-SYNC-013`; the id is the tie-break, so two captures sharing a
millisecond still drain in a fixed order.

`id NOT IN (…)` excludes items the *current drain pass* has already tried and
returned to the queue. Without it, a retryable failure — which makes a row
`PENDING` and therefore immediately claimable again — is re-claimed by the very
next iteration and retried in a tight loop, which is the app taking over the
backoff that belongs to WorkManager. Found by a test; see `ADR-F18`.

The same clause reclaims stale leases (`FLT-SYNC-009`): an item whose
`claimed_at` is older than the lease period is treated as claimable again. **Lease
period: 10 minutes** — comfortably longer than any plausible single upload attempt,
short enough that a process killed mid-upload recovers within one ordinary
WorkManager cycle. It is a named constant with this reasoning at its definition.

This is why stale recovery needs no startup sweep: recovery is a property of the
claim query, so it happens on every drain, in both isolates, without a separate
code path that could be forgotten.

---

## 5. Invariants

Each is a test in the `DATA` suite.

| # | Invariant | Enforced by |
| --- | --- | --- |
| I1 | A `queued_images` row never references a file that was not durably written first. | Write-file-then-insert ordering (`FLT-CAM-015`, `FLT-ERR-005`). |
| I2 | Enqueuing a batch moves the batch and **all** its images in one transaction, or none of them. | Single `transaction {}` (`FLT-BAT-005`). |
| I3 | At most one `DRAFT` batch exists. | `BatchPolicy` + a guard on batch creation — an **application-level capture-workflow rule**, not a database constraint. There is one creator of draft batches (the foreground capture flow) and the background worker never creates one, so there is no second writer to race with and a `UNIQUE` index would buy nothing. The guard is a read-then-insert and is deliberately *not* atomic across connections; contrast I4, which has two writers by design and is therefore enforced in SQL. See `ADR-F20`. |
| I4 | No image is `UPLOADING` in two processors at once. | The atomic claim, §4. |
| I5 | An `UPLOADING` row cannot remain unclaimable forever. | Lease expiry in the claim's `WHERE`. |
| I6 | A retryable failure destroys neither the row nor the file. | Transition writes `status`/`attempt_count` only (`FLT-SYNC-003`). |
| I7 | Marking an image `UPLOADED` twice is harmless. | `WHERE status = 'UPLOADING'`; the second call affects 0 rows (`FLT-SYNC-010`). Stricter than the `!= 'UPLOADED'` originally sketched — it also refuses a success from a caller that holds no claim, and refuses to overwrite a terminal `FAILED_PERMANENT` row (`ADR-F17`). |
| I8 | A batch becomes `COMPLETED` only when it has ≥1 image and none are outstanding. | Completion check inside the success transaction. |
| I9 | `image_count` equals the actual row count for that batch. | Updated inside the same transaction as every insert; asserted by a reconciliation test. |
| I10 | An image whose file is missing reaches a terminal state rather than looping. | `FAILED_PERMANENT` (`FLT-ERR-007`). |

`image_count` is denormalised deliberately: the Pending Uploads list renders per
batch, and recomputing a `COUNT(*)` per row on every queue change is wasteful for a
value that only changes inside transactions that already hold the write lock. I9
is the price, and it is paid with a test.

---

## 6. Transaction boundaries

| Operation | Transaction contents |
| --- | --- |
| **Capture** | *(file write happens first, outside)* → insert `queued_images` (`DRAFT`), increment `image_count`. |
| **Enqueue batch** | Batch → `QUEUED`, set `queued_at`, all its `DRAFT` images → `PENDING`. Refused if the batch has no images (`FLT-BAT-006`). |
| **Claim** | Single atomic `UPDATE` (§4). Not wrapped further — the statement *is* the transaction. |
| **Record success** | Image → `UPLOADED`, clear `claimed_at`; if no outstanding images remain, batch → `COMPLETED`. |
| **Record retryable failure** | Image → `PENDING`, `attempt_count + 1`, set `last_attempt_at`/`last_failure`, clear `claimed_at`. |
| **Record permanent failure** | Image → `FAILED_PERMANENT`, clear `claimed_at`, set `last_failure`. |
| **Discard draft batch** | Delete rows (cascade), then remove the batch directory. Row-first so a crash leaves an orphan file, not an orphan row — see below. |

**Ordering rule, applied consistently:** when the filesystem and database must
both change, sequence them so that a crash in between leaves an **orphan file**
rather than a **dangling row**. An orphan file is invisible, bounded, and
reclaimable by a sweep; a dangling row is a queue item that can never succeed.
Hence: write file → insert row on the way in, delete row → delete file on the way
out.

---

## 7. Migrations

Schema version starts at 1. `onCreate` builds the tables above; `onUpgrade` is
implemented but empty. A migration path exists from the first commit because
retrofitting one onto shipped user data is the expensive version of this problem.

`onUpgrade` is a **registry**, not an empty method body. `AppDatabase.migrations`
maps a target version to the step that reaches it, and `migrate` refuses a bump
with no registered step. The failure that guards against is specific: sqflite
records the new version whenever `onUpgrade` completes, so an empty callback
would let someone raise `schemaVersion`, ship it, and have every existing install
record the new version against the old tables — the first symptom being a query
failing on a user's device rather than in CI. `onDowngrade` refuses too, rather
than using sqflite's `onDatabaseDowngradeDelete`: deleting a queue of unuploaded
captures to resolve a version mismatch is the one outcome worse than failing to
open.

`onConfigure` runs two pragmas on **every** connection, and both are load-bearing:
`foreign_keys = ON` (off by default in SQLite, which would otherwise make the
cascade in §2 decoration rather than behaviour) and `busy_timeout = 5000` (two
connections exist by design, so a write can genuinely find the database locked;
waiting briefly is correct, failing instantly would surface as a spurious
"database is locked" on an ordinary drain).

`AppDatabase.open` takes a `singleInstance` flag that the app never changes. It
exists for the `DATA` suite: within one isolate sqflite hands back the *same*
connection for the same path, so a contention test would otherwise be two calls on
one connection and would prove nothing. Setting it `false` gives the test
genuinely independent connections to one file — the host's reproduction of what
the UI isolate and the worker isolate do on a device (§8).

## 8. Test doubles

`sqflite_common_ffi` runs the **real** SQLite engine on the Dart VM, so the `DATA`
suite exercises actual transaction and locking semantics on the host rather than a
hand-written in-memory fake. This matters most for §4: a fake would happily
"pass" a claim implementation that is not actually atomic. In-memory fakes are used
only in `BLOC` tests, where the database is not what is under test.
