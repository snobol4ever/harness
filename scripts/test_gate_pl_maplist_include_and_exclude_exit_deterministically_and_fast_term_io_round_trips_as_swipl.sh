#!/usr/bin/env bash
# test_gate_pl_maplist_include_and_exclude_exit_deterministically_and_fast_term_io_round_trips_as_swipl.sh -- two answers swipl 9.0.4 gives,
# m3 and m4 (cfo 2026-10-17, row prolog-swi-fast-term-serialized-fast-write-fast-read-and-print-message-2-are-absent-test-fastrw-reads-0-of-3).
# (1) maplist/2..5, include/3 and exclude/3 on a proper list EXIT DETERMINISTICALLY: the built-in prelude in prolog_parse.c defined them goal-first
#     (maplist(_,[]). maplist(G,[X|Xs]) :- ...), so first-argument indexing switched on the goal, every call left a choice point, and a
#     setup_call_cleanup around one deferred its cleanup -- SWI core/test_fastrw's close(Out) never ran before the file was read back, the last
#     partial 4096-byte block was never flushed, and the case read syntax_error(cannot_start_term). They now take SWI's own shape, a list-first
#     helper ('$maplist_'/N, '$include_'/3, '$exclude_'/3), which is what SWI's library(apply) does.
# (2) fast_term_serialized/2, fast_write/2 and fast_read/2 (src/parsers/prolog/prelude/swi_builtins.pl) round-trip every term of core/test_fastrw's
#     table =@= the original, a cyclic term included, written in sequence through setup_call_cleanup and read back in sequence, and fast_write of a
#     term holding a stream raises permission_error(fast_serialize, blob, S). The serialized form is SCRIP's own (a length-prefixed canonical text
#     of term_factorized's skeleton and substitution), as the row allows.
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: the table below was cut 2026-10-17 from /usr/bin/swipl, and every run re-cuts it from the
# live swipl and REFUSES rc=2 when oracle and table disagree or swipl is absent.
# FAIL-ONCE (CEO-1680, a witness red on the commit before the cure): with the prolog_parse.c prelude reverted on the same tree, m3 and m4 both read
# FAIL on the six det lines, each reading nondet, and PASS=2 again once it was restored (measured 2026-10-17). The string arm of (2) was red too
# before the serializer carried each string beside the canonical text: under the ISO default (double_quotes=codes) a string read back as codes.
# Usage: bash ../harness/scripts/test_gate_pl_maplist_include_and_exclude_exit_deterministically_and_fast_term_io_round_trips_as_swipl.sh
set -uo pipefail
GATE_NAME=test_gate_pl_maplist_include_and_exclude_exit_deterministically_and_fast_term_io_round_trips_as_swipl
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
d(G) :- setup_call_cleanup(true, G, F = c), ( F == c -> R = det ; R = nondet ), functor(G, N, A), writeq(N/A-R), nl.
term(0). term(-1). term(X) :- X is 1<<62. term(X) :- X is pi. term(''). term(aap).
term(A) :- numlist(1, 1100, L), atom_codes(A, L). term(S) :- numlist(1, 1100, L), atom_codes(A, L), atom_string(A, S).
term([]). term(f(1, f(2))). term(f(X, Y, X, Y)). term(X) :- X = f(X). term(L) :- numlist(-1000, 1000, L).
rc(In, T, R0, R) :- fast_read(In, T2), ( T =@= T2 -> R = R0 ; R = bad ).
main :- d(maplist(atom, [a, b])), d(maplist(=, [a], _)), d(maplist([X, Y, Z]>>(Z = X-Y), [1], [2], _)), d(maplist([A, B, C, E]>>(E = A-B-C), [1], [2], [3], _)),
        d(include(atom, [a, 1], _)), d(exclude(atom, [a, 1], _)),
        findall(T, term(T), Ts),
        ( forall(member(T, Ts), ( fast_term_serialized(T, S), fast_term_serialized(T1, S), T =@= T1 )) -> writeq(serialize-ok) ; writeq(serialize-bad) ), nl,
        setup_call_cleanup(tmp_file_stream(binary, F, Out), maplist(fast_write(Out), Ts), close(Out)),
        setup_call_cleanup(open(F, read, In, [type(binary)]), foldl(rc(In), Ts, ok, R), close(In)), delete_file(F), writeq(sequence-R), nl,
        open_null_stream(Nul), set_stream(Nul, encoding(octet)), catch(fast_write(Nul, a(V, V, Nul)), error(Er, _), true), close(Nul), ( Er = permission_error(P, K, _) -> writeq(P-K) ; writeq(no_error) ), nl,
        halt.
:- initialization(main).
PL
cat > "$d/want" <<'WANT'
maplist/2-det
maplist/3-det
maplist/4-det
maplist/5-det
include/3-det
exclude/3-det
serialize-ok
sequence-ok
fast_serialize-blob
WANT
(cd "$d" && timeout -k 5 30 "$SWIPL" -q w.pl </dev/null > "$d/oracle" 2>/dev/null)
cmp -s "$d/want" "$d/oracle" || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not what $SWIPL prints now"; diff "$d/want" "$d/oracle" | head -5; exit 2; }
fails=0; graded=0
(cd "$d" && timeout -k 5 30 "$SCRIP" w.pl </dev/null 2>/dev/null > "$d/m3"); rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/want" "$d/m3" | head -10; fi
graded=$((graded + 1))
if (cd "$d" && timeout -k 5 60 "$SCRIP" --compile -o w.s w.pl </dev/null >/dev/null 2>&1 \
    && gcc -no-pie -o w.bin w.s -L"$OUT" -lscrip_rt -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
    (cd "$d" && timeout -k 5 30 ./w.bin </dev/null 2>/dev/null > "$d/m4"); rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/want" "$d/m4" | head -10; fi
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLMAPLISTDETFASTRW_BOARD programs=1 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
