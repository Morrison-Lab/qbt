# Branch rulesets

Each JSON file here is a GitHub branch ruleset exported from the template's
canonical configuration. Apply them to a new repo (after creating it from
the template) with:

```sh
.github/scripts/apply-rulesets.sh                 # current repo
.github/scripts/apply-rulesets.sh owner/repo      # explicit target
```

The script is idempotent - re-running it updates a ruleset in place when
one with the same `name` already exists, rather than creating a duplicate.

Requirements:

- `gh` CLI authenticated as a repo admin (org or user). Branch rulesets
  require admin scope to create.
- `jq` available on PATH.

## What's enforced (`main.json`)

Applies to the default branch:

- **Required PR before merging** - no direct pushes to `main`. Note that
  `required_approving_review_count` is `0`: a PR is required, but **zero
  approvals** are needed, so authors can self-merge. This enforces process
  (PR + status checks) but not peer review. Raise this value if you want to
  require approvals before merge.
- **Required status checks** (not strict - branch does not need to be up
  to date): `check / link-checker`, `Spellcheck`, `check / check-chars`,
  and `build-deploy`. The `build-deploy`
  context is produced by `preview.yml` on PRs (publish.yml only runs on
  push-to-main, so it can't satisfy this); if you rename either job, the
  ruleset gate will hang. `preview.yml` renders in a `build` job and writes
  to `gh-pages` in a separate `deploy` job, so `build-deploy` is now a small
  aggregator job that reports both of their results under the name the
  ruleset requires. It fails when either dependency is anything other than
  `success`, because GitHub counts a *skipped* required check as satisfied.
  `check-links.yml` is intentionally excluded - it checks external URLs,
  which can fail due to transient network issues or link rot unrelated to
  the PR. Requiring it as a merge gate would block merges on external
  failures outside the PR author's control.
- **No force-pushes, no branch deletion.**
- **Bypass** in `pull_request` mode for the Maintain role (role id 2) -
  Maintainers can merge via a PR they authored, but cannot push directly.

## Editing the ruleset

Edit `main.json` here, then run `apply-rulesets.sh` to push the change to
the live repo. Or edit in the GitHub UI (Settings → Rules → Rulesets) and
re-export with:

```sh
# Find the ruleset ID:
RULESET_ID=$(gh api repos/OWNER/REPO/rulesets | jq '.[] | select(.name == "main") | .id')

gh api "repos/OWNER/REPO/rulesets/$RULESET_ID" \
  | jq 'del(.id, .node_id, .source, .source_type, .created_at, .updated_at, ._links, .current_user_can_bypass)' \
  > .github/rulesets/main.json
```

The fields stripped by `jq del(...)` are server-assigned and would either
be ignored or rejected by the create/update endpoints.
