#!/usr/bin/env bash
#
# llama-serve.sh -- start llama-server for one of the served local models.
#
# Reads ~/.config/llama/models.lock.yaml for the model with the given role:
# its paths, sampling, port, context and MTP settings. Verifies the API key
# file exists before binding. Runs in the foreground; use your usual process
# supervisor if you want it detached.
#
# Usage:
#   llama-serve.sh -r role [-p port] [-c ctx] [-n] [-- extra llama-server flags...]
#     -r  chat or code: the lock file's role for the model to serve
#     -p  override the model's serve.port
#     -c  override the model's serve.ctx
#     -n  print the command that would run, then exit
#
# Anything after `--` is appended to the llama-server command verbatim. That is
# how llama-agent.sh layers tool flags on top without duplicating this file.
#
# Binding: this listens on loopback only. Tailnet reachability comes from
# `tailscale serve`, which proxies http://behemoth:<port> to 127.0.0.1:<port>,
# so tailnet devices get in and the LAN does not. See MAC_README.md for that
# setup.
#
# The API key is still required, as defence in depth rather than as the only
# control: anything that can reach loopback (any local process, any SSH session)
# reaches this port. If the key file is missing this script refuses to start
# rather than falling back to an unauthenticated listener.

set -euo pipefail

LOCK="$HOME/.config/llama/models.lock.yaml"
KEY_FILE="$HOME/.config/llama/api-key"
ROLE=
PORT=
CTX=
DRY_RUN=false
USAGE="usage: llama-serve.sh -r role [-p port] [-c ctx] [-n] [-- llama-server flags]"

while getopts "r:p:c:n" opt; do
    case $opt in
        r) ROLE="$OPTARG" ;;
        p) PORT="$OPTARG" ;;
        c) CTX="$OPTARG" ;;
        n) DRY_RUN=true ;;
        *) echo "$USAGE" >&2; exit 1 ;;
    esac
done
[ -n "$ROLE" ] || { echo "$USAGE" >&2; exit 1; }
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

n=$(ROLE="$ROLE" yq '[.models[] | select(.role == strenv(ROLE))] | length' "$LOCK")
[ "$n" = 1 ] || { echo "error: $LOCK has $n models with role '$ROLE', expected 1" >&2; exit 1; }

# One yq call per field: a missing field prints "null", which the checks below
# reject, instead of shifting the remaining fields as a space-joined read would.
field() { ROLE="$ROLE" yq -r ".models[] | select(.role == strenv(ROLE)) | $1" "$LOCK"; }
require() {
    case $2 in
        ''|null) echo "error: the '$ROLE' model in $LOCK needs $1" >&2; exit 1 ;;
    esac
}

repo=$(field .repo);              require repo "$repo"
rev=$(field .revision_short);     require revision_short "$rev"
quant=$(field .quant);            require quant "$quant"
alias_name=$(field .name);        require name "$alias_name"
temp=$(field .sampling.temperature); require sampling.temperature "$temp"
top_p=$(field .sampling.top_p);   require sampling.top_p "$top_p"
top_k=$(field .sampling.top_k);   require sampling.top_k "$top_k"
draft_n=$(field .serve.spec_draft_n_max); require serve.spec_draft_n_max "$draft_n"
reasoning=$(field .serve.reasoning)
if [ -z "$PORT" ]; then PORT=$(field .serve.port); require serve.port "$PORT"; fi
if [ -z "$CTX" ]; then CTX=$(field .serve.ctx); require serve.ctx "$CTX"; fi

model_dir="$active_root/$repo/$rev/$quant"
weights="$model_dir/$(field '.files[] | select(.role == "weights") | .name')"
mmproj="$model_dir/$(field '.files[] | select(.role == "mmproj") | .name')"

for f in "$weights" "$mmproj"; do
    [ -f "$f" ] || { echo "error: missing $f (run restore-models.sh)" >&2; exit 1; }
done

# Flags verified against llama.cpp 0.9.0 (build 12110) with Ornith 1.5
# 35B-A3B Q8_0 (chat) and Swift Qwen3.8 27B Q8_0 (code).
#   --n-gpu-layers 999      offload everything to Metal
#   --flash-attn on         required for the cache-type settings below to pay off
#   --jinja                 use the model's own chat template for tool calling
#   --temp/--top-p/--top-k  the model's sampling block from the lock file
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
#   --spec-draft-n-max      draft budget per step, the model's
#       serve.spec_draft_n_max. Re-tune for each model. Ornith, mean tg over
#       code, prose and outline prompts (1024 tokens, thinking off, 3 runs
#       each): no MTP 96 t/s, n=1 117 (acceptance 0.76), n=2 121 (0.62), n=3
#       115 (0.50), n=4 111, n=5 102, n=6 94. Code alone is flat from n=2 to
#       n=4 (132-135); prose and outlines fall off past n=2. Swift Qwen's
#       numbers are in the lock file.
#
# --cache-reuse is deliberately absent: llama-server disables it when an mmproj
# is loaded ("cache_reuse is not supported by multimodal"), so passing it only
# produces a warning. Note the consequence for long sessions: an agent's
# compaction rewrites the front of the context, invalidating the cached prefix,
# so the whole rebuilt context is re-prefilled (Ornith: ~1300 t/s at 58k
# tokens, ~550 t/s at 206k).
#
#   --reasoning             the model's serve.reasoning, when set. Only the
#       server default: a request's chat_template_kwargs.enable_thinking
#       overrides it in either direction.
#
# Context sizing comes from serve.ctx. Ornith's 262144 is its trained context.
# Only 10 of its 40 layers use full attention (the rest keep a fixed-size
# recurrent state), with 2 kv heads and k/v length 256, so KV costs 20
# KiB/token at f16: 5 GiB at 262144, on top of 38 GB of weights. The whole
# server measured 48 GiB RSS. Measured tg on a 900-token completion: 119 t/s at
# depth 0, 97 at 28k, 80 at 58k, 47 at 206k, with no cliff. Swift Qwen's
# sizing is in the lock file.
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
    --spec-draft-n-max "$draft_n"
)

if [ -n "$reasoning" ] && [ "$reasoning" != null ]; then
    cmd+=(--reasoning "$reasoning")
fi

if [ ${#EXTRA[@]} -gt 0 ]; then
    cmd+=("${EXTRA[@]}")
fi

if [ "$DRY_RUN" = true ]; then
    printf '%q ' "${cmd[@]}"; echo
    exit 0
fi

echo "starting $alias_name on 127.0.0.1:$PORT (ctx $CTX)" >&2
exec "${cmd[@]}"
