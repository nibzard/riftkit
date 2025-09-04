#!/bin/bash

# Core tools installation module
# Essential tools for development environment

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

install_core_tools() {
    print_header "Installing Core Development Tools"
    
    # Update package lists
    print_status "Updating package lists..."
    apt-get update
    
    # Essential packages
    local essential_packages=(
        curl
        wget
        git
        vim
        nano
        htop
        tree
        unzip
        zip
        ca-certificates
        gnupg
        software-properties-common
        apt-transport-https
        build-essential
        pkg-config
        lsof
        net-tools
        tmux
        screen
        jq
    )
    
    install_apt_packages "${essential_packages[@]}"
    
    # Configure Git if not already configured
    setup_git
    
    # Install Node.js 20 LTS
    install_nodejs
    
    # Setup npm for global packages
    setup_npm_global
    
    # Install essential global npm packages
    install_essential_npm_packages
    
    print_success "Core tools installation complete"
}

setup_git() {
    print_status "Setting up Git..."
    
    # Check if Git is already configured globally
    local git_user=$(su - "$CURRENT_USER" -c "git config --global user.name" 2>/dev/null || echo "")
    local git_email=$(su - "$CURRENT_USER" -c "git config --global user.email" 2>/dev/null || echo "")
    
    if [[ -z "$git_user" || -z "$git_email" ]]; then
        print_warning "Git is not configured. You'll need to set it up later:"
        print_info "  git config --global user.name \"Your Name\""
        print_info "  git config --global user.email \"your.email@example.com\""
    else
        print_success "Git already configured for $git_user <$git_email>"
    fi
    
    # Set some useful Git defaults
    su - "$CURRENT_USER" -c "git config --global init.defaultBranch main" 2>/dev/null || true
    su - "$CURRENT_USER" -c "git config --global push.autoSetupRemote true" 2>/dev/null || true
    su - "$CURRENT_USER" -c "git config --global pull.rebase false" 2>/dev/null || true
    su - "$CURRENT_USER" -c "git config --global core.editor vim" 2>/dev/null || true
}

install_nodejs() {
    if command_exists node; then
        local node_version=$(get_node_version)
        if [[ $node_version -ge 18 ]]; then
            print_success "Node.js $(node --version) already installed"
            return 0
        else
            print_warning "Node.js version $node_version is too old, upgrading..."
        fi
    fi
    
    print_status "Installing Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
    
    print_success "Node.js $(node --version) installed"
}

install_essential_npm_packages() {
    print_status "Installing essential npm packages..."
    
    local npm_packages=(
        "pnpm"
        "yarn"  
        "http-server"
        "serve"
        "nodemon"
    )
    
    for package in "${npm_packages[@]}"; do
        if ! su - "$CURRENT_USER" -c "npm list -g $package >/dev/null 2>&1"; then
            install_npm_global "$package"
        else
            print_success "$package already installed"
        fi
    done
}

install_python_tools() {
    print_status "Installing Python development tools..."
    
    # Install Python and pip
    install_apt_packages python3 python3-pip python3-venv python3-dev
    
    # Install useful Python packages
    local python_packages=(
        "virtualenv"
        "poetry"
        "black"
        "flake8" 
        "pytest"
        "requests"
    )
    
    for package in "${python_packages[@]}"; do
        if ! su - "$CURRENT_USER" -c "python3 -m pip list | grep -q $package"; then
            su - "$CURRENT_USER" -c "python3 -m pip install --user $package" || print_warning "Failed to install $package"
        fi
    done
    
    print_success "Python tools installed"
}

install_tmux_config() {
    print_status "Setting up tmux configuration..."
    
    local tmux_conf="$USER_HOME/.tmux.conf"
    if [[ ! -f "$tmux_conf" ]]; then
        cat > "$tmux_conf" << 'EOF'
# Better tmux config for development

# Change prefix from C-b to C-a
unbind C-b
set-option -g prefix C-a
bind-key C-a send-prefix

# Split panes using | and -
bind | split-window -h
bind - split-window -v
unbind '"'
unbind %

# Reload config file
bind r source-file ~/.tmux.conf \; display-message "Config reloaded!"

# Switch panes using Alt-arrow without prefix
bind -n M-Left select-pane -L
bind -n M-Right select-pane -R
bind -n M-Up select-pane -U
bind -n M-Down select-pane -D

# Enable mouse mode
set -g mouse on

# Don't rename windows automatically
set-option -g allow-rename off

# Start window numbering from 1
set -g base-index 1
setw -g pane-base-index 1

# Status bar
set -g status-bg black
set -g status-fg white
set -g status-left '[#S] '
set -g status-right '%Y-%m-%d %H:%M '
set -g status-left-length 20
set -g status-right-length 20

# Highlight active window
setw -g window-status-current-style 'fg=colour1 bg=colour19 bold'
setw -g window-status-current-format ' #I#[fg=colour249]:#[fg=colour255]#W#[fg=colour249]#F '

# Vi mode
setw -g mode-keys vi
bind-key -T copy-mode-vi 'v' send -X begin-selection
bind-key -T copy-mode-vi 'y' send -X copy-selection-and-cancel

# History
set -g history-limit 10000

# No delay for escape key press
set -sg escape-time 0

# Terminal colors
set -g default-terminal "screen-256color"
EOF
        chown "$CURRENT_USER:$CURRENT_USER" "$tmux_conf"
        print_success "Tmux config created"
    else
        print_success "Tmux config already exists"
    fi
}

# Main execution if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    require_root
    install_core_tools
    install_python_tools
    install_tmux_config
fi