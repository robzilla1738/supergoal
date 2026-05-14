# Supergoal execution protocol

This file is read by the executing agent at the start of the single `/goal` session and followed throughout. It is the operating manual for the autonomous run.

## The loop

Repeat until `SUPERGOAL_RUN_COMPLETE` is printed:

1. Read `.supergoal/STATE.md`. Find `Current phase: N`.
2. Read `.supergoal/phases/phase-N.md`. This is your full work spec.
3. Print `SUPERGOAL_PHASE_START` with the spec's metadata (phase number, name, task, mandatory commands, acceptance count, evidence types, dependencies).
4. Do the work described in the spec. Run mandatory commands. Surface evidence into the transcript (command output last ~10 lines + exit code; file listings; key diff excerpts).
5. Print `SUPERGOAL_PHASE_VERIFY`: each acceptance criterion `pass|fail` with evidence; engineering checks (build/typecheck/lint/tests); files changed count; notable diff one-liners.
6. **Memory writeback check.** Anything non-obvious learned this phase? If yes, write a memory file under the detected MEM_DIR (frontmatter: `name`, `description`, `metadata.type` of `feedback`/`project`/`reference`/`user`); link it from `MEMORY.md`. Print `MEMORY_SAVED: <name>` or `MEMORY_SAVED: none`.
7. Print `SUPERGOAL_PHASE_DONE`. Update `STATE.md`: mark phase N completed; set `Current phase: N+1`; bump `Last update` timestamp; append a one-line event.
8. **User-interrupt check.** If a user message has arrived since the last turn, pause; address the message; ask before resuming.
9. If N < total phases: continue with phase N+1 (back to step 1).
10. If N == total: print `SUPERGOAL_RUN_COMPLETE` with a 5-line summary. The `/goal` condition is now satisfied.

## Failure recovery (3-strike)

### First failure of any acceptance criterion

1. Print `FAILURE_PROBE` (phase, failed criterion, what was tried, root-cause hypothesis).
2. Append the probe to `.supergoal/STATE.md` failure log.
3. **Auto-retry the same phase once.** Inject the probe as a "Previous attempt failed because: …" preamble. Do not advance.

### Second failure (auto-retry also failed)

1. Print `FAILURE_ESCALATE`.
2. Write a focused **fix spec** at `.supergoal/phases/phase-N.fix.md`. The fix spec:
   - Targets only the failing criterion.
   - Forbids scope creep ("do not touch unrelated files").
   - Ends with the original phase's VERIFY block as the success gate.
3. Execute the fix spec inline (same agent, same `/goal` — no new dispatch).
4. On fix success: re-run the original phase's VERIFY; on pass, advance to N+1.
5. On fix failure: proceed to third-failure handling.

### Third failure (fix spec also failed)

1. Print `FAILURE_HANDOFF`: failing criterion, full probe history (three attempts), suggested next move.
2. Update `STATE.md`: `Status: BLOCKED`.
3. Stop attempting. The user takes the wheel. The `/goal` condition will not be satisfied; surface the handoff clearly so the host evaluator and user both see it.

## Mid-run interruption

If the user sends any message during the run:
- Pause at the next phase boundary (after `SUPERGOAL_PHASE_DONE`, before reading the next spec).
- Address the message.
- Ask whether to resume, revise the next phase spec, or stop.

## Memory writeback rules

See `memory_writeback_rules` section in SKILL.md. Short version:

- Save anything non-obvious a future Supergoal run on a similar task would benefit from.
- Frontmatter: `name`, `description`, `metadata.type` (feedback / project / reference / user).
- Link from `MEMORY.md`.
- Final phase always writes a `project_<slug>.md` memory.
- Never save secrets, transient task details, or ephemeral state.

## Required transcript blocks

See `references/goal-format.md` for the exact format of:
- `SUPERGOAL_PHASE_START`
- `SUPERGOAL_PHASE_VERIFY`
- `MEMORY_SAVED`
- `SUPERGOAL_PHASE_DONE`
- `SUPERGOAL_RUN_COMPLETE`
- `FAILURE_PROBE` / `FAILURE_ESCALATE` / `FAILURE_HANDOFF`
