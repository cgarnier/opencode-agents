---
name: confluence
description: Confluence CLI (acli) reference — reading pages and spaces. Use whenever interacting with Confluence: viewing a page, browsing spaces, reading content or hierarchy. Trigger on any mention of confluence, page confluence, lire une page, espace confluence, wiki, acli confluence, or page ID.
---

# Confluence CLI — acli

`acli` requires a configured Confluence connection (`acli auth`).

**Note:** `acli confluence page` is **read-only** — only `view` is available (no `create`, `list`, or `search`).
To create or update pages, use the Confluence REST API directly — acli does not support it.

## Pages

```bash
# View a page by ID
acli confluence page view --id 123456789

# View with rendered content (most readable)
acli confluence page view --id 123456789 --body-format view

# View raw XHTML content
acli confluence page view --id 123456789 --body-format storage

# View ADF (Atlassian Document Format) JSON
acli confluence page view --id 123456789 --body-format atlas_doc_format

# View with JSON output (combine with --body-format to get content)
acli confluence page view --id 123456789 --body-format view --json

# View with direct child pages (navigate hierarchy)
acli confluence page view --id 123456789 --include-direct-children

# View with labels and version info
acli confluence page view --id 123456789 --include-labels --include-version

# View a specific version
acli confluence page view --id 123456789 --version 3

# View draft version
acli confluence page view --id 123456789 --get-draft
```

### `--body-format` options

| Value | Description |
|---|---|
| *(omitted)* | Metadata only — no page content returned |
| `view` | Rendered HTML — most readable for humans |
| `storage` | Raw XHTML — useful for parsing/processing |
| `atlas_doc_format` | ADF JSON — structured document format |

### `--include-*` flags

| Flag | What it adds |
|---|---|
| `--include-direct-children` | List of direct child pages |
| `--include-labels` | Tags/labels on the page |
| `--include-version` | Detailed version object (author, date) |
| `--include-versions` | Full version history |
| `--include-collaborators` | Contributors info |
| `--include-properties` | Content properties |
| `--include-operations` | Allowed operations (permissions check) |
| `--include-likes` | Reactions and likes |

## Spaces

```bash
# List all accessible spaces
acli confluence space list

# Filter by type or status
acli confluence space list --type global
acli confluence space list --type personal
acli confluence space list --status archived

# Filter by specific space keys
acli confluence space list --keys "PROJ,DEV,OPS"

# List with expanded info
acli confluence space list --expand description,homepage
acli confluence space list --expand description,homepage,permissions

# JSON output, increase limit
acli confluence space list --json --limit 100

# View a specific space by ID
acli confluence space view --id 123456
acli confluence space view --id 123456 --json

# View with all details (icon, labels, permissions, operations, properties)
acli confluence space view --id 123456 --include-all

# View with selected details
acli confluence space view --id 123456 --labels --permissions

# View description in plain text or rendered HTML
acli confluence space view --id 123456 --desc-format plain   # values: plain, view
```

### `space list --expand` values

| Value | Description |
|---|---|
| `description` | Space description |
| `homepage` | Homepage page ID and title |
| `permissions` | Space-level permissions |

## Common Patterns

### Browse all pages in a space

```bash
# Step 1 — find the space and its homepage ID
acli confluence space list --expand homepage --json

# Step 2 — view the homepage and its direct children
acli confluence page view --id <homepage-id> --include-direct-children --json

# Step 3 — drill into a child page
acli confluence page view --id <child-id> --body-format view --include-direct-children
```

### Read a page's content

```bash
# Human-readable (rendered HTML)
acli confluence page view --id 123456789 --body-format view --json

# For parsing/processing (raw XHTML)
acli confluence page view --id 123456789 --body-format storage --json
```

## Tips

- `--json` is available on all commands — use it for programmatic processing
- `acli auth` — configure authentication (run once per environment)
- `acli confluence --help` — full command reference
- Space **key** (e.g. `PROJ`) ≠ Space **ID** (numeric) — `space list --json` to find IDs
- `--keys` on `space list` accepts a comma-separated string: `--keys "PROJ,DEV,OPS"`
