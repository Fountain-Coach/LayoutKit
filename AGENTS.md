AGENTS.md — LayoutKit Engineering Guide

Scope
- Applies to files under this repository.
- Goal: Keep the engine spec‑first, deterministic, and backend‑agnostic.

Mission
- Provide a portable vector display list (`Scene`) built from spec inputs (PageSpec/SystemSpec/Style/TextRun), rendered by pluggable Canvases.
- Keep layout logic explicit and testable; keep painting mechanical.

Non‑Goals (v0)
- Full editor UI; HTTP service; advanced text shaping in this repo (SDLKit provides shaping).

Architecture
- Model: `PageSpec`, `Insets`, `Path`, `TextRun`, `Glyph`, `Style`, `Command`, `Scene`.
- Engine: `LayoutEngine` (in‑process) for deterministic page/system assembly.
- Canvas protocol: `Canvas` with `save/restore/transform/drawPath/drawText`.
- Backends live outside: SDLKitCanvas (SDL + FreeType + HarfBuzz), CoreGraphicsCanvas, SVG/PDF emitters.

Conventions
- Coordinates: page `pt`, y‑up; staff `SP`. See `COORDINATES.md`.
- Determinism: stable ordering of commands; avoid hidden randomness.
- Errors: no `fatalError` in library; bubble typed errors.
- Logging: structured, silenced in release.
- Doc comments: public APIs documented with examples when possible.

Testing Strategy
- Unit tests: engine determinism, simple path/text rendering, JSON round‑trip for `Scene`.
- Snapshot tests: SVG strings for small scenes (CI‑diffable).

Performance Targets
- Engine: small scenes in < 1 ms; A4 page stub in < 5 ms on M‑class Macs.

Milestones
- M0 Bootstrap: SPM scaffolding, core types, COORDINATES, OpenAPI stub, minimal engine + SVG canvas, tests.
- M1 Backends: SDLKitCanvas + CoreGraphicsCanvas adapters (in respective repos), Teatro plugin.
- M2 ScoreKit integration: PageSpec/SystemSpec from ScoreKit; symbol runs (SMuFL) in SP; benchmarks + snapshots.

Definition of Done (per feature)
- API documented; tests cover basic functionality; deterministic outputs; minimal docs updated.

