# Standing Order Definition — release-notes-drafter

A filled-in example. Copy [`TEMPLATE.md`](../TEMPLATE.md) for a blank one.

## Contract block

```
Order-Name: release-notes-drafter
Version: 1.0
Owner: docs lead
Project: acme/storefront-api
Trigger: schedule
Cadence: 08:00 UTC every Monday (cron: 0 8 * * 1)
Autonomy: A1
Verification: independent
Scope: read-only across pull requests merged in the past 7 days and their commit messages; writes only to orders/state/release-notes-drafter.md and one draft file per run under drafts/release-notes/
Iteration-Cap: 1
Escalate-After: 2
Budget-Cap: 25k tokens per run, 120k tokens per week; auto-pause at the weekly cap, alert at the line set in Review-Triggers
Review-Triggers: review this order off-cycle if more than one in four drafted entries needs a real rewrite rather than a light edit, or if any single run passes 20k tokens
No-Progress-Exit: not-applicable: single-pass job per run, nothing to retry within a run
Goal-Check: not-applicable: trigger is schedule, not goal
Kill-Switch: orders/KILL-SWITCH
State-File: orders/state/release-notes-drafter.md
Escalation: two consecutive weeks with no mergeable content (an empty window) pings #docs-lead directly; everything else waits for the owner's normal Monday read
Denylist-Ack: yes
Signoff: not-applicable: autonomy is A1, not A3
Rollout-Stage: A1, since 2026-03-02 (two full weekly cycles at A0 preceded promotion)
```

## What this standing order does

Once a week, reads every pull request merged in the preceding seven days, groups them by the
area of the codebase they touched, and drafts a plain-language release-notes entry for the docs
lead to edit or approve. It never publishes anything on its own — the draft lands as a file for a
human to read on their normal schedule, adjust as needed, and push out themselves. If nothing
merged that week, it writes a one-line "nothing to report" note rather than inventing content to
fill the gap.

## Why this autonomy level

Two full weekly cycles at A0 (draft written to the order ledger, nothing surfaced anywhere else)
showed the grouping and tone landed close enough to what the docs lead would have written by hand
that only a light edit was needed on 7 of 8 entries. That evidence supported promotion to A1 —
the draft now lands somewhere a person will see it on their existing cadence, but nothing it
writes is ever treated as final without someone reading it first. A2 isn't planned for this
order: release notes reach customers directly, which puts them in the outward-facing human-gate
category regardless of how reliable the draft has gotten.

## Verification detail

A separate verifier pass re-pulls the same seven-day pull-request list straight from the source
API — never from the drafter's own notes — and confirms every item the draft mentions genuinely
merged inside the claimed window, and that nothing which merged is missing from it. That check
has to pass before the draft file is even written. No human-gate category applies to the
drafting step itself (it never touches auth, payments, personal data, infrastructure, or a
schema); the draft's eventual publication is a separate, always-human action outside this order's
scope entirely.

## Budget rationale

Roughly 18-22k tokens per run (the drafting pass plus the verifier's independent re-pull) at
current merge volume, times one run per week — comfortably under the weekly cap, with headroom
if merge volume grows. `Review-Triggers` above sets the point where that growth, or a drop in
draft quality, should prompt a look before the next scheduled review rather than after.

## Run log & metrics

Each run appends one entry to `orders/state/release-notes-drafter.md`: timestamp, pull requests
covered, draft link, whether the window was empty, and token spend. Reviewed monthly: how many
runs happened (should be four or five), how much of each draft survived to publication unedited,
how often the docs lead had to substantially rewrite rather than lightly edit, spend against
budget, and how long an empty-window escalation sat before someone acknowledged it.
