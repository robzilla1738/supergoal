#!/usr/bin/env bash
# summarize-repo.sh — compressed repo map for planning context
# Writes markdown to stdout.

set -uo pipefail

echo "# Repo map"
echo
echo "_Generated $(date '+%Y-%m-%d %H:%M:%S')_"
echo

# --- High level shape ---
echo "## Top-level layout"
ls -A1 2>/dev/null | grep -v "^\." | head -40 | sed 's/^/- /'
echo

# --- Source dirs ---
echo "## Source directories (depth 2)"
# Show directories under common source roots
for root in src app lib pages components server api packages apps; do
  if [[ -d "$root" ]]; then
    echo "### \`$root/\`"
    find "$root" -maxdepth 2 -mindepth 1 -type d 2>/dev/null | head -30 | sed 's/^/- /'
    echo
  fi
done

# --- File counts by extension (top extensions only) ---
echo "## File counts (top extensions)"
if [[ -d .git ]]; then
  git ls-files 2>/dev/null | awk -F. 'NF>1 {ext=$NF; if(length(ext)<=6) c[ext]++} END {for(e in c) print c[e], e}' | sort -rn | head -10 | awk '{print "- `."$2"`: "$1" files"}'
else
  find . -type f \( -not -path './node_modules/*' -not -path './.git/*' -not -path './dist/*' -not -path './build/*' \) 2>/dev/null | awk -F. 'NF>1 {ext=$NF; if(length(ext)<=6) c[ext]++} END {for(e in c) print c[e], e}' | sort -rn | head -10 | awk '{print "- `."$2"`: "$1" files"}'
fi
echo

# --- Largest source files (signal of complexity hotspots) ---
echo "## Largest source files (top 15 by line count)"
if [[ -d .git ]]; then
  git ls-files 2>/dev/null | grep -Ev '\.(json|lock|yaml|yml|md|svg|png|jpg|jpeg|gif|webp|woff2?|ttf|otf|map|min\.js|min\.css)$' | while read -r f; do
    [[ -f "$f" ]] && wc -l "$f" 2>/dev/null
  done | sort -rn | head -15 | awk '{print "- `"$2"` ("$1" lines)"}'
fi
echo

# --- Tests presence ---
echo "## Test surface"
test_count=0
for pat in 'test' 'tests' '__tests__' 'spec' 'specs'; do
  count=$(find . -type d -name "$pat" -not -path './node_modules/*' -not -path './.git/*' 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$count" -gt 0 ]]; then
    echo "- Directories named \`$pat\`: $count"
    test_count=$((test_count + count))
  fi
done
test_files=$(find . -type f \( -name '*.test.*' -o -name '*.spec.*' -o -name 'test_*.py' -o -name '*_test.go' \) -not -path './node_modules/*' -not -path './.git/*' 2>/dev/null | wc -l | tr -d ' ')
echo "- Test files (by name pattern): $test_files"
echo

# --- Config & infra files ---
echo "## Notable config / infra"
for f in tsconfig.json next.config.* vite.config.* webpack.config.* tailwind.config.* postcss.config.* eslint.config.* .eslintrc.* prettier.config.* .prettierrc* jest.config.* vitest.config.* playwright.config.* cypress.config.* drizzle.config.* prisma/schema.prisma schema.prisma turbo.json nx.json lerna.json pnpm-workspace.yaml docker-compose.* Dockerfile* .github/workflows .gitlab-ci.yml fly.toml vercel.json netlify.toml wrangler.toml; do
  for match in $f; do
    [[ -e "$match" ]] && echo "- \`$match\`"
  done
done | sort -u
echo

# --- Recent activity (signal of where things are in flux) ---
echo "## Recent activity (last 10 commits)"
if [[ -d .git ]]; then
  git log --no-merges --pretty=format:"- \`%h\` %ad %s" --date=short -10 2>/dev/null
  echo
  echo
  echo "## Files churned in last 20 commits (top 10)"
  git log --no-merges --name-only --pretty=format: -20 2>/dev/null | grep -v '^$' | sort | uniq -c | sort -rn | head -10 | awk '{print "- `"$2"` ("$1"×)"}'
fi
echo

echo "_End repo map._"
