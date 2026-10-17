#!/usr/bin/env bash
# test_gate_icn_bal_argument_types_raise_as_icont.sh -- bal() with a non-cset, non-string or non-integer argument raises 104 / 103 / 101 with the offending value, as under icont, on the generator path too (ceo CEO-652).
#
# MEASURED 2026-09-12 on 3a510fa4e (the coo's fourth pass: Zona 88->87, Jcon 82->81, the errors program at its step for
# bal([],,,"")): bal([]) FAILED SILENTLY where icont raises 104 "cset expected" -- the CEO-645 landing made bal a generator
# at every arity and the generator re-pump (rt_call_arr_gen_s) called bn_bal_gen directly, bypassing icn_argtype_gate;
# find/upto through the same re-pump had the same hole. Cure: the re-pump runs the gate on the FIRST pump (resume cell 0)
# for bal, find and upto. Arms: seven bal shapes under &error (list as c1, c2, c3, subject, a non-integer position, a
# one-argument list) plus a generating call, byte-identical to icont in both modes. FAIL_ONCE=1 corrupts the first line.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ GATE REFUSE(2) [$G]: no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/b.icn" <<'ICN'
procedure main()
   local x;
   &error := -1;
   x := bal([],,,"");
   write("a ", &errornumber, " ", image(&errorvalue));
   x := bal("(", [], , "x");
   write("b ", &errornumber, " ", image(&errorvalue));
   x := bal("(", , [], "x");
   write("c ", &errornumber, " ", image(&errorvalue));
   x := bal("(", "(", ")", []);
   write("d ", &errornumber, " ", image(&errorvalue));
   x := bal("(", "(", ")", "(a)", "x");
   write("e ", &errornumber, " ", image(&errorvalue));
   every x := bal("a", , , "a(a)a") do write("f ", x);
   x := bal([]);
   write("g ", &errornumber, " ", image(&errorvalue));
   every x := find([], "abc") do write("h ", x);
   write("i ", &errornumber, " ", image(&errorvalue));
   every x := upto([], "abc") do write("j ", x);
   write("k ", &errornumber, " ", image(&errorvalue));
   write("errors ", -&error);
end
ICN
( cd "$T" && "$ICONT" -s b.icn -x ) >"$T/b.ref" 2>&1
grep -q '^a 104 list_1(0)$' "$T/b.ref" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's first line is not the 104 row this gate pins -- the oracle moved: $(head -1 "$T/b.ref")"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" b.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o b.s b.icn </dev/null && gcc b.s -o b.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./b.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i '1s/^a 104/a 105/' "$T/$M.out"; fi
  if diff -u "$T/b.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS ($(wc -l <"$T/b.ref") lines byte-identical to icont)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,14p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: bal, find and upto raise on a wrong-typed argument through the generator path as icont does, both modes"
else echo "GATE FAIL(1) [$G]: a wrong-typed argument to bal, find or upto does not raise as icont does (examined 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
