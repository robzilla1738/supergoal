#!/usr/bin/env bash
# detect-stack.sh — identify language, package manager, framework, build/test/lint commands
# Writes a compact markdown summary to stdout for the planning context.

set -uo pipefail

echo "# Stack context"
echo
echo "_Generated $(date '+%Y-%m-%d %H:%M:%S')_"
echo

# --- Language / framework signals ---
echo "## Language signals"

if [[ -f package.json ]]; then
  echo "- **Node/JS/TS** — package.json present"
  if command -v jq >/dev/null 2>&1; then
    name=$(jq -r '.name // "(unnamed)"' package.json)
    version=$(jq -r '.version // "?"' package.json)
    echo "  - Name: \`$name\`, version: \`$version\`"
    deps=$(jq -r '(.dependencies // {}) + (.devDependencies // {}) | keys[]' package.json 2>/dev/null | head -40)
    if [[ -n "$deps" ]]; then
      echo "  - Top dependencies: $(echo "$deps" | head -15 | tr '\n' ',' | sed 's/,$//' | sed 's/,/, /g')"
    fi
    # framework detection
    for fw in next react vue svelte solid astro nuxt remix express fastify nestjs hono; do
      if echo "$deps" | grep -qx "$fw"; then
        echo "  - Framework: **$fw**"
      fi
    done
  fi
fi

if [[ -f pyproject.toml || -f requirements.txt || -f setup.py ]]; then
  echo "- **Python** — pyproject.toml / requirements.txt / setup.py present"
  if [[ -f pyproject.toml ]] && grep -qE '\[tool\.poetry\]|\[tool\.uv\]|\[tool\.hatch\]' pyproject.toml 2>/dev/null; then
    grep -oE '\[tool\.[a-z]+\]' pyproject.toml | sort -u | sed 's/^/  - Build system: /'
  fi
fi

if [[ -f Cargo.toml ]]; then
  echo "- **Rust** — Cargo.toml present"
fi

if [[ -f go.mod ]]; then
  echo "- **Go** — go.mod present ($(head -1 go.mod | awk '{print $2}'))"
fi

if [[ -d "ios" && -f "ios/Podfile" ]] || ls *.xcodeproj >/dev/null 2>&1 || ls *.xcworkspace >/dev/null 2>&1; then
  echo "- **iOS/macOS (Swift)** — Xcode project present"
fi

if [[ -f "build.gradle" || -f "build.gradle.kts" || -f "settings.gradle" ]]; then
  echo "- **JVM / Android** — Gradle project"
fi

echo

# --- Package manager ---
echo "## Package manager"
if [[ -f pnpm-lock.yaml ]]; then
  echo "- **pnpm** (pnpm-lock.yaml)"
elif [[ -f yarn.lock ]]; then
  echo "- **yarn** (yarn.lock)"
elif [[ -f bun.lockb || -f bun.lock ]]; then
  echo "- **bun** (bun.lock)"
elif [[ -f package-lock.json ]]; then
  echo "- **npm** (package-lock.json)"
elif [[ -f uv.lock ]]; then
  echo "- **uv** (uv.lock)"
elif [[ -f poetry.lock ]]; then
  echo "- **poetry** (poetry.lock)"
elif [[ -f Pipfile.lock ]]; then
  echo "- **pipenv** (Pipfile.lock)"
elif [[ -f Cargo.lock ]]; then
  echo "- **cargo** (Cargo.lock)"
elif [[ -f go.sum ]]; then
  echo "- **go modules** (go.sum)"
else
  echo "- _none detected_"
fi
echo

# --- Scripts / commands ---
echo "## Likely commands"
if [[ -f package.json ]] && command -v jq >/dev/null 2>&1; then
  echo "From package.json scripts:"
  jq -r '.scripts // {} | to_entries[] | "- `\(.key)` → `\(.value)`"' package.json 2>/dev/null | head -25
fi
if [[ -f Makefile ]]; then
  echo
  echo "Makefile targets:"
  grep -E '^[a-zA-Z][a-zA-Z0-9_-]*:' Makefile | sed 's/:.*//' | sort -u | head -20 | sed 's/^/- `/' | sed 's/$/`/'
fi
echo

# --- Git ---
echo "## Git"
if [[ -d .git ]]; then
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "?")
  remote=$(git config --get remote.origin.url 2>/dev/null || echo "(no remote)")
  ahead=$(git rev-list --count HEAD ^origin/HEAD 2>/dev/null || echo "?")
  dirty=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  echo "- Branch: \`$branch\`"
  echo "- Remote: $remote"
  echo "- Working tree: ${dirty} files changed"
else
  echo "- Not a git repo"
fi
echo

# --- Test / lint heuristics ---
echo "## Test / lint heuristics"
if [[ -f package.json ]] && command -v jq >/dev/null 2>&1; then
  scripts=$(jq -r '.scripts // {} | keys[]' package.json 2>/dev/null)
  for key in build typecheck "type-check" test lint check ci dev start; do
    if echo "$scripts" | grep -qx "$key"; then
      echo "- Has script: \`$key\`"
    fi
  done
fi
if [[ -f .eslintrc.* || -f eslint.config.* ]]; then echo "- ESLint config present"; fi
if [[ -f .prettierrc* ]]; then echo "- Prettier config present"; fi
if [[ -f tsconfig.json ]]; then echo "- TypeScript present (tsconfig.json)"; fi
if [[ -f pytest.ini || -f conftest.py ]] || (grep -q 'pytest' pyproject.toml 2>/dev/null); then echo "- pytest detected"; fi
if [[ -f .swiftlint.yml ]]; then echo "- SwiftLint config present"; fi
echo

echo "_End stack context._"
