# Claude Code status line — styled to match Starship prompt (starship.toml)
# Requires: Nerd Font, PowerShell 7

$data = [Console]::In.ReadToEnd() | ConvertFrom-Json
$e = [char]27

$cwd = if ($data.workspace.current_dir) { $data.workspace.current_dir } else { $data.cwd }
$projectDir = $data.workspace.project_dir
$model = if ($data.model.display_name) { $data.model.display_name } else { 'Claude' }
$used = $data.context_window.used_percentage
$cost = $data.cost.total_cost_usd

# --- Directory: truncate to repo root like Starship truncate_to_repo ---
$displayDir = $cwd
if ($projectDir) {
    $repoName = Split-Path $projectDir -Leaf
    if ($cwd -and $cwd.StartsWith($projectDir)) {
        $relative = $cwd.Substring($projectDir.Length)
        $displayDir = "${repoName}${relative}"
    }
}

# --- Git: green #859900 when clean, orange #f5a623 when dirty ---
$gitInfo = ''
try {
    $isGit = git -C $cwd rev-parse --is-inside-work-tree 2>$null
    if ($isGit -eq 'true') {
        $branch = git -C $cwd symbolic-ref --short HEAD 2>$null
        if (-not $branch) { $branch = git -C $cwd rev-parse --short HEAD 2>$null }
        $dirty = git -C $cwd status --porcelain 2>$null
        if ($dirty) {
            $gitInfo = "${e}[38;2;245;166;35m${branch}${e}[0m"
        } else {
            $gitInfo = "${e}[38;2;133;153;0m${branch}${e}[0m"
        }
    }
} catch { }

# --- Context window usage ---
$ctxInfo = ''
if ($used -and $used -ne 0) {
    $pct = [math]::Floor([double]$used)
    $ctxColor = if ($pct -ge 75) { "${e}[31m" } elseif ($pct -ge 50) { "${e}[33m" } else { "${e}[32m" }
    $ctxInfo = " ${ctxColor}${pct}%${e}[0m"
}

# --- Cost ---
$costInfo = ''
if ($cost -and $cost -ne 0) {
    $costFmt = '$' + ([double]$cost).ToString('N2')
    $costInfo = " ${e}[38;2;166;173;200m${costFmt}${e}[0m"
}

# --- Assemble: dir  branch [model] ctx cost ---
$output = "${e}[38;2;137;180;250m${displayDir}${e}[0m"
if ($gitInfo) { $output += " $gitInfo" }
$output += " ${e}[38;2;166;173;200m${model}${e}[0m"
$output += $ctxInfo
$output += $costInfo

[Console]::Write($output)
