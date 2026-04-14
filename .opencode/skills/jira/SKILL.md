---
name: jira
description: Jira CLI (acli) reference — creating and managing Jira work items, transitions, searching, sprints, projects. Use whenever interacting with a Jira project: creating tickets, listing issues, changing status, viewing work item details. Trigger on any mention of Jira, acli, work item IDs matching the pattern [A-Z]+-\d+ (e.g. PROJ-42, BUG-123), sprint, or when AGENTS.md declares tracker: jira.
---

# Jira CLI — acli

`acli` requires a configured Jira connection (`acli auth`). Work item IDs follow the pattern `[A-Z]+-\d+` (e.g. `PROJ-42`).

## Work Items

```bash
acli jira workitem create \
  --summary "Title" \
  --project "PROJ" \
  --type "Task" \
  --description "Body text" \
  --assignee "user@example.com"    # or @me, or default
  --label "label1,label2"          # comma-separated
  --parent "PROJ-10"               # parent work item (for sub-tasks)

acli jira workitem view PROJ-42
acli jira workitem view PROJ-42 --json

acli jira workitem edit --key PROJ-42 --summary "New title"
acli jira workitem edit --key PROJ-42 --assignee "@me"
acli jira workitem edit --key PROJ-42 --labels "bug,urgent"

acli jira workitem assign --key PROJ-42 --assignee "user@example.com"
```

**Work item types** (value for `--type`): `Task`, `Bug`, `Story`, `Epic`, `Sub-task`

**Note on priority and components**: these fields have no dedicated CLI flags — use `--generate-json` to produce a JSON template, fill in the fields, then create with `--from-json`:
```bash
acli jira workitem create --generate-json          # generates workitem.json
acli jira workitem create --from-json workitem.json
```

## Search

```bash
acli jira workitem search --jql "project = PROJ AND status = 'Open'"
acli jira workitem search --jql "project = PROJ AND assignee = currentUser()"
acli jira workitem search --jql "project = PROJ AND sprint in openSprints()"
acli jira workitem search --jql "..." --limit 50 --paginate
acli jira workitem search --jql "..." --json
```

## Transitions (change status)

```bash
acli jira workitem transition --key PROJ-42 --status "Done" --yes
acli jira workitem transition --key PROJ-42 --status "In Progress"
acli jira workitem transition --jql "project = PROJ AND status = 'To Do'" --status "In Progress" --yes
```

**Common statuses**: `To Do`, `In Progress`, `In Review`, `Done`

## Comments

```bash
acli jira workitem comment create --key PROJ-42 --body "Comment text"
acli jira workitem comment list --key PROJ-42
```

## Projects

```bash
acli jira project list             # list accessible projects (default: 30)
acli jira project list --paginate  # fetch all projects
acli jira project view <KEY>
```

## Sprints & Boards

```bash
# Find boards
acli jira board search
acli jira board list-sprints --board <board-id>    # list sprints for a board

# List work items in a sprint
acli jira sprint list-workitems --board <board-id> --sprint <sprint-id>
acli jira sprint list-workitems --board <board-id> --sprint <sprint-id> \
  --jql "status != Done" --limit 100 --paginate
```

## Detecting Jira IDs

A string matching `[A-Z]+-\d+` (e.g. `PROJ-42`, `BUG-7`, `MYTEAM-123`) is a Jira work item key. Use it directly with `acli jira workitem view`.

## ADF — Atlassian Document Format

**Rule: always use ADF for Jira descriptions.** Jira does not render Markdown.
Pass the ADF JSON via `--description-file <file>` (preferred) or inline with `--description`.

### Node reference

| Node | Usage | Required attrs |
|---|---|---|
| `heading` | Section title | `attrs.level` (1–6) |
| `paragraph` | Plain text block | — |
| `bulletList` > `listItem` | Unordered list | — |
| `taskList` > `taskItem` | Checkbox item | `attrs.localId` (unique string), `attrs.state: "TODO"\|"DONE"` |
| `text` | Leaf text content | `text` |

### Template — Context / Task / Acceptance criteria / Notes

```json
{
  "version": 1,
  "type": "doc",
  "content": [
    {
      "type": "heading",
      "attrs": { "level": 2 },
      "content": [{ "type": "text", "text": "Context" }]
    },
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "Why this task exists." }]
    },
    {
      "type": "heading",
      "attrs": { "level": 2 },
      "content": [{ "type": "text", "text": "Task" }]
    },
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "What needs to be done." }]
    },
    {
      "type": "heading",
      "attrs": { "level": 2 },
      "content": [{ "type": "text", "text": "Acceptance criteria" }]
    },
    {
      "type": "taskList",
      "attrs": { "localId": "ac-list" },
      "content": [
        {
          "type": "taskItem",
          "attrs": { "localId": "ac-1", "state": "TODO" },
          "content": [{ "type": "text", "text": "Criterion 1" }]
        },
        {
          "type": "taskItem",
          "attrs": { "localId": "ac-2", "state": "TODO" },
          "content": [{ "type": "text", "text": "Criterion 2" }]
        }
      ]
    },
    {
      "type": "heading",
      "attrs": { "level": 2 },
      "content": [{ "type": "text", "text": "Notes" }]
    },
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "" }]
    }
  ]
}
```

### Usage with --description-file

```bash
cat > /tmp/jira-description.json << 'EOF'
{ ... ADF JSON ... }
EOF

acli jira workitem create \
  --project "PROJ" \
  --summary "Title" \
  --type "Task" \
  --description-file /tmp/jira-description.json

rm /tmp/jira-description.json
```

## Tips

- `acli jira --help` — full command reference
- `acli auth` — configure authentication
- `--json` flag available on most commands for parseable output
- `--jql` accepts any valid JQL expression: `project = PROJ AND sprint in openSprints() AND assignee = currentUser()`
