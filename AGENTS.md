# AGENTS.md

Authoritative project doc. Any agent (Claude, Codex, or other) opening this repo should be able to read this file alone and understand the project, where to make changes, and what conventions to follow.

## What this repo is

**Supergoal** is a Claude Code / Codex skill that turns a vague build request into a deeply-planned, autonomously-executed `/goal` run with built-in retry, fix-spec recovery, per-phase memory writeback, and a final audit pass that re-validates the work against the original plan.

- Slash command: `/supergoal <task>`
- Central mechanism: produces one ready-to-paste `/goal` command. The user pastes it once; the rest is autonomous.
- Works on: Claude Code (via plugin marketplace) and Codex CLI (via manual skill copy).
- Public install: see `README.md`.

## Repo layout

```
supergoal/
├── .claude-plugin/
│   ├── marketplace.json        Catalog Claude Code reads when added as a marketplace
│   └── plugin.json             Plugin manifest (name, version, description, skills path)
├── .gitattributes              Forces `*.sh` to LF (CRLF shebangs fail on a fresh Windows checkout).
├── .gitignore                  Editor/OS junk + .supergoal/ artifact dirs
├── AGENTS.md                   This file. Authoritative project doc.
├── CLAUDE.md                   Claude Code-specific tips. Points at this file.
├── CHANGELOG.md                Per-version release notes. Keep-a-Changelog format, SemVer.
├── LICENSE                     MIT.
├── README.md                   Public-facing: what it is, install, use, Mermaid flow charts.
├── skills/supergoal/
│   ├── SKILL.md                The skill itself. ~565 lines (grew with v0.7's Stage 0 namespace-claim section; the phase-loop section duplicates PROTOCOL.md and is a candidate for slimming next release).
│   ├── references/             Progressive-disclosure docs the agent reads when needed.
│   │   ├── planning-depth.md          What makes a plan deserve "super".
│   │   ├── phase-design.md            How to slice phases (adaptive count, no cap).
│   │   ├── goal-format.md             /goal mechanics on both hosts; required transcript blocks.
│   │   └── repo-state-comparison.md   The one comparison strategy (complete working tree vs baseline).
│   ├── scripts/                Bash scripts the planner/executor run during stages.
│   │   ├── detect-env.sh       Greenfield env recon.
│   │   ├── detect-stack.sh     Brownfield stack/framework detection.
│   │   ├── summarize-repo.sh   Compressed repo map.
│   │   ├── claim-run.sh        Atomically claims a unique per-run dir under .supergoal/ (concurrent-run isolation). Tested by tests/claim-run.test.sh.
│   │   ├── repo-state.sh       Complete working-tree-vs-baseline comparison (audit + cleanliness). Copied into the run's .supergoal/<run-id>/ dir at Stage 7.
│   │   └── validate-phase.sh   Sanity-checks a phase spec has required markers.
│   └── templates/              Files the planner copies into a run's `.supergoal/<run-id>/` dir.
│       ├── ROADMAP.md          Phase plan with dependencies.
│       ├── STATE.md            Live progress file.
│       ├── phase-goal.txt      Phase spec skeleton (work, criteria, evidence, commands).
│       └── PROTOCOL.md         Execution loop + failure recovery + final audit protocol.
└── tests/                      Repo-only (not shipped in the plugin payload).
    ├── claim-run.test.sh       Fixture tests for claim-run.sh (incl. the concurrent-claim race).
    └── repo-state.test.sh      Fixture tests for repo-state.sh over throwaway git repos.
```

## What ships vs what doesn't

