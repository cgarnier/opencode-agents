#!/usr/bin/env bash
set -e

AGENTS_DIR="$HOME/dev/agents"
SOURCE_LINE="source \"\$HOME/dev/agents/shell-functions.sh\""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
skip() { echo -e "  ${YELLOW}~${NC} $1"; }
warn() { echo -e "  ${RED}!${NC} $1"; }
info() { echo -e "  ${CYAN}→${NC} $1"; }

echo ""
echo "OpenCode shell helpers install"
echo "──────────────────────────────────────────"

# ── Process each shell config ─────────────────────────────────────────────────

for rc_file in "$HOME/.bashrc" "$HOME/.zshrc"; do
  [ -f "$rc_file" ] || continue

  echo ""
  info "Processing $rc_file..."

  # Already installed?
  if grep -qF "shell-functions.sh" "$rc_file"; then
    skip "$(basename "$rc_file") — shell-functions.sh already sourced"
    continue
  fi

  # Remove old wt-new and wt-done alias lines
  tmp=$(mktemp)
  grep -v "alias wt-new=" "$rc_file" | grep -v "alias wt-done=" > "$tmp"
  mv "$tmp" "$rc_file"
  ok "Removed old wt-new / wt-done aliases"

  # Insert source line — after the worktree helpers comment if it exists,
  # otherwise append at end of file
  if grep -qF "# OpenCode worktree helpers" "$rc_file"; then
    # Insert the source line on the line immediately after the comment
    sed -i "/# OpenCode worktree helpers/a $SOURCE_LINE" "$rc_file"
    ok "Inserted source line after '# OpenCode worktree helpers'"
  else
    printf '\n# OpenCode worktree helpers\n%s\nalias wt-list='"'"'git worktree list'"'"'\n' \
      "$SOURCE_LINE" >> "$rc_file"
    ok "Appended worktree helpers block to $(basename "$rc_file")"
  fi
done

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo -e "  ${GREEN}Done.${NC} Reload your shell to activate:"
echo ""
echo "    source ~/.zshrc   # or source ~/.bashrc"
echo ""
