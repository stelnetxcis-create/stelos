#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[1;36m'
NC='\033[0m'

# ── Resolve absolute path of this script (handles symlinks) ──────────────────
SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SOURCE" ]; do
    DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"
    SOURCE="$(readlink "$SOURCE")"
    [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SOURCE")" >/dev/null 2>&1 && pwd)"

# ── Log to file for debugging (called from QML Process) ─────────────────────
exec > >(tee -a /tmp/stelos-install.log) 2>&1
echo "--- Starting setup at $(date) | args: $* ---"
echo "SCRIPT_DIR: $SCRIPT_DIR"

# ── CLI sub-command dispatcher (when invoked as \"stelos\") ──────────────────
INVOKED_AS="$(basename "$0")"
if [[ "$INVOKED_AS" == "stelos" ]]; then
    LIB_DIR="$SCRIPT_DIR/sdata/cli/lib"
    BASE_DIR="$SCRIPT_DIR"
    VERBOSE=false
    TEMP_ARGS=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--verbose) VERBOSE=true; shift ;;
            *) TEMP_ARGS+=("$1"); shift ;;
        esac
    done
    set -- "${TEMP_ARGS[@]}"

    COMMAND="$1"; shift
    case "$COMMAND" in
        run|restart|update|remove-cli|hyprset)
            if [ -f "$LIB_DIR/${COMMAND}.sh" ]; then
                source "$LIB_DIR/${COMMAND}.sh" "$@"
                exit $?
            else
                echo -e "${RED}Error: $COMMAND not found${NC}"; exit 1
            fi
            ;;
        "")
            echo "Usage: stelos [-v] {run|restart|update|remove-cli|hyprset}"; exit 1 ;;
        *)
            echo -e "${RED}Invalid command: $COMMAND${NC}"; exit 1 ;;
    esac
fi

# ── Default flags ────────────────────────────────────────────────────────────
DO_PULL=true
VERBOSE=false
FORCE_INSTALL=false
BACKUP=true
FULL_INSTALL=false
NO_CONFIRM=false
USE_UPSTREAM=false
UPDATE_ONLY=false
PRESERVE_CONFIG=false
DELETE_CACHE=false
REBUILD_QS=false

FALLBACK_TO_PEDRO=false
PEDRO_REMOTE_URL="https://github.com/P3DROVFX/ii-stelos.git"
STELOS_REMOTE_URL="https://github.com/stelnetxcis-create/stelos.git"
FORK_DIR=""
STANDARD_SCRIPT_DIR="$HOME/.local/share/stelos"

# ── Helper functions ─────────────────────────────────────────────────────────
log() {
    echo -e "${GREEN}[stelos]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[warn]${NC} $1"
}

quit() {
    echo -e "${RED}$1${NC}"
    exit 1
}

confirm() {
    if [ "$NO_CONFIRM" = "true" ]; then
        return 0
    fi
    read -p "$1 (y/N): " -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# ── Parse options ────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-pull) DO_PULL=false; shift ;;
        -v|--verbose) VERBOSE=true; shift ;;
        --force-install) FORCE_INSTALL=true; shift ;;
        --no-backup) BACKUP=false; shift ;;
        --full-install) FULL_INSTALL=true; shift ;;
        --no-confirm) NO_CONFIRM=true; shift ;;
        --upstream) USE_UPSTREAM=true; shift ;;
        --update-only) UPDATE_ONLY=true; shift ;;
        --preserve-config) PRESERVE_CONFIG=true; shift ;;
        --delete-cache) DELETE_CACHE=true; shift ;;
        --rebuild-qs) REBUILD_QS=true; ;;
        --stucos) FALLBACK_TO_PEDRO=true; shift ;;
        *)
            if [[ -z "$1" ]]; then
                shift
                continue
            fi
            quit "Unknown option: $1"
            ;;
    esac
done

# ── Detect fork directory ────────────────────────────────────────────────────
if [ -n "$FORK_DIR" ] && [ -d "$FORK_DIR/.git" ]; then
    :
elif [ -d "$SCRIPT_DIR/.git" ]; then
    FORK_DIR="$SCRIPT_DIR"
elif [ -d "$HOME/.local/share/stelos-fork" ]; then
    FORK_DIR="$HOME/.local/share/stelos-fork"
elif [ -d "$HOME/Downloads/stelos/.git" ]; then
    FORK_DIR="$HOME/Downloads/stelos"
elif [ -d "$HOME/Downloads/ii-stelos/.git" ]; then
    FORK_DIR="$HOME/Downloads/ii-stelos"
else
    FORK_DIR="$SCRIPT_DIR"
fi

log "Detected fork dir: $FORK_DIR"

# ── Banner ───────────────────────────────────────────────────────────────────
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "          StelOS setup      "
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# ── Sync setup script to standard location ───────────────────────────────────
log "Syncing setup script to standard location..."
mkdir -p "$HOME/.local/share"
if [ "$FORCE_INSTALL" = "true" ] || [ ! -f "$STANDARD_SCRIPT_DIR/setup-stelos.sh" ]; then
    mkdir -p "$STANDARD_SCRIPT_DIR"
    cp "$0" "$STANDARD_SCRIPT_DIR/setup-stelos.sh"
    chmod +x "$STANDARD_SCRIPT_DIR/setup-stelos.sh"
    log "Script installed to $STANDARD_SCRIPT_DIR"
