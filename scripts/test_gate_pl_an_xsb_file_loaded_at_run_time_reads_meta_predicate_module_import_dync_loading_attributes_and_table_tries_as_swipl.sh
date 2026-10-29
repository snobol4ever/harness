#!/usr/bin/env bash
# test_gate_pl_an_xsb_file_loaded_at_run_time_reads_meta_predicate_module_import_dync_loading_attributes_and_table_tries_as_swipl.sh -- seven behaviours of a file the XSB
# loader (load_files/2 with dialect(xsb)) installs at run time, answered as swipl 9.0.4, m3 and m4 (hq_packages 2026-10-21, SWI xsb/ptq 0 of 25, xsb/attv_tests 5 of 7,
# xsb/table_tests abol_test2/abol_test2a/concomp).
# (1) ATTRIBUTES: put_attr/3 and get_attr/3 imported "from machine" are linked for a program that references load_files (the loaded copyterm_attv.P / findall_attv.P died
#     existence_error(procedure, put_attr/3)).
# (2) meta_predicate/1 in a loaded file: parser.P declares  parse(2, +)  and its clause head is  parse(M:Nonterm, String);  a call from another loaded module passes the
#     argument qualified with the CALLER's module, so  call(M:Cterm)  reaches the caller's grammar (the directive was run as a goal and raised existence_error).
# (3) Mod:import(M:F/N) with prolog_load_context(module, M): abol_test2.P tells its helper module to import arc/2 from the module the test file is loaded into.
# (4) ensure_dync_loaded/1 (XSB consult): loads a data file named exactly, relative to the loading file, into the loading module (concomp.P's node/1 facts).
# (5) TABLE TRIES: '$tbl_trienode'/1 answers the reserved value, and trie_gen/3 with it as the value enumerates the answers of a table's trie as the swi-tabling drivers read
#     them (xsb_test_ptq's write_table/2).
# (6) context_module/1 in a loaded file is the module it is loaded into, and abolish_module_tables(+Module) (imported "from tables") destroys the tables of that module
#     (xsb/table_tests abol_test2: context_module(M), abolish_module_tables(M)).
# (7) a lattice(Order/3) answer-subsumption mode whose Order the loaded file defines: the engine called the bare name from the user module (existence_error gt/3, xsb test_3vwfs_1); the loader
#     qualifies an order, or a po(Order/2), that the file itself defines.
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: every run re-cuts them from the live /usr/bin/swipl and REFUSES rc=2 when oracle and table disagree.
# Usage: bash ../harness/scripts/test_gate_pl_an_xsb_file_loaded_at_run_time_reads_meta_predicate_module_import_dync_loading_attributes_and_table_tries_as_swipl.sh
set -uo pipefail
GATE_NAME=test_gate_pl_an_xsb_file_loaded_at_run_time_reads_meta_predicate_module_import_dync_loading_attributes_and_table_tries_as_swipl
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
printf '%s\n' ':- import put_attr/3, get_attr/3 from machine.' 'a1(V) :- put_attr(X, ct, v(a)), get_attr(X, ct, V).' > "$d/at.P"
printf '%s\n' ':- export pa/2.' ':- import append/3 from basics.' ':- meta_predicate pa(2, +).' 'pa(M:Nt, _S) :- Nt =.. Tl, append(Tl, [0,3], Ntl), C =.. Ntl, call(M:C).' > "$d/mp.P"
printf '%s\n' ':- import pa/2 from mp.' 's(x, 0, 3).' 't(X) :- pa(s(X), foo).' > "$d/mc.P"
printf '%s\n' ':- export mp1/1.' 'mp1(Y) :- arc(1, Y).' > "$d/hm.P"
printf '%s\n' 'arc(1,2).' 'arc(1,3).' ':- import mp1/1 from hm.' ':- prolog_load_context(module, M), hm:import(M:arc/2).' 'w3(Y) :- mp1(Y).' > "$d/im.P"
printf '%s\n' 'node(a).' 'node(b).' > "$d/factsP"
printf '%s\n' ':- import ensure_dync_loaded/1 from consult.' ":- ensure_dync_loaded('factsP')." 'n(X) :- node(X).' > "$d/dl.P"
printf '%s\n' ':- import abolish_module_tables/1 from tables.' ':- table tp/1.' 'tp(1).' 'tp(2).' 'c1(B-A) :- context_module(M), tp(_), findall(x, current_table(M:tp(_), _), L0), length(L0, B), abolish_module_tables(M), findall(x, current_table(M:tp(_), _), L1), length(L1, A).' > "$d/ab.P"
printf '%s\n' ':- table lp(_, lattice(gt(_,_,_))).' 'lp(a,1).' 'lp(a,3).' 'lp(a,2).' 'gt(X,Y,Z) :- ( X > Y -> Z = X ; Z = Y ).' > "$d/lt.P"
cat > "$d/w.pl" <<'PL'
:- use_module(library(lists)).
:- table tt/1.
tt(1).
tt(2).
:- initialization(main).
in(M, G) :- M:G.
main :- load_files(m1:'at.P', [dialect(xsb)]), in(m1, a1(V1)), write(V1), nl,
        load_files(m2:'mc.P', [dialect(xsb)]), in(m2, t(V2)), write(V2), nl,
        load_files(m3:'im.P', [dialect(xsb)]), findall(Y, in(m3, w3(Y)), L3), msort(L3, S3), write(S3), nl,
        load_files(m4:'dl.P', [dialect(xsb)]), findall(N, in(m4, n(N)), L4), msort(L4, S4), write(S4), nl,
        load_files(m6:'lt.P', [dialect(xsb)]), findall(R7, in(m6, lp(a, R7)), L7), write(L7), nl,
        load_files(m5:'ab.P', [dialect(xsb)]), in(m5, c1(C6)), write(C6), nl,
        tt(_), '$tbl_trienode'(R),
        findall(A, ( current_table(M5:V5, T), subsumes_term(user:tt(_), M5:V5), '$tbl_table_status'(T, _, user:A, Sk), trie_gen(T, Sk, R) ), L5), msort(L5, S5), write(S5), nl,
        halt.
PL
cat > "$d/want" <<'WANT'
v(a)
x
[2,3]
[a,b]
[3]
1-0
[tt(1),tt(2)]
WANT
(cd "$d" && timeout -k 5 30 "$SWIPL" -q -g main -t halt w.pl </dev/null > "$d/oracle" 2>/dev/null)
cmp -s "$d/want" "$d/oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not what $SWIPL prints now"; diff "$d/want" "$d/oracle" | head -8; exit 2; }
fails=0; graded=0
(cd "$d" && timeout -k 5 60 "$SCRIP" w.pl </dev/null 2>/dev/null > "$d/m3"); rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/want" "$d/m3" | head -10; fi
graded=$((graded + 1))
if (cd "$d" && timeout -k 5 120 "$SCRIP" --compile --out=w.s w.pl </dev/null >/dev/null 2>&1 && gcc -no-pie -o w.bin w.s "$OUT/libscrip_rt.so" -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
    (cd "$d" && timeout -k 5 60 ./w.bin </dev/null 2>/dev/null > "$d/m4"); rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/want" "$d/m4" | head -10; fi
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLXSBLOAD_BOARD behaviours=7 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
