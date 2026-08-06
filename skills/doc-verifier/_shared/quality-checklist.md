# Shared Quality Checklist

Standard verification checklist used by `doc-verifier`, `freshness-pass`, and any skill that modifies documentation files.

---

## Fact-check quality

- [ ] Every **high-risk** claim (limit, default, lifecycle, version, pricing, term) confirmed by fetch/contract/live evidence — never a search snippet alone; low-risk claims search-verified at minimum (see `assets/_taxonomy.md`)
- [ ] Every correction includes a source citation with URL
- [ ] No claim cites the article under verification as its own evidence (self-citation exclusion)
- [ ] Numeric/limit/default/enum claims confirmed against a Contract source (Tier 1-C), not prose alone
- [ ] Contested claims (prose conflict + contract silent) flagged ⚖️ and routed to Live Validation, not guessed
- [ ] Code examples validated
- [ ] Version/deprecation status confirmed for all mentioned services
- [ ] Broken links fixed or flagged
- [ ] Unverifiable claims flagged but not removed

## Editorial quality

- [ ] `ms.date` updated (MM/DD/YYYY) **only when at least one claim was fetch/contract/live-verified** — never on a search-only pass
- [ ] Title: 30–65 chars, title case, primary keyword
- [ ] Description: 120–165 chars, CTA, keyword at beginning, unique from title/H1
- [ ] H1: sentence case, differs from title
- [ ] Customer intent present in `ms.custom`
- [ ] Heading hierarchy correct (no skipped levels, single H1)
- [ ] All H2+ headings use sentence-style capitalization
- [ ] Code fence identifiers correct (`azurecli`, `azurepowershell`)
- [ ] Alert syntax uses standard format (`> [!NOTE]`, `> [!TIP]`, etc.)
- [ ] Sensitive identifiers replaced with approved placeholders
- [ ] Writing follows MS Style Guide (contractions, active voice, Oxford comma)
- [ ] Procedures use imperative verbs, ≤ 7 steps per section

## Batch quality (multi-file workflows only)

- [ ] All files in scope processed
- [ ] Consolidated report generated and saved
- [ ] Tracking table fully populated
- [ ] Per-file findings documented
