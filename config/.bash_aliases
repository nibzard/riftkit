# AI-focused bash aliases for remote VM development
# Optimized for productivity with Claude Code and modern CLI tools

# ============================================================================
# NAVIGATION & BASICS
# ============================================================================

# Enhanced ls aliases (use eza if available, otherwise ls)
if command -v eza >/dev/null 2>&1; then
    alias ls='eza --color=always --group-directories-first'
    alias ll='eza -la --color=always --group-directories-first --git'
    alias la='eza -a --color=always --group-directories-first'
    alias lt='eza -T --color=always --group-directories-first' # Tree view
    alias l='eza -F --color=always --group-directories-first'
else
    alias ll='ls -alF --color=auto'
    alias la='ls -A --color=auto'
    alias l='ls -CF --color=auto'
fi

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias p='cd ~/projects'
alias dot='cd ~/.dotfiles'

# Quick directory creation and navigation
mkcd() {
    mkdir -p "$1" && cd "$1"
}

# ============================================================================
# AI AGENT SHORTCUTS
# ============================================================================

# Claude Code (primary AI agent)
alias yolo='claude --dangerously-skip-permissions --permission-mode acceptEdits'
alias plan='claude --dangerously-skip-permissions --permission-mode plan'
alias claude-safe='claude --permission-mode prompt'
alias loop='while :; do cat prompt.md | claude -p --dangerously-skip-permissions; sleep 2; done'

# Amp (if installed)
if command -v amp >/dev/null 2>&1; then
    alias amp-yolo='amp --auto-approve'
fi

# ============================================================================
# GIT SHORTCUTS
# ============================================================================

alias g='git'
alias gs='git status'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit -m'
alias gca='git commit -am'
alias gp='git push'
alias gpl='git pull'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gb='git branch'
alias gd='git diff'
alias gl='git log --oneline -10'
alias gll='git log --oneline --graph --decorate --all'
alias gst='git stash'
alias gstp='git stash pop'

# Enhanced git log with delta if available
if command -v delta >/dev/null 2>&1; then
    alias gdt='git diff | delta'
fi

# Quick commit and push
gcp() {
    git add -A
    git commit -m "$1"
    git push
}

# ============================================================================
# TMUX SESSION MANAGEMENT
# ============================================================================

# Tmux shortcuts inspired by your existing config
alias tl='tmux ls'
alias tc='tmux attach -t coding || tmux new -s coding'

# Enhanced tmux functions
tm() {
    if [[ -z "$1" ]]; then
        echo "Usage: tm <session-name>"
        echo "Active sessions:"
        tmux ls 2>/dev/null || echo "  No active sessions"
        return 1
    fi
    tmux attach -t "$1" 2>/dev/null || tmux new -s "$1"
}

tr() {
    if [[ -z "$1" ]]; then
        echo "Usage: tr <session-name>"
        echo "Active sessions:"
        tmux ls 2>/dev/null || echo "  No active sessions"
        return 1
    fi
    tmux kill-session -t "$1" && echo "Session '$1' killed." || echo "Session '$1' not found."
}

# ============================================================================
# DEVELOPMENT SHORTCUTS
# ============================================================================

# Node.js/NPM
alias nr='npm run'
alias ni='npm install'
alias nid='npm install --save-dev'
alias nig='npm install -g'
alias nt='npm test'
alias ns='npm start'
alias nb='npm run build'
alias nrd='npm run dev'
alias nrdh='npm run dev -- --host' # For remote VM access

# Package manager detection and shortcuts
pkg() {
    if [[ -f "package.json" ]]; then
        if [[ -f "pnpm-lock.yaml" ]]; then
            echo "📦 Using pnpm"
            pnpm "$@"
        elif [[ -f "yarn.lock" ]]; then
            echo "📦 Using yarn"
            yarn "$@"
        else
            echo "📦 Using npm"
            npm "$@"
        fi
    elif [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]; then
        echo "🐍 Python project detected"
        echo "Use: pip install -r requirements.txt"
    elif [[ -f "Cargo.toml" ]]; then
        echo "🦀 Rust project detected"
        cargo "$@"
    else
        echo "❓ No package manager detected"
    fi
}

# Python shortcuts
alias py='python3'
alias pip='python3 -m pip'
alias venv='python3 -m venv'
alias activate='source venv/bin/activate'

# Docker shortcuts (using your existing patterns)
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dc='docker compose'
alias dcu='docker compose up'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'
alias dcb='docker compose build'

# ============================================================================
# SYSTEM & MONITORING
# ============================================================================

# System information
alias ports='lsof -i -P -n | grep LISTEN'
alias myip='curl -s https://httpbin.org/ip | jq -r .origin'
alias meminfo='free -h'
alias diskinfo='df -h'

# Enhanced system monitoring with modern tools
if command -v btm >/dev/null 2>&1; then
    alias top='btm'
    alias htop='btm'
fi

if command -v duf >/dev/null 2>&1; then
    alias df='duf'
fi

if command -v ncdu >/dev/null 2>&1; then
    alias du='ncdu'
fi

