#!/usr/bin/env bash
# test_gate_pl_an_if_directive_condition_reads_as_swipl_reads_it_and_the_reader_stops_at_end_of_file.sh -- the static reader evaluates a :- if / :- elif
# condition as swipl 9.0.4 does, and stops reading a file at the term end_of_file, m3 and m4 (cfo 2026-10-18, row
# prolog-an-if-directive-condition-the-reader-cannot-evaluate-is-false-or-an-error-never-true-current-predicate-flags-and-goals-ceo-1604, the ceo's
# design word there). THE DEFECT: prolog_parse.c eval_if_condition_tree answered unknown for every condition but true, fail, false, a negation
# and two flags, and the caller kept the branch of an unknown -- every current_predicate/1, every other flag (dialect read yap, swi, gprolog,
# sicstus and ciao all at once) and every goal read TRUE. THE CURE: current_predicate(N/A) against the clauses kept so far, the static builtins
# (pl_pi_is_builtin) and the built-in prelude (pl_prelude_defines); current_prolog_flag(F, V) against the runtime's own table through
# rt_pl_flag_at_read, under the dialect the lowerer will choose (the program's SWI markers, or --dialect=gnu); exists_source(library(L)) against
# the embedded libraries; ',' ';' '->' and \+ structurally; any other goal FALSE with a warning naming it. And the reader stops at end_of_file,
# as swipl and gprolog do (it read on past it, so xsb prolog_tests_test_cond_comp printed two lines more than its ref).
# The program carries an SWI marker (:- module), so SCRIP reads it in the SWI dialect, as swipl does; under the ISO default SCRIP's dialect flag
# is scrip, a run-time answer this gate does not grade.
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: the table below was cut 2026-10-18 from /usr/bin/swipl, and every run re-cuts it from the
# live swipl and REFUSES rc=2 when oracle and table disagree or swipl is absent.
# FAIL-ONCE (CEO-1680, a witness red on the commit before the cure): with the three cure files reverted on the same tree, m3 and m4 both read FAIL
# (measured 2026-10-18), and PASS=2 again once they were restored.
# Usage: bash ../harness/scripts/test_gate_pl_an_if_directive_condition_reads_as_swipl_reads_it_and_the_reader_stops_at_end_of_file.sh
set -uo pipefail
GATE_NAME=test_gate_pl_an_if_directive_condition_reads_as_swipl_reads_it_and_the_reader_stops_at_end_of_file
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/w.pl" <<'PL'
:- module(w, []).
:- initialization(main).
defd(1).
:- if(current_predicate(defd/1)).
a(defd_seen).
:- else.
a(defd_missing).
:- endif.
:- if(current_predicate(later/0)).
b(later_seen).
:- else.
b(later_not_yet).
:- endif.
later.
:- if(current_predicate(atom_length/2)).
c(builtin).
:- else.
c(no_builtin).
:- endif.
:- if(current_predicate(nosuch_pred_xyz/1)).
d(nosuch_seen).
:- elif(\+ current_predicate(nosuch_pred_xyz/1)).
d(nosuch_absent).
:- endif.
:- if(current_prolog_flag(dialect, yap)).
e(yap).
:- elif(current_prolog_flag(dialect, swi)).
e(swi).
:- else.
e(other).
:- endif.
:- if(current_prolog_flag(version_data, swi(_, _, _, _))).
f(swi_version).
:- else.
f(other_version).
:- endif.
:- if((current_prolog_flag(bounded, false), \+ current_prolog_flag(no_such_flag_xyz, _))).
g(conj).
:- else.
g(noconj).
:- endif.
:- if((current_prolog_flag(bounded, true) -> fail ; true)).
h(ite).
:- else.
h(noite).
:- endif.
:- if(exists_source(library(assoc))).
i(assoc).
:- else.
i(no_assoc).
:- endif.
:- if(current_predicate(random_property/1)).
j(prelude).
:- else.
j(no_prelude).
:- endif.
main :- forall(member(G, [a(_), b(_), c(_), d(_), e(_), f(_), g(_), h(_), i(_), j(_)]), ((call(G) -> writeq(G) ; writeq(none(G))), nl)),
        ( catch(after_eof, _, fail) -> writeq(read_past_end_of_file) ; writeq(stopped_at_end_of_file) ), nl, halt.
end_of_file.
after_eof.
PL
cat > "$d/want" <<'WANT'
a(defd_seen)
b(later_not_yet)
c(builtin)
d(nosuch_absent)
e(swi)
f(swi_version)
g(conj)
h(ite)
i(assoc)
j(prelude)
stopped_at_end_of_file
WANT
(cd "$d" && timeout -k 5 30 "$SWIPL" -q w.pl </dev/null > "$d/oracle" 2>/dev/null)
cmp -s "$d/want" "$d/oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not what $SWIPL prints now"; diff "$d/want" "$d/oracle" | head -5; exit 2; }
fails=0; graded=0
(cd "$d" && timeout -k 5 30 "$SCRIP" w.pl </dev/null 2>/dev/null > "$d/m3"); rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/want" "$d/m3" | head -12; fi
graded=$((graded + 1))
if (cd "$d" && timeout -k 5 60 "$SCRIP" --compile -o w.s w.pl </dev/null >/dev/null 2>&1 \
    && gcc -no-pie -o w.bin w.s -L"$OUT" -lscrip_rt -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
    (cd "$d" && timeout -k 5 30 ./w.bin </dev/null 2>/dev/null > "$d/m4"); rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/want" "$d/m4" | head -12; fi
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLIFDIRECTIVE_BOARD programs=1 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
