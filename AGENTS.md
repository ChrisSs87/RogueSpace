# AGENTS.md — RogueSpace Multi-AI Workflow

This repository is the shared source of truth for RogueSpace. All AI agents and human contributors must follow these rules.

## 1. Source of truth
- `main` is the stable, reviewed baseline.
- Read `RogueSpace_CURRENT_State_UPDATED.md` before proposing or making changes.
- Read `RogueSpace_CORE_Design_UPDATED.md` when a task affects game design, architecture, progression, or project-wide contracts.
- Do not use an older ZIP, Drive copy, chat attachment, or remembered state as authority when it conflicts with the repository.

## 2. Never develop directly on main
- Create one branch per task.
- Suggested names: `codex/<task>`, `claude/<task>`, `gemini/<task>`, `chatgpt/<task>`.
- Do not merge to `main` merely because code compiles or a static review looks correct.
- Integration into `main` happens only after review and the validation appropriate to the task.

## 3. One owner per active task
- Every task must have a clearly defined scope and owner.
- Parallel work is encouraged only when scopes do not overlap.
- Before editing, identify the files/systems expected to change.
- If another active task touches the same system or files, STOP and report the conflict instead of independently solving it.
- Do not opportunistically refactor unrelated code.

## 4. CLOSED / PASS systems are contracts
- Anything marked CLOSED / PASS in CURRENT State is considered protected.
- Do not redesign, refactor, retune, or “clean up” protected systems unless:
  1. the assigned task explicitly requires it, or
  2. a reproducible regression demonstrates that the contract is broken.
- If a protected system appears to be the cause of a new issue, diagnose first and report evidence before modifying it.

## 5. Minimal-change policy
- Prefer data/Resource changes over new code when existing architecture supports the requirement.
- Prefer localized changes over new parallel systems.
- Preserve deterministic generation and existing data-driven contracts.
- Do not increase retries/backtracking/limits merely to hide a feasibility problem unless the task explicitly approves that tradeoff.
- Do not replace generic infrastructure with archetype-specific hacks without explicit approval.

## 6. Diagnosis before surgery
For bugs, regressions, or experiential problems:
1. reproduce or inspect;
2. identify the actual responsible layer;
3. state the smallest proposed change;
4. assess affected contracts/regressions;
5. only then implement if the task authorizes implementation.

If the task says READ-ONLY / DIAGNOSIS ONLY, do not edit files, create fixes, or silently implement suggestions.

## 7. Validation levels
Use the cheapest level that can genuinely prove the claim:
- Static review: data/code consistency, architecture, references.
- Automated harness/regression: deterministic logic and integration contracts.
- Godot runtime: physical generation, navigation, scenes, runtime behavior.
- Manual TEST MOBILE: player experience and Android/Cardboard-facing behavior.

Do not claim experiential closure from automated tests alone.
Do not claim runtime certification if the agent cannot run Godot.

## 8. STOP policy
- Do not chain speculative fixes.
- If the first localized fix exposes a second independent problem, STOP and report it unless the task explicitly authorizes continued debugging.
- If required information or tooling is unavailable, state the limitation instead of inventing a result.

## 9. Procedural-generation rules
- Fortress6A is a stable regression greybox; do not alter it for procedural experiments.
- Preserve Navigation B+C contracts unless demonstrated incompatible.
- Preserve archetype identity: Ship, Varkhen Base, and Horvex Nest must not converge toward one generic topology.
- Structural/topological problems should be solved at the logical/semantic layer before changing physical module sizes or adding assembler hacks, unless evidence shows the physical layer is responsible.
- Seed reproducibility is required for procedural changes.

## 10. Deliverables
Every implementation task should report:
- branch name;
- files changed;
- reason for each change;
- tests/harnesses run and exact result;
- known risks or unverified behavior;
- whether manual mobile testing is still required.

Every diagnosis-only task should report:
- responsible layer;
- evidence;
- exact files/functions/properties involved;
- minimal recommended change;
- regression risks;
- proposed validation;
- no code changes.

## 11. Documentation
- Update `RogueSpace_CURRENT_State_UPDATED.md` only when the task materially changes official project state or a certification is completed.
- Do not rewrite historical results to make a new change look cleaner.
- Keep design intent in `RogueSpace_CORE_Design_UPDATED.md`; keep implementation/certification state in CURRENT State.
- If a task is experimental or not yet accepted, document it in the branch/PR rather than declaring it official in `main`.

## 12. Pull-request handoff
Before requesting integration:
- rebase/update from current `main` when appropriate;
- review the diff for unrelated changes;
- provide concise validation evidence;
- identify any overlap with other active branches;
- leave the branch unmerged for review.

## 13. Current coordination model
Typical roles, not permanent ownership:
- Human/user: product direction, manual experience feedback, final design decisions.
- ChatGPT: technical coordination, cross-agent review, repository/diff/PR review, task decomposition.
- Claude: diagnosis/refinement and localized proposals when useful.
- Gemini: independent static analysis, audits, design/data review when useful.
- Codex: implementation, integration, Godot/harness execution and certification when available.

Roles may change per task. Repository contracts do not.
