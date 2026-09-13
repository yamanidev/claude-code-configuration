#!/usr/bin/env bash
#
# build_settings.sh — generate settings-with-statusline.json from its two sources.
#
# settings.json holds every setting shared by both install variants.
# statusline.json holds the statusLine block and nothing else.
# Claude Code reads one settings file per config dir and cannot layer a second one at the user level.
# So the status-line variant has to be a complete file, and this script produces it by merging the two sources with jq.
# The output is git-ignored. install.sh runs this script before linking it, and a re-run refreshes it after `git pull`.
#
# Claude Code writes some choices straight into the file it reads, such as /model and /config toggles.
# Through the symlink those land in the generated file, where git cannot see them.
# Before overwriting, this script prints any such difference so the choice can be moved into settings.json instead of lost.
#
# Usage: build_settings.sh [OUTPUT]
#   OUTPUT defaults to settings-with-statusline.json in the repo root.
#   validate_settings.sh passes a temp path to check that the sources are consistent.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
common="$repo_root/settings.json"
fragment="$repo_root/statusline.json"
output="${1:-$repo_root/settings-with-statusline.json}"

for file in "$common" "$fragment"; do
    if ! jq empty "$file" >/dev/null 2>&1; then
        echo "❌ $(basename "$file") is not valid JSON" >&2
        exit 1
    fi
done

if ! jq -e 'keys == ["statusLine"]' "$fragment" >/dev/null; then
    echo "❌ statusline.json must contain the statusLine key and nothing else." >&2
    exit 1
fi

if jq -e 'has("statusLine")' "$common" >/dev/null; then
    echo "❌ settings.json must not carry a statusLine key. It belongs in statusline.json." >&2
    exit 1
fi

staged="$(mktemp "$(dirname "$output")/.settings-build.XXXXXX")"
trap 'rm -f "$staged"' EXIT
jq -s '.[0] * .[1]' "$common" "$fragment" > "$staged"

if [[ -s "$output" ]] && jq empty "$output" >/dev/null 2>&1; then
    if dropped=$(diff <(jq -S . "$output") <(jq -S . "$staged")); then
        :
    else
        echo "⚠️  $(basename "$output") differed from its sources. Lines marked < are being dropped:" >&2
        echo "$dropped" >&2
        echo "   Claude Code writes /model and /config choices through the symlink into this file." >&2
        echo "   Add them to settings.json and rebuild if you want to keep them." >&2
    fi
fi

mv -f "$staged" "$output"
trap - EXIT
echo "✅ generated $(basename "$output") from settings.json and statusline.json"
