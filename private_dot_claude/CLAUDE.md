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
why. History, rejected alternatives, and measurements go in the commit message.

Generated output (error messages, log lines) is ASCII-only, simple, and concise.

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
- Commit after each logically independent, tested change; do not batch unrelated
  changes. Adjacent cleanups get their own commit or a note for later.
- Commit freely on feature branches; push only when asked.

## Code Review

Baseline standards:

- Correctness: logic errors, edge cases, off-by-one, null/undefined handling
- Security: injection, auth gaps, secrets in code, unsafe deserialization
- Performance: unnecessary allocations, N+1 patterns, missing indexes
- Maintainability: naming, abstraction level, dead code, test coverage gaps

Group findings by severity: blocking, should-fix, nit.

Silently check for `.github/copilot-instructions.md`, `.github/copilot-review-hints.md`,
and `.github/review-hints.md`. Incorporate any that exist; do not mention their absence.
