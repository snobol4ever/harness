#!/usr/bin/env bash
# test_gate_icn_dump_ast_shows_the_parsed_program_and_pruning_stays_a_lowering_step.sh -- --dump-ast prints what was parsed even when no procedure is reachable from main, and the unreachable-procedure prune still happens for a single Icon compiland but never across languages (ceo CEO-658).
#
# MEASURED 2026-09-13 on ea0c83883: 13 of the Icon rungs' ast-graded entries printed NOTHING under --dump-ast
# (procedure_write_89/91/92/94, procedure_36/40/43, procedure_suspend_1, procedure_fail_write_1,
# procedure_suspend_write_1/2, procedure_every_to_replace_6, procedure_every_suspend_5) -- every one a program with no
# `main`. icn_prune_unreachable_procs ran inside icon_compile, in the FRONTEND, keeping only what is reachable from main
# or invocable; with no main it emptied the program before the dump. The same call also emptied the Icon block of a
# polyglot program, whose caller lives in another language: test_smoke_polyglot.sh was a STANDING RED (0/2 both modes,
# "TRI: DOUBLE(21) = 42" missing) for exactly this reason. Cure: the prune is a LOWERING step -- the driver calls it
# before RECORD_SEG and only when the program is ONE source file; the polyglot path never calls it.
# ARMS: (1) three no-main programs dump their parse; (2) an unreachable procedure is still absent from a single-file
# compiland's emitted asm (the optimization is not silently deleted); (3) a procedure called from another language
# survives -- run through test_smoke_polyglot.sh's own witnesses. FAIL_ONCE=1 empties the first dump.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
printf 'procedure f(x)\n  write(x);\nend\n'                                              > "$T/a1.icn"
printf 'procedure gen(n)\n    suspend n;\n    suspend n + 1;\n    return;\nend\n'         > "$T/a2.icn"
printf 'procedure foo()\n  x := 1;\nend\nprocedure bar()\n  x := 2;\nend\n'               > "$T/a3.icn"
for W in a1 a2 a3; do
  ( cd "$T" && timeout -k 5 20 "$SCRIP" --dump-ast "$W.icn" </dev/null ) >"$T/$W.out" 2>&1
  if [ -n "${FAIL_ONCE:-}" ] && [ "$W" = a1 ]; then : > "$T/$W.out"; fi
  n=$(grep -c 'TT_PROC_DECL' "$T/$W.out" 2>/dev/null || true); [ -s "$T/$W.out" ] || n=0
  want=1; [ "$W" = a3 ] && want=2
  if [ "$n" = "$want" ]; then echo "  $W PASS (--dump-ast printed $n TT_PROC_DECL for a program with no main)"
  else echo "  $W FAIL (--dump-ast printed $n TT_PROC_DECL, expected $want -- the parse is not what the dump shows)"; sed -n '1,4p' "$T/$W.out" | sed 's/^/      /'; RC=1; fi
done
printf 'procedure unused_one()\n  write("NEVER");\nend\nprocedure main()\n  write("hi");\nend\n' > "$T/p.icn"
( cd "$T" && timeout -k 5 25 "$SCRIP" --compile -o p.s p.icn </dev/null ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the prune control witness did not compile"; exit 2; }
if [ "$(grep -c 'unused_one' "$T/p.s" || true)" = 0 ]; then echo "  prune PASS (a procedure unreachable from main is still absent from a single-file compiland's asm)"
else echo "  prune FAIL (unused_one reached the emitted asm -- the lowering-step prune was lost, not moved)"; RC=1; fi
PG="$HERE/test_smoke_polyglot.sh"
if [ -x "$PG" ] || [ -f "$PG" ]; then
  out=$(timeout -k 5 300 bash "$PG" 2>&1) || true
  m3=$(printf '%s\n' "$out" | grep -m1 'mode-3' || true); m4=$(printf '%s\n' "$out" | grep -m1 'mode-4' || true)
  if printf '%s %s\n' "$m3" "$m4" | grep -q 'FAIL=0.*FAIL=0'; then echo "  polyglot PASS (a procedure called from another language survives: $m3 / $m4)"
  else echo "  polyglot FAIL (a cross-language callee is still dropped: $m3 / $m4)"; RC=1; fi
else echo "⛔ GATE REFUSE(2) [$G]: no test_smoke_polyglot.sh to run the cross-language arm against"; exit 2; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: --dump-ast shows the parsed program, and the unreachable-procedure prune is a lowering step scoped to one compiland"
else echo "GATE FAIL(1) [$G]: the AST dump or the prune scope disagrees with what was parsed (examined 3 dumps + 1 prune control + the polyglot pair)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
