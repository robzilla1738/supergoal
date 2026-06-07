# State: {{TASK_TITLE}}

**Status:** PLANNING → IN_PROGRESS → COMPLETE
**Current phase:** —
**Started:** {{DATE}}
**Last update:** {{DATE}}
**Run root:** {{RUN_ROOT}}    <!-- this run's namespaced artifact dir under .supergoal/ (e.g. .supergoal/add-dark-mode-Ab3Kx9); isolates concurrent runs in the same working tree -->
**Baseline ref:** {{BASELINE_SHA}}    <!-- HEAD sha captured at Stage 7 dispatch; the audit + cleanliness checks compare the COMPLETE working tree (committed + staged + unstaged + untracked) against it via repo-state.sh -->


## Phase progress

| # | Phase | Status | Started | Completed | Notes |
|---|-------|--------|---------|-----------|-------|
| 1 | {{P1_NAME}} | pending | — | — | — |
| 2 | {{P2_NAME}} | pending | — | — | — |
| ... | ... | pending | — | — | — |
| N | Polish & Harden | pending | — | — | — |

## Engineering check status

Updated by each phase as it runs. Cleared at the start of the next phase, so this always reflects the **most recent** engineering check.

- Build: —
- Typecheck: —
- Lint: —
- Tests: —

## Notable events

Append-only log of anything noteworthy that happened during execution (assumption corrected mid-run, retry, manual intervention, etc.). Each phase writes a line here.

- {{DATE}} — Plan locked, {{N}} phases.
- ...

## Failure log

If a phase hits FAILURE_PROBE, record it here:

- Phase {{N}} ({{NAME}}): {{WHAT_FAILED}} — {{WHAT_WAS_TRIED}} — {{NEXT_MOVE}}
