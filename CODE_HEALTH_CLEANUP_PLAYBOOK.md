# Agent-assisted code health and cleanup playbook

Status: approved process guidance. This document does not authorize a cleanup
implementation by itself. Begin with a read-only audit and obtain owner approval
before deleting or substantially simplifying working code.

## Why this exists

Car Fight has been developed through many AI-assisted experiments, bug fixes,
engine migrations, renderer investigations, and rejected approaches. That makes
it likely that some diagnostic code, superseded workarounds, duplicated helpers,
or unused paths remain after the actual solution was found.

The layer-by-layer clean-room reconstruction during the Godot 4.6 crash
investigation was useful. It exposed hidden dependencies, missing presentation
layers, shared-resource concerns, and ordinary integration defects. It also
proved that a broad rewrite can accidentally discard established gameplay or
months of carefully tuned networking work. The useful part of that exercise was
the incremental comparison and validation, not rewriting the product.

The goal now is continuous code health: make the repository easier for humans
and agents to understand while preserving the accepted Godot 4.7 game.

## Industry model

There is no single AI cleanup technique used everywhere. Mature workflows
combine several practices:

1. **Continuous technical-debt garbage collection.** OpenAI describes encoding
   repository-specific "golden principles" as mechanical rules, running
   recurring background agent scans, maintaining quality grades, and opening
   small targeted refactoring changes. This prevents agent-generated drift from
   compounding into periodic large rewrites.
2. **Repository-aware agent review.** GitHub's agentic review gathers full
   project context rather than reviewing one file in isolation. Repository
   instructions and task-specific skills provide architectural intent that code
   alone cannot express.
3. **Deterministic analysis beside AI judgment.** Linters, type checks, static
   analysis, structural rules, coverage, and dependency checks supply evidence
   independent of an agent's opinion. Google's Tricorder and Meta's Infer are
   examples of integrating incremental analysis directly into review.
4. **Automated removal only for mechanically proven stale patterns.** Uber's
   Piranha removes expired feature-flag branches through structural
   transformations. Its safety comes from starting with a known stale flag and
   applying explicit rewrite rules, not asking an agent to guess what looks old.
5. **Clean as You Code.** New and changed code is held to a strict quality gate
   while older debt is reduced gradually. This stops new debt without requiring
   an unsafe whole-project cleanup.
6. **Small, reversible refactors.** Google's engineering guidance recommends
   adding characterization tests before refactoring untested behavior, keeping
   refactors separate from features or bug fixes, and submitting one
   self-contained change at a time.
7. **Human validation.** AI review is an additional reviewer, not proof of
   correctness. GitHub explicitly warns that agent review can miss problems or
   make mistakes and should be validated by people.

Primary references:

- OpenAI, Harness engineering and "Entropy and garbage collection":
  <https://openai.com/index/harness-engineering/>
- GitHub, About Copilot code review:
  <https://docs.github.com/en/copilot/concepts/agents/code-review>
- Google, Tricorder program-analysis ecosystem:
  <https://research.google/pubs/tricorder-building-a-program-analysis-ecosystem/>
- Google, Small CLs and tests-before-refactoring guidance:
  <https://google.github.io/eng-practices/review/developer/small-cls.html>
- Meta, incremental Infer static analysis in code review:
  <https://engineering.fb.com/2015/06/11/developer-tools/open-sourcing-facebook-infer-identify-bugs-before-you-ship/>
- Uber, Piranha stale-code removal:
  <https://www.uber.com/us/en/blog/piranha/>
- Sonar, Clean as You Code:
  <https://docs.sonarsource.com/sonarqube-server/10.7/core-concepts/clean-as-you-code/overview>

## Required Car Fight workflow

### Phase 0: preserve the reference

- Start from clean, synchronized canonical `master`.
- Record the exact reference commit.
- Create a dedicated cleanup worktree/branch. Do not develop cleanup directly
  across multiple historical worktrees.
- Treat the current native and browser game as the behavioral reference.
- Read `GODOT_46_TO_47_HISTORY.md`, `AGENTS.md`, and `.ai/CURRENT_PHASE.md`.

### Phase 1: read-only audit

The first pass must not edit production code. Produce an evidence ledger that
classifies each finding as one of:

- definitely dead;
- obsolete diagnostic or failed workaround;
- duplicate implementation;
- excessive complexity with a behavior-equivalent simplification;
- potential correctness, security, or resource-lifecycle bug;
- possible performance problem requiring measurement;
- complicated but intentional;
- uncertain, therefore retained.

For every finding, record:

