#!/usr/bin/env bash
# test_gate_icn_seq_takes_a_variable_step.sh -- seq(i, j) with a VARIABLE step is the generator icont makes of it (ceo CEO-631).
#
# MEASURED 2026-09-12 on b35ed8e2a: `every write(seq(1, x) \ 2)` raised "scrip: error 22: Undefined function called" in both
# modes while `seq(x, 1)` and `seq(1, 1)` answered 1 2 -- lower_seq required a CONSTANT step (icn_const_step) and returned
# nothing for a variable one, so the call fell to the generic by-name path where no runtime seq exists. Two IPL programs
# (ipower, iseq: `every i := seq(start, incr) \ limit`) were red on exactly this. Cure: a variable step lowers as
# `i to (if j < 0 then INT64_MIN else INT64_MAX) by j`, a synthesized to-by node handed to lower_to, so the to-by box's own
# sign-aware bound test serves both directions. Arms (one witness, seven seq shapes, both modes, byte-identical to icont):
# variable start, variable step, literal both, one argument, NEGATIVE variable step, both variable, omitted start.
# FAIL_ONCE=1 corrupts the negative-step line of the captured stream to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/s.icn" <<'ICN'
procedure main()
   local x, i, k;
   x := 1;
   every write("vstart ", seq(x, 1) \ 2);
   every write("vstep ", seq(1, x) \ 2);
   every i := seq(1, 1) \ 2 do write("lit ", i);
   every i := seq(x) \ 2 do write("one ", i);
   k := -3;
   every write("neg ", seq(10, k) \ 3);
   k := 4;
   every write("both ", seq(k, k) \ 3);
   every write("nostart ", seq(, k) \ 2);
end
ICN
( cd "$T" && "$ICONT" -s s.icn -x ) >"$T/s.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run the witness"; exit 2; }
grep -q '^neg 4$' "$T/s.ref" || { echo "⛔ REFUSE(2): the oracle's own stream does not show the negative step reaching 4 -- this gate is asserting the wrong thing, or the oracle moved"; exit 2; }
[ "$(grep -c . "$T/s.ref")" = 16 ] || { echo "⛔ REFUSE(2): the oracle's stream is not the 16 lines the seven shapes produce"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" s.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o s.s s.icn </dev/null && gcc s.s -o s.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./s.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i 's/^neg 4$/neg 5/' "$T/$M.out"; fi
  if diff -u "$T/s.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS (byte-identical to icont, 7 seq shapes)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,14p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: seq with a variable, negative, both-variable or omitted-start step answers as icont does (7 shapes x 2 modes)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: seq with a non-constant step does not answer as icont does (examined 7 shapes x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
