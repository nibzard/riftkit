#!/bin/bash

# Modern CLI tools installation module  
# Installs modern replacements for traditional Unix tools

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

install_modern_cli_tools() {
    print_header "Installing Modern CLI Tools"
    
    # Install from apt repositories first
    install_apt_modern_tools
    
    # Install tools from GitHub releases
    install_github_modern_tools
    
    # Install Rust-based tools via cargo if available
    install_cargo_tools
    
    print_success "Modern CLI tools installation complete"
}

install_apt_modern_tools() {
    print_status "Installing modern tools from apt repositories..."
    
    local apt_packages=(
        bat          # Better cat with syntax highlighting
        ripgrep      # Fast grep replacement
        fd-find      # Fast find replacement  
        fzf          # Fuzzy finder
        tree         # Directory tree viewer
        jq           # JSON processor
        htop         # Better top
        ncdu         # Disk usage analyzer
    )
    
    install_apt_packages "${apt_packages[@]}"
    
    # Create symlink for fd (installed as fd-find on Ubuntu)
    if command_exists fd-find && ! command_exists fd; then
        ln -sf /usr/bin/fd-find /usr/local/bin/fd
        print_success "Created fd symlink"
    fi
}

install_github_modern_tools() {
    print_header "Installing tools from GitHub releases"
    
    # eza - Modern ls replacement (better than exa)
    if ! command_exists eza; then
        install_eza
    else
        print_success "eza already installed"
    fi
    
    # zoxide - Smarter cd command
    if ! command_exists zoxide; then
        install_zoxide  
    else
        print_success "zoxide already installed"
    fi
    
    # delta - Better git diff viewer
    if ! command_exists delta; then
        install_delta
    else
        print_success "delta already installed"  
    fi
    
    # duf - Better df alternative
    if ! command_exists duf; then
        install_duf
    else
        print_success "duf already installed"
    fi
    
    # bottom - System monitor (btm command)
    if ! command_exists btm; then
        install_bottom
    else
        print_success "bottom already installed"
    fi
    
    # lazygit - Terminal git UI
    if ! command_exists lazygit; then
        install_lazygit
    else
        print_success "lazygit already installed"
    fi
    
    # lazydocker - Terminal docker UI  
    if ! command_exists lazydocker; then
        install_lazydocker
    else
        print_success "lazydocker already installed"
    fi
    
    # procs - Modern ps replacement
    if ! command_exists procs; then
        install_procs
    else
        print_success "procs already installed"
    fi
}

install_eza() {
    print_status "Installing eza (modern ls)..."
    
    # Install from GitHub releases
    local latest_url="https://api.github.com/repos/eza-community/eza/releases/latest"
    local download_url
    
    download_url=$(curl -s "$latest_url" | grep -o "https://github.com/eza-community/eza/releases/download/[^\"]*linux.*x86_64[^\"]*\.tar\.gz" | head -1)
    
    if [[ -n "$download_url" ]]; then
        local temp_file="/tmp/eza.tar.gz"
        curl -L "$download_url" -o "$temp_file"
        tar -xzf "$temp_file" -C /tmp/
        
        # Find the eza binary
        local eza_binary=$(find /tmp -name "eza" -type f | head -1)
        if [[ -f "$eza_binary" ]]; then
            chmod +x "$eza_binary"
            mv "$eza_binary" /usr/local/bin/eza
            rm -f "$temp_file"
            print_success "eza installed"
        else
            print_error "Could not find eza binary in archive"
        fi
    else
        print_error "Could not find eza download URL"
    fi
}

install_zoxide() {
    print_status "Installing zoxide (smarter cd)..."
    
    # Use the official installer script
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    
    if [[ -f "$USER_HOME/.local/bin/zoxide" ]]; then
        mv "$USER_HOME/.local/bin/zoxide" /usr/local/bin/
        print_success "zoxide installed"
    else
        print_error "zoxide installation failed"
    fi
}

install_delta() {
    print_status "Installing delta (better git diff)..."
    
    local latest_url="https://api.github.com/repos/dandavison/delta/releases/latest"
    local download_url
    
    download_url=$(curl -s "$latest_url" | grep -o "https://github.com/dandavison/delta/releases/download/[^\"]*linux.*x86_64[^\"]*\.tar\.gz" | head -1)
    
    if [[ -n "$download_url" ]]; then
        local temp_file="/tmp/delta.tar.gz"
        curl -L "$download_url" -o "$temp_file"
        tar -xzf "$temp_file" -C /tmp/
        
        local delta_binary=$(find /tmp -name "delta" -type f | head -1)
        if [[ -f "$delta_binary" ]]; then
            chmod +x "$delta_binary"
            mv "$delta_binary" /usr/local/bin/delta
            rm -f "$temp_file"
            print_success "delta installed"
        else
            print_error "Could not find delta binary"
        fi
    else
        print_error "Could not find delta download URL"
    fi
}

install_duf() {
    install_github_binary "muesli/duf" "duf"
}

