---
description: Create a ticket with pre-analysis and structured formatting. Detects the tracker from AGENTS.md, applies project conventions, shows a preview, and creates on confirmation.
---

# /new-ticket — Create a ticket

**Arguments:** $ARGUMENTS

**Rule: do not modify any file, do not create branches or commits.**

---

## Step 1 — Detect the tracker

Read `AGENTS.md` and look for a `## Tracker` section containing a `tracker:` key.

```
tracker: gitlab   → use glab
tracker: github   → use gh
tracker: jira     → use acli jira
```

If absent, fall back to the git remote:

```bash
git remote get-url origin
```

- Contains `github.com` → **GitHub** (gh)
- Contains `gitlab.com` or another GitLab host → **GitLab** (glab)
- Otherwise → **Jira** (acli)

---

## Step 2 — Load ticket conventions

Read `AGENTS.md` and look for a `## Ticket conventions` section.

If found, apply the conventions described there (title format, labels, description template, language).

If absent, apply these **defaults**:

| Field | Default |
|---|---|
| Language | English |
| Title format | `[Context] Verb + object` — e.g. `[Auth] Fix empty email validation` |
| Labels | `type::(feature\|bug\|tech\|chore)` + `size::(XS\|S\|M\|L\|XL)` + `priority::(critical\|high\|medium\|low)` + `status::todo` |
| Description template | **Context** / **Task** / **Acceptance criteria** / **Notes** |

Size guide: XS < 1h · S ≈ half-day · M ≈ 1 day · L ≈ 2-3 days · XL > 3 days (flag for splitting)

---

## Step 3 — Pre-analysis

Silently analyse `$ARGUMENTS` and the current codebase context to infer:

- **type** — feature / bug / tech / chore
- **size** — XS / S / M / L / XL
- **priority** — critical / high / medium / low
- **context** — the domain or module affected (for the title prefix)

Browse relevant files only if needed to understand the scope. Keep this step lightweight.

---

## Step 4 — Build the ticket

Apply the conventions from Step 2.

**Default title construction:**
```
[<Context>] <Verb> + <object>
```
Preferred verbs: Add, Fix, Implement, Refactor, Update, Remove, Handle

**Default description template (Markdown — used for preview and for GitLab/GitHub):**
```markdown
## Context
[1-2 sentences: why this task exists, what problem it solves]

## Task
[What needs to be done, derived from the request]

## Acceptance criteria
- [ ] [Main criterion]
- [ ] [Secondary criterion if obvious]

## Notes
[Technical constraints, dependencies, links — leave empty if none]
```

**If tracker = Jira:** also prepare an ADF version of the description (see Step 6). The preview in Step 5 still uses the Markdown version for readability; ADF is only used at creation time.

Do not invent criteria. Base everything on what was described in `$ARGUMENTS`. If the request is vague, keep criteria generic rather than guessing.

---

## Step 5 — Show preview and ask for confirmation

Display the formatted ticket:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Title    : <title>
  Tracker  : <gitlab|github|jira>
  Type     : <type>
  Size     : <size>
  Priority : <priority>
  Labels   : <labels if applicable>

  <full description>
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Create this ticket? [y/N]
```

Wait for the user's response. If they say no or request changes, adjust and show the preview again.

---

## Step 6 — Create the ticket

**GitLab (glab):**
```bash
glab issue create \
  --title "<title>" \
  --description "<description>" \
  --label "<labels>"
```

**GitHub (gh):**
```bash
gh issue create \
  --title "<title>" \
  --body "<description>" \
  --label "<labels>"
```

**Jira (acli):**

Use the canonical ADF template and workflow from `.opencode/skills/jira/SKILL.md`
(sections `## ADF — Atlassian Document Format` and `### Usage with --description-file`).
Fill the template with Context / Task / Acceptance criteria (one `taskItem` per criterion) / Notes,
write to a temp file, then call `acli jira workitem create --description-file ...`.

---

## Step 7 — Confirm

Display a short summary:

```
✓ Ticket created: #<id> — <title>
  <url>
```

If size is XL, add: "This ticket is large (XL) — consider splitting it into sub-issues."
