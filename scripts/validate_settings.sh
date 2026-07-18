#!/usr/bin/env bash
#
# validate_settings.sh — assert the two settings files stay in sync.
#
# install.sh symlinks one of two static settings files into a config dir: settings.json, or settings-with-statusline.json when --statusline is passed.
# The two must carry identical configuration, differing only by the statusLine block the second file adds.
# This check enforces that invariant so a key added or changed in one file is never silently missed in the other.

set -euo pipefail

base="settings.json"
statusline="settings-with-statusline.json"

for file in "$base" "$statusline"; do
    if ! jq empty "$file" >/dev/null 2>&1; then
        echo "❌ $file is not valid JSON" >&2
        exit 1
    fi
done

if diff_output=$(diff \
    <(jq -S 'del(.statusLine)' "$statusline") \
    <(jq -S . "$base")); then
    echo "✅ $base and $statusline are in sync (modulo statusLine)."
else
    echo "❌ $base and $statusline have drifted." >&2
    echo "" >&2
    echo "$diff_output" >&2
    echo "" >&2
    echo "🛑 The two files must share every key except statusLine." >&2
    echo "   Apply the change to both, then re-run this check." >&2
    exit 1
fi

if [[ "$(jq -r 'has("statusLine")' "$statusline")" != "true" ]]; then
    echo "❌ $statusline is missing its statusLine block." >&2
    exit 1
fi
