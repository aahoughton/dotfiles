#!/usr/bin/env bash
# Claude Code status line.
# Receives the session JSON on stdin and prints a single line:
#   <shortened cwd> · <model> · ctx <pct>% (<tokens used>)
# Managed by chezmoi. Enable via the "statusLine" block in ~/.claude/settings.json.

input=$(cat)

# Without jq we can't parse the payload; degrade gracefully rather than blank out.
if ! command -v jq >/dev/null 2>&1; then
    printf 'Claude (install jq for status line)'
    exit 0
fi

# Pull everything in one jq pass. Missing fields become "" or 0. Fields are
# joined with the unit separator (0x1f) rather than tab: tab is IFS whitespace,
# so empty fields between tabs would collapse and shift the columns.
IFS=$'\037' read -r cur_dir model used_pct in_tok cache_create cache_read < <(
    printf '%s' "$input" | jq -j '
        [ (.workspace.current_dir // .cwd // ""),
          (.model.display_name // .model.id // "?"),
          (.context_window.used_percentage // ""),
          (.context_window.current_usage.input_tokens // 0),
          (.context_window.current_usage.cache_creation_input_tokens // 0),
          (.context_window.current_usage.cache_read_input_tokens // 0)
        ] | map(tostring) | join("")'
)

# Prefix-shorten a path: $HOME -> ~, abbreviate every segment except the last
# (hidden dirs keep their leading dot, e.g. .local -> .l).
shorten_path() {
    local p="$1" orig="$1"
    [[ -z "$p" ]] && return
    if [[ "$p" == "$HOME" ]]; then
        printf '~'
        return
    fi
    [[ "$p" == "$HOME/"* ]] && p="~/${p#"$HOME"/}"

    local IFS='/' parts seg out="" i
    read -ra parts <<<"$p"
    local n=${#parts[@]}
    for i in "${!parts[@]}"; do
        seg="${parts[$i]}"
        [[ -z "$seg" ]] && continue
        if ((i == n - 1)); then
            out+="$seg"
        elif [[ "$seg" == .* ]]; then
            out+="${seg:0:2}/"
        else
            out+="${seg:0:1}/"
        fi
    done
    # Restore the leading slash for absolute paths that aren't under $HOME.
    [[ "$orig" == /* && "$orig" != "$HOME"* ]] && out="/$out"
    printf '%s' "$out"
}

# Render a token count compactly: 980, 45.2k, 1.3M.
human_tokens() {
    local n="$1"
    if ((n >= 1000000)); then
        printf '%d.%01dM' $((n / 1000000)) $(((n % 1000000) / 100000))
    elif ((n >= 1000)); then
        printf '%d.%01dk' $((n / 1000)) $(((n % 1000) / 100))
    else
        printf '%d' "$n"
    fi
}

# Current git branch in the session dir; falls back to a short SHA when detached.
branch=""
if [[ -n "$cur_dir" ]] && command -v git >/dev/null 2>&1; then
    branch=$(git -C "$cur_dir" symbolic-ref --quiet --short HEAD 2>/dev/null) ||
        branch=$(git -C "$cur_dir" rev-parse --short HEAD 2>/dev/null) || branch=""
fi

reset=$'\e[0m'
sep=$'\e[90m·'$'\e[0m'
c_dir=$'\e[36m'
c_branch=$'\e[33m'
c_model=$'\e[35m'

out="${c_dir}$(shorten_path "$cur_dir")${reset}"
[[ -n "$branch" ]] && out+=" ${sep} ${c_branch}${branch}${reset}"
out+=" ${sep} ${c_model}${model}${reset}"

# Append the context segment only when usage data is present.
if [[ -n "$used_pct" ]]; then
    pct_int=${used_pct%.*}
    [[ -z "$pct_int" ]] && pct_int=0
    if ((pct_int >= 80)); then
        c_ctx=$'\e[31m' # red
    elif ((pct_int >= 50)); then
        c_ctx=$'\e[33m' # yellow
    else
        c_ctx=$'\e[32m' # green
    fi
    tokens=$((in_tok + cache_create + cache_read))
    out+=" ${sep} ${c_ctx}ctx ${pct_int}% ($(human_tokens "$tokens"))${reset}"
fi

printf '%s' "$out"
