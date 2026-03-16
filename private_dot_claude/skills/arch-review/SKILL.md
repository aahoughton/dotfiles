---
name: arch-review
description: >
  Performs a deep architectural review of a codebase, evaluating composability,
  testability, and structural design. Use this skill when the user asks to review
  a repo, audit architecture, find structural issues, assess code quality at a
  system level, or evaluate design decisions. Triggers on phrases like "review
  the architecture", "audit this codebase", "what's wrong with this repo",
  "assess the design", or "what would be hard to change here". Spawns three
  parallel specialist agents and returns a single prioritized issue list.
---

# Architectural Review

You are orchestrating a senior-level architectural review. Three specialists analyze
the repo in parallel, each with a narrow mandate. You synthesize their findings into
a single prioritized issue list.

## Orientation (do this first)

Before spawning agents, spend 2–3 minutes orienting yourself. Use bash/grep/ls to:

1. Identify the project type (web app, library, service, monorepo, etc.)
2. Identify the primary language(s) and frameworks
3. Find the test directory structure
4. Note any README, ADR, or docs that explain design decisions
5. Check for unusual patterns at a glance (e.g., no tests, multiple ORM layers, circular imports)

This context shapes how specialists interpret what they find. Pass it to them.

## Agent Dispatch

Spawn these three agents **in parallel**, providing each with:
- The repo root path
- Your orientation summary
- Their specific mandate (from `agents/` below)

Agents:
- `agents/composability.md` — module boundaries, coupling, dependency management
- `agents/testability.md` — seam design, test isolation, coverage patterns
- `agents/design.md` — data models, abstractions, naming, structural patterns

Read those files before dispatching so you can give agents accurate framing.

## Synthesis

Each agent returns findings with severity and justification. Your job:

1. **De-duplicate**: If two agents flag the same root cause, merge into one issue.
2. **Promote context**: If the orientation phase found a design doc explaining a
   pattern, note that in the relevant issue — it may reduce severity or explain intent.
3. **Apply the charitable interpretation rule** (see `references/charitable-interpretation.md`).
4. **Rank** using the criteria in `references/issue-format.md`.
5. Emit the final report.

## Output Format

Read `references/issue-format.md` for the exact output structure. In brief:

```
## P1 – Critical (fix before adding features)
## P2 – Significant (fix on next major refactor)
## P3 – Suggestions (worth doing, low urgency)
## Noted / Intentional (patterns that look like smells but appear justified)
```

Do not pad the report. If there are zero P1 issues, say so. If a concern is
genuinely unclear without more context, say so and explain what you'd need to know.
