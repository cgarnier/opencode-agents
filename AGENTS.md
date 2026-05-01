# agents — OpenCode Multi-Agent System Template

## Purpose

This repo is an OpenCode agent framework — a collection of agents, skills, commands,
and rules that power OpenCode sessions, both here and in target projects via symlinks.

When asked to create or modify any OpenCode artifact (agent, skill, command, rule),
the target location is always `./.opencode/` in this repo:

| Artifact | Path |
|---|---|
| Agent | `.opencode/agents/<name>.md` |
| Skill | `.opencode/skills/<name>/` |
| Command | `.opencode/commands/<name>.md` |
| Rule | `.opencode/rules/<name>.md` |

## Stack

Bash + Markdown + OpenCode agent system (`@opencode-ai/plugin` v1.3.5, managed with Bun).
No application framework, no TypeScript, no build pipeline.

## Structure

```
.
├── setup.sh                  — Install agents into a target project (run from that project's root)
├── wt-new.sh                 — Create a git worktree + branch, symlink .env*, run setup, launch opencode
├── wt-done.sh                — Tear down a worktree: remove dir, delete branch, prune list
├── shell-functions.sh        — Defines the wt-new and wt-done shell functions (must be sourced)
├── install-shell-helpers.sh  — One-time installer: injects source shell-functions.sh into .bashrc/.zshrc
├── opencode.json             — Active config for this repo + fallback template for setup.sh
├── opencode.json.templates/  — Per-stack templates merged into target projects by setup.sh
│   ├── _agents.json          — Shared fragment: small_model + agent model/temperature overrides
│   ├── generic.json          — Base permissions (build: bash *:allow, plan: deny)
│   ├── node.json             — Identical to generic (kept for future stack-specific needs)
│   ├── python.json           — Identical to generic (kept for future stack-specific needs)
│   └── go.json               — Identical to generic (kept for future stack-specific needs)
├── AGENTS.md.template        — Starter AGENTS.md copied into target projects by setup.sh
└── .opencode/
    ├── package.json      — Single dep: @opencode-ai/plugin
    ├── agents/           — Subagent definitions (symlinked into every target project)
    │   ├── orchestrator.md
    │   ├── reviewer.md
    │   ├── debugger.md
    │   ├── tester.md
    │   ├── refactorer.md
    │   ├── docs-writer.md
    │   ├── performance.md
    │   ├── security.md
    │   └── git-publisher.md
    ├── skills/           — Reusable skill bundles (symlinked into every target project)
    │   ├── gh/
    │   ├── glab/
    │   └── jira/
    ├── commands/         — Slash commands (symlinked into every target project)
    │   ├── ticket.md
    │   ├── new-ticket.md
    │   └── check-agents.md
    └── rules/            — Always-on instructions (symlinked into every target project)
        ├── git-safety.md
        └── code-quality.md
```

## Commands

```bash
# Install agent system into a target project (run from the target project root)
# Requires `jq` to merge the shared agents fragment into the stack template
bash ~/dev/agents/setup.sh

# Create a new worktree + feature branch, then open opencode
wt-new feature/my-feature

# Clean up a worktree once the branch is merged
wt-done                       # run from inside the worktree

# Install the OpenCode plugin dependency
cd .opencode && bun install
```

## Quality Checks

These apply to this repo's own shell scripts. Run after any `.sh` file change.

- syntax: bash -n setup.sh && bash -n wt-new.sh && bash -n wt-done.sh && bash -n install-shell-helpers.sh && bash -n shell-functions.sh
- lint: shellcheck setup.sh wt-new.sh wt-done.sh install-shell-helpers.sh shell-functions.sh

No test, typecheck, format, or build steps exist for this repo (shell + markdown only).

## Conventions

### Shell Scripts

- **Shebang + strict mode**: every script starts with `#!/usr/bin/env bash` then `set -e`
- **Color helpers** defined at the top, used consistently throughout:
  ```bash
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
  ok()   { echo -e "  ${GREEN}✓${NC} $1"; }   # success
  skip() { echo -e "  ${YELLOW}~${NC} $1"; }  # already done / skipped
  warn() { echo -e "  ${RED}!${NC} $1"; }     # error / warning
  info() { echo -e "  ${CYAN}→${NC} $1"; }    # informational step
  ```
- **Guard clauses first**: validate arguments, assert git context, check for protected branches — before doing any work
- **Constants**: `SCREAMING_SNAKE_CASE` (e.g. `REPO_ROOT`, `BRANCH_SLUG`, `WORKTREE_PATH`)
- **Locals / loop vars**: lowercase (e.g. `dir`, `envfile`, `filename`)
- **Subshell syntax**: always `$(...)`, never backticks
- **No silent failures**: operations that can fail either use `set -e` to abort or explicitly handle the return code
- **Interactive prompts**: use `read -r -p` with a `[y/N]` default — default is always No

### Agent Definitions (`.opencode/agents/*.md`)

Each agent file is a markdown document with a required YAML frontmatter block:

```yaml
---
description: <one-line description used for routing by the orchestrator>
mode: primary        # "primary" = Tab-accessible in TUI; omit for subagents
color: "#hex"        # display color in the TUI
permission:
  bash:
    "*": ask         # base rule: ask, allow, or deny
    "git diff*": allow
  edit: deny         # omit if the agent should be able to edit files
  task:
    "*": allow       # only orchestrator gets this
---
```

