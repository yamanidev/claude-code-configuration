#!/usr/bin/env bash
# install.sh — symlink this repo's skills/, CLAUDE.md, and settings.json
# into one or more Claude Code config dirs. Run `./install.sh --help` for usage.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

print_usage() {
    cat <<'EOF'
Usage: install.sh [--statusline] [TARGET_DIR...]

Symlinks this repo's tracked items (skills/, CLAUDE.md, settings.json)
into one or more Claude Code config directories. Idempotent — safe to
re-run after pulling updates.

Flags:
  --statusline    Opt in to the status line (installs settings with a
                  statusLine block and symlinks statusline.sh). With
                  multiple target dirs, prompts for a display name per
                  dir.
  -h, --help      Show this message and exit.

Examples:
  ./install.sh                                      # links into ~/.claude
  ./install.sh ~/.claude-work ~/.claude-personal    # links into each path
  ./install.sh --statusline                         # with status line
EOF
}

# Flag parsing — strip recognised flags from "$@" so the rest can be
# treated as positional target dirs by the existing logic below.
STATUSLINE=false
ARGS=()
for arg in "$@"; do
    case "$arg" in
        --statusline) STATUSLINE=true ;;
        -h|--help) print_usage; exit 0 ;;
        --*) echo "❌ unknown flag: $arg" >&2; print_usage >&2; exit 2 ;;
        *) ARGS+=("$arg") ;;
    esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

# Each entry maps a path inside the repo to the name it should take in
# the Claude Code config dir. The set depends on whether the status line
# was opted into.
ITEMS=(
    "skills:skills"
    "CLAUDE.md:CLAUDE.md"
)
if [[ "$STATUSLINE" == "true" ]]; then
    ITEMS+=("settings-with-statusline.json:settings.json")
    ITEMS+=("scripts/statusline.sh:statusline.sh")
else
    ITEMS+=("settings.json:settings.json")
fi

CONFLICTS=()

link_item_into() {
    local config_root="$1"
    local source_name="$2"
    local target_name="$3"

    local source="$REPO_ROOT/$source_name"
    local target="$config_root/$target_name"

    if [[ ! -e "$source" ]]; then
        echo "❌ source missing: $source does not exist in the repo" >&2
        return 1
    fi

    if [[ -L "$target" ]]; then
        local current
        current="$(readlink "$target")"
        if [[ "$current" == "$source" ]]; then
            echo "✅ already linked: $target -> $source"
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
        echo "🔗 linked successfully: $target -> $source"
        ln -s "$source" "$target"
    fi
}

prompt_config_name() {
    local config_root="$1"
    local name_file="$config_root/.config-name"

    if [[ -f "$name_file" ]]; then
        local existing
        existing=$(cat "$name_file")
        echo "📝 display name already set: $config_root → $existing (delete $name_file to re-prompt)"

        return
    fi

    local display_name=""
    while [[ -z "$display_name" ]]; do
        read -r -p "   display name for $config_root: " display_name
        # Trim leading/trailing whitespace only; preserve internal spaces.
        display_name="${display_name#"${display_name%%[![:space:]]*}"}"
        display_name="${display_name%"${display_name##*[![:space:]]}"}"
    done

    printf '%s\n' "$display_name" > "$name_file"
    echo "📝 saved display name: $config_root/.config-name → $display_name"
}

install_into() {
    local config_root="$1"

    if [[ ! -d "$config_root" ]]; then
        echo "⏭️  config dir missing: $config_root"
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
    TARGETS=("$@")
else
    TARGETS=("$HOME/.claude")
fi

for config_root in "${TARGETS[@]}"; do
    install_into "$config_root"
done

# When the status line is opted in and more than one target dir is
# given, prompt for a display name per dir so the status line can show
# which account is active. Single-target status-line installs work fine
# without one — the script just omits the config-dir field in that case.
if [[ "$STATUSLINE" == "true" && ${#CONFLICTS[@]} -eq 0 && ${#TARGETS[@]} -gt 1 ]]; then
    echo ""
    echo "📝 Multiple config dirs detected. Set a display name for each (shown in the status line):"
    for config_root in "${TARGETS[@]}"; do
        [[ -d "$config_root" ]] || continue
        prompt_config_name "$config_root"
    done
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
