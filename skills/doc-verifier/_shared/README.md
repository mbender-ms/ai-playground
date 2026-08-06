# Shared References

Consolidated reference files used by multiple Copilot skills. Centralizing these eliminates duplication, reduces token usage, and ensures a single source of truth for formatting, style, SEO, source authority, and quality standards.

---

## Files

| File | Content | Used by |
|------|---------|---------|
| [formatting-rules.md](formatting-rules.md) | Headings, code fences, alerts, tables, lists, cross-links, UI formatting, images, spacing, frontmatter validation | doc-writer, documentor-workflow, freshness-pass |
| [quality-checklist.md](quality-checklist.md) | Standard verification checklist — fact-check quality, editorial quality, batch quality | doc-verifier, freshness-pass, all prompt assets |
| [seo-and-metadata.md](seo-and-metadata.md) | Title, description, H1, intro paragraph, subheadings, customer intent, ms.date, ms.topic, image alt text, internal linking, frontmatter template | doc-writer, documentor-workflow, freshness-pass |
| [source-hierarchy.md](source-hierarchy.md) | Tiered source authority (Tiers 1–7), domain allow-list, repository catalog integration for Tier 2 verification | doc-verifier, freshness-pass |
| [writing-style.md](writing-style.md) | Microsoft writing style essentials — voice, tone, brevity, capitalization, heading rules, procedural steps, UI terminology | doc-writer, documentor-workflow, freshness-pass |

---

## How skills reference these files

Each skill's `SKILL.md` links to shared files using relative paths:

```markdown
See [_shared/formatting-rules.md](../_shared/formatting-rules.md) for complete formatting rules.
```

Prompt assets reference shared files to avoid inlining the same content:

```markdown
## Setup
Load [_shared/source-hierarchy.md](../../_shared/source-hierarchy.md) for the source authority reference.
```

The original per-skill reference files (e.g., `doc-writer/references/formatting-rules.md`) remain in place with a consolidation notice pointing here. This preserves backward compatibility while directing agents to the canonical versions.

---

## When to add a new shared file

Add a file here when:

1. **Two or more skills** reference the same rules or content
2. The content is **stable** — not skill-specific workflow logic
3. Centralizing it **reduces total tokens** loaded across agent sessions

Keep skill-specific workflow logic (engagement checklists, article templates, sensitive identifiers) in the owning skill's `references/` folder.

---

## Relationship to other skill directories

| Directory | Purpose |
|-----------|---------|
| `_shared/` | Cross-skill reference files (this directory) |
| `sources/` | GitHub repository catalog (3,000+ repos) + routing index |
| `doc-verifier/` | Fact-checking and accuracy verification workflows |
| `doc-writer/` | Article authoring and scaffolding |
| `documentor-workflow/` | Editorial quality workflows (SEO, metadata, formatting) |
| `freshness-pass/` | Composed freshness workflow (fact-check + editorial + consolidation) |
| `my-workflow/` | Personal workflow context and commands |
| `ado-work-items/` | Azure DevOps work item creation and validation |
| `azure-quickstart-templates/` | Quickstart template authoring and review |
