<!--
Sync Impact Report
- Version change: [TEMPLATE] → 1.0.0 (initial ratification)
- Modified principles: n/a (first concrete draft, replacing bracketed placeholders)
- Added sections: Core Principles (I-V), Technology & Environment Constraints,
  Enforcement & Roles, Governance
- Removed sections: none
- Derived from: AGENTS.md, justfile, .claude/settings.json, .github/workflows/ci.yml
  (existing repo state as of 2026-09-16); no prior constitution existed.
- Follow-up TODOs: none — all placeholders resolved from repo context.
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
   `Stop` blocks ending a turn while `gauntlet-fast` is red.
2. **Git pre-commit** (`scripts/hooks/pre-commit.sh`, installed via `just install-hooks`):
   runs `gauntlet-fast` before any local commit. It MUST be installed by `just setup` on
   every fresh clone — it is not assumed to already exist.
3. **CI** (`.github/workflows/ci.yml`): runs `just doctor` then `just gauntlet-full` on
   every push/PR against `main`, in a clean container with no agent-local state.
4. **Branch protection**: `main` requires the CI check green before merge. This layer is
   configured in GitHub settings, not in code, and MUST be periodically confirmed active.

Two operational roles keep concurrent work isolated: **Generator** works at the repo
root on a feature branch, running `gauntlet-fast` continuously and committing only on a
green `gauntlet`. **Reviewer** never inspects code in the Generator's working tree — it
uses `just review-start <branch>` to get an isolated git worktree, and `just
review-clean` to tear it down.

## Governance

This constitution defines the *why*; `AGENTS.md` defines the *how* (exact commands, gate
descriptions, and the operational checklist an agent follows turn-to-turn). Where the
two conflict, this constitution takes precedence and `AGENTS.md` MUST be updated to
match.

Amendments follow semantic versioning: MAJOR for a removed or redefined principle,
MINOR for a new principle or materially expanded section, PATCH for wording or
clarification only. Every amendment MUST update `AGENTS.md` and the spec doc
(`docs/webstack-agent-harness-spec.html`, regenerated via `scripts/generate-pdf.sh`) in
the same change if it affects gates, tiers, or enforcement layers, so the three
documents never drift from each other or from the code.

**Version**: 1.0.0 | **Ratified**: 2026-09-12 | **Last Amended**: 2026-09-16
