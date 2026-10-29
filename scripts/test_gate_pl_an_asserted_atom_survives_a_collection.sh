#!/usr/bin/env bash
# stale-binary preflight -- util_require_fresh.sh is the ONE authority; no second copy of the staleness rule here.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_an_asserted_atom_survives_a_collection.sh -- AN ATOM STORED IN AN ASSERTED CLAUSE MUST STILL BE
# THAT ATOM AFTER A COLLECTION LANDS MID-OPERATION (hq_prolog 2026-09-16, row
# prolog-an-asserted-clauses-atom-argument-comes-back-empty-or-as-another-atoms-name-after-a-collection).
#
# ⛔⭐ WHAT THIS CATCHES IS A WRONG ANSWER, NOT A CRASH, AND THAT IS WHY IT EXISTS. Measured on SCRIP 385ac1f56:
# assert N clauses whose functor is interned AT RUN TIME and whose argument is a bound atom, then in a SECOND
# pass call them back. call(p_N(X)) SUCCEEDS -- the clause is there -- and X comes back as the EMPTY atom, or
# as p_10, WHICH IS ANOTHER ATOM'S NAME. A stale pointer that still reads plausibly is exactly what a single
# eyeball comparison cannot catch, which is why this grades against the oracle and grades REPEATEDLY.
#
# ⛔ THE REF IS CUT FROM swipl AT RUN TIME, NEVER FROM OUR OWN OUTPUT (CEO-753, and hq_U's standing ask on this
# class). If swipl cannot run, this REFUSES rc=2 -- it never falls back to a ref we minted ourselves.
#
# ⛔ THREE INGREDIENTS ARE ALL REQUIRED and ablating any one of them makes the witness pass, so do not "simplify"
# it: (1) the functor is interned at RUN TIME via atom_concat -- a static functor passes; (2) the argument is a
# bound ATOM -- an integer or an unbound variable passes; (3) assert-all THEN call-all in TWO passes -- interleaving
# assert and call passes. A witness missing any one of these banks a false green.
#
# ⛔ SCRIP_GC_STRESS IS A SANCTIONED CONFIGURATION, NOT A DEBUG TOY: five gates in this tree already grade under it
# (test_gc_stress_suite.sh, test_gate_gc_aggregate_interiors_are_marked_not_only_slotted.sh,
# test_gate_gc_table_insertion_order_array_is_rooted_not_pinned_alive.sh, test_gate_pas_heap_table_is_a_movable_root.sh,
# test_gate_rc8a_gc_coverage.sh). A collector must be correct at EVERY collection point; the knob only makes the
# point deterministic. ⭐ HONEST BOUND, STATED SO NOBODY OVERCLAIMS: this was NOT reproduced without the knob at
# N=200 or N=2000 (no collection occurs), and at N=20000 a DIFFERENT and unrelated limit fires first
# ("zls: vslot table overflow (16384)"), so the no-knob path could not be tested at that scale. This gate therefore
# proves a defect under a sanctioned configuration; it does NOT claim a frequency in ordinary runs.
#
# ⛔⭐ THIS GATE IS DELIBERATELY **NOT WIRED** INTO make test / test-sequential YET, AND THAT IS A DECISION, NOT AN
# OVERSIGHT. It grades an OPEN rank-0 defect (row prolog-an-asserted-clauses-atom-argument-comes-back-empty-or-as-
# another-atoms-name-after-a-collection), so wiring it today would turn the blocking set red for every seat in the
# fleet over a defect nobody is mid-cure on. It is written here so the row has a runnable DONE-WHEN and so the
# next seat can reproduce in one command. ⛔ WIRE IT BLOCKING IN THE LANDING THAT CURES THE DEFECT -- not before,
# not later. This note exists because in this tree a gate that is still `ls`-able reads as a gate that still runs,
# and the only thing that makes an unwired gate honest is the file saying so out loud.
# EXIT: 0 every iteration matched the oracle in every mode graded · 1 a mismatch (the defect) · 2 REFUSED to grade.
set -uo pipefail
GATE_NAME=test_gate_pl_an_asserted_atom_survives_a_collection
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"; RT_DIR="${RT_DIR:-$ROOT/out}"
SWIPL="${SWIPL:-/usr/bin/swipl}"
ITERS="${ITERS:-20}"; STRESS="${SCRIP_GC_STRESS_VALUE:-1}"; N="${WITNESS_N:-10}"
MODES="${MODES:-m3,m4}"
refuse(){ echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ]  || refuse "no scrip at $SCRIP -- a missing binary prints a full, plausible, entirely false board"
[ -x "$SWIPL" ]  || refuse "no swipl oracle at $SWIPL -- the ref is cut from the oracle at run time or not at all"
W="$(mktemp -d "${TMPDIR:-/tmp}/pl_atom_collect.XXXXXX")" || refuse "mktemp failed"
trap 'rm -rf "$W"' EXIT
cat > "$W/w.pl" <<PL
:- initialization(main).
mk(N,A) :- number_codes(N,C), atom_codes(S,C), atom_concat(p_,S,A).
gen(0) :- !.
gen(N) :- mk(N,A), T =.. [A,plain], assertz(T), N1 is N-1, gen(N1).
shw(0) :- !.
shw(N) :- mk(N,A), G =.. [A,X],
          ( call(G) -> ( X == plain -> R = ok ; R = wrongval(X) ) ; R = missing ),
          ( R == ok -> true ; write(N-R), nl ),
          N1 is N-1, shw(N1).
