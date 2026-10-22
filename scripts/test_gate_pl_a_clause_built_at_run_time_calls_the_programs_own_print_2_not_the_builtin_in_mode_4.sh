#!/usr/bin/env bash
# test_gate_pl_a_clause_built_at_run_time_calls_the_programs_own_print_2_not_the_builtin_in_mode_4.sh -- a program that defines print/2 itself and builds a clause at run time that calls it prints what swipl 9.0.4 prints, in m3 and m4
# (hq_packages 2026-10-22; the row prolog-m4-a-long-comment-after-a-use-module-directive-before-the-clauses-silences-the-program, whose first diagnosis -- the comment -- was wrong: the word  listing  made the program seed its predicates into the
# database, so  call(G)  of an atom  test  lowered test/0's clauses AT RUN TIME, and the compiled binary carried neither the program's predicate table nor the compile-time dialect, so the lowerer read print/2 as the builtin and rewrote it to writeq/2).
# ARM 1  assertz((t :- print(2,0))), t  with a user print/2: no listing, no tabling -- the smallest program the cure moves.
# ARM 2  the same user print/2 reached through  run(G) :- catch(ignore(G), ...)  with listing/1 in the program (the startup seeds lower test/0 before the dialect directive ran).
# THE REF IS CUT FROM THE ORACLE, NEVER FROM SCRIP: swipl 9.0.4 runs the same text live each time and the gate REFUSES rc=2 when swipl prints nothing.
# Usage: bash ../harness/scripts/test_gate_pl_a_clause_built_at_run_time_calls_the_programs_own_print_2_not_the_builtin_in_mode_4.sh
set -uo pipefail
GATE_NAME=test_gate_pl_a_clause_built_at_run_time_calls_the_programs_own_print_2_not_the_builtin_in_mode_4
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"; OUT="${RT_DIR:-$HERE/../../SCRIP/out}"; SWIPL=/usr/bin/swipl
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
[ -x "$SWIPL" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no oracle at $SWIPL"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
cat > "$d/a1.pl" <<'EOF'
:- use_module(library(lists)).
print(N,M) :- write(N-M), nl.
main :- assertz((t :- print(2,0))), t.
:- initialization(main).
EOF
cat > "$d/a2.pl" <<'EOF'
:- use_module(library(lists)).
test :- print(2,0), fail.
test.
print(N,M) :- write(N-M), nl, fail.
zz :- listing(foo/1).
run(G) :- catch(ignore(G), E, (write(caught(E)), nl)).
:- initialization(run(test)).
EOF
fails=0; graded=0
for p in a1 a2; do
    (cd "$d" && timeout -k 5 60 "$SWIPL" -q "$p.pl" </dev/null > "$d/$p.want" 2>/dev/null)
    [ -n "$(cat "$d/$p.want")" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: the oracle printed nothing for $p"; exit 2; }
    (cd "$d" && SCRIP_HEAP_CAP_KB=131072 SCRIP_STACK=8192k timeout -k 5 60 "$SCRIP" "$p.pl" </dev/null 2>/dev/null > "$d/$p.m3"); graded=$((graded + 1))
    [ "$(cat "$d/$p.want")" = "$(cat "$d/$p.m3")" ] || { fails=$((fails + 1)); echo "  $p m3 differs: want [$(tr '\n' '|' < "$d/$p.want")] got [$(tr '\n' '|' < "$d/$p.m3")]"; }
    graded=$((graded + 1))
    if (cd "$d" && timeout -k 5 120 "$SCRIP" --compile -o "$p.s" "$p.pl" </dev/null >/dev/null 2>&1 && gcc -no-pie -o "$p.bin" "$p.s" "$OUT/libscrip_rt.so" -lm -Wl,-rpath,"$OUT" 2>/dev/null); then
        (cd "$d" && SCRIP_HEAP_CAP_KB=131072 SCRIP_STACK=8192k timeout -k 5 60 "./$p.bin" </dev/null 2>/dev/null > "$d/$p.m4")
        [ "$(cat "$d/$p.want")" = "$(cat "$d/$p.m4")" ] || { fails=$((fails + 1)); echo "  $p m4 differs: want [$(tr '\n' '|' < "$d/$p.want")] got [$(tr '\n' '|' < "$d/$p.m4")]"; }
    else fails=$((fails + 1)); echo "  $p m4 did not compile or link"; fi
done
echo "PLRTPRINT2_BOARD programs=2 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
