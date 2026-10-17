#!/usr/bin/env bash
# test_gate_icn_augmented_scan_over_an_alternation.sh -- `every (a | b) ?:= e` evaluates its lvalue ONCE per variable (ceo CEO-633).
#
# MEASURED 2026-09-12 on 4faf4ed6b: `every text | comments ?:= { move(1); tab(0) }` (IPL procs/adlutils.icn nextadd, the
# idiom that strips a leading newline from two variables) left text "" and comments "" in BOTH modes where icont leaves "abc"
# and "" -- adllist printed blank names, adlsort nothing, adlcheck no address blocks. The lowerer rewrote `LV ?:= RHS` as
# `LV := (LV ? RHS)`, lowering an alternation lvalue TWICE into two independent generators, so the scanned subject and the
# assigned variable drifted apart. `+:=` and `||:=` over the same alternation were right (they dereference the one lowered
# lvalue). Cure: a non-variable augmented scan lowers the lvalue once (lower_lvalue_var) and scans over its dereference
# (lower_scan_impl, the scan case refactored to accept either a subject subtree or an lvalue). Arms: nine shapes -- the
# adlutils idiom, a plain variable, tab(0) over an alternation, a conjunction body, +:=, ||:=, := over an alternation, and
# two more scan forms -- byte-identical to icont in both modes. FAIL_ONCE=1 corrupts the A line to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.icn" <<'ICN'
procedure main()
   local text, comments, t2, a, b;
   text := "\nabc"; comments := "";
   every text | comments ?:= { move(1); tab(0) };
   write("A ", image(text), " ", image(comments));
   t2 := "\nxyz";
   t2 ?:= { move(1); tab(0) };
   write("B ", image(t2));
   text := "\nabc"; comments := "\nc";
   every (text | comments) ?:= tab(0);
   write("C ", image(text), " ", image(comments));
   text := "\nabc"; comments := "\nc";
   every text | comments ?:= (move(1), tab(0));
   write("D ", image(text), " ", image(comments));
   a := 1; b := 10;
   every (a | b) +:= 1;
   write("E ", a, " ", b);
   a := "p"; b := "q";
   every (a | b) ||:= "x";
   write("F ", a, " ", b);
   a := 1; b := 2;
   every (a | b) := 0;
   write("G ", a, " ", b);
   a := "\nm"; b := "\nn";
   every (a | b) ?:= tab(0);
   write("H ", image(a), " ", image(b));
   a := "one two"; b := "three four";
   every (a | b) ?:= tab(upto(' '));
   write("I ", image(a), " ", image(b));
end
ICN
( cd "$T" && "$ICONT" -s w.icn -x ) >"$T/w.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run the witness"; exit 2; }
grep -q '^A "abc" ""$' "$T/w.ref" || { echo "⛔ REFUSE(2): the oracle's own stream does not show the adlutils idiom stripping the newline -- this gate is asserting the wrong thing, or the oracle moved"; exit 2; }
[ "$(grep -c . "$T/w.ref")" = 9 ] || { echo "⛔ REFUSE(2): the oracle's stream is not the 9 lines the nine shapes produce"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" w.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o w.s w.icn </dev/null && gcc w.s -o w.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./w.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i 's/^A "abc" ""$/A "" ""/' "$T/$M.out"; fi
  if diff -u "$T/w.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS (byte-identical to icont, 9 augmented-assignment shapes)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,14p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: an augmented scan over an alternation of variables evaluates the lvalue once per variable and assigns through it (9 shapes x 2 modes)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: an augmented scan over an alternation does not pair subject and target as icont does (examined 9 shapes x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
