#!/usr/bin/env bash
# repo-state.test.sh — fixture tests for scripts/repo-state.sh
#
# Exercises the canonical "complete working-tree state vs baseline" comparison
# (see references/repo-state-comparison.md) against throwaway git repositories,
# one per scenario. Proves the audit/cleanliness logic sees committed, staged,
# unstaged, deleted, and untracked work — not just commits — and degrades
# safely when the baseline is missing/invalid.
#
# Repo-only (not shipped in the plugin payload). Run from anywhere:
#   bash tests/repo-state.test.sh
# Exits 0 if every assertion passes, 1 otherwise.

set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RS="$REPO_ROOT/skills/supergoal/scripts/repo-state.sh"

if [ ! -f "$RS" ]; then
  echo "FATAL: repo-state.sh not found at $RS" >&2
  exit 1
fi

pass=0
fail=0
ok()  { pass=$((pass + 1)); printf '  \033[32m✓\033[0m %s\n' "$1"; }
no()  { fail=$((fail + 1)); printf '  \033[31m✗\033[0m %s\n      %s\n' "$1" "$2"; }

# run <cmd...> -> sets OUT (stdout+stderr) and RC (exit code)
run() { OUT="$("$@" 2>&1)"; RC=$?; }

assert_eq()       { if [ "$2" = "$3" ]; then ok "$1"; else no "$1" "expected [$2] got [$3]"; fi; }
assert_rc()       { if [ "$2" = "$RC" ]; then ok "$1"; else no "$1" "expected exit $2 got $RC (out: $OUT)"; fi; }
assert_contains() { case "$3" in *"$2"*) ok "$1";; *) no "$1" "[$3] missing substring [$2]";; esac; }
assert_missing()  { case "$3" in *"$2"*) no "$1" "[$3] unexpectedly contains [$2]";; *) ok "$1";; esac; }

# mk_repo -> prints path to a fresh repo whose baseline commit holds:
#   keep.txt, src/existing.ts, "dir with space/old file.ts"
mk_repo() {
  local d
  d="$(mktemp -d)"
  (
    cd "$d" || exit 1
    git init -q
    git config user.email t@example.com
    git config user.name tester
    git config commit.gpgsign false
    git config core.autocrlf false   # deterministic line endings inside the fixture
    git config core.safecrlf false
    mkdir -p src "dir with space"
    printf 'baseline\n' > keep.txt
    printf 'export const existing = 1\n' > src/existing.ts
    printf 'old\n' > "dir with space/old file.ts"
    git add -A
    git commit -qm baseline
  ) >/dev/null 2>&1
  echo "$d"
}
base_of() { ( cd "$1" && git rev-parse HEAD ); }
cleanup() { [ -n "${1:-}" ] && rm -rf "$1"; }

echo "repo-state.test.sh — fixtures for $RS"
echo

# ---------------------------------------------------------------------------
echo "[1] Clean repository (no changes since baseline)"
d="$(mk_repo)"; b="$(base_of "$d")"; cd "$d" || exit 1
run "$RS" changed-files "$b";            assert_eq "changed-files is empty"            "" "$OUT"
run "$RS" added-lines "$b";              assert_eq "added-lines is empty"             "" "$OUT"
run "$RS" deliverable "$b" src/existing.ts
assert_rc  "existing unchanged file -> exit 0" 0
assert_contains "existing file reported present" "present" "$OUT"
run "$RS" deliverable "$b" src/never.ts
assert_rc  "absent deliverable -> exit 1" 1
assert_eq  "absent deliverable prints 'missing'" "missing" "$OUT"
cd "$REPO_ROOT"; cleanup "$d"

# ---------------------------------------------------------------------------
echo "[2] Modified tracked file, NOT committed (the core bug)"
d="$(mk_repo)"; b="$(base_of "$d")"; cd "$d" || exit 1
printf 'console.log("dbg")\n' >> src/existing.ts          # unstaged modification + a debug print
run "$RS" deliverable "$b" src/existing.ts
assert_rc  "modified-uncommitted -> present (exit 0)" 0
assert_contains "evidence proves a real diff (not exists-only)" "changed vs baseline" "$OUT"
run "$RS" added-lines "$b"
assert_contains "added-lines surfaces the uncommitted debug print" "console.log" "$OUT"
run "$RS" changed-files "$b"
assert_contains "changed-files lists the modified file" "src/existing.ts" "$OUT"
cd "$REPO_ROOT"; cleanup "$d"

