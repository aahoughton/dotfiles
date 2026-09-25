#!/bin/bash
#
# Tests for psql2csv, using --dry-run so no database is needed.
# Run from the chezmoi source dir: bash scripts/tests/psql2csv.test.bash

set -uo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/bin/executable_psql2csv"
psql2csv() { bash "$SRC" "$@"; }
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

# Run psql2csv with stdin held open but never written to, like an agent or CI
# runner's stdin. Fails (prints TIMEOUT) if it doesn't exit within 3 seconds.
run_with_idle_stdin() {
  local dir fifo out pid
  dir=$(mktemp -d)
  fifo="$dir/stdin"
  out="$dir/out"
  mkfifo "$fifo"
  exec 3<>"$fifo"
  psql2csv "$@" <"$fifo" >"$out" 2>&1 &
  pid=$!
  for _ in $(seq 30); do
    kill -0 "$pid" 2>/dev/null || break
    sleep 0.1
  done
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid"
    echo TIMEOUT
  else
    cat "$out"
  fi
  exec 3>&-
  rm -rf "$dir"
}

check "query argument, stdin is /dev/null" \
  "COPY (SELECT 1) TO STDOUT WITH (FORMAT csv, HEADER)" \
  "$(psql2csv --dry-run "SELECT 1" </dev/null)"

check "query from piped stdin" \
  "COPY (SELECT 2) TO STDOUT WITH (FORMAT csv, HEADER)" \
  "$(echo "SELECT 2" | psql2csv --dry-run)"

check "database argument plus query on stdin" \
  "COPY (SELECT 3) TO STDOUT WITH (FORMAT csv, HEADER)" \
  "$(echo "SELECT 3" | psql2csv --dry-run mydb)"

check "trailing semicolon stripped, --no-header" \
  "COPY (SELECT 4) TO STDOUT WITH (FORMAT csv)" \
  "$(psql2csv --dry-run --no-header "SELECT 4;" </dev/null)"

check "query argument with idle open stdin does not hang" \
  "COPY (SELECT 5) TO STDOUT WITH (FORMAT csv, HEADER)" \
  "$(run_with_idle_stdin --dry-run mydb "SELECT 5")"

check "whitespace-free query argument with idle open stdin does not hang" \
  "COPY (select*from t) TO STDOUT WITH (FORMAT csv, HEADER)" \
  "$(run_with_idle_stdin --dry-run "select*from t")"

check "missing query is an error" \
  "psql2csv: missing query (pass as last argument or via stdin)" \
  "$(psql2csv --dry-run </dev/null 2>&1)"

# The real (non-dry-run) path, under /bin/bash -- the shebang's interpreter,
# 3.2 on macOS -- with a stub psql that echoes its arguments and stdin.
# Bash 3.2 treats an empty array as unbound under set -u, so a query with no
# other psql arguments used to fail here.
stub_dir=$(mktemp -d)
printf '#!/bin/sh\necho "args: $*"; cat\n' >"$stub_dir/psql"
chmod +x "$stub_dir/psql"

check "query with no other psql arguments, under /bin/bash" \
  "args: --no-psqlrc --quiet
COPY (SELECT 6) TO STDOUT WITH (FORMAT csv, HEADER)" \
  "$(PATH="$stub_dir:$PATH" /bin/bash "$SRC" "SELECT 6" </dev/null 2>&1)"

check "psql arguments forwarded, under /bin/bash" \
  "args: --no-psqlrc --quiet -h localhost mydb
COPY (SELECT 7) TO STDOUT WITH (FORMAT csv, HEADER)" \
  "$(PATH="$stub_dir:$PATH" /bin/bash "$SRC" -h localhost mydb "SELECT 7" </dev/null 2>&1)"

rm -rf "$stub_dir"

[[ $failures -eq 0 ]] && echo "all passed" || { echo "$failures failed"; exit 1; }
