#!/usr/bin/env bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${RED}!${NC} $1"; }
info() { echo -e "  ${CYAN}→${NC} $1"; }

# ── Validation ────────────────────────────────────────────────────────────────

if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  warn "Not inside a git repository."
  exit 1
fi

BRANCH=$(git branch --show-current)
WORKTREE_PATH=$(git rev-parse --show-toplevel)
# Git common dir points to the main repo's .git
GIT_COMMON=$(git rev-parse --git-common-dir)
REPO_ROOT=$(dirname "$GIT_COMMON")

# Safety: refuse to run from the main worktree
if [ "$WORKTREE_PATH" = "$REPO_ROOT" ]; then
  warn "You are in the main repository, not a worktree."
  warn "Run wt-done from inside a worktree directory."
  exit 1
fi

if [ -z "$BRANCH" ]; then
  warn "Detached HEAD state — cannot determine branch."
  exit 1
fi

if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  warn "Cannot remove a worktree on '${BRANCH}'."
  exit 1
fi

echo ""
echo "Cleaning up worktree for branch: ${CYAN}${BRANCH}${NC}"
echo "Path: ${CYAN}${WORKTREE_PATH}${NC}"
echo "──────────────────────────────────────────"

# ── Check for uncommitted changes ─────────────────────────────────────────────

if ! git diff --quiet || ! git diff --cached --quiet; then
  warn "You have uncommitted changes on branch '${BRANCH}'."
  echo ""
  git status --short
  echo ""
  read -r -p "  Continue and discard them? [y/N] " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "  Aborted."
    exit 1
  fi
fi

# ── Check if branch is merged ─────────────────────────────────────────────────

MAIN_BRANCH="main"
if ! git -C "$REPO_ROOT" show-ref --verify --quiet refs/heads/main; then
  MAIN_BRANCH="master"
fi

# Fetch to get up-to-date remote state
info "Fetching origin..."
git -C "$REPO_ROOT" fetch origin --quiet

IS_MERGED=$(git -C "$REPO_ROOT" branch -r --merged "origin/${MAIN_BRANCH}" 2>/dev/null \
  | grep -c "origin/${BRANCH}" || true)

if [ "$IS_MERGED" -eq 0 ]; then
  warn "Branch '${BRANCH}' has NOT been merged into origin/${MAIN_BRANCH}."
  echo ""
  read -r -p "  Remove worktree and delete branch anyway? [y/N] " confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "  Aborted."
    exit 1
  fi
  FORCE_DELETE=true
else
  ok "Branch '${BRANCH}' is merged into origin/${MAIN_BRANCH}"
  FORCE_DELETE=false
fi

# ── Remove worktree and branch ────────────────────────────────────────────────

cd "$REPO_ROOT"

git worktree remove "$WORKTREE_PATH" --force
ok "Worktree removed: $WORKTREE_PATH"

if [ "$FORCE_DELETE" = true ]; then
  git branch -D "$BRANCH" 2>/dev/null && ok "Branch '${BRANCH}' force-deleted" \
    || warn "Could not delete branch '${BRANCH}' — it may already be gone"
else
  git branch -d "$BRANCH" 2>/dev/null && ok "Branch '${BRANCH}' deleted" \
    || warn "Could not delete branch '${BRANCH}' — delete manually with: git branch -d ${BRANCH}"
fi

git worktree prune
ok "Worktree list pruned"

echo ""
echo -e "  ${GREEN}Done.${NC}"
echo ""
