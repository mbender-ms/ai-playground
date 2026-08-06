# LAA Clone — Report Template

Render findings using this exact structure. Keep it scannable. For folder runs, the summary table has
one row per file; for single-article runs, drop the per-file table and go straight to findings.

---

```markdown
# LAA report — <target name>

**Scope:** <single article | folder>  ·  **Files scanned:** <n>  ·  **Date:** <YYYY-MM-DD>
**Passes run:** <list>  ·  **Passes skipped:** <list + reason, or "none">

## Summary

| Severity | Count |
|----------|-------|
| 🔴 Blocker | <n> |
| 🟠 Major | <n> |
| 🟡 Minor | <n> |
| ⚪ Info | <n> |

## Review coverage

| Category | Status | Rule source | Notes |
|----------|--------|-------------|-------|
| Metadata, structure & completeness | <Pass / Findings / Skipped / N/A> | Learn-wide catalog; <repository instruction path, if any> | <brief result or reason> |
| Style, voice & prose formatting | <Pass / Findings / Skipped / N/A> | Learn-wide catalog; <repository instruction path, if any> | <brief result or reason> |
| Terminology & branding | <Pass / Findings / Skipped / N/A> | Learn-wide catalog | <brief result or reason> |
| Technical accuracy & code samples | <Pass / Findings / Skipped / N/A> | Learn-wide catalog; <repository instruction path, if any> | <verified, failed, or unverified sample coverage> |
| Links | <Pass / Findings / Skipped / N/A> | Learn-wide catalog | <brief result or reason> |
| Accessibility | <Pass / Findings / Skipped / N/A> | Learn-wide catalog | <brief result or reason> |
| Freshness | <Pass / Findings / Skipped / N/A> | Learn-wide catalog | <brief result or reason> |
| Integrity & retrievability | <Pass / Findings / Skipped / N/A> | Optional deep review | <brief result or reason> |

<!-- Folder runs only: one row per file, worst-first -->
| File | Blocker | Major | Minor | Info |
|------|:-------:|:-----:|:-----:|:----:|
| articles/foo/bar.md | 1 | 3 | 5 | 2 |

## Findings

### <relative/path/to/file.md>

| Line | Severity | Pass | Rule source | Issue | Recommendation |
|------|----------|------|-------------|-------|----------------|
| 3 | 🔴 Blocker | Metadata | Learn-wide catalog | `ms.date` missing | Add `ms.date: 07/16/2026` |
| 42 | 🟠 Major | Links | Learn-wide catalog | Broken relative link `../vnet/overview.md` | Target not found; fix path or remove |
| 88 | 🟡 Minor | Style | Learn-wide catalog | Passive voice | "is configured by" → "you configure" |
| 121 | 🟡 Minor | Structure | `.github/copilot-instructions.md` | Required ending section missing | Add the repository-required ending section |

<!-- Repeat a findings section per file for folder runs -->

## Verification notes

- <Learn URL cited for each technical-accuracy verification>
- <Claims marked "unverifiable" and why>
- <Code samples classified as verified, failed, or unverified, including the evidence used>
- <Diff-dependent checks such as ai-usage marked N/A when authorship or change-scope evidence is absent>

## Recommended next steps

- <e.g., "Apply the 6 style rewrites in bar.md", "Bump ms.date after review", "Open an ADO work item">

## Overall assessment

**Verdict:** <Publish-ready | Minor fixes needed | Not ready — blockers present>
**Estimated fix effort:** <quick / moderate / significant>
```

---

## Rendering rules

- Sort files worst-first (most Blockers, then Majors).
- Within a file, sort findings by line number.
- Use **Pass** when every applicable check in the category ran without findings; **Findings** when one
  or more checks found an issue; **Skipped** when an applicable check couldn't run; and **N/A** when
  the article or available context doesn't require the check.
- Omit wholly irrelevant categories from a contributor-facing checklist. Retain an N/A row when the
  distinction matters, such as `ai-usage` without diff/authorship evidence or code checks in an article
  whose purpose normally implies samples.
- For folder runs, aggregate coverage by category and put file-specific exceptions in Notes rather than
  repeating a complete checklist for every file.
- Add an inline note to the coverage row for each failing item; the detailed findings table carries the
  exact line, evidence, and recommendation.
- Cite repository rules with a workspace-relative instruction path. Use `Learn-wide catalog` for rules
  defined by this skill. Never label a repository-only convention as Learn-wide.
- Use the severity emoji + label together so the report is scannable and greppable.
- Cap per-file findings tables at ~25 rows; if a file has more, show the top issues by severity and
  note "+N more Minor issues" rather than flooding the report.
- Every line number must come from an actual `read_file`, never an estimate.
- Keep the whole report token-aware for folder runs — the per-file summary table carries the detail,
  and full findings sections can be collapsed to the top 2–3 files unless the user wants all of them.
