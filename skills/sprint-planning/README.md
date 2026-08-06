# Sprint Planning

Turn an Azure DevOps sprint board into a defensible monthly plan and a one-pager you can hand to your manager.

Run it once a month, at the start of the sprint. It takes about 15 minutes of your attention — most of that is answering five or six questions.

---

## What it actually does

Anyone can drag work items between iterations. This skill exists for the parts that are tedious or easy to get wrong:

- **Grounds every question in the real board.** It pulls and totals your sprint *before* asking anything, so the questions name actual item IDs and point values instead of asking "what are your priorities?" in the abstract.
- **Runs seven mechanical checks** for planning errors that survive a careful human read-through — double-counted Features, impossible target dates, commitments with no work item, items blocked for months.
- **Plans two sprints at once.** Deferring work to protect this month is only a plan if next month has room. It checks.
- **Produces a shareable artifact.** Markdown plus a themed, print-ready HTML one-pager.

It plans **forward**. It does not report on what you accomplished — that's a different job.

---

## Setup

### 1. Install

Copy the `sprint-planning/` folder into your skills directory:

```
~/.copilot/skills/sprint-planning/
```

On Windows that's `C:\Users\<you>\.copilot\skills\sprint-planning\`.

### 2. Edit `config.json`

**This is the only file you need to change.** It ships with placeholder values — every one of them is wrong for you.

```json
{
  "ado": {
    "org": "https://dev.azure.com/your-org",
    "project": "YourProject",
    "areaPathRoot": "YourProject\\Path\\To\\Your\\Area",
    "iterationRoot": "YourProject"
  },
  "owner": {
    "name": "Your Name",
    "email": "you@example.com"
  },
  "output": {
    "dir": "~/sprint-one-pagers"
  },
  "onePager": {
    "preparedFor": "Your Manager"
  }
}
```

Note the **double backslashes** in area paths — they're JSON string escapes. `Content\\Production\\Networking` means `Content\Production\Networking`.

### 3. Check your prerequisites

You need:

- **Azure CLI** authenticated — `az login`, with the `azure-devops` extension
- **An ADO MCP server** connected to your org, or the `az boards` CLI as a fallback
- **At least one prior sprint** with closed, pointed work items, so velocity can be computed

Sanity check that iteration paths resolve:

```powershell
az boards iteration project list --organization $org --project $project --depth 4 -o json
```

If that returns your fiscal-year tree, you're ready.

---

## Using it

Just describe what you want in plain language. The skill triggers on sprint planning intent — you don't need to name it.

### Example 1 — Full monthly planning session

> **Run sprint planning for September. My priorities in order are: 1) contradiction cleanup, 2) TOC overhaul, 3) retrievability, 4) fact-checker delivery, 5) content gaps.**

Gives you: board snapshot for September and October, a velocity baseline from prior sprints, five or six questions grounded in your actual items, an anti-pattern scan, and a full change list held for your approval before anything is written.

### Example 2 — Just check for problems

> **Check my August sprint for planning problems. Don't change anything.**

Runs the seven checks and reports. No writes.

### Example 3 — Mid-sprint re-plan

> **I just picked up a new service and I'm leading stakeholder comms now. What comes out of this month?**

Recognizes this as a re-plan rather than a fresh sprint. Quantifies the new overhead as a capacity reserve, proposes specific items to defer with point values and reasons, and checks whether the receiving sprint has room.

### Example 4 — One-pager only

> **Build me a one-pager for this sprint I can share with my manager.**

Skips the interview, generates markdown and HTML from the current board.

### Example 5 — Test a dated commitment

> **I need to deliver fact-checker results by 10/15. Is my plan set up for that?**

Checks whether a work item carries that target date. If not, flags it, traces the upstream dependency chain across sprints, and identifies which sprint is the actual constraint.

### Example 6 — Historical validation

> **Run this for July and June without changing anything, so I can see if the numbers hold up.**

Useful after changing config, or to sanity-check velocity assumptions against months you remember well.

---

## What happens, phase by phase

| Phase | What it does | Writes to ADO? |
|---|---|---|
| 0 | Computes iteration paths from the fiscal-year algorithm, verifies the nodes exist | No |
| 1 | Snapshots the planned sprint and the next one, with totals | No |
| 2 | Computes velocity from the prior three sprints | No |
| 3 | Asks you five or six grounded questions | No |
| 4 | Reconciles the arithmetic and runs the seven checks | No |
| 5 | **Presents the full change list for approval** | No |
| 6 | Applies the approved changes, verifies with a read-back | **Yes** |
| 7 | Generates the one-pager, markdown and HTML | No |
| 8 | Records decisions and traps for next month | No |

**Nothing is written to ADO before Phase 5 approval.** Sprint boards are shared; a wrong bulk move is visible to your whole team and tedious to unwind.

---

## The seven checks

| # | Check | What it catches |
|---|---|---|
| 1 | Features carrying story points | Double-counting against pointed children — silently inflates the sprint |
| 2 | Target date precedes its own sprint | Items already late the day the sprint opens |
| 3 | Dated commitment with no work item | The expensive one — nothing tracks it, so nothing warns you |
| 4 | Long-lived `Blocked` | Items rolling month to month unexamined |
| 5 | Items outside every declared priority | Real work your priority framework doesn't account for |
| 6 | Next sprint already over velocity | The constraint is usually next month |
| 7 | Unpointed items | Every capacity number wrong by an unknown amount |

