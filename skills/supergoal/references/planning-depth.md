# Planning Depth — the bar to clear

A plan deserves the "Super" prefix when, reading it cold, a competent engineer could:

1. **Predict every file that will be created or touched.** Not exhaustively listed, but at the right granularity ("auth middleware in `lib/auth/`, new `/api/auth/*` routes, sign-in/up pages under `app/auth/`").
2. **Name the top 3 things that could go wrong** and what we're doing about each.
3. **Verify each phase independently** without reading the next one.
4. **Tell you what "done" looks like** in measurable terms, not vibes.

If any of those four are weak, do more thinking before writing the roadmap.

## Things to think about, by task type

### Greenfield projects
- Stack choice and **why** — not just "Next.js" but "Next.js because we need SSR for SEO and the team knows React"
- Initial directory structure
- What's deferred to later (auth, deployment, CI, monitoring) and why that's safe
- First-run experience (`npm run dev` should work after phase 1)

### Brownfield features
- What existing patterns/conventions the new code must match
- What it shares with existing features (extract before adding?)
- Migration story if data model changes
- Backwards compatibility surface

### Bug fixes
- The actual root cause, not just the symptom
- What tests would have caught this (and should now exist)
- Whether the fix needs to be applied in multiple places
- Regression surface — what else uses this code path

### Refactors
- The current pain (concrete, not abstract — "ChatRoom.tsx is 1400 lines and 4 people edited it last sprint")
- The destination state
- The intermediate states (each phase should leave the codebase in a buildable state)
- What stays out of scope (resist the urge to clean up adjacent code)

### UI work
- Reference designs / inspiration — find or ask for them
- Existing design tokens (colors, spacing, typography) — match, don't reinvent
- Responsive breakpoints in scope
- Accessibility: keyboard, screen reader, focus states, contrast
- Empty / loading / error states (these are 60% of "polish")

## Best practices research

Use Context7 (`mcp__claude_ai_Context7__resolve-library-id` → `query-docs`) for:
- Library APIs the plan depends on (especially anything that's evolved recently — auth, payments, AI SDKs)
- Framework patterns (RSC vs client components, server actions, etc.)
- CLI tools and their flags

Use WebSearch for:
- Security patterns (auth, secrets, sanitization)
- Industry conventions for the domain
- Known pitfalls ("Stripe webhook idempotency", "Clerk middleware ordering")

Don't research what you already know cold. Don't ship a plan against a library you haven't checked the current shape of.

## The risk list

Three risks, ranked. For each:
- **What could go wrong**
- **How likely** (gut estimate is fine)
- **What we're doing about it** (mitigation in the plan, or accepted risk with reason)

If you can't name three plausible risks, the task is either too small for Supergoal or you haven't thought hard enough.

## What this is NOT

- Not a 20-page design doc. THINKING.md should fit on 2 pages.
- Not a UML diagram festival. Words and bullets are fine.
- Not where you write code. Plan only.
- Not where every assumption gets validated with the user. Most assumptions are fine to record and proceed.
