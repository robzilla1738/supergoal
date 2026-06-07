#!/usr/bin/env bash
# claim-run.test.sh — fixture tests for scripts/claim-run.sh
#
# Proves the per-run namespacing primitive that fixes the concurrent-overwrite bug:
# two `/supergoal` runs in the same working tree must never receive the same artifact
# directory. The headline assertion is the RACE test — N simultaneous claims with an
# identical slug must yield N distinct directories.
#
# Repo-only (not shipped in the plugin payload). Run from anywhere:
#   bash tests/claim-run.test.sh
# Exits 0 if every assertion passes, 1 otherwise.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CR="$REPO_ROOT/skills/supergoal/scripts/claim-run.sh"

if [ ! -f "$CR" ]; then
  echo "FATAL: claim-run.sh not found at $CR" >&2
  exit 1
fi

pass=0
fail=0
ok() { pass=$((pass + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
no() { fail=$((fail + 1)); printf '  \033[31m✗\033[0m %s\n      %s\n' "$1" "$2"; }

# run <cmd...> -> sets OUT (stdout only) and RC (exit code)
run() { OUT="$("$@" 2>/dev/null)"; RC=$?; }

assert_rc()       { if [ "$2" = "$RC" ]; then ok "$1"; else no "$1" "expected exit $2 got $RC (out: $OUT)"; fi; }
assert_contains() { case "$3" in *"$2"*) ok "$1";; *) no "$1" "[$3] missing substring [$2]";; esac; }
assert_missing()  { case "$3" in *"$2"*) no "$1" "[$3] unexpectedly contains [$2]";; *) ok "$1";; esac; }
assert_true()     { if [ "$2" -eq 1 ] 2>/dev/null || [ "$2" = "true" ]; then ok "$1"; else no "$1" "$3"; fi; }

# Each test runs in its own throwaway working directory so the repo is never touched.
new_workdir() { mktemp -d; }

echo "claim-run.test.sh — fixtures for $CR"
echo

# ---------------------------------------------------------------------------
echo "[1] Basic claim — creates a dir under .supergoal/ and prints exactly its path"
w="$(new_workdir)"; cd "$w" || exit 1
run bash "$CR" "Add dark mode toggle"
assert_rc "claim succeeds (exit 0)" 0
assert_contains "path is under .supergoal/" ".supergoal/" "$OUT"
assert_contains "slug derived from task" "add-dark-mode-toggle" "$OUT"
[ -d "$OUT" ] && ok "claimed path is a real directory" || no "claimed path is a real directory" "[$OUT] is not a dir"
lines="$(printf '%s\n' "$OUT" | grep -c .)"
assert_contains "prints a single line (no stray output)" "1" "$lines"
cd "$REPO_ROOT"; rm -rf "$w"

# ---------------------------------------------------------------------------
echo "[2] Two sequential claims of the SAME task -> two distinct dirs"
w="$(new_workdir)"; cd "$w" || exit 1
a="$(bash "$CR" "same task" 2>/dev/null)"
b="$(bash "$CR" "same task" 2>/dev/null)"
if [ -n "$a" ] && [ -n "$b" ] && [ "$a" != "$b" ]; then
  ok "identical-slug claims produce different dirs ($a != $b)"
else
  no "identical-slug claims produce different dirs" "a=[$a] b=[$b]"
fi
[ -d "$a" ] && [ -d "$b" ] && ok "both dirs exist" || no "both dirs exist" "a=[$a] b=[$b]"
cd "$REPO_ROOT"; rm -rf "$w"

# ---------------------------------------------------------------------------
echo "[3] RACE — N parallel claims of the SAME slug -> N distinct dirs (the bug)"
w="$(new_workdir)"; cd "$w" || exit 1
N=24
outdir="$(mktemp -d)"
i=1
while [ "$i" -le "$N" ]; do
  ( bash "$CR" "concurrent build" > "$outdir/$i" 2>/dev/null ) &
  i=$((i + 1))
done
wait
# Collect every claimed path; count the distinct, non-empty ones.
distinct="$(cat "$outdir"/* 2>/dev/null | grep -c . )"   # total lines emitted
unique="$(cat "$outdir"/* 2>/dev/null | sort -u | grep -c . )"
if [ "$distinct" = "$N" ] && [ "$unique" = "$N" ]; then
  ok "$N concurrent claims produced $N unique dirs (no collision)"
else
  no "$N concurrent claims produced $N unique dirs" "emitted=$distinct unique=$unique (want $N/$N)"
fi
# Every claimed path must be a real directory.
missing=0
while IFS= read -r p; do
  [ -n "$p" ] || continue
  [ -d "$p" ] || missing=$((missing + 1))
done < <(cat "$outdir"/* 2>/dev/null | sort -u)
if [ "$missing" -eq 0 ]; then ok "all claimed paths are real directories"; else no "all claimed paths are real directories" "$missing missing"; fi
rm -rf "$outdir"
cd "$REPO_ROOT"; rm -rf "$w"

# ---------------------------------------------------------------------------
echo "[4] Empty / whitespace task -> safe fallback slug, still unique"
w="$(new_workdir)"; cd "$w" || exit 1
run bash "$CR" ""
assert_rc "empty task still claims a dir" 0
assert_contains "empty task falls back to 'run-' prefix" ".supergoal/run-" "$OUT"
[ -d "$OUT" ] && ok "fallback dir exists" || no "fallback dir exists" "[$OUT]"
cd "$REPO_ROOT"; rm -rf "$w"

# ---------------------------------------------------------------------------
echo "[5] Garbage / symbol-only task -> sanitized, no path separators leak in"
w="$(new_workdir)"; cd "$w" || exit 1
run bash "$CR" '../../etc/passwd && rm -rf /  !!!'
assert_rc "garbage task still claims a dir" 0
assert_contains "result stays under .supergoal/" ".supergoal/" "$OUT"
# The slug portion (basename) must not contain path separators or spaces.
b="$(basename "$OUT")"
assert_missing "no slash escapes into the dir name" "/" "$b"
case "$b" in *" "*) no "no space in dir name" "[$b]";; *) ok "no space in dir name";; esac
[ -d "$OUT" ] && ok "garbage task dir exists exactly where claimed" || no "garbage task dir exists" "[$OUT]"
cd "$REPO_ROOT"; rm -rf "$w"

# ---------------------------------------------------------------------------
echo "[6] Creates .supergoal/ when it does not exist yet"
w="$(new_workdir)"; cd "$w" || exit 1
[ -e .supergoal ] && no "base absent at start" "found .supergoal already" || ok "base absent at start"
run bash "$CR" "first run"
assert_rc "claim succeeds with no pre-existing base" 0
[ -d .supergoal ] && ok ".supergoal/ created on demand" || no ".supergoal/ created on demand" "still absent"
cd "$REPO_ROOT"; rm -rf "$w"

# ---------------------------------------------------------------------------
echo "[7] Honours \$SUPERGOAL_BASE override"
w="$(new_workdir)"; cd "$w" || exit 1
OUT="$(SUPERGOAL_BASE="custom-runs" bash "$CR" "task" 2>/dev/null)"; RC=$?
assert_rc "override claim succeeds" 0
assert_contains "claims under the overridden base" "custom-runs/" "$OUT"
[ -d "$OUT" ] && ok "overridden base dir exists" || no "overridden base dir exists" "[$OUT]"
cd "$REPO_ROOT"; rm -rf "$w"

# ---------------------------------------------------------------------------
echo
echo "----------------------------------------"
printf 'Results: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "All fixture scenarios passed."
exit 0
