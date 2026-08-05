#!/usr/bin/env bash
# Daily 9800 WLC PR generator — sourced by cron at 8am

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$HOME/.9800_pr.log"

# Uses Cisco LiteLLM proxy — set in ~/.claude/settings.json env block
export ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-${ANTHROPIC_API_KEY:-}}"
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://cx-us-ps-litellm.cisco.com}"
export ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-claude-sonnet-4-6[1m]}"

if [[ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
    echo "$(date): ERROR — ANTHROPIC_AUTH_TOKEN not set" >> "$LOG_FILE"
    exit 1
fi

echo "$(date): Starting 9800 PR generator..." >> "$LOG_FILE"

/Library/Frameworks/Python.framework/Versions/3.14/bin/python3 \
    "$SCRIPT_DIR/9800_pr_generator.py" >> "$LOG_FILE" 2>&1

echo "$(date): Done." >> "$LOG_FILE"
