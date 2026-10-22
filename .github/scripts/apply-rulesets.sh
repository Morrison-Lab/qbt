#!/usr/bin/env bash
# Apply branch rulesets from .github/rulesets/*.json to the current repo.
# Run once after creating a new repo from this template. Idempotent: a
# ruleset whose `name` already exists on the repo is updated in place rather
# than duplicated.
#
# Requires: gh CLI authenticated with admin access to the repo.
# Usage:    .github/scripts/apply-rulesets.sh [owner/repo]
#           Defaults to the gh-detected current repo.

# "protect-default-branch" is the shared base ruleset's name in
# Morrison-Lab/ai-config; it counts as the same ruleset, so a repo that has
# it is updated in place rather than given a second one,
# unless the repo also has a ruleset named like the example, which wins.
set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo "error: jq is required but not found" >&2; exit 1; }
command -v gh >/dev/null 2>&1 || { echo "error: gh is required but not found" >&2; exit 1; }

repo="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
ruleset_dir="$(cd "$(dirname "$0")/../rulesets" && pwd)"

shopt -s nullglob
files=("$ruleset_dir"/*.json)
if [ ${#files[@]} -eq 0 ]; then
  echo "no rulesets found in $ruleset_dir" >&2
  exit 0
fi

# Map of existing ruleset name -> id, so we can PUT updates instead of
# creating duplicates.
existing=$(gh api --paginate "repos/$repo/rulesets" | jq -s '[.[][] | {name, id}]')

for f in "${files[@]}"; do
  name=$(jq -r .name "$f")
  if [ -z "$name" ] || [ "$name" = "null" ]; then
    echo "skipping $f: missing .name field" >&2
    continue
  fi
  id=$(jq -r --arg n "$name" '(map(select(.name == $n)) + map(select(.name == "protect-default-branch"))) | .[0].id // empty' <<<"$existing")
  if [ -n "$id" ]; then
    echo "updating ruleset '$name' (id $id) on $repo"
    gh api -X PUT "repos/$repo/rulesets/$id" --input "$f" >/dev/null
  else
    echo "creating ruleset '$name' on $repo"
    gh api -X POST "repos/$repo/rulesets" --input "$f" >/dev/null
  fi
done

echo "done."
