#!/usr/bin/env bash
set -euo pipefail
[[ -z "${TMUX:-}" ]] && exit 0

EVENT="$1" WIN="$2" WIN_NAME="$3" MSG="$4" COLOR="$5"

tmux set-option -w -t ":${WIN}" @alert_color "${COLOR}" 2>/dev/null || true
