---
name: arch-review
description: >
  Performs a deep architectural review of an entire codebase as it currently
  stands, evaluating composability, testability, and structural design. Use this
  skill when the user asks to audit architecture, find structural issues, assess
  code quality at a system level, or evaluate design decisions. Triggers on
  phrases like "review the architecture", "audit this codebase", "what's wrong
  with this repo", "assess the design", or "what would be hard to change here".
  Reviews the whole repo, not a diff; for reviewing the changes on a branch
  before merging, use branch-review instead. Returns a single prioritized issue
  list. Pass a subdirectory to limit the review to it on large repos.
---

# Architectural Review

You are orchestrating a senior-level architectural review. Three specialists analyze
the repo in parallel, each with a narrow mandate. You synthesize their findings into
a single prioritized issue list.

## Scope

If the invocation names a directory ($ARGUMENTS), review only that subtree;
orientation still reads the repo root for context. Otherwise review the whole
repo. Pass the scope to every agent.

## Orientation (do this first)

Before spawning agents, orient yourself. Keep it short: read the README and the
top-level manifests (`package.json`, `pyproject.toml`, `go.mod`, etc.), list the
top two directory levels, and skim any ADR or design docs. Use bash/grep/ls to:

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
- `agents/composability.md`: module boundaries, coupling, dependency management
- `agents/testability.md`: seam design, test isolation, coverage patterns
- `agents/design.md`: data models, abstractions, naming, structural patterns

Read those files before dispatching so you can give agents accurate framing.

If you cannot spawn agents, work through the three mandates yourself, one after
another, and keep each pass's findings separate until synthesis.

## Synthesis

Each agent returns findings with severity and justification. Your job:

1. **Check evidence**: Every finding must cite a `path:line` the agent read.
   Open the cited lines for each P1 and P2 and confirm they show the pattern
   described. Demote or drop findings that don't hold up; move findings with no
   citation to "Out of scope / needs more context".
2. **De-duplicate**: If two agents flag the same root cause, merge into one issue.
3. **Promote context**: If the orientation phase found a design doc explaining a
   pattern, note that in the relevant issue; it may reduce severity or explain intent.
4. **Apply the charitable interpretation rule** (see `references/charitable-interpretation.md`).
5. **Rank** using the criteria in `references/issue-format.md`.
6. Emit the final report.

## Output Format

Read `references/issue-format.md` for the exact output structure. In brief:

```
## P1 - Critical (fix before adding features)
## P2 - Significant (fix on next major refactor)
## P3 - Suggestions (worth doing, low urgency)
## Noted / Intentional (patterns that look like smells but appear justified)
```

Do not pad the report. If there are zero P1 issues, say so. If a concern is
genuinely unclear without more context, say so and explain what you'd need to know.
