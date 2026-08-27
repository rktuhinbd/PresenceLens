# PresenceLens Agent Charter

## Mission

Build a senior-level mobile engineering assessment submission that satisfies
every requirement in the supplied Intelligent Machines technical assessment.

The repository contains:

- Native Android geo-attendance application.
- Flutter camera and resilient-sync application.

## Sources of Truth

Priority order:

1. Original assessment PDF.
2. docs/REQUIREMENTS_MATRIX.md
3. docs/DECISIONS.md
4. docs/PROJECT_STATE.md
5. Current source code and tests.
6. Agent/chat assumptions.

Never override a higher-priority source with a lower-priority assumption.

## Mandatory Session Start

Before changing code:

1. Read docs/PROJECT_STATE.md.
2. Identify current gate and active task.
3. Read relevant requirement IDs.
4. Read application-specific AGENTS.md when applicable.
5. Inspect existing implementation before proposing changes.

## Engineering Principles

- Prefer simple, production-defensible solutions.
- Do not introduce abstractions without a real responsibility.
- Separate UI, state, domain decisions, and data/device access.
- Keep business rules independently testable.
- Handle permissions, hardware failures, persistence failures, and network failures.
- Prefer deterministic behavior that can be demonstrated to reviewers.
- Avoid experimental dependencies unless essential.
- Never add unrelated features simply to appear sophisticated.

## Requirement Discipline

Every implementation change must map to one or more requirement IDs.

Never mark a requirement DONE without verification evidence.

If interpretation changes, update DECISIONS.md before implementation.

## Completion Protocol

A task is complete only after:

- implementation,
- formatting/linting,
- relevant automated tests,
- successful build,
- manual verification when required,
- requirement-matrix update,
- project-state update.

## Git Rules

Do not commit:

- secrets,
- signing keys,
- SDK paths,
- build directories,
- APK/AAB binaries,
- assessment source documents,
- personal documents.

Do not force-push or rewrite history.

Prefer small, meaningful commits.

## AI Rules

AI output is assistance, not authority.

Do not retain generated code that cannot be explained.

Record important AI-assisted reasoning and prompts in docs/AI_USAGE.md.

## Scope

This is a technical assessment, not a production startup.

Senior engineering judgment includes knowing what not to build.