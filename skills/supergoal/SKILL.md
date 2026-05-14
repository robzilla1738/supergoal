---
name: supergoal
description: Plan and autonomously build a software task end-to-end. Triggered by `/supergoal`, "plan and ship X", "supercharged plan", "autonomous build", "plan it out and don't stop until it's done", "I don't want to babysit this", or any non-trivial feature/refactor/redesign the user wants driven to completion. Strongly prefer over a plain plan when the user signals "every aspect", "fully", "perfectly", "until done", or wants depth + autonomous follow-through. Recons the codebase, applies preloaded memory, researches best practices with whatever tools are available, decomposes into the right number of phases, gets one confirmation, then prepares a single ready-to-paste `/goal` command — one paste between you and done — that drives the entire chain to completion with built-in retry, fix-spec recovery, and per-phase memory writeback. Works on Claude Code and Codex.
argument-hint: <describe what you want built, fixed, or shipped>
---

# Supergoal

You are running the Supergoal workflow. The user's task is:

$ARGUMENTS

Your job: **plan deeply, then auto-execute under a single `/goal`** until the task is verifiably complete across every phase.

## What "every aspect is perfect" means here

The user's bar is high. Translate it into measurable criteria, not vibes:

- **Functional** — the feature works for the golden path and the obvious edge cases
- **Engineering** — build, typecheck, lint, tests all pass; no new warnings
- **Polish** — UX/copy, error states, empty states, loading states are handled
- **Hardening** — security review, input validation, no obvious regressions
- **Verification** — every phase produces transcript evidence the evaluator can see

If a phase can't be measured, it isn't a phase. Rewrite it until it can.

## How this skill works (one-shot summary)

0. **Available context** — preload memory; detect available tools (Context7, WebSearch, MCPs, skills); resume any in-progress Supergoal state
1. **Intake** — restate, classify, ask questions calibrated to context: **up to 4** for greenfield (no codebase to scan), **0–2** for brownfield (recon answers most of it)
2. **Recon** — parallel codebase + environment scan
3. **Deep think** — research best practices with whatever tools exist (optional, not required); list top-3 risks + dependencies
4. **Decompose** — derive phase count from the task itself; no fixed cap
5. **Write phase specs** — one work-spec file per phase under `.supergoal/phases/phase-N.md` (any length, no char budget)
6. **Plan review** — show summary + concrete revision menu; wait for explicit go/no-go
7. **Hand off one ready-to-paste `/goal`** with a short end-state condition; the user pastes once, and the agent inside that fresh `/goal` session executes phases sequentially, with built-in retry, fix-spec recovery, and per-phase memory writeback, until the condition holds

Two human gates only: **clarifying questions for true gaps (Stage 1)** and **plan review (Stage 6)**. Everything else runs autonomously.

### Why one `/goal`, not a chain

`/goal` in both Claude Code and Codex takes a **short end-state condition**, not a long task body. A fast evaluator checks the condition against the transcript after each turn and auto-continues until it holds. Supergoal v3 leverages this directly: one `/goal` covers the whole run; phase work lives in files the agent reads from disk; the condition is "all phases done, `SUPERGOAL_RUN_COMPLETE` printed." No char budget, no inter-session chain dispatch, no fragility.

## Locate the skill directory

```bash
SUPERGOAL_DIR=$(dirname "$(ls -1 \
  "$HOME/.claude/skills/supergoal/SKILL.md" \
  "$PWD/.claude/skills/supergoal/SKILL.md" \
  2>/dev/null | head -n1)")
export SUPERGOAL_DIR
export SUPERGOAL_ROOT="${SUPERGOAL_ROOT:-.supergoal}"
mkdir -p "$SUPERGOAL_ROOT/goals"
echo "SUPERGOAL_DIR=$SUPERGOAL_DIR"
echo "SUPERGOAL_ROOT=$SUPERGOAL_ROOT"
```

All artifacts live under `$SUPERGOAL_ROOT`. Skill assets (scripts, references, templates) live under `$SUPERGOAL_DIR`.

---

## Stage 0 — Available context (memory + tools)

Before doing anything else, sense what's available this session. This is what makes the run frictionless — if memory already knows the user's preferences, don't ask; if a tool isn't available, don't try to call it.

### Memory preload

