# CLAUDE.md

Project-level instructions for Claude Code sessions opened in this repo. Read `AGENTS.md` first for the authoritative project doc; this file adds Claude-Code-specific tips on top.

## Quick orientation

This repo is the source of truth for the `supergoal` skill — a Claude Code plugin that turns vague build requests into deeply-planned, autonomously-executed `/goal` runs with a final audit pass.

Full project doc: see [AGENTS.md](AGENTS.md).

## Working in this repo from Claude Code

### File map you actually edit

- `skills/supergoal/SKILL.md` — the skill content. Edit here for behavioral changes. ~520 lines (over the prior 500-line soft budget after v0.6; phase-loop section duplicates `PROTOCOL.md` and is a slim-down candidate).
- `skills/supergoal/references/*.md` — progressive-disclosure docs the agent reads when needed (`planning-depth.md`, `phase-design.md`, `goal-format.md`, `repo-state-comparison.md`).
- `skills/supergoal/scripts/repo-state.sh` — the complete-working-tree-vs-baseline comparison helper. Edit here to change how the audit/cleanliness checks detect committed/staged/unstaged/deleted/untracked work. Copied into `.supergoal/` at Stage 7; tested by `tests/repo-state.test.sh`.
- `skills/supergoal/templates/PROTOCOL.md` — execution loop + failure recovery + final audit. Edit here when changing the per-`/goal`-session protocol.
- `skills/supergoal/templates/STATE.md` — live-progress template the planner copies to `.supergoal/STATE.md` per run. Contains `Baseline ref:` (the HEAD sha captured at Stage 7 dispatch; the audit + cleanliness checks compare the complete working tree against it via `repo-state.sh`).
- `skills/supergoal/templates/ROADMAP.md` — phase plan with `Deliverables:` bullets; the audit's deliverable check parses these bullets directly.
- `tests/repo-state.test.sh` — fixture tests for `repo-state.sh` (repo-only; run with `bash tests/repo-state.test.sh`).
- `.claude-plugin/plugin.json` — bump `version` on every shipped change so the marketplace cache refreshes.
- `CHANGELOG.md` — add a top entry per release.
- `README.md` — public-facing only. Edit for docs / Mermaid diagram tweaks. No version bump needed.

### Before shipping a change

```bash
claude plugin validate .claude-plugin/plugin.json
claude plugin validate .claude-plugin/marketplace.json
bash skills/supergoal/scripts/validate-phase.sh skills/supergoal/templates/phase-goal.txt
bash tests/repo-state.test.sh   # expects: 47 passed, 0 failed
```

The first three should return `✔ Validation passed`; the test run should end `All fixture scenarios passed.`

### Local install testing

After committing + pushing + bumping version:

```bash
claude plugin marketplace update supergoal
claude plugin update supergoal@supergoal
# then in a Claude Code session:
/reload-plugins
/supergoal <some test task>
```

If `claude plugin update` reports "already at latest" but you know you pushed changes, you forgot to bump `version` in `plugin.json`.

### Codex sync

Claude Code auto-updates via the marketplace. Codex doesn't have a marketplace — it's a manual file copy. After any shipped change:

```bash
rm -rf ~/.codex/skills/supergoal
cp -R /Users/robert/Code/supergoal/skills/supergoal ~/.codex/skills/supergoal
```

## Conventions that matter here

### Commit attribution

**Do not add `Co-Authored-By` trailers to any commit message.** All commits are authored solely by the repo owner (`robzilla1738 <robertcourson1738@gmail.com>`). This rule has been load-bearing during cleanup of prior co-author attribution; preserve it going forward.

### Naming

Everything in lowercase `supergoal`. The plugin name, marketplace name, skill frontmatter `name:`, slash command (`/supergoal`), artifact dir (`.supergoal/`), and transcript markers (`SUPERGOAL_*`) all match. If you find a stray `superplan` outside the CHANGELOG, it's a bug — the CHANGELOG keeps historical names intentionally.

### Version bumping

Source of truth is `.claude-plugin/plugin.json`'s `version`. Must match README's "Current: v..." line, the latest `CHANGELOG.md` entry, and the "Working state (as of vX.Y.Z — …)" line in `AGENTS.md`. Tag the same number: `git tag -a v0.6.x -m "..." && git push origin v0.6.x`.

### Slash command mechanics

`/goal` on both Claude Code and Codex is a **user-initiated** command. Agent text containing `/goal "..."` does **not** fire the command. Stage 7's design is an honest one-paste handoff — the planner prints a fenced code block with the `/goal` line, instructs the user to paste it, and stops. Never reframe this as automatic dispatch.