# ---------------------------------------------------------------------------
echo "[3] Staged tracked file (in index, not committed)"
d="$(mk_repo)"; b="$(base_of "$d")"; cd "$d" || exit 1
printf 'export const staged = 2\n' > src/staged.ts
git add src/staged.ts
run "$RS" deliverable "$b" src/staged.ts
assert_rc  "staged new file -> present (exit 0)" 0
assert_contains "staged file present" "present" "$OUT"
assert_contains "staged evidence proves a real diff (not exists-only)" "changed vs baseline" "$OUT"
run "$RS" changed-files "$b"
assert_contains "changed-files lists the staged file" "src/staged.ts" "$OUT"
cd "$REPO_ROOT"; cleanup "$d"

# ---------------------------------------------------------------------------
echo "[4] New untracked deliverable (never git add-ed)"
d="$(mk_repo)"; b="$(base_of "$d")"; cd "$d" || exit 1
printf 'export const fresh = 3\nconsole.log("u")\n' > src/untracked.ts
run "$RS" deliverable "$b" src/untracked.ts
assert_rc  "untracked deliverable -> present (exit 0)" 0
assert_contains "untracked deliverable flagged as untracked" "untracked" "$OUT"
run "$RS" added-lines "$b"
assert_contains "added-lines includes untracked file body (cleanliness)" "console.log" "$OUT"
run "$RS" changed-files "$b"
assert_contains "changed-files lists the untracked file" "src/untracked.ts" "$OUT"
cd "$REPO_ROOT"; cleanup "$d"

# ---------------------------------------------------------------------------
echo "[5] Deleted tracked file (deletion is the deliverable)"
d="$(mk_repo)"; b="$(base_of "$d")"; cd "$d" || exit 1
rm -f src/existing.ts
run "$RS" deliverable "$b" src/existing.ts
assert_rc  "deleted-since-baseline -> present (exit 0)" 0
assert_contains "evidence shows it changed vs baseline" "changed vs baseline" "$OUT"
run "$RS" changed-files "$b"
assert_contains "changed-files lists the deleted path" "src/existing.ts" "$OUT"
cd "$REPO_ROOT"; cleanup "$d"

# ---------------------------------------------------------------------------
echo "[6] Changes committed AFTER baseline"
d="$(mk_repo)"; b="$(base_of "$d")"; cd "$d" || exit 1
printf 'export const shipped = 4\n' > src/committed.ts
git add src/committed.ts && git commit -qm "after baseline"
run "$RS" deliverable "$b" src/committed.ts
assert_rc  "committed-after-baseline -> present (exit 0)" 0
assert_contains "evidence shows the diff" "changed vs baseline" "$OUT"
cd "$REPO_ROOT"; cleanup "$d"

# ---------------------------------------------------------------------------
echo "[7] Paths containing spaces"
d="$(mk_repo)"; b="$(base_of "$d")"; cd "$d" || exit 1
printf 'new\n' > "dir with space/new file.ts"            # untracked, spaced
printf 'edit\n' >> "dir with space/old file.ts"          # modified tracked, spaced
run "$RS" deliverable "$b" "dir with space/new file.ts"
assert_rc  "spaced untracked path -> present" 0
assert_contains "spaced untracked flagged untracked" "untracked" "$OUT"
run "$RS" deliverable "$b" "dir with space/old file.ts"
assert_rc  "spaced modified path -> present" 0
assert_contains "spaced modified shows diff" "changed vs baseline" "$OUT"
run "$RS" changed-files "$b"
assert_contains "changed-files keeps spaced path intact" "dir with space/new file.ts" "$OUT"
cd "$REPO_ROOT"; cleanup "$d"

