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

if git diff --quiet && git diff --cached --quiet && [[ -z "$(git status --porcelain)" ]]; then
    echo "Nothing to commit — working tree is clean."
    exit 0
fi

git add -A

if git diff --cached --quiet; then
    echo "Nothing staged to commit after add."
    exit 0
fi

git commit -m "$COMMIT_MSG"

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
