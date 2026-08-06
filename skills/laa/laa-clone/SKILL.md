---
name: laa-clone
description: Local clone of the Microsoft Learn Authoring Assistant (LAA). Runs a multi-pass authoring review against a single article or a whole folder of articles — style/voice compliance, metadata and structure validation, technical accuracy, broken-link checks, accessibility/alt-text, freshness (ms.date), and terminology/branding — then produces a prioritized findings report. Use this skill whenever the user wants to "run the Learn Authoring Assistant", "run LAA", "author-check", "lint", "review", "validate", or "quality-check" a `.md` article or a directory of articles, or asks whether their content is publish-ready — even if they don't say "LAA" by name. Also trigger for "check this article for style and metadata", "is this doc ready to publish", "run authoring checks on this folder", or "give me an LAA-style report".
license: Proprietary
---

# LAA Clone — Learn Authoring Assistant (local)

## Overview

The Microsoft Learn Authoring Assistant (LAA) isn't callable as a tool here. This skill reproduces
its core value by orchestrating the authoring-review tools that *are* available in this environment
and consolidating the results into one prioritized report. It works on either a **single article**
or a **folder of articles**.

You are the orchestrator. Run the passes in order, collect findings into a normalized shape, then
render the report. Never invent a finding — every issue must cite an exact file and line number that
you verified by reading the file, not estimated.

## When to use

