# =============================================================================
# PowerShell 7 profile — managed by laptop-init
# =============================================================================

# --- Local binaries ---
$localBin = Join-Path $HOME '.local\bin'
if (Test-Path $localBin) {
    $env:PATH = "$localBin;$env:PATH"
}

# --- PSReadLine (autosuggestions + syntax highlighting) ---
if (Get-Module -ListAvailable PSReadLine) {
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle InlineView
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -MaximumHistoryCount 10000

    # History search with arrow keys (like zsh up-arrow search)
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

    # Solarized-friendly syntax colors (matches iTerm2 terminal scheme)
    Set-PSReadLineOption -Colors @{
        Command            = '#268BD2'   # Solarized blue
        Parameter          = '#839496'   # Solarized base0
        Operator           = '#2AA198'   # Solarized cyan
        Variable           = '#B58900'   # Solarized yellow
        String             = '#859900'   # Solarized green
        Number             = '#CB4B16'   # Solarized orange
        Type               = '#B58900'   # Solarized yellow
        Comment            = '#586E75'   # Solarized base01
        Keyword            = '#6C71C4'   # Solarized violet
        Error              = '#DC322F'   # Solarized red
        InlinePrediction   = '#586E75'   # Solarized base01 (subdued)
        ListPrediction     = '#839496'   # Solarized base0
        ListPredictionSelected = '#073642' # Solarized base02
    }
}

# --- Aliases ---
$profileDir = Split-Path $PROFILE -Parent
$sharedAliases = Join-Path $profileDir 'aliases\aliases.shared.ps1'
$profileAliases = Join-Path $profileDir 'aliases\aliases.profile.ps1'
if (Test-Path $sharedAliases) { . $sharedAliases }
if (Test-Path $profileAliases) { . $profileAliases }

# --- Starship Prompt ---
if (Get-Command starship -ErrorAction SilentlyContinue) {
    Invoke-Expression (&starship init powershell)
}
