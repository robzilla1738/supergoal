# Superplan — Agent Handoff

A Claude Code / Codex **skill** that compiles vague build requests into hash-pinned contracts and a measurable `/goal` condition. The skill prepares execution; it does not run it.

**Repo:** `~/Code/superplan`
**Current version:** `v0.3.0` (committed at `36f5650`)
**Status:** shipped MVP. Used in production as the foundation for Superboard (the dispatcher).

---

## The non-negotiables

These are project axioms. Don't break them.

1. **The skill never invokes `/goal` itself.** `/goal` is a CLI command in the host. The skill prepares `GOAL.txt` + `LOCK.json` and either (a) auto-kicks `superplan-go` in the background, or (b) prints the command for the user/dispatcher to run.
2. **The `/goal` evaluator only sees the transcript.** File references are not enough on their own. The compiled goal forces the agent to print `SUPERPLAN_MANIFEST`, `SUPERPLAN_STATE`, `FAILURE_PROBE`, and `SELF_REVIEW` blocks into the conversation. If you change the goal template, you must keep those required transcript surfaces.
3. **Locked files are immutable mid-run.** `PLAN.md`, `ACCEPTANCE.md`, `VERIFY.md`, `POLISH.md` are hash-pinned in `LOCK.json` at lock time. The agent may only edit `STATE.md` and `logs/` during execution. If it needs to weaken the contract, it must stop with `HANDOFF.md`.
4. **`/goal` has a 4000-character hard limit.** We aim for ≤ 3800 chars (200-char headroom). The template at SKILL.md Stage 5 is currently 1,824 chars with `MAX_TURNS=120` — plenty of room, but never add inline narrative when a file reference would do.
5. **`SUPERPLAN_ROOT` redirects all artifacts.** Default `.superplan`. Dispatchers (Superboard) set it to `.superboard/tasks/<id>/superplan`. All scripts read `process.env.SUPERPLAN_ROOT` and SKILL.md threads it everywhere.
6. **bash 3.2 compatibility on macOS.** No `declare -A`, no `${!array[@]}`, no process-substitution-only tricks. Stick to bash 3.2 syntax in shell scripts. The renderer/runner are Node so they don't have this constraint.

---

## Quick start

The skill should already be symlinked at `~/.claude/skills/superplan` and `~/.agents/skills/superplan`. Verify:

```bash
readlink ~/.claude/skills/superplan
# expected: /Users/robert/Code/superplan/skills/superplan
```

If missing:

```bash
ln -s ~/Code/superplan/skills/superplan ~/.claude/skills/superplan
ln -s ~/Code/superplan/skills/superplan ~/.agents/skills/superplan
```

