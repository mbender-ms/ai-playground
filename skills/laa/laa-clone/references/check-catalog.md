# LAA Clone — Check Catalog

Detailed rules, tool arguments, and severity mapping for each pass. Read this before running the
passes for the first time in a session. Skip any pass whose tool is unavailable and record the skip in
the report's coverage section.

> **`search_guidance` fallback.** Passes 1–3 prefer the local `search_guidance` index, but it is not
> registered in every environment. If a `search_guidance` call fails or returns "not installed", do
> **not** fall back to GitHub or web search — apply the explicit rules in this catalog manually and note
> "search_guidance unavailable — manual rules applied" in the report coverage section.
>
> **Deferred tools.** `content-mentor_checkLinks`, `content-mentor_updateMsDate`, `rewrite_for_style`,
> and `scan_images_sfi` are deferred — `tool_search` and activate them before their passes. Where a tool
> is unavailable, each pass below lists a manual fallback.

## Table of contents

- [Pass 1 — Metadata & structure](#pass-1--metadata--structure)
- [Pass 2 — Style & voice](#pass-2--style--voice)
- [Pass 3 — Terminology & branding](#pass-3--terminology--branding)
- [Pass 4 — Technical accuracy](#pass-4--technical-accuracy)
- [Pass 5 — Links](#pass-5--links)
- [Pass 6 — Accessibility](#pass-6--accessibility)
- [Pass 7 — Freshness](#pass-7--freshness)
- [Pass 8 — Integrity & retrievability](#pass-8--integrity--retrievability)

---

## Pass 1 — Metadata & structure

**Tools:** parse the YAML frontmatter directly from the file; use `search_guidance` with
`corpus: "contributor-guide"` for any rule you're unsure about (phrase queries in Learn platform terms,
e.g. "ms.topic values", "tabbed conceptual", "zone pivot groups").

**Required frontmatter fields** (Blocker if missing/empty):

| Field | Rule |
|-------|------|
| `title` | Present; ≤ 60 chars recommended; unique-sounding; no trailing " - Azure" duplication with `ms.service` |
| `description` | Present; 100–160 chars recommended; not a copy of the title |
| `ms.topic` | Present; one of the allowed values (`overview`, `concept-article`, `how-to`, `quickstart`, `tutorial`, `reference`, `troubleshooting`, `faq`, etc.) |
| `ms.date` | Present; valid `MM/DD/YYYY`; not in the future |
| `author` | Present (GitHub alias) |
| `ms.author` | Present (Microsoft alias) |
| `ms.service` or `ms.subservice` | Present for service content |

**Structure checks:**

- Exactly one H1 (`#`) and it should be the first heading (Major if 0 or >1).
- No skipped heading levels (H2 → H4 without H3) (Major).
- No consecutive headings without explanatory content between them, except where the repository's
  authoring model explicitly permits it (Minor).
- Sentence-case headings (Minor).
- Includes referenced with correct `[!INCLUDE [name](../includes/file.md)]` syntax (Major if malformed).
- Zone pivots / tabs well-formed and balanced (Major if unbalanced).
- No orphaned or duplicated paragraphs, misplaced includes, or heading mislabels (Major).
- Every ordered-list item uses `1.` and nested content is indented three spaces under its parent
  item (Minor; Major if bad indentation changes the rendered procedure).
- Sibling list items use consistent grammatical form and terminal punctuation. Remove punctuation
  after a link when its visible text already ends in `?`, `!`, or another terminal mark (Minor).
- Markdown tables have the same number of cells in every row and include their closing `|` when the
  local repository convention requires it (Major if malformed, Minor for convention-only drift).
- Markdown files end with a trailing newline (Minor).

**AI disclosure:** Validate `ai-usage` only when the review has evidence about how the change was
authored, such as a PR diff, the user's statement, or generated-file provenance. For content created
or substantially modified with AI, require `ai-usage: ai-generated` or `ai-usage: ai-assisted` unless
the change is limited to links, short phrases, or less than 5% of the article's word count. Never infer
noncompliance from an unchanged legacy article that merely lacks the field. Report uncertain cases as
Info rather than adding or demanding the field.

**Content completeness:** Apply these checks according to article type and scope; don't require every
section in every article.

- Procedures include prerequisites or clearly state that none are required, all actions needed to
  reach the outcome, a way to recognize success, and any necessary cleanup or follow-up action
  (Major when an omission prevents task completion).
- The title, description, H1, introduction, and body all promise and deliver the same user outcome
  (Major for a substantive mismatch).
- Apply repository-specific required ending sections, alert limits, templates, and portal-experience
  rules only when an applicable repository instruction defines them. Record the repository rule as
  the finding source.

---

## Pass 2 — Style & voice

**Tool:** `rewrite_for_style` (pass the article body; optional `focus`: `comprehensive`, `voice`,
`structure`, `clarity`). Back it with `search_guidance` `corpus: "style-guide"` for specific rulings,
and cross-check against `laa-suggestions.md` (at `LAA_SUGGESTIONS_PATH`)
— a pattern library distilled from real LAA bot suggestion blocks, keyed by the bot's own `Rules` tags.

Report the change summary as findings — do **not** apply rewrites unless the user asks. Flag:

- Passive voice where active is clearer (Minor–Major by density).
- **Person / point of view** — Learn voice is direct second person addressed to the reader:
  - **First person** ("we", "our", "us", "I", "let's") — flag it (Minor; Major if pervasive). The one
    accepted exception is "we recommend"; everything else ("we modify", "we use", "let's create")
    should become "you" or an imperative.
  - **Third-person reader references** ("the user", "customers", "developers", "one can", "users should")
    when the sentence is really addressing the reader — rewrite to "you" (Minor).
  - **Missing second person** in procedural/how-to content — steps should be imperative or "you"-led
    (Minor).
- **Conciseness** — Learn voice is tight. Flag:
  - Wordiness and filler ("in order to" → "to", "is able to" → "can", "at this point in time" → "now",
    "the resource usage" → "resource usage") (Minor).
  - Hedging and empty intensifiers ("simply", "just", "easily", "very", "please", "note that",
    "it is important to note") (Minor).
  - Redundant lead-ins ("This article describes how to…", "This section will…") and future tense where
    present tense works ("This scenario will create" → "This scenario creates") (Minor).
- Tone drift from friendly-professional (Minor).
- Capitalization and contraction rulings per style guide (Minor).
- Microsoft word-choice violations (e.g. "log in" vs "sign in", "e-mail" vs "email") (Minor).
- Use present tense in procedures and descriptions. Prefer imperative steps ("Select **Create**")
  over future tense or unnecessary "you should" constructions (Minor).
- Use "might" for possibility; reserve "may" for permission (Minor).
- Use input-agnostic interaction verbs: **select**, **choose**, and **enter**, rather than **click**,
  **tap**, or **type**, unless the specific input method matters (Minor).
- Use people-first, gender-neutral, and bias-free language. Treat diverse example names and scenarios
  as a review consideration, not a quota-based finding (Minor–Major by impact).
- Use "by using" when a tool or feature is the means of an action; use "through" for a form or portal.
  Flag "with" or a trailing "using" only when the grammar clearly expresses an instrument, not mere
  accompaniment (Minor).
- Prefer "problem" to "issue" when describing something the reader must troubleshoot. Keep "issue"
  for tracked work items, publications, or other established meanings (Minor).
- Replace a slash between prose alternatives with "or"; don't change paths, URLs, command syntax,
  ratios, or established names (Minor).
- Add an explicit noun after a demonstrative used as a vague subject (for example, "This action" or
  "When this condition occurs") when the antecedent isn't immediately clear (Minor).
- Replace vague gerund subjects such as "Doing so" with a precise noun, and expand reduced participles
  when they create ambiguity (for example, "a rule that allows...") (Minor).
- Describe capabilities with direct constructions such as "you can" or "helps you". Prefer an active
  verb over "lets you", "allows you to", "it's possible to", or passive capability framing when the
  rewrite preserves the product claim (Minor).
- Use consistent verb mood across parallel feature or benefit lists; don't mix imperative verbs with
  third-person `-s` verbs (Minor).
- Split independent clauses joined by an em dash into sentences. Don't flag em dashes that don't join
  independent clauses; repository typography rules still govern other uses (Minor).
- Add the comma in correlative comparisons such as "The lower the value, the higher the priority"
  (Minor).
- Use simple present, not present perfect, for conditions and completed actions (`avoid_present_perfect_tense`):
  "assumes you have X deployed" → "assumes you deploy X"; "the Region you've chosen" → "the Region you choose" (Minor).
- Avoid dangling modifiers on reduced conditional clauses (`avoid_dangling_and_misplaced_modifiers`):
  a bare `if`/`when` + `-ing` clause without an explicit subject, e.g. "if using static group membership"
  → "if you use static group membership" (Minor).
- State limitations or lists directly with "the following <noun>" instead of "... are as follows:"
  (`use_following_with_noun`) (Minor).
- Avoid vague "above"/"below" references to other content (`avoid_above_below`); link or restate the
  referenced content explicitly instead (Minor).
- **Smart/curly quotes and dashes** (`“ ” ‘ ’ —`) in prose where straight ASCII is expected — flag any
  found (Minor in prose). Curly quotes **inside fenced code blocks or inline code** are a **Blocker**
  (they break copy-paste execution in PowerShell/CLI — see pass 4).
- **Inconsistent hyphenation** of the same term across the article (e.g. "end to end" vs "end-to-end",
  "reencrypt" vs "re-encrypt") (Minor).

**Formatting in prose:**

- Bold exact UI labels. Don't bold ordinary actions or conceptual terms (Minor).
- Use code style for file and folder names, commands, parameters, identifiers, custom types, domains,
  and other nonlocalizable literals. Don't wrap product names or UI labels in code style (Minor).
- Normalize Learn links by removing `https://learn.microsoft.com/en-us` when a site-root-relative link
  works; use repository-relative links for files in the same repository (Minor).
- Avoid `etc.` and "and so on". Give a complete list when it is bounded, or introduce representative
  items with "for example" (Minor).
- Use the Oxford comma in lists of three or more items (Minor).

Style findings are inherently subjective — present them as suggestions, and prefer counts
("14 passive-voice instances") over listing every one for long articles.

---

## Pass 3 — Terminology & branding

**Tool:** `search_guidance` `corpus: "style-guide"`.

- First mention of a product uses the full official name; later mentions may shorten (Major if wrong
  product name, Minor if shortening rules missed).
- Acronyms expanded on first use (Minor).
- No deprecated/renamed product or feature names (Major).
- Correct trademark and casing (e.g. "PowerShell", "GitHub", "Azure Kubernetes Service") (Minor–Major).
- Distinguish official product, feature, and SKU names from generic resource descriptions. Capitalize
  the complete official name, but lowercase generic phrases such as "virtual machine scale set" or
  "backend pool" when they aren't exact UI labels or proper names (Minor–Major).

---

## Pass 4 — Technical accuracy

**Tools:** `microsoft_docs_search` and `microsoft_docs_fetch` against Microsoft Learn; or invoke the
`doc-verifier` skill / a fact-checker subagent for a rigorous pass.

Verify claims that are objectively checkable:

- Version numbers, SKU names, region/availability statements.
- API names, cmdlet names, parameter names, CLI flags.
- Portal navigation paths and UI labels.
- Deprecation status and replacement guidance.
- **Code-block integrity:** scan fenced/inline code for **smart quotes** (`“ ” ‘ ’`), en/em dashes
  substituted for hyphens, and other typographic characters that break execution — Blocker. Also flag
  cmdlet/flag casing that won't match docs conventions (Minor).
- **Code-block language:** every fenced block has the most specific supported language identifier.
  Apply repository-specific identifiers such as `azurecli` or `bash` only when repository instructions
  define them (Minor).
- **Sample completeness:** flag placeholder comments (`// add code here`, `TODO`, omitted setup),
  undefined variables, missing imports, or elisions that prevent the documented scenario from running
  (Major). Don't flag intentionally partial fragments when the article labels them clearly and supplies
  the surrounding context.
- **Runability evidence:** classify each material sample as **verified** (executed successfully or
  matched to an authoritative tested sample), **failed** (execution produced a reproducible error), or
  **unverified** (execution wasn't practical). Never claim a sample is runnable based only on visual
  inspection. An unverified sample is coverage information, not automatically a finding.

Cite the authoritative Learn URL for each verification. Mark unverifiable claims as **Info** with a note
rather than asserting they're wrong. Wrong-and-verified claims are **Blocker**.

---

## Pass 5 — Links

**Tool:** `content-mentor_checkLinks` (deferred — load via tool search first).

- Broken relative links (target file/anchor doesn't exist) — Blocker.
- Broken absolute URLs (404/dead) — Blocker.
- Redirected URLs that should be updated — Minor.
- Anchor links to missing headings — Major.
- Bare URLs that should be descriptive links — Minor. Distinguish **illustrative example URLs** in prose
  or code (e.g. `http://contoso.com`, `https://127.0.0.1/`) — these are intentional; if the link checker
  reports them as broken it's a **false positive**, so mark them Info/ignore rather than Blocker.

If the tool is unavailable, do a best-effort static check: resolve relative link targets against the repo
and flag missing files; don't fabricate HTTP status for external URLs — mark them "unchecked".

---

## Pass 6 — Accessibility

**Tools:** `scan_images_sfi` (returns vision prompts; analyze images with built-in vision) plus a manual
scan of the Markdown.

- Every image has meaningful alt text (`![alt](path)` alt non-empty and descriptive) — Major if missing.
- Reference-style images (`![alt][ref]`) count too — a placeholder like `![scenario image][scenario]` is
  non-descriptive alt text (Minor–Major).
- No "click here" / "read more" / bare-URL link text — Minor.
- Alt text that conveys meaning **only through color** ("red arrow", "green arrow") needs a
  non-color description too — Minor.
- Information isn't conveyed by image alone (there's an equivalent text description) — Major.
- Tables have header rows — Minor.

---

## Pass 7 — Freshness

**Tool:** `content-mentor_updateMsDate` (report-only unless the user asks you to apply the bump).

- `ms.date` older than the freshness threshold (default 365 days from today) — Major.
- `ms.date` older than 180 days — Info (aging).
- Never bump `ms.date` automatically; a date bump implies the content was actually reviewed.

---

## Pass 8 — Integrity & retrievability *(optional / deep)*

Only when the user requests a deep or full review, or opts in.

- **Integrity:** invoke the `article-integrity` skill — internal contradictions, naming inconsistencies,
  obvious typos, link-text mismatches, prose-to-code mismatches. Contradictions are Major–Blocker.
- **Retrievability:** invoke the `retrievability` skill — RAG/GEO retrievability risks across chunk
  autonomy, context completeness, disambiguation, entity normalization, heading hierarchy, structured
  data. These are **Info** enhancements, not publish blockers.

These passes are token-heavy; for folder runs, offer to run them only on the highest-risk files.
