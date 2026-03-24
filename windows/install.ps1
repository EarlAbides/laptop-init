#Requires -Version 7.0

# -----------------------------------------------------------------------------
# laptop-init: Fresh machine bootstrap (Windows)
# Sets up a Windows machine with your preferred tools, shell, and configs.
# Supports work/home profiles for machine-specific configuration.
# Requires: PowerShell 7, Developer Mode enabled (for symlinks)
# Run: pwsh -ExecutionPolicy Bypass -File .\windows\install.ps1
# -----------------------------------------------------------------------------

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot
$RepoRoot = Split-Path $ScriptDir -Parent
$ProfileFile = Join-Path $HOME '.laptop-profile'

# --- Colors ---
function Write-Info  { param($msg) Write-Host "[info]  $msg" -ForegroundColor Cyan }
function Write-Ok    { param($msg) Write-Host "[ok]    $msg" -ForegroundColor Green }
function Write-Warn  { param($msg) Write-Host "[warn]  $msg" -ForegroundColor Yellow }
function Write-Err   { param($msg) Write-Host "[error] $msg" -ForegroundColor Red }

# --- Preflight checks ---
function Test-Preflight {
    # Developer Mode (needed for symlinks without admin)
    $devMode = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
        -Name 'AllowDevelopmentWithoutDevLicense' -ErrorAction SilentlyContinue
    if (-not $devMode -or $devMode.AllowDevelopmentWithoutDevLicense -ne 1) {
        Write-Warn "Developer Mode is not enabled. Symlinks may require admin elevation."
        Write-Warn "Enable it: Settings > System > For Developers > Developer Mode"
    }
}

# --- Profile Selection ---
function Select-LaptopProfile {
    $script:LaptopProfile = $null
    if (Test-Path $ProfileFile) {
        $script:LaptopProfile = (Get-Content $ProfileFile -Raw).Trim()
        Write-Info "Detected existing profile: $script:LaptopProfile"
        $response = Read-Host "Keep this profile? [Y/n]"
        if ($response -match '^[Nn]') { $script:LaptopProfile = $null }
    }

    if (-not $script:LaptopProfile) {
        Write-Host "`nSelect a profile:"
        Write-Host "  1) work"
        Write-Host "  2) home"
        $choice = Read-Host "Choice [1/2]"
        switch ($choice) {
            '1' { $script:LaptopProfile = 'work' }
            '2' { $script:LaptopProfile = 'home' }
            default { Write-Err "Invalid choice"; exit 1 }
        }
        $script:LaptopProfile | Set-Content $ProfileFile
        Write-Ok "Profile set to: $script:LaptopProfile"
    }
}

# --- Scoop (Nerd Fonts only — winget doesn't handle font installation well) ---
function Install-Scoop {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Ok "Scoop already installed"
    } else {
        Write-Info "Installing Scoop (for Nerd Font installation)..."
        Invoke-RestMethod get.scoop.sh | Invoke-Expression
        Write-Ok "Scoop installed"
    }

    # Scoop requires git for bucket management
    if (-not (scoop list git 2>$null | Select-String 'git')) {
        Write-Info "Installing git for Scoop bucket support..."
        scoop install git
    }

    $existing = scoop bucket list | Select-Object -ExpandProperty Name
    if ('nerd-fonts' -notin $existing) {
        Write-Info "Adding Scoop nerd-fonts bucket"
        scoop bucket add nerd-fonts
    }
    Write-Ok "Scoop configured"
}

