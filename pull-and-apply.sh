#!/usr/bin/env bash
# pull-and-apply.sh
#
# Wraps setup-stelos.sh with a compare-first, log-everything workflow:
#   1. Fetches the remote, compares old vs new commit (what actually changed)
#   2. Runs setup-stelos.sh --no-confirm (which itself backs up
#      ~/.config/quickshell before applying the pulled changes)
#   3. Writes a full timestamped report to
#      ~/.local/share/ii-stelos/reports/pull_<timestamp>.log
#
# No pause/confirmation - this logs what changed informationally, then
# applies automatically, per design.

set -uo pipefail

STELOS_DIR="${1:-$HOME/.local/share/ii-stelos}"
REPORTS_DIR="$STELOS_DIR/reports"
TS="$(date +%Y%m%d_%H%M%S)"
REPORT_FILE="$REPORTS_DIR/pull_${TS}.log"
STATUS_FILE="$(mktemp)"

mkdir -p "$REPORTS_DIR"

{
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  StelOS Pull Report — $(date)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [[ ! -d "$STELOS_DIR/.git" ]]; then
        echo "✗ $STELOS_DIR is not a git repo yet. Run the initial clone first."
        echo "1" > "$STATUS_FILE"
    else
        cd "$STELOS_DIR"

        OLD_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo "")"
        echo "Current commit before pull: ${OLD_COMMIT:-<none>}"
        echo ""

        DEFAULT_BRANCH="$(git remote show origin 2>/dev/null | sed -n '/HEAD branch/s/.*: //p')"
        if [[ -z "$DEFAULT_BRANCH" ]]; then
            DEFAULT_BRANCH="main"
            echo "(Could not detect default branch, assuming '$DEFAULT_BRANCH')"
        fi

        echo "── Fetching remote ──────────────────────────────"
        if git fetch origin 2>&1; then
            NEW_COMMIT="$(git rev-parse "origin/$DEFAULT_BRANCH" 2>/dev/null || echo "")"
            echo ""
            if [[ -z "$NEW_COMMIT" ]]; then
                echo "✗ Could not resolve origin/$DEFAULT_BRANCH — skipping comparison."
                echo ""
            elif [[ -z "$OLD_COMMIT" || "$OLD_COMMIT" == "$NEW_COMMIT" ]]; then
                echo "No new commits. Already up to date."
                echo ""
            else
                echo "── What changed (commits) ───────────────────────"
                git log --oneline "$OLD_COMMIT..$NEW_COMMIT" 2>&1
                echo ""
                echo "── What changed (files) ──────────────────────────"
                git diff --stat "$OLD_COMMIT..$NEW_COMMIT" 2>&1
                echo ""
            fi
        else
            echo "✗ Fetch failed — check network connectivity."
            echo ""
        fi

        echo "── Applying (setup-stelos.sh) ────────────────────"
        if bash "$STELOS_DIR/setup-stelos.sh" --no-confirm 2>&1; then
            echo ""
            echo "✓ Apply completed successfully."
            echo "0" > "$STATUS_FILE"
        else
            echo ""
            echo "✗ Apply failed — see output above."
            echo "1" > "$STATUS_FILE"
        fi
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Report saved to: $REPORT_FILE"
} | tee "$REPORT_FILE"

FINAL_EXIT="$(cat "$STATUS_FILE" 2>/dev/null || echo 1)"
rm -f "$STATUS_FILE"
exit "$FINAL_EXIT"
