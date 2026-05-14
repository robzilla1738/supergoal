# `/goal` format reference

## What `/goal` actually is

`/goal <end-state condition>` is a host slash command available in both Claude Code and Codex (Codex CLI). It is **not** a task description. It is a **measurable end-state condition** that a fast evaluator checks against the transcript after each agent turn. The agent keeps working — running tools, editing files — until the condition holds, at which point control returns to the user.

Key implications:

1. **Condition is short.** A long task body in the `/goal` argument is the wrong shape. Long content belongs in files the agent reads from disk.
2. **The evaluator only sees the transcript.** Conditions must be phrased so the agent's own output can prove them ("X printed", "Y exit code surfaced", "Z file count reported"). The evaluator does not independently run tools or read files.
3. **Host behaviour:**
   - **Claude Code**: a small fast model (Haiku) checks the condition each turn; "no" → continue with the reason as guidance; "yes" → clear goal, return control.
   - **Codex**: auto-continuation loop drives the goal to terminal status (complete / budget_limited / paused / cleared). Five subcommands: `/goal <objective>`, `/goal` (status), `/goal pause`, `/goal resume`, `/goal clear`.

## Supergoal's single-`/goal` shape

Supergoal uses **one** `/goal` per run, dispatched by the **user** at the end of Stage 7. Slash commands fire only from user input on both Claude Code and Codex — the planner cannot fire `/goal` from its own message text. Stage 7's job is to write all phase specs to disk, then print a copy-paste-ready `/goal` block. The user pastes once; from there, the run is autonomous.

The condition is:

```
Execute all phases of .supergoal/ROADMAP.md sequentially.
Read .supergoal/phases/phase-N.md for each phase; do the work;
run mandatory commands; print SUPERGOAL_PHASE_VERIFY then
SUPERGOAL_PHASE_DONE for each phase; follow the failure-recovery
protocol in .supergoal/PROTOCOL.md if any criterion fails; on the
final phase, print SUPERGOAL_RUN_COMPLETE.

Done when SUPERGOAL_RUN_COMPLETE appears in the transcript with one
SUPERGOAL_PHASE_DONE block per phase preceding it and no
FAILURE_HANDOFF in this run.
```

This works on both hosts. There is no per-phase `/goal` dispatch and no inter-session chain — once active, a single `/goal` session reads PROTOCOL.md and loops through every phase spec until the end-state holds.

## Required transcript blocks (Supergoal-specific)

The phase specs and PROTOCOL.md require the agent to print these named blocks during execution. They are what the human-readable evaluator (you, watching) AND the host evaluator both rely on.

### `SUPERGOAL_PHASE_START` (once per phase, at execution start)

```
SUPERGOAL_PHASE_START
Phase: <N> of <total> — <name>
Task: <one-line from ROADMAP.md>
Type: <greenfield|brownfield|bugfix|refactor|ui>
Mandatory commands: <comma-separated list>
Acceptance criteria: <count>
Evidence required: <comma-separated types>
Depends on phases: <list, or "none">
```

### `SUPERGOAL_PHASE_VERIFY` (once per phase, before DONE)

```
SUPERGOAL_PHASE_VERIFY
Acceptance:
- <criterion 1>: <pass|fail> — <evidence>
- <criterion 2>: <pass|fail> — <evidence>
...
Engineering:
- build: <pass|fail>
- typecheck: <pass|fail>
- lint: <pass|fail|pre-existing>
- tests: <pass|fail|N pre-existing>
Files changed: <count>
Notable diffs:
- <file>: <one-line summary>
```

### `MEMORY_SAVED` (once per phase, between VERIFY and DONE)

```
MEMORY_SAVED: <memory-name>     (or "none — nothing non-obvious this phase")
```

### `SUPERGOAL_PHASE_DONE` (once per phase, final block of the phase)

```
SUPERGOAL_PHASE_DONE
Phase <N> complete. STATE.md updated.
```

### `SUPERGOAL_RUN_COMPLETE` (once, on final phase only)

```
SUPERGOAL_RUN_COMPLETE
All <N> phases complete.
Summary: <5 lines max — what shipped, what changed, what to verify manually>
```

## Failure blocks (used by recovery protocol)

### `FAILURE_PROBE` (first failure)

```
FAILURE_PROBE
Phase: <N> — <name>
Failed criterion: <text>
Tried: <what was attempted>
Hypothesis: <root cause guess>
Next: auto-retry with probe injected
```

### `FAILURE_ESCALATE` (second failure — fix spec)

```
FAILURE_ESCALATE
Phase: <N> — <name>
Failed criterion: <text>
Retry probe history:
  attempt 1: <summary>
  attempt 2: <summary>
Writing fix spec at .supergoal/phases/phase-<N>.fix.md
```

### `FAILURE_HANDOFF` (third failure — stop)

```
FAILURE_HANDOFF
Phase: <N> — <name>
Failed criterion: <text>
Three attempts tried:
  1. <summary>
  2. <summary>
  3. <fix spec summary>
Suggested next move: <one line>
STATE.md updated to BLOCKED. User intervention required.
```

## Anti-patterns

- **Don't stuff long task content into the `/goal` argument.** Use a short condition; put work in files.
- **Don't make conditions the evaluator can't verify from the transcript.** "Tests pass" is wrong (evaluator can't run tests); "`SUPERGOAL_PHASE_DONE` printed for all phases" is right.
- **Don't chain `/goal` commands across sessions.** One run = one `/goal`. The agent loops internally inside that session.
- **Don't skip evidence to save space.** Files have no char budget — be exhaustive.
