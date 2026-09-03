#!/usr/bin/env bash
# sync-from-xenna.sh — pull Xenna's latest work into StelOS, keep the rebrand.
#
# Run this by hand, whenever you want it, from anywhere:
#   bash sync-tooling/sync-from-xenna.sh
#
# What it does:
#   1. Makes sure a source remote is configured for Xenna's working branch.
#   2. Fetches the latest dev branch.
#   3. Merges it into your local dev branch using git's real 3-way merge,
#      so untouched files just fast-forward and genuinely new work merges
#      in cleanly next to your edits.
#   4. If git reports merge conflicts, it STOPS here and lists the files —
#      it does not guess. You resolve those by hand (see the printed
#      instructions), keeping your StelOS-branded lines.
#   5. Once the merge is clean (auto or by your hand), it re-runs
#      reapply-rebrand.sh so any touched file gets StelOS branding
#      re-applied on top of the new content.
#   6. Shows you a diff summary and stops WITHOUT pushing — you review and
#      push yourself when you're happy.
#
# Nothing here force-pushes or rewrites history. It's a normal merge commit.

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SOURCE_URL="https://github.com/P3DROVFX/ii-p3drovfx.git"
SOURCE_BRANCH="dev"
LOCAL_BRANCH="dev"
REMOTE_NAME="xenna"

echo "== StelOS <- Xenna sync =="
echo "repo:   $REPO_ROOT"
echo "source: $REMOTE_NAME ($SOURCE_BRANCH)"
echo "local:  $LOCAL_BRANCH"
echo ""

if ! git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
    echo "-- adding '$REMOTE_NAME' remote"
    git remote add "$REMOTE_NAME" "$SOURCE_URL"
else
    echo "-- '$REMOTE_NAME' remote already configured"
fi

echo "-- fetching $REMOTE_NAME/$SOURCE_BRANCH"
git fetch "$REMOTE_NAME" "$SOURCE_BRANCH"

echo "-- checking out local $LOCAL_BRANCH"
git checkout "$LOCAL_BRANCH"

echo "-- merging $REMOTE_NAME/$SOURCE_BRANCH into $LOCAL_BRANCH"
# --allow-unrelated-histories: stelos was built from a fresh orphan commit,
# so git sees no shared ancestry with the source branch even though the
# content is closely related. This flag is required every time; it is not
# a one-off fix.
if git merge --allow-unrelated-histories --no-edit "$REMOTE_NAME/$SOURCE_BRANCH" \
    -m "Sync: merge latest Xenna work into $LOCAL_BRANCH"; then
    echo "-- merge succeeded with no conflicts"
else
    echo ""
    echo "!! Merge conflicts found. Files needing your attention:"
    git diff --name-only --diff-filter=U | sed 's/^/     /'
    echo ""
    echo "   Open each file, look for <<<<<<< / ======= / >>>>>>> markers."
    echo "   Keep your StelOS-branded lines where the conflict is just"
    echo "   naming (StelOS/ii-stelnet vs the old names); take the"
    echo "   incoming side where it's new logic you don't have yet."
    echo ""
    echo "   Once resolved:"
    echo "     git add <file...>"
    echo "     git commit"
    echo "     bash sync-tooling/sync-from-xenna.sh --continue"
    exit 1
fi

echo ""
echo "-- reapplying StelOS rebrand on top of the merge"
bash "$REPO_ROOT/sync-tooling/reapply-rebrand.sh"

echo ""
echo "-- what changed:"
git status --short
echo ""
echo "== Review the diff, then when you're happy: =="
echo "     git add -A"
echo "     git commit -m 'Sync Xenna work + reapply rebrand'"
echo "     git push origin $LOCAL_BRANCH"