# --- Packages ---
function Install-Packages {
    Write-Info "Installing tools via winget..."
    $wingetPackages = @(
        @{ Id = 'Starship.Starship';     Name = 'Starship' }
        @{ Id = 'jqlang.jq';             Name = 'jq' }
        @{ Id = 'JernejSimoncic.Wget';   Name = 'Wget' }
        @{ Id = 'aristocratos.btop4win'; Name = 'btop' }
        @{ Id = 'dbrgn.tealdeer';        Name = 'tealdeer' }
        @{ Id = 'astral-sh.uv';          Name = 'uv' }
        @{ Id = 'GitHub.cli';            Name = 'GitHub CLI' }
        @{ Id = 'OpenJS.NodeJS';         Name = 'Node.js' }
    )
    foreach ($pkg in $wingetPackages) {
        $installed = winget list --id $pkg.Id --accept-source-agreements 2>$null
        if ($LASTEXITCODE -ne 0 -or $installed -notmatch [regex]::Escape($pkg.Id)) {
            Write-Info "Installing $($pkg.Name)..."
            winget install --id $pkg.Id --accept-package-agreements --accept-source-agreements
        }
    }
    Write-Ok "Tools installed"

    Write-Info "Installing Nerd Fonts via Scoop..."
    # Equivalent to the Brewfile.shared Nerd Font casks
    # Run 'scoop search nerd-font' to see all available fonts
    $fonts = @(
        '0xProto-NF'
        '3270-NF'
        'FiraCode-NF'
        'Meslo-NF'
        'Monofur-NF'
        'ProFont-NF'
        'SourceCodePro-NF'
        'Terminus-NF'
    )
    foreach ($font in $fonts) {
        scoop install $font 2>$null
    }
    Write-Ok "Nerd Fonts installed"
}

