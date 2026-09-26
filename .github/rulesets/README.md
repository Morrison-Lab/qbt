# Branch rulesets

Each JSON file here is a GitHub branch ruleset matching the template's
canonical configuration, with one deliberate exception recorded under
[Editing the ruleset](#editing-the-ruleset) below.
Apply them to a new repo, after creating it from the template, with:

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

- **Extra approval for unattributed changes.**
  `require_extra_approval_for_unattributed_changes` is `true`, so the
  zero-approval rule above stops applying to a commit GitHub cannot
  attribute to an account.
  That distinction matters in this repo, which merges agent-authored work:
  an attributed commit can be self-merged, an unattributed one cannot.

- **Required status checks** (not strict - branch does not need to be up
  to date): `check / link-checker`, `Spellcheck`, `check / check-chars`,
  and `build-deploy`.
  The `build-deploy` context is produced by `preview.yml` on PRs
  (publish.yml only runs on push-to-main, so it can't satisfy this).
  If you rename either job, the ruleset gate will hang.
  `preview.yml` renders in a `build` job and writes to `gh-pages` in a
  separate `deploy` job, so `build-deploy` is now a small aggregator job
  that reports both of their results under the name the ruleset requires.
  It fails when either dependency is anything other than `success`,
  because GitHub counts a *skipped* required check as satisfied.

- **`check / link-checker` is required, deliberately.**
  An earlier version of this file recorded it as deliberately *excluded*,
  because it fetches external URLs and so can fail from transient network
  trouble or link rot that has nothing to do with the PR.
  That failure mode is real, but the run history shows it has never blocked
  a merge.
  Of 138 recorded runs, 4 failed.
  Two were scheduled sweeps of `main` (2026-03-30 and 2026-06-29), which is
  link rot surfacing exactly where it should, on a schedule rather than on
  someone's PR.
  The other two were on the branch that built the check itself, in January
  2026.
  So none of the 81 pull-request runs failed for an unrelated reason, and
  nothing has failed since the gate was added on 2026-09-14.
  If that changes, remove the context from the live ruleset and re-export,
  rather than editing this file alone; the role bypass below covers a
  one-off bad run in the meantime.

- **No force-pushes, no branch deletion.**

- **Bypass** in `pull_request` mode for repository role id `5`.
  A holder can merge a PR they authored past a failing gate, but still
  cannot push directly to `main`.
  Earlier versions of this file granted bypass to role id `2`, labelled here
  as Maintain, which was broader than what the live ruleset actually grants.
  Role ids are not self-documenting, so confirm the label under
  Settings -> Rules if you are changing who can bypass.

## Editing the ruleset

Edit `main.json` here, then run `apply-rulesets.sh` to push the change to
the live repo.
Or edit in the GitHub UI (Settings -> Rules -> Rulesets) and re-export with:

```sh
# Find the ruleset ID:
RULESET_ID=$(gh api repos/OWNER/REPO/rulesets | jq '.[] | select(.name == "main") | .id')

gh api "repos/OWNER/REPO/rulesets/$RULESET_ID" \
  | jq 'del(.id, .node_id, .source, .source_type, .created_at, .updated_at, ._links, .current_user_can_bypass)
        | .bypass_actors |= map(select(.actor_type != "OrganizationAdmin"))' \
  > .github/rulesets/main.json
```

The fields stripped by `jq del(...)` are server-assigned and would either
be ignored or rejected by the create/update endpoints.

The `bypass_actors` filter is the deliberate exception, and a re-export that
leaves it out will reintroduce a bug.
The live ruleset grants bypass to `OrganizationAdmin`, an actor type that
exists only for an organization-owned repo.
This template is meant to be usable from a personal account, where that
actor has no counterpart, so carrying it in the export would make the
template's own main use case depend on an actor the target repo cannot have.

Because the export is deliberately not a verbatim copy, it can drift from
the live ruleset without anyone noticing.
That is what #67 was: the export had fallen four fields behind, including a
bypass role and a required check, and reading this file gave a weaker
picture of the policy than the one in force.