```bash
# Detect a memory directory. Common locations:
MEM_DIR=""
for cand in \
  "$HOME/.claude/projects/-Users-$(whoami)/memory" \
  "$HOME/.claude/memory" \
  "$PWD/.claude/memory" \
  "$SUPERGOAL_ROOT/memory"; do
  [[ -d "$cand" ]] && MEM_DIR="$cand" && break
done
echo "MEM_DIR=$MEM_DIR"

if [[ -n "$MEM_DIR" && -f "$MEM_DIR/MEMORY.md" ]]; then
  echo "--- MEMORY INDEX ---"
  cat "$MEM_DIR/MEMORY.md"
fi
```

Read the index. Then **selectively** read individual memory files that look relevant to the task (feedback memories about the stack/domain, user role memories, related project memories). Don't dump them all into context — pull what matters.

Capture applicable memory hits in `$SUPERGOAL_ROOT/applied-memories.md` (one line per memory: name, why-applicable, what-it-changes). Surface them in Stage 1 as "Applied from memory: …" so the user can see what's being inherited and correct anything stale.

### Tool discovery

Tools differ between sessions and hosts (Claude Code vs Codex, different MCP server sets). Detect, don't assume:

- **Context7** — available if `mcp__claude_ai_Context7__resolve-library-id` or similar is in the tool list. If absent, skip it; rely on training-cutoff knowledge + WebSearch if that's present.
- **WebSearch / WebFetch** — available if listed. If neither, skip web research.
- **Project skills** — check the available-skills list for domain-relevant skills (e.g. `mobile-ios-design`, `clerk-auth`, `expo-dev-client`) and note them in `$SUPERGOAL_ROOT/applied-skills.md` to invoke from inside phase goals if relevant.
- **Prior Supergoal state** — if `$SUPERGOAL_ROOT/STATE.md` exists from a previous run, read it; resume rather than restart.

Write detected tools to `$SUPERGOAL_ROOT/tools.md`. Stage 3 and the phase goals reference this file when deciding what to invoke.

### Resume detection

If `STATE.md` exists and shows `Status: IN_PROGRESS` with a phase pending, **do not re-plan**. Print a one-line "Resuming Supergoal from phase N" and jump straight to Stage 6 (plan review) with the existing artifacts, or directly to Stage 7 (dispatch) if the user confirms resume.

---

## Stage 1 — Intake & clarifying questions

Echo the task back in **one sentence**. Then classify it (tags can combine):

| Tag | Trigger |
|---|---|
| `greenfield` | Request implies a new project; cwd has no `.git/` or empty tree |
| `brownfield` | Change in an existing repo |
| `bugfix` | Mentions "bug", "broken", "fails", "regression" |
| `refactor` | Mentions "refactor", "clean up", "restructure" |
| `ui` | Mentions "design", "polish", "UI", "UX", "responsive", "redesign" |

**Calibrate the question count to the context.** The agent has no codebase to scan in greenfield runs, so it needs more verbal context up front. In brownfield runs, recon answers most of what would otherwise be a question.

### Greenfield — up to 4 questions, one batch

A new project has no signal beyond the user's prompt + memory. Ask **up to 4 high-leverage questions** covering the biggest structural forks. Aim to cover the categories below, prioritized by how much each one changes the phase shape:

1. **Target platform / surface** — "iOS, Android, web, desktop, CLI, or combinations?" (Often the single biggest fork.)
2. **Stack or framework preference** — "Next.js or SvelteKit? Expo or bare RN? FastAPI or Django?" Skip if memory or prompt already specifies.
3. **Integration anchors** — auth provider, database, payment processor, hosting, anything that drops in cleanly only if chosen up front.
4. **Scope cut-line** — "MVP-this-week or full feature?", "what is explicitly out of scope?"

Pick the four that matter most for *this* prompt. Don't ask all four if some are obvious from memory + prompt — answer those silently from memory and lead with "Applied from memory: …". If memory + prompt cover everything except, say, the auth provider, ask one question, not four. The cap is 4; the floor is whatever's actually unanswered.

Everything else (naming, file paths, design tokens, library minor versions, copy, test framework if the stack has an obvious default, color palette, etc.) is **assumed**, not asked. Record assumptions in ROADMAP.md and surface them in Stage 6 — the revision menu handles corrections.

### Brownfield — 0–2 questions, one batch

