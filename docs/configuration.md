# Configuration

All configuration is done via environment variables.  Set them in
`.bashrc`, `.zshrc`, `.tmux.conf`, or export them per session.

## Core settings

These are read by `notify.sh` (the agnostic dispatcher):

| Variable | Default | Description |
|---|---|---|
| `AGENT_ALERT_MODE` | `all` | Comma-separated list of backends to enable: `bell`, `tmux-message`, `tmux-status`, `tmux-window-color`, or `all`. |
| `AGENT_ALERT_MSG_STOP` | `Agent done` | Message template for stop events. `{win}` and `{name}` are replaced at runtime. |
| `AGENT_ALERT_MSG_NOTIFY` | `Agent needs input` | Message template for notification events. |
| `AGENT_ALERT_MSG_ERROR` | `Agent error` | Message template for error events. |
| `AGENT_ALERT_COLOR_STOP` | `green` | Color for stop events (passed to backends as `$5`). |
| `AGENT_ALERT_COLOR_NOTIFY` | `yellow` | Color for notification events. |
| `AGENT_ALERT_COLOR_ERROR` | `red` | Color for error events. |

**Note on color overrides**: custom colors are fully supported by
`tmux-window-color` (any tmux color name, `colour0`-`colour255`, or
`#rrggbb` hex).  The `dunst` backend maps the default color names
(green/yellow/red) to hex values internally; custom color names are not
supported and will fall back to grey.
| `AGENT_ALERT_MUTE_FILE` | `~/.agent-alert-mute` | Path to the global mute sentinel file. |
| `AGENT_ALERT_LOG` | `/tmp/agent-alert-$USER.log` | Log file path.  Set to `/dev/null` to disable. |

Example:

```bash
export AGENT_ALERT_MODE="bell,tmux-window-color"
export AGENT_ALERT_COLOR_STOP=green
export AGENT_ALERT_COLOR_NOTIFY=yellow
export AGENT_ALERT_COLOR_ERROR=red
export AGENT_ALERT_LOG=/dev/null
```

## Per-backend settings

Each backend can read its own env vars using the convention
`AGENT_ALERT_<BACKEND>_<SETTING>`, where `<BACKEND>` is the backend name
in uppercase with dashes replaced by underscores.

### bell

No configuration.  Sends terminal BEL (`\a`).

### tmux-message

| Variable | Default | Description |
|---|---|---|
| `AGENT_ALERT_DISPLAY_DURATION` | `5000` | Duration in milliseconds for the status bar pop-up. |

### tmux-status

Writes window indices to `/tmp/agent-alert-pending-$USER`.  Add this to
your `.tmux.conf` to display a badge:

```tmux
set -g status-right '#{?#{!=:#(cat /tmp/agent-alert-pending-#{user}),}, READY:#(cat /tmp/agent-alert-pending-#{user}),} %H:%M'
```

### tmux-window-color

Sets the per-window `@alert_color` tmux user option to the event color.
Requires the following in `.tmux.conf`:

```tmux
# Color agent windows by event severity
set -g window-status-format \
  '#{?#{@alert_color},#[bg=#{@alert_color}]#[fg=black],}#I:#W#{?#{@alert_color},#[default],}'
set -g window-status-current-format \
  '#{?#{@alert_color},#[bg=#{@alert_color}]#[fg=black],}#I:#W#{?#{@alert_color},#[default],}'

# Clear color when you switch to the window
set-hook -g after-select-window 'set-option -w @alert_color ""'
```

Then reload: `tmux source-file ~/.tmux.conf`

**How it works**: the backend sets `@alert_color` on the target window.
The `window-status-format` conditional renders a colored background.  The
`after-select-window` hook clears it when you visit the window, so the
color acts as an unread indicator.

## Built-in backends summary

| Backend | Requires | Env vars | Description |
|---|---|---|---|
| `bell` | nothing | (none) | Terminal BEL |
| `tmux-message` | `tmux` | `AGENT_ALERT_DISPLAY_DURATION` | Status bar pop-up |
| `tmux-status` | `tmux` | (none) | Pending-window badge |
| `tmux-window-color` | `tmux` | (none) | Colored window tab |

All tmux backends check `$TMUX` at startup and exit silently if not
inside a tmux session.  This makes them safe to enable globally.

## Custom backends

To add your own notification backend, place an executable script in
`hooks/backends.d/`.  It receives 5 positional arguments:

| Arg | Description |
|---|---|
| `$1` EVENT | `stop`, `notification`, or `error` |
| `$2` WIN | Window index (e.g. `3`), empty if not in tmux |
| `$3` WIN_NAME | Window name (e.g. `claude`), empty if not in tmux |
| `$4` MSG | Fully resolved message string |
| `$5` COLOR | `green`, `yellow`, or `red` |

The script also inherits `TMUX`, `TMUX_PANE`, and all `AGENT_ALERT_*`
environment variables from the parent process.  Define backend-specific
vars using the `AGENT_ALERT_<BACKEND>_*` convention.

Exit non-zero to signal failure -- it will be logged but will not abort
other backends.

### Example: dunst

`hooks/backends.d/dunst.sh`:

```bash
#!/usr/bin/env bash
EVENT="$1" WIN="$2" WIN_NAME="$3" MSG="$4" COLOR="$5"
TIMEOUT="${AGENT_ALERT_DUNST_TIMEOUT:-10000}"
urgency="normal"
[[ "$EVENT" == "error" ]] && urgency="critical"
dunstify -u "$urgency" -t "$TIMEOUT" "Agent: window $WIN" "$MSG"
```

Configure with: `export AGENT_ALERT_DUNST_TIMEOUT=5000`

### Example: notify-send

`hooks/backends.d/notify-send.sh`:

```bash
#!/usr/bin/env bash
EVENT="$1" WIN="$2" WIN_NAME="$3" MSG="$4" COLOR="$5"
icon="dialog-information"
[[ "$EVENT" == "error" ]] && icon="dialog-error"
[[ "$EVENT" == "notification" ]] && icon="dialog-warning"
notify-send -i "$icon" "Agent: window $WIN" "$MSG"
```

### Enabling custom backends

Drop the script in `hooks/backends.d/`, make it executable, and include
the backend name in `AGENT_ALERT_MODE`:

```bash
chmod +x hooks/backends.d/dunst.sh
export AGENT_ALERT_MODE=all  # or: bell,tmux-window-color,dunst
```

When `AGENT_ALERT_MODE=all`, every executable `*.sh` in `backends.d/` runs.
