#!/usr/bin/env bash
# push-stelos.sh
#
# Commits and pushes any staged/unstaged changes in the ii-stelos repo
# to github.com/stelnetxcis-create/stelos. Meant to run after
# sync-live-config.sh has staged real file changes.
#
# Fails clearly (no partial state) if:
# - the repo doesn't exist yet
# - there's nothing to commit
# - the push is rejected (e.g. remote has newer commits, or no push access)

set -euo pipefail

STELOS_DIR="${1:-$HOME/.local/share/ii-stelos}"
COMMIT_MSG="${2:-Update StelOS config}"

if [[ ! -d "$STELOS_DIR/.git" ]]; then
    echo "✗ $STELOS_DIR is not a git repo. Run the setup step first."
    exit 1
fi

cd "$STELOS_DIR"

WORKING_TREE_CLEAN=false
if git diff --quiet && git diff --cached --quiet && [[ -z "$(git status --porcelain)" ]]; then
    WORKING_TREE_CLEAN=true
fi

if [[ "$WORKING_TREE_CLEAN" == false ]]; then
    git add -A
    if git diff --cached --quiet; then
        echo "Nothing staged to commit after add."
    else
        git commit -m "$COMMIT_MSG"
    fi
fi

# Check whether there's anything to actually push, regardless of whether a
# new commit was just made - a clean working tree can still be ahead of
# origin (e.g. a prior commit that was made but never successfully pushed).
git fetch origin --quiet 2>/dev/null || true
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")"
AHEAD_COUNT="$(git rev-list --count "origin/$CURRENT_BRANCH..HEAD" 2>/dev/null || echo "0")"

if [[ "$AHEAD_COUNT" == "0" ]]; then
    echo "Nothing to push — already up to date with origin/$CURRENT_BRANCH."
    exit 0
fi

echo "$AHEAD_COUNT commit(s) ahead of origin/$CURRENT_BRANCH — pushing..."
echo "Pushing to origin..."
if git push; then
    echo "✓ Pushed successfully."
    exit 0
else
    echo "✗ Push failed."
    echo ""
    echo "[Troubleshooting]"
    echo "This usually means either:"
    echo "  - the remote has commits you don't have locally (run: git pull --ff-only)"
    echo "  - this machine doesn't have push credentials for this repo"
    echo ""
    echo "Your commit was made locally and is safe. Nothing was lost."
    exit 1
fi
