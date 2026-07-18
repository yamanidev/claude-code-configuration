#!/usr/bin/env bash
#
# Claude Code status line. Reads the session JSON from stdin
# and emits a status string of up to three lines, one per concern:
#
#   Line 1: <launch-dir>[ · <config-dir-name>]
#   Line 2: <model> <version> (<context-window> context)
#   Line 3: 5h: <pct>% (⟳ <resets-in>) · 7d: <pct>% (⟳ <resets-in>) · context: <tokens>k
#
# Line 1's launch-dir is the basename of the directory
# Claude Code was launched from (workspace.project_dir).
# It stays fixed even if the working directory changes mid-session.
# The config-dir name follows it
# only when the active config dir contains a `.config-name` file
# (written by install.sh for multi-account installs).
#
# Each line is emitted only when its group has content
# so an empty group collapses rather than leaving a blank row.
# Line 3 in particular is absent
# when rate limits and context usage are both missing
# (free plan, or before the first API response of the session).
#
# Context usage is read from the latest assistant turn in the session transcript
# and color-coded by absolute token count:
# green < 80k, yellow 80–160k, red ≥ 160k.
# This tracks the practical quality-degradation curve for code/agent work.
# It holds whether the model advertises a 200k or 1M window.

set -euo pipefail

if ! command -v jq >/dev/null 2>&1; then
    printf '⚠️  status line disabled: jq not installed\n'
    exit 0
fi

input=$(cat)

join_by() {
    local sep="$1"; shift
    [[ $# -eq 0 ]] && return
    printf '%s' "$1"; shift
    for item in "$@"; do
        printf '%s%s' "$sep" "$item"
    done
}

format_resets_in() {
    local epoch="$1"
    [[ -z "$epoch" || "$epoch" == "null" ]] && return
    local now diff
    now=$(date +%s)
    diff=$(( epoch - now ))
    if (( diff <= 0 )); then
        printf 'now'
    elif (( diff < 3600 )); then
        printf '%dm' "$(( diff / 60 ))"
    elif (( diff < 86400 )); then
        printf '%dh' "$(( diff / 3600 ))"
    else
        printf '%dd' "$(( diff / 86400 ))"
    fi
}

# Line 1 — launch dir + (optional) config dir name
header_parts=()

# Directory Claude Code was launched from.
# This stays fixed for the session
# unlike a cwd that /add-dir or a subagent might change.
# Falls back to cwd.
launch_dir=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // .cwd // empty')
[[ -n "$launch_dir" ]] && header_parts+=("${launch_dir##*/}")

config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if [[ -f "$config_dir/.config-name" ]]; then
    config_name=$(tr -d '[:space:]' < "$config_dir/.config-name")
    [[ -n "$config_name" ]] && header_parts+=("$config_name")
fi

# Line 2 — model + version + context-window size
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
model_id=$(echo "$input" | jq -r '.model.id // empty')
version=$(echo "$model_id" | grep -oE '[0-9]+-[0-9]+' | head -n1 | tr '-' '.')
context_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')

# Renders the context window as a label, e.g. "1M context" or "200k context".
format_context_window_label() {
    local size="$1"
    [[ -z "$size" || "$size" == "null" || "$size" == "0" ]] && return
    if (( size >= 1000000 )); then
        printf '%dM context' "$(( size / 1000000 ))"
    else
        printf '%dk context' "$(( size / 1000 ))"
    fi
}

model_parts=()
if [[ -n "$model_name" ]]; then
    # Claude Code bakes a context suffix into display_name, e.g. "Opus 4.8 (1M context)".
    # It does so only when the window is a distinguishable model variant
    # and omits the suffix once that window becomes the model's default.
    # Strip any such suffix
    # so the label below always comes from context_window.context_window_size.
    # That field is always present
    # and does not vary with the UI convention.
    model_name=${model_name% (*context)}
    if [[ -n "$version" && "$model_name" != *"$version"* ]]; then
        model_segment="${model_name} ${version}"
    else
        model_segment="$model_name"
    fi
    context_window_label=$(format_context_window_label "$context_window_size")
    [[ -n "$context_window_label" ]] && model_segment="${model_segment} (${context_window_label})"
    model_parts+=("$model_segment")
fi

# Line 3 — subscription rate limits + context usage
five_pct=$(echo "$input"  | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_pct=$(echo "$input"  | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

format_window() {
    local label="$1" pct="$2" reset_epoch="$3"
    [[ -z "$pct" ]] && return
    local reset_in rounded color
    reset_in=$(format_resets_in "$reset_epoch")
    printf -v rounded '%.0f' "$pct"
    if (( rounded >= 90 )); then
        color=$'\033[31m'
    elif (( rounded >= 70 )); then
        color=$'\033[33m'
    else
        color=$'\033[32m'
    fi
    if [[ -n "$reset_in" ]]; then
        printf '%s: %s%.0f%%\033[0m (⟳ %s)' "$label" "$color" "$pct" "$reset_in"
    else
        printf '%s: %s%.0f%%\033[0m' "$label" "$color" "$pct"
    fi
}

usage_parts=()
five_str=$(format_window "5h" "$five_pct" "$five_reset")
[[ -n "$five_str" ]] && usage_parts+=("$five_str")
seven_str=$(format_window "7d" "$seven_pct" "$seven_reset")
[[ -n "$seven_str" ]] && usage_parts+=("$seven_str")

transcript_path=$(echo "$input" | jq -r '.transcript_path // empty')
context_tokens=
if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
    context_tokens=$(jq -r 'select(.message.usage != null) | .message.usage | (.input_tokens // 0) + (.cache_read_input_tokens // 0) + (.cache_creation_input_tokens // 0)' "$transcript_path" 2>/dev/null | tail -n 1)
fi

format_context() {
    local tokens="$1"
    [[ -z "$tokens" || "$tokens" == "0" ]] && return
    local color
    if (( tokens >= 160000 )); then
        color=$'\033[31m'
    elif (( tokens >= 80000 )); then
        color=$'\033[33m'
    else
        color=$'\033[32m'
    fi
    printf 'context: %s%dk\033[0m' "$color" "$(( tokens / 1000 ))"
}

ctx_str=$(format_context "$context_tokens")
[[ -n "$ctx_str" ]] && usage_parts+=("$ctx_str")

# Output — each populated group on its own line, empty groups collapse
if [[ ${#header_parts[@]} -gt 0 ]]; then
    join_by ' · ' "${header_parts[@]}"
    printf '\n'
fi
if [[ ${#model_parts[@]} -gt 0 ]]; then
    join_by ' · ' "${model_parts[@]}"
    printf '\n'
fi
if [[ ${#usage_parts[@]} -gt 0 ]]; then
    join_by ' · ' "${usage_parts[@]}"
    printf '\n'
fi
