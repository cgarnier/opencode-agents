---
name: gh
description: GitHub CLI (gh) reference — issues, pull requests, Actions CI logs, labels, milestones. Use whenever interacting with a GitHub project: creating or listing issues, opening PRs, checking workflow/run status, reading job logs, listing labels. Trigger on any mention of gh, GitHub, issue github, PR, pull request, GitHub Actions, workflow run, or whenever the git remote points to github.com.
---

# GitHub CLI — gh

`gh` auto-detects the repo from the `origin` remote of the current git repo.

## Issues

```bash
gh issue create \
  --title "<title>" \
  --body "<description>" \
  --label "<label1>,<label2>" \
  --milestone "<milestone-title>" \
  --assignee "<username>"          # omit to leave unassigned

gh issue list                      # open issues
gh issue list --state all
gh issue list --assignee @me
gh issue list --label "bug"
gh issue list --milestone "Sprint 3"
gh issue view <id>
gh issue view <id> --comments
gh issue close <id>
gh issue reopen <id>
```

## Labels

```bash
gh label list                      # list all labels in the repo
```

## Milestones

```bash
gh api repos/{owner}/{repo}/milestones | jq '.[].title'
```

## Pull Requests

```bash
gh pr create \
  --title "<title>" \
  --body "<description>" \
  --base main \
  --head <branch> \
  --label "<label>" \
  --assignee "<username>"

gh pr list                         # open PRs
gh pr list --state all
gh pr view <id>
gh pr view <id> --comments
gh pr diff <id>
gh pr checkout <id>                # switch to the PR branch locally
gh pr merge <id> --squash
gh pr close <id>
gh pr review <id> --approve
gh pr review <id> --request-changes --body "<comment>"
```

## Actions — Workflow Runs

```bash
gh run list                        # recent workflow runs
gh run list --workflow <filename>  # filter by workflow file
gh run view <run-id>               # summary of a run
gh run view <run-id> --log         # full logs of all jobs
gh run view <run-id> --log-failed  # logs of failed jobs only
gh run watch <run-id>              # stream a run in progress
gh run cancel <run-id>
gh run rerun <run-id>
gh run rerun <run-id> --failed     # rerun only failed jobs
```

### Logs of a specific job

```bash
gh run view <run-id> --job <job-id> --log
# List job IDs:
gh run view <run-id> --json jobs --jq '.jobs[].databaseId'
```

## Repo

```bash
gh repo view                       # project info
gh repo view --json name,url,description
```

## Tips

- Append `--json <fields>` for machine-readable output, then pipe to `jq`
- `gh auth status` — verify authentication
- `gh <command> --help` — full options for any subcommand
