#!/usr/bin/env bash
set -e

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

BRANCH="${1:-}"

# ── Validation ────────────────────────────────────────────────────────────────

if [ -z "$BRANCH" ]; then
  echo -e "${RED}Usage:${NC} wt-new <branch-name>"
  echo -e "  Example: wt-new feature/auth"
  echo -e "  Example: wt-new fix/login-bug"
  exit 1
fi

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  warn "Not inside a git repository."
  exit 1
fi

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  warn "Cannot create a worktree for '${BRANCH}' — pick a feature or fix branch name."
  exit 1
fi

# ── Compute paths ─────────────────────────────────────────────────────────────

REPO_ROOT=$(git rev-parse --show-toplevel)
REPO_NAME=$(basename "$REPO_ROOT")
BRANCH_SLUG=$(echo "$BRANCH" | sed 's|/|-|g; s|[^a-zA-Z0-9_-]|-|g')
WORKTREE_PATH="$(dirname "$REPO_ROOT")/${REPO_NAME}-${BRANCH_SLUG}"

echo ""
echo "Creating worktree for branch: ${CYAN}${BRANCH}${NC}"
echo "Path: ${CYAN}${WORKTREE_PATH}${NC}"
echo "──────────────────────────────────────────"

# ── Check worktree path doesn't already exist ─────────────────────────────────

if [ -d "$WORKTREE_PATH" ]; then
  warn "Directory already exists: $WORKTREE_PATH"
  warn "Remove it first or pick a different branch name."
  exit 1
fi

# ── Ensure branch exists or create from updated main ─────────────────────────

MAIN_BRANCH="main"
# detect main vs master
if ! git show-ref --verify --quiet refs/heads/main; then
  MAIN_BRANCH="master"
fi

BRANCH_EXISTS=$(git show-ref --verify --quiet "refs/heads/${BRANCH}" && echo yes || echo no)

if [ "$BRANCH_EXISTS" = "yes" ]; then
  skip "Branch '${BRANCH}' already exists — using it as-is"
else
  info "Fetching origin..."
  git fetch origin --quiet
  info "Creating branch '${BRANCH}' from ${MAIN_BRANCH}..."
  git branch "${BRANCH}" "origin/${MAIN_BRANCH}" 2>/dev/null \
    || git branch "${BRANCH}" "${MAIN_BRANCH}"
  ok "Branch '${BRANCH}' created from ${MAIN_BRANCH}"
fi

# ── Create the worktree ────────────────────────────────────────────────────────

git worktree add "$WORKTREE_PATH" "$BRANCH" --quiet
ok "Worktree created at $WORKTREE_PATH"

# ── Symlink .env* files from main repo ────────────────────────────────────────

while IFS= read -r -d '' envfile; do
  filename=$(basename "$envfile")
  target="$WORKTREE_PATH/$filename"
  if [ -e "$target" ] || [ -L "$target" ]; then
    skip "$filename (already exists)"
  else
    ln -s "$envfile" "$target"
    ok "Symlinked $filename → $envfile"
  fi
done < <(find "$REPO_ROOT" -maxdepth 1 -name '.env*' -not -name '.env.example' -print0)

# ── Run agents-setup in the worktree ──────────────────────────────────────────

SETUP_SCRIPT="$HOME/dev/agents/setup.sh"

if [ -f "$SETUP_SCRIPT" ]; then
  echo ""
  (cd "$WORKTREE_PATH" && bash "$SETUP_SCRIPT")
else
  warn "setup.sh not found at $SETUP_SCRIPT — skipping agents setup"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo -e "  ${GREEN}Worktree ready.${NC}"
echo -e "  When done, run ${YELLOW}wt-done${NC} from inside the worktree to clean up."
echo ""
info "Launching opencode in ${WORKTREE_PATH}..."
exec opencode "$WORKTREE_PATH"
