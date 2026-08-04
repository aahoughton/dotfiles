---
name: branch-review
description: >
  Pre-merge checks on the current branch that complement a code review rather
  than repeat one: repo-specific review guidance, CODEOWNERS, the project's own
  lint/typecheck, and new TODO/FIXME markers. Use this skill when the user asks
  what else to check before merging, asks about reviewers or owners for their
  changes, or wants the project's own checks run against the branch. Triggers on
  phrases like "anything else before I merge", "who needs to review this", "run
  the checks on this branch", or "am I clear to merge". Does NOT judge
  correctness or code quality — /code-review does that, and /arch-review audits
  whole-repo structure.
---

# Branch Pre-Merge Checks

This skill is **strictly additive on top of `/code-review`**. That built-in already
reads the diff, judges correctness and quality, and verifies its findings before
reporting. Do not redo any of it.

**Explicit non-goals.** Do not look for bugs, logic errors, or security issues. Do
not assess naming, style, or whether the code follows surrounding conventions. Do
not evaluate test quality. If you notice something in one of those categories, do
not report it here — say once, at the end, that `/code-review` would cover it.

What this skill does is the mechanical, checkable work that a reviewing model
skips: running the project's own tooling and consulting the repo's own metadata.

## Setup

Take the base branch from $ARGUMENTS, or use `main` if that is empty. Confirm it
exists (`git rev-parse --verify <base>`); if not, say so and stop.

Get the changed paths once and reuse them throughout:

```
git diff --name-only <base>...HEAD
```

If the diff is empty, say so and stop — there is nothing to check.

## Checks

**1. Repo-specific review guidance.** Look for `.github/copilot-instructions.md`,
`.github/copilot-review-hints.md`, `.github/review-hints.md`, `CLAUDE.md`, and
`.claude/CLAUDE.md`. Read any that exist. Report only the rules that are *relevant
to the changed paths*, and check the diff against those rules specifically — this
is guidance a generic review would not know about. Quote the rule when you flag a
violation. If no such files exist, say so in one line; it is useful to know none
are configured.

**2. CODEOWNERS.** If `CODEOWNERS` exists (repo root, `.github/`, or `docs/`), map
each changed path to its owning entries and list the distinct owners whose approval
the change will need. Note any changed path that matches no rule.

**3. Lint and typecheck.** Identify the project's own entrypoint from its config
rather than guessing — `package.json` scripts, `Makefile` targets, `justfile`,
`pyproject.toml`, `Cargo.toml`. Run it. Redirect output to a file in the scratchpad
directory and grep that file for the changed paths rather than reading it whole;
these commands can produce thousands of lines.

Report violations **in changed files only**. Pre-existing violations elsewhere are
noise. If the command fails to run at all (missing deps, no such target), report
that as its own finding — an unrunnable lint setup is worth knowing about — and do
not treat it as a clean pass. If the project has no such entrypoint, say so.

**4. New TODO/FIXME/HACK markers.** Search added lines only, so existing markers
are not re-reported:

```
git diff <base>...HEAD | grep -n '^+' | grep -E 'TODO|FIXME|HACK|XXX'
```

Report each with its file and the surrounding intent.

## Output

Report only checks that produced something, plus a one-line summary of those that
came back clean. Keep it compact — this is a checklist result, not a review.

```
## Owners
[Distinct owners needed, or "no CODEOWNERS".]

## Repo guidance
[Violations of repo-specific rules, quoting the rule. Or "no guidance files found".]

## Lint / typecheck
[New violations in changed files, or "clean", or "could not run: <reason>".]

## Markers
[TODO/FIXME/HACK added in this diff, or omit this section.]
```

End by noting whether `/code-review` has been run on this branch yet, and
recommend it if not — these checks do not substitute for it.
