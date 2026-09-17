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
copied literally instead, and its two real substitutions (`__PACKAGE_NAME__`,
`__DB_NAME__`) are resolved with `sed` in `copier.yml`'s `_tasks`, after copying.

## What's deliberately not here yet

There's no automated test suite verifying the template mechanism itself (that
`copier copy` reliably produces a project where `just gauntlet` passes) — verified
manually once per change instead. If this template starts changing often enough for
that manual check to become a bottleneck, that's worth revisiting; see
`docs/progress.md` for current status.