# --- PowerShell Profile ---
function Configure-Shell {
    Write-Info "Configuring PowerShell profile..."
    $psProfileDir = Split-Path $PROFILE -Parent
    if (-not (Test-Path $psProfileDir)) {
        New-Item -ItemType Directory -Path $psProfileDir -Force | Out-Null
    }

    # Back up existing profile if it's a real file (not already a symlink)
    if ((Test-Path $PROFILE) -and -not (Get-Item $PROFILE).LinkType) {
        Write-Warn "Backing up existing profile to Microsoft.PowerShell_profile.ps1.bak"
        Copy-Item $PROFILE "$PROFILE.bak"
    }

    # Symlink profile
    New-Item -ItemType SymbolicLink -Path $PROFILE `
        -Value "$ScriptDir\powershell\profile.ps1" -Force | Out-Null
    Write-Ok "Linked PowerShell profile"

    # Symlink aliases into profile directory
    $aliasDir = Join-Path $psProfileDir 'aliases'
    if (-not (Test-Path $aliasDir)) {
        New-Item -ItemType Directory -Path $aliasDir -Force | Out-Null
    }

    New-Item -ItemType SymbolicLink -Path "$aliasDir\aliases.shared.ps1" `
        -Value "$ScriptDir\powershell\aliases.shared.ps1" -Force | Out-Null
    Write-Ok "Linked shared aliases"

    $profileAliases = "$ScriptDir\powershell\aliases.$script:LaptopProfile.ps1"
    if (Test-Path $profileAliases) {
        New-Item -ItemType SymbolicLink -Path "$aliasDir\aliases.profile.ps1" `
            -Value $profileAliases -Force | Out-Null
        Write-Ok "Linked $script:LaptopProfile aliases"
    }
}

# --- Starship ---
function Configure-Starship {
    Write-Info "Configuring Starship prompt..."
    $configDir = Join-Path $HOME '.config'
    if (-not (Test-Path $configDir)) {
        New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    }

    # Share the same starship.toml with macOS
    New-Item -ItemType SymbolicLink -Path "$configDir\starship.toml" `
        -Value "$RepoRoot\starship\starship.toml" -Force | Out-Null
    Write-Ok "Linked starship.toml (shared cross-platform config)"
}

# --- Git ---
function Configure-Git {
    Write-Info "Configuring git..."

    # Use forward-slash paths for git config (works cross-platform)
    $sharedGitconfig = "$RepoRoot/git/gitconfig.shared" -replace '\\', '/'
    $profileGitconfig = "$RepoRoot/git/gitconfig.$script:LaptopProfile" -replace '\\', '/'

    $existingIncludes = git config --global --get-all include.path 2>$null
    if ($existingIncludes -notcontains $sharedGitconfig) {
        git config --global --add include.path $sharedGitconfig
        Write-Ok "Added shared gitconfig include"
    }

    $profileGitconfigWin = "$RepoRoot\git\gitconfig.$script:LaptopProfile"
    if ((Test-Path $profileGitconfigWin) -and ($existingIncludes -notcontains $profileGitconfig)) {
        git config --global --add include.path $profileGitconfig
        Write-Ok "Added profile gitconfig include"
    }

    Write-Ok "Git configured"
}

# --- Claude Code ---
function Configure-ClaudeCode {
    Write-Info "Configuring Claude Code status line..."
    $claudeDir = Join-Path $HOME '.claude'
    if (-not (Test-Path $claudeDir)) {
        New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    }

    # Symlink the status line script
    $slTarget = Join-Path $claudeDir 'statusline-command.ps1'
    New-Item -ItemType SymbolicLink -Path $slTarget `
        -Value "$ScriptDir\claude\statusline.ps1" -Force | Out-Null
    Write-Ok "Linked statusline script"

    # Merge statusLine config into settings.json
    $settingsPath = Join-Path $claudeDir 'settings.json'
    $slCommand = "pwsh -NoProfile -File `"$slTarget`""
    $slConfig = @{ statusLine = @{ type = 'command'; command = $slCommand } }

    if (Test-Path $settingsPath) {
        $existing = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
        foreach ($key in $slConfig.Keys) { $existing[$key] = $slConfig[$key] }
        $existing | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
    } else {
        $slConfig | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
    }
    Write-Ok "Claude Code status line configured"
}

# --- Windows Terminal ---
function Configure-WindowsTerminal {
    Write-Info "Configuring Windows Terminal..."

    # Find Windows Terminal settings.json
    $wtPaths = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"
    )
    $wtSettingsPath = $wtPaths | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $wtSettingsPath) {
        Write-Warn "Windows Terminal settings not found — skipping"
        Write-Warn "Install Windows Terminal, then re-run this script."
        return
    }

    # Load our config fragment
    $fragment = Get-Content "$ScriptDir\terminal\settings.json" -Raw | ConvertFrom-Json -AsHashtable

    # Load existing WT settings (strip // comments for parsing)
    $rawContent = Get-Content $wtSettingsPath -Raw
    $cleanContent = $rawContent -replace '(?m)^\s*//.*$', '' -replace ',(\s*[}\]])', '$1'
    try {
        $wt = $cleanContent | ConvertFrom-Json -AsHashtable
    } catch {
        Write-Warn "Could not parse Windows Terminal settings — skipping"
        return
    }

    # Back up
    Copy-Item $wtSettingsPath "$wtSettingsPath.bak" -Force
    Write-Ok "Backed up Windows Terminal settings"

    # Merge color scheme
    if (-not $wt.ContainsKey('schemes')) { $wt['schemes'] = @() }
    $existingSchemes = @($wt['schemes'] | ForEach-Object { $_['name'] })
    foreach ($scheme in $fragment['schemes']) {
        if ($scheme['name'] -notin $existingSchemes) {
            $wt['schemes'] = @($wt['schemes']) + $scheme
        }
    }

    # Merge profile defaults
    if (-not $wt.ContainsKey('profiles')) { $wt['profiles'] = @{} }
    if (-not $wt['profiles'].ContainsKey('defaults')) { $wt['profiles']['defaults'] = @{} }
    foreach ($key in $fragment['profileDefaults'].Keys) {
        $wt['profiles']['defaults'][$key] = $fragment['profileDefaults'][$key]
    }

    # Save
    $wt | ConvertTo-Json -Depth 20 | Set-Content $wtSettingsPath -Encoding UTF8
    Write-Ok "Windows Terminal configured with Solarized Dark + Nerd Font"
}

# --- Main ---
function Main {
    Write-Host ""
    Write-Host "========================================="
    Write-Host "  laptop-init (Windows)"
    Write-Host "  Fresh machine bootstrap"
    Write-Host "========================================="
    Write-Host ""

    Test-Preflight
    Select-LaptopProfile
    Install-Scoop
    Install-Packages
    Configure-Shell
    Configure-Starship
    Configure-Git
    Configure-ClaudeCode
    Configure-WindowsTerminal

    # Run profile-specific setup if it exists
    $profileScript = "$ScriptDir\profiles\$script:LaptopProfile.ps1"
    if (Test-Path $profileScript) {
        Write-Info "Running $script:LaptopProfile profile setup..."
        . $profileScript
        Write-Ok "$script:LaptopProfile profile setup complete"
    }

    Write-Host ""
    Write-Ok "========================================="
    Write-Ok "  Setup complete!"
    Write-Ok "  Profile: $script:LaptopProfile"
    Write-Ok "  Restart your terminal to apply changes."
    Write-Ok "========================================="
    Write-Host ""
}

Main
