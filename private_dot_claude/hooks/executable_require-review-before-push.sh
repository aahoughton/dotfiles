#!/usr/bin/env bash
#
# Block `git push` until the content it would publish has been recorded
# as reviewed.
#
# Reviews keep finding real defects in code that already passed its tests,
# and the failure is always the same: the author verifies the case they
# aimed at and misses the adjacent one. This turns "run a review first"
# from a habit into a gate.
#
# The gate sits at push rather than at commit. Three commits on one
# branch are one change to whoever reads the pull request, and reviewing
# each commit separately spent three reviews to answer one question,
# twice on intermediate states nobody would ever run. Push is also the
# first moment the shape is final.
#
# The marker is keyed to the exact content, so adding a commit and
# pushing again invalidates it and the gate asks again.
#
# Escape hatch: prefix the command with `env SKIP_REVIEW_GATE=1`, or set
# SKIP_REVIEW_GATE=1 in the environment this hook runs in. See the
# comment at the check itself for why both exist.

set -uo pipefail

input=$(cat)

cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null) || exit 0
case "$cmd" in
*"git push"*) ;;
*) exit 0 ;;
esac

# The escape hatch has to be readable from the command, not just from the
# environment. This hook denies the command, so the command never runs,
# so an env assignment on it never reaches any process: `env FOO=1 git
# push` sets FOO for a git that is never started. Env-only meant there
# was no working per-command hatch at all, and an agent that cannot skip
# a gate it has decided to skip will `touch` the marker instead. That is
# strictly worse: a touched marker is indistinguishable from a real
# review, while a bypass is visible in the command it is attached to.
#
# Matched only at the start of a command or straight after a `&&`, `||`
# or `;`, so the token appearing inside a commit message (a message about
# this hook, say) does not wave the push through.
if [[ $cmd =~ (^|(\&\&|\|\||\;)[[:space:]]*)env[[:space:]]+SKIP_REVIEW_GATE=1[[:space:]] ]]; then
  exit 0
fi

[ "${SKIP_REVIEW_GATE:-}" = "1" ] && exit 0

# Where the push will run. The hook's own working directory is the
# session's, which is not where the command runs when it changes
# directory first. A commit made from a worktree under `cd "$WT" && ...`
# went through this gate completely unexamined, because the session repo
# was clean and a clean repo has nothing to review.
session_cwd=$(printf '%s' "$input" | jq -r '.cwd // ""' 2>/dev/null) || session_cwd=""
[ -n "$session_cwd" ] || session_cwd=$PWD

# `cd <literal>` and `git -C <literal>` are resolvable. A path built from
# a variable is not, and that is the shape the worktree bypass had.
dir=$session_cwd
unresolved=0
if [[ $cmd =~ (^|[[:space:]&|\;])cd[[:space:]]+([^[:space:]\&\|\;]+) ]]; then
  target=${BASH_REMATCH[2]}
  target=${target%\"}
  target=${target#\"}
  target=${target%\'}
  target=${target#\'}
  case "$target" in
  *'$'* | *'`'*) unresolved=1 ;;
  /*) dir=$target ;;
  *) dir="$session_cwd/$target" ;;
  esac
fi
if [[ $cmd =~ git[[:space:]]+-C[[:space:]]+([^[:space:]]+) ]]; then
  target=${BASH_REMATCH[1]}
  case "$target" in
  *'$'* | *'`'*) unresolved=1 ;;
  /*) dir=$target ;;
  *) dir="$session_cwd/$target" ;;
  esac
fi
[ -d "$dir" ] || dir=$session_cwd

root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$root" ] || exit 0

# Candidate checkouts to examine. Normally exactly one: a push publishes
# the branch you are standing on, and an unrelated worktree's unpushed
# work is none of this push's business. When the command changed
# directory to somewhere this hook cannot resolve, every worktree of the
# repo is a candidate, because one of them is the real answer.
candidates=$root
if [ "$unresolved" = "1" ]; then
  others=$(git -C "$root" worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
  [ -n "$others" ] && candidates=$others
fi

dir_for_message=""
content=""
files=""

while IFS= read -r wt; do
  [ -n "$wt" ] || continue
  [ -d "$wt" ] || continue

  # What this push would publish: everything on HEAD that the branch's
  # upstream does not have. A branch with no upstream yet (the first
  # push of a feature branch) is measured against the remote's default
  # head instead, which is the base its pull request will use.
  base=$(git -C "$wt" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
  if [ -z "$base" ] || ! git -C "$wt" rev-parse --verify -q "$base" >/dev/null 2>&1; then
    base=$(git -C "$wt" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null)
    [ -n "$base" ] || base="origin/main"
  fi
  git -C "$wt" rev-parse --verify -q "$base" >/dev/null 2>&1 || continue

  merge_base=$(git -C "$wt" merge-base "$base" HEAD 2>/dev/null) || continue
  wt_content=$(git -C "$wt" diff "$merge_base" HEAD 2>/dev/null)

  # Nothing to publish: an already-pushed branch, a tag push, a delete.
  [ -n "$wt_content" ] || continue

  wt_hash=$(printf '%s' "$wt_content" | shasum -a 256 | cut -d' ' -f1)
  if [ -f "${HOME}/.claude/review-markers/$(basename "$root")-${wt_hash}" ]; then
    continue
  fi

  dir_for_message=$wt
  content=$wt_content
  files=$(git -C "$wt" diff "$merge_base" HEAD --name-only 2>/dev/null)
  break
done <<<"$candidates"

# Every candidate is either empty or already reviewed.
[ -n "$content" ] || exit 0

hash=$(printf '%s' "$content" | shasum -a 256 | cut -d' ' -f1)
dir_markers="${HOME}/.claude/review-markers"
marker="${dir_markers}/$(basename "$root")-${hash}"

# Scale the ask to the diff, in both directions.
#
# A dependency bump is the clearest case: a lockfile diff has no claims
# to check and no consumers to enumerate, the tool that wrote it is
# deterministic, and CI installs and runs the result. A review there
# produces paragraphs about version numbers nobody acts on.
#
# A consumer-and-path enumeration over a diff that changes no executable
# code is a subtler version of the same waste. Run once against two
# paragraphs of English, it dutifully enumerated every heading in the
# file and every file that mentioned it. What a prose diff can get wrong
# is its claims, so that is what to ask about.
lock_only=1
prose_only=1
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
  pnpm-lock.yaml | package-lock.json | yarn.lock | */pnpm-lock.yaml | */package-lock.json | */yarn.lock) ;;
  *)
    lock_only=0
    ;;
  esac
  case "$f" in
  *.md | *.markdown | *.txt | *.rst | *.adoc | LICENSE | */LICENSE) ;;
  *)
    prose_only=0
    ;;
  esac
