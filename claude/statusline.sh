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
  if [ ${#branch} -gt 40 ]; then
    branch="$(printf '%.37s' "$branch")..."
  fi
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
  # Color in 20% bands, matching the cmux card meter (cmux/sidebars/cards.js):
  # green, yellow-green, amber, amber-red, red
  if [ "$pct" -ge 80 ] 2>/dev/null; then
    ctx_color="\033[38;2;229;83;75m"
  elif [ "$pct" -ge 60 ] 2>/dev/null; then
    ctx_color="\033[38;2;229;122;60m"
  elif [ "$pct" -ge 40 ] 2>/dev/null; then
    ctx_color="\033[38;2;224;160;48m"
  elif [ "$pct" -ge 20 ] 2>/dev/null; then
    ctx_color="\033[38;2;168;197;69m"
  else
    ctx_color="\033[38;2;95;184;120m"
  fi
  ctx_info=$(printf " ${ctx_color}%s%%\033[0m" "$pct")
fi

# --- Cost ---
cost_info=""
if [ -n "$cost" ] && [ "$cost" != "null" ] && [ "$cost" != "0" ]; then
  cost_fmt=$(printf '$%.2f' "$cost")
  cost_info=$(printf " \033[38;2;166;173;200m%s\033[0m" "$cost_fmt")
fi

# --- Ponytail mode badge ---
# ${CLAUDE_CONFIG_DIR:-~/.claude}/.ponytail-active holds the level; absent = off.
pony_info=""
pony_flag="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.ponytail-active"
if [ -f "$pony_flag" ]; then
  mode=$(head -n1 "$pony_flag" | tr -d '[:space:]')
  # ultra amber #d7875f, everything else green #87af87
  if [ "$mode" = "ultra" ]; then
    pony_color="\033[38;2;215;135;95m"
  else
    pony_color="\033[38;2;135;175;135m"
  fi
  if [ -z "$mode" ] || [ "$mode" = "full" ]; then
    pony_info=$(printf " ${pony_color}[PONYTAIL]\033[0m")
  else
    pony_info=$(printf " ${pony_color}[PONYTAIL:%s]\033[0m" "$(printf '%s' "$mode" | tr '[:lower:]' '[:upper:]')")
  fi
fi

# --- cmux: publish stats for the workspace card (cmux/sidebars/cards.js) ---
# The custom sidebar can read a workspace's progress but not its statuses, so
# progress carries them: value = context used, label = "model · cost".
# ponytail: one progress slot per workspace, so two Claude tabs in one
# workspace overwrite each other; last render wins.
if [ -n "$CMUX_WORKSPACE_ID" ] && command -v cmux >/dev/null 2>&1 && [ -n "$pct" ]; then
  card_label=$(printf '%s' "$model" | sed 's/ (\(.*\) context)/ \1/')
  [ -n "$cost_fmt" ] && card_label="$card_label · $cost_fmt"
  (cmux set-progress "$(awk "BEGIN{print $pct/100}")" --label "$card_label" >/dev/null 2>&1 &)
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
printf "%s" "$pony_info"
