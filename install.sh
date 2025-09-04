#!/bin/bash

# RiftKit - AI-focused dotfiles for remote VM development
# One-liner installer: curl -fsSL https://raw.githubusercontent.com/nibzard/riftkit/main/install.sh | bash

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/nibzard/riftkit.git"
INSTALL_DIR="$HOME/.dotfiles"
PROFILE="agent"

print_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                                  🚀 RIFTKIT                                  ║
║                                                                              ║
║            AI-focused dotfiles for remote VM development                     ║
║         Optimized for Claude Code, Amp, and modern CLI tools                ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo
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
    echo -e "${PURPLE}ℹ${NC} $1"
}

check_requirements() {
    print_status "Checking requirements..."
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "Don't run this script as root!"
        print_info "The script will use sudo when needed"
        exit 1
    fi
    
    # Check for required commands
    local required_commands=("git" "curl" "sudo")
    for cmd in "${required_commands[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            print_error "$cmd is required but not installed"
            exit 1
        fi
    done
    
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        print_warning "This script requires sudo access for installation"
        print_info "You may be prompted for your password"
        sudo -v || {
            print_error "Cannot obtain sudo access"
            exit 1
        }
    fi
    
    print_success "Requirements check passed"
}

handle_existing_installation() {
    if [[ -d "$INSTALL_DIR" ]]; then
        print_warning "Existing installation found at $INSTALL_DIR"
        
        # Check if it's a git repository
        if [[ -d "$INSTALL_DIR/.git" ]]; then
            print_status "Updating existing installation..."
            cd "$INSTALL_DIR"
            git fetch origin main >/dev/null 2>&1 || {
                print_error "Failed to fetch updates"
                return 1
            }
            
            local current_commit=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
            local remote_commit=$(git rev-parse origin/main 2>/dev/null || echo "unknown")
            
            if [[ "$current_commit" != "$remote_commit" ]]; then
                print_status "Updates available, pulling changes..."
                git reset --hard origin/main
                print_success "Updated to latest version"
            else
                print_success "Already up to date"
            fi
        else
            print_warning "Existing directory is not a git repository"
            print_status "Backing up and reinstalling..."
            mv "$INSTALL_DIR" "${INSTALL_DIR}.backup.$(date +%s)"
            return 1  # Signal to do fresh install
        fi
    else
        return 1  # Signal to do fresh install
    fi
}

clone_repository() {
    print_status "Cloning RiftKit repository..."
    
    if ! git clone "$REPO_URL" "$INSTALL_DIR"; then
        print_error "Failed to clone repository"
        print_info "Check your internet connection and try again"
        exit 1
    fi
    
    print_success "Repository cloned successfully"
}

run_setup() {
    print_status "Running RiftKit setup..."
    
    cd "$INSTALL_DIR"
    
    # Make setup script executable
    chmod +x setup.sh
    
    # Run setup with agent profile
    if sudo ./setup.sh "$PROFILE" --non-interactive; then
        print_success "RiftKit setup completed successfully!"
    else
        print_error "Setup failed"
        print_info "Check the installation log for details"
        exit 1
    fi
}

show_post_install() {
    print_success "🎉 RiftKit installation complete!"
    echo
    
    print_info "📋 Next steps:"
    echo "1. 🔄 Log out and back in (or run: source ~/.bashrc)"
    echo "2. 🤖 Authenticate Claude Code: claude auth login"
    echo "3. 🚀 Start AI coding: yolo"
    echo ""
    
    print_info "💡 Useful commands:"
    echo "• yolo        - Claude in YOLO mode"
    echo "• plan        - Claude in planning mode"  
    echo "• new-project - Create project with AI config"
    echo "• aliases     - Show all shortcuts"
    echo "• tm <name>   - Tmux session"
    echo ""
    
    # Show VM IP for remote access
    local vm_ip
    vm_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "your-vm-ip")
    print_info "🌐 For remote access to dev servers:"
    echo "   http://$vm_ip:3000 (or your chosen port)"
    echo ""
    
    print_info "📚 Documentation: https://github.com/nibzard/riftkit"
    print_success "Happy AI coding! 🤖✨"
}

main() {
    print_banner
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --profile)
                PROFILE="$2"
                shift 2
                ;;
            --help)
                echo "RiftKit Installer"
                echo ""
                echo "Usage: $0 [options]"
                echo ""
                echo "Options:"
                echo "  --profile PROFILE    Installation profile (agent, full, custom)"
                echo "  --help              Show this help"
                echo ""
                echo "Profiles:"
                echo "  agent    Essential tools + AI agents (default, ~2-3 min)"
                echo "  full     Everything including modern CLI tools (~5-7 min)"
                echo "  custom   Interactive selection"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
    
    print_info "Installing RiftKit with '$PROFILE' profile"
    echo
    
    # Main installation flow
    check_requirements
    
    # Handle existing installation or clone fresh
    if ! handle_existing_installation; then
        clone_repository
    fi
    
    # Run the setup
    run_setup
    
    # Show post-install information
    show_post_install
}

# Run main function with all arguments
main "$@"