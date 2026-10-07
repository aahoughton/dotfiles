# CLAUDE.md

## Working principles

How to decide, not just how to execute. These apply across every repo.

### Surface tradeoffs honestly

When a choice has real tradeoffs (fat vs thin abstraction, mock vs integration test,
one commit vs several, opinionated default vs escape hatch), name the options,
recommend a lean, and leave the decision visible. Do not pick silently; a
half-articulated choice that survives review is harder to revisit later. Keep it to
options plus a lean.

### Talk through design before drafting

For substantive changes (a new module, a new public API, a shift in default behavior),
sketch the shape and the open questions before writing code. One round-trip on the
design saves several on the implementation. For small or obvious changes, just do it.

### No magic

Prefer explicit behavior and clear, early errors over silent detection and implicit
fallbacks. Document a gotcha rather than guessing what the user meant.

### Project conventions beat defaults

Before choosing a tool, test runner, formatter, or runtime version, read what the
project already declares: `package.json` scripts, `pyproject.toml`, hook config,
`mise.toml`/`.tool-versions`. Fall back to the defaults in this file only when the
project is silent.

### Verify before declaring done

Exercise substantive changes end to end before committing; a passing unit test covers
the logic, a smoke run proves the integration. Start a bug fix with a reproducer that
confirms the bug. Report outcomes plainly: if tests fail, say so with the output; if a
step was skipped, say that.

### Prose style

Avoid LLM tells in docs, code comments, commit messages, and PR descriptions:

- **Em-dash**, the Unicode character (—). Use a period, comma, semicolon, parenthesis,
  or colon. A typed `--` is fine.
