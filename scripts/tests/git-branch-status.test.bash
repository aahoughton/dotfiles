#!/bin/bash
#
# Tests for git-branch-status, against a local bare repo standing in for
# origin, with a default branch other than main.
# Run from the chezmoi source dir: bash scripts/tests/git-branch-status.test.bash

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/bin/executable_git-branch-status"
# /bin/bash is the shebang's interpreter: 3.2 on macOS. The alarm keeps a
# regression that loops from hanging the test run.
gbs() { perl -e 'alarm 10; exec @ARGV' /bin/bash "$SRC" "$@"; }
failures=0

check() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$actual" == "$expected" ]]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name"
    echo "       expected: $expected"
    echo "       actual:   $actual"
    failures=$((failures + 1))
  fi
}

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t

# origin: default branch "trunk"; "feature" was squash-merged as PR #7.
git init -q -b trunk "$tmp/seed"
(
  cd "$tmp/seed"
  echo a >a && git add a && git commit -qm init
  git checkout -qb feature && echo b >b && git add b && git commit -qm "add b"
  git checkout -q trunk && git merge -q --squash feature >/dev/null && git commit -qm "add b (#7)"
)
git clone -q --bare "$tmp/seed" "$tmp/origin.git"
git clone -q "$tmp/origin.git" "$tmp/clone"
git -C "$tmp/clone" branch -q feature origin/feature

out=$(cd "$tmp/clone" && gbs 2>&1)

check "default branch read from origin/HEAD" \
  "* trunk" \
  "$(grep -o '^\* trunk' <<<"$out")"

check "squash merge found on the default branch" \
  "merged in #7" \
  "$(grep '^  feature' <<<"$out" | grep -o 'merged in #7')"

git -C "$tmp/clone" remote set-head origin --delete

check "missing origin/HEAD is an error" \
  "git-branch-status: origin/HEAD is not set; run: git remote set-head origin --auto
exit 1" \
  "$(cd "$tmp/clone" && gbs 2>&1; echo "exit $?")"

git -C "$tmp/clone" remote set-head origin trunk

check "-n without a value is an error, not a hang" \
  "git-branch-status: -n: option requires an argument
exit 2" \
  "$(cd "$tmp/clone" && gbs --no-fetch -n 2>&1; echo "exit $?")"

check "--depth=N is accepted" \
  "exit 0" \
  "$(cd "$tmp/clone" && gbs --no-fetch --depth=5 >/dev/null 2>&1; echo "exit $?")"

check "-nN is accepted" \
  "exit 0" \
  "$(cd "$tmp/clone" && gbs --no-fetch -n5 >/dev/null 2>&1; echo "exit $?")"

check "a non-numeric depth is an error" \
  "git-branch-status: depth must be a whole number, got: abc
exit 2" \
  "$(cd "$tmp/clone" && gbs --no-fetch -n abc 2>&1; echo "exit $?")"

mkdir "$tmp/plain"
check "outside a git repository" \
  "git-branch-status: not a git repository
exit 1" \
  "$(cd "$tmp/plain" && gbs --no-fetch 2>&1; echo "exit $?")"

# No origin at all: compare against the local main.
git init -q -b main "$tmp/local"
(
  cd "$tmp/local"
  git commit -q --allow-empty -m one
  git branch side
  git commit -q --allow-empty -m two
)
out=$(cd "$tmp/local" && gbs 2>&1; echo "exit $?")

check "no origin remote falls back to local main" \
  "exit 0" \
  "$(tail -n 1 <<<"$out")"

check "local-only branch checked against local main" \
  "merged into main (fast-forward)" \
  "$(grep '^  side' <<<"$out" | grep -o 'merged into main (fast-forward)')"

[[ $failures -eq 0 ]] && echo "all passed" || { echo "$failures failed"; exit 1; }
