# Superplan

Plan deeply, then autonomously build until it's done.

`/superplan <what you want>` recons your codebase, applies your saved preferences from memory, decomposes the work into the right number of phases for the task, gets one confirmation from you, then prints a **single ready-to-paste `/goal` command**. Paste it once and the rest is autonomous: every phase runs sequentially with built-in retry, fix-spec recovery, and per-phase memory writeback until `SUPERPLAN_RUN_COMPLETE`.

Works on **Claude Code** and **Codex** (Codex CLI).

## Why one `/goal` (not a chain)

`/goal` on both hosts takes a short **end-state condition** that an evaluator checks against the transcript after each turn — not a long task body. Superplan leverages this directly: one `/goal` covers the whole run; phase work lives in files the agent reads from disk. No char budget, no inter-session chain, no fragility.

Slash commands only fire from user input, so Stage 7 is an honest one-paste handoff: the planner prepares the `/goal` line, you paste it, the autonomous run starts. From there it drives itself to completion.

## Install — Claude Code

Three commands inside a Claude Code session:

```text
/plugin marketplace add robzilla1738/superplan
/plugin install superplan@superplan
/reload-plugins
```

That's it. `/superplan` is available immediately.

If `/plugin install` errors with "not found", run `/plugin marketplace update superplan` and try again.

**Manual install** (if you don't want to use the marketplace):

```bash
mkdir -p ~/.claude/skills
git clone https://github.com/robzilla1738/superplan /tmp/superplan-clone
cp -R /tmp/superplan-clone/skills/superplan ~/.claude/skills/
rm -rf /tmp/superplan-clone
```

Then run `/reload-plugins` (or restart Claude Code) and `/superplan` is available.

## Install — Codex CLI

Codex doesn't have a plugin marketplace, so the install is a manual clone-and-copy:

```bash
mkdir -p ~/.codex/skills
git clone https://github.com/robzilla1738/superplan /tmp/superplan-clone
cp -R /tmp/superplan-clone/skills/superplan ~/.codex/skills/
rm -rf /tmp/superplan-clone
```

Restart Codex and `/superplan` is available. To update later, re-run the clone-and-copy.

## Use

```text
/superplan build me an Expo app that converts photos to ASCII art
```

What happens:

1. **Stage 0 — Available context.** Detects your memory directory, preloads relevant feedback/user/project memories, senses which tools/MCPs are available this session.
2. **Stage 1 — Intake.** Greenfield (no codebase to scan): up to 4 high-leverage questions covering platform/stack/integrations/scope. Brownfield (existing repo): 0–2 questions for true gaps only. Well-described tasks often ask zero.
3. **Stage 2 — Recon.** Parallel codebase/environment scan.
4. **Stage 3 — Deep think.** Identifies top-3 risks + dependencies. Uses Context7/WebSearch if available (optional, not required).
5. **Stage 4 — Decompose.** Phase count derived from the task — no fixed cap. Small change = 2 phases; full-stack greenfield = 8–12+.
6. **Stage 5 — Write specs.** `ROADMAP.md` + `STATE.md` + one `phase-N.md` work spec per phase, all under `.superplan/`.
7. **Stage 6 — Plan review.** Shows phases, assumptions, risks, and applied memories. Concrete revision menu: **Start now / Adjust assumption / Tweak a phase / Restructure phases.**
8. **Stage 7 — Hand off.** Prints a ready-to-paste `/goal` line. You paste it once; the chain runs phases sequentially with 3-strike auto-retry → fix-spec → handoff, writing a memory at each phase boundary so future runs start smarter.

## Self-healing failure recovery

Built into every run:

- **First failure** of any acceptance criterion → `FAILURE_PROBE` printed, probe injected as feedback, **auto-retry once**.
- **Second failure** → `FAILURE_ESCALATE`, write a focused fix spec at `phase-N.fix.md`, execute inline.
- **Third failure** → `FAILURE_HANDOFF`, mark state `BLOCKED`, stop. You take the wheel.

Flaky envs, typos, and missed deps self-resolve. Only real blockers escalate.

## Memory writeback

Each phase ends with a "non-obvious learnings" check. If anything a future run on a similar task would benefit from was learned (an API quirk, a confirmed user preference, a project-level fact, a failure-and-fix pattern), it's saved to your memory directory using the standard `name`/`description`/`metadata.type` frontmatter. The final phase always writes a `project_<slug>.md` memory pointing at the new/changed project.

The memory directory is auto-detected from a cascade: `$HOME/.claude/projects/-Users-$(whoami)/memory`, `$HOME/.claude/memory`, `$PWD/.claude/memory`, `.superplan/memory`. The skill works with or without a memory directory; it just starts smarter when one is present.

## Artifacts a run produces

All under `.superplan/` in the project directory:

```
.superplan/
├── ROADMAP.md            full plan
├── STATE.md              live progress, updated per phase
├── THINKING.md           risks, dependencies, applied memories, best practices
├── PROTOCOL.md           execution loop + failure recovery (copied at dispatch)
├── context.md            recon output
├── repo-map.md           brownfield only
├── applied-memories.md   memory hits that informed the plan
├── tools.md              detected MCPs / skills / hosts
└── phases/
    ├── phase-1.md
    ├── phase-2.md
    ├── ...
    └── phase-N.md
```

## Skill internals

```
skills/superplan/
├── SKILL.md
├── references/
│   ├── planning-depth.md      what makes a plan deep enough to deserve "Super"
│   ├── phase-design.md        how to slice phases (adaptive count, no cap)
│   └── goal-format.md         /goal mechanics on CC + Codex, required transcript blocks
├── scripts/
│   ├── detect-env.sh          greenfield env recon
│   ├── detect-stack.sh        brownfield stack recon
│   ├── summarize-repo.sh      repo map
│   └── validate-phase.sh      checks phase spec structure
└── templates/
    ├── ROADMAP.md
    ├── STATE.md
    ├── phase-goal.txt         phase spec skeleton
    └── PROTOCOL.md            execution loop + failure recovery
```

## Requirements

- **Claude Code**: `/goal` is a built-in command (no extra plugin). Available in current Claude Code releases. See [code.claude.com/docs/en/goal](https://code.claude.com/docs/en/goal).
- **Codex CLI**: `/goal` is a built-in slash command. See [developers.openai.com/codex/cli/slash-commands](https://developers.openai.com/codex/cli/slash-commands).

## Version

Current: **v0.4.1**. See [CHANGELOG.md](CHANGELOG.md) for release notes.

Marketplace consumers can pin a specific version via the `/plugin` UI. Auto-updates are off by default for third-party marketplaces — enable per-marketplace via `/plugin` → **Marketplaces** if you want them.

## License

MIT. See [LICENSE](LICENSE).