`/goal` itself is built-in on Claude Code (no plugin dependency) per the official docs.

### Transcript markers

**Inside the `/goal` session** (the autonomous run). The agent must print these named blocks; they're how the host evaluator + the user judge progress:

- `SUPERGOAL_PHASE_START` / `SUPERGOAL_PHASE_VERIFY` (v0.6 added a `Cleanliness:` section) / `SUPERGOAL_PHASE_DONE`
- `MEMORY_SAVED`
- `AUDIT_START` / `AUDIT_VERIFY` (v0.6 added a `Deliverables:` block from the diff-based check) / `AUDIT_GAPS` / `AUDIT_COMPLETE` (v0.6 added `Audit coverage:`) / `AUDIT_HANDOFF`
- `SUPERGOAL_RUN_COMPLETE` (v0.6 prepends a `⚠ Audit coverage: …` honesty banner when trust-prior > 30%)
- `FAILURE_PROBE` / `FAILURE_ESCALATE` / `FAILURE_HANDOFF`

**Inside the planner session** (Supergoal stages, before the `/goal` is dispatched). The user sees these but the `/goal` evaluator doesn't (it isn't active yet):

- `Self-critique:` — inside the Stage 6 plan-review summary (Stage 6a — 1–3 findings or `clean`)
- `PREFLIGHT_GREEN` / `PREFLIGHT_RED` — Stage 6.5 output after running the deduplicated mandatory commands once

These are how the `/goal` evaluator decides the run is done. Don't rename the `/goal`-session markers without thinking through the protocol + the end-state condition string.

The `/goal` end-state requires `SUPERGOAL_RUN_COMPLETE` preceded by `AUDIT_COMPLETE` and one `SUPERGOAL_PHASE_DONE` per phase, with no `FAILURE_HANDOFF` or `AUDIT_HANDOFF`.

## Common pitfalls (field-tested)

- **Forgot to bump `version` after a content change** → marketplace cache stays stale. Symptom: `claude plugin update` says "already at latest". Fix: bump and re-push.
- **Mass find/replace missed `.gitignore`** → it has no extension so most find filters skip it. Always check it separately after global renames.
- **GitHub Contributors sidebar shows stale data after a history rewrite** → it's a stats-endpoint caching lag, clears on its own (minutes to hours). The actual `/contributors` API is what to trust.
- **`/plugin marketplace add owner/repo` shorthand defaults to SSH** → fails for users without GitHub SSH keys. README leads with the HTTPS URL form for this reason.
- **Codex install is a one-way copy** → users have to re-clone on update. Mention in any breaking-change CHANGELOG.
- **The skill description is the trigger** → tweak it carefully. Lead with `/supergoal` and natural-language phrases users actually type. Keep it pushy.
- **Updating SKILL.md/PROTOCOL.md? Codex stays in sync only via manual `rm -rf … && cp -R …`.** After any shipped change, re-run the copy and verify with `diff -r skills/supergoal ~/.codex/skills/supergoal` → expect `(no output)`. AGENTS.md's "Working state" section documents the latest verified sync.
- **v0.6.1 cleanliness + deliverable checks compare the COMPLETE working tree vs `Baseline ref` via `repo-state.sh`** — not a `<Baseline ref>..HEAD` commit range (that missed every uncommitted change, the bug v0.6.1 fixed). Tracked changes come from the single-revision `git diff <Baseline ref>` (committed + staged + unstaged + deleted); untracked files are detected separately. `Baseline ref:` is still captured at Stage 7 from `git rev-parse HEAD 2>/dev/null || echo "no-git"`. If a user runs `/supergoal` in a directory without git history (or any invalid/unresolvable baseline), `repo-state.sh` degrades to a filesystem existence check and `added-lines` yields nothing — cleanliness counts go to 0, so phases in that mode should treat cleanliness as `trust-prior-verify`-shaped. The one documented strategy lives in `references/repo-state-comparison.md`; the logic is implemented once in `repo-state.sh` and tested by `tests/repo-state.test.sh`.
- **Honesty test for v0.6 Stage 6a self-critique**: if it produces `clean` on essentially every real plan, it's theater and gets dropped. AGENTS.md "Open work" tracks the heuristic — don't defend the feature for its own sake.

## When in doubt

Read `AGENTS.md`. It's the authoritative project doc. This file is a Claude-Code-flavored skim on top.
