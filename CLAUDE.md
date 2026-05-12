# CLAUDE.md — Superplan

> Claude Code-specific notes. For full project context, conventions, and architecture, read **`AGENTS.md`** in this same directory — it's the authoritative handoff doc.

---

## What this is, in 30 seconds

**Superplan** is a Claude Code / Codex **skill** (not an app) that compiles a vague build request into:
1. Durable planning artifacts under `$SUPERPLAN_ROOT/` (default `.superplan/`)
2. A self-contained `plan.html` reviewable in the browser
3. A hash-pinned `LOCK.json` contract
4. A measurable `GOAL.txt` containing a `/goal` command ≤ 3800 chars

Then it auto-kicks `superplan-go` headless (unless `SUPERPLAN_NO_AUTOKICK=1` is set) and stops. **The skill never invokes `/goal` itself.**

You're most likely here because either:
- A new Claude Code session is starting in this repo, or
- You're maintaining the skill (templates, reference docs, scripts)

Almost all forward work happens in **`~/Code/superboard`** (the dispatcher). This repo is stable.

---

## Claude Code-specific bits

### Invocation
```
/superplan <task description>
```

When invoked, the skill loads `skills/superplan/SKILL.md` as procedural context. The model runs through Stages 1–5 there.

### `/goal` mechanics you must respect
- 4000-char hard limit; we target ≤ 3800 (safe budget)
- The evaluator **only sees the transcript** — it does not read files. Hence the required `SUPERPLAN_MANIFEST` / `SUPERPLAN_STATE` / `FAILURE_PROBE` / `SELF_REVIEW` blocks the goal forces the agent to print.
- `claude -p "/goal …"` headless works (Superplan-go uses it).
- `claude -p` requires `--verbose` when combined with `--output-format stream-json`.
- `--max-turns` does NOT exist for `-p` — the cap lives inside the goal text (`turn cap = N`).

### Hooks reference (current accurate list)
Valid Claude Code hooks: `SessionStart`, `SessionEnd`, `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Notification`, `Stop`, `SubagentStop`, `PreCompact`.
- `SubagentStart` does **not** exist. Don't reference it.
- `PreToolUse` and other permission hooks **do** fire in `-p` mode.

### Skill discovery
Discover the skill's own path in SKILL.md via:
```bash
SUPERPLAN_DIR=$(dirname "$(ls -1 \
  "$HOME/.claude/skills/superplan/SKILL.md" \
  "$HOME/.agents/skills/superplan/SKILL.md" \
  "$PWD/.claude/skills/superplan/SKILL.md" \
  "$PWD/.agents/skills/superplan/SKILL.md" \
  2>/dev/null | head -n1)")
export SUPERPLAN_DIR
```

`$SUPERPLAN_ROOT` defaults to `.superplan` if unset. Dispatchers (Superboard) set it to a per-task directory.

### When editing the skill, reload it
After changing files under `skills/superplan/`, in the active Claude Code session run:
```
/reload-plugins
```
Otherwise the in-memory skill stays stale.

---

## Repo layout (one-line tour)

```
skills/superplan/SKILL.md          5-stage choreography (the entry point the model reads)
skills/superplan/references/       6 docs: goal-format, planning/verification rubric, etc.
skills/superplan/templates/        9 files: PLAN/ACCEPTANCE/VERIFY/RISKS/POLISH/STATE/HANDOFF/LOCK.json/plan.html
skills/superplan/scripts/          6 scripts: detect-stack, summarize-repo, render-plan, open-plan, superplan-go, stuck-watcher
.claude-plugin/plugin.json         plugin manifest
.codex-plugin/plugin.json          plugin manifest (experimental)
docs/                              install / claude-code-setup / codex-setup
examples/                          greenfield-saas demo
```

Full file-by-file map is in `AGENTS.md`.

---

## Common tasks

**Edit a template.** Just edit the file at `skills/superplan/templates/<NAME>.template.md`. After saving, in Claude Code run `/reload-plugins`. Next `/superplan` invocation picks up the change.

**Add a reference doc.** Drop the file under `skills/superplan/references/`. Add a one-line entry under "Reference docs" at the bottom of `SKILL.md`.

**Add a new script.** Place at `skills/superplan/scripts/`. Make it executable (`chmod +x`). bash scripts must be bash 3.2 compatible (default macOS shell). Reference from `SKILL.md` using `bash "$SUPERPLAN_DIR/scripts/<name>"`.

**Tweak the compiled `/goal` template.** It lives in `SKILL.md` under **Stage 5 → Step 2**. After editing, check the rendered length:
```bash
python3 -c "
import re
with open('skills/superplan/SKILL.md') as f:
    c = f.read()
m = re.search(r'\`\`\`\n(/goal Complete the build locked.*?turn cap = \{MAX_TURNS\}\.)\n\`\`\`', c, re.DOTALL)
print(len(m.group(1).replace('\$SUPERPLAN_ROOT', '.superboard/tasks/team-invites-7f3a/superplan').replace('{MAX_TURNS}', '120')))
"
```
Must be ≤ 3800 for the worst-case substitution.

**Smoke-test the renderer.** See `AGENTS.md` § Build/test/run commands.

---

## Convention TL;DR

- Bash scripts: bash 3.2 only. Use `compgen -G` for glob tests; parallel arrays or `case` instead of associative arrays.
- Node scripts: ESM only (`.mjs`), Node 20+. Minimal deps (`marked` dynamic-imported with fallback).
- Templates: `{{PLACEHOLDER}}` slots filled at Stage 3/5. Never ship an unfilled placeholder — write `N/A` with a reason instead.
- Markdown headings + sentence case in docs. No emoji unless the user explicitly asks.
- No new dependencies without strong justification.

---

## Working state at handoff (2026-05-12)

- Commit: `36f5650` (initial), tagged `v0.3.0`
- Working tree: **clean**
- Installed at: `~/.claude/skills/superplan` (symlink)
- Companion: `~/Code/superboard` consumes this skill via `SUPERPLAN_ROOT`

If a session continues here, you're almost certainly maintaining — not building. The forward work is in **`~/Code/superboard`**. See its `CLAUDE.md` and `AGENTS.md`.
