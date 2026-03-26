# =============================================================================
# Home aliases — loaded on home machines (PowerShell)
# =============================================================================

function Switch-RainmeterTheme {
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$ThemeName
    )
    $themesDir = Join-Path $PSScriptRoot '..\..\rainmeter\EarlSkins\@Resources\themes' | Resolve-Path -ErrorAction SilentlyContinue
    if (-not $themesDir) {
        # Fallback: find it relative to the repo
        $themesDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'rainmeter\EarlSkins\@Resources\themes'
    }
    $themeFile = Join-Path $themesDir "$ThemeName.inc"
    if (-not (Test-Path $themeFile)) {
        Write-Host "Theme '$ThemeName' not found. Available themes:" -ForegroundColor Red
        Get-ChildItem $themesDir -Filter '*.inc' |
            Where-Object { $_.Name -ne 'current.inc' -and $_.Name -ne 'template.inc' } |
            ForEach-Object { Write-Host "  $($_.BaseName)" -ForegroundColor Cyan }
        return
    }
    $currentLink = Join-Path $themesDir 'current.inc'
    Remove-Item $currentLink -Force -ErrorAction SilentlyContinue
    New-Item -ItemType SymbolicLink -Path $currentLink -Value $themeFile -Force | Out-Null
    Write-Host "Theme switched to '$ThemeName'." -ForegroundColor Green

    $rmExe = "${env:ProgramFiles}\Rainmeter\Rainmeter.exe"
    if ((Get-Process -Name Rainmeter -ErrorAction SilentlyContinue) -and (Test-Path $rmExe)) {
        & $rmExe !RefreshApp
        Write-Host "Rainmeter refreshed." -ForegroundColor Green
    } else {
        Write-Host "Refresh Rainmeter to apply." -ForegroundColor Yellow
    }
}
