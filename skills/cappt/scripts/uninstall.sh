#!/usr/bin/env bash
# uninstall.sh - Remove cappt CLI and local config (macOS / Linux)
# Usage: bash uninstall.sh [--yes]
set -euo pipefail

BIN_NAME="cappt"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

auto_yes="no"
for arg in "$@"; do
    case "$arg" in
        --yes|-y) auto_yes="yes" ;;
        --help|-h) echo "Usage: bash uninstall.sh [--yes]"; exit 0 ;;
        *) log_error "Unknown argument: $arg"; exit 2 ;;
    esac
done

if ! command -v "$BIN_NAME" &>/dev/null; then
    log_warn "cappt is not installed"
    exit 0
fi

BIN_PATH="$(command -v "$BIN_NAME")"
BIN_PATH="$(readlink -f "$BIN_PATH" 2>/dev/null || realpath "$BIN_PATH" 2>/dev/null || echo "$BIN_PATH")"
CFG_DIR="${HOME}/.config/cappt"

echo ""
echo "  The following will be removed:"
echo "  [binary] ${BIN_PATH}"
[[ -d "$CFG_DIR" ]] && echo "  [config] ${CFG_DIR}"
echo ""

if [[ "$auto_yes" != "yes" ]]; then
    read -r -p "Confirm uninstall? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_warn "Uninstall cancelled"
        exit 0
    fi
fi

if [[ -d "$CFG_DIR" ]]; then
    rm -rf "$CFG_DIR"
    log_ok "Removed config: ${CFG_DIR}"
fi

rm -f "$BIN_PATH"
log_ok "Removed binary: ${BIN_PATH}"

echo ""
log_ok "Uninstall complete"
