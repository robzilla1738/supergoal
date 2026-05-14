# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.1] — 2026-05-14

Public-release readiness pass. Honest install + honest dispatch.

### Fixed

- **Stage 7 dispatch is now correct.** Previously SKILL.md instructed the planning agent to print `/goal "..."` as its final text output, expecting the host to auto-fire it. Slash commands fire only from user input on both Claude Code and Codex, so the autonomous-execution claim was structurally broken. Stage 7 now prints a clearly fenced, ready-to-paste `/goal` block with a one-line instruction telling the user to paste it. One paste between Stage 6 confirmation and full autonomous execution.
- **Plugin install now actually works.** Added `.claude-plugin/marketplace.json` so the plugin can be installed via the Claude Code marketplace command sequence: `/plugin marketplace add robzilla1738/superplan` → `/plugin install superplan@superplan` → `/reload-plugins`. The previous README assumed marketplace registration that hadn't been done.
- **Codex install path is now explicit.** Removed the dead `.codex-plugin/` directory (Codex CLI has no plugin system; the file was silently ignored). README's Codex section now contains the actual clone-and-copy commands to `~/.codex/skills/superplan/`.

### Changed

- `SKILL.md` description, one-shot summary, Stage 6 confirmation copy, and revision-menu option labels all updated to reflect the user-paste dispatch model.
- `references/goal-format.md`: "Superplan's single-`/goal` shape" section clarified to state that dispatch is user-initiated by paste, not agent-initiated.
- `README.md`: rewritten install sections for both Claude Code (marketplace flow + manual fallback) and Codex (manual clone-and-copy). Use walkthrough's Stage 7 description aligned with the new dispatch mechanic.
- `.claude-plugin/plugin.json`: description aligned with new dispatch language, version bumped 0.4.0 → 0.4.1.

### Removed

- `.codex-plugin/plugin.json` and the surrounding `.codex-plugin/` directory (Codex has no plugin manifest convention).
- Stray `.DS_Store` files from `skills/superplan/`.

## [0.4.0] — 2026-05-14

Initial single-`/goal` redesign. Adaptive phase count, memory preload + writeback, tool discovery, 3-strike self-healing recovery. Internal release; see v0.4.1 for the first public-ready cut.
