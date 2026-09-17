<!--
Sync Impact Report
- Version change: 1.0.0 → 1.1.0
- Modified principles: none renamed/removed
- Added sections: Core Principles VI (Slice Discipline: Budget by Tokens, Not Clock
  Time); Enforcement & Roles expanded with PostToolUse fast-feedback hook and the
  fail-closed/fail-open classification; Governance expanded to cover docs/adr/ and
  docs/progress.md
- Removed sections: none
- Derived from: this session's live-verified fix of the PreToolUse/Stop exit-code bug
  (docs/adr/0001), the new generator/reviewer subagents (.claude/agents/), and
  gauntlet-template's ADR-0002 (token budget, not clock time) adapted to this stack.
- Follow-up TODOs: none.
-->

# Webstack Agent Harness Constitution

## Core Principles

### I. Fail-Closed by Default (NON-NEGOTIABLE)
If a required tool is missing, a check cannot run, or a script exits non-zero, the
pipeline MUST abort immediately. Success is never assumed by omission — an agent or
script that cannot verify a condition MUST treat that as failure, not as permission to
proceed. This is enforced by `just doctor` (missing tooling) and by every gate script's
`set -euo pipefail` + explicit exit-code checks.

### II. Layered Verification
Verification MUST run at the tier matched to its cost, coordinated through the
`justfile`: `gauntlet-fast` (<5s, every file edit — typecheck, lint, unit tests,
staged-secret scan) → `gauntlet` (<30s, before every commit — architecture isolation,
schema drift, reversible migrations, auth matrix, N+1 detection) → `gauntlet-full`
(<3min, before merge — property tests, contract fuzzing, seed determinism, hold-outs,
diff mutation) → `audit` (scheduled — full-domain mutation). A change MUST NOT be
considered complete until the tier appropriate to its stage exits 0.

### III. Domain/Infra/HTTP Isolation
`src/domain` MUST NOT import from `src/infra` or `src/http`; `src/infra` MUST NOT import
from `src/http`. This is mechanically enforced by `dependency-cruiser`
(`.dependency-cruiser.js`) as part of `just gauntlet`, not left to code review. Business
logic stays testable and swappable independent of the database or HTTP framework.

### IV. Deterministic & Reversible Data
Every schema change MUST ship with both an up and a down migration, and rolling both
back MUST leave zero DDL residue (Gate 1). Seed data MUST be reproducible byte-for-byte
across runs — no `Date.now()`, no random UUIDs, no wall-clock timestamps (Gate 7). A
schema edit without a regenerated migration is schema drift and MUST fail the pipeline
(Gate 2).

### V. Anti-Tampering on Security Invariants
`tests/holdout/` and its `.holdout.sha256` signature are read-only to any agent. An
agent MUST NOT weaken, delete, or work around a hold-out assertion to force a pass; the
`PreToolUse` hook MUST block writes to these paths, and the signature check MUST fail
closed on any byte-level change (Gate 5). Only a human, via `just seal-holdouts`, may
update the signature after a deliberate, reviewed change to that suite.

### VI. Slice Discipline: Budget by Tokens, Not Clock Time
A task statement that, read literally, implies more than one red test is not one task —
it is several, and MUST be split (via `/speckit-plan`/`/speckit-tasks`) before work
starts, not mid-session once the context budget is already spent. The real budget of an
agent session is tokens consumed, not wall-clock time; a short-looking task that hides
several unsplit slices can exhaust a session's entire budget while a properly sliced
multi-session feature costs a fraction of it. Each slice MUST close with a green `just
gauntlet` before the next one starts — an unfinished slice is not deferred debt, it is
an unfinished slice.

## Technology & Environment Constraints

Stack: Node.js 22 LTS, TypeScript 5, Fastify 5 + TypeBox + Swagger, Drizzle ORM,
PostgreSQL 16 (tmpfs-backed, ephemeral by design), Vitest, Stryker Mutator, fast-check,
Schemathesis, Gitleaks, `just` as the task runner. Target environment is WSL2/Linux with
Docker Compose; the compose project is unified under the name `webstack-agent-harness`
so `db-up`/`db-down`/`db-reset` never collide with other local stacks. Every endpoint
registered in `src/http/app.ts` MUST declare a TypeBox schema, including its `401`
contract if it requires auth, or explicit `config: { isPublic: true }` if it does not
(Gate 3, Gate 4).

## Enforcement & Roles

Enforcement is layered and independent — no single disabled layer removes the others:
1. **Agent hooks** (`.claude/settings.json`): `PreToolUse` blocks hold-out tampering;
   `Stop` blocks ending a turn while `gauntlet-fast` is red; `PostToolUse` gives fast
   ESLint feedback per edited file. Security hooks (`PreToolUse`, `Stop`) MUST fail
   CLOSED (exit 2 on Claude Code, the only code that blocks those events); convenience
   hooks (`PostToolUse`) MUST fail OPEN — a missing dependency silences feedback, it
   never blocks an edit that already happened. See `AGENTS.md` for the full
   classification table and `docs/adr/0001-hooks-de-seguridad-usan-exit-2.md` for the
   incident that established this rule.
2. **Git pre-commit** (`scripts/hooks/pre-commit.sh`, installed via `just install-hooks`):
   runs `gauntlet-fast` before any local commit. It MUST be installed by `just setup` on
   every fresh clone — it is not assumed to already exist.
3. **CI** (`.github/workflows/ci.yml`): runs `just doctor` then `just gauntlet-full` on
   every push/PR against `main`, in a clean container with no agent-local state.
4. **Branch protection**: `main` requires the CI check green before merge. This layer is
   configured in GitHub settings, not in code, and MUST be periodically confirmed active.

Two operational roles keep concurrent work isolated, codified as Claude Code subagents
in `.claude/agents/`: **Generator** (`generator.md`) is the only role with `Edit`/`Write`
— it works at the repo root on a feature branch, running `gauntlet-fast` continuously
and committing only on a green `gauntlet`. **Reviewer** (`reviewer.md`) has no
`Edit`/`Write` and never inspects code in the Generator's working tree while it may be
changing — it uses `just review-start <branch>` to get an isolated git worktree, and
`just review-clean` to tear it down. A Reviewer invocation MUST receive only the diff
(a commit range, `git diff`, or file paths), never the conversation that produced it —
a reviewer that inherits the author's context inherits the author's blind spots.

## Governance

This constitution defines the *why*; `AGENTS.md` defines the *how* (exact commands, gate
descriptions, and the operational checklist an agent follows turn-to-turn);
`docs/progress.md` defines *where things stand right now* (overwritten each session,
never accumulated); `docs/adr/` defines *why a specific decision was made*, dated and
immutable once accepted. Where the constitution and `AGENTS.md` conflict, this
constitution takes precedence and `AGENTS.md` MUST be updated to match.

Amendments follow semantic versioning: MAJOR for a removed or redefined principle,
MINOR for a new principle or materially expanded section, PATCH for wording or
clarification only. Every amendment MUST update `AGENTS.md` and the spec doc
(`docs/webstack-agent-harness-spec.html`, regenerated via `scripts/generate-pdf.sh`) in
the same change if it affects gates, tiers, or enforcement layers, so the documents
never drift from each other or from the code. A decision significant enough to need its
own rationale and consequences — not just a rule — gets an ADR in `docs/adr/` instead of
(or in addition to) a constitution edit.

**Version**: 1.1.0 | **Ratified**: 2026-09-12 | **Last Amended**: 2026-09-16