To invoke (in a Claude Code or Codex session, with the user's project as cwd):

```
/superplan <task description>
```

To smoke-test the renderer standalone:

```bash
mkdir -p /tmp/sp-test && cd /tmp/sp-test
echo "# Plan" > .superplan/PLAN.md   # (mkdir .superplan first)
# … create other stub files …
node ~/.claude/skills/superplan/scripts/render-plan.mjs
open .superplan/plan.html
```

---

## Architecture

The skill is a procedural prompt loaded as system context. The model runs the 5 stages by following the procedural instructions in `SKILL.md`. Bash + Node scripts handle work that the model shouldn't do inline (filesystem scanning, markdown rendering, browser launching, the headless run wrapper, the stuck-watcher).

```text
/superplan <task>
   │
   ├─ Stage 1  Intake        classify task (greenfield / brownfield / bugfix / refactor / ui)
   │
   ├─ Stage 2  Recon         brownfield: detect-stack.sh + summarize-repo.sh
   │                         greenfield: inline environment recon (runtimes + folder)
   │
   ├─ Stage 3  Draft         fill 6 .md templates into $SUPERPLAN_ROOT/
   │                         render plan.html (Node + marked or fallback)
   │                         open in browser (open / xdg-open / wsl)
   │
   ├─ Stage 4  Iterate       Edit (not Write) artifacts; re-render HTML on each edit batch
   │
   └─ Stage 5  Lock          compute sha256 of PLAN/ACCEPTANCE/VERIFY/POLISH
                             write LOCK.json with hashes + phases + commands + stop_conditions
                             write GOAL.txt (≤3800 chars; references files; includes the
                                             SUPERPLAN_MANIFEST/STATE/FAILURE_PROBE/SELF_REVIEW
                                             contract; substitutes $SUPERPLAN_ROOT inline)
                             unless SUPERPLAN_NO_AUTOKICK=1, fire `nohup superplan-go &`
                             print summary and STOP (job ends here)
```

Execution (post-lock) is handled by `superplan-go`, which calls `claude -p "/goal ..."` with the compiled goal. The agent inside that headless session is required to print MANIFEST/STATE/FAILURE_PROBE/SELF_REVIEW blocks per the goal text.

---

## File map

```
skills/superplan/
├── SKILL.md                              5-stage choreography (the entry point)
├── references/
│   ├── goal-format.md                    /goal syntax, 4000-char limit, MANIFEST shapes
│   ├── planning-rubric.md                quality bar for PLAN.md sections
│   ├── verification-rubric.md            matrix structure per stack
│   ├── interactive-flow.md               edge cases per stage
│   ├── ui-verification.md                browser-harness integration for UI tasks
│   └── html-viewer.md                    plan.html structure spec
├── templates/
│   ├── PLAN.template.md                  15 sections, variable slots
│   ├── ACCEPTANCE.template.md            functional / engineering / polish / evidence / visual
│   ├── VERIFY.template.md                mandatory / conditional / non-terminating matrix
│   ├── RISKS.template.md                 severity-tagged risk table
│   ├── POLISH.template.md                6 passes (+ visual for UI)
│   ├── STATE.template.md                 ledger; compact SUPERPLAN_STATE block per turn
│   ├── HANDOFF.template.md               honest-stop skeleton for blocked runs
│   ├── LOCK.template.json                hash-pinned contract structure
│   └── plan.html.template                self-contained HTML, dark mode, copy /goal btn
└── scripts/
    ├── detect-stack.sh                   scan cwd for stack markers; emit context.md
    ├── summarize-repo.sh                 git status + tree + entry points → repo-map.md
    ├── render-plan.mjs                   read .md files; fill plan.html.template
    ├── open-plan.sh                      cross-platform browser open
    ├── superplan-go                      headless runner; calls `claude -p "/goal …"`
    └── stuck-watcher.mjs                 4-signal stall detector (Node, sidecar)

.claude-plugin/plugin.json                Claude Code plugin manifest
.codex-plugin/plugin.json                 Codex plugin manifest (experimental)
docs/{install,claude-code-setup,codex-setup}.md
examples/greenfield-saas/
README.md, LICENSE, .gitignore
```

---

## Build / test / run commands

There are no NPM scripts — this is a skill, not a Node app. Verification is by inspection + smoke tests.

```bash
# Syntax-check all scripts
bash -n skills/superplan/scripts/detect-stack.sh
bash -n skills/superplan/scripts/summarize-repo.sh
bash -n skills/superplan/scripts/open-plan.sh
bash -n skills/superplan/scripts/superplan-go
node --check skills/superplan/scripts/render-plan.mjs
node --check skills/superplan/scripts/stuck-watcher.mjs

# Validate plugin manifests
python3 -m json.tool .claude-plugin/plugin.json
python3 -m json.tool .codex-plugin/plugin.json

# Validate SKILL.md frontmatter
python3 -c "import yaml, re; c=open('skills/superplan/SKILL.md').read(); print(yaml.safe_load(re.match(r'---\n(.*?)\n---', c, re.DOTALL).group(1)))"

# End-to-end renderer test
mkdir -p /tmp/sp-test/.superplan
cd /tmp/sp-test
# … create stub .superplan/*.md and LOCK.json …
SUPERPLAN_ROOT=$PWD/.superplan node ~/.claude/skills/superplan/scripts/render-plan.mjs
```

---

## Code conventions

**Shell:** bash 3.2 (default macOS). No `declare -A`. Use `compgen -G` for globbing, parallel arrays or `case` for lookup tables. All scripts start `#!/usr/bin/env bash` + `set -u` (or `set -euo pipefail` for the runner). Avoid `pipefail` only where intentional pipeline failures are OK.

**Node:** ES modules (`.mjs`). Node 20+ APIs. No transpilation; `node --check` is the only static check. Use `import { execSync } from 'node:child_process'` style. No external deps beyond `marked` (optional, dynamic-imported with fallback).

**Markdown templates:** `{{PLACEHOLDER}}` slots that the model fills at Stage 3/5. Never leave a placeholder unfilled in a final artifact — write `N/A` with reason if a section doesn't apply.

**`$SUPERPLAN_ROOT` substitution:** in shell, use `"${SUPERPLAN_ROOT:-.superplan}"`. In Node, `process.env.SUPERPLAN_ROOT || '.superplan'`. In SKILL.md prose, write `$SUPERPLAN_ROOT/PLAN.md` and tell the model to substitute the actual root value at compile time.

**No new dependencies** unless they're necessary. The skill is intentionally lean: zero npm-installed packages required for the renderer (uses `npx -y marked` opportunistically, falls back to a built-in minimal parser).

---

## Things that bit us (gotchas)

- **bash 3.2 doesn't have associative arrays.** `detect-stack.sh` initially used `declare -A`. Rewrote to parallel arrays / inline lookups.
- **`grep | head` returns head's exit code.** A risky-surfaces check used to always succeed. Fixed with `grep -q` instead.
- **`/goal` evaluator can't read files.** Plan-only contracts that point to files don't work — the evaluator only sees the transcript. Hence the required `SUPERPLAN_MANIFEST` block.
- **`claude -p` requires `--verbose` with `--output-format stream-json`.** Easy to miss; the Claude adapter in Superboard sets both.
- **`--max-turns` does NOT exist for `claude -p`.** Use the in-goal `turn cap = N` instead.
- **`SubagentStart` hook does NOT exist** (only `SubagentStop`). Don't reference it.
- **Permission hooks DO fire in `-p` mode** (correcting an earlier misconception in the design brief).
- **Auto-kick race condition** — if Superboard manages launch and Superplan auto-kicks, you get two competing runs. Always set `SUPERPLAN_NO_AUTOKICK=1` when a dispatcher spawns the worker.
- **Long `SUPERPLAN_ROOT` paths inflate the goal.** With `.superboard/tasks/<long-id>/superplan` the goal grew to 2069 chars (still under budget). For longer hierarchies, check the rendered GOAL.txt size.

---

## What's done

- ✅ 5-stage choreography in `SKILL.md`
- ✅ 9 templates (`PLAN/ACCEPTANCE/VERIFY-matrix/RISKS/POLISH/STATE/HANDOFF/LOCK.json/plan.html`)
- ✅ 6 scripts (`detect-stack/summarize-repo/render-plan/open-plan/superplan-go/stuck-watcher`)
- ✅ 6 reference docs (`goal-format/planning-rubric/verification-rubric/interactive-flow/ui-verification/html-viewer`)
- ✅ `SUPERPLAN_ROOT` env var threaded through all paths
- ✅ Auto-kick on lock with `SUPERPLAN_NO_AUTOKICK=1` opt-out
- ✅ Hash-pinned `LOCK.json` (sha256 of PLAN/ACCEPTANCE/VERIFY/POLISH)
- ✅ `SUPERPLAN_MANIFEST` / `SUPERPLAN_STATE` / `FAILURE_PROBE` / `SELF_REVIEW` transcript contract
- ✅ Verification matrix (mandatory / conditional / non-terminating)
- ✅ Node-based stuck-watcher with 4-signal stall detection + allowlist
- ✅ Plugin manifests for Claude Code + Codex
- ✅ Install docs + example

---

## Backlog (V2+)

- Cost / token surfacing (parse Claude's API usage events into a summary)
- Per-project template library (Next.js / Rails / SwiftUI scaffolds)
- Plan-quality scorer before lock (red-team the spec)
- Pre-existing-failure classifier (distinguish "my change broke this" vs "this was already broken")
- AI triage step before lock — optional cleanup pass
- Richer HTML viewer (live STATE.md updates via WebSocket, screenshot gallery)
- GitHub issue / Linear ticket import

---

## Working state at handoff (2026-05-12)

- Last commit: `36f5650 Initial commit: Superplan v0.3 — goal-compiler skill`
- Tagged: `v0.3.0`
- Working tree: clean
- Skill installed at: `~/.claude/skills/superplan` (symlink to repo)
- Companion project: **Superboard** at `~/Code/superboard` (the dispatcher) consumes this skill via `SUPERPLAN_ROOT`

**What you'd reasonably do next:** Superplan itself is settled. Real work happens in `~/Code/superboard`. If you need to touch Superplan, it'll be one of: tightening the goal-format spec, adding a new template, or implementing the V2 cost-tracker.

See also: `~/Code/superboard/AGENTS.md` for the dispatcher that sits on top of this skill.
