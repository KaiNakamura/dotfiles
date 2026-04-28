#!/usr/bin/env bash
# PreToolUse hook: Force a permission prompt when dangerous commands are
# detected anywhere in a Bash command string (including pipes, chains,
# bash -c, etc.).
#
# The settings.json `ask` rules only match prefix (first command in a string).
# This hook scans the ENTIRE command string with word-boundary matching,
# catching cloud tools after pipes, in chains, and in subshells.
#
# Skipped entirely in auto/dontAsk/bypassPermissions modes.
# Read-only invocations (aws s3 ls, kubectl get, helm list, etc.) are always allowed.
#
# Dependencies: jq
#
# Exit behavior:
#   - Unattended mode: exits 0 (no prompt)
#   - Read-only command: exits 0 (no prompt)
#   - Dangerous tool found: outputs permissionDecision "ask" (forces prompt)
#   - No match: exits 0 silently (falls through to normal permission check)
#   - Error/missing deps: exits 0 silently (safe fallthrough)

set -euo pipefail

# Read hook input from stdin
INPUT=$(cat) || exit 0

# Skip in unattended modes -- user has intentionally granted broad trust
PERMISSION_MODE=$(echo "$INPUT" | jq -r '.permission_mode // empty' 2>/dev/null) || exit 0
case "$PERMISSION_MODE" in
  auto|dontAsk|bypassPermissions) exit 0 ;;
esac

# Extract command
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty' 2>/dev/null) || exit 0
[[ -z "$COMMAND" ]] && exit 0

# Read-only allowlist: these patterns are safe regardless of mode
SAFE_PATTERNS=(
  # aws: s3 ls, and service-level describe-*/list-*/get-* subcommands
  'aws\s+s3\s+ls(\s|$)'
  'aws\s+\S+\s+(describe|list|get)-'
  # kubectl: closed list of read-only verbs
  'kubectl\s+(get|describe|logs|top|explain|api-resources|api-versions|cluster-info|version|diff|events)(\s|$)'
  'kubectl\s+rollout\s+(history|status)(\s|$)'
  'kubectl\s+config\s+view(\s|$)'
  # helm: read-only commands
  'helm\s+(list|ls|get|show|status|history|search|lint|template|env|verify|version)(\s|$)'
  'helm\s+repo\s+(list|ls)(\s|$)'
  # gcloud: list/describe verbs, logging read, config get
  'gcloud\s+\S+\s+(list|describe)(\s|$)'
  'gcloud\s+logging\s+read(\s|$)'
  'gcloud\s+config\s+get(\s|$)'
  # terraform: definitively read-only commands
  'terraform\s+(validate|show|output|version|graph)(\s|$)'
  'terraform\s+state\s+(list|show|pull)(\s|$)'
  'terraform\s+fmt\s+.*--check'
)

for pattern in "${SAFE_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    exit 0
  fi
done

DANGEROUS_COMMANDS=(
  aws
  kubectl
  helm
  terraform
  gcloud
)

# Build regex pattern: \b(aws|kubectl|helm|...)\b
# Word boundaries avoid false positives (e.g., "awscli" won't match "aws")
PATTERN=$(IFS='|'; echo "\b(${DANGEROUS_COMMANDS[*]})\b")

if echo "$COMMAND" | grep -qE "$PATTERN"; then
  echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Command contains a potentially dangerous tool. Please review before approving."}}'
fi

exit 0
