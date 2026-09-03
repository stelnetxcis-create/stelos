#!/usr/bin/env bash
# reapply-rebrand.sh — turns a fresh checkout of Xenna's working tree into StelOS.
#
# Run this from the repo root AFTER merging/checking out Xenna's latest code
# (e.g. after `git merge xenna/dev`). It is idempotent: running it
# twice in a row on an already-rebranded tree is a safe no-op.
#
# What it does NOT touch, on purpose:
#   - The real upstream clone URL (https://github.com/P3DROVFX/ii-p3drovfx)
#     used internally by setup-ii-stelnet.sh / ChangelogService.qml / etc.
#     to silently pull Xenna's code and commit history.
#   - Any file/script/CLI internal name other than the ones explicitly
#     listed below (ii-p3drovfx -> ii-stelnet, fork id p3drovfx -> stelos).
#   - The dots/.config/quickshell/ii/README.md commit permalinks.
#   - The budslink D-Bus CLIENT_ID (protocol identifier, not branding).
#
# Safe to extend: add new find/replace pairs to the SIMPLE_REPLACEMENTS
# array below for anything that's a plain, unambiguous text swap. Anything
# that needs structural surgery (like the About page card consolidation)
# needs its own function, same pattern as fix_about_config below.

set -euo pipefail
cd "$(dirname "$0")/.."   # repo root, assuming this script lives in ./sync-tooling/

echo "== StelOS rebrand pass =="

# ---------------------------------------------------------------------------
# Step 1: rename the main script file, if a fresh sync re-created it
# under its original name.
# ---------------------------------------------------------------------------
if [[ -f setup-ii-p3drovfx.sh && ! -f setup-ii-stelnet.sh ]]; then
    echo "renaming setup-ii-p3drovfx.sh -> setup-ii-stelnet.sh"
    git mv setup-ii-p3drovfx.sh setup-ii-stelnet.sh
elif [[ -f setup-ii-p3drovfx.sh && -f setup-ii-stelnet.sh ]]; then
    echo "WARNING: both setup-ii-p3drovfx.sh and setup-ii-stelnet.sh exist."
    echo "         The sync likely re-added the old filename. Diff them"
    echo "         by hand: diff setup-ii-p3drovfx.sh setup-ii-stelnet.sh"
fi

if [[ -f dots/.config/quickshell/ii/assets/icons/ii-p3drovfx.png \
   && ! -f dots/.config/quickshell/ii/assets/icons/ii-stelnet.png ]]; then
    echo "renaming icon asset"
    git mv dots/.config/quickshell/ii/assets/icons/ii-p3drovfx.png \
           dots/.config/quickshell/ii/assets/icons/ii-stelnet.png
fi

# ---------------------------------------------------------------------------
# Step 2: setup-ii-stelnet.sh — protect the real upstream URL, then rename
# everything else, then re-point the preset id.
# ---------------------------------------------------------------------------
if [[ -f setup-ii-stelnet.sh ]]; then
    python3 - "setup-ii-stelnet.sh" <<'PYEOF'
import sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    s = f.read()

PLACEHOLDER = "@@SOURCE_URL@@"
real_url = "https://github.com/P3DROVFX/ii-p3drovfx"
s = s.replace(real_url, PLACEHOLDER)

s = s.replace("setup-ii-p3drovfx.sh", "setup-ii-stelnet.sh")
s = s.replace("ii-p3drovfx", "ii-stelnet")
s = s.replace("setup-p3drovfx", "setup-stelnet")

s = s.replace(PLACEHOLDER, real_url)

# preset id p3drovfx -> stelos, but never touch the real_url text itself
s = s.replace('["p3drovfx"]', '["stelos"]')
s = s.replace("fork p3drovfx", "fork stelos")
s = s.replace('[\"' + real_url + '\"]=\"p3drovfx\"', '[\"' + real_url + '\"]=\"stelos\"')

# banner display text
s = s.replace('ui_banner "ii-stelnet"', 'ui_banner "StelNet"')

with open(path, "w", encoding="utf-8") as f:
    f.write(s)
print("  setup-ii-stelnet.sh rebranded")
PYEOF
fi

# ---------------------------------------------------------------------------
# Step 3: update-fork.sh, hyprmerge.sh, hyprset.sh — same legacy-fallback
# pattern every time. Only touch these if they still look like the
# fresh, unrebranded file (i.e. the *primary* config path still says
# ii-p3drovfx) — otherwise we'd clobber our own intentional legacy-fallback
# lines that are SUPPOSED to keep saying ii-p3drovfx.
# ---------------------------------------------------------------------------
HS="sdata/cli/lib/hyprset.sh"
if [[ -f "$HS" ]] && grep -q 'CONFIG_PATH="${HYPRSET_CONFIG:-$XDG_DATA_HOME/ii-p3drovfx/hyprland.conf}"' "$HS"; then
    python3 - "$HS" <<'PYEOF'
import sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    s = f.read()

old_primary = 'CONFIG_PATH="${HYPRSET_CONFIG:-$XDG_DATA_HOME/ii-p3drovfx/hyprland.conf}"'
new_block = (
    'CONFIG_PATH="${HYPRSET_CONFIG:-$XDG_DATA_HOME/ii-stelnet/hyprland.conf}"\n'
    'if [[ ! -f "$CONFIG_PATH" && -f "$XDG_DATA_HOME/ii-p3drovfx/hyprland.conf" ]]; then\n'
    '    CONFIG_PATH="$XDG_DATA_HOME/ii-p3drovfx/hyprland.conf"\n'
)
s = s.replace(
    old_primary + '\nif [[ ! -f "$CONFIG_PATH" && -f "$XDG_DATA_HOME/ii-vynx/hyprland.conf" ]]; then\n',
    new_block + 'elif [[ ! -f "$CONFIG_PATH" && -f "$XDG_DATA_HOME/ii-vynx/hyprland.conf" ]]; then\n'
)
s = s.replace(
    "# Reached as `setup-ii-p3drovfx.sh hyprset ...`, as `ii-p3drovfx hyprset ...`,",
    "# Reached as `setup-ii-stelnet.sh hyprset ...`, as `ii-stelnet hyprset ...`,"
)
s = s.replace(
    "# pre-rename location so a half-migrated install still writes somewhere sane.",
    "# pre-rename locations so a half-migrated install still writes somewhere sane."
)
with open(path, "w", encoding="utf-8") as f:
    f.write(s)
PYEOF
    echo "  hyprset.sh: primary path rebranded, legacy fallbacks preserved"
elif [[ -f "$HS" ]]; then
    echo "  hyprset.sh: already rebranded, left as-is"
fi

for f in update-fork.sh sdata/cli/lib/hyprmerge.sh; do
    [[ -f "$f" ]] || continue
    sed -i \
        -e 's|command -v ii-p3drovfx|command -v ii-stelnet|g' \
        -e 's|ii-p3drovfx hyprset|ii-stelnet hyprset|g' \
        -e 's|ii-p3drovfx/sdata/cli/lib/hyprset\.sh|ii-stelnet/sdata/cli/lib/hyprset.sh|g' \
        "$f"
done
echo "  update-fork.sh / hyprmerge.sh: CLI/path references fixed"

# ---------------------------------------------------------------------------
# Step 4: simple plain-text swaps across known QML/doc files. Each pair is
# FIND -> REPLACE, applied only within the listed files, never globally.
# ---------------------------------------------------------------------------
declare -A SIMPLE_FILE_SWAPS=()

apply_swaps_in_file() {
    local file="$1"; shift
    [[ -f "$file" ]] || return 0
    python3 - "$file" "$@" <<'PYEOF'
import sys
path = sys.argv[1]
pairs = sys.argv[2:]
with open(path, encoding="utf-8") as f:
    s = f.read()
for i in range(0, len(pairs), 2):
    s = s.replace(pairs[i], pairs[i+1])
with open(path, "w", encoding="utf-8") as f:
    f.write(s)
PYEOF
}

apply_swaps_in_file "dots/.config/quickshell/ii/modules/common/Config.qml" \
    "setup-ii-p3drovfx.sh). See AboutConfig.qml." "setup-ii-stelnet.sh). See AboutConfig.qml."

apply_swaps_in_file "dots/.config/quickshell/ii/modules/welcome/WelcomeProjectLinks.qml" \
    "https://github.com/P3DROVFX/ii-p3drovfx\"" "https://github.com/stelnetxcis-create/stelos\"" \
    "https://github.com/P3DROVFX/ii-p3drovfx/wiki\"" "https://github.com/stelnetxcis-create/stelos/wiki\""

apply_swaps_in_file "dots/.config/quickshell/ii/scripts/appStats/README.md" \
    '`setup-ii-p3drovfx.sh`' '`setup-ii-stelnet.sh`'

apply_swaps_in_file "dots/.config/quickshell/ii/scripts/touchGestures/README.md" \
    '`ii-p3drovfx`' '`ii-stelnet`'

