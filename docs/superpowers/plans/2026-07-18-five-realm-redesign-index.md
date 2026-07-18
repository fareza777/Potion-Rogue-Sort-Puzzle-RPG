# Five-Realm Redesign Execution Index

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Execute each linked plan task-by-task with RED/GREEN/REFACTOR discipline.

**Goal:** Deliver the approved five-realm Potion Rogue redesign as version 1.2.0/code 13, including two new realms, exactly fifteen new enemies, all ten audit recommendations, stronger visuals, meaningful meta systems, reliable audio, and a verified Android APK no larger than 70 MiB.

**Specification:** `docs/superpowers/specs/2026-07-18-five-realm-production-redesign.md`

## Ordered Slices

1. `docs/superpowers/plans/2026-07-18-engine-foundation.md`
   Establish solver-backed boards, deterministic balance simulation, runtime-aware generation, content validation, transactional saves, and a decomposed battle coordinator.
2. `docs/superpowers/plans/2026-07-18-five-realm-content.md`
   Add Frostbound Reliquary, Abyssal Apothecary, their route grammars, seven Frost enemies, eight Abyss enemies, bosses, mechanics, images, and realm music.
3. `docs/superpowers/plans/2026-07-18-meta-audio-truth.md`
   Make Ascension, Mastery, Daily, history, build/reward copy, Hall navigation, settings, and screen-aware audio truthful and persistent.
4. `docs/superpowers/plans/2026-07-18-visual-runtime-release.md`
   Consolidate the design system, improve accessibility and battle motion, curate exports, add perceptual/runtime gates, and ship the APK.

## Dependency Rules

- Slice B begins only after Slice A's schema, save, solver, and coordinator gates pass.
- Slice C may begin after Slice A; it must consume normalized content and audio identifiers from Slice B before its gate is closed.
- Slice D starts component migration after Slice A and performs final captures only after Slices B and C pass.
- Every production change begins with a failing automated test or approved failing visual baseline.
- Existing user changes in `DESIGN-IS-2026-07-17/05-recommendations.md` and `.codex-remote-attachments/` remain untouched.

## Final Acceptance Gate

- Five ordered realms load, unlock, save, resume, and complete without migration loss.
- Total enemy roster is 42, with exactly the fifteen approved new IDs and one inspected full-body sprite per new enemy.
- Board generation, routes, enemy mutations, bosses, event outcomes, audio routing, and settings are deterministic under a fixed seed/snapshot.
- All test scenes, long simulations, content validation, screenshot baselines, runtime budgets, and `git diff --check` pass.
- Android smoke tests cover cold launch, all five realm paths, exact battle resume, abandon/continue, interruption recovery, accessibility settings, Daily, and both new bosses.
- `builds/PotionRogue-v13-debug.apk` reports version 1.2.0/code 13, has valid v2/v3 signatures, is at most 70 MiB, and has a recorded SHA-256.
