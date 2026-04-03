#!/usr/bin/env bash
# OpenCode worktree helper functions.
# Must be SOURCED (not executed) so that cd affects the current shell.
#
#   source "$HOME/dev/agents/shell-functions.sh"
#
# Provides: wt-new <branch>  —  create worktree + cd + launch opencode
#           wt-done          —  cleanup worktree + cd back to main repo

AGENTS_DIR="$HOME/dev/agents"

# Colors (safe to redefine — same values as the scripts)
_WT_GREEN='\033[0;32m'
_WT_CYAN='\033[0;36m'
_WT_NC='\033[0m'

# ── wt-new ────────────────────────────────────────────────────────────────────
#
# Usage: wt-new <branch-name>
#
# 1. Delegates all setup logic to wt-new.sh
# 2. cd into the new worktree  (only possible from a function, not a script)
# 3. Launches opencode (blocking — Ctrl-C to exit)
# 4. After opencode exits, the shell is still in the worktree (ready for wt-done)
#
wt-new() {
  local branch="${1:-}"

  # Early validation — mirror of wt-new.sh so we fail fast before calling it
  if [ -z "$branch" ]; then
    echo -e "\033[0;31mUsage:\033[0m wt-new <branch-name>"
    echo "  Example: wt-new feature/auth"
    return 1
  fi

  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "\033[0;31m!\033[0m Not inside a git repository."
    return 1
  fi

  # Compute the worktree path using the same logic as wt-new.sh
  local repo_root branch_slug worktree_path
  repo_root=$(git rev-parse --show-toplevel)
  branch_slug=$(echo "$branch" | sed 's|/|-|g; s|[^a-zA-Z0-9_-]|-|g')
  worktree_path="$(dirname "$repo_root")/$(basename "$repo_root")-${branch_slug}"

  # Run the setup script (everything except cd + opencode)
  bash "$AGENTS_DIR/wt-new.sh" "$@" || return 1

  # cd into the worktree — works because we are in a shell function
  cd "$worktree_path" || return 1

  echo -e "  ${_WT_CYAN}→${_WT_NC} Launching opencode... (Ctrl-C to exit, then run wt-done)"
  echo ""

  # Launch opencode — blocking (no exec), so the shell stays alive after Ctrl-C
  opencode "$worktree_path"

  echo ""
  echo -e "  ${_WT_GREEN}✓${_WT_NC} Back in worktree: ${_WT_CYAN}$(pwd)${_WT_NC}"
  echo "  Run wt-done when the branch is merged."
}

# ── wt-done ───────────────────────────────────────────────────────────────────
#
# Usage: wt-done  (run from inside a worktree)
#
# 1. Captures REPO_ROOT before the cleanup removes the worktree directory
# 2. Delegates all cleanup logic to wt-done.sh
# 3. cd back to the main repo  (only possible from a function, not a script)
#
wt-done() {
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo -e "\033[0;31m!\033[0m Not inside a git repository."
    return 1
  fi

  # Capture the main repo path BEFORE the worktree is removed
  local git_common repo_root
  git_common=$(git rev-parse --git-common-dir 2>/dev/null) || {
    echo -e "\033[0;31m!\033[0m Could not determine git common dir."
    return 1
  }
  repo_root=$(cd "$git_common/.." && pwd)

  # Run the cleanup script
  bash "$AGENTS_DIR/wt-done.sh" || return 1

  # cd back to the main repo — works because we are in a shell function
  cd "$repo_root" || return 1

  echo -e "  ${_WT_GREEN}✓${_WT_NC} Now in: ${_WT_CYAN}$(pwd)${_WT_NC}"
}
