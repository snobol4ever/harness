#!/usr/bin/env bash
# test_gate_pl_a_table_that_depends_only_on_itself_completes_at_once_instead_of_once_per_leader_round_as_swipl.sh -- a tabled call made while another table is being evaluated completes
# when its own evaluation ends if it consumed no incomplete table older than itself, so its clauses run once -- as swipl 9.0.4 runs them -- and the answers stay the same, m3 and m4
# (hq_packages 2026-10-21, SWI xsb/table_tests concomp: leader/2's body was entered 4+ times and reachable/2's base clause ran thousands of times, > 280 s and > 1 GB against swipl's
# 1 entry, 51 base calls, 0.13 s; the file's 60 s run ended there and 17 later cases read no verdict).
# CAUSE: the engine kept '$tbl_dep' as a boolean set by ANY incomplete table a call consumed, so a left-recursive table (it consumes its own) never completed early; every such table
# stayed in-progress until the first call's leader ended and '$tbl_rounds' renewed and re-ran all of them each round. CURE (prolog_parse.c, '$tbl_eval1n'): the cell holds the oldest
# in-progress position consumed; a nested table whose evaluation consumed nothing older than itself runs local rounds over itself and the tables younger than it, watches for a
# dependency on something older in those rounds (it can appear only once new answers send a body down another path), and completes them together; otherwise it stays and propagates.
# FOUR ARMS: (1) COUNT -- a non-recursive leader whose body calls two left-recursive tables is entered once (swipl: 1; the engine re-entered it once per round, 7 times here) and they answer [a,b,c]; (2) MUTUAL -- p/q, two tables
# calling each other, nested under that leader, answer p = [1,2,3], q = [2,3]; (3) OLDER -- a nested table whose later rounds depend on the leader's own table still gets every
# answer; (4) SELF-LEADER -- the first call itself recursive, unchanged.
# THE REFS ARE CUT FROM THE ORACLE, NEVER FROM SCRIP: every run re-cuts them from the live /usr/bin/swipl and REFUSES rc=2 when oracle and table disagree.
# Usage: bash ../harness/scripts/test_gate_pl_a_table_that_depends_only_on_itself_completes_at_once_instead_of_once_per_leader_round_as_swipl.sh
set -uo pipefail
GATE_NAME=test_gate_pl_a_table_that_depends_only_on_itself_completes_at_once_instead_of_once_per_leader_round_as_swipl
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
:- dynamic cnt/1.
cnt(0).
bump :- retract(cnt(N)), N1 is N + 1, assertz(cnt(N1)).
edge(a,b). edge(b,c). edge(c,a). edge(x,y).
:- table leader/1, reach/2.
reach(L, L).
reach(L, T) :- reach(L, T1), edge(T1, T).
leader(N) :- bump, member(N, [a,x]), reach(N, _).
:- table p/1, q/1, lead2/1.
p(1).
p(X) :- q(X).
q(X) :- p(Y), X is Y + 1, X < 4.
lead2(done) :- findall(X, p(X), Xs), findall(Y, q(Y), Ys), assertz(res2(Xs, Ys)).
:- dynamic res2/2.
:- table lead3/1, nest3/1, olda/1.
olda(1).
olda(X) :- nest3(Y), X is Y + 10, X < 14.
nest3(Y) :- olda(Z), Y is Z + 1, Y < 4.
lead3(X) :- olda(X).
:- table slead/2.
slead(X, Y) :- edge(X, Y).
slead(X, Y) :- slead(X, Z), edge(Z, Y).
main :- forall(leader(_), true), cnt(C), findall(T, reach(a,T), L), msort(L, S), write(count(C, S)), nl,
        forall(lead2(_), true), res2(Xs, Ys), msort(Xs, SX), msort(Ys, SY), write(mutual(SX, SY)), nl,
        findall(X, lead3(X), L3), msort(L3, S3), write(older(S3)), nl,
        findall(Y, slead(a, Y), L4), msort(L4, S4), write(self(S4)), nl,
        halt.
:- initialization(main).
PL
(cd "$d" && timeout -k 5 60 "$SWIPL" -q w.pl </dev/null > "$d/want" 2>/dev/null)
[ -s "$d/want" ] && [ "$(wc -l < "$d/want")" -eq 4 ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: the oracle did not print the four lines"; head -3 "$d/want"; exit 2; }
head -1 "$d/want" | grep -q '^count(1,\[a,b,c\])$' || { echo "⛔ REFUSED(2) [$GATE_NAME]: the oracle's count line is not count(1,[a,b,c]): $(head -1 "$d/want")"; exit 2; }
fails=0; graded=0
(cd "$d" && timeout -k 5 120 "$SCRIP" w.pl </dev/null 2>/dev/null > "$d/m3"); rc=$?; graded=$((graded + 1))
if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc differs:"; diff "$d/want" "$d/m3" | head -8; fi
graded=$((graded + 1))
if (cd "$d" && timeout -k 5 120 "$SCRIP" --compile -o w.s w.pl </dev/null >/dev/null 2>&1 && gcc -no-pie -o w.bin w.s "$OUT/libscrip_rt.so" -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
    (cd "$d" && timeout -k 5 120 ./w.bin </dev/null 2>/dev/null > "$d/m4"); rc=$?
    if [ $rc -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc differs:"; diff "$d/want" "$d/m4" | head -8; fi
else fails=$((fails + 1)); echo "  m4 did not compile or link"; fi
echo "PLTBLSCC_BOARD arms=4 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
