# Issue Format and Prioritization

## Severity tiers

### P1 – Critical
Fix before adding significant new features.

Criteria (any one is sufficient):
- Blocks independent team development (everything touches one file)
- Business logic is untestable without running the full application
- Data model problem that will require multi-file migrations or broad refactors to fix
- Fundamental mismatch between the domain and the code structure that is actively
  causing bugs or slowing every feature

### P2 – Significant
Fix on the next major refactor or before the next growth phase.

Criteria:
- Creates consistent friction in development (not blocking, but slowing)
- Integration tests doing work that unit tests could do, due to structural issues
- Abstraction quality problems that complicate onboarding and reasoning
- Coupling that will require broad changes when requirements shift (and they will)

### P3 – Suggestions
Worth doing, low urgency.

Criteria:
- Naming or consistency issues that erode slowly
- Patterns that work but are non-idiomatic for the stack
- Opportunities to reduce cognitive load

### Noted / Intentional
Patterns that look like antipatterns but appear to be deliberate, justified choices.

Include these because:
- It confirms the reviewer saw them (not just missed them)
- It documents the reasoning for future reviewers
- If the reasoning is wrong, the team can now correct it explicitly

## Issue format

Each issue entry:

```
### [Title — specific, not generic]

**Location**: `path/to/file.ext` (line range if applicable)

**Pattern**: What the code does.

**Consequence**: Why this matters architecturally. Be specific about what future
work it complicates or what class of bugs it invites. Do not invent consequences;
only name ones you can trace to the actual code.

**Justification check**: What would make this OK? Did you find any evidence of
that justification? (If you found evidence, this item probably belongs in Noted/Intentional.)

**Recommendation**: What to do. Keep this architectural, not implementation-level.
("Introduce a seam between the business logic and the HTTP layer" not "extract method on line 47.")
```

## Anti-patterns in issue writing

**Do not**:
- Quantify improvements you cannot know ("this will reduce build time by 30%")
- Flag things that are fine ("uses a class instead of a function")
- Flag things that belong in a code review, not an arch review ("this function
  is too long")
- Repeat the same root cause as multiple issues — find the root and say it once
- Use severity P1 for everything (it loses meaning)
- List issues without recommendations

**Do**:
- Use specific file paths
- Trace the consequence to a real outcome
- Acknowledge when you're uncertain
- Group related findings if they share a root cause

## Report skeleton

```markdown
# Architectural Review: [Project Name]

## Context

[2–3 sentences on project type, stack, and anything from orientation that
 shapes the findings below.]

## P1 – Critical

[Issues or "None identified."]

## P2 – Significant

[Issues or "None identified."]

## P3 – Suggestions

[Issues or "None identified."]

## Noted / Intentional

[Patterns that look like problems but appear deliberate.]

## Out of scope / needs more context

[Anything you couldn't assess without more information, and what you'd
 need to assess it.]
```