# Process management
alias psg='ps aux | grep'
killport() {
    if [[ -z "$1" ]]; then
        echo "Usage: killport <port>"
        return 1
    fi
    lsof -ti:$1 | xargs -r kill -9
    echo "Killed processes on port $1"
}

# ============================================================================
# FILE OPERATIONS
# ============================================================================

# Enhanced file operations with modern tools
if command -v bat >/dev/null 2>&1; then
    alias cat='bat --paging=never'
    alias less='bat --paging=always'
fi

if command -v rg >/dev/null 2>&1; then
    alias grep='rg'
fi

if command -v fd >/dev/null 2>&1; then
    alias find='fd'
fi

# Quick file serving
serve() {
    local port=${1:-8000}
    echo "🚀 Starting HTTP server on port $port"
    echo "📱 Access from host: http://$(hostname -I | awk '{print $1}'):$port"
    python3 -m http.server "$port"
}

# ============================================================================
# PROJECT MANAGEMENT
# ============================================================================

# Quick project setup with AI agent configuration
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
\`\`\`bash
npm run dev --host        # Development with remote access
npm run build            # Build for production
npm run test             # Run tests
npm run lint             # Lint code
\`\`\`

## Project Structure
Describe your project structure and important files here.

## Notes for Claude
Add any project-specific instructions or context for Claude Code.
EOF
    
    echo "✅ Created new project: $name"
    echo "  📁 Directory created and navigated"
    echo "  🔧 Git repository initialized"
    echo "  📝 README.md and CLAUDE.md created"
    echo "  🤖 Ready for AI development with 'yolo' or 'plan'"
}

# Project navigation with fuzzy finding
if command -v fzf >/dev/null 2>&1; then
    proj() {
        local project_dir=~/projects
        if [[ -d "$project_dir" ]]; then
            local project=$(find "$project_dir" -maxdepth 2 -type d -name .git -exec dirname {} \; | fzf)
            [[ -n "$project" ]] && cd "$project"
        else
            echo "Projects directory not found: $project_dir"
        fi
    }
fi

# ============================================================================
# UTILITIES
# ============================================================================

# Quick editing
alias v='vim'
alias n='nano'

# Archive operations
extract() {
    if [[ -f "$1" ]]; then
        case "$1" in
            *.tar.bz2)   tar xjf "$1"     ;;
            *.tar.gz)    tar xzf "$1"     ;;
            *.bz2)       bunzip2 "$1"     ;;
            *.rar)       unrar e "$1"     ;;
            *.gz)        gunzip "$1"      ;;
            *.tar)       tar xf "$1"      ;;
            *.tbz2)      tar xjf "$1"     ;;
            *.tgz)       tar xzf "$1"     ;;
            *.zip)       unzip "$1"       ;;
            *.Z)         uncompress "$1"  ;;
            *.7z)        7z x "$1"        ;;
            *)           echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# Quick system cleanup
cleanup() {
    echo "🧹 Cleaning up system..."
    sudo apt autoremove -y
    sudo apt autoclean
    sudo journalctl --vacuum-time=7d
    if command -v docker >/dev/null 2>&1; then
        docker system prune -f
    fi
    echo "✅ Cleanup complete"
}

# Show useful aliases
aliases() {
    echo "🤖 AI Agent shortcuts:"
    echo "  yolo    - Claude in YOLO mode"
    echo "  plan    - Claude in planning mode"
    echo "  loop    - Continuous development loop"
    echo ""
    echo "📁 Navigation:"
    echo "  ll, la  - Enhanced ls (with eza)"
    echo "  p       - cd ~/projects"
    echo "  ..      - cd .."
    echo ""
    echo "🔧 Development:"
    echo "  nr      - npm run"
    echo "  gs      - git status"
    echo "  tm      - tmux session"
    echo "  serve   - HTTP server"
    echo ""
    echo "💡 Use 'type <alias>' to see what an alias does"
}

# ============================================================================
# COMPLETIONS & ENHANCEMENTS
# ============================================================================

# Enable programmable completion features
if ! shopt -oq posix; then
    if [[ -f /usr/share/bash-completion/bash_completion ]]; then
        source /usr/share/bash-completion/bash_completion
    elif [[ -f /etc/bash_completion ]]; then
        source /etc/bash_completion
    fi
fi

# History optimization for VM usage
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE="ls:ll:la:cd:cd *:pwd:exit:clear:history"

# Append to history file, don't overwrite it
shopt -s histappend

# Check window size after each command
shopt -s checkwinsize

# Make less more friendly for non-text input files
[[ -x /usr/bin/lesspipe ]] && eval "$(SHELL=/bin/sh lesspipe)"

# ============================================================================
# WELCOME MESSAGE
# ============================================================================

# Show useful info when opening a new shell (only in interactive mode)
if [[ $- == *i* ]]; then
    echo "🚀 VM Development Environment Ready"
    echo "💡 Type 'aliases' to see available shortcuts"
    echo "🤖 Type 'yolo' to start AI coding with Claude"
    if command -v tmux >/dev/null 2>&1 && [[ -z "$TMUX" ]]; then
        echo "📱 Available tmux sessions:"
        tmux ls 2>/dev/null | head -3 || echo "   None (create with 'tm <name>')"
    fi
    echo ""
fi