# ---------------------------------------------------------------------------
echo "[8] Invalid / unavailable baseline (graceful filesystem fallback)"
d="$(mk_repo)"; cd "$d" || exit 1
printf 'x\n' > src/fallback.ts
# 8a: literal sentinel from a non-git run
run "$RS" deliverable "no-git" src/fallback.ts
assert_rc  "no-git sentinel, file exists -> present" 0
assert_contains "fallback notes baseline unavailable" "baseline unavailable" "$OUT"
run "$RS" deliverable "no-git" src/ghost.ts
assert_rc  "no-git sentinel, file absent -> missing" 1
# 8b: a syntactically-valid sha that doesn't exist in this repo
run "$RS" deliverable "0000000000000000000000000000000000000000" src/existing.ts
assert_rc  "bogus sha, file exists -> present (no crash)" 0
assert_contains "bogus sha falls back" "baseline unavailable" "$OUT"
# 8c: running outside any git repo at all
od="$(mktemp -d)"; cd "$od" || exit 1
printf 'hi\n' > here.txt
run "$RS" deliverable "$(printf 'deadbeef')" here.txt
assert_rc  "non-repo dir, file exists -> present" 0
run "$RS" deliverable "anything" gone.txt
assert_rc  "non-repo dir, file absent -> missing" 1
cd "$REPO_ROOT"; cleanup "$d"; cleanup "$od"

# ---------------------------------------------------------------------------
echo "[9] Shell scripts checked out with LF endings (.gitattributes)"
ga="$REPO_ROOT/.gitattributes"
if [ -f "$ga" ]; then
  if grep -Eq '^\*\.sh[[:space:]]+text[[:space:]]+eol=lf' "$ga"; then
    ok ".gitattributes forces '*.sh text eol=lf'"
  else
    no ".gitattributes forces '*.sh text eol=lf'" "rule not found in $ga"
  fi
else
  no ".gitattributes present" "$ga not found"
fi
# The attribute must actually resolve to eol=lf for a real script...
run git -C "$REPO_ROOT" check-attr eol -- skills/supergoal/scripts/repo-state.sh
assert_contains "git resolves repo-state.sh eol attr to lf" "eol: lf" "$OUT"
# ...and no shell script may carry CR bytes in the working tree.
crlf_hits=""
while IFS= read -r f; do
  if LC_ALL=C grep -qU $'\r' "$f" 2>/dev/null; then crlf_hits="$crlf_hits $f"; fi
done < <(find "$REPO_ROOT" -name '*.sh' -not -path '*/.git/*' 2>/dev/null)
if [ -z "$crlf_hits" ]; then
  ok "no tracked *.sh contains CR bytes (LF endings)"
else
  no "no tracked *.sh contains CR bytes (LF endings)" "CRLF in:$crlf_hits"
fi

# ---------------------------------------------------------------------------
echo "[10] .gitignore'd file (excluded from untracked detection by --exclude-standard)"
d="$(mk_repo)"; b="$(base_of "$d")"; cd "$d" || exit 1
printf 'ignored/\n' > .gitignore
git add .gitignore && git commit -qm gitignore
b="$(base_of "$d")"   # rebase baseline past the .gitignore commit
mkdir -p ignored
printf 'export const ig = 1\nconsole.log("ignored debug")\n' > ignored/artifact.ts
run "$RS" deliverable "$b" ignored/artifact.ts
assert_rc  "ignored file that exists -> present (exit 0)" 0
assert_contains "ignored file uses exists-fallback, NOT untracked" "exists, unchanged" "$OUT"
assert_missing "ignored file is not mislabelled untracked" "untracked" "$OUT"
run "$RS" changed-files "$b"
assert_missing "changed-files excludes the ignored file" "ignored/artifact.ts" "$OUT"
run "$RS" added-lines "$b"
assert_missing "added-lines excludes ignored debug output" "ignored debug" "$OUT"
cd "$REPO_ROOT"; cleanup "$d"

# ---------------------------------------------------------------------------
echo "[11] Renamed tracked file (delete old path + add new path)"
d="$(mk_repo)"; b="$(base_of "$d")"; cd "$d" || exit 1
git mv src/existing.ts src/renamed.ts
run "$RS" deliverable "$b" src/renamed.ts
assert_rc  "renamed-to path -> present (exit 0)" 0
assert_contains "renamed-to path shows a diff" "changed vs baseline" "$OUT"
run "$RS" deliverable "$b" src/existing.ts
assert_rc  "renamed-from path -> present as a change (deletion)" 0
run "$RS" changed-files "$b"
assert_contains "changed-files lists the new name" "src/renamed.ts" "$OUT"
cd "$REPO_ROOT"; cleanup "$d"

# ---------------------------------------------------------------------------
echo
echo "----------------------------------------"
printf 'Results: %d passed, %d failed\n' "$pass" "$fail"
if [ "$fail" -gt 0 ]; then
  exit 1
fi
echo "All fixture scenarios passed."
exit 0
