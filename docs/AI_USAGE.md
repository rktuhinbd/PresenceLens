# AI Usage Log & Disclosure

The Intelligent Machines technical assessment explicitly mandates the use of Generative AI. We embraced this requirement by using AI not just as a code generator, but as a strategic partner to build a more resilient, better-tested, and highly traceable application. 

This document discloses how AI was used, the specific prompts employed, and how outputs were validated. Entire transcripts are omitted in favor of highlighting the most impactful interventions.

---

## 1. Requirements Extraction & Traceability

**Purpose:** To extract every explicit requirement from the assessment PDF and build a durable planning/compliance matrix before any code was written.

**Prompt Summary:** *Read the assessment PDF and extract every explicit requirement into a matrix with stable IDs, planned implementation, and a verification method per row. If you cannot read the PDF, stop and say so — do not reconstruct requirements from assumptions.*

**Impact:** Forced the discovery of missing text at a page boundary (AMB-01), ensuring no optical behaviors or camera zoom presets were invented based on partial instructions. The generated `REQUIREMENTS_MATRIX.md` became the single source of truth for the project.

## 2. Architecture Review & Decision Discipline

**Purpose:** Ensure the architecture proposed was scalable, testable, and free of "architecture theater" (e.g., adding complex DI frameworks for simple apps).

**Prompt Summary:** *Propose the smallest senior-level architecture that satisfies the assessment. Avoid architecture theater. If a decision requires external technical verification, mark it PROPOSED rather than pretending certainty.*

**Impact:** Led to the deliberate rejection of Hilt in the Android app (ADR-009) and the adoption of a single-module architecture (ADR-004), favoring pure constructor injection and testability over boilerplate.

## 3. SQLite & WorkManager Edge-Case Discovery

**Purpose:** Validate the atomicity and durability of the background sync engine.

**Prompt Summary:** *I have a WorkManager task draining a SQLite queue. The user can also manually press 'Retry' in the UI. Concurrency correctness must NOT depend on Dart bools, in-memory mutexes, process-local locks, or singletons. Those mechanisms do not protect multiple DB connections/isolates. Propose a SQL-level locking strategy to prevent duplicate uploads.*

**Impact:** Shifted the concurrency burden entirely to SQLite, utilizing atomic `UPDATE` claims with leases instead of fragile Dart-level locks. This guaranteed that the background isolate and the UI could safely process the queue concurrently.

## 4. Camera API & Physical-Device Debugging

**Purpose:** Ensure the Flutter camera implementation correctly mapped to actual physical hardware rather than hardcoded assumptions.

**Prompt Summary:** *Write the CameraEngine interface. Zoom presets and focus regions must be derived from the device's reported optical range, not hardcoded. Android's inability to report permanent permission denial must be handled honestly.*

**Impact:** Resulted in the `ZoomPolicy` and `FocusPointMapper` domain models. The app dynamically queries the hardware limits (e.g., min zoom is not always 1.0) and adapts the UI, ensuring correctness across disparate devices like the Samsung S25 and HONOR DNP-NX9.

## 5. Test Planning

**Purpose:** Guarantee that the riskiest components had undeniable proof of correctness.

**Prompt Summary:** *Write the contention test early, with `sqflite_common_ffi` and separate database connections. A fake repository is NOT evidence. A test around an in-memory mutex is NOT evidence.*

**Impact:** Resulted in over 590 automated tests across both platforms. Forced the discovery that sqflite shares connections within the same isolate, requiring a specialized test harness to truly validate database contention.

## 6. UX Review & Refinement

**Purpose:** Polish the Android Attendance UI into a state-driven, professional experience.

**Prompt Summary:** *Refine the success state only. Remove the completed button, replace it with a compact confirmation carrying the time and the verified distance. Make the top status card read as complete. Do not change the 50m rule or the location layer.*

**Impact:** Reduced the vertical density of the success state by 36%, removing redundant visual noise while retaining all required assessment features. 

## 7. Release Audit

**Purpose:** Finalize the repository for submission, ensuring no missing assets, lingering debug code, or unchecked requirements.

**Prompt Summary:** *Perform a final audit of the tree. Search tracked files for placeholders, debug prints, absolute Windows paths, or unverified claims. Rebuild the SUBMISSION_CHECKLIST.md based strictly on verifiable evidence.*

**Impact:** Identified missing screenshots and unverified release signatures, enabling a fully green, transparent final submission.

---

## Validation Strategy

Every AI-assisted decision and code block was strictly subjected to the following validation gates:

1. **Automated Tests:** 158 Android unit tests and 521 Flutter tests (all passing).
2. **Static Analysis:** 0 lint errors in Android, 0 issues from `flutter analyze`.
3. **Builds:** Both debug and release (`assembleRelease`, `flutter build apk --release`) builds completed successfully from a clean clone.
4. **Physical Device QA:** Manual execution of end-to-end flows on HONOR DNP-NX9 (Android 16) and Samsung Galaxy S25 (Android 15), verifying hardware features like pinch-to-zoom and WorkManager execution.
5. **Direct Source/API Inspection:** Manual code review ensuring no hallucinations (e.g., verifying `APPEND_OR_REPLACE` behavior in the resolved WorkManager plugin source).
