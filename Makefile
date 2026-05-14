PLUGIN_NAME := agent-alert
INSTALL_DIR := $(HOME)/.local/share/$(PLUGIN_NAME)

CLAUDE_PLUGIN_DIR := $(HOME)/.claude/plugins/$(PLUGIN_NAME)
OPENCODE_PLUGIN_DIR := $(HOME)/.config/opencode/plugins

.PHONY: help install install-claude install-opencode uninstall uninstall-claude uninstall-opencode check

help:
	@echo "agent-alert"
	@echo ""
	@echo "  make install-claude    Install as a Claude Code plugin"
	@echo "  make install-opencode  Install as an OpenCode plugin"
	@echo "  make install           Install for all detected platforms"
	@echo "  make uninstall-claude  Remove Claude Code plugin"
	@echo "  make uninstall-opencode Remove OpenCode plugin"
	@echo "  make uninstall         Remove from all platforms"
	@echo "  make check             Verify runtime dependencies"

check:
	@echo "Checking dependencies..."
	@command -v tmux >/dev/null 2>&1 && echo "  tmux: $$(tmux -V)" || echo "  tmux: not found (needed for tmux-* backends)"
	@command -v bash >/dev/null 2>&1 && echo "  bash: $$(bash --version | head -1)" || echo "  bash: MISSING (required)"
	@command -v jq >/dev/null 2>&1 && echo "  jq:   $$(jq --version)" || { \
		command -v python3 >/dev/null 2>&1 && echo "  jq:   missing (python3 fallback available)" || \
		echo "  jq:   MISSING (install jq or python3)"; \
	}
	@command -v claude >/dev/null 2>&1 && echo "  claude: available" || echo "  claude: not found"
	@command -v opencode >/dev/null 2>&1 && echo "  opencode: available" || echo "  opencode: not found"

install-claude: check
	@echo "Installing Claude Code plugin..."
	@mkdir -p $(INSTALL_DIR)
	@cp -r .claude-plugin hooks commands LICENSE README.md $(INSTALL_DIR)/
	@chmod +x $(INSTALL_DIR)/hooks/notify.sh $(INSTALL_DIR)/hooks/backends.d/*.sh
	@mkdir -p $(dir $(CLAUDE_PLUGIN_DIR))
	@ln -snf $(INSTALL_DIR) $(CLAUDE_PLUGIN_DIR)
	@echo "Installed to $(INSTALL_DIR)"
	@echo "Symlinked $(CLAUDE_PLUGIN_DIR) -> $(INSTALL_DIR)"
	@echo ""
	@echo "Done. Restart Claude Code to activate."

install-opencode: check
	@echo "Installing OpenCode plugin..."
	@mkdir -p $(INSTALL_DIR)
	@cp -r hooks opencode LICENSE README.md $(INSTALL_DIR)/
	@chmod +x $(INSTALL_DIR)/hooks/notify.sh $(INSTALL_DIR)/hooks/backends.d/*.sh
	@mkdir -p $(OPENCODE_PLUGIN_DIR)
	@ln -snf $(INSTALL_DIR)/opencode/plugin.ts $(OPENCODE_PLUGIN_DIR)/$(PLUGIN_NAME).ts
	@echo "Installed to $(INSTALL_DIR)"
	@echo "Symlinked $(OPENCODE_PLUGIN_DIR)/$(PLUGIN_NAME).ts -> $(INSTALL_DIR)/opencode/plugin.ts"
	@echo ""
	@echo "Done. Restart OpenCode to activate."

install:
	@HAS_CLAUDE=0; HAS_OPENCODE=0; \
	command -v claude >/dev/null 2>&1 && HAS_CLAUDE=1; \
	command -v opencode >/dev/null 2>&1 && HAS_OPENCODE=1; \
	if [ "$$HAS_CLAUDE" -eq 0 ] && [ "$$HAS_OPENCODE" -eq 0 ]; then \
		echo "Neither claude nor opencode found. Install at least one first."; \
		exit 1; \
	fi; \
	[ "$$HAS_CLAUDE" -eq 1 ] && $(MAKE) install-claude; \
	[ "$$HAS_OPENCODE" -eq 1 ] && $(MAKE) install-opencode; \
	echo ""; \
	echo "All detected platforms installed."

uninstall-claude:
	@echo "Removing Claude Code plugin..."
	@rm -f $(CLAUDE_PLUGIN_DIR)
	@echo "Removed symlink $(CLAUDE_PLUGIN_DIR)"

uninstall-opencode:
	@echo "Removing OpenCode plugin..."
	@rm -f $(OPENCODE_PLUGIN_DIR)/$(PLUGIN_NAME).ts
	@echo "Removed symlink $(OPENCODE_PLUGIN_DIR)/$(PLUGIN_NAME).ts"

uninstall: uninstall-claude uninstall-opencode
	@rm -rf $(INSTALL_DIR)
	@echo "Removed $(INSTALL_DIR)"
	@echo "Uninstall complete."
