#!/bin/bash

# =============================================================================
# Postiz One-Liner Installer
# =============================================================================
# Usage: curl -fsSL <raw-url>/install.sh | bash
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()  { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[⚠]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step()  { echo -e "    → $1"; }

echo ""
echo "╔══════════════════════════════════════════╗"
echo "║       Postiz One-Liner Installer          ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# --- Check 1: Dependencies ---
log_step "Checking dependencies..."

MISSING=0
for cmd in git docker openssl; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        log_error "$cmd is not installed."
        MISSING=1
    fi
done

if ! docker compose version >/dev/null 2>&1; then
    log_error "Docker Compose V2 is not available (need 'docker compose')."
    MISSING=1
fi

if [ "$MISSING" -eq 1 ]; then
    echo ""
    log_error "Please install the missing dependencies and try again."
    exit 1
fi
log_info "All dependencies found."

# --- Check 2: Clone or Enter Repo ---
REPO_URL="https://github.com/Rita5fr/postiz-app.git"
INSTALL_DIR="postiz-app"

if [ -f "docker-compose.yaml" ] && [ -d ".git" ] && [ -f "postiz" ]; then
    # We are already inside the repo
    log_info "Detected existing Postiz repository in current directory."
else
    if [ -d "$INSTALL_DIR" ]; then
        log_info "Directory '$INSTALL_DIR' already exists. Entering it..."
        cd "$INSTALL_DIR"

        if [ ! -f "postiz" ]; then
            log_step "Pulling latest files..."
            git pull || {
                log_error "Failed to pull latest changes."
                exit 1
            }
        fi
    else
        log_step "Cloning Postiz repository..."
        git clone "$REPO_URL" "$INSTALL_DIR" || {
            log_error "Failed to clone repository."
            exit 1
        }
        cd "$INSTALL_DIR"
    fi
fi

# --- Check 3: Validate postiz CLI ---
if [ ! -f "postiz" ]; then
    log_error "postiz CLI script not found. The repository may be corrupted."
    log_error "Try deleting the directory and running this script again."
    exit 1
fi

chmod +x postiz
log_info "Postiz CLI ready."

# --- Run Install ---
echo ""
./postiz install
