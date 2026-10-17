#!/usr/bin/env bash
# test_gate_dangling_blocker_refused.sh -- DONE-WHEN gate for row `picker-dangling-blocker-parks-a-row-forever-in-silence`.
#
# Exercises BOTH cures in a fully isolated sandbox postoffice (S4E_POST override) plus S4E_QUEUE/S4E_QUEUE_DONE
# overrides for the audit script -- never touches the live /home/resources/postoffice.
#   cure 1: `s4e_msg.sh park <topic> BLOCKED-ON:<dangling>` REFUSES rc=2, leaves QUEUE.tsv untouched.
#           A real-blocker park, a swept-done-blocker park, an unpark to FREE, and a plain PARKED (no colon
#           blocker at all) must all still SUCCEED -- this is a refusal of ONE new bad shape, not a regression
#           in ordinary park usage.
#   cure 2: `util_queue_dangling_blocker.sh` reports the dangling row (rc=1) and stays silent (rc=0) once
#           repaired, and correctly does NOT flag a blocker that is a live row or an already swept-done one.
#
# usage: bash ../harness/scripts/test_gate_dangling_blocker_refused.sh
# exit:  0 = both cures behave correctly   1 = a behavioral check failed   2 = REFUSES (cannot set up the sandbox)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MSG="$HERE/s4e_msg.sh"
AUDIT="$HERE/util_queue_dangling_blocker.sh"
[ -x "$MSG" ] || { echo "⛔ REFUSES rc=2: $MSG not found/executable" >&2; exit 2; }
[ -x "$AUDIT" ] || { echo "⛔ REFUSES rc=2: $AUDIT not found/executable" >&2; exit 2; }
T="$(mktemp -d)" || { echo "⛔ REFUSES rc=2: mktemp -d failed" >&2; exit 2; }
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/po/seat_gate/inbox" "$T/po/tasks" "$T/po/claims" || { echo "⛔ REFUSES rc=2: sandbox mkdir failed" >&2; exit 2; }
cat > "$T/po/QUEUE.tsv" <<'EOF'
0	real-row-a	unassigned	FREE
1	target-row	unassigned	FREE
EOF
cat > "$T/po/QUEUE.done.tsv" <<'EOF'
99	already-finished-row	seat01	DONE
EOF
fail=0
check() { # <label> <expected-rc> <actual-rc>
  if [ "$2" = "$3" ]; then echo "  ok   $1 (rc=$3)"; else echo "  FAIL $1 (expected rc=$2, got rc=$3)"; fail=1; fi
}
export S4E_POST="$T/po" S4E_SEAT=seat_gate
# --- cure 1: park refusals / non-regressions ---
out="$(bash "$MSG" park target-row "PARKED-AWAITING:some-subitem-gloss-not-a-row" 2>&1)"; rc=$?
check "park refuses a dangling PARKED-AWAITING blocker" 2 "$rc"
st="$(awk -F'\t' '$2=="target-row"{print $4}' "$T/po/QUEUE.tsv")"
if [ "$st" = "FREE" ]; then echo "  ok   QUEUE.tsv state untouched by the refused park (still FREE)"
else echo "  FAIL QUEUE.tsv state was mutated by a refused park (now: $st)"; fail=1; fi
case "$out" in *"has no QUEUE.tsv row"*) echo "  ok   refusal message names the dangling blocker" ;;
  *) echo "  FAIL refusal message missing expected text"; fail=1 ;; esac
bash "$MSG" park target-row "BLOCKED-ON:real-row-a" >/dev/null 2>&1; check "park still succeeds behind a REAL live blocker" 0 "$?"
bash "$MSG" park target-row "BLOCKED-ON:already-finished-row" >/dev/null 2>&1; check "park still succeeds behind a swept-DONE blocker" 0 "$?"
bash "$MSG" park target-row FREE >/dev/null 2>&1; check "park still succeeds un-parking to FREE" 0 "$?"
bash "$MSG" park target-row PARKED >/dev/null 2>&1; check "park still succeeds for a plain PARKED (no blocker)" 0 "$?"
unset S4E_POST S4E_SEAT
# --- cure 2: audit script ---
cat > "$T/po/QUEUE2.tsv" <<'EOF'
0	real-row-a	unassigned	FREE
1	blocked-on-real	unassigned	BLOCKED-ON:real-row-a
2	blocked-on-dangling	unassigned	PARKED-AWAITING:some-subitem-gloss-not-a-row
3	blocked-on-swept-done	unassigned	BLOCKED-ON:already-finished-row
EOF
S4E_QUEUE="$T/po/QUEUE2.tsv" S4E_QUEUE_DONE="$T/po/QUEUE.done.tsv" bash "$AUDIT" --quiet >/dev/null 2>&1
check "audit reports the dangling row (rc=1)" 1 "$?"
sed -i '/blocked-on-dangling/d' "$T/po/QUEUE2.tsv"
S4E_QUEUE="$T/po/QUEUE2.tsv" S4E_QUEUE_DONE="$T/po/QUEUE.done.tsv" bash "$AUDIT" --quiet >/dev/null 2>&1
check "audit is clean once the dangling row is removed (rc=0)" 0 "$?"
S4E_QUEUE="/tmp/nonexistent-$$" bash "$AUDIT" >/dev/null 2>&1
check "audit REFUSES rc=2 on an unreadable QUEUE" 2 "$?"
if [ "$fail" = 0 ]; then echo "✅ GATE OK -- park refuses dangling blockers, audit finds/clears them, no regression in ordinary park usage"; exit 0
else echo "⛔ GATE FAIL -- see FAIL lines above"; exit 1; fi
