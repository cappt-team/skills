#!/usr/bin/env bash
# install.sh - Download and install cappt CLI (macOS / Linux)
# Usage: bash install.sh [--yes] [--force]
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
force="no"

for arg in "$@"; do
    case "$arg" in
        --yes|-y)   auto_yes="yes" ;;
        --force|-f) force="yes" ;;
        --help|-h)
            echo "Usage: bash install.sh [options]"
            echo ""
            echo "Options:"
            echo "  --yes,   -y   Non-interactive mode, skip confirmation"
            echo "  --force, -f   Reinstall even if already installed"
            echo "  --help,  -h   Show this help"
            exit 0 ;;
        *) log_error "Unknown argument: $arg"; exit 2 ;;
    esac
done

detect_os() {
    local os
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$os" in
        darwin) echo "darwin" ;;
        linux)  echo "linux" ;;
        *)      log_error "Unsupported OS: $os (Windows users: use install.ps1)"; exit 1 ;;
    esac
}

detect_arch() {
    local arch
    arch="$(uname -m)"
    case "$arch" in
        x86_64|amd64)   echo "amd64" ;;
        arm64|aarch64)  echo "arm64" ;;
        *)              log_error "Unsupported CPU architecture: $arch"; exit 1 ;;
    esac
}

OS="$(detect_os)"
ARCH="$(detect_arch)"
PLATFORM="${OS}-${ARCH}"
INSTALL_DIR="${HOME}/.local/bin"
BIN_PATH="${INSTALL_DIR}/${BIN_NAME}"

if command -v "$BIN_NAME" &>/dev/null && [[ "$force" != "yes" ]]; then
    INSTALLED_VER="$(cappt version 2>/dev/null || echo "unknown")"
    log_warn "cappt is already installed (version: $INSTALLED_VER)"
    log_warn "Use --force to reinstall"
    exit 0
fi

log_info "Fetching latest version..."

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
CLI_VERSION="${LATEST_TAG#v}"

RELEASE_BASE="https://github.com/${GITHUB_REPO}/releases/download/${LATEST_TAG}"
DOWNLOAD_URL="${RELEASE_BASE}/${BIN_NAME}-${PLATFORM}"

echo ""
echo "  Installing cappt CLI v${CLI_VERSION}"
echo "  Platform: ${PLATFORM}"
echo "  Destination: ${BIN_PATH}"
echo "  Source: ${DOWNLOAD_URL}"
echo ""

if [[ "$auto_yes" != "yes" ]]; then
    read -r -p "Confirm installation? [y/N] " confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        log_warn "Installation cancelled"
        exit 0
    fi
fi

TMP_DIR="$(mktemp -d)"
TMP_BIN="${TMP_DIR}/${BIN_NAME}"
TMP_CHECKSUMS="${TMP_DIR}/checksums.txt"

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT

log_info "Downloading cappt CLI v${CLI_VERSION}..."

if command -v curl &>/dev/null; then
    curl -fsSL --connect-timeout 30 -o "$TMP_BIN" "$DOWNLOAD_URL" || {
        log_error "Download failed: $DOWNLOAD_URL"
        exit 1
    }
else
    wget -q --timeout=30 -O "$TMP_BIN" "$DOWNLOAD_URL" || {
        log_error "Download failed: $DOWNLOAD_URL"
        exit 1
    }
fi

log_info "Fetching checksums..."
CHECKSUMS_URL="${RELEASE_BASE}/checksums.txt"
if command -v curl &>/dev/null; then
    curl -fsSL --connect-timeout 30 -o "$TMP_CHECKSUMS" "$CHECKSUMS_URL" || TMP_CHECKSUMS=""
else
    wget -q --timeout=30 -O "$TMP_CHECKSUMS" "$CHECKSUMS_URL" || TMP_CHECKSUMS=""
fi

if [[ -n "$TMP_CHECKSUMS" && -f "$TMP_CHECKSUMS" ]]; then
    log_info "Verifying integrity..."
    EXPECTED="$(grep "${BIN_NAME}-${PLATFORM}" "$TMP_CHECKSUMS" | awk '{print $1}')"
    if [[ -z "$EXPECTED" ]]; then
        log_warn "No checksum entry for platform ${PLATFORM}, skipping verification"
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

mkdir -p "$INSTALL_DIR"
cp "$TMP_BIN" "$BIN_PATH"
chmod +x "$BIN_PATH"

log_ok "cappt CLI v${CLI_VERSION} installed: ${BIN_PATH}"

if ! command -v "$BIN_NAME" &>/dev/null; then
    echo ""
    log_warn "Install directory is not in PATH. Add this to your shell profile:"
    echo ""
    echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    echo ""
fi

echo ""
log_info "Next step: run 'cappt login' to authenticate"
echo ""
