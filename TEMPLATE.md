# Standing Order Definition — <order name>

Copy this file into the repo that runs the job, at `orders/<order-name>.order.md`. The
**contract block** below is what a gate script checks — a standing order whose definition
doesn't pass does not go live. The prose sections after the block carry the human context a
reviewer needs that the contract block can't express in `key: value` form.

The `orders/` directory of a repo is that repo's standing-order registry: one `.order.md` file
per job, plus an optional `orders/KILL-SWITCH` file. If that file exists, every standing order
in the repo must treat itself as paused — each iteration's stop-check tests for it before doing
anything else. See [README.md](README.md) for the doctrine this template encodes.

## Contract block (keep the `Key: value` format, one field per line)

```
Order-Name: <kebab-case-name>
Version: <n.n>
Owner: <named accountable human or team — not a role nobody staffs>
Project: <project or repo this order runs against>
Trigger: <heartbeat | schedule | event | goal>
Cadence: <interval, cron expression, event source, or n/a for goal>
Autonomy: <A0 | A1 | A2 | A3>
Verification: <self-check | independent | adversarial | human-gate>
Scope: <the file or surface scope this order may touch>
Iteration-Cap: <integer — max attempts per task, and max iterations per run>
Escalate-After: <integer — repeated failures on the same item that trigger the mandatory human gate>
Budget-Cap: <token/time/cost ceiling per run AND per week, with real numbers>
Review-Triggers: <this order's own false-positive ceiling and budget-alert line — both set at declaration time, not inherited from doctrine>
No-Progress-Exit: <how a stalled run is detected — e.g. identical state hash twice in a row; or not-applicable: <reason> if there is truly nothing to retry within a single run>
Goal-Check: <machine-verifiable done criterion, required when Trigger is goal — otherwise not-applicable: <reason>>
Kill-Switch: <path checked at every stop-check — e.g. orders/KILL-SWITCH>
State-File: <this order's ledger — durable state it reads on wake and writes on completion, e.g. orders/state/<name>.md>
Escalation: <who is notified, on what condition, over which channel>
Denylist-Ack: <the literal word "yes" — only after the path denylist in README.md is applied>
Signoff: <name + date — required if Autonomy is A3, else n/a>
Rollout-Stage: <A0-observing | A1 | A2 | A3, plus the date it entered that stage>
```

## What this standing order does
<one paragraph: the job, the surfaces it reads, the actions it's permitted to take>

## Why this autonomy level
<the evidence behind the current Rollout-Stage, and what would justify promoting it>

## Verification detail
<who or what verifies each iteration, and — this is the part reviewers skip — exactly what the
verifier EXECUTES rather than merely inspects; list which human-gate items apply, if any>

## Budget rationale
<per-iteration cost estimate × cadence = projected spend; alert threshold as set in
`Review-Triggers`, not a fixed default>

## Run log & metrics
<where structured run-logs land; what gets reviewed on a cadence — how many times it ran, what
it actually did, how often a human had to step in, what it spent, and how long a failure sat
before a person saw it>
