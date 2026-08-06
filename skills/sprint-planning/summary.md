# Build summary — sprint-planning skill

**Purpose:** an account of how this skill came about, including what was wrong along the way — because several of those mistakes are the reason specific instructions exist.

Identifying details have been removed: no work item IDs, no names, no org or project names, no real board numbers. What's left is the reasoning, which is the part worth keeping.

---

## 1. How this started

The session began as an ordinary request: re-run a month's sprint planning against an updated priority list. A skill was not the goal. It emerged several steps later, once the workflow had been performed end to end and was obviously repeatable.

That ordering matters. The eight phases in `SKILL.md` are not a designed process — they're a transcript of what actually happened, cleaned up. Every reference file exists because something went wrong that a reference file would have prevented.

---

## 2. The first planning pass

**The board was pulled *before* any question was asked.** This turned out to be the single most valuable property of the whole workflow, and it became Phase 1. The interview questions that followed could name real items and real point values — "this month is at X points before the new overhead, what comes out first?" — rather than asking abstractly about priorities.

### Three things surfaced that nobody asked about

These became the seed of the anti-pattern detector:

1. **Features carrying story points** while also having pointed children — phantom points inflating the sprint.
2. **A dated external commitment with no work item.** It existed only in conversation.
3. **A target date preceding its own sprint** — an item that was late the day the sprint opened.

None of these are visible on a board view. All three were found by mechanical comparison rather than by reading.

---

## 3. Artifacts, then the reusability question

A markdown one-pager was produced, then converted to self-contained themed HTML with a print stylesheet. Then came the question that changed the session's direction: how do you recreate this monthly, and how does a teammate run it?

**`config.json` is the whole portability story.** The process was saturated with one person's constants — area path, parent IDs, email, priority names, manager name. Externalizing them makes onboarding "copy the folder, edit one file." Anything a teammate would have to change belongs in config, not in the workflow body and not in the HTML template.

The skill also filled a real gap. Backward-looking reporting skills and backlog scoring already existed; nothing did forward sprint planning.

**Model tier:** frontier reasoning for the whole run. Not because of token cost — it runs once a month — but because the failure modes are silent: arithmetic that lands in a manager-visible document, and the judgment of which six questions to ask out of a seventy-item board.

---

## 4. Structure

Detail was pushed into `references/` rather than kept in `SKILL.md`, following progressive disclosure — the workflow body stays readable, and the fiddly tracker specifics load only when the apply phase needs them.

**Deliberately deferred:** a board-snapshot script. Generalizing a script from a single dataset produces something shaped by one month's accident. Better written against a second real run.

---

## 5. The smoke test, and the correction it forced

The skill was run historically against three prior months — read-only, no writes to closed sprints.

### What it validated

- The fiscal-year iteration-path algorithm across a year boundary, confirmed against live iteration nodes.
- The documented parse pattern ran clean on a large batch on the first attempt.
- Velocity reconciled against the independently recorded figure, with one item of drift.

### What it broke

**A scoping bug in check #1.** Features were matched to children by filtering the *queried sprint set*. A Feature whose children sit in a different sprint would silently pass while still double-counting. Fixed to enumerate children through the hierarchy link relation.

**A missing check.** One historical sprint had 42% of its closed items unpointed. That invalidates every capacity number and compounds: unpointed items close, contribute zero, and depress the baseline the next month is planned against. Added as check #7.

### The redirection — the most important lesson in the build

The trailing three-month average came out far below the single-prior-month figure the plan had been built on. This was raised as a serious flag: the sprint appeared to be badly over its true baseline.

**That flag was wrong.** It was retracted the following turn, with evidence.

Testing the numbers properly meant looking at the *shape* of the closed work, not the totals. Two of the three prior months were large-item authoring with a high median item size and low item count. The third was a different regime entirely — many small, similar remediation stories — and the month being planned was that same workstream continued.

Averaging across a regime change produces a baseline describing no month that will ever happen again. The proof arrived unprompted a few days later, when the sprint closed a large fraction of its points in its first week.

The skill's own default guidance — prefer a trailing average, single months are noisy — is correct in general and would have produced a materially worse plan here. `SKILL.md` Phase 2 was rewritten to diagnose regime change *before* averaging anything, using median item size, item count, and whether the closed titles resemble the work now scheduled.

A smoke test that only confirms what you already believe has not tested anything. This one changed the skill.

### An honest limitation

Three of the seven checks returned "none" across all historical sprints — correctly, because closed sprints have no blocked items and no carry-forward. The historical run was a **weak test of the detector**. Its real validation was the live board, where it found three genuine problems. Past sprints cannot exercise checks that are about unresolved state.

---

## 6. Re-planning, one day later

Re-pulling the board showed it had moved substantially in a single day: a large block of stories had closed, one item was added, and one was re-estimated upward.

The resulting few-point discrepancy was caught during reconciliation and **traced rather than absorbed** — worth preserving as a property. Arithmetic that doesn't tie out should be explained, not rounded past.

Check #4 fired correctly on an item that had been `Blocked` for two full sprints, not one. Surfacing it prompted a follow-up with the PM, which produced an answer and unblocked the item in the same session. The check paid for itself immediately.

With a large share of the month's points already banked, the original deferral rationale had evaporated and the deferrals were **reversed**. Both the current and following month then landed at velocity — reversing the deferrals fixed the following month as a side effect, which was the month every input for the dated commitment had to land in.

---

## 7. Corrections made during the session

The pattern matters more than any individual item.

| # | What was wrong | How it surfaced | Where it's now captured |
|---|---|---|---|
| 1 | The query CLI was assumed to return fields | Returned IDs with empty field objects | `references/queries.md` |
| 2 | Parse produced null rows with correct headers | Root normalization branch misbehaved on a top-level array | `references/queries.md`, with the anti-pattern spelled out |
| 3 | Work item `create` rejected a valid-looking fields array | Error message blamed JSON escaping — a red herring; the real cause was a `format` key | `references/ado-gotchas.md` |
| 4 | Velocity flagged as far too low, alarm raised | Regime-change analysis of closed-item shape | `SKILL.md` Phase 2, rewritten |
| 5 | Check #1 scoped to the queried set | Historical smoke test | `references/anti-patterns.md` |
| 6 | No unpointed-item check | Historical smoke test | Added as check #7 |
| 7 | Reparenting failed — only one parent link allowed | Attempted a second parent link | `references/ado-gotchas.md` |
| 8 | Claimed a gotcha was documented before writing it | Caught on the next turn | Fixed |
| 9 | A target date changed externally between two reads | Read-back verification | Reported rather than silently absorbed |

Items 4, 5, and 6 all came from the smoke test. Items 1, 2, 3, and 7 are tracker friction that cost time and are now written down so they cost nothing next month.

---

## 8. What to carry into the next run

1. **Pull the board before asking anything.** Everything good about this workflow follows from it.
2. **Never write to the tracker before approval.** Present the whole change list; approve once.
3. **Run all seven checks even when the sprint looks clean.** They found three problems in a sprint that had already been planned twice.
4. **Test velocity for regime change before averaging.** The default is right in general and was wrong here.
5. **Verify with a read-back.** It caught both a silent re-estimate and an externally changed date.
6. **Write the next run's script, not this one's.** The board-snapshot script is still deliberately unwritten.

### Open items

- `evals/evals.json` has prompts and no assertions. Assertions were deferred rather than invented before a second real run.
- The historical smoke test can't validate three of the seven checks. Live-board validation is the only path for those.
- Trailing-3 vs. single-month velocity is currently a judgment call. More data may make it decidable.
