# =============================================================================
# Shared aliases — loaded on all machines (PowerShell)
# =============================================================================

# --- Kubernetes ---
Set-Alias -Name k -Value kubectl -ErrorAction SilentlyContinue

# --- Git shortcuts ---
function gs { git status @args }
function gd { git diff @args }
function gl { git log --oneline -20 @args }
function gp { git pull @args }

# --- General ---
function ll { Get-ChildItem -Force @args }
function la { Get-ChildItem -Force -Name @args }

# --- Markdown reader (requires pandoc + lynx) ---
function rmd {
    param([string]$Path)
    pandoc $Path | lynx -stdin
}
