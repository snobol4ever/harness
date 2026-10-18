#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_bounded_expression_releases_suspended_frame.sh — CEO-456 R5, the omega release, as a gate (R6).
#
# A bounded expression that leaves a callee generator SUSPENDED must release that frame at its omega (iconx
# Op_Unmark resets rsp below the ef_marker, dropping every suspended frame above it). If SCRIP retained the
# frame, a loop would grow the stack once per iteration and die ERROR 246 long before a million laps. The
# witness: f suspends and is never resumed; one million bounded calls, then two hundred thousand more in a
# condition, both modes, against icont's counts. PASS = both modes print the oracle's two lines and exit 0.
# ⭐ r6 (hq_icon 2026-10-01, the Expressions demo leak row): repeat, while and until carried no Op_Mark/Op_Unmark at all --
# only every's do-clause did -- so a generator abandoned by a limitation (t() \ 1) in a repeat body, a while/until body or
# condition, or a generator doing `repeat suspend t() \ 1` resumed by its consumer, kept its frame every lap and died
# ERROR 246 near 18,650 laps at the shipped 4 MB stack (iconx: no limit). lower_icon.c now marks each loop's head and
# unmarks on its back-edge (and on next). Seven loops of 200,000 laps, icont's counts. RED on the parent 3be51478c: m3
# ERROR 246 rc 1 before its first line.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/r5.icn" <<'ICN'
procedure f(); suspend 1; suspend 2; end
procedure main();
   local i, n;
   n := 0;
   every i := 1 to 1000000 do { f(); n +:= 1 };
   write(n);
   every i := 1 to 200000 do { if f() = 1 then n +:= 1 };
   write(n);
end
ICN
printf '1000000\n1200000\n' > "$T/want"
fail=0
timeout -k 5 120 "$SCRIP" "$T/r5.icn" </dev/null > "$T/m3" 2>&1; rc3=$?
if [ $rc3 -ne 0 ] || ! cmp -s "$T/m3" "$T/want"; then echo "⛔ FAIL m3 rc=$rc3: $(head -c 160 "$T/m3" | tr '\n' ' ')"; fail=1; fi
if "$SCRIP" --compile "$T/r5.icn" > "$T/r5.s" 2>/dev/null && gcc -c "$T/r5.s" -o "$T/r5.o" 2>/dev/null && gcc "$T/r5.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/r5.bin" 2>/dev/null; then
  timeout -k 5 120 "$T/r5.bin" </dev/null > "$T/m4" 2>&1; rc4=$?
  if [ $rc4 -ne 0 ] || ! cmp -s "$T/m4" "$T/want"; then echo "⛔ FAIL m4 rc=$rc4: $(head -c 160 "$T/m4" | tr '\n' ' ')"; fail=1; fi
else echo "⛔ REFUSE(2): mode-4 build of the witness failed -- cannot measure"; exit 2; fi
cat > "$T/r6.icn" <<'ICN'
procedure t(); suspend 1; suspend 2; end
procedure g(); repeat suspend t() \ 1; end
procedure main();
   local n;
   n := 0; repeat { t() \ 1; if (n +:= 1) >= 200000 then break }; write(n);
   n := 0; while (n +:= 1) < 200000 do t() \ 1; write(n);
   n := 0; while t() \ 1 do if (n +:= 1) >= 200000 then break; write(n);
   n := 0; until (n +:= 1) >= 200000 do t() \ 1; write(n);
   n := 0; until not (t() \ 1) do if (n +:= 1) >= 200000 then break; write(n);
   n := 0; repeat { if (n +:= 1) % 2 = 0 then { t() \ 1; next }; if n >= 200000 then break }; write(n);
   n := 0; every g() \ 200000 do n +:= 1; write(n);
end
ICN
printf '200000\n200000\n200000\n200000\n200000\n200001\n200000\n' > "$T/want6"
timeout -k 5 120 "$SCRIP" "$T/r6.icn" </dev/null > "$T/m3r6" 2>&1; rc3=$?
if [ $rc3 -ne 0 ] || ! cmp -s "$T/m3r6" "$T/want6"; then echo "⛔ FAIL r6 m3 rc=$rc3: $(head -c 160 "$T/m3r6" | tr '\n' ' ')"; fail=1; fi
if "$SCRIP" --compile "$T/r6.icn" > "$T/r6.s" 2>/dev/null && gcc -c "$T/r6.s" -o "$T/r6.o" 2>/dev/null && gcc "$T/r6.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/r6.bin" 2>/dev/null; then
  timeout -k 5 120 "$T/r6.bin" </dev/null > "$T/m4r6" 2>&1; rc4=$?
  if [ $rc4 -ne 0 ] || ! cmp -s "$T/m4r6" "$T/want6"; then echo "⛔ FAIL r6 m4 rc=$rc4: $(head -c 160 "$T/m4r6" | tr '\n' ' ')"; fail=1; fi
else echo "⛔ REFUSE(2): mode-4 build of the r6 witness failed -- cannot measure"; exit 2; fi
[ $fail = 0 ] && echo "✅ PASS: a bounded expression releases its suspended callee frame at omega -- every do (1,200,000 laps) and repeat/while/until bodies, conditions, next and a resumed repeat-suspend generator (7 x 200,000 laps), both modes, no ERROR 246 (CEO-456 R5)"
exit $fail
