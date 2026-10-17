#!/usr/bin/env bash
# sweep_free_rows_gate.sh -- THE CADENCE GATE for queue row `sweep-free-rows-are-real`.
# ⭐ WHY THIS EXISTS: that row is rank 0 and its DONE-WHEN refuses by design, so it is ALWAYS the
# topmost free row -- `s4e_msg.sh next` re-serves it to a fresh seat within seconds of the previous
# pass releasing it. Four separate picks (16:00Z, 18:54Z, 21:07Z, 21:08Z on 2026-08-24) opened a
# session, measured a 1-2 row delta, and released unworked. Passes 4-12 each flagged the underlying
# question -- event-driven vs clock-driven cadence -- and each declined it as "not this row's call".
# This script IS the call: it converts the clock-driven sweep into an event-driven one by measuring
# the delta BEFORE a pass is opened, so the decision is a computed exit status and not a judgement
# every seat has to re-derive from the LEDGER.
#
# ⛔ THE MISSING-INPUT ARM REFUSES (rc=2) AND NEVER SKIPS. This row's own sibling defect
# (`prolog-assertz-retract-abolish-unmasked`) exists because a `[ -d ] || exit 0` guard turned
# "I cannot measure" into "nothing to report" and hid 12 real failures for weeks. A gate that
# cannot read its inputs must be LOUD, never green.
#
# EXIT: 0 = gross churn >= threshold, a pass is worth running (proceed, work the row's ## NEXT)
#       1 = below threshold, RELEASE UNWORKED (record the delta in the LEDGER, do not open a pass)
#       2 = REFUSED, could not measure (missing QUEUE.tsv / claims/ / baseline) -- fix that first
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
PO="${S4E_POST:-/home/resources/postoffice}"
BASE="$PO/SWEEP-CLASSIFIED.tsv"
THRESHOLD="${SWEEP_CHURN_THRESHOLD:-4}"
[ -f "$PO/QUEUE.tsv" ] || { echo "⛔ REFUSE: no QUEUE.tsv at $PO" >&2; exit 2; }
[ -d "$PO/claims" ]    || { echo "⛔ REFUSE: no claims/ dir at $PO" >&2; exit 2; }
[ -f "$BASE" ]         || { echo "⛔ REFUSE: no baseline at $BASE -- pass 4 landed it; regenerate before gating" >&2; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# true-free := QUEUE.tsv state==FREE AND no claims/<topic>.claim  (../harness/scripts/s4e_msg.sh PASS 3)
# ⭐ QUEUE.tsv and claims/ are read back-to-back: at FLEET-12 velocity the set moves DURING a pass
# (pass 9 caught a claim landing between two reads, pass 12 caught two such races).
awk -F'\t' 'NF>=4 && $4=="FREE"{print $2}' "$PO/QUEUE.tsv" | sort > "$TMP/free"
ls "$PO/claims" | sed 's/\.claim$//' | sort > "$TMP/claimed"
comm -23 "$TMP/free" "$TMP/claimed" > "$TMP/truefree"
# ⛔ the baseline carries BOTH `#` comments AND one literal un-prefixed `TOPIC<TAB>VERDICT` header
# line; stripping only comments leaks that header in as a phantom GONE row (pass 10 caught it).
grep -v '^#' "$BASE" | awk -F'\t' 'NF>=1 && $1!="TOPIC" && $1!=""{print $1}' | sort > "$TMP/base"
comm -13 "$TMP/base" "$TMP/truefree" > "$TMP/new"
comm -23 "$TMP/base" "$TMP/truefree" > "$TMP/gone"
NEW=$(wc -l < "$TMP/new"); GONE=$(wc -l < "$TMP/gone"); GROSS=$((NEW+GONE))
NOW=$(wc -l < "$TMP/truefree"); WAS=$(wc -l < "$TMP/base")
echo "baseline $BASE ($(date -u -r "$BASE" +%Y-%m-%dT%H:%M:%SZ), $WAS topics)"
echo "true-free now: $NOW   net: $((NOW-WAS))   gross churn: $GROSS (new=$NEW gone=$GONE)  threshold: $THRESHOLD"
[ "$NEW"  -gt 0 ] && { echo "NEW:";  sed 's/^/  + /' "$TMP/new"; }
[ "$GONE" -gt 0 ] && { echo "GONE:"; sed 's/^/  - /' "$TMP/gone"; }
if [ "$GROSS" -ge "$THRESHOLD" ]; then
    echo "✅ RUN A PASS: gross churn $GROSS >= $THRESHOLD."
    exit 0
fi
echo "⛔ DO NOT OPEN A PASS: gross churn $GROSS < $THRESHOLD -- release unworked and record the delta in the LEDGER."
echo "   Rationale: measured gross churn was 4-11 on every pass that found something (5-12) and 1-2 on every"
echo "   pick that released unworked (16:00Z, 18:54Z, 21:07Z, 21:08Z). The threshold sits in that gap."
exit 1