apply_swaps_in_file "dots/.config/quickshell/ii/.github/WIDGETS.md" \
    "https://github.com/P3DROVFX/ii-p3drovfx/issues" "https://github.com/stelnetxcis-create/stelos/issues"

apply_swaps_in_file "dots/.config/quickshell/ii/README.md" \
    "git clone --recurse-submodules https://github.com/P3DROVFX/ii-vynx.git" \
    "git clone --recurse-submodules https://github.com/stelnetxcis-create/stelos.git"

echo "  simple doc/QML swaps applied"

# ---------------------------------------------------------------------------
# Step 5: ShellUpdates.qml — paths + default fork/branch.
# ---------------------------------------------------------------------------
SU="dots/.config/quickshell/ii/services/ShellUpdates.qml"
if [[ -f "$SU" ]]; then
    apply_swaps_in_file "$SU" \
        '"/.local/share/ii-p3drovfx/setup-ii-p3drovfx.sh"' '"/.local/share/ii-stelnet/setup-ii-stelnet.sh"' \
        'property string activeBranch: "main"' 'property string activeBranch: "dev"' \
        'property string activeFork: "p3drovfx"' 'property string activeFork: "stelos"' \
        '(parts[1] ?? "").trim() || "main"' '(parts[1] ?? "").trim() || "dev"' \
        '(parts[2] ?? "").trim() || "p3drovfx"' '(parts[2] ?? "").trim() || "stelos"'
    echo "  ShellUpdates.qml rebranded"
fi

# ---------------------------------------------------------------------------
# Step 6: ChangelogService.qml — local search paths only, never OWNER_REPO.
# ---------------------------------------------------------------------------
CS="dots/.config/quickshell/ii/services/ChangelogService.qml"
if [[ -f "$CS" ]]; then
    apply_swaps_in_file "$CS" \
        '$HOME/.local/share/ii-p3drovfx' '$HOME/.local/share/ii-stelnet' \
        '$HOME/Downloads/ii-p3drovfx' '$HOME/Downloads/ii-stelnet'
    echo "  ChangelogService.qml local paths fixed (OWNER_REPO left untouched)"
fi

# ---------------------------------------------------------------------------
# Step 7: AboutConfig.qml — the structural one. Only run the card-merge
# surgery if the old 3-card structure is detected (i.e. the sync
# reintroduced the original "Upstream Info" / "This fork info" cards).
# Otherwise just fix paths/ids/labels, since our consolidated card already
# exists.
# ---------------------------------------------------------------------------
AC="dots/.config/quickshell/ii/modules/settings/configs/AboutConfig.qml"
if [[ -f "$AC" ]]; then
    if grep -q 'Translation.tr("Upstream Info")' "$AC" && grep -q 'Translation.tr("This fork info")' "$AC"; then
        echo "  AboutConfig.qml: old 3-card structure detected from upstream merge."
        echo "  This needs the structural card-consolidation patch reapplied by hand"
        echo "  (or re-run the Claude session that built it) — flagging, not guessing."
        echo "  See: sync-tooling/about-config-card-patch.md"
    fi

    apply_swaps_in_file "$AC" \
        '/.local/share/ii-p3drovfx/setup-ii-p3drovfx.sh' '/.local/share/ii-stelnet/setup-ii-stelnet.sh' \
        '/.local/state/ii-p3drovfx/' '/.local/state/ii-stelnet/' \
        'run setup-ii-p3drovfx.sh' 'run setup-ii-stelnet.sh' \
        '"ii-p3drovfx-action"' '"ii-stelnet-action"' \
        '--unit=ii-p3drovfx-action-' '--unit=ii-stelnet-action-' \
        'assets/icons/ii-p3drovfx.png' 'assets/icons/ii-stelnet.png' \
        '"p3drovfx"' '"stelos"' \
        '"P3DROVFX"' '"StelOS"' \
        'fork p3drovfx' 'fork stelos' \
        'e.g. p3drovfx, end4, vynx' 'e.g. stelos, end4' \
        "Branch switcher is only available on the P3DROVFX fork. Use the CLI for other forks: 'vynx branch <name>'." \
        "Branch switcher is only available on StelOS. Use the CLI for other forks: 'vynx branch <name>'." \
        '// Section: Commit History (kept verbatim)' "// Section: Xenna's Updates (kept verbatim)" \
        'Translation.tr("Commit History")' "Translation.tr(\"Xenna's Updates\")"
    echo "  AboutConfig.qml paths/ids/labels fixed"
fi

echo ""
echo "== Done. Review with: git status && git diff --stat =="
echo "== Then: git add -A && git commit -m 'Sync Xenna work + reapply rebrand' =="
