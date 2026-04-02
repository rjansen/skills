# Sync Claude Code skills plugin to ~/.claude/
# Cross-platform: rsync on Unix, PowerShell+robocopy on Windows
#
# Usage:
#   make install  - copy only new/updated files
#   make mirror   - full sync (deletes extras at destination)

DIRS := commands agents skills

ifeq ($(OS),Windows_NT)
  CLAUDE_HOME := $(USERPROFILE)\.claude

install:
	@echo Installing skills to $(CLAUDE_HOME) ...
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/sync.ps1
	@echo Done.

mirror:
	@echo Mirroring skills to $(CLAUDE_HOME) ...
	powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/sync.ps1 -Mirror
	@echo Done.

select:
	@powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/select.ps1

else
  CLAUDE_HOME := $(HOME)/.claude

install:
	@echo Installing skills to $(CLAUDE_HOME) ...
	@for d in $(DIRS); do \
	  mkdir -p "$(CLAUDE_HOME)/$$d" && \
	  rsync -av "$$d/" "$(CLAUDE_HOME)/$$d/"; \
	done
	@echo Done.

mirror:
	@echo Mirroring skills to $(CLAUDE_HOME) ...
	@for d in $(DIRS); do \
	  mkdir -p "$(CLAUDE_HOME)/$$d" && \
	  rsync -av --delete "$$d/" "$(CLAUDE_HOME)/$$d/"; \
	done
	@echo Done.

select:
	@bash scripts/select.sh

endif

.PHONY: install mirror select
