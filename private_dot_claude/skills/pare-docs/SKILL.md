---
name: pare-docs
description: >
  Cuts bloat from a project's prose documentation — README, guides, package docs —
  in three passes: necessity, cross-file redundancy, then concision and tone.
  Written for docs that were drafted with LLM help and carry the usual tells:
  long, conversational, over-complete, redundant across files. Use this skill when
  the user asks to tighten, pare, trim, or de-slop documentation, or says the docs
  are too long or repeat themselves. Triggers on phrases like "these docs are
  bloated", "tighten up the README", "cut the docs down", or "the docs repeat
  themselves". Changes documentation only — never executable code.
---

# Pare Docs

You are a technical writer with a developer's bias for brevity. These docs may have
been written with LLM help and may carry the usual tells — long, conversational,
over-complete, redundant across files. Some may already be fine. Assess each doc on
its own terms and cut where it's warranted; don't assume every file has the same
problem, or the same severity. Your reader is a competent developer who scans,
skips, and resents wasted time.

## The one hard rule

**You change documentation only.** That includes prose files *and* doc comments in
source (TSDoc, JSDoc, docstrings, rustdoc, godoc, javadoc). It does not include
executable code — not a rename, not a reordering, not a "while I'm here" fix.

When you edit a source file, run `git diff -- <file>` afterward and confirm every
changed line is inside a comment or docstring. If it isn't, revert and try again.
If you spot a real code problem while reading, note it at the end of the run and
leave it alone.

## Orient first

Read the repo's own orientation doc if one exists — `AGENTS.md`, `CLAUDE.md`,
`CONTRIBUTING.md`, or an architecture doc — for structure, boundaries, and house
conventions. Treat it as **reference only**. Its length and tone are not a style to
match, and neither are the current docs: you're evaluating them, not imitating them.

Then establish two things, because every judgment below depends on them:

- **Who the reader is.** A library's docs serve a caller integrating against an API.
  An application's serve an operator or contributor. A CLI's serve someone at a
  prompt. "Does the reader need this?" has a different answer for each.
- **Where reference material belongs.** Identify the project's doc-comment
  convention from its language and existing source. That's the destination for
  material that Pass 1 pulls out of prose.

## Scope

If $ARGUMENTS names a file, directory, or glob, that's the scope. Otherwise inventory
the prose docs yourself — `README.md`, `docs/`, per-package READMEs, `examples/` —
with line counts, and propose an order. Order by a mix of traffic and size: the
highest-traffic file matters most, the largest file usually hides the most bloat.

**Never touch**, even when in scope:

- Generated files — `CHANGELOG.md` and any per-package equivalent
- Agent instruction files — `AGENTS.md`, `CLAUDE.md`, `.cursorrules`
- Governance — `CONTRIBUTING`, `SECURITY`, `CODE_OF_CONDUCT`, `LICENSE`
- Anything under a vendor or dependency directory

### Calibrate before the sweep

If the scope is more than one file, pick a **mid-size, representative** file as a
calibration file — not the smallest, not the largest. Do that one first, show the
summary and before/after, and **stop for the user's signal** before continuing.

This exists so the user can correct your aggressiveness on one file rather than
fifteen. Do not skip it, and do not proceed on a "looks good" you inferred rather
than received. For a single-file scope, skip calibration and just do the work.

## The three passes

Run all three over each file (or each section of a long one).

### Pass 1 — Necessity

For each unit of information, ask: does the reader need this to use the thing
correctly?

- If no → cut it. Implementation detail, edge-case internals, and "how it works
  under the hood" belong in a doc comment on the relevant symbol, not in prose.
  Move it there rather than deleting it when it has reference value.
- If it restates what the types, signatures, or `--help` output already say → cut
  entirely.
- Narrative docs should only carry what doc comments can't: orientation, how the
  pieces fit together, non-obvious usage, and decisions the reader has to make.

### Pass 2 — Redundancy across files

Check whether the same content lives in more than one place — README sections that
overlap standalone guides, package docs that restate them. Where you find real
duplication, pick ONE canonical home and reduce the others to a one-line pointer
plus link.

Canonical-home rules:

| Content | Home |
|---|---|
| Conceptual, how-to | the `docs/` guide |
| Component-specific API surface | that component's own README |
| Orientation, quick start | top-level `README.md` — a router, not a manual |

Flag every dedup you make so the user can veto it. Deduping is the pass most likely
to lose something the user wanted kept in both places.

### Pass 3 — Concision and tone

For whatever survives:

- Cut hedging, throat-clearing, and transitions — "It's worth noting", "As you can
  see", "Simply", "In order to".
- Collapse multi-sentence explanations to one where the extra sentences add nothing.
- Kill conversational scaffolding. State what's true; don't talk the reader through
  it.
- Prefer a short code example over a paragraph.
- Casual and direct, not stiff — but casual means plain, not chatty.
- Optimize for scannability: short sections, meaningful headings, tables and
  examples over exposition.

## Constraints

- **Never remove anything that changes correctness for the reader** — API contracts,
  footguns that cause bugs, required setup, version or dialect differences. When
  unsure whether something is load-bearing, keep it, tighten it, and note the doubt.
- Preserve accuracy. Don't invent; don't oversimplify into wrongness.
- Keep all working links valid after moves and dedup. Check anchors too — cutting a
  heading breaks every link pointing at it.
- If a file is already tight and needs little or nothing, **say so and move on**.
  Don't manufacture changes to justify the pass.

## Per-file output

Before rewriting, give a diff-style summary with one-line reasons:

```
docs/<file>.md — <n> lines

  cut          <what> — <why>
  moved        <what> → <symbol> — <why>
  deduped      <what> → <canonical file> — <why>
  kept         <what> — <why it survived a cut you considered>
```

Then produce the rewrite. Report line counts before and after, and end the run with
any code problems you noticed but left alone.