Permission model rules:
- **Primary agents** (`build`, `orchestrator`): `bash: "*": allow` — zero prompts at the top level. Safety is delegated to (1) the read-only frontmatters of subagents, (2) the `plan` agent for inspection-only sessions, and (3) `.opencode/rules/git-safety.md` which forbids direct work on `main`. Orchestrator also has `task: "*": allow` so it can invoke every subagent.
- **Plan agent**: `edit: deny`, `bash: deny` — the only fully locked primary, for when you want a read-only brainstorm session.
- **Read-only subagents** (`reviewer`, `debugger`, `performance`, `security`): `edit: deny`, bash limited to an explicit allow list; catch-all is `deny`. These restrictions live in the agent's frontmatter and cannot be overridden by the project's `opencode.json`.
- **Write subagents** (`tester`, `refactorer`): no `edit: deny`, `bash: "*": allow` so any stack's tooling works without prompts.
- **Docs writer**: `edit: allow` but `bash: "*": deny` with a read-only allow list — no build/test execution, only file inspection and `mkdir`/`touch`.
- **Security agent**: most restricted — `edit: deny`, bash limited to `grep *`, `ls*`, `cat *`, `find *` only.

Agent body is plain markdown using `##` sections. Structure:
1. One-sentence role statement
2. `## Workflow` or `## Review Dimensions` — step-by-step numbered procedure
3. `## Output Format` — specify the exact response shape (if the agent produces a report)
4. `## Principles` — short bullet list of non-negotiable constraints

### Rules Files (`.opencode/rules/*.md`)

```yaml
---
alwaysApply: true   # injected into every session automatically
---
```

- One concern per file — keep rules focused and scannable
- Use `##` sections, decision trees and tables for precision
- Written in the imperative ("Never commit to main", "Always run format first")
- These files are symlinked and shared across all projects — keep them project-agnostic

### Commit Messages

Conventional commits, always:

```
feat:     new agent, new script, new capability
fix:      bug in a script or agent logic
refactor: restructure without behavior change
docs:     README, AGENTS.md, comments only
chore:    dependency update, gitignore, config
```

### Branch Naming

| Type | Prefix | Example |
|---|---|---|
| New agent / feature | `feature/` | `feature/performance-agent` |
| Bug fix | `fix/` | `fix/wt-done-detached-head` |
| Refactor | `refactor/` | `refactor/setup-idempotency` |
| Documentation | `docs/` | `docs/agent-authoring-guide` |

All names in kebab-case. Never commit directly to `main` (enforced by `.opencode/rules/git-safety.md`).

## Adding a New Agent

1. Create `.opencode/agents/<name>.md` with valid YAML frontmatter
2. Decide the permission tier (read-only vs write, `mode: primary` vs subagent)
3. Add a `description:` line that clearly states what tasks it handles — the orchestrator uses this for routing
4. Add an entry to the routing table in `orchestrator.md` (`## Workflow > Step 2 — Task Analysis`)
5. If the agent needs a non-default model, add its override to `opencode.json.templates/_agents.json` and mirror it in `opencode.json` at the repo root
6. Run `bash -n` on any shell scripts you touched, then `shellcheck` if available

## Updating Agent Model Overrides

Model and temperature overrides for custom subagents live in a single fragment:
`opencode.json.templates/_agents.json`. `setup.sh` deep-merges it into the
stack-specific template using `jq -s '.[0] * .[1]'` when creating a new
project's `opencode.json`.

Workflow when changing a model:

1. Edit `opencode.json.templates/_agents.json` — the single source of truth for overrides
2. Mirror the same change in `opencode.json` at the repo root — this is the active config when opening opencode in this repo and the fallback template when a stack `.json` is missing. Keep both in sync manually.
3. Existing target projects do NOT auto-update; users must delete their local `opencode.json` and re-run `bash ~/dev/agents/setup.sh` to pick up the new overrides.

Conventions:

- The `_` prefix on `_agents.json` marks it as a fragment, not a selectable stack template. `setup.sh` never picks it up via stack detection.
- Stack templates (`node.json`, `python.json`, etc.) must NOT define agents that appear in the fragment — the fragment would silently override them. Stack templates are for `build`/`plan` permissions and bash allowlists only.

## Notes

- **Symlink model**: `agents/` and `rules/` are symlinked from `~/dev/agents/.opencode/` into every target project. Editing a file here instantly affects all linked projects — be deliberate.
- **Per-project files**: `opencode.json` and `AGENTS.md` are *copied* (not symlinked) so each project can customize them independently.
- **`AGENTS.md.template`** is the canonical starter — do not use it directly; `setup.sh` copies it as `AGENTS.md` into the target project.
- **Bun for the plugin only**: `.opencode/package.json` has one dep (`@opencode-ai/plugin`). `node_modules`, `package.json`, and `bun.lock` are gitignored inside `.opencode/` so the symlink in target projects doesn't pull in local build artifacts.
- **`wt-new` requires `opencode` on PATH**: it ends with `opencode "$worktree_path"` — the binary must be installed system-wide.
