#!/usr/bin/env bash
set -e

TEMPLATE_DIR="$HOME/dev/agents"
PROJECT_DIR="$(pwd)"
TARGET_DIR="$PROJECT_DIR/.opencode"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
skip() { echo -e "  ${YELLOW}~${NC} $1"; }
warn() { echo -e "  ${RED}!${NC} $1"; }

echo ""
echo "OpenCode multi-agent setup → $PROJECT_DIR"
echo "──────────────────────────────────────────"

# 1. Create .opencode/
mkdir -p "$TARGET_DIR"

# 2. Symlink agents/, rules/ and commands/
for dir in agents rules commands; do
  TARGET="$TARGET_DIR/$dir"
  SOURCE="$TEMPLATE_DIR/.opencode/$dir"

  if [ ! -d "$SOURCE" ]; then
    warn "$dir/ not found in template ($SOURCE) — skipping"
    continue
  fi

  if [ -L "$TARGET" ]; then
    skip ".opencode/$dir/ (symlink already exists)"
  elif [ -d "$TARGET" ]; then
    warn ".opencode/$dir/ exists as a real directory — skipping (delete it first to use symlink)"
  else
    ln -s "$SOURCE" "$TARGET"
    ok ".opencode/$dir/ → $SOURCE"
  fi
done

# 3. Copy opencode.json if absent
if [ ! -f "$PROJECT_DIR/opencode.json" ]; then
  cp "$TEMPLATE_DIR/opencode.json" "$PROJECT_DIR/opencode.json"
  ok "opencode.json copied (customize for this project)"
else
  skip "opencode.json already exists"
fi

# 4. Create AGENTS.md from template if absent
if [ ! -f "$PROJECT_DIR/AGENTS.md" ]; then
  cp "$TEMPLATE_DIR/AGENTS.md.template" "$PROJECT_DIR/AGENTS.md"
  ok "AGENTS.md created from template"
  echo ""
  echo -e "  ${YELLOW}→ Fill in AGENTS.md with your project's quality check commands.${NC}"
else
  skip "AGENTS.md already exists"
fi

echo ""
echo "Done. Run 'opencode' to start."
echo ""
