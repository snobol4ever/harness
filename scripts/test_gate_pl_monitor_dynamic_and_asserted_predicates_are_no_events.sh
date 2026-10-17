#!/usr/bin/env bash
# test_gate_pl_monitor_dynamic_and_asserted_predicates_are_no_events.sh -- THE PROLOG PLUG IS SILENT FOR A PREDICATE THE PROGRAM DECLARES DYNAMIC OR
# CREATES BY ASSERT (ceo CEO-1269, MONITOR-BINARY-DESIGN.md, the Prolog reading of the contract: no CALL, no STMT inside its clauses, no RETURN, on
# every side; gpx and swx already hold it). hq_prolog 2026-09-25, CEO-1266/1270; the cure is lower_prolog.c pl_pred_graph, whose silence test
# for prelude (library) predicates now also asks pl_db_owned -- declared dynamic, or given a database slot with no clause in the file.
# THE BRACKET IT CURES: sync_step_prolog_4.pl against gpx agreed to step 34 (LABEL stno=12) and diverged at step 35, scr firing
# CALL counter/1 for the dynamic counter/1 where gpx fires nothing. With the plug silent the witness agrees to its end (AGREE=44 DIVERGE=0).
# ARMS: 1 (no oracle) the trace names the static st/1 and NEITHER the dynamic counter/1, NOR the asserted made/1,
#       NOR a meta-called ==/2 (a built-in's compiled meta-call wrapper is library code: the second half of CEO-1269, bracketed on Logtalk
#       logical_update_semantics_clause_retract at step 117, scr firing CALL ==/2 for the case's (Assertion) goal) -- st/1 is the control against
#       a plug that went silent for everything. (A program may not redefine a built-in under gprolog -- gplc refuses append/3 -- so no oracle
#       arbitrates a same-named program predicate; the silence test still keeps one the file defines, via !pl_file_defines.)
#       2 (gpx) monitor_run.sh on sync_step_prolog_4.pl reads AGREE with DIVERGE=0; a missing gpx REFUSES rc=2, never a pass.
# RED BEFORE on origin ccbe115b5: ARM 1 names counter/1 and made/1 (and L212 inside made/1); ARM 2 DIVERGE at step 35.
set -u
GATE_NAME=test_gate_pl_monitor_dynamic_and_asserted_predicates_are_no_events
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$HERE/../../SCRIP/out/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0
cat > "$TMPD/dyn.pl" <<'EOP'
:- dynamic(counter/1).
counter(0).
st(X) :- X = 1.
main :- counter(C), write(C), nl, assertz(made(7)), made(M), write(M), nl, st(S), write(S), nl,
        G = (1 == 1), call(G), write(G), nl.
:- initialization(main).
EOP
tr="$(timeout -k 5 30 "$SCRIP" --trace --run "$TMPD/dyn.pl" </dev/null 2>&1)"; trc=$?
[ "$trc" = 0 ] || refuse "the traced run exited $trc -- ARM 1 measured nothing"
printf '%s\n' "$tr" | grep -q 'st/1()' && printf '%s\n' "$tr" | grep -q 'RETURN st/1' || { echo "  RED ARM 1: the static st/1 fired no CALL/RETURN -- the plug went silent for everything"; red=$((red+1)); }
for p in counter/1 made/1 ==/2; do
    if printf '%s\n' "$tr" | grep -qE "(^|[[:space:]])$p\(\)|RETURN $p "; then echo "  RED ARM 1: $p fired a trace event -- a dynamic or asserted predicate is an event"; red=$((red+1)); fi
done
[ "$red" = 0 ] && echo "  ok  ARM 1: st/1 traced; counter/1 (dynamic), made/1 (asserted) and a meta-called ==/2 silent"
W="$HERE/monitor/witnesses/sync_step_prolog_4.pl"
[ -r "$W" ] || refuse "no witness at $W"
out="$(timeout -k 5 300 bash "$HERE/monitor_run.sh" "$W" --oracle 2>&1)"; mrc=$?
[ "$mrc" = 2 ] && refuse "monitor_run.sh could not measure: $(printf '%s' "$out" | grep -m1 REFUSE | cut -c1-200)"
if [ "$mrc" = 0 ] && printf '%s' "$out" | grep -qE 'AGREE=[0-9]+ DIVERGE=0 UNGRADED=0'; then echo "  ok  ARM 2: $(printf '%s' "$out" | grep -oE 'AGREE=[0-9]+ DIVERGE=0 UNGRADED=0')"
else echo "  RED ARM 2 (rc=$mrc): $(printf '%s' "$out" | grep -m1 -E 'VERDICT|DIVERGE' | cut -c1-200)"; red=$((red+1)); fi
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: dynamic and asserted predicates are no monitor events, static ones still are, and witness 4 agrees with gpx to its end"
exit 0
