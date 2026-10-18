#!/usr/bin/env bash
# test_gate_icn_args_of_a_variadic_procedure_is_negative.sh -- args(p) of a procedure declared p(a[]) is negative, as under icont (ceo CEO-643).
#
# MEASURED 2026-09-12 on 3de7f285d (the adversarial batch): args(va) for `procedure va(a[])` answered 1 in both modes where
# icont answers -1 (the negative count marks a variadic procedure; args(main) 0 and args(write) -1 agreed). Cure: the args
# builtin negates the registered parameter count when the procedure's proc_table entry carries is_variadic. Arms: a fixed
# two-parameter procedure, a variadic one-parameter procedure, a variadic three-parameter procedure, main, and two builtins,
# byte-identical to icont in both modes. FAIL_ONCE=1 corrupts the captured stream to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/v.icn" <<'ICN'
procedure two(a, b)
   return a;
end
procedure va(a[])
   return *a;
end
procedure vb(x, y, z[])
   return *z;
end
procedure main()
   write(args(two), " ", args(va), " ", args(vb), " ", args(main), " ", args(write), " ", args(reverse));
   write(va(1, 2, 3), " ", vb(1, 2), " ", vb(1, 2, 3, 4), " ", two(5, 6));
end
ICN
( cd "$T" && "$ICONT" -s v.icn -x ) >"$T/v.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run the witness"; exit 2; }
grep -q '^2 -1 -3 0 -1 1$' "$T/v.ref" || { echo "⛔ REFUSE(2): the oracle's own first line is not the arity row this gate pins -- the oracle moved: $(head -1 "$T/v.ref")"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" v.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o v.s v.icn </dev/null && gcc v.s -o v.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./v.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i 's/^2 -1 -3 /2 1 3 /' "$T/$M.out"; fi
  if diff -u "$T/v.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS (byte-identical to icont)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,8p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: args() of a variadic procedure is negative, fixed and builtin arities unchanged (2 lines x 2 modes)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: args() of a variadic procedure does not answer as icont does (examined 2 lines x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
