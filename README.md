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
copier copy https://github.com/MrJuancho/webstack-agent-harness.git my-new-project
cd my-new-project
just setup
```

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

There's no meta-test suite beyond this (what `gauntlet-template` has, with its own
`pyproject.toml`/`pytest` at the root) — `verify-template.sh` is a fast mechanism-level
check, not full coverage. Worth building if this template starts changing often enough
for that gap to matter; see `docs/progress.md` for current status.
