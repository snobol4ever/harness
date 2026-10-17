#!/usr/bin/env bash
# test_gate_icn_coexpression_image_counts_activations_like_icont.sh -- the number in image(co-expression) and *C is the count of RESULTS the co-expression has produced for its activator, as under icont: it moves at the return seam, never on an explicit transfer (ceo CEO-655).
#
# MEASURED 2026-09-12 on 7bac62499 (the adversarial batch a03; the row's baton): after `7 @ f` with f := create |(v := @&source)
# icont reads f (0) and SCRIP (1); after the second @g with g := create (1 @ &main) icont &main (1), SCRIP (3). SCRIP
# incremented target->activations on every return of control to the activator (rt_coexpr.c scrip_coexpr_activate),
# icont increments coexpr.size only on Op_Coret (interp.r:1144), when the co-expression returns a result. Cure: the
# increment lives in scrip_coret (the co-expression producing the result), nowhere else; &main stays at 1. Ref cut from
# icont, both modes; FAIL_ONCE=1 corrupts the second line.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
ICONT="${ICONT_BIN:-/home/resources/icon-master/bin/icont}"; [ -x "$ICONT" ] || { echo "⛔ GATE REFUSE(2) [$G]: no icont at $ICONT -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/c.icn" <<'ICN'
procedure main()
   local f, g, v, h;
   write(image(&current), " ", image(&main));
   f := create |(v := @&source);
   7 @ f; write("f1 ", image(f), " ", image(&main));
   8 @ f; write("f2 ", image(f), " ", image(&main), " v=", v);
   8 @ f; write("f3 ", image(f), " ", image(&main));
   g := create (1 @ &main);
   write("g0 ", image(g), " ", @g, " ", image(g), " ", image(&main));
   write("g1 ", @g | "fail", " ", image(g), " ", image(&main));
   write("g2 ", @g | "fail", " ", image(g), " ", image(&main));
   h := ^g; write("h0 ", image(h), " ", @h, " ", image(h));
   h := create |seq(); every 1 to 3 do @h; write("h ", image(h), " ", *h, " ", *g, " ", *&main);
   write(image(&current), " ", image(&main));
end
ICN
( cd "$T" && "$ICONT" -s c.icn -x ) >"$T/c.ref" 2>&1
grep -q '^f1 co-expression_2(0) co-expression_1(1)$' "$T/c.ref" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle's f1 line is not the row this gate pins -- the oracle moved: $(sed -n 2p "$T/c.ref")"; exit 2; }
RC=0
for M in m3 m4; do
  if [ "$M" = m3 ]; then ( cd "$T" && timeout -k 5 20 "$SCRIP" c.icn </dev/null ) >"$T/$M.out" 2>&1
  else ( cd "$T" && timeout -k 5 20 "$SCRIP" --compile -o c.s c.icn </dev/null && gcc c.s -o c.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: mode-4 witness did not build"; exit 2; }
       ( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20 ./c.bin </dev/null ) >"$T/$M.out" 2>&1
  fi
  if [ -n "${FAIL_ONCE:-}" ]; then sed -i '2s/_2(0)/_2(1)/' "$T/$M.out"; fi
  if diff -u "$T/c.ref" "$T/$M.out" >"$T/$M.diff"; then echo "  $M PASS ($(wc -l <"$T/c.ref") lines byte-identical to icont)"
  else echo "  $M FAIL ($(grep -c '^[-+][^-+]' "$T/$M.diff") diff lines)"; sed -n '1,14p' "$T/$M.diff" | sed 's/^/      /'; RC=1; fi
done
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: image(C) and *C count the results a co-expression produced, as icont does, in both modes"
else echo "GATE FAIL(1) [$G]: the co-expression count disagrees with icont (examined 2 modes)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $ICONT  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
