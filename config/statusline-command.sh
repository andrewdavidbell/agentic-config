#!/bin/sh
# Claude Code status line command
# Reads JSON from stdin and prints a status line

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
model=$(echo "$input" | jq -r '.model.display_name // empty')
remaining=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
session_name=$(echo "$input" | jq -r '.session_name // empty')

# Git branch (skip optional locks)
branch=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir > /dev/null 2>&1; then
    branch=$(git -C "$cwd" -c core.fsmonitor=false symbolic-ref --short HEAD 2>/dev/null \
             || git -C "$cwd" -c core.fsmonitor=false rev-parse --short HEAD 2>/dev/null)
fi

# Build status line parts
parts=""

# Directory
if [ -n "$cwd" ]; then
    dir=$(basename "$cwd")
    parts="${parts}$(printf '\033[34m%s\033[0m' "$dir")"
fi

# Git branch
if [ -n "$branch" ]; then
    parts="${parts} $(printf '\033[33m\xef\x9c\xb0 %s\033[0m' "$branch")"
fi

# Session name
if [ -n "$session_name" ]; then
    parts="${parts} $(printf '\033[35m[%s]\033[0m' "$session_name")"
fi

# Model
if [ -n "$model" ]; then
    parts="${parts} $(printf '\033[36m%s\033[0m' "$model")"
fi

# Context remaining
if [ -n "$remaining" ]; then
    pct=$(printf '%.0f' "$remaining")
    if [ "$pct" -le 20 ]; then
        color='\033[31m'
    elif [ "$pct" -le 50 ]; then
        color='\033[33m'
    else
        color='\033[32m'
    fi
    parts="${parts} $(printf "${color}ctx:%s%%\033[0m" "$pct")"
fi

printf '%s' "$parts"
