#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the instrumentation switch (--stlimit): Icon &trace rides the call/return hooks that are off by default since SCRIP 2026-09-24 (Lon: monitor hooks behind the switch)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_icn_apply_invocation_of_a_generator_opens_one_level_not_two.sh -- invoking a GENERATOR through
# the apply operator (`p ! args`, and every other route that reaches rt_call_value_gen_h) opened TWO
# activation levels for ONE activation: rt_proc_call_gen_h raised rt_k_level around scrip_coexpr_activate
# AND the coroutine body's own rt_proc_call_open -> rt_proc_call_prologue_lex raised it again through
# rt_lvl_open(own=0), which is the arm a generator always takes. A DIRECT call of the same generator opens
# exactly one, which is why only the apply route was wrong (row: jcon tracing, cfo, under CEO-545).
#
# ⭐ THE VISIBLE FACE WAS THE TRACE INDENT, THE DEFECT WAS &level. The extra level printed one extra "| "
# on the call and on the first suspend, and -- because rt_trace_resume_hook walks g_icn_act DOWNWARD from
# rt_k_level looking for the activation with this name -- it made the "NAME resumed" line report a STALE
# earlier call site's line. Both are cosmetics of one wrong number: measured pre-cure, `&level` read inside
# a generator reached by `g ! args` answered 3 where iconx 9.5.25a answers 2, with the direct call of the
# same procedure answering 2 on both. A2 is the load-bearing arm for exactly that reason -- a cure written
# in the renderer (padding the bars, or re-dating the resume line) greens A1 and leaves A2 red.
#
# ⭐ A3 IS THE OVERSHOOT CONTROL: a NON-generator invoked through the same `!` operator was already right
# (it never enters the coroutine arm at all) and must stay right, so a cure written one layer too wide --
# in rt_call_value_gen_h, or in rt_lvl_open -- is caught here rather than by a suite three hours later.
#
# ⛔ NAMED, NOT CURED, AND NOT HIDDEN: iconx emits NO line marker for an apply-invocation, so its &line
# LAGS -- `every g ! args` on line 6 traces its call at line 5, the previous statement's line, and a bare
# `g ! args` on line 7 traces 5 too (measured, iconx 9.5.25a, 2026-09-11). SCRIP reports the statement's
# OWN line, 6 and 7. A1 is written in the `while ... do every g ! args` shape, where the previous statement
# IS the while header and both sides agree, so this gate grades the level defect and not that one. The lag
# is a separate divergence with its own witness; it is NOT graded here and must not be assumed cured.
#
# ⛔ &trace WRITES ONLY TO stderr; every arm captures 2>&1 for that reason.
# Every .want below is the byte-exact stdout+stderr of icont/iconx 9.5.25a (/home/resources/icon-master/bin).
# EXIT: 0 all six arms byte-identical; 1 a mismatch; 2 REFUSED (no binary, no gcc, stale build).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc for mode 4"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/a1.icn" <<'ICN'
procedure main()
   local args;
   &trace := -1;
   args := [1,2,3];
   while pull(args) do
      every g ! args;
end
procedure g(a, b[])
   suspend *b;
end
ICN
cat > "$T/a1.want" <<'WANT'
a1.icn       :    5  | g(1,list_2 = [2])
a1.icn       :    9  | g suspended 1
a1.icn       :    5  | g resumed
a1.icn       :   10  | g failed
a1.icn       :    5  | g(1,list_3 = [])
a1.icn       :    9  | g suspended 0
a1.icn       :    5  | g resumed
a1.icn       :   10  | g failed
a1.icn       :    5  | g(&null,list_4 = [])
a1.icn       :    9  | g suspended 0
a1.icn       :    5  | g resumed
a1.icn       :   10  | g failed
a1.icn       :    7  main failed
WANT
cat > "$T/a2.icn" <<'ICN'
procedure main()
   local args;
   args := [1,2];
   every write("direct ", g(1,2));
   every write("apply  ", g ! args);
   every write("nested ", h ! args);
   write("outer  ", &level);
end
procedure g(a, b[])
   suspend &level;
end
procedure h(a, b[])
   suspend g(a) | g(a);
end
ICN
cat > "$T/a2.want" <<'WANT'
direct 2
apply  2
nested 3
nested 3
outer  1
WANT
cat > "$T/a3.icn" <<'ICN'
procedure main()
   local args;
   &trace := -1;
   args := [1,2];
   every write(&level);
   every write(n ! args);
end
procedure n(a, b[])
   return &level;
end
ICN
cat > "$T/a3.want" <<'WANT'
1
a3.icn       :    6  | n(1,list_2 = [2])
a3.icn       :    9  | n returned 2
2
a3.icn       :    7  main failed
WANT
graded=0; fail=0
for w in a1 a2 a3; do
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
if [ "$fail" = 0 ]; then echo "✅ PASS: 6/6 -- an applied generator opens ONE level (A1 trace depth and resume line, A2 &level direct=apply=2), and the applied NON-generator is unmoved (A3), both modes"; exit 0; fi
echo "⛔ FAIL: an apply-invoked generator is opening two activation levels for one activation (see the FAIL rows)"; exit 1
