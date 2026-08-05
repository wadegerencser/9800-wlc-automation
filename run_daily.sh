#!/usr/bin/env bash
# Daily 9800 WLC PR generator
# Fires at 8am via cron. If VPN is not up, retries every 5 min for up to 8 hours.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$HOME/.9800_pr.log"
LOCK_FILE="/tmp/9800_pr_daily.lock"
RETRY_INTERVAL=300   # 5 minutes in seconds
MAX_ATTEMPTS=96      # 96 × 5 min = 8 hours max wait

# Prevent a second instance from stacking if the first is still waiting for VPN
if [[ -f "$LOCK_FILE" ]]; then
    echo "$(date): Already running (lock exists). Exiting." >> "$LOG_FILE"
    exit 0
fi
touch "$LOCK_FILE"
trap 'rm -f "$LOCK_FILE"' EXIT

# Uses Cisco LiteLLM proxy — keys come from ~/.claude/settings.json env block
export ANTHROPIC_AUTH_TOKEN="${ANTHROPIC_AUTH_TOKEN:-${ANTHROPIC_API_KEY:-}}"
export ANTHROPIC_BASE_URL="${ANTHROPIC_BASE_URL:-https://cx-us-ps-litellm.cisco.com}"
export ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-claude-sonnet-5}"

if [[ -z "${ANTHROPIC_AUTH_TOKEN:-}" ]]; then
    echo "$(date): ERROR — ANTHROPIC_AUTH_TOKEN not set" >> "$LOG_FILE"
    exit 1
fi

# VPN check: try to reach Cisco internal GitHub with a 3-second timeout
vpn_up() {
    curl -s --connect-timeout 3 --max-time 5 --head \
        "https://wwwin-github.cisco.com" > /dev/null 2>&1
}

# Wait for VPN — retry every 5 minutes up to 8 hours
attempt=0
until vpn_up; do
    attempt=$(( attempt + 1 ))
    if [[ $attempt -ge $MAX_ATTEMPTS ]]; then
        echo "$(date): ERROR — VPN not reachable after 8 hours. Giving up for today." >> "$LOG_FILE"
        exit 1
    fi
    echo "$(date): VPN not reachable — retry $attempt/$MAX_ATTEMPTS in ${RETRY_INTERVAL}s" >> "$LOG_FILE"
    sleep $RETRY_INTERVAL
done

echo "$(date): VPN up. Starting 9800 PR generator..." >> "$LOG_FILE"

/Library/Frameworks/Python.framework/Versions/3.14/bin/python3 \
    "$SCRIPT_DIR/9800_pr_generator.py" >> "$LOG_FILE" 2>&1

echo "$(date): Done." >> "$LOG_FILE"
