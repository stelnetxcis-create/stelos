#!/usr/bin/env bash
# get-active-remote.sh
#
# Determines the actual git remote for the StelOS fork.
#
# Priority order:
#   1. The real ii-stelos repo (source of truth - if it exists and is a git
#      repo, its remote wins, regardless of any cached .active-remote file)
#   2. Older ii-vynx fallback paths, for machines mid-migration
#   3. The cached .active-remote file, LAST - since it can go stale (e.g.
#      still pointing at an old fork/original author's repo after migrating)

set -uo pipefail

CANDIDATES=(
    "$HOME/.local/share/ii-stelos"
    "$HOME/Downloads/ii-vynx"
    "$HOME/.local/share/ii-vynx-fork"
    "$HOME/.local/share/ii-vynx-upstream"
    "$HOME/.local/share/ii-vynx"
    "$HOME/dotfiles"
)

for dir in "${CANDIDATES[@]}"; do
    if git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
        REMOTE="$(git -C "$dir" remote get-url origin 2>/dev/null || echo "")"
        if [[ -n "$REMOTE" ]]; then
            echo "$REMOTE"
            exit 0
        fi
    fi
done

# Fall back to the cached file only if no real repo was found at all
CACHE_FILE="$HOME/.config/quickshell/ii/.active-remote"
if [[ -f "$CACHE_FILE" ]]; then
    cat "$CACHE_FILE"
    exit 0
fi

echo ""
