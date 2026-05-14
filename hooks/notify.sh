#!/usr/bin/env bash
set -euo pipefail

EVENT="${1:?usage: notify.sh <stop|notification|error>}"
shift

SUBAGENT=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --subagent) SUBAGENT=true ;;
  esac
  shift
done

# Claude Code pipes a JSON payload to stdin when a hook fires (contains
# agent_id, transcript_path, etc.).  OpenCode does not — it passes flags
# via CLI args instead.  We slurp stdin here because it's a stream and
# can only be read once; fields are extracted from the variable later.
HOOK_JSON=""
if ! [ -t 0 ]; then
  HOOK_JSON=$(cat)
fi

# --- Early exits ---

# Resolve session context.  Inside tmux we use the window index/name.
# Outside tmux we fall back to the Claude Code session_id (truncated to
# 8 chars) so backends like dunst still have something meaningful to show.
WIN=""
WIN_NAME=""
if [[ -n "${TMUX:-}" ]]; then
  WIN=$(tmux display-message -t "${TMUX_PANE}" -p '#{window_index}' 2>/dev/null || echo "")
  WIN_NAME=$(tmux display-message -t "${TMUX_PANE}" -p '#{window_name}' 2>/dev/null || echo "")
fi
if [[ -z "${WIN}" && -n "${HOOK_JSON}" ]]; then
  SESSION_ID=""
  if command -v jq >/dev/null 2>&1; then
    SESSION_ID=$(echo "${HOOK_JSON}" | jq -r '.session_id // empty' 2>/dev/null || true)
  elif command -v python3 >/dev/null 2>&1; then
    SESSION_ID=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(d.get('session_id', ''))
" "${HOOK_JSON}" 2>/dev/null || true)
  fi
  if [[ -n "${SESSION_ID}" ]]; then
    WIN="${SESSION_ID:0:8}"
    WIN_NAME="session"
  fi
fi

# Global mute
MUTE_FILE="${AGENT_ALERT_MUTE_FILE:-${HOME}/.agent-alert-mute}"
[[ -f "${MUTE_FILE}" ]] && exit 0

# Per-window mute (only meaningful inside tmux)
[[ -n "${WIN}" && -f "${MUTE_FILE}-window-${WIN}" ]] && exit 0

# Sub-agent filtering (CLI flag from OpenCode adapter)
[[ "${SUBAGENT}" == "true" ]] && exit 0

# Sub-agent filtering (stdin JSON from Claude Code)
if [[ -n "${HOOK_JSON}" ]]; then
  AGENT_ID=""
  if command -v jq >/dev/null 2>&1; then
    AGENT_ID=$(echo "${HOOK_JSON}" | jq -r '.agent_id // empty' 2>/dev/null || true)
  elif command -v python3 >/dev/null 2>&1; then
    AGENT_ID=$(python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print(d.get('agent_id', ''))
" "${HOOK_JSON}" 2>/dev/null || true)
  fi
  [[ -n "${AGENT_ID}" ]] && exit 0

  # Plan-mode exit filtering (Claude Code only)
  if [[ "${EVENT}" == "stop" ]]; then
    TRANSCRIPT=""
    if command -v jq >/dev/null 2>&1; then
      TRANSCRIPT=$(echo "${HOOK_JSON}" | jq -r '.transcript_path // empty' 2>/dev/null || true)
    elif command -v python3 >/dev/null 2>&1; then
      TRANSCRIPT=$(python3 -c "
import json, sys, os
d = json.loads(sys.argv[1])
print(os.path.expanduser(d.get('transcript_path', '')))
" "${HOOK_JSON}" 2>/dev/null || true)
    fi
    if [[ -n "${TRANSCRIPT}" && -f "${TRANSCRIPT}" ]]; then
      if tail -n 5 "${TRANSCRIPT}" 2>/dev/null | grep -q 'ExitPlanMode'; then
        exit 0
      fi
    fi
  fi
fi

# --- Build message ---

MODE="${AGENT_ALERT_MODE:-all}"

case "${EVENT}" in
  stop)         MSG_TEMPLATE="${AGENT_ALERT_MSG_STOP:-Agent done}" ;;
  notification) MSG_TEMPLATE="${AGENT_ALERT_MSG_NOTIFY:-Agent needs input}" ;;
  error)        MSG_TEMPLATE="${AGENT_ALERT_MSG_ERROR:-Agent error}" ;;
  *)            MSG_TEMPLATE="Agent [${EVENT}]" ;;
esac

MSG="${MSG_TEMPLATE}"
MSG="${MSG//\{win\}/${WIN}}"
MSG="${MSG//\{name\}/${WIN_NAME}}"

# --- Resolve color ---

case "${EVENT}" in
  stop)         COLOR="${AGENT_ALERT_COLOR_STOP:-green}"  ;;
  notification) COLOR="${AGENT_ALERT_COLOR_NOTIFY:-yellow}" ;;
  error)        COLOR="${AGENT_ALERT_COLOR_ERROR:-red}"    ;;
  *)            COLOR="default" ;;
esac

# --- Dispatch to backends ---

BACKENDS_DIR="$(cd "$(dirname "$0")" && pwd)/backends.d"

if [[ "${MODE}" == "all" ]]; then
  BACKENDS=()
  for f in "${BACKENDS_DIR}"/*.sh; do
    [[ -x "$f" ]] || continue
    BACKENDS+=("$(basename "$f" .sh)")
  done
else
  IFS=',' read -ra BACKENDS <<< "${MODE}"
fi

for backend_name in "${BACKENDS[@]}"; do
  backend_file="${BACKENDS_DIR}/${backend_name}.sh"
  if [[ -x "${backend_file}" ]]; then
    "${backend_file}" "${EVENT}" "${WIN}" "${WIN_NAME}" "${MSG}" "${COLOR}" 2>/dev/null || true
  fi
done

# --- Log ---

LOG_FILE="${AGENT_ALERT_LOG:-/tmp/agent-alert-${USER:-$(id -un)}.log}"
if [[ "${LOG_FILE}" != "/dev/null" ]]; then
  echo "$(date -Iseconds) ${EVENT} window=${WIN} name=${WIN_NAME}" >> "${LOG_FILE}"
fi
