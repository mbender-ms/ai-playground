---
name: sprint-planning
description: Run a monthly sprint planning session end to end — snapshot the ADO board, compute velocity, interview the user for priorities and capacity, detect planning anti-patterns, apply approved changes, and generate a shareable one-pager. Use this skill whenever the user mentions sprint planning, monthly planning, re-running or re-doing a sprint plan, "plan my month", "what should be in August", capacity or velocity checks against a sprint, moving work between sprints or months, deferring work to next sprint, or wants a sprint summary or one-pager for their manager — even if they never say "sprint planning" by name.
category: Planning
version: 1.0.0
argument-hint: 'the month to plan, plus your priorities in order (e.g., "plan August: contradiction work, TOC, retrievability")'
user-invocable: true
roles: [content-developer, technical-advisor, pm, manager]
---

# Sprint Planning

Turn a sprint board into a defensible monthly plan and a one-pager you can hand to your manager.

The value of this skill is not scheduling — anyone can drag items between iterations. The value is that it **grounds every decision in the actual board before asking a single question**, and it runs a mechanical scan for the planning errors humans reliably skim past.

Run it once a month, at the start of the sprint. It takes about 15 minutes of your attention.

## Before you start

Read `config.json` from the skill directory. It holds the org, project, area path, owner, and output directory. Every value in this skill that looks personal comes from there — never hardcode a person, path, or area into the workflow.

If `config.json` is missing or still has placeholder values, stop and ask the user to fill it in. Running with someone else's constants produces a plausible-looking plan for the wrong board, which is worse than failing.

---

## Phase 0 — Preflight

**Compute the iteration path. Never query for it.**

```
FY = year + 1 if month is Jul–Dec, else year
Q  = Jul/Aug/Sep → Q1 · Oct/Nov/Dec → Q2 · Jan/Feb/Mar → Q3 · Apr/May/Jun → Q4
Path = {iterationRoot}\FY{YY}\Q{Q}\{MM} {Mon}
```

August 2026 → `Content\FY27\Q1\08 Aug`. October 2026 → `Content\FY27\Q2\10 Oct`.

Compute three paths: the sprint being planned, the next sprint, and the prior sprint. You need all three — the next sprint is where deferred work lands, and the prior sprint is your velocity baseline.

Verify the nodes exist before using them. See `references/queries.md` → *Verify iteration nodes*.

## Phase 1 — Board snapshot

Pull the open items for the planned sprint **and** the next one in a single query. Planning one sprint in isolation is how work gets shoved into an already-overloaded next month and nobody notices until it's next month.

Use the WIQL and the parsing pattern in `references/queries.md`. Two things will bite you if you improvise:

- `az boards query` returns **IDs only**, regardless of what you SELECT. Always follow with a batch fetch and an explicit fields array.
- Batch results routinely exceed the inline result limit and get written to a file. Parse that file rather than re-fetching in smaller chunks.

Produce a table of every item — ID, type, sprint, state, points, target date, parent, title — plus totals by sprint. You will refer back to this constantly; get it into one readable artifact early.

## Phase 2 — Velocity baseline

Query items closed in each of the **prior three sprints** and sum their points. State the number explicitly and show your work.

**Report the spread, then check for a regime change before averaging.** Real data from three consecutive sprints:

| Sprint | Closed items | Closed points | Median closed item |
|---|---|---|---|
| May | 9 | 62 | 10 pts |
| June | 11 | 37 | 3 pts |
| July | 43 | 105 | 3 pts |

The trailing-3 mean is 68. Using it would have been **wrong**, and badly so.

May and June were large-item authoring months. July was the first month of a contradiction-remediation workstream — dozens of small, similar stories — and the sprint being planned was a continuation of exactly that workstream. July was not an outlier; it was the first month of the current regime. Averaging it against two months of different work produces a baseline that describes no month that will ever happen again.

**So: when a month deviates sharply from the others, don't average it away. Ask what changed.**

Diagnose regime change by comparing the *shape* of closed work, not just the total:

- Median closed item size — a shift from 10 pts to 3 pts means the work decomposed differently
- Item count — a 4x jump in items closed at similar total points is a different working mode
- Titles of the closed items — do they look like the work now scheduled?

If the sprint being planned resembles one prior month far more than the other two, **use that month and say why.** If the work genuinely is heterogeneous month to month, the trailing-3 average is right. The judgment call is which situation you're in, and it's worth two minutes of looking at titles to get it right.

Also cross-check against Phase 4's unpointed-item count. If a meaningful share of a month carried no estimate, its closed-point total understates real throughput, and the baseline is conservative by an unknown margin. Say so rather than presenting a precise-looking number you don't trust.

Report both item count and point total. A month that closed 43 items for 105 points has a different character than one that closed 9 for 62, and it changes how much unplanned work the coming sprint can absorb.

## Phase 3 — Interview

Ask for the user's priorities in order first, if they haven't already given them. Everything downstream keys off that ordering.

Then ask **5–6 questions grounded in what you found in Phase 1**. This is the step that separates a useful session from a generic one. A question like "what are your priorities?" wastes the board snapshot you just built. Good questions name real IDs, real point totals, and real conflicts:

