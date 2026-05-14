#!/usr/bin/env bash
set -euo pipefail
[[ -z "${TMUX:-}" ]] && exit 0

EVENT="$1" WIN="$2" WIN_NAME="$3" MSG="$4" COLOR="$5"
DURATION="${AGENT_ALERT_DISPLAY_DURATION:-5000}"

tmux display-message -d "${DURATION}" "${MSG}: window ${WIN} (${WIN_NAME})" 2>/dev/null || true
