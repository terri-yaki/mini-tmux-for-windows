#!/usr/bin/env bash
# ==============================================================================
# MiniTmux Web Bootstrap & Installer for macOS and Linux
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/terri-yaki/mini-tmux-for-windows/main/scripts/install.sh | bash
# ==============================================================================

set -euo pipefail

INSTALL_DIR="${MINITMUX_DIR:-$HOME/.minitmux}"
BIN_DIR="${HOME}/.local/bin"
REPO_URL="https://github.com/terri-yaki/mini-tmux-for-windows.git"

# ANSI Colors
C_CYAN='\033[36m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_RED='\033[31m'
C_RESET='\033[0m'

echo -e "${C_CYAN}================================================================${C_RESET}"
echo -e "${C_CYAN}           MiniTmux POSIX Automated Installer (macOS/Linux)     ${C_RESET}"
echo -e "${C_CYAN}================================================================${C_RESET}"

# 1. Check or install tmux dependency
if ! command -v tmux >/dev/null 2>&1; then
    echo -e "${C_YELLOW}[!] tmux not found in PATH.${C_RESET}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Installing tmux via Homebrew..."
        if command -v brew >/dev/null 2>&1; then
            brew install tmux
        else
            echo -e "${C_RED}Please install Homebrew (https://brew.sh) or install tmux manually.${C_RESET}"
        fi
    elif [ -f /etc/debian_version ]; then
        echo "Installing tmux via apt..."
        sudo apt-get update && sudo apt-get install -y tmux
    elif [ -f /etc/arch-release ]; then
        echo "Installing tmux via pacman..."
        sudo pacman -Sy --noconfirm tmux
    elif [ -f /etc/redhat-release ]; then
        echo "Installing tmux via dnf/yum..."
        sudo dnf install -y tmux 2>/dev/null || sudo yum install -y tmux
    fi
fi

# 2. Clone or update repository
if [ -d "$INSTALL_DIR/.git" ]; then
    echo -e "${C_CYAN}Updating MiniTmux in ${INSTALL_DIR}...${C_RESET}"
    git -C "$INSTALL_DIR" pull --ff-only
else
    echo -e "${C_CYAN}Cloning MiniTmux into ${INSTALL_DIR}...${C_RESET}"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/bin/mtmux" "$INSTALL_DIR/mtmux"

# Initialize default theme in user config if not present
mkdir -p "$HOME/.config/mtmux"
if [ ! -f "$HOME/.config/mtmux/current.conf" ] && [ -f "$INSTALL_DIR/etc/themes/catppuccin-mocha.conf" ]; then
    cp "$INSTALL_DIR/etc/themes/catppuccin-mocha.conf" "$HOME/.config/mtmux/current.conf"
fi

# 3. Create symlink in ~/.local/bin
mkdir -p "$BIN_DIR"
ln -sf "$INSTALL_DIR/bin/mtmux" "$BIN_DIR/mtmux"
echo -e "${C_GREEN}  PASS  Linked $BIN_DIR/mtmux -> $INSTALL_DIR/bin/mtmux${C_RESET}"

# 4. PATH and Shell completion check
PATH_CONFIGURED=0
if [[ ":$PATH:" == *":$BIN_DIR:"* ]]; then
    PATH_CONFIGURED=1
fi

SHELL_NAME="$(basename "${SHELL:-bash}")"
case "$SHELL_NAME" in
    zsh)
        RC_FILE="$HOME/.zshrc"
        COMP_LINE="eval \"\$(mtmux completion zsh)\""
        ;;
    *)
        RC_FILE="$HOME/.bashrc"
        COMP_LINE="eval \"\$(mtmux completion bash)\""
        ;;
esac

if [ -f "$RC_FILE" ]; then
    if ! grep -q "mtmux completion" "$RC_FILE" 2>/dev/null; then
        echo -e "\n# MiniTmux completion\n$COMP_LINE" >> "$RC_FILE"
        echo -e "${C_GREEN}  PASS  Added tab completion hook to $RC_FILE${C_RESET}"
    fi
    if [ "$PATH_CONFIGURED" -eq 0 ] && ! grep -q "$BIN_DIR" "$RC_FILE" 2>/dev/null; then
        echo -e "export PATH=\"$BIN_DIR:\$PATH\"" >> "$RC_FILE"
        echo -e "${C_GREEN}  PASS  Added $BIN_DIR to PATH in $RC_FILE${C_RESET}"
    fi
fi

echo -e "\n${C_GREEN}MiniTmux installed successfully!${C_RESET}"
echo -e "Run '${C_CYAN}mtmux doctor${C_RESET}' to verify your installation."
echo -e "${C_CYAN}================================================================${C_RESET}\n"
