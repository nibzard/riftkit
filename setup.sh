#!/bin/bash

# Optimized Dotfiles Setup for Remote VM AI Development
# Usage: sudo ./setup.sh [profile] [options]
# Profiles: agent (default), full, custom
# Options: --non-interactive, --skip-existing

set -euo pipefail

# Script directory detection
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load common functions
source "$SCRIPT_DIR/lib/common.sh"

# Configuration
DEFAULT_PROFILE="agent"
PROFILE="${1:-$DEFAULT_PROFILE}"
NON_INTERACTIVE=false
SKIP_EXISTING=false
INSTALL_LOG="/tmp/dotfiles-install.log"

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --non-interactive|-y)
                NON_INTERACTIVE=true
                export NON_INTERACTIVE
                shift
                ;;
            --skip-existing|-s)
                SKIP_EXISTING=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            agent|full|custom)
                PROFILE="$1"
                shift
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
🚀 Optimized Dotfiles Setup for Remote VM AI Development

Usage: sudo ./setup.sh [profile] [options]

Profiles:
  agent    Default profile with essential tools and AI agents (Claude, Amp)
  full     Everything including modern CLI tools and enhancements  
  custom   Interactive selection of components

Options:
  --non-interactive, -y    Run without prompting (uses defaults)
  --skip-existing, -s     Skip installation of already installed tools
  --help, -h              Show this help message

Examples:
  sudo ./setup.sh                    # Install agent profile (default)
  sudo ./setup.sh full -y           # Install everything non-interactively
  sudo ./setup.sh custom            # Interactive component selection
  sudo ./setup.sh agent --skip-existing  # Quick reinstall

Components by Profile:
  agent:  Core tools + Node.js + Git + tmux + AI agents + aliases
  full:   Everything in agent + modern CLI tools + Python + enhancements
  custom: Choose exactly what you want

Post-installation:
  1. Log out and back in to refresh environment
  2. Run 'claude auth login' to authenticate Claude Code
  3. Use 'yolo' for AI coding in YOLO mode
  4. Use 'aliases' to see all available shortcuts
EOF
}

show_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║                   🚀 VM DOTFILES SETUP FOR AI DEVELOPMENT                   ║
║                                                                              ║
║  Optimized for remote VMs running AI coding agents like Claude Code         ║
║  Focus: Lightweight, fast, CLI-only tools for maximum productivity          ║
╚══════════════════════════════════════════════════════════════════════════════╝
EOF
    echo
}

show_profile_info() {
    print_header "Profile: $PROFILE"
    
    case "$PROFILE" in
        "agent")
            echo "📦 Essential tools for AI agent development:"
            echo "  • Core: Git, Node.js, tmux, essential packages"  
            echo "  • AI Agents: Claude Code, Amp CLI"
            echo "  • Aliases: AI-focused productivity shortcuts"
            echo "  • Time: ~2-3 minutes"
            ;;
        "full")
            echo "🔧 Complete development environment:"
            echo "  • Everything in 'agent' profile"
            echo "  • Modern CLI: eza, bat, fzf, ripgrep, fd, delta, etc."
            echo "  • Python tools and utilities"
            echo "  • Enhanced shell with starship prompt"
            echo "  • Time: ~5-7 minutes"
            ;;
        "custom")
            echo "🎯 Interactive component selection:"
            echo "  • Choose exactly what you need"
            echo "  • Modular installation"
            echo "  • Time: varies by selection"
            ;;
    esac
    echo
}

# Profile-specific installations
install_agent_profile() {
    print_header "Installing Agent Profile"
    
    # Core tools (essential)
    run_module "$SCRIPT_DIR/modules/core.sh" "Core tools"
    
    # AI Agents
    run_module "$SCRIPT_DIR/modules/agents.sh" "AI agents"
    
    # Setup aliases
    setup_aliases
    
    print_success "Agent profile installation complete"
}

install_full_profile() {
    print_header "Installing Full Profile"
    
    # Start with agent profile
    install_agent_profile
    
    # Add modern CLI tools
    run_module "$SCRIPT_DIR/modules/modern_cli.sh" "Modern CLI tools"
    
    print_success "Full profile installation complete"
}

install_custom_profile() {
    print_header "Custom Installation"
    
    echo "Select components to install:"
    echo
    
    local components=(
        "core:Core tools (Git, Node.js, tmux):true"
        "agents:AI agents (Claude, Amp):true"  
        "modern:Modern CLI tools (eza, bat, fzf, etc.):false"
        "aliases:Productivity aliases:true"
    )
    
    local selected=()
    
    for component in "${components[@]}"; do
        IFS=':' read -r key desc default <<< "$component"
        
        local prompt="Install $desc?"
        if ask_user "$prompt" "$default"; then
            selected+=("$key")
        fi
    done
    
    echo
    print_status "Installing selected components..."
    
    for component in "${selected[@]}"; do
        case "$component" in
            "core")
                run_module "$SCRIPT_DIR/modules/core.sh" "Core tools"
                ;;
            "agents")
                run_module "$SCRIPT_DIR/modules/agents.sh" "AI agents"
                ;;
            "modern")
                run_module "$SCRIPT_DIR/modules/modern_cli.sh" "Modern CLI tools"
                ;;
            "aliases")
                setup_aliases
                ;;
        esac
    done
    
    print_success "Custom installation complete"
}

