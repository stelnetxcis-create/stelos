#!/usr/bin/env bash
# get-commit-history.sh
#
# Finds the local StelOS repo, determines its GitHub owner/repo, and prints
# the last 10 commits (prefers live GitHub API, falls back to local git log).
# Output format: sha<0x1f>title<0x1f>relative_date<0x1f>body<0x1e>
#
# Candidate directories are checked in priority order - ii-stelos first,
# since that's the actual StelOS repo. Older ii-vynx paths are kept as
# fallbacks only for machines that haven't migrated yet.

set -uo pipefail

REPO_PATH_ARG="${1:-}"

CANDIDATES=(
    "$REPO_PATH_ARG"
    "$HOME/.local/share/ii-stelos"
    "$HOME/Downloads/ii-vynx"
    "$HOME/.local/share/ii-vynx-fork"
    "$HOME/.local/share/ii-vynx-upstream"
    "$HOME/.local/share/ii-vynx"
    "$HOME/dotfiles"
)

MATCHED_DIR=""
for dir in "${CANDIDATES[@]}"; do
    [[ -z "$dir" ]] && continue
    if git -C "$dir" rev-parse --is-inside-work-tree &>/dev/null; then
        MATCHED_DIR="$dir"
        break
    fi
done

OWNER_REPO="stelnetxcis-create/stelos"
if [[ -n "$MATCHED_DIR" ]]; then
    REMOTE_URL="$(git -C "$MATCHED_DIR" remote get-url origin 2>/dev/null || echo "")"
    if [[ -n "$REMOTE_URL" ]]; then
        OWNER_REPO="$(echo "$REMOTE_URL" | sed -E 's#.*github\.com[/:]##; s#\.git$##')"
    fi
fi

API_URL="https://api.github.com/repos/$OWNER_REPO/commits?per_page=10"
API_DATA="$(curl -s --connect-timeout 3 --max-time 5 "$API_URL" 2>/dev/null || echo "")"

if [[ -n "$API_DATA" ]] && echo "$API_DATA" | python3 -c '
import sys, json, datetime
try:
    data = json.load(sys.stdin)
    if not isinstance(data, list):
        sys.exit(1)
    for item in data[:10]:
        sha = item["sha"][:8]
        message = item["commit"]["message"] or ""
        parts = message.splitlines()
        title = parts[0].strip() if parts else ""
        body = chr(10).join(parts[1:]).strip() if len(parts) > 1 else ""
        iso_str = item["commit"]["author"]["date"]
        dt = datetime.datetime.strptime(iso_str, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=datetime.timezone.utc)
        now = datetime.datetime.now(datetime.timezone.utc)
        diff_sec = int((now - dt).total_seconds())
        diff_min = diff_sec // 60
        diff_hr = diff_min // 60
        diff_day = diff_hr // 24
        diff_wk = diff_day // 7
        diff_mon = diff_day // 30
        if diff_sec < 60: date_str = "just now"
        elif diff_min < 60: date_str = str(diff_min) + (" minute ago" if diff_min == 1 else " minutes ago")
        elif diff_hr < 24: date_str = str(diff_hr) + (" hour ago" if diff_hr == 1 else " hours ago")
        elif diff_day < 7: date_str = "yesterday" if diff_day == 1 else str(diff_day) + " days ago"
        elif diff_wk < 4: date_str = "1 week ago" if diff_wk == 1 else str(diff_wk) + " weeks ago"
        else: date_str = "1 month ago" if diff_mon <= 1 else str(diff_mon) + " months ago"
        sys.stdout.write(sha + chr(31) + title + chr(31) + date_str + chr(31) + body + chr(30))
except Exception:
    sys.exit(1)
' 2>/dev/null; then
    exit 0
fi

# Fallback: local git log if the API call failed or returned nothing usable
if [[ -n "$MATCHED_DIR" ]]; then
    git -C "$MATCHED_DIR" log -n 10 --pretty="format:%h%x1f%s%x1f%ar%x1f%b%x1e"
else
    git log -n 10 --pretty="format:%h%x1f%s%x1f%ar%x1f%b%x1e" 2>/dev/null
fi
