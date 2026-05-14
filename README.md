# agent-alert

Pluggable notifications for AI coding agents.  Know when your agent
finishes or needs input - in tmux, on your desktop, or anywhere else.

Works with **Claude Code** and **OpenCode**.  No hard dependencies beyond
`bash`, enable only the backends you need.

```
┌──────────────────┐   ┌──────────────────┐
│  Claude Code     │   │  OpenCode        │
│  hooks.json      │   │  plugin.ts       │
└────────┬─────────┘   └────────┬─────────┘
         │                      │
         ▼                      ▼
   ┌───────────────────-──────────────-─┐
   │  notify.sh  (agnostic core)        │
   │  parse → filter → color → dispatch |
   └──────────---────┬────--────────────┘
                     │
         ┌───────────┼───────────┐
         ▼           ▼           ▼
     backends.d/  backends.d/  backends.d/
     tmux-*.sh    bell.sh      your-own.sh
```

## Requirements

- `bash` >= 4.0
- `jq` (or `python3` as fallback)
- At least one of: `claude` CLI, `opencode` CLI
- Backend-specific: `tmux` >= 3.0 for tmux backends, `dunstify` for dunst, etc.

## Install

```bash
git clone https://github.com/fmount/agent-alert.git
cd agent-alert

make check             # verify dependencies
make install-claude    # Claude Code only
make install-opencode  # OpenCode only
make install           # auto-detect all
```

To remove:

```bash
make uninstall-claude
make uninstall-opencode
make uninstall          # remove everything
```

### Manual install

**Claude Code** -- add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": "bash /path/to/agent-alert/hooks/notify.sh stop"
      }
    ],
    "Notification": [
      {
        "matcher": "permission_prompt",
        "type": "command",
        "command": "bash /path/to/agent-alert/hooks/notify.sh notification"
      },
      {
        "matcher": "elicitation_dialog",
        "type": "command",
        "command": "bash /path/to/agent-alert/hooks/notify.sh notification"
      }
    ]
  }
}
```

**OpenCode** -- symlink the plugin:

```bash
# Global
ln -s /path/to/agent-alert/opencode/plugin.ts \
      ~/.config/opencode/plugins/agent-alert.ts

# Project-local
mkdir -p .opencode/plugins
ln -s /path/to/agent-alert/opencode/plugin.ts \
      .opencode/plugins/agent-alert.ts
```

## Usage

Notifications fire automatically once installed.  Add this to your
`.bashrc` / `.zshrc`:

```bash
# Pick which backends to run (default: all)
export AGENT_ALERT_MODE="dunst,tmux-window-color"
```

Events map to colors by default (customizable via `AGENT_ALERT_COLOR_*`,
see [docs/configuration.md](docs/configuration.md)):

| Event | Color | Meaning |
|---|---|---|
| `stop` | green | Agent finished work |
| `notification` | yellow | Agent needs user input |
| `error` | red | Agent encountered an error |

### /mute and /unmute

```bash
touch ~/.agent-alert-mute            # mute all
touch ~/.agent-alert-mute-window-3   # mute window 3 only
rm ~/.agent-alert-mute               # unmute
```

### Built-in backends

| Backend | What it does | Requires |
|---|---|---|
| `bell` | Sends terminal BEL (`\a`) | nothing |
| `dunst` | Desktop notification with semaphore colors | `dunstify` |
| `tmux-message` | Status bar pop-up for 5 seconds | `tmux` |
| `tmux-status` | Persistent pending-window badge | `tmux` |
| `tmux-window-color` | Colors the window tab green/yellow/red | `tmux` |

Select backends via `AGENT_ALERT_MODE`:

```bash
export AGENT_ALERT_MODE=all                          # all backends
export AGENT_ALERT_MODE=bell,tmux-window-color       # pick specific ones
export AGENT_ALERT_MODE=dunst                        # desktop only
```

Backends are pluggable -- drop a script in `hooks/backends.d/` to add
notify-send or anything else.

Full reference: **[docs/configuration.md](docs/configuration.md)**

## Filtering

- **Sub-agents** -- only the main agent triggers notifications.
- **Plan-mode exits** -- exiting plan mode in Claude Code does not notify.

## License

MIT
