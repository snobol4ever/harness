#!/usr/bin/env bash
# test_gate_icn_augmented_assignment_to_an_element_or_field_applies_its_own_operator.sh -- `T[i] op:= e` and `r.f op:= e` apply op, as icont does.
#
# MEASURED 2026-10-02 on 282c61031 (hq_icon, the IPL progs/solit.icn crawl): `run[dest] |||:= run[from]` left run[dest] unchanged and
# FAILED in both modes, so solit's autopilot moved QD onto KS and never drew it (seed1 auto, the first byte of difference at 453).
# Bracket: monitor_run.sh --oracle on the four-line witness, step 5 at stno 4 -- icx assigns `<lval> = DATA`, scr goes on to stno 5.
# Cause: a non-variable target lowers through augop_code(), whose switch had no case for |||:=, @:=, ===:=, ~===:= or &:=, so each
# fell to `default: return 0`, which is BINOP_ADD -- `L[1] |||:= [9]` computed L[1] + [9]. The same road also skipped what the plain
# binary operator does: no numeric coercion (`L[1] +:= "x"` failed silently where icont raises 102) and no large-integer codes
# (`L[1] +:= 2^62` wrapped negative). A plain variable never showed it: it is rewritten `x := x op e` and lowers as the binary operator.
# Cure (lower_icon.c): augop_code() names every operator; icn_augop_build() gives the target road the plain operator's coercions and
# large-integer codes and an IR_ACTIVATE for @:=; &:= on a target is `:=` (a & b yields b). Arm 1: 17 shapes byte-identical to icont
# in both modes; arm 2: `L[1] +:= "x"` raises 102 in both modes as icont does. FAIL_ONCE=1 corrupts the A line to prove arm 1 trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.icn" <<'ICN'
record R(f)
global run, long
procedure main()
   local L, T, r, c, k, x, dest, from, part, h;
   L := [[1], [2], [3]];
   L[1] |||:= [9];
   write("A ", *L[1]);
   T := table(); T["k"] := [1];
   T["k"] |||:= [8, 9];
   write("B ", *T["k"]);
   r := R([1]);
   r.f |||:= [9];
   write("C ", *r.f);
   L[-1] |||:= [8, 9];
   write("D ", *L[-1]);
   x := [];
   L := [x, 1, 2];
   (L[1] ===:= x) & write("E ", image(L[1] === x));
   (L[2] ===:= 3) | write("F ", L[2]);
   (L[3] ~===:= 7) & write("G ", L[3]);
   (L[3] ~===:= 7) | write("H ", L[3]);
   L[2] &:= 9; r.f &:= "z";
   write("I ", L[2], " ", r.f);
   c := create ("x" | "y" | "z");
   L := [&null];
   writes("J");
   while L[1] @:= c do writes(" ", L[1]);
   write();
   L := [2^62, 2^40, "5"];
   L[1] +:= 2^62; L[2] *:= 2^40; L[3] +:= 3;
   write("K ", L[1], " ", L[2], " ", L[3]);
   L := [[1], [2], [3]];
   every L[1 to 3] |||:= [0];
   writes("L"); every writes(" ", *!L); write();
   L := ["a"];
   (L[1] ===:= ("b" | "a")) & write("M ", L[1]);
   L := [5];
   (L[1] <:= (1 | 3 | 9)) & write("N ", L[1]);
   k := [[1]];
   write("O ", *(k[1] |||:= [3]), " ", *k[1]);
   run := [["KS"], [], [], [], ["QD"], [], []]; long := [1, 1, 1, 1, 1, 1, 1];
   from := "5"; dest := "1";
   run[dest] |||:= run[from]; run[from] := [];
   every part := !"51" do { h := ((long[part] < *run[part]) | long[part]); writes("P", part, "=", h, " "); long[part] := *run[part] };
   write();
   L := [7.0, "ab"];
   L[1] %:= "2"; L[2] ||:= 0.5;
   write("Q ", L[1], " ", L[2]);
end
ICN
( cd "$T" && "$ICONT" -s w.icn -x ) >"$T/w.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run the witness"; exit 2; }
grep -q '^A 2$' "$T/w.ref" || { echo "⛔ REFUSE(2): the oracle's own stream does not show L[1] |||:= [9] growing the element to 2 -- this gate is asserting the wrong thing, or the oracle moved"; exit 2; }
[ "$(grep -c . "$T/w.ref")" = 17 ] || { echo "⛔ REFUSE(2): the oracle's stream is not the 17 lines the 17 shapes produce"; exit 2; }
cat > "$T/e.icn" <<'ICN'
procedure main()
   local L;
   L := ["x"];
   L[1] +:= 1;
   write("after ", image(L[1]));
end
ICN
( cd "$T" && "$ICONT" -s e.icn -x ) >"$T/e.ref" 2>&1
grep -q 'Run-time error 102' "$T/e.ref" || { echo "⛔ REFUSE(2): the oracle does not raise 102 on L[1] +:= 1 over a non-numeric element -- arm 2 asserts the wrong thing"; exit 2; }
RC=0
for M in m3 m4; do
  for W in w e; do
    if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" $W.icn </dev/null ) >"$T/$M.$W.out" 2>&1
    else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o $W.s $W.icn </dev/null && gcc $W.s -o $W.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness $W did not build"; exit 2; }
         ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./$W.bin </dev/null ) >"$T/$M.$W.out" 2>&1
    fi
  done
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i 's/^A 2$/A 1/' "$T/$M.w.out"; fi
  if diff -u "$T/w.ref" "$T/$M.w.out" >"$T/$M.diff"; then echo "  $M arm 1 PASS (byte-identical to icont, 17 shapes)"
  else echo "  $M arm 1 FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,14p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
  if grep -q 'error 102' "$T/$M.e.out" && ! grep -q '^after' "$T/$M.e.out"; then echo "  $M arm 2 PASS (L[1] +:= 1 over \"x\" raises 102)"
  else echo "  $M arm 2 FAIL (icont raises 102; SCRIP printed: $(head -c 120 "$T/$M.e.out" | tr '\n' ' '))"; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: an augmented assignment to an element or field applies its own operator, coercions and large integers as icont does (17 shapes + error 102, x 2 modes)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: an augmented assignment to an element or field does not apply its operator as icont does (examined 17 shapes + error 102 x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
