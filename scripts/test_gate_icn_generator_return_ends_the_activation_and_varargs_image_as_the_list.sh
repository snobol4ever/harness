#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the instrumentation switch (--stlimit): Icon &trace rides the call/return hooks that are off by default since SCRIP 2026-09-24 (Lon: monitor hooks behind the switch)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_generator_return_ends_the_activation_and_varargs_image_as_the_list.sh -- two things a traced
# procedure that CONTAINS a suspend still got wrong after 1493214e4 raised its RETURN event: the return did
# not END the activation (the next resume reached omega and printed a spurious "NAME failed", where Icon's
# return removes the generator), and its variadic parameter imaged as &null instead of the collected list.
# Both had ONE cause and are cured together (row icon-a-traced-generator-that-returns-traces-as-failed, cfo,
# under CEO-545). 1493214e4 named the first of them explicitly as left uncured; the second it never touched.
#
# ⛔ IT SITS BESIDE test_gate_icn_generator_return_traces_returned_not_failed.sh, NOT INSTEAD OF IT, and the
# overlap was checked rather than assumed: that gate bounds its generator with `\ 2` so the post-return
# resume NEVER HAPPENS -- which is exactly why it could go green while the spurious "failed" stood. This one
# drives the generator to exhaustion with no bound, which is the only shape that reaches the defect.
#
# ⛔ THE CONDITION IS "THE PROCEDURE CONTAINS A suspend", NOT "THE CALL IS VARIADIC" -- that is the finding
# and it is why g3 is here. A variadic NON-generator was already byte-identical to iconx; adding one
# `suspend` to the SAME procedure broke the call image AND the outcome verb at once, because a generator is
# entered through the N-2 region path: its CALL event is raised CALLER-side from the incoming argument
# vector (so the collected tail list is never read and the loop pads with &null), and its `return` is
# lowered as YIELD-THEN-RETIRE (so its only exit tap was omega's, which reports a failure).
#
# ⭐ THE LOAD-BEARING CONTROLS ARE g2 AND g3, and they guard OPPOSITE overshoots. g2's generator never
# returns -- it suspends and is driven to exhaustion -- so it MUST still print "g failed": a cure that
# suppresses the retire tap unconditionally, rather than one fail per recorded return, greens g1 and
# silently deletes the event that test_gate_icn_generator_exhaustion_traces_failed exists to protect. g3 is
# the variadic non-generator that was ALREADY correct, so it catches a cure written too wide in the call path.
#
# ⛔ &trace WRITES ONLY TO stderr; every arm captures 2>&1 for that reason.
# Every .want below is the byte-exact stdout+stderr of icont/iconx 9.5.25a (/home/resources/icon-master/bin).
# EXIT: 0 all six arms byte-identical; 1 a mismatch; 2 REFUSED (no binary, no gcc, stale build).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/g1.icn" <<'ICN'
procedure main()
   &trace := -1;
   every vp();
   every vp(1);
   every vp(1,2,3);
end
procedure vp(a, b[])
   if *b = 0 then return a
   else suspend *b | 0;
end
ICN
cat > "$T/g1.want" <<'WANT'
g1.icn       :    3  | vp(&null,list_1 = [])
g1.icn       :    8  | vp returned &null
g1.icn       :    4  | vp(1,list_2 = [])
g1.icn       :    8  | vp returned 1
g1.icn       :    5  | vp(1,list_3 = [2,3])
g1.icn       :    9  | vp suspended 2
g1.icn       :    5  | vp resumed
g1.icn       :    9  | vp suspended 0
g1.icn       :    5  | vp resumed
g1.icn       :   10  | vp failed
g1.icn       :    6  main failed
WANT
cat > "$T/g2.icn" <<'ICN'
procedure main()
   &trace := -1;
   every g(1);
end
procedure g(n)
   suspend n;
end
ICN
cat > "$T/g2.want" <<'WANT'
g2.icn       :    3  | g(1)
g2.icn       :    6  | g suspended 1
g2.icn       :    3  | g resumed
g2.icn       :    7  | g failed
g2.icn       :    4  main failed
WANT
cat > "$T/g3.icn" <<'ICN'
procedure main()
   &trace := -1;
   every h();
   every h(1,2);
end
procedure h(a, b[])
   return a;
end
ICN
cat > "$T/g3.want" <<'WANT'
g3.icn       :    3  | h(&null,list_1 = [])
g3.icn       :    7  | h returned &null
g3.icn       :    4  | h(1,list_2 = [2])
g3.icn       :    7  | h returned 1
g3.icn       :    5  main failed
WANT
graded=0; fail=0
for w in g1 g2 g3; do
  ( cd "$T" && timeout -k 5 60 "$SCRIP" "$w.icn" </dev/null > "$w.m3" 2>&1 ); rc3=$?
  graded=$((graded+1))
  if cmp -s "$T/$w.m3" "$T/$w.want"; then echo "  PASS  m3 $w (rc=$rc3)"; else echo "  FAIL  m3 $w rc=$rc3"; diff "$T/$w.want" "$T/$w.m3" | head -10 | sed 's/^/        /'; fail=1; fi
  if ( cd "$T" && "$SCRIP" --compile "$w.icn" > "$w.s" 2>/dev/null && gcc -c "$w.s" -o "$w.o" 2>/dev/null && gcc "$w.o" -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$w.bin" 2>/dev/null ); then
    ( cd "$T" && timeout -k 5 60 "./$w.bin" </dev/null > "$w.m4" 2>&1 ); rc4=$?
    graded=$((graded+1))
    if cmp -s "$T/$w.m4" "$T/$w.want"; then echo "  PASS  m4 $w (rc=$rc4)"; else echo "  FAIL  m4 $w rc=$rc4"; diff "$T/$w.want" "$T/$w.m4" | head -10 | sed 's/^/        /'; fail=1; fi
  else echo "  FAIL  m4 $w: no binary"; fail=1; graded=$((graded+1)); fi
done
[ "$graded" -eq 6 ] || { echo "⛔ REFUSE(2): graded $graded arms, expected 6"; exit 2; }
if [ "$fail" = 0 ]; then echo "✅ PASS: 6/6 -- a generator's return ends the activation and its vararg images as the list (g1), exhaustion still traces as failed (g2), and the variadic non-generator is unmoved (g3), both modes"; exit 0; fi
echo "⛔ FAIL: a traced generator is re-entered after its return, or is misreporting its argument image (see the FAIL rows)"; exit 1
