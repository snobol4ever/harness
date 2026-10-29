#!/usr/bin/env bash
# test_gate_pas_the_c_parser_builds_the_pruned_parse_tree.sh -- the C Pascal parser hands the lowerer the PRUNED PARSE TREE and nothing
# invented: one node per rule that fires, children in source order, the declared type kept as a child of its declaration, no desugaring
# (Lon 2026-10-03, in-chat to hq_snocone, verbatim: "The right shape can be decided not by me but by the RULE, in the same left to right
# order as source input, and built directly from Shift/Reduce and the Counter stack primitives ONLY ... It is a PRUNED PARSE TREE, it is
# not a FANCY SYNTAX TREE."; RULES.md FACT RULE -- THE TREE IS THE PRUNED PARSE TREE, its last bullet names hq_pascal for the C Pascal
# parser; the cto's ruling to hq_pascal 2026-10-09: "LEVER (2) NEEDS NOBODY'S WORD" and the tree conversion "does not wait on the speed phase").
#
# MEASURED 2026-10-09 by hq_pascal on SCRIP 86763386e, the cto's six-line program under --dump-ast: the parser DROPS the declared types and
# DESUGARS WITH THEM (a type checker lives in the parser): v := loc / 2 arrives as ADD(DIV(MUL(loc, FLIT 1), ILIT 2), FLIT 0); the globals
# get invented zero-init assignments and an arr_make call at the head of an invented PROC_DECL main under an invented STMT; writeln(r:6:2)
# becomes a __pas_writeln call with a -3 sentinel. Every one of those moves to lower_pascal.c (A PARSER MOVES NOTHING; THE LOWERER PLACES IT).
#
# ARMS over ONE program (the expectations are read from its SOURCE, never pasted from a dump): (1) no invented STMT wrapper; (2) no invented
# main procedure; (3) no builtin call the parser names (__pas_*); (4) no arr_make; (5) one TT_ASSIGN per := in the source (no invented zero-init
# assignments); (6) the / of the source is one DIV over its two source operands (no MUL-by-1.0, no ADD-0.0 coercion); (7) the declared types
# integer and real, and the array bounds, are in the tree; (8) the field widths of writeln(r:6:2) follow r in source order with no sentinel;
# (9) and (10) the program still prints what fpc -Miso prints, m3 and m4 (the cure moves meaning from the parser to the lowerer and may not change it).
# Arms (1) to (8) FAIL on 86763386e (that is the row's red); arms (9) and (10) are the behaviour the cure must keep, green on it. FAIL_ONCE=1 corrupts their ref.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- arms (9) and (10) are CUT FROM THE ORACLE"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
cat > "$T/prune.pas" <<'PAS'
program prune(output);
var i: integer; r: real; a: array[1..3] of integer;
procedure p(n: integer; var x: real);
var loc: integer; v: real;
begin loc := n; v := loc / 2; x := v end;
begin i := 1; r := 0.0; a[2] := 7; p(i, r); writeln(r:6:2, a[2]:3) end.
PAS
( cd "$T" && timeout -k 5 20s "$SCRIP" --dump-ast prune.pas </dev/null >"$T/ast" 2>"$T/ast.err" ); arc=$?
[ -s "$T/ast" ] || { echo "⛔ GATE REFUSE(2) [$G]: --dump-ast printed nothing (rc=$arc): $(head -1 "$T/ast.err" | cut -c1-140)"; exit 2; }
tr -s ' \n' ' ' < "$T/ast" | sed -e 's/( */(/g' -e 's/ *)/)/g' > "$T/ast.flat"; mv "$T/ast.flat" "$T/ast"   # one line, the form the arms read (--dump-ast prints the tree one node per line)
arm() { N=$((N + 1)); if [ "$1" = ok ]; then echo "  ($N) $2"; else echo "  ⛔ ($N) FAILED: $2"; RC=1; fi; }
n_assign_src=$(grep -o ':=' "$T/prune.pas" | wc -l); n_assign_ast=$(grep -o '(TT_ASSIGN' "$T/ast" | wc -l)
c_stmt=$(grep -c '^(STMT' "$T/ast"); c_main=$(grep -c '(TT_VAR main)' "$T/ast"); c_pas=$(grep -c '__pas_' "$T/ast"); c_arr=$(grep -c 'arr_make' "$T/ast")
[ "$c_stmt" = 0 ] && arm ok "no invented STMT wrapper" || arm bad "the parser wraps $c_stmt top-level trees in an invented STMT"
[ "$c_main" = 0 ] && arm ok "no invented main procedure" || arm bad "the parser invents a PROC_DECL main ($c_main references) the source does not contain"
[ "$c_pas" = 0 ] && arm ok "no builtin call the parser names" || arm bad "the parser names $c_pas __pas_* builtin calls; the lowerer places those"
[ "$c_arr" = 0 ] && arm ok "no arr_make in the tree" || arm bad "the parser builds $c_arr arr_make calls from a declaration; the declaration node carries the type and the lowerer builds the array"
[ "$n_assign_ast" = "$n_assign_src" ] && arm ok "one TT_ASSIGN per := in the source ($n_assign_src)" || arm bad "the source has $n_assign_src := and the tree $n_assign_ast TT_ASSIGN (invented zero-init assignments)"
grep -q '(TT_DIV (TT_VAR loc) (TT_ILIT 2))' "$T/ast" && arm ok "loc / 2 is one DIV over loc and 2" || arm bad "loc / 2 is not (TT_DIV (TT_VAR loc) (TT_ILIT 2)): $(grep -o 'TT_ADD (TT_DIV[^\n]*' "$T/ast" | head -1 | cut -c1-110)"
{ grep -qw integer "$T/ast" && grep -qw real "$T/ast"; } && arm ok "the declared types integer and real are in the tree" || arm bad "the declared types integer and real are not in the tree (the parser drops them)"
grep -q '(TT_VAR r) (TT_ILIT 6) (TT_ILIT 2)' "$T/ast" && ! grep -q -- '-3' "$T/ast" && arm ok "the field widths follow r in source order, no sentinel" || arm bad "writeln(r:6:2) does not carry r, 6, 2 in source order without a sentinel"
run() { local m="$1"
  if [ "$m" = m3 ]; then ( cd "$T" && LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 20s "$SCRIP" --run prune.pas </dev/null >"$T/o" 2>"$T/e" ); return $?; fi
  ( cd "$T" && timeout -k 5 20s "$SCRIP" --compile --out="$T/prune.s" prune.pas </dev/null >/dev/null 2>&1 && cc -m64 -no-pie prune.s -o prune.m4 -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" >/dev/null 2>&1 ) || return 125
  ( cd "$T" && timeout -k 5 20s ./prune.m4 </dev/null >"$T/o" 2>"$T/e" ); return $?; }
( cd "$T" && "$FPC" -Miso -v0 -oprune.fpc prune.pas >/dev/null 2>&1 ) || { echo "⛔ GATE REFUSE(2) [$G]: fpc -Miso would not compile the witness"; exit 2; }
( cd "$T" && timeout -k 5 20s ./prune.fpc </dev/null >"$T/want" 2>/dev/null ); frc=$?
[ -n "${FAIL_ONCE:-}" ] && echo "corrupted by FAIL_ONCE" >> "$T/want"
for m in m3 m4; do run $m; rc=$?
  if [ "$rc" = "$frc" ] && cmp -s "$T/want" "$T/o"; then arm ok "$m: rc=$rc, stdout byte-identical to fpc -Miso ($(tr '\n' '|' < "$T/o"))"
  else arm bad "$m: rc=$rc (fpc $frc), stdout differs from fpc -Miso: $(head -c 80 "$T/o" | tr '\n' '|') err: $(head -1 "$T/e" | cut -c1-100)"; fi; done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: the C Pascal parser hands lower the pruned parse tree, and the program still prints what fpc -Miso prints in both modes, $N of $N arms"
else echo "GATE FAIL(1) [$G]: the tree is not the pruned parse tree yet; $N arms over one program, ARMS (1) TO (8) ARE THE ROW'S RED"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)" \
     " oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
