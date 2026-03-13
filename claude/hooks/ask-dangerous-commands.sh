#!/usr/bin/env bash
# PreToolUse hook: Force a permission prompt when dangerous commands are
# detected anywhere in a Bash command string (including pipes, chains,
# bash -c, etc.).
#
# The settings.json `ask` rules only match prefix (first command in a string).
# This hook scans the ENTIRE command string with word-boundary matching,
# catching cloud tools after pipes, in chains, and in subshells.
#
# Dependencies: jq
#
# Exit behavior:
#   - Dangerous tool found: outputs permissionDecision "ask" (forces prompt)
#   - No match: exits 0 silently (falls through to normal permission check)
#   - Error/missing deps: exits 0 silently (safe fallthrough)

set -euo pipefail

DANGEROUS_COMMANDS=(
  aws
  kubectl
  helm
  terraform
  gcloud
  curl
  wget
)

# Build regex pattern from the array: \b(aws|kubectl|helm|...)\b
# Uses \b word boundaries to avoid false positives (e.g., "awscli" won't match "aws")
PATTERN=$(IFS='|'; echo "\b(${DANGEROUS_COMMANDS[*]})\b")

# Read hook input from stdin
INPUT=$(cat) || exit 0
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0

# If no command or empty, fall through
[[ -z "$COMMAND" ]] && exit 0

# Check if any dangerous command appears anywhere in the command string
if echo "$COMMAND" | grep -qE "$PATTERN"; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Command contains a potentially dangerous tool. Please review before approving."}}'
fi

exit 0