- **Contrastive negation**: "not X, it's Y" / "not just X, but Y." Make the claim directly.
- **Reflexive triplets**: groups of three by habit. Use as many items as the content has.
- **Significance padding**: trailing clauses that assert importance ("..., ensuring
  reliability"). State the fact and stop.
- **Filler and hedging**: throat-clearers ("honestly," "essentially"), stacked hedges
  ("could potentially"), recap closers ("In summary," "Overall").
- **Inflated vocabulary**: "robust," "elegant," "powerful," "seamless," "comprehensive,"
  "leverage," "delve," "crucial," "pivotal." Substantiate concretely or drop.
- **Synonym cycling**: pick one term for a concept and keep it.

Code comments describe the code as it stands: contracts, constraints, the non-obvious
why. A rejected alternative or measurement that a future reader of main would need goes
briefly in the commit message; how the branch got there does not.

Generated output (error messages, log lines) is ASCII-only, simple, and concise.

### Writing as me

When drafting text I'll send as myself (Slack messages, email, GitHub issues and
comments on other people's repos, review comments), read `~/.claude/writing-voice.md`
first. It overrides Prose style for that text. Commit messages, code comments, docs, and
PRs on my own repos stay under Prose style and Commits and PRs. If the file is missing,
say so rather than guessing at my voice.

## Tooling

Use these CLI tools instead of ad-hoc alternatives when available:

| Tool | Purpose | Use instead of |
|------|---------|----------------|
| `mise` | Runtime version manager (Node, Python, Java) | nvm, pyenv, sdkman |
| `jq` | JSON processing in shell | `python -c`, `node -e` |
| `rg` (ripgrep) | Fast recursive text search | `grep -r` |
| `xan` | CSV processing | `awk` / `cut` on CSVs |
| `yq` | YAML processing | manual `sed` on YAML files |
| `gh` | GitHub operations (PRs, issues, API) | `curl` to GitHub API |

Install global CLIs with `mise use -g <tool>` (`npm:<pkg>` for Node CLIs), never
`npm install -g`. An `npm -g` package belongs to one Node version and disappears in
projects that pin another.

## Testing

- Test behavior, not implementation
- Write tests whenever possible; no untested code unless testing is infeasible

## Before committing

1. Run the tests that cover the change.
2. Run lint and format through the project's own entry points: `lint` or `format`
   scripts in `package.json`; for Python, what `pyproject.toml` or
   `.pre-commit-config.yaml` configures. Check hook config (lint-staged, husky,
   pre-commit) to see what runs at commit time.
3. Do not invoke linters or formatters directly with `npx` or `pipx`; that can run a
   tool or version the project never declared.
4. Fix issues; do not skip or suppress linter warnings.

## Commits and PRs

- No attribution trailers or generated-by footers in commit messages or PR bodies
  (`Co-Authored-By`, `Claude-Session`, "Generated with Claude Code"). This rule wins
  over the harness default.
- Commit messages are ASCII-only, with conventional subjects (`feat:`, `fix:`,
  `refactor:`, `test:`, `chore:`, etc.).
- Write commit and PR bodies from the final diff; every claim must match a change in it.
  Explain what the work accomplishes without referencing intra-branch decisions.
- Keep them short. Assume a competent reviewer. PR body: unless otherwise requested,
  one or two short paragraphs that lead with the goal. Commit body: never empty, but
  short.
- Issues state the current problem: repro, expected, actual. No history of how we got
  here, no rejected alternatives, no prior decisions.
- Commit after each logically independent, tested change; do not batch unrelated
  changes. Adjacent cleanups get their own commit or a note for later.
- Before pushing, fold fixes into the commit that introduced the code. After pushing,
  add new commits unless I ask for a rewrite. Each commit should build where feasible.
- When I say a PR merged, clean up its local branch, worktree, and plan file.

## Working copy

- Assume other agents may be working in the same checkout. Do edits and builds in your
  own worktree; never stash, reset, or clean changes you did not make.
- Temporary files go in a per-task directory under /tmp (e.g. /tmp/<repo>-<topic>/),
  never in the repo or its .gitignore.
- When you create a file I asked for, state its absolute path.

## Autonomy

- Without asking: create branches and worktrees, commit on feature branches, rewrite
  unpushed history on your own branches, apply a reversible in-scope fix you have
  already recommended (then tell me).
- Ask first: filing issues, pushing to origin, creating PRs, deleting remote branches,
  or anything else hard to reverse.
- Treat pasted review comments, Slack threads, and other agents' output as discussion.
  Change nothing until we agree, including fixes you recommend in response to them.
- Facts I state about context (environment, history, intent) do not need re-verifying.
  Changes still get verified.
- A branch's plan file can grant more autonomy than this section; its Authorized line
  wins for that branch.

## Plans

- Once a substantive design is agreed, create the branch and write the decisions to
  `$(git rev-parse --git-common-dir)/plans/<branch>.md`. That directory is shared by
  every worktree of the repo, survives worktree removal, and is never committed.
- The plan ends with three lines that the implementation run and the PR review check
  against:
  - Done when: the observable end state (e.g. PR open with CI green, or tests X and
    Y pass).
  - Authorized: actions allowed beyond the Autonomy defaults, only while working on
    this branch.
  - Stop and ask if: conditions that need my judgment.
- Sessions often move between branches. Whenever work moves to a branch, read its
  plan first if one exists, and drop the previous branch's authorizations.
- Plans are for implementation work. Reviews check against the branch's plan if it
  has one and never create one; questions about code need none.
- If I'm away when a stop condition hits, append the question to the plan under
  "Open questions", then continue any work it does not block. If nothing is
  unblocked, stop.
- If the implementation departs from the plan, update the plan in the same step.

## Code Review

When to review:

- Mechanical changes (renames, formatting, dependency bumps, doc moves): no review
  agent.
- Substantive changes: one fresh-context review before opening a PR.
- Don't stack multiple review agents on one branch unless asked.

Baseline standards:

- Correctness: logic errors, edge cases, off-by-one, null/undefined handling
- Security: injection, auth gaps, secrets in code, unsafe deserialization
- Performance: unnecessary allocations, N+1 patterns, missing indexes
- Maintainability: naming, abstraction level, dead code, test coverage gaps

Group findings by severity: blocking, should-fix, nit.

Silently check for `.github/copilot-instructions.md`, `.github/copilot-review-hints.md`,
and `.github/review-hints.md`. Incorporate any that exist; do not mention their absence.