Trigger on any request to author-check, lint, review, validate, or assess publish-readiness of
Markdown content. Single file or folder both apply. If the user only wants one dimension (e.g. "just
check links" or "only style"), run that pass alone and skip the rest.

## Inputs — resolve the target first

1. **Determine scope.** If the user named a file, target that file. If they named a folder, expand it
   to every `.md` file (recurse unless they say top-level only). If nothing is named, ask for the path.
2. **Confirm the file set** before a folder run. Use `file_search` / `list_dir` to enumerate `.md`
   files and show the count. For folders larger than ~15 files, tell the user you'll sample or ask
   them to narrow scope unless they confirm the full run.
3. **Read every target file with line numbers** (`read_file`) before citing anything. Line accuracy is
   non-negotiable — inaccurate line numbers erode trust.
4. **Load the applicable rule stack.** Starting at each target file, identify the owning repository
   root and read its applicable authoring instructions (`.github/copilot-instructions.md`, `AGENTS.md`,
   and matching `.github/instructions/*.instructions.md` files when present). Learn-wide catalog rules
   form the baseline; repository instructions are an overlay and may add or narrow checks. Never apply
   a repository-specific convention to content from another repository.
5. **Resolve change context when available.** For PRs or changed-file reviews, use the diff to decide
   whether checks such as `ai-usage` apply. For standalone legacy-article reviews without authorship or
   diff evidence, mark those checks N/A rather than inferring a failure.

## The passes

Run these in order. Each maps to a real tool in this environment. Skip a pass silently if its tool is
unavailable, and note the skip in the report's coverage section. Full per-pass rules, severities, and
tool arguments live in [references/check-catalog.md](references/check-catalog.md) — read it before
running the passes for the first time in a session. Pass 2 is additionally grounded in
`laa-suggestions.md`, a living pattern
library distilled from real LAA bot suggestion blocks on `azure-docs-pr` PRs — read it alongside the
catalog so pre-emptive checks match what the real bot actually flags.

> **Set `LAA_SUGGESTIONS_PATH`** to wherever your copy of `laa-suggestions.md` lives — it is maintained
> outside this skill so both `laa-clone` and `laa-block-remediation` share one catalog. If the variable is
> unset or the file is missing, skip the cross-check and note it in the report's coverage section.

| # | Pass | Primary tool | What it catches |
|---|------|--------------|-----------------|
| 1 | Metadata, structure & completeness | `search_guidance` (corpus: `contributor-guide`) + frontmatter parse | Missing/invalid metadata; H1 and heading hierarchy; include/zone-pivot misuse; procedure completeness; conditional AI disclosure; repository-required article structure |
| 2 | Style, voice & prose formatting | `rewrite_for_style` + `search_guidance` (corpus: `style-guide`) + `laa-suggestions.md` | Passive voice, first/third-person misuse, conciseness, tone, word choice, UI/code formatting, list consistency, and observed LAA suggestion patterns |
| 3 | Terminology & branding | `search_guidance` (corpus: `style-guide`) | Product-name accuracy, deprecated terms, acronym expansion, trademark usage |
| 4 | Technical accuracy & code samples | `microsoft_docs_search` / `microsoft_docs_fetch` (or `doc-verifier` skill) | Wrong versions, API/param names, portal paths, deprecated guidance, code integrity, language identifiers, completeness, and runability evidence |
| 5 | Links | `content-mentor_checkLinks` | Broken relative/absolute links, bad anchors, redirected URLs |
| 6 | Accessibility | `scan_images_sfi` + alt-text scan | Missing/empty alt text, non-descriptive link text ("click here"), image-only info |
| 7 | Freshness | `content-mentor_updateMsDate` (report-only unless asked) | Stale `ms.date`, content older than freshness threshold |
| 8 | Integrity & retrievability *(optional, on request or `--deep`)* | `article-integrity` + `retrievability` skills | Internal contradictions, naming inconsistencies, RAG retrievability risks |

Passes 1–7 are the default LAA-equivalent run. Pass 8 is heavier — include it only when the user asks
for a "deep" or "full" review, or opts in when you offer it.

> **Tool availability (read first).** Several passes depend on *deferred* tools that must be loaded
> before use: `content-mentor_checkLinks` (pass 5), `content-mentor_updateMsDate` (pass 7), and the CDA
> tools `rewrite_for_style` / `scan_images_sfi` (passes 2, 6). At the start of a run, `tool_search` for
> "check links", "ms.date", "rewrite for style", and "scan images" and activate what's available — a run
> that silently skips the real link/freshness check is a weaker review. **`search_guidance` may be
> unavailable in some environments** (it's not always registered). If it is, don't fall back to GitHub
> or web search for style/metadata rules — apply the built-in rules in
> [references/check-catalog.md](references/check-catalog.md) manually, and note the fallback in the
> report's coverage section.

## Workflow

1. Resolve scope, enumerate files, and identify the owning repository for each file (see **Inputs**).
2. On first run in a session, read [references/check-catalog.md](references/check-catalog.md).
3. Read the applicable repository instruction files and build a rule stack with two named sources:
   `Learn-wide catalog` and `Repository overlay: <relative instruction path>`. If the sources conflict,
   follow the more specific repository instruction unless it weakens an explicit safety, accessibility,
   or factual-accuracy requirement; report unresolved conflicts as Info instead of choosing silently.
4. **Activate deferred tools.** `tool_search` for and load the pass-5/6/7 tools above before running the
   passes. Record any that are unavailable so you can note the coverage gap and fall back to the manual
   checks in the catalog (static link resolution, manual date diff, Markdown-only alt-text scan).
5. For each file, run passes 1–7 (and 8 if requested), collecting findings as you go. For folder runs,
   process files one at a time and keep a running tally — don't hold every file's full text at once.
6. For each catalog category, record `Pass`, `Findings`, `Skipped`, or `N/A`. Use `Skipped` only when an
   applicable check couldn't run; use `N/A` when the article or available context doesn't require it.
7. Normalize every finding to: `file`, `line`, `severity` (Blocker / Major / Minor / Info), `pass`,
   `source`, `issue`, `recommendation`. `source` identifies either the Learn-wide catalog or the exact
   repository instruction path that supplied the rule.
8. Render the report using [references/report-template.md](references/report-template.md).
9. Offer next steps: apply fixes (style rewrites, ms.date bump, alt text), open the worst files, or
   create an ADO work item / PR for the remediation. Never auto-apply edits without confirmation.

## Output

Default output is an inline Markdown report following
[references/report-template.md](references/report-template.md): a summary table (files scanned, finding
counts by severity), an applicability-aware coverage matrix, a per-file findings section, and the rule
sources and reasons for any skipped or N/A checks.

If the user asks for a saved report, write it to `~/LAA Reports/<target>-<YYYYMMDD-HHMMSS>.md` (create
the folder if needed). Never write scratch or report files inside a repository working tree.

## Severity guidance

- **Blocker** — would fail the publish/OPS build or is factually wrong (missing required metadata,
  broken links, incorrect version/API, contradictions).
- **Major** — real quality problem a reviewer would flag (structural/heading errors, passive-heavy
  prose, missing alt text, stale-beyond-threshold `ms.date`).
- **Minor** — polish (word choice, minor wordiness, capitalization).
- **Info** — advisory or opt-in enhancement (retrievability suggestions, optional metadata).

## Principles

- Verify before you cite — read the file, confirm the line, quote the exact text.
- Keep global and local rules distinct — cite repository overlays by path and never generalize them to
   other docsets without Learn-wide evidence.
- Prefer the local `search_guidance` index for style/metadata rules; if it's unavailable, use the
  catalog's built-in rules — never fall back to GitHub or web search for these.
- Report, don't rewrite, unless the user asks you to apply fixes.
- Keep folder runs token-aware: summarize per file, don't dump full articles into the report.
- Be honest about coverage — list every pass you skipped and why.
