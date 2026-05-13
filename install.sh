#!/usr/bin/env bash
#
# Symlinks this repo's tracked items (skills/, CLAUDE.md, settings.json)
# into a Claude Code config directory. Idempotent — safe to re-run after
# pulling updates.
#
# If a target path already exists as a real file or directory (not a
# symlink), the script aborts with a non-zero exit code and asks you to
# back up and rename or remove the conflicting file before re-running.
#
# Usage:
#   ./install.sh                                       # links into ~/.claude
#   ./install.sh ~/.claude-work ~/.claude-personal     # links into each path
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

# Each entry maps a path inside the repo to the name it should take in the
# Claude Code config dir. They're the same in every case today, but the
# pairing keeps the loop honest if that ever changes.
ITEMS=(
    "skills:skills"
    "CLAUDE.md:CLAUDE.md"
    "settings.json:settings.json"
)

CONFLICTS=()

link_item_into() {
    local config_root="$1"
    local source_name="$2"
    local target_name="$3"

    local source="$REPO_ROOT/$source_name"
    local target="$config_root/$target_name"

    if [[ ! -e "$source" ]]; then
        echo "❌ error:    $source does not exist in the repo" >&2
        return 1
    fi

    if [[ -L "$target" ]]; then
        local current
        current="$(readlink "$target")"
        if [[ "$current" == "$source" ]]; then
            echo "✅ ok:       $target -> $source"
        else
            echo "⚠️  conflict: $target -> $current (expected -> $source)" >&2
            CONFLICTS+=("$target")
            return 1
        fi
    elif [[ -e "$target" ]]; then
        echo "⚠️  conflict: $target already exists (not a symlink)" >&2
        CONFLICTS+=("$target")
        return 1
    else
        echo "🔗 link:     $target -> $source"
        ln -s "$source" "$target"
    fi
}

install_into() {
    local config_root="$1"

    if [[ ! -d "$config_root" ]]; then
        echo "⏭️  skip:     $config_root (not present)"
        return
    fi

    local item source_name target_name
    for item in "${ITEMS[@]}"; do
        source_name="${item%%:*}"
        target_name="${item##*:}"
        link_item_into "$config_root" "$source_name" "$target_name" || true
    done
}

if [[ $# -gt 0 ]]; then
    for config_root in "$@"; do
        install_into "$config_root"
    done
else
    install_into "$HOME/.claude"
fi

if [[ ${#CONFLICTS[@]} -gt 0 ]]; then
    echo "" >&2
    echo "🛑 Installation aborted: ${#CONFLICTS[@]} conflict(s) detected." >&2
    echo "" >&2
    echo "📦 Back up anything worth keeping, then remove the paths below so install.sh can create fresh symlinks:" >&2
    for path in "${CONFLICTS[@]}"; do
        echo "       $path" >&2
    done
    echo "" >&2
    echo "🔁 Re-run install.sh once the paths above no longer exist." >&2
    exit 1
fi
