#!/usr/bin/env bash
# test_gate_pl_a_cell_less_box_gets_no_backed_frame_slot.sh -- IN A HOME-FRAME PROLOG GRAPH A BOX WHOSE CELL-SHAPE ROW IS UNCONDITIONALLY ZERO (UNMARK, UNIFY_CONST, UNIFY_FIRST, UNIFY_VALUE) AND
# WHICH IS NOT FRAME-RESIDENT IS GRANTED NO BACKED FRAME SLOT (hq_snobol4, D3 kind 6 -- the cell-less half, 2026-10-24; the cfo's ARCH-PROLOG-ACTIVATION-LIFETIME section 7 and his note of 15:51;
# CEO-1945/1946/1951). THE DEFECT: zls_overlay (the multi-clause graphs' clause overlay) granted a 16-byte result slot inside the BACKED region to every box of the alternatives, residents or not,
# and the reuse plan's direct-slot order took the cell-less UNIFY_* boxes too: 329 boxes of the empty program (UNMARK 134, UNIFY_CONST 129, UNIFY_FIRST 50, UNIFY_VALUE 16) printed off>=0 in
# `scrip --dump-homes`, the census's ops_prealloc 1404. THE MEASUREMENT: every cell is compiled with --dump-homes and the [HOMES] rows of the four kinds are counted with a backed offset (the dump
# prints -1 for a key past the resident region); the count must read 0. THE BEHAVIOUR CELLS: the same programs run in m3 and agree with swipl (expectations CUT FROM THE ORACLE at run time), so
# a layout that took a slot a template reads cannot pass. FAIL_ONCE=1 corrupts the first behaviour expectation so the gate reads red once; the layout count reads red on the commit before the
# cure (a scratch worktree of <cure>^: 329 on the empty program). rc 0 green, 1 red, 2 could not measure.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; RT_DIR="${RT_DIR:-$ROOT/out}"
. "$HERE/lib_oracle_flags.sh" || { echo "⛔ GATE REFUSE(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
SWI="$(swipl_bin)" || { echo "⛔ GATE REFUSE(2) [$G]: no swipl -- every behaviour expectation is cut from the oracle"; exit 2; }
[ -x "$SCRIP" ] && [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip or runtime"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
CELLS=(
"empty|main."
"clause_facts|f(1). f(2). f(a). f(b). main :- f(X), write(X), nl, fail. main."
"ite_in_a_two_clause_predicate|g(X) :- ( X > 1 -> write(big) ; write(small) ), nl. g(_) :- write(other), nl. main :- g(3)."
"negation_and_unify_first|h(X, Y) :- X = Y. h(X, _) :- \\+ X = 3. main :- h(1, 1), write(ok), nl."
"struct_head_with_repeated_variable|k(f(A, A)). k(g(_)). main :- k(f(1,1)), write(yes), nl."
"cut_and_unify_value|m(X, Y) :- X = Y, !. m(_, _) :- write(none), nl. main :- m(a, a), write(done), nl."
)
swi() { ( cd "$T" && timeout -k 5 20s "$SWI" -q -g halt -t halt "$1" </dev/null 2>/dev/null ); }
run3() { ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" "$1" </dev/null 2>/dev/null ); }
backed() { ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 60s "$SCRIP" --dump-homes --compile --out=/dev/null "$1" </dev/null 2>&1 | grep -E '^\[HOMES\] .* kind=IR_(UNMARK|UNIFY_CONST|UNIFY_FIRST|UNIFY_VALUE) ' | grep -vc ' off=-1 ' ); }
RC=0; N=0; A3=0; BAD=""; FIRST=1; TOTAL=0
for c in "${CELLS[@]}"; do n="${c%%|*}"; body="${c#*|}"; f="$n.pl"
  printf ':- initialization(main).\n%s\n' "$body" > "$T/$f"
  want="$(swi "$f")"; [ "$n" = empty ] || [ -n "$want" ] || { echo "⛔ GATE REFUSE(2) [$G]: swipl printed nothing for cell $n ($body)"; exit 2; }
  [ -n "${FAIL_ONCE:-}" ] && [ "$FIRST" = 1 ] && want="$want corrupted by FAIL_ONCE"; FIRST=0
  N=$((N + 1)); g3="$(run3 "$f")"; b="$(backed "$f")"; TOTAL=$((TOTAL + b))
  if [ "$g3" = "$want" ]; then A3=$((A3 + 1)); else RC=1; BAD="$BAD
      m3 $n: swipl [$(echo "$want" | tr '\n' ' ')] scrip [$(echo "$g3" | tr '\n' ' ' | cut -c1-80)]   $body"; fi
  if [ "$b" != 0 ]; then RC=1; BAD="$BAD
      layout $n: $b cell-less boxes carry a backed slot (UNMARK / UNIFY_CONST / UNIFY_FIRST / UNIFY_VALUE with off>=0)"; fi
done
echo "  blocking: m3 $A3 of $N cells agree with swipl; cell-less boxes with a backed slot: $TOTAL (must read 0)"
[ -n "$BAD" ] && printf '  ⛔ failing cells:%s\n' "$BAD" | head -30
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: $N cells, no cell-less box of a home-frame Prolog graph holds a backed frame slot, every cell agrees with swipl in m3"
else echo "GATE FAIL(1) [$G]: $TOTAL cell-less boxes with a backed slot, $((N - A3)) m3 cells disagree with swipl"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY) oracle: $SWI measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
