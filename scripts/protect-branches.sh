#!/usr/bin/env bash
set -euo pipefail

# Provision GitHub branch protection using REST API v3.
# Usage:
#   export GITHUB_TOKEN=<PAT with admin:repo_hook, repo>
#   ./scripts/protect-branches.sh kakashi3lite Encorely main,develop
#
# Optional fourth arg: comma-separated required status check contexts
#   ./scripts/protect-branches.sh <owner> <repo> <branches> "Swift 6 CI / SwiftPM Build & Test,CodeQL / Analyze (Swift)"

OWNER=${1:-}
REPO=${2:-}
BRANCHES_CSV=${3:-main}
CONTEXTS_CSV=${4:-}

if [[ -z "${OWNER}" || -z "${REPO}" ]]; then
  echo "Usage: $0 <owner> <repo> <branches_csv> [contexts_csv]" >&2
  exit 1
fi

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "GITHUB_TOKEN env var is required (PAT with admin:repo_hook, repo)." >&2
  exit 1
fi

IFS=',' read -r -a BRANCHES <<< "${BRANCHES_CSV}"

# Build JSON array for contexts
CONTEXTS_JSON="[]"
if [[ -n "${CONTEXTS_CSV}" ]]; then
  CONTEXTS_JSON="[\n$(echo "${CONTEXTS_CSV}" | awk -F, '{for(i=1;i<=NF;i++){gsub(/^ +| +$/,"",$i); printf "  \"%s\"%s\n", $i, (i<NF?",":"")}}') ]"
fi

BASE_URL="https://api.github.com"
AUTH_HEADER="Authorization: token ${GITHUB_TOKEN}"
JSON_HEADER="Accept: application/vnd.github+json"

for BR in "${BRANCHES[@]}"; do
  echo "Protecting ${OWNER}/${REPO}@${BR}..."

  read -r -d '' BODY <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": ${CONTEXTS_JSON}
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "block_creations": false,
  "required_linear_history": true,
  "required_conversation_resolution": true
}
EOF

  curl -sS -X PUT \
    -H "${AUTH_HEADER}" \
    -H "${JSON_HEADER}" \
    -H "Content-Type: application/json" \
    -d "${BODY}" \
    "${BASE_URL}/repos/${OWNER}/${REPO}/branches/${BR}/protection" \
    | sed -e 's/.*/[protection] &/'

  # Enable required signatures (if supported for the repo)
  curl -sS -X POST \
    -H "${AUTH_HEADER}" \
    -H "${JSON_HEADER}" \
    "${BASE_URL}/repos/${OWNER}/${REPO}/branches/${BR}/protection/required_signatures" \
    | sed -e 's/.*/[signatures] &/' || true

  echo "Done: ${BR}"
done

echo "All requested branches processed."

