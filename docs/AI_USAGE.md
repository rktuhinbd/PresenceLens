# AI Usage Log

Source record for README §3, which the assessment makes **mandatory** (DOC-05, DOC-06).

Per AGENTS.md, AI output is assistance, not authority: nothing is retained that the author cannot explain.

## At a glance

**How AI was used.** Claude, via the Claude Code CLI, assisted throughout — **Claude Opus 5** for the majority of gates (requirements extraction, architecture and ADR drafting, SQLite concurrency and edge-case analysis, implementation, and documentation reconciliation) and **Claude Sonnet 5** for three specific gates: G1 (Android foundation dependency research), G2 (Android attendance domain and office-location persistence), and the Android release-signing gate. AI did not make final engineering decisions; every retained artefact was reviewed against the verification criteria.

**How every output was validated.** Nothing was accepted on the model's word:
- **Automated tests** — 679 across both apps (158 Native Android, 521 Flutter).
- **Static analysis** — Android Lint and `flutter analyze`, both clean.
- **Builds** — debug and release builds, including from a clean clone.
- **Source inspection** — every retained line reviewed; nothing is kept that the author cannot explain.
- **Device and emulator QA** — physical HONOR DNP-NX9 runtime QA for the Flutter app, emulator acceptance walkthroughs for the Native app.

## Summary of AI Contributions & Human Corrections

- **Requirements extraction (Claude Opus 5)**: Extracted requirements from the assessment PDF into a traceable matrix. The AI was explicitly instructed *not* to guess missing text (e.g. across page boundaries) which led to identifying a source defect (AMB-01) rather than inventing a requirement.
- **Android Foundation (Claude Sonnet 5)**: Researched current stable coordinates for dependencies. Hilt was evaluated but rejected by the AI based on the "Anti-theatre constraint" prompt, favoring manual dependency wiring (ADR-009).
- **Android Domain & Persistence (Claude Sonnet 5)**: Implemented the 50m eligibility rule, Haversine distance, and DataStore persistence. A test defect (Windows filesystem limitation on `renameTo`) was exposed and corrected.
- **Android Location & UI (Claude Opus 5)**: Built the FusedLocationProvider layer and state-driven `AttendanceScreen`. The AI initially mapped the "location availability" estimate to a hard failure, which was caught by manual emulator QA (oscillating state) and subsequently fixed by separating *what the platform said* from *what the app knows* (ADR-014).
- **Android Release Signing (Claude Sonnet 5)**: Generated the local release keystore and configured Gradle without hardcoding secrets (ADR-010). The AI initially tried a PKCS12 conversion but gracefully fell back to JKS when interactive prompts failed, preserving the zero-interaction requirement.
- **Flutter Synchronization & Camera (Claude Opus 5)**: Drafted the SQLite durable queue and camera engine. The AI was heavily constrained ("Concurrency correctness must NOT depend on Dart bools..."). Architecture audits caught and corrected scheduling-liveness races (`ExistingWorkPolicy.keep` replaced with `.append`).
- **Physical Device QA Corrections**: Real device testing on a HONOR device revealed a MagicOS background constraint and an SQLite cold-start defect (`PRAGMA busy_timeout` through `db.execute`). These were diagnosed and fixed through human-AI collaboration.

## Human Ownership
All AI-generated code was verified by the author. When the AI hallucinated or took incorrect paths (e.g., oscillating location state, SQLite PRAGMA execution, PKCS12 conversion), the human reviewer identified the failure and directed the correction. The AI served as an accelerator, but the final architectural decisions, verification, and code ownership remain entirely with the human author.
