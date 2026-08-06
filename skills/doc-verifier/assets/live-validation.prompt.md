---
mode: agent
description: "Gated empirical validation for contested numeric/behavioral claims. Read-only API introspection by default; mutating probe only on explicit user opt-in. Never auto-runs mutating commands."
tools:
  - execute/runInTerminal
  - microsoft-learn-mcp-server/microsoft_docs_fetch
  - read/readFile
  - todo
---

# Live Validation (escalation)

Use ONLY when a claim is `⚖️ Contested` (prose conflict + contract silent) or an Escalation Trigger fires and the user approves.

## Tier 4a — Read-only introspection (default-safe)
- `az <cmd> --help`, `Get-Help <cmd> -Full`, `az rest --method get` against provider metadata.
- No resources created or modified. Capture accepted ranges/defaults from parameter help.
- Record results as `verification_method: live` with `confidence: high`.

## Tier 4b — Mutating probe (opt-in only)
- GENERATE a boundary-probe script; present it to the user. NEVER execute without explicit approval.
- Require a non-production subscription, `az login`, and always include resource cleanup.
- After the user runs it (or approves running it), fold the accepted/rejected boundary into the verdict and flip `contested` → `accurate`/`inaccurate`.

## Guardrails
- Default to 4a. Escalate to 4b only with explicit confirmation.
- Never bypass safety checks; never leave resources behind.
