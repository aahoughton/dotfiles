#!/usr/bin/env bash
#
# Block `git commit` until the content it would commit has been recorded
# as reviewed.
#
# Reviews keep finding real defects in code that already passed its tests,
# and the failure is always the same: the author verifies the case they
# aimed at and misses the adjacent one. This turns "run a review first"
# from a habit into a gate.
#
# The marker is keyed to the exact content, so changing what would be
# committed invalidates it and the gate asks again.
#
# Escape hatch: prefix the command with `env SKIP_REVIEW_GATE=1`, or set
# SKIP_REVIEW_GATE=1 in the environment this hook runs in. See the
# comment at the check itself for why both exist.

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

# The escape hatch has to be readable from the command, not just from the
# environment. This hook denies the command, so the command never runs,
# so an env assignment on it never reaches any process: `env FOO=1 git
# commit` sets FOO for a git that is never started. Env-only meant there
# was no working per-command hatch at all, and an agent that cannot skip
# a gate it has decided to skip will `touch` the marker instead. That is
# strictly worse: a touched marker is indistinguishable from a real
# review, while a bypass is visible in the command it is attached to.
#
# Matched only at the start of a command or straight after a `&&`, `||`
# or `;`, so the token appearing inside a commit message (a message about
# this hook, say) does not wave the commit through.
if [[ $cmd =~ (^|(\&\&|\|\||\;)[[:space:]]*)env[[:space:]]+SKIP_REVIEW_GATE=1[[:space:]] ]]; then
  exit 0
fi
[ "${SKIP_REVIEW_GATE:-}" = "1" ] && exit 0

# Not a repo: nothing to gate, and git will produce its own error.
root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -n "$root" ] || exit 0

# This hook runs BEFORE the command does, so the index it can see is the
# index as of now. When the command stages its own content first, the
# index is still empty at this point and reading it would wave the whole
# commit through. That is not hypothetical: `git add -A && git commit`
# is the shape the matcher above was written for, and it bypassed this
# gate completely until the check below existed.
#
# So when the command will stage for itself, review what the commit
# would contain rather than what is staged right now.
stages_tracked=0
stages_untracked=0

# An explicit `git add` can bring in files git has never seen.
case "$cmd" in
*"git add"* | *"git stage"*)
  stages_tracked=1
  stages_untracked=1
  ;;
esac

# `-a` / `--all` on the commit stages every tracked change without a
# separate `git add`, and deliberately does not touch untracked files.
# Matched as a flag token rather than a substring: `git commit -m
# "banana"` contains "-m \"b...a..." and a looser pattern reads that as
# `-a`, which would silently widen every ordinary commit.
if [[ " $cmd" =~ [[:space:]]--all([[:space:]]|$) ]] ||
  [[ " $cmd" =~ [[:space:]]-[a-zA-Z]*a[a-zA-Z]*([[:space:]]|$) ]]; then
  stages_tracked=1
fi

if [ "$stages_tracked" = "1" ]; then
  # Tracked modifications and deletions, plus (only where the command
  # stages untracked files too) the content of every
  # untracked-but-not-ignored file, which a diff against HEAD cannot
  # see.
  content=$(
    git diff HEAD 2>/dev/null
    if [ "$stages_untracked" = "1" ]; then
      git ls-files --others --exclude-standard 2>/dev/null | LC_ALL=C sort |
        while IFS= read -r f; do
          printf '=== new file: %s\n' "$f"
          cat -- "$f" 2>/dev/null
        done
    fi
  )
  files=$(
    git diff HEAD --name-only 2>/dev/null
    if [ "$stages_untracked" = "1" ]; then
      git ls-files --others --exclude-standard 2>/dev/null
    fi
  )
  subject="The changes this commit would include have not been reviewed."
else
  content=$(git diff --cached 2>/dev/null)
  files=$(git diff --cached --name-only 2>/dev/null)
  subject="Staged changes have not been reviewed."
fi

# Nothing to commit: an empty commit, an `--amend --no-edit`, or a
# mistake. Whichever it is, there is no new content to have reviewed.
[ -n "$content" ] || exit 0

hash=$(printf '%s' "$content" | shasum -a 256 | cut -d' ' -f1)
dir="${HOME}/.claude/review-markers"
marker="${dir}/$(basename "$root")-${hash}"

[ -f "$marker" ] && exit 0

# Scale the ask to the diff. A consumer-and-path enumeration over a diff
# that changes no executable code is a lot of work for a question the
# diff cannot answer wrongly: there are no consumers and no paths. Run
# once against two paragraphs of English, it dutifully enumerated every
# heading in the file and every file that mentioned it. What a prose diff
# can get wrong is its claims, so that is what to ask about.
prose_only=1
while IFS= read -r f; do
  [ -n "$f" ] || continue
  case "$f" in
  *.md | *.markdown | *.txt | *.rst | *.adoc | LICENSE | */LICENSE) ;;
  *)
    prose_only=0
    break
    ;;
  esac
done <<<"$files"

if [ "$prose_only" = "1" ]; then
  ask="Ask it to check claims, not consumers. This diff changes no
executable code, so there are no consumers and no code paths to walk:
  - every factual claim the new prose makes, checked against the tree
  - anything the prose now contradicts elsewhere in the repo"
else
  ask="Ask it to enumerate rather than judge:
  - every consumer of every symbol this diff changes, checked one by one
  - every path through every function this diff changes"
fi

reason="${subject}

Run a review over those changes before committing. Prefer a
fresh-context reviewer over a fork of this session: a fork inherits the
reasoning that produced the code, which is the thing most worth doubting.

${ask}

Then record it:

  mkdir -p '${dir}' && touch '${marker}'

Record it as its own command, before the commit rather than chained onto
it. This hook runs before the command it is inspecting, so a
\`touch marker && git commit\` sees the state from before the touch and
denies anyway.

Use exactly that path. The hash is over the content this hook read,
which is not always what \`git diff --cached\` prints: when the command
stages for itself, the gate reads what the commit would contain.
Computing a hash separately and getting a different answer means you
hashed something else.

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

The marker is keyed to that exact content, so changing what would be
committed asks again. To bypass for one command, prefix it:
\`env SKIP_REVIEW_GATE=1 git commit ...\` (valid in fish and bash alike;
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