Findings are reported as flags, never auto-fixed. Each has a legitimate variant, and silently "correcting" a deliberate choice is worse than missing it.

---

## Outputs

Two files land in your configured `output.dir`:

```
2026-08-04-august-sprint-one-pager.md
2026-08-04-august-sprint-one-pager.html
```

The HTML is self-contained — no external dependencies, no network calls. It auto-detects light/dark, has a manual toggle, and includes a print stylesheet so **Print → Save as PDF** produces a clean handout with the interface chrome stripped out.

---

## Customizing it

The skill is plain markdown. Edit it.

### Easy — change `config.json`

| Setting | Try changing it when |
|---|---|
| `velocity.source` | Your months are genuinely heterogeneous — `trailing-3-sprint` is the safer default |
| `conventions.defaultCapacityReservePoints` | You consistently get more or less unplanned work than 5 pts' worth |
| `conventions.featuresCarryPoints` | Your team *does* estimate at the Feature level — set `true` to disable check #1 |
| `onePager.preparedFor` | Sharing beyond your manager |

### Moderate — reshape the one-pager

`assets/one-pager-template.html` is a token template. Anything written as `{{config.*}}` resolves from `config.json` — the manager name, your name, and the board identifier live there, not in the HTML. Replace the sample rows inside `<div class="sheet">` and keep the theme block and component classes:

`.rank` priority badges · `.callout` framing sentence · `.tag` status pills · `tr.total` summary rows · `.risks` numbered list · `.net` closing box

Reorder the sections in SKILL.md Phase 7 if your manager cares about different things. If they always ask "what slipped and why," add a section for it.

### Moderate — adjust the interview

Phase 3 in SKILL.md lists what to ask about. Add your own recurring questions — on-call rotation, conference travel, a standing carve-out for support work. The instruction that matters is that questions must name real IDs and point values from the Phase 1 snapshot; keep that property when you add to them.

### Advanced — add or modify checks

`references/anti-patterns.md` holds all seven, each with detect/why/fix. Follow the same shape when adding one. Candidates worth considering:

- Items with no acceptance criteria
- Stories above a point threshold that should be split
- Items whose parent Feature sits in a different sprint
- High removal rate — over-scheduling then culling

Update the count in SKILL.md Phase 4 when you add one.

### Advanced — a different work tracker

The workflow is tracker-agnostic; only `references/queries.md` and `references/ado-gotchas.md` are ADO-specific. Replace those two with equivalents for Jira or GitHub Projects and the eight phases still hold.

---

## Sharing with your team

`config.json` is the whole portability story. A teammate copies the folder, edits that one file, and runs it.

Worth agreeing on as a team before you all adopt it:

- **Do Features carry points?** Check #1 is noise if your convention says yes.
- **What's a standard story?** Point values only compare across people if the scale does.
- **What does `Blocked` mean?** Check #4 depends on it being reserved for genuine external dependencies.

---

## Troubleshooting

**"`az boards query` returned no fields"** — expected. It returns IDs only, whatever you SELECT. The skill follows with a batch fetch; see `references/queries.md`.

**Parsed rows are all null but headers look right** — the batch result is a top-level array. Don't try to normalize the root with `if ($j.value) {...} elseif ($j.workItems) {...}`; pipe `ConvertFrom-Json` straight into `ForEach-Object`. Full pattern in `references/queries.md`.

**Work item creation fails with a JSON error** — the `create` action rejects a `format` key anywhere in its fields array. Create with Title and AreaPath only, then `update` for everything else. See `references/ado-gotchas.md`.

**"TF201036: only one Parent link"** — remove the existing parent relation before adding the new one. `System.Parent` is read-only.

**Velocity looks wrong** — check whether your prior months are the same *kind* of work. A shift in median item size or a jump in item count means a regime change, and averaging across it produces a number describing no month that will ever happen again. Phase 2 covers how to diagnose this.

**The skill doesn't trigger** — say "run sprint planning for <month>" explicitly. If it still doesn't, confirm the folder is directly under `~/.copilot/skills/` with `SKILL.md` at its root.

---

## Files

```
sprint-planning/
├── README.md                      this file
├── summary.md                     build account — why the skill looks the way it does
├── SKILL.md                       the workflow — 8 phases
├── config.json                    the only file you must edit
├── references/
│   ├── queries.md                 WIQL, batch fetch, parsing
│   ├── ado-gotchas.md             create/update rules, link types, CLI fallback
│   └── anti-patterns.md           the seven checks
├── assets/
│   └── one-pager-template.html    themed, print-ready, token-driven
└── evals/
    └── evals.json                 test prompts
```

Open `assets/one-pager-template.html` in a browser to see the layout before running anything — the `{{tokens}}` render as literal text until the skill fills them in.

Read `summary.md` if you're modifying the skill. It records what was tried, what broke, and why several instructions are worded the way they are — useful context before changing them.
