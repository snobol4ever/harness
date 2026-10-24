#!/usr/bin/env bash
# test_gate_pl_a_cell_written_before_a_disjunction_or_inside_its_arms_is_read_after_the_join.sh -- ON A HOME-SET PROLOG GRAPH EVERY CELL A CLAUSE WRITES BEFORE A DISJUNCTION, AND EVERY
# VARIABLE WHOSE FIRST WRITE LIES INSIDE ITS ARMS, IS READ AFTER THE JOIN WHERE THE WRITE LEFT IT (hq_snobol4, D3 kind 5, 2026-10-24; the cfo's ARCH-PROLOG-ACTIVATION-LIFETIME section 4;
# CEO-1945/1946). TWO DEFECTS, ONE WITNESS SET. (i) emit.cpp carved an admitted disjunction at a literal 32 bytes while the planner's carve for the kind on a home-set graph is 64 (the arms'
# 32 plus the choice header at +24..+63), so every cell below a disjunction was read 32 bytes off: X = 1, ( true ; true ), write(X) printed _G0. (ii) a variable first written in an
# arm ( Y = 1 ; Y = 2 ), write(Y) was hosted at its plan-order first use, the read after the join, and the arms wrote it before that box carved it: the FATAL of x86_zop (an IR_VAR with
# no frame bytes). Every expectation is CUT FROM THE ORACLE, swipl, at run time, one program per cell, graded in m3 (--run) and m4 (--compile, run_prolog_via_x86_backend.sh).
# FAIL_ONCE=1 corrupts the first expectation so the gate reads red once. rc 0 green, 1 red, 2 could not measure.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; RT_DIR="${RT_DIR:-$ROOT/out}"
. "$HERE/lib_oracle_flags.sh" || { echo "⛔ GATE REFUSE(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
SWI="$(swipl_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: no swipl -- every expectation is cut from the oracle"; exit 2; }
[ -x "$SCRIP" ] && [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip or runtime"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
CELLS=(
"before_trivial|main :- X = 1, ( true ; true ), write(X), nl."
"before_two_trivial|main :- X = 1, Y = 5, ( true ; true ), write(X-Y), nl."
"before_compound|main :- X = f(a,b), ( Y = 1 ; Y = 2 ), write(X-Y), nl, fail. main."
"before_call_result|main :- atom_length(abc, N), ( M is N+1 ; M is N+2 ), write(M), nl, fail. main."
"before_call_result_trivial|main :- atom_length(hello, N), ( true ; true ), M is N*2, write(M), nl, fail. main."
"arm_first_write|main :- ( Y = 1 ; Y = 2 ), write(Y), nl, fail. main :- write(done), nl."
"arm_first_write_clause_level|main :- ( X = 1 ; X = 2 ), write(X), nl, fail. main."
"arm_first_write_one_arm|main :- ( Y = 1 ; Y = 2 ), write(hi), nl."
"arm_first_write_two_joins|main :- ( B = x ; B = y ), ( C = 1 ; C = 2 ), write(B-C), nl, fail. main."
"before_and_arm_write|main :- X = 5, ( ( Y = 1 ; Y = 2 ) ; Y = 3 ), write(X-Y), nl, fail. main."
"generator_then_arm_value|main :- ( between(1,3,X), ( Y is X*2 ; Y is X*3 ), write(X-Y), nl, fail ; true )."
"findall_over_arms|main :- findall(X-Y, ( member(X,[1,2,3]), ( Y = a ; Y = b ) ), L), write(L), nl."
"guard_then_value|main :- ( between(1,3,X), ( X > 1 ; X < 0 ), Z is X*10, write(Z), nl, fail ; true )."
)
swi() { ( cd "$T" && timeout -k 5 20s "$SWI" -q -g halt -t halt "$1" </dev/null 2>/dev/null ); }
run3() { ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" "$1" </dev/null 2>/dev/null ); }
run4() { ( cd "$T" && timeout -k 5 40s bash "$HERE/run_prolog_via_x86_backend.sh" "$T/$1" </dev/null 2>/dev/null ); }
RC=0; N=0; A3=0; A4=0; BAD=""; FIRST=1
for c in "${CELLS[@]}"; do n="${c%%|*}"; body="${c#*|}"; f="$n.pl"
  printf ':- initialization(main).\n%s\n' "$body" > "$T/$f"
  want="$(swi "$f")"; [ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: swipl printed nothing for cell $n ($body)"; exit 2; }
  [ -n "${FAIL_ONCE:-}" ] && [ "$FIRST" = 1 ] && want="$want corrupted by FAIL_ONCE"; FIRST=0
  N=$((N + 1)); g3="$(run3 "$f")"; g4="$(run4 "$f")"
  if [ "$g3" = "$want" ]; then A3=$((A3 + 1)); else RC=1; BAD="$BAD
      m3 $n: swipl [$(echo "$want" | tr '\n' ' ')] scrip [$(echo "$g3" | tr '\n' ' ' | cut -c1-80)]   $body"; fi
  if [ "$g4" = "$want" ]; then A4=$((A4 + 1)); else RC=1; BAD="$BAD
      m4 $n: swipl [$(echo "$want" | tr '\n' ' ')] scrip [$(echo "$g4" | tr '\n' ' ' | cut -c1-80)]   $body"; fi
done
echo "  blocking: m3 $A3 of $N cells agree with swipl; m4 $A4 of $N"
[ -n "$BAD" ] && printf '  ⛔ disagreeing cells:%s\n' "$BAD" | head -30
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N cells, a cell written before a disjunction or inside its arms is read after the join in m3 and m4"
else echo "GATE FAIL(1) [$G]: $((N - A3)) m3 and $((N - A4)) m4 cells disagree with swipl"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY) oracle: $SWI measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