- **Ships to consumers** (via marketplace install or manual clone): everything under `skills/supergoal/` — including `scripts/repo-state.sh` and `scripts/claim-run.sh` (the per-run namespace claimer) — the `/goal` session needs `repo-state.sh` at audit time (copied into the run's `.supergoal/<run-id>/` dir at Stage 7). The plugin manifest at `.claude-plugin/plugin.json` declares `skills: "./skills/"`.
- **Repo-only** (not part of the plugin payload): `README.md`, `CHANGELOG.md`, `LICENSE`, `AGENTS.md`, `CLAUDE.md`, `.gitignore`, `.gitattributes`, `tests/`. Docs / hygiene / fixtures.
- **Marketplace entry** at `.claude-plugin/marketplace.json` is read by Claude Code when a user runs `/plugin marketplace add ...` against this repo. Points at the plugin at `./`.

## How the skill works (one paragraph)

When invoked, the skill runs Stages 0–6.5 (preload memory, detect tools, intake clarifying questions, recon, deep think, decompose into N phases, write per-phase specs to the run's namespaced `.supergoal/<run-id>/` dir, **self-critique + plan review with revision menu**, **pre-flight smoke check against the deduplicated mandatory commands**). At Stage 7 it captures `Baseline ref:` into `STATE.md` and prints a ready-to-paste `/goal` command. The user pastes it. Inside the `/goal` session, the agent loops through each phase (read spec → do work → SUPERGOAL_PHASE_VERIFY including cleanliness counts → memory writeback → SUPERGOAL_PHASE_DONE), self-healing failures with a 3-strike retry/fix-spec/handoff protocol. After the last phase, the **final audit** re-reads the original `ROADMAP.md`, re-runs the deduplicated mandatory commands, spot-checks every acceptance criterion, **diff-checks every declared deliverable against `Baseline ref`**, and writes `audit-fix-<round>.md` for any gaps (up to 3 audit rounds). Only after `AUDIT_COMPLETE` does it print `SUPERGOAL_RUN_COMPLETE` — with an audit-coverage line that warns when more than 30% of checks were `trust-prior-verify`.

## Making changes

### Editing the skill content

Edit `skills/supergoal/SKILL.md` or the files under `references/`, `scripts/`, `templates/`. The user-visible behavior is driven by what's in `SKILL.md` plus what the planner reads from `references/` and writes from `templates/`.

After editing:

1. **Validate any manifests you touched** — `claude plugin validate .claude-plugin/plugin.json` and `claude plugin validate .claude-plugin/marketplace.json`.
2. **Validate any phase spec template** — `bash skills/supergoal/scripts/validate-phase.sh skills/supergoal/templates/phase-goal.txt`. **If you touched `repo-state.sh` or the comparison logic, run** `bash tests/repo-state.test.sh` (expects `47 passed, 0 failed`); **if you touched `claim-run.sh` or the namespacing logic, run** `bash tests/claim-run.test.sh` (expects `23 passed, 0 failed`).
3. **Bump the version** in `.claude-plugin/plugin.json` (`0.6.x → 0.6.x+1` for backwards-compatible patches, `0.x → 0.x+1` for new features, `x.0` for breaking changes). The marketplace cache only refreshes when this field changes.
4. **Add a CHANGELOG entry** at the top of `CHANGELOG.md`, Keep-a-Changelog format.
5. **Commit, push, tag** with the new version: `git tag -a v0.7.x -m "..."`, `git push origin v0.7.x`.
6. **Re-sync to Codex**: `rm -rf ~/.codex/skills/supergoal && cp -R skills/supergoal ~/.codex/skills/supergoal`, then verify byte-identical with `diff -r skills/supergoal ~/.codex/skills/supergoal`.
7. **Update this file's "Working state" line** to the new version + brief note on what shipped.

### Editing READMEs / docs only

No version bump needed. Just commit + push. Docs don't affect what install consumers get.

### Conventions

- **Slash command and skill name**: always `supergoal` (lowercase). Plugin name, marketplace name, skill frontmatter `name:`, slash command, artifact dir (`.supergoal/`), and transcript markers (`SUPERGOAL_*`) all match.
- **Versioning**: SemVer. Plugin manifest `version` field is the source of truth. README and CHANGELOG must match.
- **CHANGELOG**: every version gets an entry. Mention what changed, what's new, what's removed. Migration steps if breaking.
- **Co-Authored-By trailers**: do NOT add Claude or any AI attribution to commit messages. All commits are authored only by the repo owner.
- **No `.DS_Store`**: gitignored. If one slips in, remove it.

## Install flows (verified working)

### For a new user (Claude Code)

```text
/plugin marketplace add https://github.com/robzilla1738/supergoal.git
/plugin install supergoal@supergoal
/reload-plugins
```

The `owner/repo` shorthand (`/plugin marketplace add robzilla1738/supergoal`) also works, but only if the user has GitHub SSH keys configured — the CLI defaults to SSH cloning for that shorthand.

### For a new user (Codex CLI)

```bash
mkdir -p ~/.codex/skills
git clone https://github.com/robzilla1738/supergoal /tmp/supergoal-clone
cp -R /tmp/supergoal-clone/skills/supergoal ~/.codex/skills/
rm -rf /tmp/supergoal-clone
```

Codex doesn't have a plugin marketplace; this is the manual path.

### For local development on this repo

Source-of-truth is the repo (`/Users/robert/Code/supergoal/`). To test changes:

```bash
# After committing + pushing + version-bumping:
claude plugin marketplace update supergoal
claude plugin update supergoal@supergoal
# Then /reload-plugins in a Claude Code session
```

For Codex, after committing:

```bash
rm -rf ~/.codex/skills/supergoal
cp -R /Users/robert/Code/supergoal/skills/supergoal ~/.codex/skills/supergoal
```

## Transcript markers (load-bearing)

### Inside the `/goal` session

Named blocks the executing agent must print into the transcript. The host's `/goal` evaluator + the user both read them.

- `SUPERGOAL_PHASE_START` — once per phase, at the start. Metadata only.
- `SUPERGOAL_PHASE_VERIFY` — once per phase, before DONE. Each criterion pass/fail with evidence; engineering checks; **v0.6: `Cleanliness:` section** with grep counts vs `Baseline ref` (debug prints, session TODO/FIXME, dead imports). **v0.6.1: those counts run against the complete working tree via `bash <run-root>/repo-state.sh added-lines <Baseline ref>`, so uncommitted + untracked work is included — not just commits.** Non-zero cleanliness counts trigger 3-strike unless the phase spec declares `Cleanliness override:`.
- `MEMORY_SAVED` — once per phase, between VERIFY and DONE. `<name>` or `none`.
- `SUPERGOAL_PHASE_DONE` — once per phase, final block.
- `FAILURE_PROBE` / `FAILURE_ESCALATE` / `FAILURE_HANDOFF` — 3-strike phase-criterion recovery.
- `AUDIT_START` / `AUDIT_VERIFY` (**v0.6: includes a `Deliverables:` block vs `Baseline ref`; v0.6.1: that check compares the complete working tree via `bash <run-root>/repo-state.sh deliverable`, not a `..HEAD` commit range, and detects untracked deliverables**) / `AUDIT_GAPS` / `AUDIT_COMPLETE` (**v0.6: includes `Audit coverage:` line**) / `AUDIT_HANDOFF` — final audit pass.
- `SUPERGOAL_RUN_COMPLETE` — only after `AUDIT_COMPLETE`. Run is done. **v0.6: prepends a `⚠ Audit coverage: …` warning banner when trust-prior is > 30% of total checks.**

The `/goal` end-state requires `SUPERGOAL_RUN_COMPLETE` preceded by `AUDIT_COMPLETE` and one `SUPERGOAL_PHASE_DONE` per phase, with no `FAILURE_HANDOFF` or `AUDIT_HANDOFF`.

### Inside the planner session (v0.6)

Before the user pastes `/goal`, the planner emits two additional named blocks the user sees in Stage 6/6.5:

- `Self-critique:` — printed inside the Stage 6 plan-review summary (Stage 6a). 1–3 findings (falsifiability of criteria, phase atomicity, weakest dependency) or `clean`. Falsifiability issues are rewritten in place in the phase specs before the summary prints — so the user sees the post-critique version.
- `PREFLIGHT_GREEN` / `PREFLIGHT_RED` — Stage 6.5 output after running the deduplicated mandatory commands once. `PREFLIGHT_RED` re-enters Stage 6 with a "Skip pre-flight, dispatch anyway" option for cases where the broken baseline is exactly what phase 1 will fix.

These are not part of the `/goal` end-state — the `/goal` session hasn't started yet at this point — but they're load-bearing for plan quality.

### Other v0.6 state

- **`Baseline ref:`** in `<run-root>/STATE.md` is captured at Stage 7 dispatch from `git rev-parse HEAD 2>/dev/null || echo "no-git"`. The audit's deliverable check and the cleanliness greps both compare the **complete working tree** (committed + staged + unstaged + deleted + untracked) against it via `scripts/repo-state.sh` — **not** a `<Baseline ref>..HEAD` commit range, which would miss every uncommitted change. The single documented strategy lives in `references/repo-state-comparison.md`.

Full format spec: `skills/supergoal/references/goal-format.md`.

## Gotchas

- **Slash commands fire only from user input.** Agent text containing `/goal "..."` is *not* parsed as a command. Stage 7 is a one-paste handoff — the planner prints the line, the user pastes it. Never frame this as "automatic dispatch."
- **Plugin cache only refreshes on version-field change.** If you push a code change without bumping `plugin.json` version, `claude plugin update` reports "already at latest" and the cache stays stale. Always bump on shipped changes.
- **`.gitignore` extension filter**: the file has no extension, so `find -name "*.md"` etc. skip it. When doing mass renames, include the gitignore separately.
- **Codex install is a one-way copy**. There's no auto-update path. To update Codex users: `rm -rf ~/.codex/skills/supergoal && cp -R …` again. Document this in any breaking-change CHANGELOG entry.
- **Memory writeback is per-phase, optional**. The agent emits `MEMORY_SAVED: <name>` or `MEMORY_SAVED: none`. Future runs preload these for the user — load-bearing for the "starts smarter" pitch.
- **One run = one namespace; one working tree ≠ safe for two executions.** v0.7 namespacing (`.supergoal/<run-id>/` via `claim-run.sh`) isolates *planning* artifacts so concurrent `/supergoal` planning can't clobber. It does **not** make two `/goal` *executions* in the same working tree safe — they still edit the same source files. For real parallelism, each task needs its own `git worktree`. Don't "fix" the coexistence warning by implying parallel execution in one tree is safe.
- **Mermaid renders natively in GitHub README** but not always in every external markdown viewer. Stick to standard Mermaid syntax (flowchart TD / LR, subgraphs, classDef styling).

## Working state (as of v0.7.0 — 2026-06-06)

- All planning + execution surfaces (Stages 0–6.5 + Phase loop + Final audit) are implemented and live, including the v0.6 additions, the v0.6.1 working-tree-audit fix, and the **v0.7.0 concurrent-run isolation**: every run claims its own `.supergoal/<run-id>/` namespace via `scripts/claim-run.sh` (`mktemp -d`, atomic create-or-fail), so two runs started in the same working tree can't overwrite each other's `STATE.md` / `ROADMAP.md` / `phases/`. `PROTOCOL.md` + phase specs use a `{{RUN_ROOT}}` placeholder substituted at Stage 7; the dispatched `/goal` line and the reference docs reference `<run-root>/…`. Stage 0 prints a coexistence warning (use a separate `git worktree` for parallel *execution*).
- README headline, CHANGELOG top entry, and `plugin.json` `version` all aligned at v0.7.0.
- Fixture tests pass: `tests/repo-state.test.sh` (47 assertions) and `tests/claim-run.test.sh` (23 assertions, incl. the 24-way concurrent-claim race). Both `claude plugin validate` calls and `validate-phase.sh` pass.
- **Pending for the release PR:** commit/push, tag (`git tag -a v0.7.0`), Codex re-sync (`rm -rf ~/.codex/skills/supergoal && cp -R skills/supergoal ~/.codex/skills/supergoal`), and marketplace verification (`claude plugin marketplace update supergoal` → `claude plugin update supergoal@supergoal` → confirm `/plugin` lists `supergoal 0.7.0`).

## Open work (none blocking)

- v0.6 is additive: every existing transcript marker, STATE.md field, and protocol step still works. No migration needed.
- Backlog (deferred from the v0.6 brainstorm, not in this release): plan-fitness checkpoint for runs ≥8 phases, `PHASE_SPEC_READ` calibration block, skill-binding written into phase specs, scope-driven Polish & Harden menu, resume-from-`BLOCKED` pathway. Plus the still-deferred removal candidates (`Type:` tag, `MEMORY_SAVED: none` lines, `STATE.md` engineering-check duplication, possibly collapsing 3-tier failure recovery to 2-tier). Revisit each once we have signal on how often the new checks actually catch things.
- Observe how often Stage 6a self-critique produces findings vs. "clean" on real plans — if it's nearly always "clean", drop it next release per the honesty test in SKILL.md.

## Related

- Repo: https://github.com/robzilla1738/supergoal
- License: MIT
- Author: Robert Courson