done <<<"$files"

[ "$lock_only" = "1" ] && exit 0

changed_lines=$(printf '%s\n' "$content" | grep -c '^[+-][^+-]' || true)

if [ "$prose_only" = "1" ]; then
  ask="Ask it to check claims, not consumers. This diff changes no
executable code, so there are no consumers and no code paths to walk:
  - every factual claim the new prose makes, checked against the tree
  - anything the prose now contradicts elsewhere in the repo"
else
  ask="Ask it to enumerate rather than judge:
  - every consumer of every symbol this diff changes, checked one by one
  - every path through every function this diff changes"
  if [ "${changed_lines:-0}" -le 30 ]; then
    ask="${ask}

Changed lines: ${changed_lines}. Scope the review to the diff and its
immediate consumers; a repo-wide sweep on a diff this size costs more
than it has ever returned."
  fi
fi

reason="The changes this push would publish have not been reviewed.

Branch at: ${dir_for_message}

Run a review over those changes before pushing. Prefer a fresh-context
reviewer over a fork of this session: a fork inherits the reasoning that
produced the code, which is the thing most worth doubting.

${ask}

Then record it:

  mkdir -p '${dir_markers}' && touch '${marker}'

Record it as its own command, before the push rather than chained onto
it. This hook runs before the command it is inspecting, so a
\`touch marker && git push\` sees the state from before the touch and
denies anyway.

Use exactly that path. The hash is over the diff between this branch and
its base, which is what a reader of the pull request will see, not what
any one commit changed. Computing a hash separately and getting a
different answer means you hashed something else.

Three things about acting on what comes back, each of which has cost a
real session more than the defect did:

  - A finding against a comment is settled by DELETING the claim, not by
    rewriting it. A rewritten claim is a new unverified claim, and it
    arrives with the authority of having just survived a review. Three
    rounds of this in one session, each replacement false in a new way,
    ended when the claim was cut instead.
  - Run a second pass only if the first returned something blocking.
    Absent a stopping rule, \"the reviewer found something\" always
    argues for another round, and what it finds gets thinner each time
    while the odds of a self-inflicted finding do not.
  - A finding outside the diff is a decision, not an instruction. File
    it or defer it. Nothing in the loop will say \"that is out of
    scope\", so a two-line fix becomes a refactor one reasonable yes at
    a time.

The marker is keyed to that exact content, so another commit on this
branch asks again. To bypass for one command, prefix it:
\`env SKIP_REVIEW_GATE=1 git push ...\` (valid in fish and bash alike;
a bare \`VAR=1 cmd\` prefix is a syntax error in fish). Prefer that over
touching the marker without a review: the marker cannot tell the
difference, and a later reader deserves to see which happened."

jq -n --arg reason "$reason" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: $reason
  }
}'
exit 0
