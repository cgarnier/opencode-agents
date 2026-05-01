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
for dir in agents rules commands skills; do
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

# 3. Copy opencode.json if absent — detect the stack, then merge the shared
#    _agents.json fragment (model overrides) into the stack template via jq.
if [ ! -f "$PROJECT_DIR/opencode.json" ]; then
  if ! command -v jq >/dev/null 2>&1; then
    warn "jq is required to merge agent model overrides into opencode.json"
    warn "Install jq and re-run setup.sh:"
    warn "  Arch/Omarchy:  sudo pacman -S jq"
    warn "  Ubuntu/Debian: sudo apt install jq"
    warn "  macOS:         brew install jq"
    exit 1
  fi

  STACK="generic"
  if [ -f "$PROJECT_DIR/package.json" ]; then
    STACK="node"
  elif [ -f "$PROJECT_DIR/pyproject.toml" ] || [ -f "$PROJECT_DIR/setup.py" ] || [ -f "$PROJECT_DIR/requirements.txt" ]; then
    STACK="python"
  elif [ -f "$PROJECT_DIR/go.mod" ]; then
    STACK="go"
  fi

  TEMPLATE_FILE="$TEMPLATE_DIR/opencode.json.templates/${STACK}.json"
  AGENTS_FRAGMENT="$TEMPLATE_DIR/opencode.json.templates/_agents.json"

  # Fall back to legacy template if the per-stack version is missing
  [ -f "$TEMPLATE_FILE" ] || TEMPLATE_FILE="$TEMPLATE_DIR/opencode.json"

  if [ ! -f "$AGENTS_FRAGMENT" ]; then
    warn "Shared agents fragment not found: $AGENTS_FRAGMENT"
    cp "$TEMPLATE_FILE" "$PROJECT_DIR/opencode.json"
    ok "opencode.json copied (stack: ${STACK}) — no model overrides applied"
  else
    # Deep merge stack template with agents fragment (fragment wins on conflicts)
    jq -s '.[0] * .[1]' "$TEMPLATE_FILE" "$AGENTS_FRAGMENT" > "$PROJECT_DIR/opencode.json"
    ok "opencode.json generated (stack: ${STACK} + shared agents overrides)"
  fi
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
