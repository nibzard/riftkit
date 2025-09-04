# 🚀 RiftKit

AI-focused dotfiles for remote VM development. Optimized for Claude Code, Amp, and modern CLI tools. One-liner install for instant productivity.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub stars](https://img.shields.io/github/stars/nibzard/riftkit.svg)](https://github.com/nibzard/riftkit/stargazers)

## 🏃‍♂️ Quick Install

**One-liner install (recommended):**
```bash
curl -fsSL https://raw.githubusercontent.com/nibzard/riftkit/main/install.sh | bash
```

**Or clone and run:**
```bash
git clone https://github.com/nibzard/riftkit.git ~/.dotfiles
cd ~/.dotfiles && sudo ./setup.sh
```

## ✨ Features

- **🤖 AI Agent Optimized**: Built-in support for Claude Code, Amp, and other AI tools
- **📱 Remote VM Friendly**: All tools work great over SSH with minimal resource usage
- **⚡ YOLO Mode Ready**: Shortcuts and configs for rapid AI-assisted development
- **🛠️ Modern CLI Tools**: eza, bat, fzf, ripgrep, delta, and more
- **🔧 Modular Installation**: Choose exactly what you need
- **📋 Smart Aliases**: Productivity shortcuts for common development tasks

## 🚀 Quick Start

### Installation Options

The one-liner above installs the "agent" profile (essential tools + AI agents). For other options:

### Installation Profiles

```bash
# Agent Profile (default) - Essential tools + AI agents (~2-3 min)
sudo ./setup.sh agent

# Full Profile - Everything including modern CLI tools (~5-7 min)  
sudo ./setup.sh full

# Custom Profile - Interactive selection
sudo ./setup.sh custom

# Non-interactive installation
sudo ./setup.sh agent --non-interactive
```

## 🤖 AI Agent Usage

### Claude Code (Primary)

```bash
# YOLO mode - Auto-accept edits (fast development)
yolo

# Planning mode - Review before executing
plan  

# Safe mode - Prompt for each action
claude-safe

# Continuous development loop
echo "Your task description" > prompt.md
loop
```

### Project Setup

```bash
# Create new project with AI configuration
new-project my-awesome-app

# This creates:
# ├── README.md
# ├── CLAUDE.md (AI instructions)  
# └── .git/ (initialized repo)
```

### Authentication

```bash
# Authenticate Claude Code
claude auth login

# Check agent status
agent-status
```

## 📦 What Gets Installed

### Agent Profile (Default)
- **Core Tools**: Git, Node.js 20, tmux, essential packages
- **AI Agents**: Claude Code, Amp CLI
- **Aliases**: AI-focused productivity shortcuts
- **Shell Config**: Enhanced bash with completions

### Full Profile  
- **Everything in Agent** +
- **Modern CLI**: eza, bat, fzf, ripgrep, fd, delta, lazygit, lazydocker
- **System Tools**: bottom, duf, ncdu, procs
- **Python Tools**: poetry, black, pytest
- **Shell Enhancement**: starship prompt, zoxide

## 🔧 Key Aliases & Functions

### AI Development
```bash
yolo              # Claude in YOLO mode
plan              # Claude in planning mode  
loop              # Continuous development with prompt.md
new-project name  # Create project with AI config
agent-status      # Check AI agent status
```

### Navigation & Files
```bash
ll                # Enhanced ls (with eza if available)
p                 # cd ~/projects
..                # cd ..
proj              # Fuzzy find projects (with fzf)
```

### Git Shortcuts  
```bash
gs                # git status
ga                # git add
gc "msg"          # git commit -m "msg"  
gcp "msg"         # add, commit, and push
gp                # git push
```

### Development
```bash
nr dev            # npm run dev
nr build          # npm run build
serve             # HTTP server (python3 -m http.server)
killport 3000     # Kill process on port 3000
pkg install       # Smart package manager (detects npm/yarn/pnpm)
```

### Tmux Sessions
```bash
tm coding         # Create/attach to "coding" session
tl                # List sessions
tr session-name   # Remove session
```

### System Monitoring
```bash
ports             # Show listening ports
./scripts/monitor.sh     # Resource monitoring
./scripts/monitor.sh -c  # Continuous monitoring
```

## 📁 Directory Structure

```
~/.dotfiles/
├── setup.sh              # Main installer
├── README.md             # This file
├── lib/
│   └── common.sh         # Shared functions
├── modules/
│   ├── core.sh           # Essential tools
│   ├── agents.sh         # AI agents
│   └── modern_cli.sh     # Modern CLI tools
├── config/
│   └── .bash_aliases     # Productivity aliases
├── scripts/
│   ├── kill_ports.sh     # Enhanced port killer
│   └── monitor.sh        # Resource monitoring
└── [legacy scripts]      # Original scripts (for reference)
```

## 🔧 Configuration Files Created

- `~/.bash_aliases` - Productivity aliases and functions
- `~/.claude/CLAUDE.md` - Global AI agent instructions
- `~/.tmux.conf` - Enhanced tmux configuration
- Shell integrations for modern tools (zoxide, starship, etc.)

## 💡 Remote VM Tips

### Development Servers
```bash
# Always use --host for external access
npm run dev -- --host
python manage.py runserver 0.0.0.0:8000
```

### Access from Host Machine
```bash
# Your VM's IP (shown in aliases welcome message)
http://VM_IP:3000
```

### Tmux for Persistence  
```bash
# Keep development sessions running
tm frontend    # Frontend development
tm backend     # Backend services  
tm ai          # AI coding session
```

### Resource Management
```bash
# Monitor VM resources
./scripts/monitor.sh --continuous

# Clean up when needed
cleanup        # System cleanup (apt, docker, logs)
```

## 🎯 AI Development Workflows

### Rapid Prototyping
```bash
new-project quick-test
cd quick-test
yolo           # Start AI coding immediately
```

### Continuous Development
```bash
# Create task description
cat > prompt.md << 'EOF'
Add a user authentication system with:
- Login/register forms
- JWT tokens
- Protected routes
- User profile page
EOF

# Run continuous development loop
loop
```

### Safe Development
```bash
plan           # Review changes before applying
claude-safe    # Prompt for each action
```

## 🛠️ Customization

### Adding Your Own Aliases
Edit `~/.bash_aliases` and source it:
```bash
vim ~/.bash_aliases
source ~/.bash_aliases
```

### Project-Specific AI Instructions
Create `CLAUDE.md` in your project root:
```markdown
# Project: My App

## Development Commands
npm run dev --host
npm run build
npm test

## Architecture Notes
- Next.js with TypeScript
- Tailwind CSS for styling
- Prisma ORM with PostgreSQL

## Current Task
Working on user authentication system
```

### Custom Claude Configuration
Edit `~/.claude/CLAUDE.md` for global AI instructions.

## 🐛 Troubleshooting

### AI Agents Not Found
```bash
# Check PATH refresh
echo $PATH | grep npm-global

# Logout and login again, or:
source ~/.bashrc
```

### Permission Issues
```bash
# Ensure proper npm global setup
npm config get prefix  # Should show ~/.npm-global
```

### Port Access Issues
```bash
# Check if processes are blocking ports
./scripts/kill_ports.sh
./scripts/kill_ports.sh -p 3000  # Specific port
```

### Resource Monitoring
```bash
# Check VM resources
./scripts/monitor.sh --alert  # Show only problems
./scripts/monitor.sh --json   # Machine-readable output
```

## 📊 Performance

- **Agent Profile**: ~2-3 minutes installation
- **Full Profile**: ~5-7 minutes installation  
- **Memory Usage**: ~50-100MB additional
- **Disk Usage**: ~500MB-1GB depending on profile

## 🔄 Updates

```bash
cd ~/.dotfiles
git pull origin main
sudo ./setup.sh --skip-existing  # Update without reinstalling
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test on a fresh VM
5. Submit a pull request

## 📄 License

MIT License - feel free to use and modify for your needs.

## 🙏 Acknowledgments

- Built for developers using Claude Code and AI agents
- Inspired by the needs of remote VM development
- Optimized for speed and minimal resource usage

---

**Happy AI coding! 🤖✨**

*Use `yolo` to start and `aliases` to explore all available shortcuts.*