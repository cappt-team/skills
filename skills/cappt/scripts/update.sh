#!/usr/bin/env bash
# update.sh - Update cappt CLI to the latest version (macOS / Linux)
# Usage: bash update.sh [--yes]
set -euo pipefail

BIN_NAME="cappt"
GITHUB_REPO="cappt-team/skills"
GITHUB_API="https://api.github.com/repos/${GITHUB_REPO}/releases"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }

auto_yes="no"
for arg in "$@"; do
    case "$arg" in
        --yes|-y) auto_yes="yes" ;;
        --help|-h)
            echo "Usage: bash update.sh [--yes]"
            exit 0 ;;
        *) log_error "Unknown argument: $arg"; exit 2 ;;
    esac
done

if ! command -v "$BIN_NAME" &>/dev/null; then
    log_error "cappt is not installed. Run install.sh first."
    exit 1
fi

BIN_PATH="$(command -v "$BIN_NAME")"
BIN_PATH="$(readlink -f "$BIN_PATH" 2>/dev/null || realpath "$BIN_PATH" 2>/dev/null || echo "$BIN_PATH")"
CURRENT_VER="$(cappt version 2>/dev/null || echo "unknown")"
log_info "Current version: ${CURRENT_VER}  Path: ${BIN_PATH}"

detect_os() {
    local os; os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$os" in
        darwin) echo "darwin" ;;
        linux)  echo "linux" ;;
        *)      log_error "Unsupported OS: $os"; exit 1 ;;
    esac
}

detect_arch() {
    local arch; arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)  echo "amd64" ;;
        arm64|aarch64) echo "arm64" ;;
        *)             log_error "Unsupported architecture: $arch"; exit 1 ;;
    esac
}

OS="$(detect_os)"
ARCH="$(detect_arch)"
PLATFORM="${OS}-${ARCH}"

log_info "Checking for updates..."

if command -v curl &>/dev/null; then
    releases_json=$(curl -fsSL --connect-timeout 30 "$GITHUB_API")
elif command -v wget &>/dev/null; then
    releases_json=$(wget -q --timeout=30 -O - "$GITHUB_API")
else
    log_error "curl or wget is required"
    exit 1
fi

LATEST_TAG="$(echo "$releases_json" | grep -o '"tag_name":"v[^"]*"' | head -1 | grep -o 'v[^"]*')"
if [[ -z "$LATEST_TAG" ]]; then
    log_error "No release found (expected tag format: v*)"
    exit 1
fi
LATEST_VER="${LATEST_TAG#v}"
log_info "Latest version: ${LATEST_VER}"

version_gt() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | tail -1)" = "$1" ] && [ "$1" != "$2" ]
}

if ! version_gt "$LATEST_VER" "$CURRENT_VER"; then
    log_ok "Already up to date (${CURRENT_VER})"
    exit 0
fi

RELEASE_BASE="https://github.com/${GITHUB_REPO}/releases/download/${LATEST_TAG}"
DOWNLOAD_URL="${RELEASE_BASE}/${BIN_NAME}-${PLATFORM}"
CHECKSUMS_URL="${RELEASE_BASE}/checksums.txt"

echo ""
echo "  Current: ${CURRENT_VER}"
echo "  Latest:  ${LATEST_VER}"
echo "  Path:    ${BIN_PATH}"
echo ""

if [[ "$auto_yes" != "yes" ]]; then
    read -r -p "Confirm update? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_warn "Update cancelled"
        exit 0
    fi
fi

TMP_DIR="$(mktemp -d)"
TMP_BIN="${TMP_DIR}/${BIN_NAME}"
TMP_CHECKSUMS="${TMP_DIR}/checksums.txt"
cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

log_info "Downloading cappt CLI v${LATEST_VER}..."
if command -v curl &>/dev/null; then
    curl -fsSL --connect-timeout 30 -o "$TMP_BIN" "$DOWNLOAD_URL" || { log_error "Download failed"; exit 1; }
else
    wget -q --timeout=30 -O "$TMP_BIN" "$DOWNLOAD_URL" || { log_error "Download failed"; exit 1; }
fi

log_info "Fetching checksums..."
if command -v curl &>/dev/null; then
    curl -fsSL --connect-timeout 30 -o "$TMP_CHECKSUMS" "$CHECKSUMS_URL" 2>/dev/null || TMP_CHECKSUMS=""
else
    wget -q --timeout=30 -O "$TMP_CHECKSUMS" "$CHECKSUMS_URL" 2>/dev/null || TMP_CHECKSUMS=""
fi

if [[ -n "$TMP_CHECKSUMS" && -f "$TMP_CHECKSUMS" ]]; then
    log_info "Verifying integrity..."
    EXPECTED="$(grep "${BIN_NAME}-${PLATFORM}" "$TMP_CHECKSUMS" | awk '{print $1}')"
    if [[ -z "$EXPECTED" ]]; then
        log_warn "No checksum entry for ${PLATFORM}, skipping verification"
    else
        if command -v shasum &>/dev/null; then
            ACTUAL="$(shasum -a 256 "$TMP_BIN" | awk '{print $1}')"
        elif command -v sha256sum &>/dev/null; then
            ACTUAL="$(sha256sum "$TMP_BIN" | awk '{print $1}')"
        else
            log_warn "shasum/sha256sum not found, skipping verification"
            ACTUAL="$EXPECTED"
        fi
        if [[ "$ACTUAL" != "$EXPECTED" ]]; then
            log_error "SHA256 mismatch!"
            log_error "  Expected: $EXPECTED"
            log_error "  Actual:   $ACTUAL"
            exit 1
        fi
        log_ok "Integrity check passed"
    fi
else
    log_warn "Could not fetch checksums, skipping verification"
fi

chmod +x "$TMP_BIN"
cp "$TMP_BIN" "$BIN_PATH"

log_ok "cappt CLI updated to v${LATEST_VER}: ${BIN_PATH}"
