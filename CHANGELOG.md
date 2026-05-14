# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] — 2026-05-14

Renamed `superplan` → `supergoal` end-to-end. The skill produces a `/goal`, so the name now points at the central primitive. Breaking change for anyone who had v0.4.x installed: uninstall the old marketplace + plugin, then re-add at the new name.

### Changed

- **Repo:** `github.com/robzilla1738/superplan` → `github.com/robzilla1738/supergoal` (GitHub auto-redirects old URLs).
- **Plugin name:** `superplan` → `supergoal`. Install command is now `/plugin install supergoal@supergoal`.
- **Marketplace name:** `superplan` → `supergoal`. Re-add with `/plugin marketplace add https://github.com/robzilla1738/supergoal.git`.
- **Slash command:** `/superplan` → `/supergoal`.
- **Skill dir:** `skills/superplan/` → `skills/supergoal/`.
- **Artifact dir in user projects:** `.superplan/` → `.supergoal/`.
- **Transcript markers:** `SUPERPLAN_PHASE_START` / `_VERIFY` / `_DONE` / `_RUN_COMPLETE` → `SUPERGOAL_*`.
- **Env vars in scripts:** `$SUPERPLAN_DIR` / `$SUPERPLAN_ROOT` → `$SUPERGOAL_*`.
- **All copy and Mermaid diagrams** in README updated to the new name.

### Migration

```text
/plugin uninstall superplan@superplan
/plugin marketplace remove superplan
/plugin marketplace add https://github.com/robzilla1738/supergoal.git
/plugin install supergoal@supergoal
/reload-plugins
```

For Codex: `rm -rf ~/.codex/skills/superplan` and re-clone per the new README.

## [0.4.1] — 2026-05-14

Public-release readiness pass. Honest install + honest dispatch.

### Fixed

- **Stage 7 dispatch is now correct.** Previously SKILL.md instructed the planning agent to print `/goal "..."` as its final text output, expecting the host to auto-fire it. Slash commands fire only from user input on both Claude Code and Codex, so the autonomous-execution claim was structurally broken. Stage 7 now prints a clearly fenced, ready-to-paste `/goal` block with a one-line instruction telling the user to paste it. One paste between Stage 6 confirmation and full autonomous execution.
- **Plugin install now actually works** (end-to-end verified against the live GitHub repo with `claude plugin install supergoal@supergoal` returning `Successfully installed plugin: supergoal@supergoal (scope: user)`). Added `.claude-plugin/marketplace.json` so the plugin can be installed via the Claude Code marketplace command sequence: `/plugin marketplace add https://github.com/robzilla1738/supergoal.git` → `/plugin install supergoal@supergoal` → `/reload-plugins`. The README's `owner/repo` shorthand is documented with a note that it requires GitHub SSH keys, falling back to the HTTPS URL otherwise.
- **Codex install path is now explicit.** Removed the dead `.codex-plugin/` directory (Codex CLI has no plugin system; the file was silently ignored). README's Codex section now contains the actual clone-and-copy commands to `~/.codex/skills/supergoal/`.

### Changed

- `SKILL.md` description, one-shot summary, Stage 6 confirmation copy, and revision-menu option labels all updated to reflect the user-paste dispatch model.
- `references/goal-format.md`: "Supergoal's single-`/goal` shape" section clarified to state that dispatch is user-initiated by paste, not agent-initiated.
- `README.md`: rewritten install sections for both Claude Code (marketplace flow + manual fallback) and Codex (manual clone-and-copy). Use walkthrough's Stage 7 description aligned with the new dispatch mechanic.
- `.claude-plugin/plugin.json`: description aligned with new dispatch language, version bumped 0.4.0 → 0.4.1.

### Removed

- `.codex-plugin/plugin.json` and the surrounding `.codex-plugin/` directory (Codex has no plugin manifest convention).
- Stray `.DS_Store` files from `skills/supergoal/`.

## [0.4.0] — 2026-05-14

Initial single-`/goal` redesign. Adaptive phase count, memory preload + writeback, tool discovery, 3-strike self-healing recovery. Internal release; see v0.4.1 for the first public-ready cut.
