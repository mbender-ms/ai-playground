# LAA Clone

`laa-clone` is a local approximation of the Microsoft Learn Authoring Assistant (LAA). It reviews
Microsoft Learn Markdown before publication and produces a prioritized, evidence-based report. The
skill supports one article or a folder of articles.

This skill does not call the production LAA service. It combines available authoring tools with a
maintained catalog of Learn-wide rules and suggestion patterns observed in real LAA reviews.

## Use the skill

Ask Copilot to review a file or folder, for example:

- `Run LAA on articles/load-balancer/quickstart-load-balancer-standard-public-portal.md.`
- `Check this folder for style, metadata, broken links, and accessibility problems.`
- `Is this article ready to publish?`
- `Run a deep LAA review, including integrity and retrievability.`

The standard review runs passes 1 through 7. A deep review also runs the more expensive integrity and
retrievability pass.

## Review coverage

The skill checks:

1. Metadata, structure, content completeness, and conditional AI disclosure.
1. Microsoft voice, style, prose formatting, and observed LAA suggestion patterns.
1. Product terminology, capitalization, branding, and deprecated names.
1. Technical claims and code-sample integrity, completeness, and verification evidence.
1. Relative and external links, including heading anchors and redirects.
1. Images, alt text, link text, tables, and other Markdown accessibility concerns.
1. `ms.date` freshness without automatically changing the date.
1. Internal integrity and RAG retrievability when a deep review is requested.

See [references/check-catalog.md](references/check-catalog.md) for the complete rules and severity
guidance.

## Repository overlays

Learn-wide catalog rules form the baseline. The skill also reads applicable repository instructions,
including:

- `.github/copilot-instructions.md`
- `AGENTS.md`
- Matching `.github/instructions/*.instructions.md` files

Repository rules can add or narrow checks for their own docset. Every overlay-derived finding cites
the instruction path that supplied the rule, and repository-only conventions aren't applied to other
repositories.

Checks that require change context are evidence-sensitive. For example, the skill doesn't report a
missing `ai-usage` field on unchanged legacy content when no diff or authorship evidence is available.

## Report output

Reports include:

- Finding counts by severity: Blocker, Major, Minor, and Info.
- Coverage states: Pass, Findings, Skipped, and N/A.
- Exact file and line references for every finding.
- The Learn-wide or repository-specific source of each rule.
- Verification notes for technical claims and code samples.
- A publish-readiness verdict and estimated remediation effort.

Code samples are classified as **verified**, **failed**, or **unverified**. Visual inspection alone is
not treated as execution evidence. The output format is defined in
[references/report-template.md](references/report-template.md).

## Skill layout

| Path | Purpose |
| --- | --- |
| [SKILL.md](SKILL.md) | Triggering, orchestration, tool selection, and review workflow. |
| [references/check-catalog.md](references/check-catalog.md) | Learn-wide checks, observed LAA patterns, applicability rules, and severities. |
| [references/report-template.md](references/report-template.md) | Required report structure and rendering rules. |
| [evals/evals.json](evals/evals.json) | Regression prompts, expected behavior, and assertions. |
| `evals/fixtures/` | Small articles and repository overlays used by the regression cases. |

## Evaluate changes

The regression suite covers four behaviors:

1. A clean standalone article doesn't receive fabricated findings.
1. An incomplete procedure reports missing context, placeholder code, and unverified runability.
1. Unchanged legacy content doesn't receive an unsupported AI-disclosure finding.
1. Repository-specific rules apply only to content owned by that repository and retain their source.

When changing review behavior, update or add a focused case in [evals/evals.json](evals/evals.json),
then compare the revised skill with a snapshot of the previous version by following the `skill-creator`
evaluation workflow.

## Related workflow

Use `laa-clone` to find likely authoring problems before publication. Use `laa-block-remediation` when
the production LAA bot has already posted suggestion comments that block an existing pull request.
