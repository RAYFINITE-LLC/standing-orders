#!/bin/sh
# order-gate.sh — go-live gate for a Standing Order declaration.
#
# Validates a standing-order definition file (see TEMPLATE.md) against the mandatory
# stop-condition quad and the guardrail acknowledgements described in README.md. Run it before a
# standing order goes live, and again after any change to its definition.
#
# Usage:   order-gate.sh <path-to-order-file>
#          order-gate.sh check <path-to-order-file>   (older form, still accepted)
# Exit:    0 = PASS (the standing order may go live)
#          2 = FAIL (one or more blocking findings — it must NOT go live)
#          1 = usage error or the file could not be read
#
# POSIX sh, no dependencies beyond grep/sed — this is meant to run anywhere, including inside a
# CI job that has nothing but a shell.

set -u

if [ "${1:-}" = "check" ]; then
  FILE=${2:-}
else
  FILE=${1:-}
fi

if [ -z "$FILE" ]; then
  echo "usage: order-gate.sh <path-to-order-file>" >&2
  exit 1
fi

if [ ! -r "$FILE" ]; then
  echo "order-gate: cannot read '$FILE'" >&2
  exit 1
fi

FAILS=0
fail() {
  FAILS=$((FAILS + 1))
  echo "  BLOCK: $1"
}

# field <Key>  ->  prints the trimmed value of the first "Key: value" line (empty if absent)
field() {
  sed -n "s/^$1:[[:space:]]*//p" "$FILE" | head -n 1 | sed 's/[[:space:]]*$//'
}

# is_placeholder <value>  ->  true if the value is empty, or STARTS WITH a placeholder token
# (n/a, none, tbd, pending — any casing). Matches on the leading token, not the whole string, so
# "n/a — see below" and "TBD (pending review)" are caught the same as a bare "n/a" instead of
# slipping past an exact-string check.
is_placeholder() {
  case "$1" in
    ""|[nN]/[aA]*|[nN]-[aA]*|[nN][oO][nN][eE]*|[tT][bB][dD]*|[pP][eE][nN][dD][iI][nN][gG]*) return 0 ;;
    *) return 1 ;;
  esac
}

echo "order-gate: checking $FILE"

# --- 1. Required fields present and non-empty -------------------------------
REQUIRED="Order-Name Version Owner Project Trigger Cadence Autonomy Verification Scope \
Iteration-Cap Escalate-After Budget-Cap Review-Triggers No-Progress-Exit Goal-Check Kill-Switch \
State-File Escalation Denylist-Ack Signoff Rollout-Stage"
for key in $REQUIRED; do
  val=$(field "$key")
  [ -n "$val" ] || fail "missing or empty required field '$key:'"
done

TRIGGER=$(field "Trigger")
AUTONOMY=$(field "Autonomy")
VERIFICATION=$(field "Verification")
ITER_CAP=$(field "Iteration-Cap")
ESCALATE_AFTER=$(field "Escalate-After")
GOAL_CHECK=$(field "Goal-Check")
SIGNOFF=$(field "Signoff")
DENYLIST=$(field "Denylist-Ack")

# --- 2. Enumerated values ----------------------------------------------------
case "$TRIGGER" in
  heartbeat|schedule|event|goal|"") : ;;
  *) fail "Trigger '$TRIGGER' is not one of: heartbeat | schedule | event | goal" ;;
esac
case "$AUTONOMY" in
  A0|A1|A2|A3|"") : ;;
  *) fail "Autonomy '$AUTONOMY' is not one of: A0 | A1 | A2 | A3" ;;
esac
case "$VERIFICATION" in
  self-check|independent|adversarial|human-gate|"") : ;;
  *) fail "Verification '$VERIFICATION' is not one of: self-check | independent | adversarial | human-gate" ;;
esac

# --- 3. The stop-condition quad ----------------------------------------------
case "$ITER_CAP" in
  ""|*[!0-9]*) fail "Iteration-Cap must be a positive integer (got '$ITER_CAP')" ;;
  0)           fail "Iteration-Cap must be greater than 0" ;;
esac
case "$ESCALATE_AFTER" in
  ""|*[!0-9]*) fail "Escalate-After must be a positive integer (got '$ESCALATE_AFTER')" ;;
  0)           fail "Escalate-After must be greater than 0" ;;
