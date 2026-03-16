# Charitable Interpretation

Architectural review agents must apply charitable interpretation before flagging
anything as a problem. This is not about being lenient — it's about producing
findings that are actually actionable and credible.

## The principle

Before flagging a pattern as a problem, ask: **is there a plausible, legitimate
reason this exists?**

If the answer is yes, note the potential justification in your finding and adjust
severity accordingly. If the evidence strongly suggests it's intentional and well-
reasoned, move it to the "Noted / Intentional" section rather than the issue list.

## Patterns that are often justified

**Denormalized databases**
- Optimizing hot read paths
- Simplifying reporting queries
- Reducing joins in latency-sensitive paths
- Supporting event-sourced projections
- Avoiding ORM join complexity

**"God objects" or large classes**
- Façade over a complex subsystem
- Orchestrator in a workflow with explicit ownership
- Accumulation point during an in-progress decomposition

**Tight coupling between specific modules**
- Two modules that always change together (coupling reflects domain reality)
- Performance-critical paths where indirection is too expensive
- Intentional monolith boundary while scaling

**Missing abstractions / "naive" implementations**
- Early-stage project where premature abstraction would be waste
- Domain that hasn't stabilized yet
- Simple CRUD where an abstraction layer adds no value

**Duplicated code**
- Duplication that evolved from similar-but-different domains
- Intentional divergence (shared abstraction would create coupling)
- Copied to avoid a dependency on a shared module

**Mixed patterns / inconsistency**
- Active migration from old to new approach
- Parts of the codebase with different age/maturity
- Third-party integration forcing different patterns

**Heavy test mocking**
- Legacy code being retrofitted with tests under constraints
- External services with no in-memory fake

## How to apply this

1. Find the pattern
2. Look for evidence: comments, ADRs, docs, commit history references, naming
   that suggests awareness
3. If evidence exists: note it in the finding, reduce severity, or move to
   "Noted / Intentional"
4. If no evidence exists but the pattern is plausible: still flag it, but frame
   as "consider whether this is intentional" rather than "this is wrong"
5. If the pattern is incoherent with the rest of the codebase: flag it normally

## What this is NOT

This is not a reason to suppress all findings. A denormalized table that makes
sense for reporting is fine; a denormalized table that exists because the schema
was never thought through is a real problem. The difference is usually visible
in the surrounding code and documentation.

The goal is findings the team will actually act on, not a list of everything
that doesn't match a textbook.
