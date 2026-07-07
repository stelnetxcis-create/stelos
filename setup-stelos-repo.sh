#!/usr/bin/env bash
# setup-stelos-repo.sh
#
# Ensures ~/.local/share/ii-stelos exists as a local clone of
# github.com/stelnetxcis-create/stelos. Safe to run repeatedly:
# - If the folder doesn't exist: clones fresh.
# - If it exists and is already the right repo: does nothing.
# - If it exists but isn't a git repo, or points elsewhere: stops and
#   reports the conflict rather than overwriting anything.

set -euo pipefail

STELOS_DIR="${1:-$HOME/.local/share/ii-stelos}"
STELOS_REMOTE="https://github.com/stelnetxcis-create/stelos"

if [[ -d "$STELOS_DIR/.git" ]]; then
    EXISTING_REMOTE="$(git -C "$STELOS_DIR" remote get-url origin 2>/dev/null || echo "")"
    if [[ "$EXISTING_REMOTE" == *"stelnetxcis-create/stelos"* ]]; then
        echo "✓ $STELOS_DIR already exists and points at stelos. Nothing to do."
        exit 0
    else
        echo "✗ $STELOS_DIR exists but points at a different remote:"
        echo "    $EXISTING_REMOTE"
        echo "  Not touching it. Remove or rename it manually if you want to re-clone here."
        exit 1
    fi
elif [[ -e "$STELOS_DIR" ]]; then
    echo "✗ $STELOS_DIR exists but is not a git repo. Not touching it."
    echo "  Remove or rename it manually, then re-run this script."
    exit 1
fi

echo "Cloning $STELOS_REMOTE into $STELOS_DIR ..."
mkdir -p "$(dirname "$STELOS_DIR")"
git clone "$STELOS_REMOTE" "$STELOS_DIR"
echo "✓ Cloned. StelOS fork is ready at $STELOS_DIR"
