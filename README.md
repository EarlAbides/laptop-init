# laptop-init

Bootstrap script for setting up a fresh development machine with preferred tools, shell, and configs. Supports **macOS** and **Windows**, with work/home profiles for machine-specific configuration.

## What it does

- Installs CLI tools (starship, gh, jq, wget, uv, node, etc.)
- Installs Nerd Fonts (FiraCode, Meslo, 0xProto, and more)
- Configures your shell with autosuggestions, syntax highlighting, and history search
- Sets up the [Starship](https://starship.rs) prompt with git status, language detection, and Solarized colors
- Configures git with aliases, VS Code diff/merge, and profile-based identity
- Configures the Claude Code status line
- Configures your terminal emulator (iTerm2 on macOS, Windows Terminal on Windows)

## Profiles

Choose **work** or **home** at install time. Each profile provides:

- Separate git identity (name/email)
- Profile-specific shell aliases
- Profile-specific packages
- Post-setup hook script

The selection is saved to `~/.laptop-profile` and remembered on re-runs.

## macOS

**Requires:** macOS, zsh (default shell)

```sh
./install.sh
```

Uses [Homebrew](https://brew.sh) for package management. Configures zsh with plugins (autosuggestions, syntax highlighting) and iTerm2 as the terminal.

### Structure

```
install.sh              Main bootstrap script
Brewfile.shared         Core packages (all machines)
Brewfile.home           Home profile packages
Brewfile.work           Work profile packages
shell/zshrc             Zsh configuration
shell/aliases.shared    Shared aliases
shell/aliases.home      Home aliases
shell/aliases.work      Work aliases
git/gitconfig.shared    Git aliases, diff/merge tools, LFS
git/gitconfig.home      Home git identity
git/gitconfig.work      Work git identity
starship/starship.toml  Starship prompt config (shared cross-platform)
claude/statusline.sh    Claude Code status line (bash)
iterm2/                 iTerm2 preferences
profiles/home.sh        Home post-setup hook
profiles/work.sh        Work post-setup hook
```

## Windows

**Requires:** PowerShell 7, Developer Mode enabled (for symlinks)

```powershell
pwsh -ExecutionPolicy Bypass -File .\windows\install.ps1
```

Uses [winget](https://github.com/microsoft/winget-cli) for tools and [Scoop](https://scoop.sh) for Nerd Fonts. Configures PowerShell 7 with PSReadLine (autosuggestions, syntax highlighting) and Windows Terminal with Solarized Dark + FiraCode Nerd Font.

### Structure

```
windows/install.ps1                 Main bootstrap script
windows/powershell/profile.ps1      PowerShell 7 profile
windows/powershell/aliases.shared.ps1   Shared aliases
windows/powershell/aliases.home.ps1     Home aliases
windows/terminal/settings.json      Windows Terminal config (Solarized Dark scheme + defaults)
windows/claude/statusline.ps1       Claude Code status line (PowerShell)
windows/profiles/home.ps1           Home post-setup hook
```

### Shared across platforms

- `starship/starship.toml` — same Starship config on both macOS and Windows
- `git/gitconfig.shared` — same git aliases and tool config
- `git/gitconfig.home` / `git/gitconfig.work` — same identity files

## Nerd Fonts installed

| Font | Brew cask | Scoop package |
|------|-----------|---------------|
| 0xProto | `font-0xproto-nerd-font` | `0xProto-NF` |
| 3270 | `font-3270-nerd-font` | `3270-NF` |
| Fira Code | `font-fira-code-nerd-font` | `FiraCode-NF` |
| Meslo LG | `font-meslo-lg-nerd-font` | `Meslo-NF` |
| Monofur | `font-monofur-nerd-font` | `Monofur-NF` |
| ProFont | `font-profont-nerd-font` | `ProFont-NF` |
| Sauce Code Pro | `font-sauce-code-pro-nerd-font` | `SourceCodePro-NF` |
| Terminess | `font-terminess-ttf-nerd-font` | `Terminus-NF` |
