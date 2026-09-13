#!/usr/bin/env bash
#
# validate_settings.sh — assert settings.json and statusline.json build cleanly.
#
# settings-with-statusline.json is generated from those two by build_settings.sh and is git-ignored.
# So there is no committed artifact to compare against.
# The check is that a build into a throwaway path succeeds.
# build_settings.sh already rejects invalid JSON, a fragment with keys other than statusLine, and a statusLine key in settings.json.

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

scratch_dir="$(mktemp -d)"
trap 'rm -rf "$scratch_dir"' EXIT

if "$repo_root/scripts/build_settings.sh" "$scratch_dir/settings-with-statusline.json" >/dev/null; then
    echo "✅ settings.json and statusline.json build cleanly."
else
    echo "🛑 Fix the source files above, then re-run this check." >&2
    exit 1
fi
