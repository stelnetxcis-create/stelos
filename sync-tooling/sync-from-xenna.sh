#!/usr/bin/env bash
# sync-from-xenna.sh — pull the latest work into StelOS, keep the rebrand,
# and commit it as a single squashed commit authored as Xenna.
#
# Run this by hand, whenever you want it, from anywhere:
#   bash sync-tooling/sync-from-xenna.sh
#
# What it does:
#   1. Makes sure a source remote is configured for the upstream working
#      branch. This remote is never shown in any commit message, author
#      field, or log output — it only exists locally so git has something
#      to fetch from.
#   2. Fetches the latest dev branch.
#   3. Does a SQUASH merge (`git merge --squash`) into your local dev
#      branch. A squash merge stages the resulting file changes but
#      creates NO individual commits and carries over NO author/committer
#      metadata from the source — the entire history of who wrote what,
#      when, and under what name is discarded. Only the final file
#      contents survive.
#   4. If git reports merge conflicts, it STOPS here and lists the files —
#      it does not guess. You resolve those by hand (see the printed
#      instructions), keeping your StelOS-branded lines.
#   5. Once the merge is clean (auto or by your hand), it re-runs
#      reapply-rebrand.sh so any touched file gets StelOS branding
#      re-applied on top of the new content.
#   6. Commits everything as ONE commit, authored and committed as Xenna
#      (name/email set for this commit only, via -c user.name/user.email —
#      your global git identity is never changed).
#   7. Shows you a diff summary and stops WITHOUT pushing — you review and
#      push yourself when you're happy.
#
# Nothing here force-pushes or rewrites existing history. It's one new,
# normal commit on top of your branch, authored as Xenna.

set -euo pipefail
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

SOURCE_URL="https://github.com/P3DROVFX/ii-p3drovfx.git"
SOURCE_BRANCH="dev"
LOCAL_BRANCH="dev"
REMOTE_NAME="xenna-src"

XENNA_NAME="Xenna"
XENNA_EMAIL="xenna@stelnetxcis-create.local"

echo "== StelOS <- Xenna sync =="
echo "repo:  $REPO_ROOT"
echo "local: $LOCAL_BRANCH"
echo ""

if ! git remote get-url "$REMOTE_NAME" >/dev/null 2>&1; then
    echo "-- configuring source remote"
    git remote add "$REMOTE_NAME" "$SOURCE_URL"
else
    echo "-- source remote already configured"
fi

echo "-- fetching latest work"
git fetch "$REMOTE_NAME" "$SOURCE_BRANCH" --quiet

echo "-- checking out local $LOCAL_BRANCH"
git checkout "$LOCAL_BRANCH"

echo "-- squash-merging latest work into $LOCAL_BRANCH"
# --squash: stages the combined file changes with NO individual commits and
#   NO author/committer metadata carried over — only file contents survive.
# --allow-unrelated-histories: stelos was built from a fresh orphan commit,
#   so git sees no shared ancestry with the source branch even though the
#   content is closely related. Required every time.
if git merge --squash --allow-unrelated-histories "$REMOTE_NAME/$SOURCE_BRANCH"; then
    echo "-- merge staged with no conflicts"
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
    echo "   Once every conflict is resolved:"
    echo "     git add <file...>"
    echo "     bash sync-tooling/reapply-rebrand.sh"
    echo "     git add -A"
    echo "     git -c user.name=\"$XENNA_NAME\" -c user.email=\"$XENNA_EMAIL\" \\"
    echo "         commit -m \"Xenna's latest work\""
    echo "     git push origin $LOCAL_BRANCH"
    exit 1
fi

echo ""
echo "-- reapplying StelOS rebrand on top of the squashed changes"
bash "$REPO_ROOT/sync-tooling/reapply-rebrand.sh"

echo ""
echo "-- staging everything (including rebrand fixes)"
git add -A

if git diff --cached --quiet; then
    echo "-- nothing changed, nothing to commit"
    exit 0
fi

echo "-- committing as $XENNA_NAME (this commit only — your global git identity is untouched)"
git -c user.name="$XENNA_NAME" -c user.email="$XENNA_EMAIL" \
    commit -m "Xenna's latest work"

echo ""
echo "-- what changed:"
git show --stat HEAD | head -20
echo ""
echo "-- cleaning up local sync remote and fetched refs"
git remote remove "$REMOTE_NAME" 2>/dev/null || true
git gc --prune=now --quiet 2>/dev/null || true
echo ""
echo "== Review the diff, then when you're happy: =="
echo "     git push origin $LOCAL_BRANCH"