else
    log "Script already present in $STANDARD_SCRIPT_DIR"
fi

# ── Update fork / upstream ───────────────────────────────────────────────────
log "Updating your fork..."
cd "$FORK_DIR" || quit "Fork directory not found: $FORK_DIR"

if [ "$USE_UPSTREAM" = "true" ]; then
    TARGET_URL="$STELOS_REMOTE_URL"
    TARGET_DIR="$FORK_DIR"
elif [ "$FALLBACK_TO_PEDRO" = "true" ]; then
    TARGET_URL="$PEDRO_REMOTE_URL"
    TARGET_DIR="$FORK_DIR"
else
    TARGET_URL="$STELOS_REMOTE_URL"
    TARGET_DIR="$FORK_DIR"
fi

if [ "$DO_PULL" = "true" ]; then
    CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    if [ "$CURRENT_REMOTE" != "$TARGET_URL" ]; then
        git remote set-url origin "$TARGET_URL" || true
    fi
    git fetch origin || warn "Fetch failed; continuing with local files"
    if [ "$USE_UPSTREAM" = "true" ] || [ "$FALLBACK_TO_PEDRO" = "true" ]; then
        git reset --hard origin/main || warn "Reset failed; keeping local files"
    else
        git pull --rebase origin main || warn "Pull failed; keeping local files"
    fi
else
    log "Skipping git pull (--no-pull)"
fi

if [ "$UPDATE_ONLY" = "true" ]; then
    log "Update-only mode; exiting."
    exit 0
fi

# ── Submodules ───────────────────────────────────────────────────────────────
log "Syncing submodules..."
git submodule update --init --recursive

SUBMODULE_OK=true
while IFS= read -r submodule_path; do
    [[ -z "$submodule_path" ]] && continue
    full_path="$FORK_DIR/$submodule_path"
    if [[ ! -d "$full_path" ]] || [[ -z "$(ls -A "$full_path" 2>/dev/null)" ]]; then
        warn "Submodule '$submodule_path' is empty, retrying..."
        git submodule update --init --recursive --force -- "$submodule_path"
        if [[ ! -d "$full_path" ]] || [[ -z "$(ls -A "$full_path" 2>/dev/null)" ]]; then
            warn "Submodule '$submodule_path' still empty after retry."
            SUBMODULE_OK=false
        fi
    fi
done < <(git config -f .gitmodules --get-regexp path 2>/dev/null | awk '{print $2}')

if [ "$SUBMODULE_OK" = "false" ]; then
    quit "One or more submodules failed to populate. Not applying config (this would leave your install broken). Check your network connection and re-run this script."
fi

# ── Install ──────────────────────────────────────────────────────────────────
TARGET_INSTALL_DIR="$FULL_INSTALL" && true
if [ -z "$TARGET_INSTALL_DIR" ]; then
    TARGET_INSTALL_DIR="$HOME/.config/quickshell"
fi

log "This will switch your Quickshell config to:"
log "  $FORK_DIR/dots/.config/quickshell"
echo
log "Protected files (About.qml, .env) will NOT be overwritten."
echo

if ! confirm "Continue?"; then
    echo "Cancelled"
    exit 0
fi

TS=$(date +%Y%m%d_%H%M%S)

# ── Backup current config ────────────────────────────────────────────────────
if [ "$BACKUP" = "true" ] && [ -d "$HOME/.config/quickshell" ]; then
    BACKUP_PATH="$HOME/.config/quickshell_backup_$TS"
    log "Backing up current config to: $BACKUP_PATH"
    cp -a "$HOME/.config/quickshell" "$BACKUP_PATH"
fi

# ── Apply dotfiles ───────────────────────────────────────────────────────────
log "Applying dotfiles..."
mkdir -p "$HOME/.config"
rm -rf "$HOME/.config/quickshell"
cp -a "$FORK_DIR/dots/.config/quickshell" "$HOME/.config/quickshell"

# ── Restore protected files if present ───────────────────────────────────────
if [ -f "$BACKUP_PATH/.config/quickshell/About.qml" ]; then
    cp "$BACKUP_PATH/.config/quickshell/About.qml" "$HOME/.config/quickshell/About.qml"
fi
if [ -f "$BACKUP_PATH/.config/quickshell/.env" ]; then
    cp "$BACKUP_PATH/.config/quickshell/.env" "$HOME/.config/quickshell/.env"
fi

# ── Rebuild Quickshell if requested ─────────────────────────────────────────
if [ "$REBUILD_QS" = "true" ]; then
    log "Rebuilding Quickshell..."
    if command -v paru >/dev/null 2>&1; then
        paru -S --noconfirm quickshell-git || warn "Rebuild via paru failed"
    elif command -v yay >/dev/null 2>&1; then
        yay -S --noconfirm quickshell-git || warn "Rebuild via yay failed"
    else
        warn "No AUR helper found; please rebuild Quickshell manually"
    fi
fi

# ── Restart Quickshell ───────────────────────────────────────────────────────
log "Restarting Quickshell..."
pkill -f quickshell || true
sleep 0.5
if command -v systemctl --user >/dev/null 2>&1; then
    systemctl --user restart quickshell.service || true
fi
nohup quickshell >/tmp/quickshell.log 2>&1 &
disown

log "Setup completed successfully."
