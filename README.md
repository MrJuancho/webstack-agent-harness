# webstack-agent-harness

A [Copier](https://copier.readthedocs.io/) template that scaffolds a fail-closed
engineering harness for TypeScript/Fastify/Drizzle projects built by autonomous coding
agents: 8 verification gates, 4 layers of enforcement, Claude Code subagents, and a
spec-kit workflow, ready on `copier copy`.

This repo is the **template**, not a runnable project — there's no `package.json` or
`justfile` at this level. Everything a generated project gets lives under
[`template/`](./template/); this root only holds the things about *maintaining the
template itself*: [`copier.yml`](./copier.yml), [`docs/adr/`](./docs/adr/) (decisions
about the harness's own design), and [`docs/progress.md`](./docs/progress.md) (session
handoff for whoever is working on the template).

## Generate a new project

```bash
uv tool install copier   # or: pipx install copier
copier copy --vcs-ref main https://github.com/MrJuancho/webstack-agent-harness.git my-new-project
cd my-new-project
just setup
```

**Always pass `--vcs-ref` explicitly — don't rely on the default.** Without it, Copier
uses the *latest git tag* if this repo has one, not `main`. This repo has no tags right
now, so today omitting `--vcs-ref` happens to also land on `main` — but that's an
accident of the current state, not a guarantee: this bit a real user once, when two
stale tags from early in this repo's history silently shadowed months of fixes with no
warning (see `docs/progress.md` and `template/scripts/doctor.sh`'s template-provenance
check, which exists because of that incident). If/when this repo starts cutting tagged
releases — the normal, desirable state for a template people build on — pin to the tag
you actually want (`--vcs-ref v1.2.3`) for a real project, and use `--vcs-ref main` for
anything you're just trying out. Never delete a tag to "fix" this once it's been used —
anyone who already generated against it loses `copier update`'s base reference, which
is a real, not hypothetical, way to break someone else's project.

You'll be asked for `project_name` (human title), `package_name` (kebab-case slug,
defaults from `project_name`), `db_name` (defaults from `package_name`), and
`github_owner` (defaults to `MrJuancho`).

## Pull in template improvements later

Any fix or improvement made here (a corrected hook, a new gate, a hardened default)
can be pulled into an already-generated project without redoing it by hand:

```bash
cd my-existing-project
copier update
```

Copier re-applies the template on top of the project's current state, using the
answers recorded in `.copier-answers.yml` at generation time. Project-specific edits to
templated files may produce a merge conflict you resolve like a normal git conflict;
`docs/progress.md` is explicitly protected (`_skip_if_exists` in `copier.yml`) and is
never touched by an update.

## Why a template instead of a plain clone

This started as a plain repo, cloned per project (see
[`docs/adr/0002-instanciacion-clon-no-template.md`](./docs/adr/0002-instanciacion-clon-no-template.md)
for that original decision and why it changed) — every improvement had to be
manually ported into every project that already existed. Converting to Copier trades
that manual step for the templating machinery above: `{{ variable }}` substitution,
`.jinja`-suffixed files, and `copier update`'s ability to diff-and-reapply.

One deliberate exception: `template/justfile` is **not** `.jinja`-suffixed. `just`'s own
recipe syntax uses `{{ }}` for parameters (see `review-start BRANCH="HEAD":` and its
`{{BRANCH}}`), which collides with Jinja's default delimiters — rendering it as a
template would try to resolve `{{BRANCH}}` as a missing Copier variable and fail. It's
copied literally instead, and its one real substitution (`__DB_NAME__`) is resolved with
`sed` in `copier.yml`'s `_tasks`, after copying. The Docker Compose project name is
*not* hardcoded this way — it comes from `COMPOSE_PROJECT_NAME` in `.env.local`, derived
per-worktree by `scripts/worktree-env.sh` (see "Running parallel worktrees" in the
generated project's own README for why).

## Workflow: this repo requires PRs, generated projects don't

`main` is branch-protected: every change needs a PR with a green `verify-template.sh`
check (enforced for the owner too, no bypass) before it can merge — `git push origin
main` directly will be rejected. This is deliberate and specific to *this* repo, not
inherited by projects generated from it (those default to direct-push-to-main, matching
`template/AGENTS.md.jinja`'s Generator role). The two-command flow:

```bash
git checkout -b fix/whatever
git commit -am "..." && git push origin fix/whatever
gh pr create --base main --head fix/whatever --title "..." --body "..."
# wait for the verify-template.sh check, then:
gh pr merge --squash --delete-branch
```

## Maintaining this template

[`scripts/verify-template.sh`](./scripts/verify-template.sh) runs a real `copier copy`
against the current working tree (including uncommitted changes) and checks for the
specific regressions this template has actually hit: a failed copy, a missing `.git/`
in the output, leftover unrendered `{{ }}` Jinja markers, or a stray `webstack`
reference that should have been generalized. It does **not** install dependencies or
run the example app's own `just gauntlet` — that needs Docker and a few minutes, too
slow for every turn or every commit. See
[`docs/adr/0003-migracion-a-copier-template.md`](./docs/adr/0003-migracion-a-copier-template.md)
for why it's built this way (a plain local `copier copy` against this repo's own
`.git` turned out to *not* reliably reflect uncommitted edits — it copies to a
git-free scratch directory first specifically to avoid that).

To install the git pre-commit hook (runs `verify-template.sh` before every commit):

```bash
cp scripts/hooks/pre-commit.sh .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

Claude Code agent hooks (`.claude/settings.json`) mirror the same idea: `PreToolUse`
still blocks writes to `template/tests/holdout/` and `template/.holdout.sha256`
(unmodified — the existing guard matches on path substring, so it already covers the
new location), and `Stop` runs `verify-template.sh` before a turn can end. Both were
added after `.claude/` had already moved into `template/` mid-session, so — unlike an
edit to an existing settings file, which hot-reloads — a session needs to be
**restarted** to pick up a settings.json that didn't exist at session start.

`verify-template.sh` is deliberately a fast mechanism-level check, not full coverage —
and that gap already cost a real regression once: it passed green on a working tree
where the generated project's own `just setup` failed against real Docker (worktree
isolation env vars never resolved in time, a Postgres wait that didn't actually wait,
`db-reset` silently reusing a previous run's container). `verify-template.sh` cannot
catch that class of bug by design — it never installs dependencies or touches Docker.

[`scripts/verify-e2e.sh`](./scripts/verify-e2e.sh) closes that gap: unlike
`verify-template.sh` (which copies the local working tree), it clones this repo's real
remote with `copier copy` and **no `--vcs-ref`** — exactly what a user following this
README gets — then runs `just setup && just gauntlet-full` against real Docker and real
Postgres, and asserts on the actual consumer: the generated project's `.copier-answers.yml`
`_commit` matches the template's real remote `HEAD` (this is what would have caught the
stale-tag incident above — a working-tree-based check structurally can't), `.env.local`
exists after setup, the running container's name carries the worktree hash, no generated
file has a literal `5432` that isn't tied to `PG_PORT`. It's slow on purpose (network +
Docker + a full gauntlet, several minutes), so it doesn't run on every push/PR like
`verify-template.sh` does — see
[`.github/workflows/verify-e2e.yml`](./.github/workflows/verify-e2e.yml) (scheduled
daily + manual dispatch) instead.
