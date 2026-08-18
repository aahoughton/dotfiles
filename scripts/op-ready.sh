#!/bin/sh
# Answer "can `op` authenticate right now?" without ever blocking the caller.
#
# `.chezmoiignore` gates the 1Password-backed files on this answer. It used to
# ask by running `op whoami` inline with no bound. On a machine where the
# 1Password desktop app is prompting for approval that nobody is looking at, a
# remote session or a headless box, that call never returns: every chezmoi
# command hangs with no output, and `--debug` stops after reading
# `.chezmoiignore` with no indication that a subprocess is waiting.
#
# The `|| echo notready` guard in the old form catches a non-zero exit, which
# is a different failure from never exiting at all.
#
# Two changes. The call is bounded, so a machine that cannot reach 1Password
# degrades to the same "skip the secret files" path a fresh machine takes. And
# a wait long enough to look like a hang says what it is waiting for.
#
# Prints exactly `ready` or `notready` on stdout. Everything explanatory goes
# to stderr, so the template only ever sees the verdict.

set -u

timeout=${CHEZMOI_OP_TIMEOUT:-15}
notice_after=${CHEZMOI_OP_NOTICE_AFTER:-3}

command -v op >/dev/null 2>&1 || {
    echo notready
    exit 0
}

# Only speak up when the call is slow enough to be mistaken for a hang, so the
# common authenticated case stays silent.
(
    sleep "$notice_after"
    printf 'chezmoi: waiting on 1Password (op whoami). Approve the prompt in the desktop app; giving up after %ss and skipping 1Password-backed files.\n' "$timeout" >&2
) &
notice_pid=$!

# `alarm` survives the exec and its default disposition terminates the process,
# so a stuck `op` exits non-zero rather than hanging. perl ships with macOS,
# which `timeout`/`gtimeout` do not.
# Run in the background and `wait` for it. A foreground child killed by
# SIGALRM makes the shell narrate "Alarm clock" on its own stderr, which no
# redirection on the child can suppress; a backgrounded one is reaped quietly.
# The explanatory line below is the only thing the caller should see.
perl -e 'alarm shift; exec @ARGV' "$timeout" sh -c 'op whoami >/dev/null 2>&1' 2>/dev/null &
op_pid=$!
if wait "$op_pid" 2>/dev/null; then
    result=ready
else
    result=notready
fi

kill "$notice_pid" 2>/dev/null
wait "$notice_pid" 2>/dev/null

if [ "$result" = notready ]; then
    printf 'chezmoi: 1Password is not reachable, so 1Password-backed files are skipped this run. Sign in and re-run `chezmoi apply` to land them.\n' >&2
fi

echo "$result"