main :- gen($N), shw($N), write(done), nl.
PL
# ⛔ THE ORACLE RUNS FIRST AND ITS FAILURE IS A REFUSAL, NEVER A REF.
REF="$W/ref.txt"
if ! timeout -k 5 60 "$SWIPL" -q -g true -t halt "$W/w.pl" </dev/null > "$REF" 2>"$W/ref.err"; then
    refuse "the swipl oracle did not run the witness (rc=$?): $(head -3 "$W/ref.err" | tr '\n' ' ')"
fi
[ -s "$REF" ] || refuse "the oracle produced an EMPTY ref -- an empty expectation makes every run trivially pass"
grep -qx 'done' "$REF" || refuse "the oracle's own answer is not the expected shape (no 'done' line); witness or oracle changed"
echo "ORACLE REF (swipl, cut at run time): $(tr '\n' ' ' < "$REF")"
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
run_mode_m3(){ SCRIP_GC_STRESS="$STRESS" timeout -k 5 60 "$SCRIP" "$W/w.pl" </dev/null 2>&1; }
# ⛔⭐ THE M4 ARM COMPILES INTO ITS OWN DIRECTORY AND PROVES THE ARTIFACT IS FRESH BEFORE RUNNING IT. A stale
# artifact under a refusing compile is indistinguishable from success (cto 2026-09-14): a gate that compiled two
# arms into one scratch dir once linked and ran the CONTROL arm's leftovers and reported them as the subject's.
M4DIR="$W/m4"; mkdir -p "$M4DIR"
m4_build(){
    rm -f "$M4DIR/w.s" "$M4DIR/w.bin"
    timeout -k 5 120 "$SCRIP" --compile --out="$M4DIR/w.s" "$W/w.pl" </dev/null >"$M4DIR/compile.log" 2>&1 || return 1
    [ -s "$M4DIR/w.s" ] || return 1
    timeout -k 5 120 gcc -no-pie "$M4DIR/w.s" -o "$M4DIR/w.bin" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm >>"$M4DIR/compile.log" 2>&1 || return 1
    [ -x "$M4DIR/w.bin" ] || return 1
    return 0
}
run_mode_m4(){ SCRIP_GC_STRESS="$STRESS" timeout -k 5 60 "$M4DIR/w.bin" </dev/null 2>&1; }
for m in ${MODES//,/ }; do
    if [ "$m" = m4 ]; then
        m4_build || refuse "mode 4 could not build the witness -- refusing rather than grading a stale or absent artifact: $(tail -3 "$M4DIR/compile.log" 2>/dev/null | tr '\n' ' ')"
    fi
    bad=0; first=""
    for i in $(seq 1 "$ITERS"); do
        out="$(run_mode_$m)"
        if [ "$out" != "$(cat "$REF")" ]; then bad=$((bad+1)); [ -n "$first" ] || first="iter $i: $(printf '%s' "$out" | head -2 | tr '\n' ' ')"; fi
    done
    if [ "$bad" -eq 0 ]; then ck ok "$m: $ITERS/$ITERS runs byte-equal to the swipl ref under SCRIP_GC_STRESS=$STRESS"
    else ck no "$m: $bad of $ITERS runs DIVERGED from the swipl ref under SCRIP_GC_STRESS=$STRESS -- $first"; fi
done
echo "------------------------------------------------------------"
if [ "$fails" -eq 0 ]; then echo "✅ GATE PASS: an asserted clause's atom argument survives a mid-operation collection in every mode graded ($checks check(s))"; exit 0; fi
echo "⛔ GATE FAIL: $fails of $checks check(s) failed -- an asserted atom did not survive a collection"; exit 1
