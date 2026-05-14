#!/usr/bin/env bash
set -euo pipefail
command -v dunstify >/dev/null 2>&1 || exit 0

EVENT="$1" WIN="$2" WIN_NAME="$3" MSG="$4" COLOR="$5"
TIMEOUT="${AGENT_ALERT_DUNST_TIMEOUT:-10000}"

case "${EVENT}" in
  error)        urgency="critical" ;;
  notification) urgency="normal"   ;;
  *)            urgency="low"      ;;
esac

# dunst bgcolor requires hex — map color names to hex values
case "${COLOR}" in
  green)   HEX="#2ea043" ;;
  yellow)  HEX="#d4a017" ;;
  red)     HEX="#d73a49" ;;
  *)       HEX="#444444" ;;
esac

dunstify -u "${urgency}" -t "${TIMEOUT}" -h "string:fgcolor:#ffffff" -h "string:bgcolor:${HEX}" "Agent: ${WIN_NAME:-agent}" "${MSG}"
