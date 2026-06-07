# Repository-state comparison — the one strategy

Both the **final audit's deliverable check** and the **per-phase cleanliness check** ask the
same question: *what changed in this repository since the run started?* This is the single,
canonical answer. Everything else (PROTOCOL.md, SKILL.md, goal-format.md, phase-design.md)
defers to it.

## The trap: `git diff <baseline>..HEAD`

A two-dot range compares two **commits**. An autonomous Supergoal run frequently leaves its
work **uncommitted** — staged, unstaged, or brand-new untracked files. Against an uncommitted
run, `git diff <baseline>..HEAD` is **empty**:

- the deliverable check would report shipped files as "missing"; and
- the cleanliness greps would report "0 debug prints / 0 TODOs / 0 dead imports" no matter what
  was actually written.

The baseline (`Baseline ref:` in `<run-root>/STATE.md`) is captured at Stage 7 dispatch, before
any phase runs. By completion the working tree — not just `HEAD` — holds the result. So the
comparison must be **baseline → working tree**, not **baseline → HEAD**.

## The strategy: complete working-tree state vs baseline

| What | How | Captures |
|------|-----|----------|
| Tracked changes | `git diff <baseline>` (single revision — **no** `..HEAD`) | committed, staged, unstaged, **and** deleted tracked files |
| Untracked files | `git ls-files --others --exclude-standard` | brand-new deliverables never `git add`-ed |
| Invalid/unavailable baseline | filesystem existence (`-e`, `git ls-files`) | `no-git` sentinel, bogus sha, or non-repo dir |

`git diff <baseline>` (a single revision argument) diffs the **working tree** against the
baseline commit, so it already folds in staged + unstaged changes *and* any commits made after
the baseline. Untracked files are diff-invisible, so they are detected **separately** and on
purpose. When the baseline cannot be resolved to a commit, every check degrades to "does the
path exist now?" — coverage drops to existence-only, which the audit should surface honestly.

**Ignored files are intentionally out of scope of untracked detection.** `--exclude-standard`
honours `.gitignore`, so a `.gitignore`'d file is *not* reported as an untracked deliverable and
its body is *not* fed to the cleanliness greps via `added-lines`. This is deliberate — ignored
paths are usually ephemeral build output or logs, not shipping artifacts. Two consequences worth
knowing: (a) an ignored deliverable still reads `present` via the existence fallback (it exists
on disk), just not flagged `untracked new file`; (b) debug output that lives *only* in an ignored
file escapes the cleanliness count — if a phase legitimately ships such output and wants it
inspected, declare a `Cleanliness override:` in the phase spec rather than relying on the greps.

## The implementation: `scripts/repo-state.sh`

Don't hand-type the git incantations — the single-revision-vs-range distinction is exactly the
bug this exists to prevent. Use the helper, which encapsulates the table above and never mutates
the repo or index. At Stage 7 it is copied next to `PROTOCOL.md` into `<run-root>/` (this run's
namespaced artifact dir, e.g. `.supergoal/add-dark-mode-Ab3Kx9`), so the `/goal` session invokes
it as `bash <run-root>/repo-state.sh`.

```
bash <run-root>/repo-state.sh deliverable   <baseline> <path>
    -> "present — <evidence>" (exit 0) | "missing" (exit 1)
       evidence distinguishes: changed vs baseline / untracked new file /
       exists-unchanged / baseline-unavailable

bash <run-root>/repo-state.sh changed-files <baseline>
    -> newline-delimited paths changed since baseline (tracked + untracked + deleted)

bash <run-root>/repo-state.sh added-lines   <baseline>
    -> every added/new line since baseline: tracked-diff '+' lines plus the full body
       of each untracked file. Pipe to grep for cleanliness counts.
```

Quote path arguments — deliverable paths may contain spaces.

### Audit deliverable check

For each `**Deliverables:**` bullet that names a path/glob:

```
bash <run-root>/repo-state.sh deliverable "$(baseline)" "<path>"
```

`missing` (exit 1) → `AUDIT_GAP: phase <N> deliverable "<bullet>" not present in working tree or diff`.

### Per-phase cleanliness check

```
bash <run-root>/repo-state.sh added-lines "$(baseline)" > /tmp/sg-added
grep -cE 'console\.log|console\.error' /tmp/sg-added   # JS/TS debug prints (adjust per stack)
grep -cE '\b(TODO|FIXME|XXX)\b'        /tmp/sg-added   # session TODO/FIXME added
# dead imports: inspect added import lines for usage in their file
```

Because `added-lines` includes untracked file bodies, debug prints in a freshly-created,
never-committed file are caught too — the case the old `..HEAD` grep missed entirely.

## Backward compatibility

The transcript markers (`SUPERGOAL_PHASE_VERIFY` cleanliness section, `AUDIT_VERIFY`
`Deliverables:` block, `AUDIT_GAP`, `AUDIT_COMPLETE`) and the 3-strike semantics are unchanged.
Only the *source of truth* moved from a commit range to the complete working tree, and untracked
detection was added. A deliverable that merely exists unchanged still reads as `present`, exactly
as the old `ls`/`git ls-files` fallback did.

## Line endings (cross-platform)

`repo-state.sh` and every other `*.sh` are forced to LF via `.gitattributes` (`*.sh text eol=lf`).
On Windows with `core.autocrlf=true`, a CRLF shebang (`#!/usr/bin/env bash␍`) yields a "bad
interpreter" failure, so LF is mandatory for these scripts to run. `eol=lf` overrides
`core.autocrlf` per-path, so consumers get LF regardless of their global git config.
