# Branch Protection Automation

This repo includes a script and a GitHub Actions workflow to provision branch protection via the GitHub API.

## Options

1) Run locally via script (admin PAT)
- Generate a fine-scoped PAT with `repo` and `admin:repo_hook` (or `repo` + `admin:repo` if available).
- Export it as an env var (do not commit):
  `export GITHUB_TOKEN=ghp_XXXXXXXXXXXXXXXXXXXX`
- Execute for main+develop:
  `bash scripts/protect-branches.sh kakashi3lite Encorely main,develop "Swift 6 CI / SwiftPM Build & Test,CodeQL / Analyze (Swift)"`

2) Run in GitHub Actions (recommended)
- Add a repo secret `ADMIN_TOKEN` with the PAT above.
- Trigger the workflow: Actions > Protect Branches > Run workflow.
- Optionally pass custom branch list and required status contexts.

## Defaults Enforced
- Required PR reviews (1 approval), code owners, dismiss stale, last-push approval
- Required linear history and conversation resolution
- Enforce for admins, no force pushes, no deletions
- Strict up-to-date merges; optional required status checks contexts
- Attempt to enable required signatures (if supported on the repo)

See `.github/workflows/protect-branches.yml` and `scripts/protect-branches.sh`.