install_bottom() {
    print_status "Installing bottom (system monitor)..."
    
    local latest_url="https://api.github.com/repos/ClementTsang/bottom/releases/latest"
    local download_url
    
    download_url=$(curl -s "$latest_url" | grep -o "https://github.com/ClementTsang/bottom/releases/download/[^\"]*linux.*x86_64[^\"]*\.tar\.gz" | head -1)
    
    if [[ -n "$download_url" ]]; then
        local temp_file="/tmp/bottom.tar.gz"
        curl -L "$download_url" -o "$temp_file"
        tar -xzf "$temp_file" -C /tmp/
        
        local btm_binary=$(find /tmp -name "btm" -type f | head -1)
        if [[ -f "$btm_binary" ]]; then
            chmod +x "$btm_binary"
            mv "$btm_binary" /usr/local/bin/btm
            rm -f "$temp_file"
            print_success "bottom (btm) installed"
        else
            print_error "Could not find btm binary"
        fi
    else
        print_error "Could not find bottom download URL"
    fi
}

install_lazygit() {
    print_status "Installing lazygit..."
    
    local latest_url="https://api.github.com/repos/jesseduffield/lazygit/releases/latest"
    local download_url
    
    download_url=$(curl -s "$latest_url" | grep -o "https://github.com/jesseduffield/lazygit/releases/download/[^\"]*Linux_x86_64\.tar\.gz" | head -1)
    
    if [[ -n "$download_url" ]]; then
        local temp_file="/tmp/lazygit.tar.gz"
        curl -L "$download_url" -o "$temp_file"
        tar -xzf "$temp_file" -C /tmp/
        
        if [[ -f "/tmp/lazygit" ]]; then
            chmod +x /tmp/lazygit
            mv /tmp/lazygit /usr/local/bin/lazygit
            rm -f "$temp_file"
            print_success "lazygit installed"
        else
            print_error "Could not find lazygit binary"
        fi
    else
        print_error "Could not find lazygit download URL"
    fi
}

install_lazydocker() {
    print_status "Installing lazydocker..."
    
    local latest_url="https://api.github.com/repos/jesseduffield/lazydocker/releases/latest"
    local download_url
    
    download_url=$(curl -s "$latest_url" | grep -o "https://github.com/jesseduffield/lazydocker/releases/download/[^\"]*Linux_x86_64\.tar\.gz" | head -1)
    
    if [[ -n "$download_url" ]]; then
        local temp_file="/tmp/lazydocker.tar.gz"
        curl -L "$download_url" -o "$temp_file"
        tar -xzf "$temp_file" -C /tmp/
        
        if [[ -f "/tmp/lazydocker" ]]; then
            chmod +x /tmp/lazydocker
            mv /tmp/lazydocker /usr/local/bin/lazydocker
            rm -f "$temp_file"
            print_success "lazydocker installed"
        else
            print_error "Could not find lazydocker binary"
        fi
    else
        print_error "Could not find lazydocker download URL"
    fi
}

install_procs() {
    install_github_binary "dalance/procs" "procs"
}

install_cargo_tools() {
    if ! command_exists cargo; then
        print_info "Cargo not available, skipping Rust-based tools"
        return 0
    fi
    
    print_header "Installing Rust-based CLI tools via Cargo"
    
    local cargo_tools=(
        "starship --locked"  # Cross-shell prompt
        "tldr"              # Simplified man pages
    )
    
    for tool in "${cargo_tools[@]}"; do
        local tool_name=$(echo "$tool" | cut -d' ' -f1)
        if ! command_exists "$tool_name"; then
            print_status "Installing $tool_name via cargo..."
            su - "$CURRENT_USER" -c "cargo install $tool" || print_warning "Failed to install $tool_name"
        else
            print_success "$tool_name already installed"
        fi
    done
}

setup_shell_integrations() {
    print_header "Setting up shell integrations"
    
    # Setup zoxide integration
    if command_exists zoxide; then
        local shell_configs=("$USER_HOME/.bashrc" "$USER_HOME/.zshrc")
        for config in "${shell_configs[@]}"; do
            if [[ -f "$config" ]] && ! grep -q "zoxide init" "$config"; then
                echo 'eval "$(zoxide init bash)"' >> "$config"
                print_success "Added zoxide integration to $(basename "$config")"
            fi
        done
    fi
    
    # Setup starship prompt
    if command_exists starship; then
        local shell_configs=("$USER_HOME/.bashrc" "$USER_HOME/.zshrc")
        for config in "${shell_configs[@]}"; do
            if [[ -f "$config" ]] && ! grep -q "starship init" "$config"; then
                echo 'eval "$(starship init bash)"' >> "$config"
                print_success "Added starship integration to $(basename "$config")"
            fi
        done
        
        # Create basic starship config
        local starship_config="$USER_HOME/.config/starship.toml"
        mkdir -p "$(dirname "$starship_config")"
        if [[ ! -f "$starship_config" ]]; then
            cat > "$starship_config" << 'EOF'
# Minimal starship config for development VMs
[character]
success_symbol = "[➜](bold green)"
error_symbol = "[➜](bold red)"

[directory]
truncation_length = 3
truncate_to_repo = true

[git_branch]
symbol = "🌱 "

[nodejs]
symbol = "⬢ "

[python]
symbol = "🐍 "

[docker_context]
symbol = "🐳 "

[time]
disabled = false
format = "[$time]($style)"
EOF
            chown "$CURRENT_USER:$CURRENT_USER" "$starship_config"
            print_success "Created basic starship config"
        fi
    fi
}

# Main execution if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    require_root
    install_modern_cli_tools
    setup_shell_integrations
fi