The codebase plus recon scripts already answer most structural questions (stack, package manager, build/test/lint, conventions, what exists). Ask only for **true gaps** memory + prompt + recon leave open:

- Scope cut-line ("just this surface, or also touch the related ones?")
- Compatibility surface ("backwards compat with the old API path, or break it?")
- Primary fork when ambiguous ("which of these two existing patterns do you want me to extend?")

Most well-described brownfield tasks ask **zero questions**.

### In both modes

1. Lead with "Applied from memory: …" so the user sees what's being inherited and can correct stale memories before answering.
2. Use a single `AskUserQuestion` batch (the tool maxes at 4 per call — that's the hard ceiling for either mode).
3. If you'd ask zero, say "No clarifying questions — proceeding from prompt + memory + recon." and move straight to Stage 2 (greenfield: skip recon if cwd is empty).
4. Never ask about anything you could responsibly assume and surface in the Stage 6 plan review.

---

## Stage 2 — Recon (parallel)

Run recon scripts in parallel. They populate context files under `$SUPERGOAL_ROOT/`.

### Brownfield path

```bash
bash "$SUPERGOAL_DIR/scripts/detect-stack.sh"   > "$SUPERGOAL_ROOT/context.md"
bash "$SUPERGOAL_DIR/scripts/summarize-repo.sh" > "$SUPERGOAL_ROOT/repo-map.md"
```

### Greenfield path

```bash
bash "$SUPERGOAL_DIR/scripts/detect-env.sh" > "$SUPERGOAL_ROOT/context.md"
```

Read the outputs. Then print a **5-line summary** to the user: stack, package manager, build/test/lint commands, notable modules (if any), risky areas. This is what tells them you've actually understood their codebase before planning.

---

## Stage 3 — Deep think

This is the difference between a generic plan and a Supergoal. Spend real cycles here — but use only what's available.

**Required regardless of tools:**
- Identify the **top 3 risks**: what's most likely to go wrong, what's hardest to undo, what's easy to miss until shipped.
- Identify **non-obvious dependencies**: things that have to happen in a specific order or block other work.
- Apply memory hits from `$SUPERGOAL_ROOT/applied-memories.md` — bake them into goals, constraints, or risk mitigations.

**Optional, use if available** (check `$SUPERGOAL_ROOT/tools.md`):
- **Context7** — if available, query current docs for any third-party SDK touched. Don't plan against stale APIs. If unavailable, lean on training-cutoff knowledge and call it out as an assumption ("planned against my training-cutoff understanding of Expo SDK — verify in phase 1").
- **WebSearch** — if available, look up current consensus on patterns you're unsure about (auth flows, payment idempotency, accessibility standards). If unavailable, skip.
- **Project skills** — if relevant skills are listed in `$SUPERGOAL_ROOT/applied-skills.md` (e.g. `clerk-auth`, `mobile-ios-design`), note them in THINKING.md as "consult `<skill>` skill during phase N" so the executor invokes them at the right moment.

**Write `$SUPERGOAL_ROOT/THINKING.md`** with sections: Goals, Constraints, Risks, Dependencies, Open Questions (already-assumed), Memory hits applied, Tools/skills relied on, Best Practices Applied. Keep it tight — 1–2 pages. This is the substrate the roadmap derives from.

See `references/planning-depth.md` for the bar to clear here.

---

## Stage 4 — Decompose into phases

Break the work into **as many phases as the task actually needs** — no fixed count, no upper or lower cap. The right number falls out of the work itself: how many independently verifiable units exist between empty repo (or current state) and "done perfectly." A trivial change might need 2 phases; a typical feature 4–6; a full-stack greenfield app 8–12; a major migration 15+. Read `references/phase-design.md` for how to slice well — the short version:

- Each phase delivers something **verifiable on its own** (it builds, it passes its own tests, you could ship it as a partial increment)
- Phases have **explicit dependencies** (phase 3 depends on 1 and 2)
- The **last phase is always a "Polish & Harden" phase** covering edge cases, error states, security, accessibility, copy, perf — this is how "every aspect is perfect" gets enforced
- For UI work, include a dedicated **visual polish** phase with screenshot/visual evidence requirements
- For brownfield, include an early **safety net** phase if test coverage is thin (add characterization tests before changing behavior)

Each phase has:
- **Name** (5 words max, action-first: "Build auth foundation")
- **Why** (1 sentence)
- **Deliverables** (concrete files/features that will exist when done)
- **Acceptance criteria** (5–10 measurable items)
- **Mandatory commands** (build, typecheck, lint, test that must pass)
- **Evidence required** (what the agent must print into the transcript to prove completion)
- **Dependencies** (which prior phases must be done)

---

## Stage 5 — Write the roadmap and phase specs

Three files, all under `$SUPERGOAL_ROOT/`:

1. **`ROADMAP.md`** — the plan (template at `$SUPERGOAL_DIR/templates/ROADMAP.md`).
2. **`STATE.md`** — live progress file the executor updates per phase (template at `$SUPERGOAL_DIR/templates/STATE.md`).
3. **`phases/phase-N.md`** — one work-spec file per phase (template at `$SUPERGOAL_DIR/templates/phase-goal.txt`, renamed conceptually to "phase spec"). **Any length** — these are read from disk by the executor, not passed to `/goal`, so no char budget.

Each phase spec must include these markers so the agent and evaluator both have stable anchors:

```
SUPERGOAL_PHASE_START
Phase: <N> of <total> — <name>
Task: <one-line>
Mandatory commands: <list>
Acceptance criteria: <count>
Evidence required: <list>
Depends on phases: <list or "none">

[... full work description, acceptance criteria, evidence requirements ...]

[Agent will print SUPERGOAL_PHASE_VERIFY and SUPERGOAL_PHASE_DONE here during execution]
```

Validate each spec with `bash $SUPERGOAL_DIR/scripts/validate-phase.sh .supergoal/phases/phase-N.md` — it confirms the required markers exist. No char budget.

---

## Stage 6 — Plan review & confirmation (hard gate)

Before any `/goal` is dispatched, show the user the full plan and **ask for explicit confirmation**. The chain runs unsupervised once it starts, so this is the last cheap moment to correct course. Skipping this step is a bug.

Print a scannable summary in this exact shape:

```
✓ Plan ready for review. <N> phases.

Applied from memory:
  - <memory hit 1>
  - <memory hit 2>
  (or: "none — clean run")

Phases:
  1. <name> — <one-line deliverable>
  2. <name> — <one-line deliverable>
  ...
  N. Polish & Harden — every aspect verified

Stack: <stack> · pkg: <pm> · build/test/lint: <commands>

Key assumptions (correct any that are wrong):
  - <assumption 1>
  - <assumption 2>
  - <assumption 3>

Top risks & mitigations:
  1. <risk> → <mitigation>
  2. <risk> → <mitigation>
  3. <risk> → <mitigation>

Artifacts:
  Roadmap: .supergoal/ROADMAP.md
  Progress: .supergoal/STATE.md (auto-updates)
  Phase specs: .supergoal/phases/phase-1..N.md

Once you confirm, I'll print a ready-to-paste `/goal` line. Paste it
once and the chain runs through to completion, with auto-retry and
fix-spec recovery.
```

Then call `AskUserQuestion` with one question, header "Start chain?", offering **concrete revision modes** (not a vague "revise plan"):

- **Start now** — print the ready-to-paste `/goal` line; I paste it and the chain runs unsupervised
- **Adjust an assumption** — pick one to change (will re-show plan)
- **Tweak a phase** — change criteria, scope, or commands for a specific phase
- **Restructure phases** — merge, split, add, or remove a phase

Keep options at 4 max. If the user picks any revision option, follow up with a second `AskUserQuestion` to pin down exactly what (e.g., "Which assumption?" with the assumptions listed). Apply the change, update ROADMAP/THINKING/STATE and the affected phase specs, re-run `validate-phase.sh` on each touched spec, then re-show the Stage 6 summary and ask again. Loop until "Start now" or user aborts.

**Wait for the answer.** Do not dispatch `/goal` until the user picks "Start now". Never assume confirmation; never start the chain on silence.

---

## Stage 7 — Hand off the `/goal` dispatch (one paste)

Slash commands on both Claude Code and Codex fire **only from user input** — agent message text is never parsed as a command. So Stage 7 is not an automatic dispatch; it's an honest one-paste handoff. After explicit "Start now" in Stage 6:

1. Update `STATE.md`: `Status: READY_TO_DISPATCH`, `Current phase: 1`.
2. Copy `$SUPERGOAL_DIR/templates/PROTOCOL.md` to `.supergoal/PROTOCOL.md`. This is the operating manual the executing agent reads at the start of the `/goal` session.
3. Verify each `.supergoal/phases/phase-N.md` exists; run `bash $SUPERGOAL_DIR/scripts/validate-phase.sh .supergoal/phases/phase-<N>.md` on each.
4. Print a fenced code block with the **ready-to-paste `/goal` command** — the condition below is short, instructional but measurable, and well under the 4000-char `/goal` argument limit:

````
```
/goal "Execute all phases of .supergoal/ROADMAP.md sequentially. Read .supergoal/phases/phase-N.md for each phase; do the work; run mandatory commands; print SUPERGOAL_PHASE_VERIFY then SUPERGOAL_PHASE_DONE for each phase; follow the failure-recovery protocol in .supergoal/PROTOCOL.md if any criterion fails; on the final phase, print SUPERGOAL_RUN_COMPLETE. Done when SUPERGOAL_RUN_COMPLETE appears in the transcript with one SUPERGOAL_PHASE_DONE block per phase preceding it and no FAILURE_HANDOFF in this run."
```
````

5. Follow the fenced block with **exactly this one-line instruction**:

> **Paste the `/goal` line above into your input to dispatch the chain.** From there it runs autonomously — auto-retry, fix-spec recovery, per-phase memory writeback — until `SUPERGOAL_RUN_COMPLETE` appears.

6. **Stop.** Do not generate any further output. The Supergoal invocation ends here. The user's paste begins the autonomous run under a fresh `/goal` session, which reads `PROTOCOL.md`, `ROADMAP.md`, `STATE.md`, and the phase specs from disk and runs the loop documented in the next sections.

Once `/goal` is active (you'll see the `◎ /goal active` indicator on Claude Code), the per-turn evaluator keeps the agent working until the end-state condition holds. On Codex, the auto-continuation loop does the same. The agent inside the `/goal` session has zero special context from the Supergoal invocation; everything it needs is in the files on disk — by design.

---

## Phase execution loop (inside the single `/goal` session)

The agent's loop, repeated until `SUPERGOAL_RUN_COMPLETE`:

1. Read `STATE.md` → find current phase N.
2. Read `.supergoal/phases/phase-N.md` → full work spec.
3. Print `SUPERGOAL_PHASE_START` block with values from the spec.
4. Do the work; run mandatory commands; surface evidence into the transcript.
5. Print `SUPERGOAL_PHASE_VERIFY` block (every criterion `pass|fail` + engineering checks).
6. **Memory writeback check** — anything non-obvious learned? If yes, write a memory file under the detected MEM_DIR; print `MEMORY_SAVED: <name>` (or `MEMORY_SAVED: none`).
7. Print `SUPERGOAL_PHASE_DONE`, update `STATE.md` (mark phase N complete, set Current phase = N+1, append events line).
8. **User-interrupt check** — if a new user message has arrived since the last turn, pause and address it before continuing.
9. If N < total: loop to step 1 for phase N+1.
10. If N == total: print `SUPERGOAL_RUN_COMPLETE` with a 5-line summary. The `/goal` condition is now satisfied and clears.

### Failure recovery (3-strike, built into the protocol)

**First failure of any criterion:**
1. Print `FAILURE_PROBE` (what failed, what tried, root-cause hypothesis).
2. Append probe to `STATE.md` failure log.
3. **Auto-retry the same phase once** with the probe injected as feedback. Do not advance.

**Second failure (auto-retry also failed):**
1. Print `FAILURE_ESCALATE`.
2. Write a focused **fix spec** at `.supergoal/phases/phase-N.fix.md` (targets only the failing criterion, no scope creep).
3. Execute the fix spec inline (same agent, same `/goal` — no new dispatch). On success, re-run the original phase's VERIFY block; on pass, advance to N+1.

**Third failure (fix spec also failed):**
1. Print `FAILURE_HANDOFF` with: failing criterion, full probe history, three things tried, suggested next move.
2. Update `STATE.md`: `Status: BLOCKED`. The user takes the wheel.
3. The `/goal` condition will not be satisfied; the host's evaluator will keep evaluating but the agent should stop attempting and surface the handoff clearly.

This recovers from flaky envs, simple typos, and missed deps automatically. Only real blockers escalate.

### Mid-run interruption

If the user sends any message during the `/goal` run, the agent pauses at the next phase boundary, addresses the message, and asks before resuming. Phase boundaries are after `SUPERGOAL_PHASE_DONE` and before reading the next phase spec.

---

## Memory writeback rules (referenced by PROTOCOL.md)

Memory is load-bearing. Future runs start smarter because past runs wrote down what they learned. The phase execution loop's step 6 references these rules.

**At each phase boundary**, ask: "Did this phase surface anything a future Supergoal run on a similar task would benefit from knowing?"

Worth saving:
- A library API quirk that wasn't in the docs
- A user preference confirmed during this run ("user accepted dark-only UI without pushback")
- A project-level fact ("auth lives in `lib/auth/` not `app/api/auth/`")
- A failure pattern + fix ("X always fails on first build; second build works")

Write the memory file under the detected MEM_DIR using the standard `name` / `description` / `metadata.type` frontmatter. Link it from `MEMORY.md`. Print `MEMORY_SAVED: <name>` to the transcript. If nothing non-obvious this phase: print `MEMORY_SAVED: none`.

**At the final phase**, always write a `project_<slug>.md` memory pointing at the new/changed project (location, stack, status, ROADMAP link). Guarantees future Supergoal runs on the same project start from the latest state.

**Never save:** secrets, transient task details, ephemeral state. Bar is "useful to a future run." When in doubt, skip.

---

## Operating principles (read every run)

- **One `/goal`, short condition.** `/goal` takes an end-state, not a task body. Long content lives in files the agent reads from disk. This is the natural shape on both Claude Code and Codex.
- **Frictionless is the goal.** Memory + prompt + recon should answer most questions. Zero clarifying questions on well-described tasks is a win.
- **Adapt to available tools.** Detect what's there (Context7, WebSearch, MCPs, skills). Use what's available; degrade gracefully without it. Never hard-require a tool that might not be present.
- **Memory is load-bearing.** Preload at Stage 0, surface as "Applied from memory: …" in Stage 1, write back at every phase boundary.
- **"Perfect" is not a stopping condition — criteria are.** Translate every "perfect" into observable, falsifiable criteria.
- **Two human gates, no more.** Clarifying gaps (Stage 1 — up to 4 for greenfield, often zero for brownfield) and plan review (Stage 6). Between and after, autonomous.
- **The loop self-heals.** Auto-retry once, then write a fix spec and execute inline, then escalate. Don't stop on first failure.
- **The evaluator only sees the transcript.** Phase specs require the agent to surface their contract — START, commands, evidence, VERIFY, DONE — into the conversation, not just point at files.
- **Each phase is independently shippable** in spirit. If phase 3 can't build/test on its own, the slicing is wrong.
- **The Polish & Harden phase is mandatory.** It's how "every aspect is perfect" gets enforced.

---

## When to deviate from the workflow

- **Very small task** (< 1 hour of work, single file): tell the user this doesn't need Supergoal, suggest just doing it. Don't force the machinery.
- **The user pushes back on a phase during intake**: collapse, re-plan, continue.
- **Mid-run interruption**: if the user stops the run and asks for a change, update the affected `.supergoal/phases/phase-N.md` spec, run `validate-phase.sh` on it, then ask the user to resume (they can re-dispatch the same `/goal` or just say "continue"). No need to restart phase 1.

---

## Reference files

- `references/planning-depth.md` — what makes a plan deep enough to deserve "Super"
- `references/phase-design.md` — how to slice phases that auto-chain cleanly
- `references/goal-format.md` — what `/goal` is on Claude Code + Codex, Supergoal's single-`/goal` shape, required transcript blocks

## Scripts

- `scripts/detect-stack.sh` — identifies language, package manager, framework, build/test/lint commands (brownfield)
- `scripts/detect-env.sh` — greenfield environment recon
- `scripts/summarize-repo.sh` — compressed repo map (brownfield)
- `scripts/validate-phase.sh` — checks a phase spec has the required SUPERGOAL_PHASE_START marker and a non-empty acceptance criteria section

## Templates

- `templates/ROADMAP.md` — phase plan with dependencies
- `templates/STATE.md` — live progress file
- `templates/phase-goal.txt` — phase spec skeleton (work, criteria, evidence, mandatory commands)
- `templates/PROTOCOL.md` — phase execution loop, failure recovery, memory writeback (copied to `.supergoal/PROTOCOL.md` at dispatch)
