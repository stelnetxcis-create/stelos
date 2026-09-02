#!/usr/bin/env bash
# sync-from-pedro.sh — pull Pedro's latest dev branch into stelos, keep the
# StelOS rebrand.
#
# Run this by hand, whenever you want it, from anywhere:
#   bash sync-tooling/sync-from-pedro.sh
#
# What it does:
#   1. Makes sure a "pedro" remote exists, pointing at his real repo.
#   2. Fetches his dev branch.
#   3. Merges it into your local dev branch using git's real 3-way merge,
#      so untouched files just fast-forward and genuinely new Pedro code
#      merges in cleanly next to your edits.
#   4. If git reports merge conflicts, it STOPS here and lists the files —
#      it does not guess. You resolve those by hand (see the printed
#      instructions), keeping your rebranded lines.
#   5. Once the merge is clean (auto or by your hand), it re-runs
#      reapply-rebrand.sh so any file Pedro touched gets StelOS branding
#      re-applied on top of his new content.
#   6. Shows you a diff summary and stops WITHOUT pushing — you review and
#      push yourself when you're happy.
#
# Nothing here force-pushes or rewrites history. It's a normal merge commit.

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

PEDRO_URL="https://github.com/P3DROVFX/ii-p3drovfx.git"
PEDRO_BRANCH="dev"
LOCAL_BRANCH="dev"

echo "== StelOS <- Pedro sync =="
echo "repo:   $REPO_ROOT"
echo "pedro:  $PEDRO_URL ($PEDRO_BRANCH)"
echo "local:  $LOCAL_BRANCH"
echo ""

if ! git remote get-url pedro >/dev/null 2>&1; then
    echo "-- adding 'pedro' remote"
    git remote add pedro "$PEDRO_URL"
else
    echo "-- 'pedro' remote already configured"
fi

echo "-- fetching pedro/$PEDRO_BRANCH"
git fetch pedro "$PEDRO_BRANCH"

echo "-- checking out local $LOCAL_BRANCH"
git checkout "$LOCAL_BRANCH"

echo "-- merging pedro/$PEDRO_BRANCH into $LOCAL_BRANCH"
if git merge --no-edit "pedro/$PEDRO_BRANCH" -m "Sync: merge pedro/$PEDRO_BRANCH into $LOCAL_BRANCH"; then
    echo "-- merge succeeded with no conflicts"
else
    echo ""
    echo "!! Merge conflicts found. Files needing your attention:"
    git diff --name-only --diff-filter=U | sed 's/^/     /'
    echo ""
    echo "   Open each file, look for <<<<<<< / ======= / >>>>>>> markers."
    echo "   Keep your StelOS-branded lines where the conflict is just"
    echo "   naming (StelOS/ii-stelnet vs P3DROVFX/ii-p3drovfx); take"
    echo "   Pedro's side where it's new logic you don't have."
    echo ""
    echo "   Once resolved:"
    echo "     git add <file...>"
    echo "     git commit"
    echo "     bash sync-tooling/sync-from-pedro.sh --continue"
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
echo "     git commit -m 'Sync from Pedro dev + reapply rebrand'"
echo "     git push origin $LOCAL_BRANCH"
