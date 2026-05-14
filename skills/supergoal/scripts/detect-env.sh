#!/usr/bin/env bash
# detect-env.sh — environment recon for greenfield Supergoal runs
# Writes markdown to stdout.

set -uo pipefail

echo "# Environment context (greenfield)"
echo
echo "_Generated $(date '+%Y-%m-%d %H:%M:%S')_"
echo

echo "## CWD"
echo "- \`$(pwd)\`"
echo "- Contents: $(ls -A1 2>/dev/null | wc -l | tr -d ' ') entries"
ls -A1 2>/dev/null | head -10 | sed 's/^/  - /'
echo

echo "## System"
echo "- OS: $(uname -srm)"
echo "- Shell: \`$SHELL\`"
echo "- User: $USER"
echo

echo "## Toolchains available"
for tool in node npm pnpm yarn bun deno python python3 uv poetry pip go cargo rustc swift xcrun docker make git gh; do
  if command -v "$tool" >/dev/null 2>&1; then
    version=$("$tool" --version 2>/dev/null | head -1)
    echo "- \`$tool\` — $version"
  fi
done
echo

echo "## Git"
git_user=$(git config --global user.name 2>/dev/null || echo "(unset)")
git_email=$(git config --global user.email 2>/dev/null || echo "(unset)")
echo "- Configured user: $git_user <$git_email>"
echo

if command -v gh >/dev/null 2>&1; then
  echo "## GitHub CLI"
  if gh auth status >/dev/null 2>&1; then
    echo "- Authenticated"
  else
    echo "- Not authenticated"
  fi
fi
echo

echo "_End environment context._"
