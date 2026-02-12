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

# --- Check 1: Auto-Install Dependencies ---
log_step "Checking and installing dependencies..."

install_dependencies() {
    local packages="git curl openssl"
    local install_cmd=""
    local update_cmd=""
    local missing_packages=""

    # Detect Package Manager
    if command -v apt-get >/dev/null 2>&1; then
        log_info "Detected Debian/Ubuntu system."
        update_cmd="sudo apt-get update"
        install_cmd="sudo apt-get install -y"
    elif command -v dnf >/dev/null 2>&1; then
        log_info "Detected RHEL/CentOS/Fedora system (dnf)."
        update_cmd="sudo dnf check-update"
        install_cmd="sudo dnf install -y"
    elif command -v yum >/dev/null 2>&1; then
        log_info "Detected RHEL/CentOS system (yum)."
        update_cmd="sudo yum check-update"
        install_cmd="sudo yum install -y"
    elif command -v apk >/dev/null 2>&1; then
        log_info "Detected Alpine Linux."
        update_cmd="sudo apk update"
        install_cmd="sudo apk add"
        packages="git curl openssl bash" # Alpine needs bash explicitly
    elif command -v pacman >/dev/null 2>&1; then
        log_info "Detected Arch Linux."
        update_cmd="sudo pacman -Sy"
        install_cmd="sudo pacman -S --noconfirm"
    elif command -v zypper >/dev/null 2>&1; then
        log_info "Detected OpenSUSE."
        update_cmd="sudo zypper refresh"
        install_cmd="sudo zypper install -y"
    else
        log_error "Unsupported package manager. Please install git, docker, and openssl manually."
        exit 1
    fi

    # Install basic tools
    for pkg in $packages; do
        if ! command -v "$pkg" >/dev/null 2>&1; then
            missing_packages="$missing_packages $pkg"
        fi
    done

    if [ -n "$missing_packages" ]; then
        log_warn "Installing missing packages: $missing_packages"
        $update_cmd >/dev/null 2>&1 || true
        $install_cmd $missing_packages
    else
        log_info "Basic dependencies (git, curl, openssl) are installed."
    fi

    # Install Docker if missing
    if ! command -v docker >/dev/null 2>&1; then
        log_warn "Docker not found. Installing Docker..."
        curl -fsSL https://get.docker.com | sh
        
        log_step "Starting Docker service..."
        sudo systemctl enable docker >/dev/null 2>&1 || true
        sudo systemctl start docker >/dev/null 2>&1 || true
        
        # Add current user to docker group to avoid sudo requirement
        log_step "Adding user '$USER' to 'docker' group..."
        sudo usermod -aG docker "$USER" || true
        
        log_warn "Docker installed. You may need to log out and back in for group changes to take effect."
        log_warn "If the script fails with 'permission denied', run: 'newgrp docker' and try again."
    else
        log_info "Docker is already installed."
    fi

    # Check for Docker Compose V2
    if ! docker compose version >/dev/null 2>&1; then
        log_warn "Docker Compose V2 plugin not found. Attempting to install..."
        if command -v apt-get >/dev/null 2>&1; then
            sudo apt-get install -y docker-compose-plugin
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y docker-compose-plugin
        elif command -v yum >/dev/null 2>&1; then
            sudo yum install -y docker-compose-plugin
        else
            log_error "Could not auto-install docker-compose-plugin. Please install it manually."
            exit 1
        fi
    else
        log_info "Docker Compose V2 is ready."
    fi
}

install_dependencies

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
