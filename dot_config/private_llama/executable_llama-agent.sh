#!/usr/bin/env bash
#
# llama-agent.sh - llama-serve.sh plus tool calling.
#
# This is llama-serve.sh with MCP servers attached, kept separate because the
# threat model differs. llama-serve.sh serves text and images: the worst a
# caller can do is spend GPU time. This one gives the model tools that reach
# the network, and with -t, tools that touch a filesystem. Those deserve their
# own file rather than a flag on the plain server.
#
# Usage:
#   llama-agent.sh [-p port] [-c ctx] [-n] [-t]
#     -t  additionally enable llama.cpp's built-in file and shell tools,
#         confined to a container (see the note on -t below)
#
# All other flags are passed through to llama-serve.sh, which owns the model
# selection and the sampling and KV settings. Nothing here duplicates them.
#
# Reachability is inherited: loopback only, with `tailscale serve` fronting it
# for the tailnet. Note what that means once tools are on. Any tailnet device
# holding the API key can drive these tools, and POST /tools executes them
# directly with no model in the loop. The key is the whole boundary.

set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVE="$HERE/llama-serve.sh"
MCP_CONFIG="$HERE/mcp-servers.json"
SEARXNG_URL="http://127.0.0.1:8889"

BUILTIN_TOOLS=false
ARGS=()
while getopts "p:c:nt" opt; do
    case $opt in
        t) BUILTIN_TOOLS=true ;;
        p) ARGS+=(-p "$OPTARG") ;;
        c) ARGS+=(-c "$OPTARG") ;;
        n) ARGS+=(-n) ;;
        *) echo "usage: llama-agent.sh [-p port] [-c ctx] [-n] [-t]" >&2; exit 1 ;;
    esac
done

[ -x "$SERVE" ] || { echo "error: $SERVE not found or not executable" >&2; exit 1; }
[ -f "$MCP_CONFIG" ] || { echo "error: missing $MCP_CONFIG" >&2; exit 1; }

# Fail here rather than letting the model discover mid-session that every search
# returns an error. llama-server starts fine without SearXNG; the tools just
# break, which surfaces as the model inventing an answer instead of saying so.
if ! curl -fsS -m 3 -o /dev/null "$SEARXNG_URL/healthz" 2>/dev/null; then
    echo "error: SearXNG is not answering at $SEARXNG_URL" >&2
    echo "       start it with:" >&2
    echo "         docker compose -f ~/.config/llama/searxng/compose.yaml up -d" >&2
    exit 1
fi

EXTRA=(--mcp-servers-config "$MCP_CONFIG")

# -t adds read_file, write_file, edit_file, grep_search, file_glob_search,
# exec_shell_command and get_info. Without --tools-runtime those run as your
# user against your home directory, which turns an API key into shell access.
# The container gets nothing mounted, so the tools operate on an empty
# filesystem: useful for letting the model run throwaway code, useless for
# working on real files. That asymmetry is deliberate. If you ever want it
# pointed at a real tree, mount that tree explicitly and know what you granted.
if [ "$BUILTIN_TOOLS" = true ]; then
    command -v docker >/dev/null 2>&1 || { echo "error: -t needs docker on PATH" >&2; exit 1; }
    EXTRA+=(--tools all --tools-runtime docker:alpine:3.22)
fi

exec "$SERVE" "${ARGS[@]}" -- "${EXTRA[@]}"
