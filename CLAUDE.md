@AGENTS.md

# Claude Code Instructions

Before any implementation task:

1. Read docs/PROJECT_STATE.md.
2. Identify the active gate.
3. Read only the relevant rows from docs/REQUIREMENTS_MATRIX.md.
4. Read the applicable application-level AGENTS.md if working inside an app.
5. State which requirement IDs the change addresses before editing.

For architecture or multi-file changes, use Plan Mode first.

Use subagents for isolated research, repository exploration, or verbose analysis
whose raw output is not needed in the main context.

Do not use agent teams for normal implementation.

Before declaring work complete:

1. run the applicable formatter/linter,
2. run relevant tests,
3. run the required build,
4. inspect git diff,
5. update REQUIREMENTS_MATRIX.md when evidence changed,
6. update PROJECT_STATE.md,
7. update AI_USAGE.md if AI contributed a meaningful decision or implementation.

Never push, rewrite Git history, expose secrets, or change assessment requirements
without explicit approval.