- exact files, symbols, scenes, resources, signals, or settings involved;
- every known reference and dynamic entry point;
- the Git commit or investigation that introduced it, where discoverable;
- what problem it attempted to solve;
- whether that solution was accepted, superseded, or disproven;
- concrete removal/simplification evidence;
- the shortest appropriate validation if it is changed;
- risk and rollback notes.

An agent may recommend a cleanup. It may not silently convert uncertainty into
permission to delete.

### Phase 2: owner review and ordering

Review the ledger with the owner before editing. Start with high-confidence,
low-risk material:

1. obsolete 4.6 crash diagnostics and abandoned renderer experiments;
2. launch/test helpers for worlds and modes that no longer exist;
3. comments, documents, flags, and settings contradicted by the current design;
4. duplicated presentation-only helpers;
5. gameplay internals with focused characterization coverage;
6. networking, rollback, transport, and state schema last and under the strictest
   evidence requirements.

Do not combine cleanup with new features, visual changes, balance changes,
engine changes, or bug fixes. If the audit discovers a real bug, report it and
handle its fix separately.

### Phase 3: one cleanup slice at a time

Each implementation commit should address one coherent finding or tightly
related group. Before editing:

- establish the behavior with an existing focused test or add a short
  characterization test;
- compare the current implementation with relevant historical code;
- resolve Godot's indirect references, not just textual call sites;
- define the expected diff and rollback point.

After editing:

- review the complete diff as if it came from another developer;
- run parse/static checks and the shortest relevant focused test;
- launch a short native or browser smoke only when presentation/runtime behavior
  is involved;
- ask for human validation when feel, appearance, or cross-client behavior is
  material;
- commit the accepted slice independently.

Do not run the long gate suite after every cleanup. Reserve broad or extended
tests for accumulated high-risk boundaries, release checkpoints, or explicit
owner requests.

### Phase 4: independent review

A second review pass should try to disprove the cleanup rather than merely agree
with it. It should check:

- missed dynamic Godot references;
- scene/resource paths and exported properties;
- signals, groups, autoloads, reflection, string-based calls, and RPCs;
- native ENet and browser WebRTC differences;
- server-only, client-only, reconnect, and late-join paths;
- assumptions that exist only in an agent's narrative and not in code/tests;
- accidental packet, state schema, authority, physics, or timing changes.

Only deterministic checks and observed behavior can turn an agent's suggestion
into evidence.

## Godot-specific deletion rules

Text search alone cannot prove that Godot code or an asset is unused. Before
deletion, check:

- `.tscn`, `.tres`, `.godot`, import metadata, and script preloads/loads;
- scene inheritance, node paths, exported resources, signals, groups, and
  autoloads;
- `Callable`, `call`, `get`, `set`, string names, and dynamically constructed
  resource paths;
- RPC annotations, multiplayer authority paths, transport-specific code, and
  synchronized state fields;
- headless/server paths that rendered tests do not execute;
- optional local assets and clean-checkout fallback behavior.

If a resource is expensive or unavailable, lack of execution in one smoke test
is not evidence that it is dead.

## Protected behavior

Cleanup is not authorization to redesign:

- server authority or ownership;
- ENet, WebRTC, mux, reconnect, late join, or rollback behavior;
- vendored netfox fixes;
- synchronized packet/state layout, including dormant fields retained for
  compatibility;
- FOLLOW mouse controls, physics feel, collision, weapons, tractor, ball,
  defenses, damage response, or presentation timing;
- Godot 4.7.1, Rapier 0.8.39, Compatibility rendering, Intel lighting policy,
  or the ordinary-window safety policy.

Complicated networking code is not presumed waste. It must be understood
against its history and focused multi-platform tests before modification.

## Cleanup is not optimization

Removing dead code and consolidating helpers can improve maintainability,
build/import time, and sometimes runtime cost. It does not automatically improve
FPS, latency, memory, or network corrections.

Performance work begins with a measured baseline and a named bottleneck:

- frame CPU/GPU time, FPS distribution, draw calls, shader stalls;
- physics time and object counts;
- memory/resource loading;
- server tick time;
- bandwidth, correction magnitude, latency, and rollback behavior.

An optimization is accepted only when the same measurement improves without a
behavior regression. A shorter implementation without measurements is a
cleanup, not a proven optimization.

## Definition of success

The cleanup campaign succeeds when:

- obsolete experiments are removed with evidence;
- current architecture and historical exceptions are easier to discover;
- new agent sessions cannot mistake old plans for current authorization;
- repeated patterns become mechanically enforceable rules where practical;
- each accepted change is small and reversible;
- gameplay, networking, browser/native cross-play, visuals, and Intel stability
  remain unchanged unless the owner explicitly approves a change;
- future work produces less cleanup debt than it removes.