esac
# Budget-Cap / Review-Triggers: must be real, order-declared values — never a placeholder, and
# there is no "not-applicable" exemption for either (every order sets its own numbers here).
for k in "Budget-Cap" "Review-Triggers"; do
  v=$(field "$k")
  if is_placeholder "$v"; then
    fail "$k must be a real, order-specific value, not a placeholder"
  fi
done
# No-Progress-Exit: a real stop-condition, OR the explicit "not-applicable: <reason>" — a bare
# n/a / TBD / pending reads as an unfinished contract, not a considered answer, and still fails.
NPE=$(field "No-Progress-Exit")
case "$NPE" in
  not-applicable:*) : ;;
  *)
    if is_placeholder "$NPE"; then
      fail "No-Progress-Exit must be a real stop-condition value, or the explicit 'not-applicable: <reason>'"
    fi
    ;;
esac
# Goal-Check: when Trigger is goal, a real verifiable done-criterion is required — marking it
# not-applicable is itself a failure here. When Trigger is anything else, the field must be the
# explicit "not-applicable: <reason>" — a bare n/a (or a stray done-criterion) is not accepted.
if [ "$TRIGGER" = "goal" ]; then
  case "$GOAL_CHECK" in
    not-applicable:*)
      fail "Trigger is 'goal' but Goal-Check is marked not-applicable — a goal-triggered order needs a real, verifiable done-criterion" ;;
    *)
      if is_placeholder "$GOAL_CHECK"; then
        fail "Trigger is 'goal' but Goal-Check has no verifiable done-criterion"
      fi
      ;;
  esac
else
  case "$GOAL_CHECK" in
    not-applicable:*) : ;;
    *) fail "Goal-Check must be the explicit 'not-applicable: <reason>' when Trigger is not 'goal'" ;;
  esac
fi

# --- 4. Autonomy / verification topology rules -------------------------------
if [ "$AUTONOMY" != "A0" ] && [ -n "$AUTONOMY" ] && [ "$VERIFICATION" = "self-check" ]; then
  fail "Verification 'self-check' is only allowed at A0 (got Autonomy $AUTONOMY) — an independent verifier is required"
fi
if [ "$AUTONOMY" = "A3" ]; then
  if is_placeholder "$SIGNOFF"; then
    fail "Autonomy A3 requires a recorded Signoff (name + date)"
  fi
  if [ "$TRIGGER" = "goal" ] && [ "$VERIFICATION" != "adversarial" ] && [ "$VERIFICATION" != "human-gate" ]; then
    fail "goal-trigger + A3 requires Verification 'adversarial' or 'human-gate' (got '$VERIFICATION')"
  fi
fi

# --- 5. Guardrail acknowledgement --------------------------------------------
if [ "$DENYLIST" != "yes" ]; then
  fail "Denylist-Ack must be exactly 'yes' — the path denylist must be read and applied, not skipped"
fi

# --- 6. Kill switch — a repo-wide pause. Resolved directly from the declared Kill-Switch field,
#        relative to the current working directory order-gate.sh is invoked from (the repo root,
#        alongside the orders/ registry it's checking — see README.md's Adopting section). An
#        earlier version of this check ignored the declared field and instead hardcoded
#        "<one-directory-up-from-the-declaration>/orders/KILL-SWITCH" — which silently doubled up
#        into "orders/orders/KILL-SWITCH" for any repo that nests declarations under orders/, and
#        ignored a custom Kill-Switch path entirely. Reading the field directly removes both
#        failure modes. --------------------------------------------------------------------------
KILL_SWITCH=$(field "Kill-Switch")
if [ -n "$KILL_SWITCH" ] && [ -e "$KILL_SWITCH" ]; then
  fail "kill switch active — '$KILL_SWITCH' exists; repo-wide pause in effect, this order may not go live"
fi

# --- Verdict -------------------------------------------------------------------
if [ "$FAILS" -eq 0 ]; then
  NAME=$(field "Order-Name")
  echo "order-gate: PASS — contract complete; standing order '$NAME' may go live at $AUTONOMY."
  exit 0
else
  echo "order-gate: FAIL — $FAILS blocking finding(s); standing order must NOT go live."
  exit 2
fi
