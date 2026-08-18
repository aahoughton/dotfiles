#!/usr/bin/env bash
#
# Block `git commit` until the staged diff has been recorded as reviewed.
#
# Reviews keep finding real defects in code that already passed its tests,
# and the failure is always the same: the author verifies the case they
# aimed at and misses the adjacent one. This turns "run a review first"
# from a habit into a gate.
#
# The marker is keyed to the exact staged diff, so restaging different
# content invalidates it and the gate asks again.
#
# Escape hatch: SKIP_REVIEW_GATE=1 in the environment.

set -uo pipefail

input=$(cat)

# Only commits are our business. Matched on substring rather than a
# prefix rule, because the common shape here is
# `git add -A && git commit -F - <<EOF`, which no prefix matches.
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null) || exit 0
case "$cmd" in
*"git commit"*) ;;
*) exit 0 ;;
esac

[ "${SKIP_REVIEW_GATE:-}" = "1" ] && exit 0

# Not a repo: nothing to gate, and git will produce its own error.
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$root" ] || exit 0

# Nothing staged: an empty commit, an `--amend --no-edit`, or a mistake.
# Whichever it is, there is no new content to have reviewed.
staged=$(git diff --cached 2>/dev/null)
[ -n "$staged" ] || exit 0

hash=$(printf '%s' "$staged" | shasum -a 256 | cut -d' ' -f1)
dir="${HOME}/.claude/review-markers"
marker="${dir}/$(basename "$root")-${hash}"

[ -f "$marker" ] && exit 0

reason="Staged changes have not been reviewed.

Run a review over the staged diff before committing. Prefer a
fresh-context reviewer over a fork of this session: a fork inherits the
reasoning that produced the code, which is the thing most worth doubting.

Ask it to enumerate rather than judge:
  - every consumer of every symbol this diff changes, checked one by one
  - every path through every function this diff changes

Then record it:

  mkdir -p '${dir}' && touch '${marker}'

The marker is keyed to this exact staged diff, so changing what is staged
asks again. SKIP_REVIEW_GATE=1 bypasses the gate for one command."

jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
