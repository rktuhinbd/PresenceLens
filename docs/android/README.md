# PresenceLens Attendance — Engineering Documentation

**What this document is for:** it is the primary entry point to the Native Android engineering documentation for PresenceLens. Give an interviewer a 30-second map of Task 1 documentation.

## Current implementation

- [../../android-attendance/README.md](../../android-attendance/README.md)
- [ARCHITECTURE.md](ARCHITECTURE.md)
- [UX_SPEC.md](UX_SPEC.md)
- [TEST_STRATEGY.md](TEST_STRATEGY.md)

## Canonical shared evidence

- [../REQUIREMENTS_MATRIX.md](../REQUIREMENTS_MATRIX.md)
- [../PROJECT_STATE.md](../PROJECT_STATE.md)
- [../AI_USAGE.md](../AI_USAGE.md)

## Engineering provenance


The root ADR/research/execution documents preserve stable published engineering provenance. Android-specific current documentation lives in this folder.

## Runtime evidence

- [../assets/android/attendance-ready.png](../assets/android/attendance-ready.png)

## Design reference

- [design/README.md](design/README.md)
- [design/index.html](design/index.html)

**Post-implementation UI reference**: nine HTML pages rendered directly from the shipped Compose source (`android-attendance/app/src/main/java/.../presentation/attendance/`), parsed `strings.xml` copy, and the project's own vector icons. Only `02-tracking-ready.html` has committed Native runtime screenshot evidence; the rest are backed by deterministic `@Preview` fixtures or, for two kinds, derived directly from source. See `design/README.md` for the full authority and fidelity contract.
