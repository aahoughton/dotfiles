#!/usr/bin/env bash
#
# llama-serve.sh -- start llama-server for the primary local model.
#
# Reads ~/.config/llama/models.lock.yaml for the model paths and verifies the
# API key file exists before binding. Runs in the foreground; use your usual
# process supervisor if you want it detached.
#
# Usage:
#   llama-serve.sh [-p port] [-c ctx] [-n] [-- extra llama-server flags...]
#     -n  print the command that would run, then exit
#
# Anything after `--` is appended to the llama-server command verbatim. That is
# how llama-agent.sh layers tool flags on top without duplicating this file.
#
# Binding: this listens on loopback only. Tailnet reachability comes from
# `tailscale serve`, which proxies http://behemoth:8080 to 127.0.0.1:8080, so
# tailnet devices get in and the LAN does not. See MAC_README.md for that setup.
#
# The API key is still required, as defence in depth rather than as the only
# control: anything that can reach loopback (any local process, any SSH session)
# reaches this port. If the key file is missing this script refuses to start
# rather than falling back to an unauthenticated listener.

set -euo pipefail

LOCK="$HOME/.config/llama/models.lock.yaml"
KEY_FILE="$HOME/.config/llama/api-key"
PORT=8080
CTX=262144
DRY_RUN=false

while getopts "p:c:n" opt; do
    case $opt in
        p) PORT="$OPTARG" ;;
        c) CTX="$OPTARG" ;;
        n) DRY_RUN=true ;;
        *) echo "Usage: llama-serve.sh [-p port] [-c ctx] [-n]" >&2; exit 1 ;;
    esac
done
shift $((OPTIND - 1))
EXTRA=("$@")

for cmd in llama-server yq; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "error: $cmd not found on PATH" >&2; exit 1; }
done

[ -f "$LOCK" ] || { echo "error: missing $LOCK" >&2; exit 1; }

# Refuse to bind a public interface without a key. See the header note.
if [ ! -s "$KEY_FILE" ]; then
    echo "error: $KEY_FILE is missing or empty; refusing to start an" >&2
    echo "       unauthenticated server. Create it with:" >&2
    echo "         mkdir -p ~/.config/llama && chmod 700 ~/.config/llama" >&2
    echo "         openssl rand -hex 32 > $KEY_FILE && chmod 600 $KEY_FILE" >&2
    exit 1
fi

perms=$(stat -f '%Lp' "$KEY_FILE")
[ "$perms" = "600" ] || echo "warning: $KEY_FILE has mode $perms, expected 600" >&2

active_root=$(yq -r '.active_root' "$LOCK")
active_root="${active_root/#\~/$HOME}"

read -r repo rev quant alias_name < <(
    yq -r '.models[] | select(.role == "primary")
           | [.repo, .revision_short, .quant, .name] | join(" ")' "$LOCK"
)
[ -n "${repo:-}" ] || { echo "error: no model with role 'primary' in $LOCK" >&2; exit 1; }

model_dir="$active_root/$repo/$rev/$quant"
weights="$model_dir/$(yq -r '.models[] | select(.role=="primary") | .files[] | select(.role=="weights") | .name' "$LOCK")"
mmproj="$model_dir/$(yq -r '.models[] | select(.role=="primary") | .files[] | select(.role=="mmproj") | .name' "$LOCK")"

for f in "$weights" "$mmproj"; do
    [ -f "$f" ] || { echo "error: missing $f (run restore-models.sh)" >&2; exit 1; }
done

read -r temp top_p top_k < <(
    yq -r '.models[] | select(.role == "primary") | .sampling
           | [.temperature, .top_p, .top_k] | join(" ")' "$LOCK"
)
for v in "${temp:-}" "${top_p:-}" "${top_k:-}"; do
    case $v in
        ''|null) echo "error: primary model in $LOCK needs sampling.temperature, .top_p and .top_k" >&2; exit 1 ;;
    esac
done

