#!/bin/bash

# Common utilities for dotfiles setup scripts
# Source this file to access shared functions

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Current user detection
CURRENT_USER=${SUDO_USER:-$USER}
USER_HOME=$(eval echo ~$CURRENT_USER)

# Print functions
print_header() {
    echo -e "\n${PURPLE}${BOLD}=== $1 ===${NC}"
}

print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ${NC} $1"
}

print_dim() {
    echo -e "${DIM}$1${NC}"
}

# Utility functions
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_root() {
    [[ $EUID -eq 0 ]]
}

require_root() {
    if ! is_root; then
        print_error "This operation requires root privileges"
        echo "Run with: sudo $0"
        exit 1
    fi
}

# Ask user for confirmation (respects non-interactive mode)
ask_user() {
    local prompt="$1"
    local default="${2:-N}"
    
    if [[ "${NON_INTERACTIVE:-false}" == "true" ]]; then
        [[ "$default" == "y" || "$default" == "Y" ]]
    else
        echo -en "${CYAN}$prompt${NC} "
        if [[ "$default" == "y" || "$default" == "Y" ]]; then
            echo -n "(Y/n): "
        else
            echo -n "(y/N): "
        fi
        read -n 1 -r
        echo
        if [[ "$default" == "y" || "$default" == "Y" ]]; then
            [[ $REPLY =~ ^[Nn]$ ]] && return 1 || return 0
        else
            [[ $REPLY =~ ^[Yy]$ ]]
        fi
    fi
}

# Version comparison
version_ge() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

# Get Node.js major version
get_node_version() {
    if command_exists node; then
        node --version 2>/dev/null | sed 's/v//' | cut -d. -f1
    else
        echo "0"
    fi
}

# Install packages with apt (with error handling)
install_apt_packages() {
    local packages=("$@")
    print_status "Installing packages: ${packages[*]}"
    
    if apt-get update && apt-get install -y "${packages[@]}"; then
        print_success "Packages installed successfully"
    else
        print_error "Failed to install some packages"
        return 1
    fi
}

# Install npm package globally as user
install_npm_global() {
    local package="$1"
    local name="${2:-$package}"
    
    print_status "Installing $name globally..."
    if su - "$CURRENT_USER" -c "npm install -g $package"; then
        print_success "$name installed"
    else
        print_warning "Failed to install $name"
        return 1
    fi
}

# Install from GitHub releases (binary)
install_github_binary() {
    local repo="$1"
    local binary_name="$2"
    local install_path="${3:-/usr/local/bin}"
    local arch="${4:-x86_64}"
    local os="${5:-linux}"
    
    print_status "Installing $binary_name from $repo..."
    
    local latest_url="https://api.github.com/repos/$repo/releases/latest"
    local download_url
    
    download_url=$(curl -s "$latest_url" | grep -o "https://github.com/$repo/releases/download/[^\"]*${os}.*${arch}[^\"]*" | head -1)
    
    if [[ -z "$download_url" ]]; then
        print_error "Could not find download URL for $binary_name"
        return 1
    fi
    
    local temp_file="/tmp/${binary_name}.tar.gz"
    if curl -L "$download_url" -o "$temp_file"; then
        if [[ "$download_url" == *.tar.gz ]]; then
            tar -xzf "$temp_file" -C /tmp/
            local extracted_binary="/tmp/$binary_name"
            [[ -f "$extracted_binary" ]] || extracted_binary=$(find /tmp -name "$binary_name" -type f | head -1)
            
            if [[ -f "$extracted_binary" ]]; then
                chmod +x "$extracted_binary"
                mv "$extracted_binary" "$install_path/$binary_name"
                print_success "$binary_name installed to $install_path"
            else
                print_error "Could not find extracted binary"
                return 1
            fi
        else
            # Direct binary download
            chmod +x "$temp_file"
            mv "$temp_file" "$install_path/$binary_name"
            print_success "$binary_name installed to $install_path"
        fi
        rm -f "$temp_file"
    else
        print_error "Failed to download $binary_name"
        return 1
    fi
}

# Setup npm for global packages without sudo
setup_npm_global() {
    print_status "Configuring npm for global packages..."
    
    su - "$CURRENT_USER" -c "mkdir -p '$USER_HOME/.npm-global'"
    su - "$CURRENT_USER" -c "npm config set prefix '$USER_HOME/.npm-global'"
    
    # Add to shell profiles
    for profile in "$USER_HOME/.bashrc" "$USER_HOME/.zshrc" "$USER_HOME/.profile"; do
        if [[ -f "$profile" ]] && ! grep -q ".npm-global/bin" "$profile"; then
            echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> "$profile"
            print_success "Added npm global path to $(basename "$profile")"
        fi
    done
    
    # Update current session
    export PATH="$USER_HOME/.npm-global/bin:$PATH"
    print_success "NPM configured for global packages"
}

# Cleanup temp files
cleanup_temp() {
    print_dim "Cleaning up temporary files..."
    rm -f /tmp/setup_*.log /tmp/*.tar.gz /tmp/*.deb 2>/dev/null || true
}

# Log function
log() {
    local level="$1"
    shift
    local message="$*"
    
    case "$level" in
        "ERROR")
            print_error "$message" ;;
        "WARN")
            print_warning "$message" ;;
        "INFO")
            print_info "$message" ;;
        "SUCCESS")
            print_success "$message" ;;
        *)
            echo "$message" ;;
    esac
}

# Progress indicator
show_progress() {
    local current="$1"
    local total="$2"
    local task="$3"
    
    local progress=$((current * 100 / total))
    local bar_length=20
    local filled=$((progress * bar_length / 100))
    local empty=$((bar_length - filled))
    
    printf "\r${BLUE}[%s%s] %d%% - %s${NC}" \
        "$(printf '=%.0s' $(seq 1 $filled))" \
        "$(printf ' %.0s' $(seq 1 $empty))" \
        "$progress" "$task"
    
    [[ "$current" -eq "$total" ]] && echo
}

# Check if script is being sourced
(return 0 2>/dev/null) && SOURCED=1 || SOURCED=0

if [[ $SOURCED -eq 0 ]]; then
    print_error "This script should be sourced, not executed directly"
    echo "Usage: source lib/common.sh"
    exit 1
fi