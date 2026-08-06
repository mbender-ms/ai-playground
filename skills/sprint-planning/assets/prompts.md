# Prompts — how this skill got built

The actual prompts, verbatim, in the order they were typed — the ones that turned a one-off monthly planning session into a portable skill.

Identifying details are removed: no work item IDs, no names, no org or project names, no service names, no real board numbers.

The point of this file for the presentation: **nobody set out to build a skill.** The first request was ordinary sprint planning. The skill is what fell out once the workflow had been run end to end and was obviously repeatable.

---

## 1. Ask the reusability question

> I want to make my sprint planning process re-useable.
> Create a plan for how I'd recreate the outputs monthly.
> Also, I'd like to share this with teammates.
> Recommend model the work should be run in.
> Also, recommend if this should be a standalone skill.

**What it produced:** the decision to build a skill at all, plus the two structural choices that shaped everything after — `config.json` as the portability boundary, and frontier reasoning for the whole run because the failure modes are silent (arithmetic that lands in a manager-visible document, and judging which six questions to ask out of a seventy-item board).

**Why it mattered:** this is the hinge. Asking "should this be a skill?" *after* doing the work once produces a skill that documents reality. Asking it before produces a designed process that doesn't survive contact with a real board.

Note what the prompt does *not* do: it doesn't assume the answer. *"Recommend if this should be a standalone skill"* leaves room for "no." Two of the four asks — model tier and sharing — are the ones that actually determined the structure.

---

## 2. Build it on a known scaffold

> Build in default Skills location using skill-creator skill from anthropic

**What it produced:** the folder layout — `SKILL.md` with the workflow body, `references/` for the fiddly details, `assets/` for the template, `evals/` for test prompts.

**Why it mattered:** one short sentence, two decisions. *"Default Skills location"* means it's discoverable the moment it exists, not sitting in a scratch folder. *"Using skill-creator"* means the conventions come from something that already knows them — including the guidance that when the conversation already contains the workflow, you extract it from history rather than interviewing from scratch. That applied exactly.

---

## 3. Smoke test it against history

> Smoke test skill by running historically for the Month of July and June

**What it produced:** three real findings — a scoping bug in the first anti-pattern check, an entirely missing check (42% of one month's closed items were unpointed), and a velocity flag that turned out to be wrong and was retracted with evidence.

**Why it mattered:** **this is the most important prompt in the build.** Past months are free test data — real boards, no write risk, and you already know what the answer should look like. The velocity finding rewrote a whole phase of `SKILL.md`: the skill's own default guidance (prefer a trailing average) would have produced a materially worse plan, because the months being averaged were structurally different work. A smoke test that only confirms what you already believe hasn't tested anything.

Honest limitation, recorded in `summary.md`: closed sprints have no blocked items and no carry-forward, so three of the checks returned "none" correctly and were never actually exercised. History is a strong test of arithmetic and parsing, a weak test of anything about unresolved state.

---

## 4. Write the README before you think you need it

> Add a readme.md to the skill root.
> Include examples of how to use.
> Include enough information so someone with just the readme.md and skill can utilize it.
> Include suggestions for adding personal customizations.

**What it produced:** `README.md`, written to the "someone with only this file" bar.

**Why it mattered:** the constraint *"someone with just the readme.md and skill can utilize it"* is what forced hidden assumptions into the open. Every place the README couldn't explain something without referencing my board became a candidate for `config.json`.

---

## 5. Write down what went wrong

> Add a summary.md
> this summarizes the work being done in this chat, the items that were corrected along the way, re-directions, and how the skill was built.
> Intent is to provide a written account of what went into building the eventual skill.
> If necessary, review other sprint planning chats and the handoff docs.

**What it produced:** `summary.md` — the build account, including the corrections, the scoping bug the smoke test found, and the one flag that was raised and then retracted with evidence.

**Why it mattered:** *"items that were corrected along the way, re-directions"* is the operative clause. A summary of what worked is marketing. A summary of what broke explains why half the instructions in `SKILL.md` exist.

---

## 6. Find the next skill the same way

> Review my last 5 days and create a list of candidates to create skills from the workflows based on the skill-creator skill from Anthropic.
> If you don't have the skill, download it and put it in the default directory.
> Ask clarifying questions.

**What it produced:** a ranked list of repeated workflows worth turning into skills.

**Why it mattered:** generalizes the accident. Session history is the evidence of what you actually do repeatedly — better input than brainstorming what you *think* you'd automate. Note the two throwaway clauses doing real work: *"if you don't have the skill, download it"* (self-healing setup) and *"ask clarifying questions"* (stops the model from guessing scope).

---

## 7. Push the personal constants into one file

> in sprint-planner, use config.json for hard-coded items that a teammate would use like manager name

**What it produced:** every person-specific value — area path, parent IDs, email, priority names, manager name — pulled out of `SKILL.md`, the references, and the HTML template into a single `config.json`.

**Why it mattered:** this is the entire portability story in one prompt. Onboarding a teammate becomes "copy the folder, edit one file." Anything a teammate would have to change belongs in config, not in the workflow body.

---

## The pattern

| Phase | Prompt shape |
|---|---|
| Do the work | A normal request. No skill in mind. |
| Notice repetition | "Make this re-useable. Recommend whether it should be a standalone skill." |
| Build on a scaffold | "Build in the default skills location using skill-creator." |
| Test against reality | "Smoke test it by running historically against past months." |
| Force portability | "Write the README for someone who only has this file." |
| Capture failure | "Summarize what was corrected and re-directed." |
| Generalize | "Review my history for other workflows worth skilling." |
| Externalize constants | "Put anything a teammate would change into config." |

The two that carry the most weight are the ones that look least like building: **asking whether it should be a skill at all**, and **testing it against months you already know the answer to**.
