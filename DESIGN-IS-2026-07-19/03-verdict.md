# Verdict — REDESIGN

The project needs a **targeted systemic redesign**, not an art reset: preserve the dark-fantasy assets, solver-safe puzzle core, five-realm content, and exact-resume foundation, but rebuild the layout, information, runtime, and progression systems around one coherent mobile contract.

Highest-leverage moves:

1. **Principles #2/#3/#10 — Responsive hierarchy:** replace fixed-width area/map geometry with viewport- and grammar-driven layout; consolidate type, spacing, color, and touch tokens. Evidence: `01-evidence.md` §§3, 8, 10.
2. **Principles #7/#9 — Runtime architecture:** split the 1,122-line battle screen; coalesce main-thread saves; lazy-load audio; pool FX and cache generated textures. Evidence: `01-evidence.md` §§7, 9.
3. **Principles #2/#6/#8 — Correct system contracts:** route every hazard through one validated board-command API, repair corruption intent, and add production-wiring/latency/frame-budget tests in CI. Evidence: `01-evidence.md` §§6, 8.
4. **Principles #1/#2/#4 — Deeper procedural runs:** use actual HP/build/repetition context and a serialized run RNG; turn Daily, Ascension, Mastery, events, and build synergies into authored systems. Evidence: `01-evidence.md` “Engine and feature inventory.”
5. **Principles #3/#5/#9 — Purposeful presentation:** give realms/enemies authored visual/audio identities, remove duplicate navigation and idle redraw, and make reduced-motion/accessibility settings comprehensive. Evidence: `01-evidence.md` §§3, 5, 8, 9.