run_module() {
    local module_path="$1"
    local module_name="$2"
    
    if [[ ! -f "$module_path" ]]; then
        print_error "Module not found: $module_path"
        return 1
    fi
    
    print_status "Running $module_name module..."
    
    # Make module executable
    chmod +x "$module_path"
    
    # Run module and capture output
    if "$module_path" >> "$INSTALL_LOG" 2>&1; then
        print_success "$module_name completed"
    else
        print_error "$module_name failed (check $INSTALL_LOG)"
        return 1
    fi
}

setup_aliases() {
    print_status "Setting up aliases and shell configuration..."
    
    local bash_aliases_src="$SCRIPT_DIR/config/.bash_aliases"
    local bash_aliases_dst="$USER_HOME/.bash_aliases"
    
    if [[ -f "$bash_aliases_src" ]]; then
        # Copy aliases file
        cp "$bash_aliases_src" "$bash_aliases_dst"
        chown "$CURRENT_USER:$CURRENT_USER" "$bash_aliases_dst"
        
        # Ensure .bashrc sources the aliases
        local bashrc="$USER_HOME/.bashrc"
        if [[ -f "$bashrc" ]] && ! grep -q "\.bash_aliases" "$bashrc"; then
            echo "" >> "$bashrc"
            echo "# Load custom aliases" >> "$bashrc"
            echo "if [ -f ~/.bash_aliases ]; then" >> "$bashrc"
            echo "    source ~/.bash_aliases" >> "$bashrc"
            echo "fi" >> "$bashrc"
        fi
        
        print_success "Aliases configured"
    else
        print_warning "Aliases file not found: $bash_aliases_src"
    fi
}

create_quick_setup_script() {
    print_status "Creating quick setup script for future VMs..."
    
    local quick_setup="$SCRIPT_DIR/quick-setup.sh"
    
    cat > "$quick_setup" << 'EOF'
#!/bin/bash
# Quick setup script for new VMs
# Run: curl -fsSL https://raw.githubusercontent.com/your-username/dotfiles/main/quick-setup.sh | bash

set -e

print_status() {
    echo "🚀 $1"
}

print_status "Cloning dotfiles..."
if [[ ! -d "$HOME/.dotfiles" ]]; then
    git clone https://github.com/your-username/dotfiles.git "$HOME/.dotfiles"
fi

print_status "Running setup..."
cd "$HOME/.dotfiles"
sudo ./setup.sh agent -y

print_status "Setup complete! Log out and back in to refresh environment."
print_status "Then run 'yolo' to start AI coding with Claude!"
EOF
    
    chmod +x "$quick_setup"
    chown "$CURRENT_USER:$CURRENT_USER" "$quick_setup"
    
    print_success "Quick setup script created: $quick_setup"
}

show_post_install() {
    print_header "Installation Complete! 🎉"
    
    echo "📋 Next Steps:"
    echo ""
    echo "1. 🔄 Log out and back in (or restart terminal) to refresh environment"
    echo "2. 🤖 Authenticate Claude Code:"
    echo "   claude auth login"
    echo ""
    echo "3. 🚀 Start AI coding:"
    echo "   yolo        # Claude in YOLO mode"
    echo "   plan        # Claude in planning mode"  
    echo "   new-project <name>  # Create new project with AI config"
    echo ""
    echo "4. 💡 Explore shortcuts:"
    echo "   aliases     # Show all available aliases"
    echo "   tm <name>   # Create/attach tmux session"
    echo "   serve       # Quick HTTP server"
    echo ""
    
    if command_exists claude; then
        echo "✅ Claude Code: Ready"
    else
        echo "⚠️  Claude Code: May need PATH refresh"
    fi
    
    if command_exists amp; then
        echo "✅ Amp CLI: Ready"  
    fi
    
    if command_exists tmux; then
        echo "✅ Tmux: Ready (use 'tm coding' for main session)"
    fi
    
    echo ""
    print_info "Installation log available at: $INSTALL_LOG"
    print_info "For issues, check the log or run components individually"
    echo ""
    
    # Show VM-specific tips
    print_header "Remote VM Tips"
    echo "• Use 'npm run dev -- --host' for external access to dev servers"
    echo "• Access your VM's services at: http://$(hostname -I | awk '{print $1}'):PORT"
    echo "• Keep tmux sessions running: 'tm project-name'"
    echo "• Monitor resources: 'htop' or 'btm' (if installed)"
}

main() {
    # Initialize logging
    echo "=== Dotfiles Installation Log - $(date) ===" > "$INSTALL_LOG"
    
    # Parse arguments (skip first which is script name)
    shift # Remove script name from args
    parse_arguments "$@"
    
    # Show banner and info
    show_banner
    show_profile_info
    
    # Root check
    require_root
    
    # Confirmation (unless non-interactive)
    if [[ "$NON_INTERACTIVE" != "true" ]]; then
        if ! ask_user "Continue with $PROFILE profile installation?" "y"; then
            print_info "Installation cancelled"
            exit 0
        fi
    fi
    
    echo
    print_status "Starting installation..."
    
    # Run profile-specific installation
    case "$PROFILE" in
        "agent")
            install_agent_profile
            ;;
        "full")
            install_full_profile
            ;;
        "custom")
            install_custom_profile
            ;;
        *)
            print_error "Unknown profile: $PROFILE"
            show_help
            exit 1
            ;;
    esac
    
    # Create quick setup script
    create_quick_setup_script
    
    # Cleanup temp files
    cleanup_temp
    
    # Show post-installation info
    show_post_install
}

# Run main function with all arguments
main "$0" "$@"