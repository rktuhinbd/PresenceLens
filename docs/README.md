# Documentation Guide

This repository's `docs/` tree mixes two kinds of document, and conflating them is
the single easiest way to misread the project's status. This page exists to
prevent that.

**Historical gate snapshots describe the state at that gate and are not current
status claims.** Several documents narrate progress gate by gate as it happened —
that narration is deliberately preserved as provenance, not deleted or rewritten
to look complete in hindsight. **Current submission status is defined by
[PROJECT_STATE.md](PROJECT_STATE.md), [REQUIREMENTS_MATRIX.md](REQUIREMENTS_MATRIX.md),
and [SUBMISSION_CHECKLIST.md](SUBMISSION_CHECKLIST.md) alone.** Where a historical
paragraph elsewhere might read as a live status, it is labelled
`HISTORICAL GATE SNAPSHOT` inline, naming the later gate that supersedes it.

## Reviewer-facing current state

Start here to evaluate the submission as it stands today.

- [../README.md](../README.md) — root README: assessment status, screenshots, tech stack
- [../SUBMISSION.md](../SUBMISSION.md) — submission summary and links
- [PROJECT_STATE.md](PROJECT_STATE.md) — authoritative current-state snapshot
- [REQUIREMENTS_MATRIX.md](REQUIREMENTS_MATRIX.md) — every requirement's final disposition
- [SUBMISSION_CHECKLIST.md](SUBMISSION_CHECKLIST.md) — the binary submission audit

## Flutter final evidence

- [flutter/REQUIREMENTS_SPEC.md](flutter/REQUIREMENTS_SPEC.md) — 84 atomic requirements, final status
- [flutter/TRACEABILITY_MATRIX.md](flutter/TRACEABILITY_MATRIX.md) — assessment sentence → evidence, one lookup
- [flutter/CAMERA_ENGINE.md](flutter/CAMERA_ENGINE.md) — camera design + device verification checklist (§9)
- [flutter/SYNC_ENGINE.md](flutter/SYNC_ENGINE.md) — sync design + failure-injection matrix (§10)
- [flutter/TEST_STRATEGY.md](flutter/TEST_STRATEGY.md) — test strategy + final execution summary (§0)
- [flutter/RISK_REGISTER.md](flutter/RISK_REGISTER.md) — every risk's final disposition (§8)

## Historical engineering record

Preserved as provenance — read for *why*, not for current status.

- [EXECUTION_PLAN.md](EXECUTION_PLAN.md) — the original Android/G-numbered gate plan
- [flutter/EXECUTION_PLAN.md](flutter/EXECUTION_PLAN.md) — the F0–F8 Flutter gate plan
- [DECISIONS.md](DECISIONS.md) · [flutter/DECISIONS.md](flutter/DECISIONS.md) — ADRs
- [RESEARCH.md](RESEARCH.md) · [flutter/RESEARCH.md](flutter/RESEARCH.md) — pre-implementation research
- [ARCHITECTURE.md](ARCHITECTURE.md) · [flutter/ARCHITECTURE.md](flutter/ARCHITECTURE.md)
- [flutter/DATA_MODEL.md](flutter/DATA_MODEL.md) · [flutter/UX_SPEC.md](flutter/UX_SPEC.md)

## Also

- [AI_USAGE.md](AI_USAGE.md) — the Generative AI disclosure log (DOC-05, DOC-06)
