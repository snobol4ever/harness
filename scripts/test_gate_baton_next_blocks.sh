#!/usr/bin/env bash
# test_gate_baton_next_blocks.sh — THE ONE-NEXT-BLOCK INVARIANT over LIVE batons (ceo 2026-08-29, row baton-one-next-block-gate).
#
# LAW (PROTOCOL.md step 4, ceo ruling 2026-08-29 on hq_B's measured finding): a baton carries exactly ONE `^## NEXT`
# heading — newest FIRST; replaced blocks are demoted to `## SUPERSEDED-NEXT`. hq_B measured why this is a gate and not
# a style note: 45 of 420 batons had NO block (a seat told to "read the ONE ## NEXT block" found a void and floundered —
# measured empty sessions), 8 had several under two OPPOSITE conventions, and one live rank-1 baton's five blocks were
# physically scrambled so the top block was FALSE (FINDING-2026-08-29-hq_B-baton-next-blocks-carry-two-opposite-conventions-*).
#
# SCOPE: LIVE rows only — present in QUEUE.tsv with a state not SUPERSEDED/RETIRED/DONE. Done/retired batons are history.
# A live row with NO baton file at all is counted as an offender too (the picker prints a task path that does not exist).
#
# RATCHET, NOT A HARD ==1 (hq_B's recommendation, adopted): allowed offenders start at the post-sweep baseline and may
# only FALL. Raise this number in a commit and you are reinstating the flounder class; the gate prints every offender by
# name so the sweep row can drive it to 0. Override for negative-arm testing only: S4E_NEXT_RATCHET.
#
# THREE STATES: rc=0 within ratchet | rc=1 above ratchet (offenders named) | rc=2 cannot measure (never skip-as-success)
set -u
PO="${S4E_POST:-/home/resources/postoffice}"
RATCHET="${S4E_NEXT_RATCHET:-4}"
Q="$PO/QUEUE.tsv"
[ -r "$Q" ] || { echo "⛔ REFUSE rc=2: cannot read $Q — nothing was measured"; exit 2; }
live=$(awk -F'\t' '!/^#/ && NF>=4 && $4!~/^(SUPERSEDED|RETIRED|DONE)/{print $2}' "$Q" | sort -u)
[ -n "$live" ] || { echo "⛔ REFUSE rc=2: zero live rows enumerated from $Q — an empty denominator is not a pass"; exit 2; }
total=0; bad=0; offenders=""
while IFS= read -r t; do
    [ -n "$t" ] || continue
    f="$PO/tasks/$t.task.md"
    total=$((total+1))
    if [ ! -f "$f" ]; then bad=$((bad+1)); offenders="$offenders
  NO-BATON   $t"; continue; fi
    n=$(grep -c '^## NEXT' "$f")
    if [ "$n" -eq 0 ]; then bad=$((bad+1)); offenders="$offenders
  ZERO-NEXT  $t"
    elif [ "$n" -gt 1 ]; then bad=$((bad+1)); offenders="$offenders
  MULTI-NEXT($n) $t"; fi
done <<EOF
$live
EOF
[ "$total" -gt 0 ] || { echo "⛔ REFUSE rc=2: enumerated no batons — nothing was measured"; exit 2; }
echo "=== BATON NEXT-BLOCK GATE: live=$total offenders=$bad ratchet=$RATCHET ==="
[ -n "$offenders" ] && printf '%s\n' "$offenders" | sed '/^$/d'
if [ "$bad" -gt "$RATCHET" ]; then echo "⛔ FAIL: $bad offender(s) exceed the ratchet ($RATCHET) — fix the batons, never raise the number"; exit 1; fi
echo "✅ PASS: $bad offender(s) within the never-rising ratchet ($RATCHET)"
exit 0
