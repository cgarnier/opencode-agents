# OpenCode — Multi-Agent Dev System

A system of specialized agents for OpenCode, designed for fullstack development (front, back, devops).
Each agent has a precise role and scoped permissions. Global rules ensure `main` is never touched and all quality checks pass before a task is declared done.

---

## Table of contents

1. [Overview](#1-overview)
2. [Prerequisites](#2-prerequisites)
3. [Installation](#3-installation)
4. [File structure](#4-file-structure)
5. [Agents](#5-agents)
   - [Orchestrator](#51-orchestrator--primary)
   - [Build](#52-build--primary-built-in)
   - [Plan](#53-plan--primary-built-in)
   - [Reviewer](#54-reviewer--subagent)
   - [Debugger](#55-debugger--subagent)
   - [Tester](#56-tester--subagent)
   - [Refactorer](#57-refactorer--subagent)
   - [Docs-writer](#58-docs-writer--subagent)
   - [Performance](#59-performance--subagent)
   - [Security](#510-security--subagent)
   - [Git-publisher](#511-git-publisher--subagent)
6. [Global rules](#6-global-rules)
   - [git-safety](#61-git-safety)
   - [code-quality](#62-code-quality)
7. [Custom commands](#7-custom-commands)
   - [/ticket](#71-ticket)
   - [/new-ticket](#72-new-ticket)
   - [/check-agents](#73-check-agents)
8. [Per-project configuration](#8-per-project-configuration)
9. [Complete workflow examples](#9-complete-workflow-examples)
10. [Customization](#10-customization)
11. [Parallel work — Worktrees](#11-parallel-work--worktrees)
12. [Quick reference](#12-quick-reference)

---

## 1. Overview

### Problem solved

OpenCode's default `build` mode is a generalist agent: it does everything, but without guardrails. It can work on `main`, forget to run tests, and mix investigation and implementation in the same context.

This system provides:

- **`main` protection** — no agent touches `main` directly. The working branch is always decided upfront, with confirmation if the context is ambiguous.
- **Specialization** — each task type (review, debug, tests, refactoring, docs, perf, security) has a dedicated agent with a tailored process and permissions.
- **Automatic quality gate** — after any code change, the checks defined in `AGENTS.md` (lint, typecheck, tests, build) must pass. An agent never declares a task done if a check fails.
- **Parallel delegation** — the orchestrator can launch several specialized agents in parallel and synthesize the results.

### Philosophy

```
One agent = one role = permissions scoped to that role
```

A review agent doesn't need to write files. A debug agent doesn't need to modify code. These restrictions are not artificial limitations: they ensure each agent does exactly what it was designed to do, with no risk of side effects.

---

## 2. Prerequisites

- [OpenCode](https://opencode.ai) installed (`curl -fsSL https://opencode.ai/install | bash`)
- A Claude provider configured in OpenCode (`/connect` in the TUI)
- The template directory at `~/dev/agents/` (this repo)
- `git` available in the PATH

---

## 3. Installation

### One-time setup

Run the shell helpers installer:

```bash
bash ~/dev/agents/install-shell-helpers.sh
```

This script updates `.bashrc` and `.zshrc` automatically:
- Adds `agents-setup` (alias for `setup.sh`)
- Replaces any old `wt-new` / `wt-done` aliases with a `source` of `shell-functions.sh`
- Keeps the `wt-list` alias

> **Why `source` instead of aliases?**
> `wt-new` and `wt-done` need to change the terminal's current directory (`cd`). An alias or script runs in a subshell — the `cd` doesn't affect the parent shell. Only a shell function sourced into the current shell can do this.

Reload the shell:

```bash
source ~/.zshrc   # or source ~/.bashrc
```

### Per-project (in each new repo)

```bash
cd my-project/
agents-setup
```

Expected output:

```
OpenCode multi-agent setup → /path/to/my-project
──────────────────────────────────────────
  ✓ .opencode/agents/ → /home/<user>/dev/agents/.opencode/agents
  ✓ .opencode/rules/  → /home/<user>/dev/agents/.opencode/rules
  ✓ opencode.json copied (customize for this project)
  ✓ AGENTS.md created from template

  → Fill in AGENTS.md with your project's quality check commands.

Done. Run 'opencode' to start.
```

### What `setup.sh` does in detail

| Step | Action | Behavior if already present |
|---|---|---|
| 1 | Creates `.opencode/` | Skipped if exists |
| 2 | Symlink `.opencode/agents/` → template | Skip + warning if a real folder already exists |
| 3 | Symlink `.opencode/rules/` → template | Skip + warning if a real folder already exists |
| 4 | Symlink `.opencode/commands/` → template | Skip + warning if a real folder already exists |
| 5 | Symlink `.opencode/skills/` → template | Skip + warning if a real folder already exists |
| 6 | Copies `opencode.json` | Skip if already present |
| 7 | Copies `AGENTS.md.template` → `AGENTS.md` | Skip if already present |

**Idempotent**: re-running `agents-setup` in an already-configured project is safe.

### Symlink vs copy strategy

| File | Strategy | Reason |
|---|---|---|
| `.opencode/agents/` | **Symlink** | Updating the template instantly updates all projects |
| `.opencode/rules/` | **Symlink** | Same — git and quality rules are global |
| `.opencode/commands/` | **Symlink** | Same — custom commands are shared across all projects |
| `.opencode/skills/` | **Symlink** | Same — CLI skills (glab, gh, jira) are shared |
| `opencode.json` | **Copy** | Each project can have different permissions and models |
| `AGENTS.md` | **Copy** | Content is entirely project-specific |

> To customize an agent for a specific project, remove the `.opencode/agents/` symlink and replace it with a real folder containing your overrides. See [Customization](#10-customization).

### Why per-project and not global

The agent *logic* (agents, rules, commands, skills) is already global: it lives in `~/dev/agents/` and is symlinked into every project. What's installed per-project is the *context* — `AGENTS.md` and `opencode.json` — which tells the agents what to do specifically in *this* project.

This distinction matters because agent quality is directly tied to project quality. `AGENTS.md` tells agents which commands to run for the quality gate, which tracker to use, what the coding conventions are. On a well-managed project — quality checks defined, conventions documented, tracker configured — the agents work exactly as intended. On a project with none of that, they operate blind: they skip the quality gate, pick the wrong tracker, and apply generic conventions that may contradict the actual codebase.

If the system were installed globally with a single shared config, a poorly maintained project would silently degrade behavior across the board — wrong commands, wrong tracker, wrong conventions, no guardrails. The per-project model isolates each project's context: a project that hasn't done the setup gets a clear signal (empty sections flagged by `/check-agents`) rather than silently broken agents. Good projects are not affected by bad ones.

---

## 4. File structure

```
~/dev/agents/
│
├── README.md                        ← this documentation
├── setup.sh                         ← installation script (agents-setup)
├── opencode.json                    ← config template (copied into each project)
├── AGENTS.md.template               ← starter AGENTS.md (copied into each project)
│
└── .opencode/
    ├── rules/                       ← symlinked into each project
    │   ├── git-safety.md            ← branching rule (alwaysApply: true)
    │   └── code-quality.md          ← quality gate rule (alwaysApply: true)
    │
    ├── agents/                      ← symlinked into each project
    │   ├── orchestrator.md          ← PRIMARY agent
    │   ├── reviewer.md              ← subagent
    │   ├── debugger.md              ← subagent
    │   ├── tester.md                ← subagent
    │   ├── refactorer.md            ← subagent
    │   ├── docs-writer.md           ← subagent
    │   ├── performance.md           ← subagent
    │   ├── security.md              ← subagent
    │   └── git-publisher.md         ← subagent
    │
    ├── commands/                    ← symlinked into each project
    │   ├── ticket.md                ← /ticket <id> [context]
    │   ├── new-ticket.md            ← /new-ticket <description>
    │   └── check-agents.md          ← /check-agents
    │
    └── skills/                      ← symlinked into each project
        ├── glab/
        │   └── SKILL.md             ← GitLab CLI (issues, MR, CI, pipelines)
        ├── gh/
        │   └── SKILL.md             ← GitHub CLI (issues, PRs, Actions)
        └── jira/
            └── SKILL.md             ← Jira CLI via acli (workitems, sprints)
```

After `agents-setup` in a project, the local structure is:

```
my-project/
├── opencode.json                    ← copied, customizable
├── AGENTS.md                        ← copied, to be filled in
└── .opencode/
    ├── agents/    →  ~/dev/agents/.opencode/agents/    (symlink)
    ├── rules/     →  ~/dev/agents/.opencode/rules/     (symlink)
    ├── commands/  →  ~/dev/agents/.opencode/commands/  (symlink)
    └── skills/    →  ~/dev/agents/.opencode/skills/    (symlink)
```

---

## 5. Agents

OpenCode provides two types of agents:
- **Primary**: interactive agents, accessible via the **Tab** key in the TUI
- **Subagent**: specialized agents, invokable via `@name` in a message or automatically via the Task tool

### 5.1 Orchestrator — primary

| Property | Value |
|---|---|
| Mode | `primary` |
| Color | Purple `#7c3aed` |
| File access | Full read/write |
| Bash | Git read `allow` · git checkout/pull `allow` · rest `ask` |
| Task tool | All subagents `allow` |

**Role**: entry point for complex tasks. Analyzes the request, manages the branching strategy, delegates to the right specialists, and validates everything with the final quality gate.

**When to use**: whenever a task goes beyond a simple implementation — review + security, debug + fix, refactoring + tests, etc.

**Internal workflow**:

```
1. Branch Decision
   └─ git branch --show-current
   └─ Apply git-safety (see §6.1)
   └─ Ask if branch target is ambiguous

2. Task Analysis
   └─ Read AGENTS.md (stack, conventions, quality checks)
   └─ Identify task type(s)
   └─ Select specialists

3. Delegation
   └─ Independent tasks → launch in parallel
   └─ Dependent tasks   → launch sequentially

4. Final Quality Gate
   └─ Read ## Quality Checks in AGENTS.md
   └─ Run: format → lint → typecheck → test → build
   └─ Fix failures, retry until all pass

5. Synthesis
   └─ Branch used / created
   └─ Specialist results
   └─ Quality gate status
```

---

### 5.2 Build — primary (built-in)

| Property | Value |
|---|---|
| Mode | `primary` (built-in OpenCode agent, customized) |
| File access | Full read/write |
| Bash | Git read `allow` · rest `ask` |

**Role**: direct implementation. Default agent for writing code, creating files, fixing simple bugs.

**Difference from the orchestrator**: `build` works directly without delegating. Use it for simple, focused tasks. For composite tasks, prefer the orchestrator.

**Customization in `opencode.json`**:
- Git read (status, diff, log, branch, fetch): automatic `allow`
- All other bash: `ask` — the agent asks for confirmation before executing

---

### 5.3 Plan — primary (built-in)

| Property | Value |
|---|---|
| Mode | `primary` (built-in OpenCode agent, customized) |
| File access | **None** — `edit: deny` |
| Bash | **None** — full `deny` |

**Role**: thinking and planning without modifying anything. Ideal for exploring an architecture, designing a feature, or understanding a codebase before acting.

**Usage**: press **Tab** in the TUI to cycle between Build, Plan and Orchestrator.

---

### 5.4 Reviewer — subagent

| Property | Value |
|---|---|
| Mode | `subagent` |
| Color | Blue `#0891b2` |
| File access | **None** — `edit: deny` |
| Bash | `git diff/log/show`, `grep`, `ls` only |

**Role**: structured code review. Analyzes code across 8 dimensions and returns a hierarchical report.

**Dimensions analyzed**:
- Correctness (logic, edge cases, null handling)
- Quality (naming, function size, single responsibility)
- Duplication (repeated logic to extract)
- Complexity (nested code, cyclomatic complexity)
- Patterns (anti-patterns, inconsistencies with the rest of the project)
- Error handling (missing try/catch, silent promise rejections)
- Types (use of `any`, missing types — TS projects)
- Tests (untested critical paths)

**Output format**:

```
## Code Review — <scope>

### Critical
- [file:line] Description + Suggestion

### Warning
- [file:line] Description + Suggestion

### Info
- [file:line] Minor note + Suggestion

### Positive
- What is well done (1-3 items max)

### Summary
Overall assessment in 2-3 sentences.
```

**Invocation**: `@reviewer review the auth module` or automatically by the orchestrator.

---

### 5.5 Debugger — subagent

| Property | Value |
|---|---|
| Mode | `subagent` |
| Color | Red `#dc2626` |
| File access | **None** — `edit: deny` |
| Bash | `git log/diff/show/blame`, `grep`, `ls`, `cat` only |

**Role**: hypothesis-driven bug investigation. Never fixes — identifies and locates.

**4-phase process**:

```
Phase 1 — Understand the symptom
  → Observed vs expected behavior, reproduction conditions

Phase 2 — Form hypotheses
  → 2-4 plausible root causes, ranked by likelihood

Phase 3 — Investigate
  → Trace the data flow, git log, grep, eliminate hypotheses

Phase 4 — Report
  → Confirmed root cause + precise location + fix direction
```

**Output format**:

```
## Debug Report — <description>

### Symptom
### Root Cause
Location: file:line
### Evidence
### Eliminated hypotheses
### Fix direction
Estimated complexity: XS / S / M / L
```

**Important**: the debugger does not code the fix. It hands off to `build` or the orchestrator.

---

### 5.6 Tester — subagent

| Property | Value |
|---|---|
| Mode | `subagent` |
| Color | Green `#16a34a` |
| File access | **Full** — `edit: allow` |
| Bash | `git diff/branch`, `grep`, `ls` · rest `allow` |

**Role**: analyzes existing coverage and generates missing tests. Follows the project's test conventions. Runs the tests at the end — they must pass.

**Priorities**:
1. Critical paths (happy path)
2. Error cases (invalid input, missing data)
3. Edge cases (boundary values, null/undefined, concurrent calls)
4. Integration points (interactions between modules)

**Quality gate**: runs the `test` command from `AGENTS.md` after writing tests. All must pass before handing back.

**Output format**:

```
## Tests written — <scope>

### Coverage added
- <file> — N tests (list of scenarios)

### Edge cases covered
### Not covered (out of scope / needs more context)

### Quality gate
test: ✓ (N passing)
```

---

### 5.7 Refactorer — subagent

| Property | Value |
|---|---|
| Mode | `subagent` |
| Color | Orange `#ea580c` |
| File access | **Full** — `edit: allow` |
| Bash | `git diff/branch`, `grep`, `ls` · rest `allow` |

**Role**: improves the internal structure of code without changing its observable behavior. Proposes a plan before acting.

**Absolute rule**: if tests fail after a refactoring, it's a regression — the refactoring changed behavior. Stop and fix.

**Process**:

```
1. Read the code in full
2. Propose a plan (issues identified, proposed changes, risks)
3. Wait for approval (implicit if invoked by orchestrator with a clear task)
4. Refactor incrementally
5. Full quality gate: format → lint → typecheck → test → build
```

**Allowed operations**:
- Extracting functions/constants/types
- Renaming for expressiveness
- Simplification (flatten nested conditions)
- Consolidation (remove dead code, merge duplicated logic)
- Separation (split files/modules that have too many responsibilities)

**Forbidden operations**:
- Changing business logic
- Introducing new dependencies
- Modifying public APIs without flagging it explicitly

---

### 5.8 Docs-writer — subagent

| Property | Value |
|---|---|
| Mode | `subagent` |
| Color | Dark blue `#0369a1` |
| File access | **Full** — `edit: allow` |
| Bash | `ls`, `git log`, `grep` only — no execution |

**Role**: writes and maintains technical documentation. Adapts to the existing style in the project.

**Types of documentation produced**:

| Type | Detail |
|---|---|
| JSDoc / TSDoc | `@param`, `@returns`, `@throws`, `@example` |
| Inline comments | Only the *why*, never the *what* |
| README | Structured sections, working code examples |
| ADR | Architecture Decision Records in standard format |
| API docs | Endpoints, request/response, curl examples |

**Core principle**: accuracy over completeness. Wrong documentation is worse than no documentation.

---

### 5.9 Performance — subagent

| Property | Value |
|---|---|
| Mode | `subagent` |
| Color | Amber `#b45309` |
| File access | **None** — `edit: deny` |
| Bash | `ls`, `grep`, `git diff`, `cat`, `find` · nothing else (`deny`) |

**Role**: performance audit. Identifies bottlenecks and returns a report prioritized by user impact.

**Areas covered**:

*Backend / API*: N+1 queries, missing indexes, excessive fetching, blocking operations, missing cache, oversized payloads.

*Frontend*: unnecessary re-renders, missing memoization, bundle size, waterfall requests instead of parallel, memory leaks.

*Algorithms*: O(n²) complexity or worse, wrong data structure, unnecessary multiple passes over the same data.

**Output format**:

```
## Performance Audit — <scope>

### Critical  (significant user impact)
- [file:line] Issue + Impact + Fix

### High      (noticeable impact at scale)
### Medium    (minor gains)
### Out of scope (requires real profiling data)

### Summary
```

---

### 5.10 Security — subagent

| Property | Value |
|---|---|
| Mode | `subagent` |
| Color | Dark red `#991b1b` |
| File access | **None** — `edit: deny` |
| Bash | `grep`, `ls`, `cat`, `find` only (read-only) |

**Role**: security audit based on OWASP Top 10. Returns a severity-ranked report.

**Categories analyzed**:

| Category | OWASP | Examples |
|---|---|---|
| Injection | A03 | SQL injection, command injection, NoSQL |
| Auth & Authz | A01, A07 | Missing auth, broken RBAC, weak JWT |
| Data Exposure | A02 | Hardcoded secrets, PII in logs, no encryption |
| Misconfiguration | A05 | CORS wildcard, permissive headers, debug in prod |
| Dependencies | A06 | Packages with known CVEs, outdated critical versions |
| Dangerous patterns | — | `eval()`, `innerHTML`, path traversal, ReDoS, race conditions |

**Severity levels**: Critical → High → Medium → Low → Info

**Important**: reports only what is found in the code. Does not construct hypothetical attack chains.

---

### 5.11 Git-publisher — subagent

| Property | Value |
|---|---|
| Mode | `subagent` |
| Color | Indigo `#4f46e5` |
| File access | **None** — `edit: deny` |
| Bash | Git read + `git add/commit/push`, `glab mr`, `gh pr` |

**Role**: writes commit messages (conventional commits) and MR/PR descriptions, then executes the full publish flow.

**Workflow**:

```
1. git status + git diff --staged (or main...HEAD)
2. Platform detection via git remote get-url origin
   → github.com → gh
   → other       → glab
3. Write the commit message (conventional commits)
4. Commit directly if the diff is clear — otherwise asks for confirmation
5. git push (with -u origin <branch> if no upstream)
6. Offers to create the MR/PR — if yes, writes and creates
```

**Invocation**: `@git-publisher` or automatically by the orchestrator after a task.

---

## 6. Global rules

Rules are markdown files with `alwaysApply: true` in their frontmatter. They are injected into the context of **all** agents via the `instructions` field of `opencode.json`. They therefore apply to `build`, the orchestrator, and every subagent.

### 6.1 git-safety

**File**: `.opencode/rules/git-safety.md`

#### Core rule

> NEVER commit, push, or make code changes directly on `main`.

#### Decision tree (executed before any code change)

```
git branch --show-current
        │
        ▼
  Branch = main?
  ┌─ YES ──────────────────────────────────────────────────────┐
  │  STOP. Warn the user.                                      │
  │  "I don't work directly on main."                         │
  │  Suggest creating a branch before continuing.              │
  │  Do not modify anything while on main.                     │
  └────────────────────────────────────────────────────────────┘
        │
  Branch ≠ main
        │
        ├─ Fix / improvement related to the current branch?
        │   └─ Stay on the current branch.
        │
        ├─ New feature depending on the current branch?
        │   └─ git checkout -b <name>
        │       (fork from the current branch)
        │
        └─ New independent feature?
            └─ git fetch origin
               git checkout main && git pull
               git checkout -b <name>
               (fork from up-to-date main)
```

#### Ambiguous cases

If the intent is ambiguous (task related **or** independent), the agent asks **before** creating anything:

> "Is this task related to `feat/auth` or independent from that branch?
> I suggest `feature/notifications` — does that work?"

#### Branch naming

| Prefix | Usage |
|---|---|
| `feature/` | New feature |
| `fix/` | Bug fix |
| `refactor/` | Refactoring |
| `docs/` | Documentation |
| `test/` | Adding tests |
| `perf/` | Performance optimization |

Names in **kebab-case**, short and descriptive.

#### Commits

- **Conventional Commits** format: `feat:`, `fix:`, `refactor:`, `test:`, `docs:`, `chore:`
- Never `git push --force` on a shared branch without explicit confirmation
- Prefer rebase over merge to integrate `main` into a feature branch

---

### 6.2 code-quality

**File**: `.opencode/rules/code-quality.md`

#### Core rule

> After ANY code change, all quality checks defined in `AGENTS.md` must pass before declaring the task done.

#### Procedure

```
1. Read ## Quality Checks in AGENTS.md
   └─ If section missing → warn the user and ask for the commands

2. Run in order:
   format    → format the code (may modify files)
   lint      → check static rules
   typecheck → check types
   test      → run tests
   build     → verify compilation / bundle

3. On failure:
   └─ Analyze the error
   └─ Fix
   └─ Re-run the affected command
   └─ Repeat until all pass

4. If the failure pre-existed before the changes:
   └─ Report: "This check was already failing before my changes: <error>"
   └─ Offer to fix or ignore depending on context

5. Confirm once everything passes:
   "All quality checks pass: format ✓ lint ✓ typecheck ✓ test ✓ build ✓"
```

#### Agents subject to the quality gate

| Agent | Quality gate | Reason |
|---|---|---|
| `build` | Yes | After each code change |
| `tester` | Yes | Generated tests must themselves pass |
| `refactorer` | Yes | Critical — any regression is a bug |
| `orchestrator` | Yes | Final gate after all subagents |
| `reviewer` | No | Read-only, no code changes |
| `debugger` | No | Read-only, no code changes |
| `docs-writer` | No | Documentation only |
| `performance` | No | Audit only |
| `security` | No | Audit only |

---

## 7. Custom commands

Commands are markdown files in `.opencode/commands/`. They are invoked with `/` in the TUI and accept positional arguments (`$1`, `$2`, …) or `$ARGUMENTS` to capture everything.

The `commands/` directory is **symlinked** from the template — adding a command here deploys it automatically to all installed projects.

---

### 7.1 /ticket

**File:** `.opencode/commands/ticket.md`

**Usage:**
```
/ticket <id> [additional context]
```

**Examples:**
```
/ticket 42
/ticket 87 focus on the payment module
/ticket PROJ-123 do not touch the public API
```

**Role:** analyzes a ticket (GitLab, GitHub or Jira) and all its sub-tickets to produce a structured implementation plan. Does not create a branch or modify any files.

**Supported trackers:**

| ID format | Detected tracker | Command used |
|---|---|---|
| Integer (`42`) + `gitlab.com` remote | GitLab | `glab issue view` + GraphQL |
| Integer (`42`) + `github.com` remote | GitHub | `gh issue view` |
| `PROJ-42` | Jira | `acli jira workitem view` |

**Output produced:**

```
## Implementation Plan — Ticket #<id>: <title>

### Additional context
### Sub-ticket tree      — ID, title, status, estimated size
### Technical analysis   — impacted files, dependencies, risks
### Implementation order — recommended sequence with approach per sub-ticket
### Concrete next steps  — branch to create, where to start
```

**Agent to use:** choose before running the command.
- `plan` — pure analysis, no bash access (recommended if `glab` is already configured)
- `build` / `orchestrator` — can also explore the codebase dynamically

---

### 7.2 /new-ticket

**File:** `.opencode/commands/new-ticket.md`

**Usage:**
```
/new-ticket <free description of the problem or feature>
```

**Examples:**
```
/new-ticket bug on login when email is empty
/new-ticket add CSV export on the reports page
/new-ticket refactor the payment module — too coupled
```

**Role:** creates a ticket in the right ticketing system with automatic pre-analysis. Displays a formatted preview before creating. Does not modify any files.

**Internal workflow:**
1. Reads `AGENTS.md` → `## Tracker` section to detect the target system
2. Fallback: detects via `git remote get-url origin` (`github.com` → gh, gitlab → glab, otherwise → jira)
3. Reads `## Ticket conventions` in `AGENTS.md` if present — otherwise applies defaults
4. Silent pre-analysis: type, size, priority from the description
5. Builds the title `[Context] Verb + object` and the structured description
6. Displays the formatted ticket and asks for confirmation `[y/N]`
7. Creates the ticket via the right CLI
8. Displays the link to the created ticket

**Supported trackers:**

| Tracker | CLI | Detection |
|---|---|---|
| GitLab | `glab issue create` | `tracker: gitlab` in `AGENTS.md` or gitlab remote |
| GitHub | `gh issue create` | `tracker: github` in `AGENTS.md` or github.com remote |
| Jira | `acli jira workitem create` | `tracker: jira` in `AGENTS.md` or `[A-Z]+-\d+` ID |

**Default conventions (if `## Ticket conventions` is absent):**

| Field | Value |
|---|---|
| Language | English |
| Title | `[Context] Verb + object` |
| Labels | `type::feature\|bug\|tech\|chore` + `size::XS…XL` + `priority::critical…low` |
| Description | Context / Task / Acceptance criteria / Notes |

**Skills loaded automatically**: `glab`, `gh`, or `jira` depending on the detected tracker — the corresponding CLI skill is consulted for the exact creation command syntax.

---

### 7.3 /check-agents

**File:** `.opencode/commands/check-agents.md`

**Usage:**
```
/check-agents
```

**Role:** audits the current project's `AGENTS.md` by comparing it to the `AGENTS.md.template` from the agents repo. Identifies missing or empty sections, infers content from the codebase, and proposes additions — with confirmation before writing anything.

**Internal workflow:**
1. Locates the template via `readlink -f .opencode/` → goes up one level
2. Parses sections from both files and classifies each:
   - `✓ OK` — present and filled
   - `~ Empty` — present but empty or contains only comments/placeholders
   - `✗ Missing` — absent from `AGENTS.md`
   - `→ Project-specific` — present in the project but not in the template (listed as info, not modified)
3. Explores the codebase to infer content for problematic sections (`package.json`, `Makefile`, `go.mod`, git remote, etc.)
4. **Interactive tracker detection**: attempts detection via `git remote get-url origin`, always asks for confirmation, and if incorrect asks directly (including the project key if Jira)
5. Displays a report + preview of proposed additions
6. Applies only if confirmed — never overwrites existing content

**Example report:**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AGENTS.md — Audit

  ✓ Stack
  ✓ Commands
  ~ Quality Checks        (empty)
  ✗ Tracker               (missing)
  → Purpose               (project-specific, kept as-is)

  --- Proposed additions ---

  ## Quality Checks
  - test: npm test
  - lint: npm run lint
  - format: npm run format

  ## Tracker
  tracker: github
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Apply these additions to AGENTS.md? [y/N]
```

---

## 8. Per-project configuration

### `opencode.json`

Copied into each project by `agents-setup`. Customize it per project.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",

  // Global rules injected into all agents
  "instructions": [
    ".opencode/rules/git-safety.md",
    ".opencode/rules/code-quality.md"
  ],

  "agent": {
    "build": {
      "permission": {
        "bash": {
          "*": "ask",                // all bash commands → confirmation
          "git status*": "allow",   // git read → silent
          "git diff*": "allow",
          "git log*": "allow",
          "git branch*": "allow",
          "git fetch*": "allow",
          "ls*": "allow",
          "pwd": "allow"
        }
      }
    },
    "plan": {
      "permission": {
        "edit": "deny",   // no file modification
        "bash": "deny"    // no shell commands
      }
    }
  }
}
```

**Useful customizations**:

```jsonc
// Use a specific model for an agent
"agent": {
  "orchestrator": {
    "model": "anthropic/claude-opus-4-5"
  }
}

// Automatically allow test commands for this project
"agent": {
  "build": {
    "permission": {
      "bash": {
        "npm test": "allow",
        "npm run lint": "allow"
      }
    }
  }
}

// Disable an agent not relevant for this project
"agent": {
  "security": {
    "disable": true
  }
}
```

---

### `AGENTS.md`

Copied from `AGENTS.md.template`. This is the most important file to fill in — agents read it systematically to understand the project and retrieve quality commands.

**Structure**:

```markdown
# Project name

## Stack
NestJS + TypeScript / Nuxt 3 + Vue / etc.

## Structure
- src/modules/  — feature modules
- src/common/   — shared utilities
- tests/        — tests (mirror of src/)

## Commands
- dev: npm run dev
- install: npm install

## Quality Checks
<!-- REQUIRED — all agents that modify code run these commands -->
- test: npm test
- lint: npm run lint
- format: npm run format
- typecheck: npm run typecheck
- build: npm run build

## Tracker
<!-- Ticketing system used in this project -->
<!-- Values: gitlab | github | jira -->
tracker: gitlab

## Ticket conventions
<!-- Optional — if absent, /new-ticket uses defaults (English, [Context] Verb+object, type/size/priority labels) -->
<!-- Example:
- Language: French
- Title format: feat(scope): description
- Labels: none
- Description: Problem / Solution / Impact
-->

## Conventions
- Named exports only, no default export
- DTOs validated with class-validator
- Conventional commits: feat/fix/chore/refactor/test/docs
- ...

## Notes
- Run DB migrations with: npm run migrate
- ...
```

> The `## Quality Checks` section is **required**. If absent, agents report it and ask to fill it in before continuing.

---

## 9. Complete workflow examples

### Example 1 — New independent feature

**Context**: you are on `feat/auth`, you want to add a notifications system.

```
You → @orchestrator "Implement a push notification system"

Orchestrator:
  1. git branch --show-current → feat/auth
  2. "Is notifications related to feat/auth or independent?"
     → You answer: "Independent"
  3. git fetch origin && git checkout main && git pull
     git checkout -b feature/push-notifications
  4. Task = implementation → delegates to build directly
     (or handles directly depending on complexity)
  5. Quality gate: format ✓ lint ✓ typecheck ✓ test ✓ build ✓
  6. Synthesis: "Feature implemented on feature/push-notifications"
```

---

### Example 2 — Bug + investigation + fix

**Context**: confirmation emails are not being sent.

```
You → @orchestrator "Confirmation emails are not being sent"

Orchestrator:
  1. git branch --show-current → feature/user-onboarding  ✓
  2. Task = bug → invoke @debugger first

  @debugger:
    Phase 1: symptom documented
    Phase 2: 3 hypotheses (blocked queue, SMTP config, missing template)
    Phase 3: git log → grep the mail service → trace the flow
    Phase 4: Root cause = SMTP_HOST env variable missing in staging
    → Report handed back to orchestrator

  Orchestrator:
    → Targeted fix via build (add the config + startup guard)
    → Full quality gate
    → Synthesis: root cause + fix applied + checks ✓
```

---

### Example 3 — Code review + security audit in parallel

**Context**: you just finished a payment module.

```
You → @orchestrator "Full review of the payment module before merge"

Orchestrator:
  1. git branch --show-current → feature/payment  ✓
  2. Tasks = review + security → independent → launch in parallel

  In parallel:
    @reviewer  → analyze src/modules/payment/
    @security  → audit src/modules/payment/

  Results:
    reviewer  → 2 Critical, 4 Warning (e.g.: amount not validated server-side)
    security  → 1 High (Stripe secret in code), 2 Medium

  Orchestrator:
    → Consolidated synthesis of both reports
    → Prioritized: Critical and High first
    → No quality gate (no files modified by these agents)
```

---

### Example 4 — Module refactoring

**Context**: the `UserService` is 600 lines long.

```
You → @orchestrator "Refactor UserService, it's too large"

Orchestrator:
  1. git branch --show-current → feat/user-improvements  ✓
  2. Task related to current branch → stay on it
  3. Invoke @refactorer

  @refactorer:
    Step 1: Read UserService in full
    Step 2: Proposed plan
      - Extract AuthUserService (auth logic)
      - Extract UserQueryService (read logic)
      - Rename ambiguous methods
      - Risk: Medium (public interfaces change)
    → Waiting for approval

  You → "Go"

  @refactorer:
    Step 3: Incremental refactoring
    Step 4: format ✓ lint ✓ typecheck ✓ test ✓ build ✓

  Orchestrator:
    → Final quality gate (already passed by refactorer, verifies anyway)
    → Synthesis: 3 files created, 1 file deleted, all checks ✓
```

---

### Example 5 — Attempt to work on `main`

```
You → (on main branch) @build "Add an email field to User"

Build:
  1. git branch --show-current → main
  2. STOP.
     "I don't work directly on main.
     Create a branch first. I suggest: feature/user-email-field
     You can run: git checkout -b feature/user-email-field"

→ No files modified.
```

---

## 10. Customization

### Adding a project-specific agent

Create a file in the project's `.opencode/agents/` (not in the symlink — you need to replace it with a real folder first):

```bash
# Replace the symlink with a real folder while keeping the global agents
cp -r ~/dev/agents/.opencode/agents my-project/.opencode/agents-backup
rm my-project/.opencode/agents
cp -r ~/dev/agents/.opencode/agents my-project/.opencode/agents
```

Then create the specific agent:

```bash
# Example: specialized agent for DB migrations
cat > my-project/.opencode/agents/db-migrator.md << 'EOF'
---
description: Database migration specialist — creates, reviews and runs database migrations safely.
mode: subagent
permission:
  edit: allow
  bash:
    "*": ask
    "npm run migrate:status": allow
    "npm run migrate:dry-run": allow
---

You are specialized in database migrations for this project.
...
EOF
```

### Overriding built-in agent permissions

In the project's `opencode.json`:

```jsonc
"agent": {
  // Automatically allow tests for this project
  "build": {
    "permission": {
      "bash": {
        "*": "ask",
        "npm test": "allow",
        "npm run test:watch": "allow",
        "git *": "allow"
      }
    }
  }
}
```

### Disabling an agent

```jsonc
"agent": {
  "performance": { "disable": true },
  "docs-writer": { "disable": true }
}
```

### Updating all projects

Modify a file in `~/dev/agents/.opencode/agents/` or `~/dev/agents/.opencode/rules/`: the update is **immediate** in all projects using the symlinks. No need to reinstall.

---

## 11. Parallel work — Worktrees

OpenCode does not natively manage session parallelism. The solution is **git worktrees**: each feature works in its own folder on disk, with its own branch, and can have its own `opencode` open in parallel with no file conflicts.

### Concept

```
~/dev/
├── my-project/                         ← main repo (main)
├── my-project-feature-auth/            ← worktree feature/auth
└── my-project-feature-notifications/   ← worktree feature/notifications
```

Each folder is independent on disk but shares the same git history.

### `wt-new <branch> [--from <base>]` — create a worktree

```bash
# From anywhere in the main repo
wt-new feature/auth

# Fork from a specific branch instead of main
wt-new feature/notifications --from feature/auth

# Fork from the current branch (shorthand)
wt-new feature/sub-task --from current
```

What it does:
1. Refuses to work on `main`/`master`
2. Fetches origin and creates the branch from up-to-date `main` (or from `--from <base>` if specified)
3. `git worktree add ../my-project-feature-auth feature/auth`
4. Runs `agents-setup` in the new worktree (symlinks + opencode.json + AGENTS.md)
5. `cd` into the worktree (terminal moves automatically)
6. Launches opencode (blocking — Ctrl-C to quit)
7. After closing opencode, the terminal is still in the worktree → ready for `wt-done`

Expected output:

```
Creating worktree for branch: feature/auth
Path: /home/<user>/dev/my-project-feature-auth
──────────────────────────────────────────
  ✓ Branch 'feature/auth' created from main
  ✓ Worktree created at /home/<user>/dev/my-project-feature-auth
  ✓ .opencode/agents/ → ~/dev/agents/.opencode/agents
  ✓ .opencode/rules/  → ~/dev/agents/.opencode/rules
  ✓ opencode.json copied
  ✓ AGENTS.md created from template

  Worktree ready.
  When done, run wt-done from inside the worktree to clean up.

  → Launching opencode... (Ctrl-C to exit, then run wt-done)
```

### `wt-done` — clean up a finished worktree

```bash
# From inside the worktree, after the PR is merged
wt-done
```

What it does:
1. Refuses to run from the main repo
2. Checks for uncommitted changes → asks for confirmation if any
3. Fetches origin and checks if the branch is merged into `origin/main`
   - **Merged** → deletes directly without confirmation
   - **Not merged** → warning + explicit confirmation required
4. `git worktree remove` + `git branch -d` + `git worktree prune`
5. `cd` into the main repo (terminal returns automatically)

### `wt-list` — view active worktrees

```bash
wt-list
# alias for: git worktree list

/home/user/dev/my-project                          abc1234 [main]
/home/user/dev/my-project-feature-auth             def5678 [feature/auth]
/home/user/dev/my-project-feature-notifications    ghi9012 [feature/notifications]
```

### Full flow — two features in parallel

```bash
# ── Feature A: auth ───────────────────────────────────────────
cd ~/dev/my-project
wt-new feature/auth
# → automatic cd into the worktree + opencode launched
# → Ctrl-C to quit opencode
# → terminal in ~/dev/my-project-feature-auth

# ── Feature B: notifications (from another terminal) ──────────
cd ~/dev/my-project
wt-new feature/notifications
# → same, terminal in ~/dev/my-project-feature-notifications

# ── Cleanup after merge ────────────────────────────────────────
# (from the feature/auth worktree, PR merged)
wt-done   # → deletes worktree + branch + cd into ~/dev/my-project

# (from the feature/notifications worktree)
wt-done   # same
```

### Special case — fork from an in-progress feature

If `feature/notifications` depends on `feature/auth` (not yet merged into main):

```bash
# Option 1 — from anywhere, naming the source branch
wt-new feature/notifications --from feature/auth

# Option 2 — from the feature/auth worktree, with --from current
cd ~/dev/my-project-feature-auth
wt-new feature/notifications --from current
```

> `wt-new` creates the branch from `main` by default. Use `--from <branch>` to fork from any branch without moving.

---

## 12. Quick reference

### Agent table

| Agent | Mode | Color | Writes code | Bash | Use case |
|---|---|---|---|---|---|
| `orchestrator` | primary | Purple | Yes | Git read/write · utilities · uv/npm/… | Composite tasks, delegation |
| `build` | primary | — | Yes | Git read (auto) · rest (ask) | Direct implementation |
| `plan` | primary | — | No | No | Planning, exploration |
| `reviewer` | subagent | Blue | No | Git read · grep · cat · find | Code review |
| `debugger` | subagent | Red | No | Git read · grep · cat · find | Bug investigation |
| `tester` | subagent | Green | Yes | Git read · utilities · uv/npm/… | Test generation |
| `refactorer` | subagent | Orange | Yes | Git read · utilities · uv/npm/… | Refactoring |
| `docs-writer` | subagent | Dark blue | Yes (docs) | Git log/diff · ls · grep · cat · find | Documentation |
| `performance` | subagent | Amber | No | ls · grep · cat · find | Performance audit |
| `security` | subagent | Dark red | No | grep · ls · cat · find (read-only) | Security audit |
| `git-publisher` | subagent | Indigo | No | Git read/add/commit/push · glab · gh | Commit + MR/PR |

### Useful OpenCode commands

| Action | Command |
|---|---|
| Cycle between primary agents | **Tab** |
| Invoke a subagent | `@agent-name message` |
| Switch to Plan mode | **Tab** until "Plan" |
| Undo last changes | `/undo` |
| Redo | `/redo` |
| Initialize AGENTS.md | `/init` |
| Share a session | `/share` |
| List available models | `opencode models` (CLI) |

### Custom commands

| Command | Description |
|---|---|
| `/ticket <id> [context]` | Analyzes an existing ticket and its sub-tickets, produces an implementation plan |
| `/new-ticket <description>` | Creates a ticket (GitLab/GitHub/Jira) with pre-analysis and confirmation preview |
| `/check-agents` | Audits `AGENTS.md` vs the template, infers missing content, proposes and applies additions |

### Available shell helpers

| Command | Type | Source | Description |
|---|---|---|---|
| `agents-setup` | alias | `setup.sh` | Installs agents in the current project |
| `wt-new <branch> [--from <base>]` | **function** | `shell-functions.sh` | Creates a worktree + cd + opencode (base: `main` by default) |
| `wt-done` | **function** | `shell-functions.sh` | Cleans up the worktree + cd to the main repo |
| `wt-list` | alias | `git worktree list` | Lists all active worktrees |

> `wt-new` and `wt-done` are **shell functions** (not aliases) because they need to change the terminal's current directory. They are loaded via `source "$HOME/dev/agents/shell-functions.sh"` in `.bashrc` and `.zshrc`.

### Key files to fill in after `agents-setup`

| Priority | File | Required action |
|---|---|---|
| **Required** | `AGENTS.md` | Fill in `## Quality Checks` with the project's commands |
| **Required** | `AGENTS.md` | Fill in `## Tracker` with `tracker: gitlab\|github\|jira` |
| Recommended | `AGENTS.md` | Fill in Stack, Structure, Conventions |
| Recommended | `AGENTS.md` | Fill in `## Ticket conventions` if the defaults don't fit |
| Optional | `opencode.json` | Adjust bash permissions, add specific models |

> **Tip**: run `/check-agents` after `agents-setup` to automatically detect empty sections and let the agent infer content from the codebase.
