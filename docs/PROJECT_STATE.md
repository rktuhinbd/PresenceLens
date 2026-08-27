# Project State

Resumption document. Read this first, then the active gate in
[EXECUTION_PLAN.md](EXECUTION_PLAN.md), then only the relevant rows of
[REQUIREMENTS_MATRIX.md](REQUIREMENTS_MATRIX.md).

Last updated: 2026-08-28
Overall status: **G0.1 READY TO CLOSE — human review complete**
Current gate: **G0.1 — Requirements & Architecture Freeze**

## Progress

| Area | State |
| --- | --- |
| Requirements extracted from the PDF | Complete — 64 requirements, 15 ambiguities |
| Architecture defined | Complete (both apps) |
| ADRs | 12 recorded — 10 `ACCEPTED`, 2 `PROPOSED` (ADR-009 technical revisit, ADR-010 deferred to G8) |
| **Android feature implementation** | **0% — not started** |
| **Flutter application** | **0% — project not created** |
| README / submission artefacts | Not started |

Feature progress is genuinely zero. The Android baseline builds, but that is scaffold
verification, not evidence for any assessment requirement.

## Verification status

| Check | Result |
| --- | --- |
| Android Gradle sync | PASS (Android Studio and PowerShell) |
| Android `clean` | PASS (PowerShell CLI) |
| Android `assembleDebug` | PASS (PowerShell CLI) |
| Android emulator launch | PASS |
| Command-line build viability | **RESOLVED** — PowerShell + Gradle wrapper is the documented path (`RF-20`) |
| Android `assembleRelease` | NOT RUN — would produce an **unsigned** APK (RF-09) |
| Android unit tests | Template placeholders only |
| Flutter project | **NOT CREATED** |
| Flutter build / tests | N/A |

## Active objective

G0.1 is complete. Human review closed all outstanding approvals on 2026-08-28, the
documentation set has been corrected accordingly, and the gate is ready to close.
**Do not begin G1 until the gate is formally closed.**

## Completed milestones

1. Repository governance established (AGENTS.md, CLAUDE.md).
2. Android project bootstrapped; baseline build and emulator launch verified.
3. **G0.1 documentation set authored** — requirements matrix, architecture, ADRs,
   research, execution plan, submission checklist, AI usage log.
4. Assessment PDF fully extracted, including all three embedded screenshots.
5. **G0.1 human review completed (2026-08-28).** ADR-001, ADR-002, ADR-003, ADR-011
   accepted; ADR-012 (Android visual direction) added and accepted; ADR-010 deferred
   to G8; `ER-01` and `ER-03` closed; `DA-07` resolved.

## Next gate

**G1 — Android Foundation.** No approvals outstanding; G1 through G3 are all
unblocked by the G0.1 review.

First actions in G1:

1. Resolve `ER-02` and `ER-04` to get exact artifact coordinates before pinning them.
2. Add G2's dependencies via the version catalog. **Do not** add
   `org.jetbrains.kotlin.android` — AGP 9+ supplies built-in Kotlin support (`RF-17`).
3. Adopt the verified PowerShell + Gradle wrapper command (`RF-20`) as the documented
   build path for later gates and README §4.

## Blockers

| ID | Blocker | Blocks | Notes |
| --- | --- | --- | --- |
| B-01 | Release build defines no `signingConfig`; `assembleRelease` would be unsigned and non-installable. | SUB-03, at G8 only | RF-09. Signing strategy (ADR-010) **deliberately deferred to G8** by human decision. Not a blocker before then, but must not be forgotten — it is the last-mile risk to the APK deliverable. |
| ~~B-02~~ | ~~`ER-03` unanswered (geofence minimum-radius guidance).~~ | — | **RESOLVED at G0.1 review** — `RF-18`; ADR-001 is now `ACCEPTED`. |
| B-03 | Flutter plugin viability unverified (`ER-05`, `ER-06`, `ER-07`). | G4 | Resolve before adding Flutter plugins, not after. |
| B-04 | A physical Android device is required for camera work (`DA-04`) and background-retry verification (`DA-06`). | G5, G6, G7 | Confirm availability before G5 — this is a scheduling risk, not a technical one. |

## Decisions resolved at G0.1 review (2026-08-28)

| ADR | Outcome |
| --- | --- |
| [ADR-001](DECISIONS.md#adr-001) | **ACCEPTED** — foreground, lifecycle-aware Fused Location Provider; no `GeofencingClient`. Android's recommended minimum geofence radius (~100–150 m) is far above this 50 m rule (`RF-18`). |
| [ADR-002](DECISIONS.md#adr-002) | **ACCEPTED** — DataStore for office coordinates; DataStore is for small, simple datasets, Room for complex ones (`RF-19`). |
| [ADR-003](DECISIONS.md#adr-003) | **ACCEPTED** — no Google Maps SDK. Preserve the panel's position and information role via an original dependency-free Compose/vector surface. No Maps branding, no copyrighted tiles, and no implied interactivity. |
| [ADR-011](DECISIONS.md#adr-011) | **ACCEPTED** — the availability caption is preserved as presentation detail and **must not** become an eligibility rule. The 50 m radius stays the only functional condition. |
| [ADR-012](DECISIONS.md#adr-012) | **ACCEPTED, new** — Android visual direction: reference-layout fidelity with premium native Material 3 execution. Preserve the reference information architecture; elevate execution using stable Material 3 only. Presentation authority only. |

## Decisions still open

| ADR | Status | Notes |
| --- | --- | --- |
| [ADR-010](DECISIONS.md#adr-010) | `PROPOSED` — **deferred to G8** | Release signing strategy: generated uncommitted keystore vs debug-signed release. Deliberately not chosen yet, by human decision. |
| [ADR-009](DECISIONS.md#adr-009) | `PROPOSED` | Manual DI instead of Hilt / get_it. Technical revisit only; no approval needed. Reassess if the Flutter background-worker entry point needs shared singletons (G6). |

## Constraints in force at G0.1

- No application features.
- No changes to Android source or build files.
- No new dependencies.
- No commits, no pushes.

## Notes for the next session

- The assessment PDF **loses text across the p2/p3 boundary** (AMB-01, RF-03). This is
  a defect in the source document, confirmed at character level — do not re-investigate.
- The Android screenshot is **prescriptive**; the Flutter screenshots are **advisory**
  ("Suggested UI"). The matrix preserves this distinction (RF-04) — do not flatten it.
- Two release APKs are planned, not one (AMB-09) — the deliverable says "APK" singular
  but the assessment has two apps.
- Nothing may be marked `DONE` without executing its own verification method.