> "August is 97 pts before the new overhead. What comes out first?" — with options listing the actual candidate items and their point values.

Ask about, at minimum:

- **Scope of any new or dated commitment** — which services, which deliverable, which date
- **When that work starts**, given the deadline and the dependency chain
- **Capacity reserve** for known-but-unquantified overhead (new service ownership, new meetings, on-call)
- **What leaves the sprint** if the total exceeds velocity — offer specific items, not categories
- **How to track new responsibilities** — work item vs. untracked overhead

Present these through the ask-questions tool with selectable options and a recommended default on each. Multi-select where more than one answer is legitimate. Users answer a concrete menu far faster than an open prompt, and the answers are unambiguous.

## Phase 4 — Reconcile and scan

Compute the arithmetic: what leaves, what arrives, resulting item count and point total for both sprints, and the planned load against velocity. Show before → after. Silent arithmetic errors here end up in a document the user's manager reads.

Then run every check in `references/anti-patterns.md`. All seven are cheap, and each one has caught a real problem:

| Check | Why it hides |
|---|---|
| Features carrying story points | Double-counts against child stories; inflates the sprint invisibly |
| Target date precedes its own sprint | Looks fine on the board, is already impossible |
| Dated commitment with no work item | The most expensive miss — nothing tracks it, so nothing warns you |
| Long-lived `Blocked` | Rolls month to month unexamined |
| Item in the sprint outside every declared priority | Real work that no priority accounts for |
| Next sprint already over velocity | The constraint is usually next month, not this one |
| Unpointed items | Every capacity number is wrong by an unknown amount |

Report findings as flags for the user to decide on. Do not auto-fix them — several look like errors and are deliberate.

## Phase 5 — Present for approval

Present the complete change list before writing anything: items leaving with points and reason, items arriving, items to create, the before/after totals, and the anti-pattern flags.

🛑 **Never write to ADO before the user approves.** Sprint boards are shared. A wrong bulk move is visible to the whole team and tedious to unwind. Approval of the plan as a whole is enough — you don't need to confirm each individual write.

## Phase 6 — Apply

Batch the updates. Use a single batch-update call for field changes across many items rather than one call per item.

Creating work items has a specific failure mode — the `create` action rejects a `format` key anywhere in its fields array, and adding many fields at once can fail with a misleading JSON error. Create with Title and AreaPath only, then `update` for everything else, then link the parent with the friendly `"parent"` link type. Full details in `references/ado-gotchas.md`.

If `config.json` defines `requestInformation`, set those custom fields on every create and update: `Custom.Modality`, `Custom.ResourceType`, `Custom.ProposalType`, `Custom.ProposalPointofContact`. Skip this step when the block is `null` — not every org requires them.

Finish with a single read-back of every touched item and confirm the values landed. Report what changed, not what you attempted.

## Phase 7 — One-pager

Generate two files in the configured output directory:

- `{YYYY-MM-DD}-{month}-sprint-one-pager.md`
- `{YYYY-MM-DD}-{month}-sprint-one-pager.html` — from `assets/one-pager-template.html`

The HTML template is self-contained and themed, with a print stylesheet so **Print → Save as PDF** produces a clean handout.

Structure, in this order:

1. **Masthead** — prepared for, from, date, sprint, board, reference velocity
2. **Priorities in order** — with point totals and a one-line description each
3. **Sprint at a glance** — the framing sentence, then before/after/reserve/planned-vs-velocity
4. **Dated commitments** — the dependency chain, sprint by sprint, with gates
5. **New responsibilities** — status and sprint impact
6. **Risks and asks** — numbered, most important first
7. **Deferred work** — framed as decision, not slippage
8. **Net** — two or three sentences a busy reader could stop at

Every `{{config.*}}` token in the template resolves from `config.json` — `onePager.preparedFor`, `owner.name`, `ado.org`, `ado.project`, and `conventions.defaultCapacityReservePoints`. Never write those values into the HTML directly; a teammate changes them in one place.

Write for a manager who will skim it in ninety seconds. Lead each section with the conclusion. If the sprint has a single defining characteristic — a merge sprint, a recovery sprint, a ramp sprint — say so in one bolded sentence near the top and let everything else support it.

Be honest about risk. A one-pager that presents everything as green is worthless the first time something slips.

## Phase 8 — Handoff note

Record for next month: decisions taken and why, traps encountered, key IDs, and anything left unresolved. Next month's session starts by reading this, which is what keeps the process from re-deriving the same analysis every sprint.

Log durable decisions to session memory so they surface in recall.

---

## Reference files

| File | Read when |
|---|---|
| `references/queries.md` | Phase 1–2 — WIQL, batch fetch, the parsing pattern that works |
| `references/ado-gotchas.md` | Phase 6 — create/update split, format-key rules, link types |
| `references/anti-patterns.md` | Phase 4 — the six checks and how to detect each |
| `assets/one-pager-template.html` | Phase 7 — themed, print-ready template |

## Scope

This skill plans **forward**. It does not report on what was accomplished — that's `monthly-report` (backward, monthly) and `1-1-reports` (backward, weekly). It also doesn't score an unordered backlog to decide what's worth doing; that's `backlog-analysis`, which pairs well as an input when choosing what fills remaining capacity.
