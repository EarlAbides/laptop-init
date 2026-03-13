#!/usr/bin/env zsh

# -----------------------------------------------------------------------------
# laptop-init: Fresh machine bootstrap
# Sets up a macOS machine with your preferred tools, shell, and configs.
# Supports work/home profiles for machine-specific configuration.
# -----------------------------------------------------------------------------

set -e

SCRIPT_DIR="${0:a:h}"
PROFILE_FILE="$HOME/.laptop-profile"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info()  { echo "${CYAN}[info]${NC}  $1" }
ok()    { echo "${GREEN}[ok]${NC}    $1" }
warn()  { echo "${YELLOW}[warn]${NC}  $1" }
err()   { echo "${RED}[error]${NC} $1" }

# --- Profile Selection ---
select_profile() {
  if [[ -f "$PROFILE_FILE" ]]; then
    PROFILE=$(cat "$PROFILE_FILE")
    info "Detected existing profile: $PROFILE"
    echo -n "Keep this profile? [Y/n] "
    read -r response
    if [[ "$response" =~ ^[Nn] ]]; then
      unset PROFILE
    fi
  fi

  if [[ -z "$PROFILE" ]]; then
    echo ""
    echo "Select a profile:"
    echo "  1) work"
    echo "  2) home"
    echo -n "Choice [1/2]: "
    read -r choice
    case "$choice" in
      1) PROFILE="work" ;;
      2) PROFILE="home" ;;
      *) err "Invalid choice"; exit 1 ;;
    esac
    echo "$PROFILE" > "$PROFILE_FILE"
    ok "Profile set to: $PROFILE"
  fi
}

# --- Homebrew ---
install_homebrew() {
  if command -v brew &>/dev/null; then
    ok "Homebrew already installed"
  else
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add Homebrew to PATH for Apple Silicon
    if [[ -f /opt/homebrew/bin/brew ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
    ok "Homebrew installed"
  fi
}

install_packages() {
  info "Installing shared packages..."
  brew bundle --file="$SCRIPT_DIR/Brewfile.shared"
  local profile_brewfile="$SCRIPT_DIR/Brewfile.$PROFILE"
  if [[ -f "$profile_brewfile" ]]; then
    info "Installing $PROFILE profile packages..."
    brew bundle --file="$profile_brewfile"
  fi
  ok "Packages installed"
}

# --- Shell Configuration ---
configure_shell() {
  info "Configuring shell..."

  # Symlink .zshrc
  if [[ -f "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
    warn "Backing up existing .zshrc to .zshrc.bak"
    cp "$HOME/.zshrc" "$HOME/.zshrc.bak"
  fi
  ln -sf "$SCRIPT_DIR/shell/zshrc" "$HOME/.zshrc"
  ok "Linked .zshrc"

  # Symlink shared aliases
  ln -sf "$SCRIPT_DIR/shell/aliases.shared" "$HOME/.aliases.shared"
  ok "Linked shared aliases"

  # Symlink profile-specific aliases
  local profile_aliases="$SCRIPT_DIR/shell/aliases.$PROFILE"
  if [[ -f "$profile_aliases" ]]; then
    ln -sf "$profile_aliases" "$HOME/.aliases.profile"
    ok "Linked $PROFILE aliases"
  fi
}

# --- Starship ---
configure_starship() {
  info "Configuring Starship prompt..."
  mkdir -p "$HOME/.config"
  ln -sf "$SCRIPT_DIR/starship/starship.toml" "$HOME/.config/starship.toml"
  ok "Linked starship.toml"
}

# --- Git ---
configure_git() {
  info "Configuring git..."

  # Symlink shared gitconfig
  ln -sf "$SCRIPT_DIR/git/gitconfig.shared" "$HOME/.gitconfig.shared"

  # Symlink profile gitconfig
  local profile_gitconfig="$SCRIPT_DIR/git/gitconfig.$PROFILE"
  if [[ -f "$profile_gitconfig" ]]; then
    ln -sf "$profile_gitconfig" "$HOME/.gitconfig.profile"
  fi

  # Create main .gitconfig that includes both (if not already configured)
  if ! git config --global --get include.path "$HOME/.gitconfig.shared" &>/dev/null; then
    git config --global --add include.path "$HOME/.gitconfig.shared"
    ok "Added shared gitconfig include"
  fi

  if ! git config --global --get include.path "$HOME/.gitconfig.profile" &>/dev/null; then
    git config --global --add include.path "$HOME/.gitconfig.profile"
    ok "Added profile gitconfig include"
  fi

  ok "Git configured"
}

# --- Claude Code ---
configure_claude_code() {
  info "Configuring Claude Code status line..."
  mkdir -p "$HOME/.claude"

  # Symlink the status line script
  ln -sf "$SCRIPT_DIR/claude/statusline.sh" "$HOME/.claude/statusline-command.sh"
  ok "Linked statusline script"

  # Merge statusLine config into settings.json (preserves existing settings)
  local settings="$HOME/.claude/settings.json"
  local sl_config='{"statusLine":{"type":"command","command":"bash ~/.claude/statusline-command.sh"}}'
  if [[ -f "$settings" ]]; then
    local merged
    merged=$(jq --argjson sl "$sl_config" '. * $sl' "$settings")
    echo "$merged" > "$settings"
  else
    echo "$sl_config" | jq . > "$settings"
  fi
  ok "Claude Code status line configured"
}

# --- iTerm2 ---
configure_iterm2() {
  info "Configuring iTerm2..."
  # Tell iTerm2 to load preferences from our repo
  defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$SCRIPT_DIR/iterm2"
  defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
  # Save changes back to the custom folder on quit
  defaults write com.googlecode.iterm2 NoSyncNeverRemindPrefsChangesLostForFile_selection -int 2
  ok "iTerm2 configured to load/save preferences from $SCRIPT_DIR/iterm2"
}

# --- Remove OMZ (if present) ---
remove_omz() {
  if [[ -d "$HOME/.oh-my-zsh" ]]; then
    warn "Oh My Zsh detected. Removing..."
    rm -rf "$HOME/.oh-my-zsh"
    ok "Oh My Zsh removed"
  fi
}

# --- Main ---
main() {
  echo ""
  echo "========================================="
  echo "  laptop-init"
  echo "  Fresh machine bootstrap"
  echo "========================================="
  echo ""

  select_profile
  install_homebrew
  install_packages
  remove_omz
  configure_shell
  configure_starship
  configure_git
  configure_claude_code
  configure_iterm2

  # Run profile-specific setup if it exists
  local profile_script="$SCRIPT_DIR/profiles/$PROFILE.sh"
  if [[ -f "$profile_script" ]]; then
    info "Running $PROFILE profile setup..."
    source "$profile_script"
    ok "$PROFILE profile setup complete"
  fi

  echo ""
  ok "========================================="
  ok "  Setup complete!"
  ok "  Profile: $PROFILE"
  ok "  Restart your terminal to apply changes."
  ok "========================================="
  echo ""
}

main "$@"
