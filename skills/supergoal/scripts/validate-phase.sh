#!/usr/bin/env bash
# validate-phase.sh — verify a phase spec has the required structure
#
# Usage: validate-phase.sh <path-to-phase-spec.md>
#
# Exits 0 if the file has the required markers and sections.
# Exits 1 with specific errors otherwise.

set -uo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: validate-phase.sh <path-to-phase-spec.md>" >&2
  exit 2
fi

f="$1"
if [[ ! -f "$f" ]]; then
  echo "validate-phase.sh: file not found: $f" >&2
  exit 2
fi

errors=0

check_marker() {
  local marker="$1"
  local label="$2"
  if ! grep -q "$marker" "$f"; then
    echo "❌ $f: missing $label ($marker)" >&2
    errors=$((errors + 1))
  fi
}

check_section() {
  local heading="$1"
  if ! grep -qi "^## $heading\|^\*\*$heading" "$f"; then
    echo "❌ $f: missing section: $heading" >&2
    errors=$((errors + 1))
  fi
}

# Required markers
check_marker "SUPERGOAL_PHASE_START" "phase-start marker"

# Required sections
check_section "Work"
check_section "Acceptance criteria"
check_section "Mandatory commands"
check_section "Evidence required"

# Sanity check: at least one criterion line
crits=$(grep -cE '^[[:space:]]*-' "$f" || true)
if [[ "$crits" -lt 3 ]]; then
  echo "⚠️  $f: only $crits bullet lines — acceptance criteria look thin" >&2
fi

if (( errors > 0 )); then
  echo "✗ $f: $errors structural error(s)" >&2
  exit 1
fi

lines=$(wc -l < "$f" | tr -d ' ')
echo "✓ $f: structure ok ($lines lines, $crits bullets)"
exit 0
