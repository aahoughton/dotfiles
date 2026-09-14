#!/usr/bin/env bash
#
# restore-models.sh — rebuild the active model tree from models.lock.yaml.
#
# Source order is archive first, Hugging Face second: the Dropbox archive is a
# local copy of a known-good revision, so it is faster and does not depend on
# the upstream repo still existing. Every restored file is verified by SHA-256
# against the lock manifest before it is considered good.
#
# Usage:
#   restore-models.sh [-f] [-v] [model-name ...]
#     -f  force: re-fetch even if the active file already verifies
#     -v  verify only: check what is present, restore nothing
#
# Inference never runs from the archive. Dropbox is an archive destination, not
# a memory-mapped runtime filesystem; files are copied out before use.

set -euo pipefail

LOCK="$HOME/.config/llama/models.lock.yaml"
FORCE=false
VERIFY_ONLY=false

while getopts "fv" opt; do
    case $opt in
        f) FORCE=true ;;
        v) VERIFY_ONLY=true ;;
        *) echo "Usage: restore-models.sh [-f] [-v] [model-name ...]" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))

for cmd in yq shasum; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "error: $cmd not found on PATH" >&2; exit 1; }
done
[ -f "$LOCK" ] || { echo "error: missing $LOCK" >&2; exit 1; }

expand() { printf '%s' "${1/#\~/$HOME}"; }
active_root=$(expand "$(yq -r '.active_root' "$LOCK")")
archive_root=$(expand "$(yq -r '.archive_root' "$LOCK")")

# A Dropbox online-only placeholder has a real size in stat but no local
# blocks, so it reads back as a stall or an error rather than data. Treat a
# zero-block file as absent instead of trying to copy it.
is_hydrated() {
    local f=$1
    [ -f "$f" ] || return 1
    local blocks; blocks=$(stat -f '%b' "$f")
    [ "$blocks" -gt 0 ]
}

verify() {
    local file=$1 want=$2
    [ -f "$file" ] || return 1
    local got; got=$(shasum -a 256 "$file" | cut -d' ' -f1)
    [ "$got" = "$want" ]
}

failed=0

names=("$@")
if [ ${#names[@]} -eq 0 ]; then
    while IFS= read -r n; do names+=("$n"); done < <(yq -r '.models[].name' "$LOCK")
fi

for name in "${names[@]}"; do
    sel=".models[] | select(.name == \"$name\")"
    repo=$(yq -r "$sel | .repo" "$LOCK")
    [ -n "$repo" ] && [ "$repo" != "null" ] || { echo "error: no model named '$name' in $LOCK" >&2; failed=1; continue; }
    rev=$(yq -r "$sel | .revision" "$LOCK")
    rev_short=$(yq -r "$sel | .revision_short" "$LOCK")
    quant=$(yq -r "$sel | .quant" "$LOCK")

    active_dir="$active_root/$repo/$rev_short/$quant"
    archive_dir="$archive_root/$repo/$rev_short/$quant"
    echo "== $name ($repo @ $rev_short, $quant)"

    while IFS=' ' read -r fname want; do
        dest="$active_dir/$fname"

        if [ "$FORCE" = false ] && verify "$dest" "$want"; then
            echo "  ok       $fname"
            continue
        fi
        if [ "$VERIFY_ONLY" = true ]; then
            if [ -f "$dest" ]; then echo "  BAD      $fname (checksum mismatch)"
            else echo "  MISSING  $fname"; fi
            failed=1
            continue
        fi

        mkdir -p "$active_dir"
        src="$archive_dir/$fname"
        if is_hydrated "$src"; then
            echo "  restore  $fname from archive"
            cp "$src" "$dest"
        else
            if [ -f "$src" ]; then
                echo "  note     archive copy of $fname is online-only, falling back to Hugging Face" >&2
            fi
            command -v hf >/dev/null 2>&1 || { echo "  error: hf not on PATH and no local archive copy" >&2; failed=1; continue; }
            echo "  download $fname from $repo@$rev"
            # One file per invocation: passing several filenames with --include
            # silently downloads only the first and still exits 0.
            hf download "$repo" "$fname" --revision "$rev" --local-dir "$active_dir"
        fi

        if verify "$dest" "$want"; then
            echo "  ok       $fname"
        else
            echo "  FAIL     $fname checksum mismatch after restore" >&2
            failed=1
        fi
    done < <(yq -r "$sel | .files[] | [.name, .sha256] | join(\" \")" "$LOCK")
done

exit "$failed"
