#!/usr/bin/env bash
# sync-live-config.sh
#
# Walks every file already tracked in the StelOS fork repo's dots/.config,
# and for each one that also exists in your live ~/.config, checks if it
# differs. If so, shows a diff and asks whether to sync the live version
# INTO the fork (staged for the next push).
#
# File-level granularity is intentional: only files that ALREADY exist in
# the fork are ever touched. Anything that exists only in your live config
# (personal scripts, extra functions, unrelated apps, etc.) is never copied
# in, never looked at, and never listed.

set -euo pipefail

FORK_DIR="${1:-$HOME/.local/share/ii-stelos}"
FORK_CONFIG="$FORK_DIR/dots/.config"
LIVE_CONFIG="$HOME/.config"

AUTO_YES=false
DRY_RUN=false
for arg in "${@:2}"; do
    case "$arg" in
        --yes|--no-confirm) AUTO_YES=true ;;
        --dry-run) DRY_RUN=true ;;
    esac
done

if [[ ! -d "$FORK_CONFIG" ]]; then
    echo "✗ Fork config dir not found: $FORK_CONFIG"
    exit 1
fi

echo "Comparing tracked files in:"
echo "  Fork: $FORK_CONFIG"
echo "  Live: $LIVE_CONFIG"
echo ""
echo "(Only files that already exist in the fork are checked."
echo " Anything only in your live config - personal scripts, extra files -"
echo " is never touched.)"
echo ""

CHANGED=0
SYNCED=0
SKIPPED=0

# Walk every FILE already tracked in the fork (not just top-level folders)
while IFS= read -r -d '' fork_file; do
    rel_path="${fork_file#"$FORK_CONFIG"/}"
    live_file="$LIVE_CONFIG/$rel_path"

    if [[ ! -e "$live_file" ]]; then
        # Tracked in fork but doesn't exist live - nothing to sync from, skip.
        continue
    fi

    if [[ -L "$live_file" ]]; then
        # Skip symlinks in live config to avoid surprises
        continue
    fi

    if cmp -s "$fork_file" "$live_file"; then
        continue
    fi

    CHANGED=$((CHANGED + 1))
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Differs: $rel_path"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    diff -u "$fork_file" "$live_file" 2>/dev/null | head -30 || true
    echo ""

    if [[ "$DRY_RUN" == true ]]; then
        echo "  (dry-run, not syncing)"
        echo ""
        continue
    fi

    if [[ "$AUTO_YES" == true ]]; then
        answer="y"
    else
        read -r -p "  Sync live '$rel_path' into fork? [y/N] " answer
    fi

    if [[ "$answer" =~ ^[Yy]$ ]]; then
        cp "$live_file" "$fork_file"
        echo "  ✓ Synced $rel_path"
        SYNCED=$((SYNCED + 1))
    else
        echo "  - Skipped $rel_path"
        SKIPPED=$((SKIPPED + 1))
    fi
    echo ""
done < <(find "$FORK_CONFIG" -type f -print0)

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Done. $CHANGED differed, $SYNCED synced, $SKIPPED skipped."
echo "(Only files already tracked in the fork were ever compared or touched.)"
if [[ $SYNCED -gt 0 ]]; then
    echo ""
    echo "Changes are staged in $FORK_DIR — review with:"
    echo "  cd \"$FORK_DIR\" && git status"
    echo "then commit/push using the Push button, or manually."
fi
