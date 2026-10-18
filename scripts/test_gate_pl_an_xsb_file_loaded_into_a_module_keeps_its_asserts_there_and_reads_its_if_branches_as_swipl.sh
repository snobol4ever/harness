#!/usr/bin/env bash
# test_gate_pl_an_xsb_file_loaded_into_a_module_keeps_its_asserts_there_and_reads_its_if_branches_as_swipl.sh -- the run-time loader classes
# SWI's xsb/sub_tests driver named (hq_prolog 2026-10-17, xsb_test_sub 0 -> 35 of 36 in both modes), answered as swipl 9.0.4 answers them, m3 and m4.
# (1) :- if/elif/else/endif IN A FILE LOADED AT RUN TIME (load_files/2) chooses ONE branch: '$lf_read' kept every term, so both load_data/1
#     clauses of Driver.P loaded and the directives printed existence_error(if/1), else/0, endif/0.
# (2) UNDER THE SWI DIALECT version_data is swi(9,0,4,[]) and dialect is swi, as swipl answers: Driver.P chooses its loader with
#     :- if(current_prolog_flag(version_data, swi(_,_,_,_))) and SCRIP answered scrip(0,0,0,[]).
# (3) assert/retract OF A RUN-TIME TERM FROM A CLAUSE LOADED INTO MODULE M REACH M (swipl creates M:p even when user defines p), and a call to a
#     predicate the file neither defines nor finds visible resolves in M at call time: the facts of one test module reached user and the next
#     module read them (lrtc4 printed 34 extra anc_l/2 answers).
#     A clause term written in the source and asserted from M (assert(r(1)), assert((s(X) :- r(X)))) has its head qualified to M as well; the
#     loader once rewrote that head as a goal, and a first cut of this landing turned assert(query(p)) into a write to '$lfx_mc'/2 (SWI
#     xsb/delay_tests interp1..15: permission_error(modify, static_procedure, '$lfx_mc'/2)).
# (3b) get_residual(G, R) with G a variable in a clause loaded into M looks G up in M's tables: the loader wrapped such a goal as '$lfx_mc'(M, G),
#     right for a goal that is CALLED, but get_residual reads a table, and the wrapper has none (xsb/sub_tests test_answer_abstraction printed nothing).
# (3c) get_returns_for_call/2 and get_calls/3 written in a clause loaded into M look their goal up as M:Goal (current_table strips the module and answers
#     unqualified): get_returns_for_call(b(_), R) found no table (xsb/neg_tests ldynstrat3/4 lost their "b(1) is true" line).
# (3d) assert OF A FACT FOR A PREDICATE THE FILE DECLARES BOTH table AND dynamic reaches the table's implementation ('$tbl M:u'), so calling u/1 fills
#     its table: the loader qualified the asserted head to M:u, beside the tabling wrapper, so u(_) answered from the facts directly and no table was
#     made (2026-10-18, xsb/table_tests atc_test lost a3_2, a4_2, a5_3, a9_3; '$lfx_mh' now targets '$tbl M:p' when it exists). Fail-once: on SCRIP
#     de14c4404 plus hq_prolog's loader commits and the abolish landing, without the cure, both modes printed [] for that line.
# (4) file_name_extension/3 is linked for a run-time-loaded file (Driver.P calls it; existence_error before).
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: the expectation below was cut 2026-10-17 from /usr/bin/swipl by absolute path and every run
# re-cuts it from the live swipl and REFUSES rc=2 when oracle and table disagree or swipl is absent.
# FAIL-ONCE: on the parent (bcc5be7bb) m3 printed [swi,other], scrip-scrip/4, [1,2,3] for both modules, and stopped at existence_error
# file_name_extension/3.
# NOT GRADED: a literal module in the static program (m1:which(W) written in the source) resolves at compile time and misses a module created by
# load_files at run time -- a divergence outside this gate; the witness reaches the modules through a variable, as xsb_test.pl does.
# Usage: bash ../harness/scripts/test_gate_pl_an_xsb_file_loaded_into_a_module_keeps_its_asserts_there_and_reads_its_if_branches_as_swipl.sh
set -uo pipefail
GATE_NAME=test_gate_pl_an_xsb_file_loaded_into_a_module_keeps_its_asserts_there_and_reads_its_if_branches_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
cat > "$d/drv.P" <<'PL'
:- if(current_prolog_flag(version_data, swi(_,_,_,_))).
which(swi).
:- else.
which(other).
:- endif.
ld([]).
ld([T|Ts]) :- assert(T), ld(Ts).
drop(T) :- retract(T).
q(X) :- p(X).
fx(B, E) :- file_name_extension(B, E, 'a/b.P').
mk :- assert(r(1)), assert((s(X) :- r(X))).
:- table t/1.
t(1).
t(2).
res(G, R) :- get_residual(G, R).
rc(L) :- findall(R, get_returns_for_call(t(_), R), L0), msort(L0, L).
:- table u/1.
:- dynamic u/1.
ua :- assert(u(a)), assert(u(b)).
PL
printf ":- include('drv').\n" > "$d/a.P"
printf ":- include('drv').\n" > "$d/b.P"
cat > "$d/w.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
in(M, G) :- M:G.
main :- load_files(m1:'a.P', [dialect(xsb)]), load_files(m2:'b.P', [dialect(xsb)]),
        findall(W, in(m1, which(W)), Ws), write(Ws), nl,
        current_prolog_flag(dialect, D), current_prolog_flag(version_data, V), functor(V, VN, VA), write(D-VN/VA), nl,
        in(m1, ld([p(1), p(2)])), in(m2, ld([p(3)])),
        findall(X, in(m1, q(X)), L1), write(L1), nl,
        findall(X, in(m2, q(X)), L2), write(L2), nl,
        in(m1, drop(p(1))), findall(X, in(m1, q(X)), L3), write(L3), nl,
        findall(X, in(m2, q(X)), L4), write(L4), nl,
        in(m2, fx(B, E)), write(B-E), nl,
        ( catch(p(_), error(existence_error(_, _), _), fail) -> write(user_p) ; write(no_user_p) ), nl,
        in(m1, mk), findall(X, in(m1, s(X)), L5), write(L5), nl,
        ( catch(r(_), error(existence_error(_, _), _), fail) -> write(user_r) ; write(no_user_r) ), nl,
        ( in(m1, t(_)), fail ; true ), findall(X-R, in(m1, res(t(X), R)), L6), msort(L6, L7), write(L7), nl,
        in(m1, rc(L8)), write(L8), nl,
        in(m1, ua), ( in(m1, u(_)), fail ; true ), findall(X-R, in(m1, res(u(X), R)), L9), msort(L9, L10), write(L10), nl,
        halt.
