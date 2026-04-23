#!/usr/bin/env bash
# Claude Code statusline - Monokai theme

input=$(cat)

# --- CWD ---
raw_cwd=$(echo "$input" | jq -r '.cwd // empty')
if [ -n "$raw_cwd" ]; then
  home="$HOME"
  if [[ "$raw_cwd" == "$home"* ]]; then
    cwd="~${raw_cwd#$home}"
  else
    cwd="$raw_cwd"
  fi
else
  cwd="~"
fi

# --- Model ---
display_name=$(echo "$input" | jq -r '.model.display_name // empty')
if [ -n "$display_name" ]; then
  model_label="$display_name"
else
  model_label="--"
fi

# --- Context bar and percentage ---
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

BAR_FILLED="█"
BAR_EMPTY="░"
BAR_LEN=10

# Colors (truecolor ANSI)
COLOR_PURPLE="\033[38;2;174;129;255m"
COLOR_ORANGE="\033[38;2;253;151;31m"
COLOR_GREEN="\033[38;2;166;226;46m"
COLOR_YELLOW="\033[38;2;230;219;116m"
COLOR_RED="\033[38;2;249;38;114m"
COLOR_GREY="\033[38;2;117;113;94m"
COLOR_RESET="\033[0m"

if [ -n "$used_pct" ]; then
  used_int=$(printf "%.0f" "$used_pct")

  # Pick color based on percentage
  if [ "$used_int" -ge 90 ]; then
    bar_color="$COLOR_RED"
  elif [ "$used_int" -ge 70 ]; then
    bar_color="$COLOR_YELLOW"
  else
    bar_color="$COLOR_GREEN"
  fi

  # Build bar
  filled=$(( used_int * BAR_LEN / 100 ))
  empty=$(( BAR_LEN - filled ))
  bar=""
  for i in $(seq 1 $filled); do bar="${bar}${BAR_FILLED}"; done
  for i in $(seq 1 $empty);  do bar="${bar}${BAR_EMPTY}";  done

  pct_label="${used_int}%"
else
  bar_color="$COLOR_GREY"
  bar=""
  for i in $(seq 1 $BAR_LEN); do bar="${bar}${BAR_EMPTY}"; done
  pct_label="--"
fi

# --- Output ---
printf "${COLOR_PURPLE}%s${COLOR_RESET}  ${COLOR_ORANGE}%s${COLOR_RESET}  ${bar_color}%s${COLOR_RESET}  ${bar_color}%s${COLOR_RESET}" \
  "$cwd" "$model_label" "$bar" "$pct_label"
