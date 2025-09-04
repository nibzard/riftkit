#!/bin/bash

# AI Agents installation module
# Optimized for remote VM development with YOLO mode

# Load common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

install_ai_agents() {
    print_header "Installing AI Coding Agents"
    
    # Ensure Node.js is available for npm-based agents
    if ! command_exists node; then
        print_error "Node.js is required for AI agents installation"
        return 1
    fi
    
    # Setup npm for global packages if not already done
    setup_npm_global
    
    # Install Claude Code (Anthropic)
    install_claude_code
    
    # Install Amp (Sourcegraph) 
    install_amp
    
    # Setup global Claude configuration
    setup_global_claude_config
    
    # Create agent-specific aliases
    create_agent_aliases
    
    print_success "AI agents installation complete"
}

install_claude_code() {
    print_status "Installing Claude Code..."
    
    if command_exists claude; then
        local version=$(claude --version 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' || echo "unknown")
        print_success "Claude Code already installed (version: $version)"
        return 0
    fi
    
    # Install via npm (most reliable method)
    if install_npm_global "@anthropic-ai/claude-code" "Claude Code"; then
        print_success "Claude Code installed"
        
        # Verify installation
        if command_exists claude; then
            local version=$(claude --version 2>/dev/null | head -1 || echo "installed")
            print_info "Claude Code version: $version"
        fi
    else
        print_error "Failed to install Claude Code via npm, trying curl installer..."
        
        # Fallback to curl installer
        if su - "$CURRENT_USER" -c 'curl -fsSL https://claude.ai/install.sh | bash'; then
            print_success "Claude Code installed via curl installer"
        else
            print_error "Failed to install Claude Code"
            return 1
        fi
    fi
}

install_amp() {
    print_status "Installing Amp CLI..."
    
    if command_exists amp; then
        print_success "Amp CLI already installed"
        return 0
    fi
    
    # Install Sourcegraph Amp
    if install_npm_global "@sourcegraph/amp" "Amp CLI"; then
        print_success "Amp CLI installed"
    else
        print_error "Failed to install Amp CLI"
        return 1
    fi
}

setup_global_claude_config() {
    print_header "Setting up global Claude configuration"
    
    local claude_dir="$USER_HOME/.claude"
    local claude_config="$claude_dir/CLAUDE.md"
    
    # Create .claude directory
    su - "$CURRENT_USER" -c "mkdir -p '$claude_dir'"
    
    # Create/update global CLAUDE.md if it doesn't exist or is minimal
    if [[ ! -f "$claude_config" ]] || [[ $(wc -l < "$claude_config") -lt 5 ]]; then
        cat > "$claude_config" << 'EOF'
# Global Claude Instructions

This file provides guidance to Claude Code when working across all projects.

## General Guidelines
- Use conventional git commits (feat:, fix:, docs:, refactor:, etc.)
- Always push meaningful scope of work when appropriate
- Focus on clean, maintainable code
- Prefer existing patterns and conventions in each project

## Development Workflow for VMs
- Work in YOLO mode for rapid development: `yolo`
- Use plan mode for complex changes: `plan`
- Leverage tmux for persistent sessions: `tm <session-name>`
- Use modern CLI tools (eza, bat, fzf, rg) when available

## VM-Specific Considerations
- Keep resource usage minimal
- Prefer CLI tools over GUI applications
- Use efficient commands and scripts
- Monitor system resources with `btm` or `htop`

## Project Setup
- Always check for existing package.json, requirements.txt, etc.
- Follow project-specific CLAUDE.md instructions when present
- Use appropriate package managers (npm, pnpm, yarn, poetry, etc.)
- Set up development servers with --host flag for remote access

## Common Commands by Project Type

### Node.js/JavaScript
```bash
npm run dev --host        # Development with remote access
npm run build            # Production build
npm run test             # Run tests
npm run lint             # Code linting
```

### Python
```bash
python -m venv venv      # Create virtual environment
source venv/bin/activate # Activate environment
pip install -r requirements.txt  # Install dependencies
python manage.py runserver 0.0.0.0:8000  # Django dev server
```

### Docker Projects
```bash
docker compose up -d     # Start services in background
docker compose logs -f   # Follow logs
docker compose down      # Stop services
```

## Security Notes
- Never commit API keys or secrets
- Use environment variables for sensitive data
- Be cautious with --dangerously-skip-permissions in production
- Review changes before pushing to main/master branches

## Quick Reference
- New project setup: `new-project <name>`
- Kill processes on ports: `killport <port>`
- Quick HTTP server: `serve [port]`
- Git status: `gs`
- Tmux session: `tm <name>`
EOF
        chown "$CURRENT_USER:$CURRENT_USER" "$claude_config"
        print_success "Global CLAUDE.md configuration created"
    else
        print_success "Global CLAUDE.md already exists"
    fi
}

create_agent_aliases() {
    print_status "Creating AI agent aliases..."
    
    local aliases_file="$USER_HOME/.agent_aliases"
    
    cat > "$aliases_file" << 'EOF'
# AI Agent Aliases for Remote VM Development

# Claude Code shortcuts
alias yolo='claude --dangerously-skip-permissions --permission-mode acceptEdits'
alias plan='claude --dangerously-skip-permissions --permission-mode plan'
alias claude-safe='claude --permission-mode prompt'
alias loop='while :; do cat prompt.md | claude -p --dangerously-skip-permissions; sleep 1; done'

# Amp shortcuts (if installed)
if command -v amp >/dev/null 2>&1; then
    alias amp-yolo='amp --auto-approve'
    alias amp-safe='amp'
fi

# Quick project setup with Claude config
new-project() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Usage: new-project <project-name>"
        return 1
    fi
    
    mkdir -p "$name" && cd "$name"
    git init
    echo "# $name" > README.md
    
    # Create project-specific CLAUDE.md
    cat > CLAUDE.md << EOF
# Project: $name

## Development Commands
Add your project-specific commands here:
\`\`\`bash
npm run dev --host
npm run build
npm run test
\`\`\`

## Project Structure
Describe your project structure and important files.

## Notes
Add any project-specific notes for Claude Code.
EOF
    
    echo "✓ Created new project: $name"
    echo "  - Initialized git repository"
    echo "  - Created README.md and CLAUDE.md"
    echo "  - Use 'yolo' or 'plan' to start coding with Claude"
}

# Prompt template creation
create-prompt() {
    local prompt_file="prompt.md"
    if [[ -f "$prompt_file" ]]; then
        echo "prompt.md already exists"
        return 1
    fi
    
    cat > "$prompt_file" << 'EOF'
# Development Task

## Objective
Describe what you want to accomplish...

## Context  
Provide relevant context about the codebase, current state, etc...

## Requirements
- List specific requirements
- Include any constraints
- Mention preferred approaches

## Additional Notes
Any other relevant information...
EOF
    
    echo "✓ Created prompt.md template"
    echo "  Edit the file and run 'loop' for continuous development"
}

# Agent status check
agent-status() {
    echo "=== AI Agent Status ==="
    
    if command -v claude >/dev/null 2>&1; then
        local claude_version=$(claude --version 2>/dev/null | head -1 || echo "installed")
        echo "✓ Claude Code: $claude_version"
        
        # Check authentication
        if claude auth status >/dev/null 2>&1; then
            echo "  └─ Authentication: ✓"
        else
            echo "  └─ Authentication: ✗ (run 'claude auth login')"
        fi
    else
        echo "✗ Claude Code: Not installed"
    fi
    
    if command -v amp >/dev/null 2>&1; then
        echo "✓ Amp CLI: $(amp --version 2>/dev/null | head -1 || echo 'installed')"
    else
        echo "✗ Amp CLI: Not installed"
    fi
    
    echo ""
    echo "Usage:"
    echo "  yolo     - Claude in YOLO mode (auto-accept edits)"
    echo "  plan     - Claude in planning mode" 
    echo "  loop     - Continuous development with prompt.md"
    echo "  new-project <name> - Create new project with Claude config"
}

# Export functions
export -f new-project create-prompt agent-status
EOF
    
    chown "$CURRENT_USER:$CURRENT_USER" "$aliases_file"
    
    # Source the aliases in shell configs
    local shell_configs=("$USER_HOME/.bashrc" "$USER_HOME/.zshrc")
    for config in "${shell_configs[@]}"; do
        if [[ -f "$config" ]] && ! grep -q ".agent_aliases" "$config"; then
            echo "" >> "$config"
            echo "# AI Agent aliases" >> "$config"
            echo "source ~/.agent_aliases" >> "$config"
            print_success "Added agent aliases to $(basename "$config")"
        fi
    done
    
    print_success "AI agent aliases created"
}

setup_claude_for_yolo() {
    print_status "Configuring Claude for YOLO mode..."
    
    # Create a simple Claude config for YOLO mode
    local claude_dir="$USER_HOME/.claude"
    local claude_settings="$claude_dir/settings.json"
    
    su - "$CURRENT_USER" -c "mkdir -p '$claude_dir'"
    
    if [[ ! -f "$claude_settings" ]]; then
        cat > "$claude_settings" << 'EOF'
{
  "defaultPermissionMode": "acceptEdits",
  "dangerouslySkipPermissions": true,
  "autoSave": true,
  "theme": "dark"
}
EOF
        chown "$CURRENT_USER:$CURRENT_USER" "$claude_settings"
        print_success "Claude configured for YOLO mode"
    fi
}

# Main execution if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    require_root
    install_ai_agents
    setup_claude_for_yolo
fi