# Flags verified against llama.cpp 0.9.0 (build 12110) with the Ornith 1.5
# 35B-A3B Q8_0 primary. Notes that name Swift Qwen were measured on that
# earlier primary (dense 27B, Q8_0).
#   --n-gpu-layers 999      offload everything to Metal
#   --flash-attn on         required for the cache-type settings below to pay off
#   --jinja                 use the model's own chat template for tool calling
#   --temp/--top-p/--top-k  the primary's sampling block from the lock file
#   --image-min-tokens 1024 Qwen-VL needs at least this many tokens per image.
#       Below it the vision path does not error, it confabulates: on Swift
#       Qwen, a 1082x400 document page budgeted ~440 tokens produced entirely
#       invented field values that looked plausible. With this flag, Ornith
#       read all seven fields of a page that size exactly in 5 of 6 runs (the
#       sixth dropped a hyphen from a name), and every run returned null for a
#       field the page did not have.
#
#   --parallel 1            one slot owns the whole context window.
#       Left at its default, llama-server picks 4 slots and unifies the KV
#       cache, so all four share a single --ctx-size pool rather than getting
#       one each. Two agents running at once then silently contend for the same
#       tokens, which shows up as unexplained truncation. With one slot,
#       concurrent requests queue instead, which fails loudly and predictably.
#
#   --spec-type draft-mtp   speculative decoding off the model's own MTP head.
#       The weights carry an extra block (blk.<last>.nextn.*, keyed by
#       <arch>.nextn_predict_layers), so there is no separate draft model to
#       download or pin. On Swift Qwen, a fixed 900-token completion at
#       temperature 0 took 40.9s without and 26.7s with. Output is not
#       guaranteed identical with and without: on quantized weights the MTP
#       path can change greedy output (llama.cpp issue #25618).
#
#   --spec-draft-n-max 3    draft budget per step. This is also llama.cpp's
#       current default; it is passed explicitly so a future change to that
#       default does not silently retune this. Tuned on Swift Qwen, where
#       larger budgets were slower overall: n=3 26.7s (acceptance 0.68), n=4
#       31.0s (0.60), n=5 31.3s (0.52), n=6 36.2s (0.47). Not retuned for
#       Ornith, which accepts 0.55 of drafted tokens at n=3.
#
# --cache-reuse is deliberately absent: llama-server disables it when an mmproj
# is loaded ("cache_reuse is not supported by multimodal"), so passing it only
# produces a warning. Note the consequence for long sessions: an agent's
# compaction rewrites the front of the context, invalidating the cached prefix,
# so the whole rebuilt context is re-prefilled (Ornith: ~1300 t/s at 58k
# tokens, ~550 t/s at 206k).
#
# Context sizing: 262144 is Ornith's trained context. Only 10 of its 40 layers
# use full attention (the rest keep a fixed-size recurrent state), with 2 kv
# heads and k/v length 256, so KV costs 20 KiB/token at f16: 5 GiB at 262144,
# on top of 38 GB of weights. The whole server measured 48 GiB RSS. Measured
# tg on a 900-token completion: 119 t/s at depth 0, 97 at 28k, 80 at 58k, 47
# at 206k, with no cliff.
cmd=(
    llama-server
    --model "$weights"
    --mmproj "$mmproj"
    --alias "$alias_name"
    --host 127.0.0.1 --port "$PORT"
    --api-key-file "$KEY_FILE"
    --n-gpu-layers 999
    --ctx-size "$CTX"
    --parallel 1
    --batch-size 2048 --ubatch-size 512
    --flash-attn on
    --cache-type-k f16 --cache-type-v f16
    --temp "$temp" --top-p "$top_p" --top-k "$top_k"
    --image-min-tokens 1024
    --jinja
    --spec-type draft-mtp
    --spec-draft-n-max 3
)

if [ ${#EXTRA[@]} -gt 0 ]; then
    cmd+=("${EXTRA[@]}")
fi

if [ "$DRY_RUN" = true ]; then
    printf '%q ' "${cmd[@]}"; echo
    exit 0
fi

echo "starting $alias_name on 127.0.0.1:$PORT (ctx $CTX)" >&2
exec "${cmd[@]}"
