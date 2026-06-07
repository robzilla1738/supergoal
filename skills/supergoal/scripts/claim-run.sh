#!/usr/bin/env bash
# claim-run.sh — atomically claim a unique per-run artifact directory under .supergoal/.
#
# Why this exists
# ---------------
# Two `/supergoal` runs started in the same working tree both defaulted to a flat
# `.supergoal/` directory and clobbered each other's STATE.md / ROADMAP.md / phases/.
# The fix: every run claims its OWN namespaced subdirectory. `mktemp -d` creates the
# directory and claims the name in a single atomic step, failing if it already exists,
# so two simultaneous callers can never receive the same path. That removes the
# check-then-write race that caused the overwrite — even when both runs slugify to the
# same prefix, the random suffix keeps them distinct.
#
# This namespacing protects the PLANNING artifacts. It does NOT make two `/goal`
# executions in the same working tree safe — they still edit the same source files.
# For true parallel execution, use a separate `git worktree` per task.
#
# Usage:
#   claim-run.sh "<task description>"   -> prints the claimed run-root path on stdout,
#                                          e.g.  .supergoal/add-dark-mode-Ab3Kx9
#
# Nothing but the path is printed, so callers can capture it directly:
#   SUPERGOAL_ROOT="$(bash claim-run.sh "$ARGUMENTS")"
#
# Honours $SUPERGOAL_BASE (default ".supergoal") as the parent directory.

set -u

base="${SUPERGOAL_BASE:-.supergoal}"

# Slugify the task for a human-readable prefix: lowercase, every non-[a-z0-9] run becomes
# a single '-', trim leading/trailing '-', cap at 40 chars (then re-trim a dangling '-').
# Purely cosmetic — uniqueness comes from mktemp's suffix, not the slug.
slug="$(printf '%s' "${1:-}" \
  | tr '[:upper:]' '[:lower:]' \
  | tr -c 'a-z0-9' '-' \
  | sed -E 's/-+/-/g; s/^-//; s/-$//' \
  | cut -c1-40 \
  | sed -E 's/-$//')"
[ -n "$slug" ] || slug="run"

mkdir -p "$base" || { echo "claim-run.sh: cannot create base dir '$base'" >&2; exit 1; }

# mktemp -d is the load-bearing primitive: atomic create-or-fail under $base.
runroot="$(mktemp -d "$base/${slug}-XXXXXX" 2>/dev/null)" || {
  echo "claim-run.sh: mktemp failed to claim a run dir under '$base'" >&2; exit 1; }

printf '%s\n' "$runroot"
