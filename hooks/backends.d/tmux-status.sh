#!/usr/bin/env bash
set -euo pipefail
[[ -z "${TMUX:-}" ]] && exit 0

EVENT="$1" WIN="$2" WIN_NAME="$3" MSG="$4" COLOR="$5"
PENDING_FILE="/tmp/agent-alert-pending-${USER:-$(id -un)}"

if [[ -f "${PENDING_FILE}" ]]; then
  if ! grep -q "^${WIN}$" "${PENDING_FILE}" 2>/dev/null; then
    echo "${WIN}" >> "${PENDING_FILE}"
  fi
else
  echo "${WIN}" > "${PENDING_FILE}"
fi
