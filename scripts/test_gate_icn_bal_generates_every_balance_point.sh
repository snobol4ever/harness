#!/usr/bin/env bash
# test_gate_icn_bal_generates_every_balance_point.sh -- bal() is a generator at every arity and resumes to the next balance point (ceo CEO-645).
#
# MEASURED 2026-09-12 (row icon-bal-generator-yields-one-result-not-a-backtracking-sequence; the adversarial batch a13):
# `every writes(bal('+-', '(', ')', "(a+b)+c-(d)+e"))` printed 6 alone where icont prints 6 8 12 -- bal with two or more
# arguments was lowered as a plain call (one result, no resume) and the by-name generator re-pump knew only find and upto.
# Cure: the lowerer treats bal at every arity (0..6) as a generator, and the by-name branch is a stepping function that
# carries (position, running balance count) in the generator's resume cell -- a restart with count zero would misread a
# c1 character that also opens or closes. Arms: four cset shapes, tab(bal()) inside a scan with a further conjunct (the
# tokenizer idiom the row names), the no-argument scanning form, explicit i and j, and a c1 that overlaps c2, byte-identical
# to icont in both modes. FAIL_ONCE=1 corrupts the captured stream to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ REFUSE(2): no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/b.icn" <<'ICN'
procedure main()
   local s;
   s := "(a+b)+c-(d)+e";
   every writes(bal('+-', '(', ')', s), " "); write();
   every writes(bal(&cset, '(', ')', s), " "); write();
   every writes(bal('(', '(', ')', "((a)(b))"), " "); write();
   every writes(bal(')', '(', ')', "((a)(b))"), " "); write();
   s ? { every writes(tab(bal('+-')), "|"); write(); };
   s ? { write(tab(bal('+-')) & tab(0)); };
   "x(y" ? write(bal() | "nobal");
   every writes(bal('+', '[', ']', "[a+b]+[c]", 2, -1), " "); write();
   write(bal('+', '(', ')', "(a)+b", 3, 4) | "f34");
   s ? { write(tab(bal('+-')) & tab(bal('+-')) & tab(0)); };
   every writes(bal(&cset, '(', ')', "()a"), " "); write();
end
ICN
( cd "$T" && "$ICONT" -s b.icn -x ) >"$T/b.ref" 2>&1 || { echo "⛔ REFUSE(2): the oracle itself did not run the witness"; exit 2; }
grep -q '^6 8 12 $' "$T/b.ref" || { echo "⛔ REFUSE(2): the oracle's own first line is not the three balance points this gate pins -- the oracle moved: $(head -1 "$T/b.ref")"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" b.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o b.s b.icn </dev/null && gcc b.s -o b.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./b.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i '1s/^6 8 12 $/6 /' "$T/$M.out"; fi
  if diff -u "$T/b.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS (byte-identical to icont, 11 lines)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,10p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: bal generates every balance point and resumes through tab() conjuncts, at every arity, in both modes"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: bal does not generate every balance point as icont does (examined 11 lines x 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
