#!/usr/bin/env bash
#
# Claude Code status line. Reads the session JSON from stdin and emits
# a two-line status string:
#
#   Line 1: <model> <version>[ · <config-dir-name>]
#   Line 2: 5h: <pct>% (<resets-in>) · 7d: <pct>% (<resets-in>)
#
# Line 1's config-dir name appears only when the active config dir
# contains a `.config-name` file (written by install.sh for multi-account
# installs). Line 2 is omitted entirely when rate limits are absent
# (free plan, or before the first API response of the session).

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

# Line 1 — model + (optional) config dir name
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
model_id=$(echo "$input" | jq -r '.model.id // empty')
version=$(echo "$model_id" | grep -oE '[0-9]+-[0-9]+' | head -n1 | tr '-' '.')

line1_parts=()
if [[ -n "$model_name" ]]; then
    if [[ -n "$version" ]]; then
        line1_parts+=("${model_name} ${version}")
    else
        line1_parts+=("$model_name")
    fi
fi

config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
if [[ -f "$config_dir/.config-name" ]]; then
    config_name=$(tr -d '[:space:]' < "$config_dir/.config-name")
    [[ -n "$config_name" ]] && line1_parts+=("$config_name")
fi

# Line 2 — subscription rate limits
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
        printf '%s: %s%.0f%%\033[0m (resets in %s)' "$label" "$color" "$pct" "$reset_in"
    else
        printf '%s: %s%.0f%%\033[0m' "$label" "$color" "$pct"
    fi
}

line2_parts=()
five_str=$(format_window "5h" "$five_pct" "$five_reset")
[[ -n "$five_str" ]] && line2_parts+=("$five_str")
seven_str=$(format_window "7d" "$seven_pct" "$seven_reset")
[[ -n "$seven_str" ]] && line2_parts+=("$seven_str")

# Output
join_by ' · ' "${line1_parts[@]}"
printf '\n'
if [[ ${#line2_parts[@]} -gt 0 ]]; then
    join_by ' · ' "${line2_parts[@]}"
    printf '\n'
fi
