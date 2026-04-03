---
description: Audit AGENTS.md against the template, detect missing or empty sections, infer content from the codebase, and propose additions.
---

# /check-agents — Audit AGENTS.md

**Rule: do not modify any file until the user confirms.**

---

## Step 1 — Locate the template

Resolve the `.opencode/` symlink to find the agents repo root:

```bash
OPENCODE_REAL=$(readlink -f .opencode)
TEMPLATE="$(dirname "$OPENCODE_REAL")/AGENTS.md.template"
```

If `AGENTS.md` is missing from the project root → stop and say:
> "No AGENTS.md found in this project. Run `bash ~/dev/agents/setup.sh` first."

If the template file is not found at the resolved path → stop and say:
> "AGENTS.md.template not found at `$TEMPLATE`. Is .opencode/ correctly symlinked?"

---

## Step 2 — Extract sections from both files

Read `AGENTS.md` (project) and `AGENTS.md.template`.

Extract all `## Heading` sections from each file.

**Template sections (canonical order):**
1. Stack
2. Structure
3. Commands
4. Quality Checks
5. Conventions
6. Tracker
7. Ticket conventions
8. Notes

---

## Step 3 — Classify each template section

For each section in the template, determine its status in the project's `AGENTS.md`:

| Status | Condition |
|---|---|
| `✓ OK` | Section exists and contains non-comment, non-placeholder content |
| `~ Empty` | Section exists but body is empty, or contains only `<!-- ... -->` comments, or only lines matching `<...>` placeholders |
| `✗ Missing` | Section heading is absent from AGENTS.md |

Also collect sections present in AGENTS.md but **not** in the template → mark as `→ Project-specific`.

A section with real content means at least one non-empty, non-comment line under the heading before the next `##`.

---

## Step 4 — Infer content for `~ Empty` and `✗ Missing` sections

For each section that needs content, explore the project silently:

### Stack
Look for: `package.json` (check `dependencies`, `devDependencies`), `go.mod`, `Gemfile`, `pyproject.toml`, `Cargo.toml`, `pom.xml`, `build.gradle`, `composer.json`.
Infer the main language, framework, and runtime.

### Structure
Run:
```bash
ls -1
```
List top-level dirs and their apparent roles. If `src/` exists, list one level deeper.

### Commands
Check `package.json` → `scripts`, `Makefile`, `justfile`, `Taskfile.yml`.
Extract dev, install, start, build commands.

### Quality Checks
Same sources as Commands. Look for lint, test, format, typecheck, build scripts.
Map them to the format:
```
- test: <cmd>
- lint: <cmd>
- format: <cmd>
- typecheck: <cmd>
- build: <cmd>
```
Only include lines where a command was actually found. Omit lines with no match.

### Conventions
Read config files: `.eslintrc*`, `.prettierrc*`, `tsconfig.json`, `pyproject.toml` (ruff/black sections), `.rubocop.yml`, `biome.json`.
Infer 2-4 key conventions (naming, exports, error handling, commit style).

### Tracker
See **Step 5** — interactive detection.

### Ticket conventions
Leave as minimal placeholder if Tracker is being set up for the first time:
```
<!-- See /new-ticket for defaults -->
```

### Notes
Leave empty (no placeholder invented — better to have nothing than noise).

---

## Step 5 — Tracker: detect, confirm, correct

### Detection

1. If `## Tracker` is already filled in `AGENTS.md` → skip this step entirely (status is `✓ OK`).
2. Otherwise, run:
```bash
git remote get-url origin 2>/dev/null
```
- Contains `github.com` → suggest `github`
- Contains `gitlab.com` or another GitLab host → suggest `gitlab`
- No match or no remote → no suggestion

### Confirmation (always ask, even when a value was detected)

If a value was detected:
```
Tracker detected: github  (from git remote)
Is this correct? [Y/n]
```

If the user confirms → use the detected value.

If the user says no, or if nothing was detected:
```
Which tracker does this project use?
  1. github
  2. gitlab
  3. jira
  4. other (I'll type it)
```

If the user picks **jira**, also ask:
```
Jira project key? (e.g. PROJ, BUG, MYAPP)
```
Store the key for use in the Ticket conventions section if that section is also missing/empty.

### Output
Build the `## Tracker` section content:
```
tracker: <value>
```

---

## Step 6 — Display the audit report and proposed additions

Show the full report:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  AGENTS.md — Audit

  ✓ Stack
  ✓ Commands
  ~ Quality Checks        (empty)
  ✗ Tracker               (missing)
  → Purpose               (project-specific, kept as-is)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

If there are no `~` or `✗` sections → print:
```
✓ AGENTS.md is complete — nothing to add.
```
And stop.

Otherwise, show each proposed addition:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Proposed additions
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

## Quality Checks
- test: npm test
- lint: npm run lint
- format: npm run format

## Tracker
tracker: github

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Apply these additions to AGENTS.md? [y/N]
```

Wait for the user's response.
- If **no**: stop, nothing is written.
- If the user requests changes to a specific section: adjust and show the preview again.
- If **yes**: proceed to Step 7.

---

## Step 7 — Apply additions to AGENTS.md

For each section to add or fill:

- If `✗ Missing`: append the section at the end of AGENTS.md (or insert it in template order if possible).
- If `~ Empty`: replace the existing empty section body with the proposed content. **Never touch the heading line or surrounding sections.**

Rules:
- Never overwrite content that was already there.
- Never remove existing `<!-- comments -->` if the section had some — append content below them.
- Preserve all other sections exactly as they are.

After writing, confirm:

```
✓ AGENTS.md updated — 2 section(s) added/filled.
```
