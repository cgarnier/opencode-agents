---
name: glab
description: GitLab CLI (glab) reference — issues, merge requests, pipelines, CI logs, labels, milestones. Use whenever interacting with a GitLab project: creating or listing issues, opening MRs, checking pipeline status, reading build logs, listing labels or milestones. Trigger on any mention of glab, GitLab, issue gitlab, MR, merge request, pipeline, CI, build logs, or whenever the git remote points to a GitLab host.
---

# GitLab CLI — glab

`glab` auto-detects the project from the `origin` remote of the current git repo.

## Issues

```bash
glab issue create \
  --title "<title>" \
  --description "<body>" \
  --label "<label1>,<label2>" \
  --milestone "<milestone-title>" \
  --assignee "<username>"          # omit to leave unassigned

glab issue list                    # open issues
glab issue list --all              # all issues
glab issue list --assignee=@me
glab issue list --label="bug"
glab issue list --milestone="Sprint 3"
glab issue view <id>
glab issue view <id> --comments
glab issue close <id>
glab issue reopen <id>
```

## Labels

```bash
glab label list                    # list all labels in the project
```

## Milestones

```bash
glab milestone list                # list all milestones
```

## Merge Requests

```bash
glab mr create \
  --title "<title>" \
  --description "<body>" \
  --source-branch <branch> \
  --target-branch main \
  --label "<label>" \
  --assignee "<username>"

glab mr list                       # open MRs
glab mr list --all
glab mr view <id>
glab mr view <id> --comments       # MR + all comments (-c)
glab mr view <id> --comments --unresolved  # unresolved threads only
glab mr diff <id>
glab mr checkout <id>              # switch to the MR branch locally
glab mr merge <id>
glab mr close <id>
```

## Pipelines & CI

```bash
glab ci list                       # recent pipelines on current branch
glab ci list --ref <branch>        # pipelines for a specific branch
glab ci list --status failed       # filter by status: running|pending|success|failed|canceled|skipped

glab ci status                     # status of the latest pipeline (current branch)
glab ci status --branch <branch>   # status for a specific branch
glab ci status --live              # refresh in real time until pipeline ends
glab ci status --compact           # compact single-line format

glab ci view                       # interactive TUI — view, run, trace, cancel jobs

glab ci trace                      # stream logs interactively (job picker)
glab ci trace <job-id>             # stream logs of a specific job by ID
glab ci trace <job-name>           # stream logs of a specific job by name

glab ci retry <job-id>             # retry a specific job by ID
glab ci retry <job-name>           # retry a specific job by name
glab ci retry                      # interactive job picker

glab ci cancel pipeline <id>       # cancel a running pipeline
glab ci cancel job <id>            # cancel a running job
```

### Get logs of a specific job (non-interactive, via API)

```bash
PROJECT_ID=$(glab repo view --output json | jq -r '.id')

# List jobs for the latest pipeline
PIPELINE_ID=$(glab ci list --output json | jq -r '.[0].id')
glab api "projects/$PROJECT_ID/pipelines/$PIPELINE_ID/jobs" | jq '.[].{id, name, status}'

# Fetch job log
glab api "projects/$PROJECT_ID/jobs/<job-id>/trace"
```

## Repo

```bash
glab repo view                     # project info
glab repo view --output json       # machine-readable
glab repo clone <namespace>/<repo>
```

## Tips

- Append `--output json` to most commands for parseable output
- `glab auth status` — verify authentication
- `glab <command> --help` — full options for any subcommand
