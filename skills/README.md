# skills

Skill packages. One folder per skill, each containing a `SKILL.md` plus any scripts,
references, or assets it needs. Related skills can be grouped in a subfolder.

```
skills/
  doc-verifier/               technical accuracy verification for Microsoft docs
  sprint-planning/            monthly ADO sprint planning, end to end
  laa/                        Learn Authoring Assistant workflows
    laa-clone/                local multi-pass authoring review
    laa-block-remediation/    find and clear LAA suggestion blocks on PRs
```

Everything here is sanitized for public use — org names, emails, manager names, and local
paths are placeholders. Set your own values before running: `sprint-planning/config.json`
for the sprint planner, and `LAA_SUGGESTIONS_PATH` for the LAA skills.
