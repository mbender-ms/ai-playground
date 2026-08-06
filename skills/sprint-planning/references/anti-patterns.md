# Anti-patterns

Seven mechanical checks. Run all of them in Phase 4, every sprint.

They exist because each one is invisible on a board view. A sprint can pass a careful human read-through and still contain all seven. Report findings as flags for the user to decide on — several of these look like errors and are deliberate.

---

## 1. Features carrying story points

**Detect:** any item where `WorkItemType == "Feature"` (or Epic) and `StoryPoints` is non-null, *and* the item has pointed children.

> ⚠️ **Enumerate children through relations, not through the queried set.** Filtering your sprint snapshot for `Parent == featureId` only finds children that happen to sit in the sprints you queried. A Feature whose children live in a different sprint will silently pass the check while still double-counting. Fetch the Feature with `expand: "Relations"` and follow `System.LinkTypes.Hierarchy-Forward`.

**Why it matters:** the sprint total double-counts. A Feature at 5 points whose children sum to 8 makes the sprint look 5 points heavier than the actual work. This inflates against velocity and causes real work to be deferred for no reason.

**Fix:** `Remove` the points from the parent. Not `Replace` with `0` — zero is a real estimate and rolls up as one.

**Caveat:** a Feature with no pointed children may legitimately carry an estimate as a placeholder. Check for children before flagging.

---

## 2. Target date precedes its own sprint

**Detect:** `TargetDate` earlier than the start of the item's `IterationPath` month.

**Why it matters:** the item is already late the moment the sprint opens, and nothing surfaces that. It usually means the item was moved between sprints and the date wasn't updated — so the date reflects a commitment that was quietly abandoned.

**Fix:** ask whether the date or the sprint is correct. Both answers are common; don't guess.

---

## 3. Dated commitment with no work item

**Detect:** cross-reference dates the user states in conversation — "deliver X by 10/15" — against `TargetDate` values on the board. A stated date with no item within a few days of it is a gap.

**Why it matters:** this is the most expensive miss on the list. Nothing tracks it, so nothing warns when its upstream dependencies slip. It surfaces the week it's due.

**Fix:** create a milestone story in the sprint containing the date, with a dependency table naming the upstream work and the gate each one must clear.

---

## 4. Long-lived blocked items

**Detect:** `State == "Blocked"` where the state change date is more than one sprint old.

**Why it matters:** blocked items roll month to month unexamined, consuming allocated points while doing nothing. They also mask the fact that whatever they're waiting on is never arriving.

**Fix:** ask for an explicit decision — chase the dependency, defer with a re-evaluation date, or remove. "Leave it blocked in the current sprint" is a valid answer, but it should be a choice rather than a default.

---

## 5. Sprint items outside every declared priority

**Detect:** after mapping every item to the user's ordered priority list, anything unmapped.

**Why it matters:** it's real, committed work that the priority framework doesn't account for. Either the priority list is incomplete, or the item shouldn't be in the sprint. Both are worth knowing before the plan is shared with a manager who will read the priority list as complete.

**Fix:** surface it. Don't silently drop it from the one-pager — show it under an "outside this list" line so the point total reconciles.

---

## 6. Next sprint already over velocity

**Detect:** sum the next sprint's points after applying the planned deferrals, and compare to velocity.

**Why it matters:** the constraint is usually next month, not this one. Deferring work to protect the current sprint feels responsible and is often just moving the problem somewhere less visible. If next month is already over before the deferrals land, the deferral isn't a plan.

**Fix:** flag it as the leading risk. If a dated commitment depends on next sprint's capacity, say so explicitly — that combination is how deadlines are missed.

---

## 7. Unpointed items

**Detect:** items in the sprint with null `StoryPoints`, excluding `Removed`.

**Why it matters:** every capacity number in the plan is wrong by an unknown amount. In one real sprint, 18 of 52 items — 35% — carried no estimate, which means both the sprint load and the velocity derived from it were understated by roughly a third. You cannot plan against velocity if velocity is measured from partially-estimated sprints.

This compounds: unpointed items close, contribute zero to the closed-point total, and depress the velocity baseline that next month's plan is measured against.

**Fix:** report the count and percentage. Ask for estimates on anything above ~15% of the sprint, or agree explicitly that certain item types — Features, tracking items, recurring overhead — are never pointed and exclude them from the ratio.

---

## Reporting

Group findings by severity, most consequential first. For each: what was found, which items, and what decision is needed. Keep it to a line or two each — the point is to surface them, not to write an essay per finding.

Do not auto-fix. Every one of these has a legitimate variant, and silently "correcting" a deliberate choice erodes trust in the whole planning pass.
