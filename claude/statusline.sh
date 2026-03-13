#!/bin/sh
# Claude Code status line — styled to match Starship prompt (starship.toml)
# Requires: Nerd Font (e.g., JetBrainsMono Nerd Font), jq

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd')
project_dir=$(echo "$input" | jq -r '.workspace.project_dir // empty')
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# --- Directory: truncate to repo root like Starship truncate_to_repo ---
display_dir="$cwd"
if [ -n "$project_dir" ] && [ "$project_dir" != "null" ]; then
  # Show path relative to project root, prefixed with repo name
  repo_name=$(basename "$project_dir")
  case "$cwd" in
    "$project_dir"*)
      relative="${cwd#"$project_dir"}"
      display_dir="${repo_name}${relative}"
      ;;
  esac
fi

# --- Git: green #859900 when clean, orange #f5a623 when dirty ---
git_info=""
if git -C "$cwd" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" symbolic-ref --short HEAD 2>/dev/null || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$(git -C "$cwd" status --porcelain 2>/dev/null)" ]; then
    # Dirty: orange #f5a623
    git_info=$(printf "\033[38;2;245;166;35m%s\033[0m" "$branch")
  else
    # Clean: green #859900
    git_info=$(printf "\033[38;2;133;153;0m%s\033[0m" "$branch")
  fi
fi

# --- Context bar ---
ctx_info=""
if [ -n "$used" ] && [ "$used" != "null" ]; then
  pct=$(echo "$used" | cut -d. -f1)
  # Color: green < 50, yellow < 75, red >= 75
  if [ "$pct" -ge 75 ] 2>/dev/null; then
    ctx_color="\033[31m"
  elif [ "$pct" -ge 50 ] 2>/dev/null; then
    ctx_color="\033[33m"
  else
    ctx_color="\033[32m"
  fi
  ctx_info=$(printf " ${ctx_color}%s%%\033[0m" "$pct")
fi

# --- Cost ---
cost_info=""
if [ -n "$cost" ] && [ "$cost" != "null" ] && [ "$cost" != "0" ]; then
  cost_fmt=$(printf '$%.2f' "$cost")
  cost_info=$(printf " \033[38;2;166;173;200m%s\033[0m" "$cost_fmt")
fi

# --- Assemble: dir  branch [model] ctx cost ---
# Directory in #89b4fa (Catppuccin blue)
printf "\033[38;2;137;180;250m%s\033[0m" "$display_dir"

if [ -n "$git_info" ]; then
  printf " %s" "$git_info"
fi

# Model in subdued #a6adc8 (Catppuccin subtext)
printf " \033[38;2;166;173;200m%s\033[0m" "$model"

printf "%s" "$ctx_info"
printf "%s" "$cost_info"