PL
cat > "$d/want" <<'WANT'
[swi]
swi-swi/4
[1,2]
[3]
[2]
[3]
a/b-P
no_user_p
[1]
no_user_r
[1-[],2-[]]
[t(1),t(2)]
[a-[],b-[]]
WANT
(cd "$d" && "$SWIPL" -q -g main -t halt w.pl </dev/null > "$d/oracle" 2>/dev/null)
cmp -s "$d/want" "$d/oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not what $SWIPL prints now"; diff "$d/want" "$d/oracle" | head -5; exit 2; }
fails=0; graded=0
(cd "$d" && timeout -k 5 30 "$SCRIP" w.pl </dev/null 2>/dev/null > "$d/m3"); rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/want" "$d/m3" | head -10; fi
graded=$((graded + 1))
if (cd "$d" && timeout -k 5 60 "$SCRIP" --compile -o w.s w.pl </dev/null >/dev/null 2>&1 && as --64 -o w.o w.s 2>/dev/null \
    && gcc -no-pie -o w.bin w.o "$OUT/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$OUT" 2>/dev/null); then
    (cd "$d" && timeout -k 5 30 ./w.bin </dev/null 2>/dev/null > "$d/m4"); rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/want" "$d/m4" | head -10; fi
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLXSBMODULELOAD_BOARD programs=1 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
