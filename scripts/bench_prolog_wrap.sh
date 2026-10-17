#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off: the collector's self-checks and the node-id stores (Lon 2026-09-25, in-chat to the ceo: "For benchmarks turn off all diagnostic code."; ceo CEO-1262)
# bench_prolog_wrap.sh -- BUILD A TIMED / COUNTED PROLOG BENCHMARK ON THE FLY FROM A PRISTINE KERNEL.
#
#   bash ../harness/scripts/bench_prolog_wrap.sh <kernel.pl> [-o <out.pl>] [--mode=single|time|iter] [--n=<iters>]
#                                     [--engine=scrip|gnu|swi]
#
# ⭐ WHY THIS EXISTS (CEO-567, RULES.md:321, ARCH-PROGRAM-LEDGER.md): the kernel's source holds the
#   COMPUTATION AND NOTHING ELSE; the wrapping and the messaging are GENERATED around a pristine source.
#   This is the Prolog twin of bench_wrap.sh, which has done the same job for SNOBOL4 since s265.
#
#   BEFORE (measured hq_P 2026-09-13, the state this script was written to end):
#     corpus/benchmarks/prolog/bench/ shipped TWO conventions in ONE directory -- 13 kernels were
#     pristine result-signature programs, and 10 baked a wall_us/wall_ms timing bracket into main/0.
#     ⛔ The 10 were UNMEASURABLE ON THE ENGINE UNDER MEASUREMENT: the rival arms consult
#     prelude_gplc.pl / prelude_swipl.pl, which define wall_us/1 and wall_ms/1, but SCRIP registers
#     wall_us and wall_ms at ARITY 0 ONLY (by_name_dispatch.c:2842, `nargs == 0`), so every one of the
#     ten raised existence_error(wall_us/1) -- AND EXITED 0, printing no answer.  A sweep counted that
#     as a run.  So the Prolog speed axis has been silently unmeasurable on SCRIP since the harness was
#     designed, while the rival columns kept reporting real numbers.
#     corpus/benchmarks/prolog/vanroy/ is the same 10+11 kernels with `main :- l__(64).` FROZEN into
#     each source -- the iteration count living inside the artifact under measurement.
#
#   AFTER: every corpus/benchmarks/prolog/bench/*.pl is a real standalone program that prints its own
#   oracle-graded answer and contains no timing and no iteration builtin.  This script builds the timed
#   or counted version into a temp file when someone wants a number.
#
# THE CONTRACT -- two things in the pristine kernel, both of which keep it standalone:
#
#     % *BENCH kernel=<name>                 one comment line, inert to every engine
#     bench_work(Res) :- <the computation>.  the work, and only the work
#     main :- bench_work(Res), write(Res), nl.
#
#   bench_work/1 is the bracket's content: the timing bracket encloses the CALL TO IT and nothing else,
#   so the published number is work-on-work and the write stays outside.  main/0 is what makes the file
#   a program rather than a fragment, and its stdout is what <name>.ref grades.
#
# ⭐ THREE ANGLES OVER ONE PRISTINE SOURCE (the same three bench_wrap.sh gives SNOBOL4):
#     --mode=single  the work ONCE, self-timed.  stdout is the kernel's real answer, so the run is
#                    GRADED and TIMED at once; work_us/work_ms go to user_error and stdout stays
#                    byte-comparable against <name>.ref.
#     --mode=iter    exactly --n=N iterations, no wall-clock deadline anywhere.  This is the arm for
#                    callgrind/cachegrind, where a deadline measures the INSTRUMENT's throughput
#                    instead of the kernel's (FINDING-2026-08-22-bench-harness-unmeasurable).
#                    ⛔ stdout is N copies of the answer ON PURPOSE -- that is what lets loop_check()
#                    in lib_prolog_bench.sh PROVE the loop looped before its time is divided by N.
#     --mode=time    (angle 3's companion) run the work until --bud ms is spent, COUNT the iterations.
#   The process wrapper -- /usr/bin/time, perf stat, callgrind around the whole run -- is angle 3 and
#   needs no generated file at all; its total minus the self-measured work IS the overhead number.
#
# ⛔ --engine names WHO WILL RUN THE OUTPUT, and it changes only the PRELUDE, never the kernel.
#   ⭐ The prelude is here rather than in the kernel because the KERNEL must be byte-identical across
#   every engine -- the kernel is the thing being compared.
#
# ✅⭐⭐ RETRACTED 2026-09-13 BY hq_P, BY EXECUTION: SCRIP'S PROLOG NOW HAS A WALL CLOCK, AND THE
#   PARAGRAPH BELOW IS KEPT ONLY FOR ITS HISTORY AND ITS LESSON.  The cto landed wall_us/1 and wall_ms/1
#   as real Prolog builtins at SCRIP 05317a5fb.  Verified HERE with NO prelude loaded, so it is SCRIP
#   answering and not a rival prelude's definition: m3 -> us(248130129882) ms(248130129), m4 -> the same
#   shape.  The script no longer believes either the old claim OR the new one: it PROBES the binary (see
#   the CLOCK block below) and both modes must answer before a bracket is emitted.
#   ⛔⭐ THE LESSON IS WHY THE WHOLE PARAGRAPH STAYS: the claim below was MEASURED, was TRUE the day it
#   was written, named its evidence and its commit -- and was still the thing that made this harness
#   wrong, because it was frozen into a CONSTANT (`CLOCK=1; [ "$ENGINE" = scrip ] && CLOCK=0`) sitting
#   under a comment that said "Measured, not assumed."  A measurement pasted into a constant stops being
#   a measurement the moment the world moves, and it keeps the authority of one.  That is the defect
#   class, not this one flag: TRUE-WHEN-WRITTEN IS NOT TRUE, AND A CAPABILITY IS ASKED, NEVER REMEMBERED.
# ⛔⛔ THE SUPERSEDED CLAIM (hq_P 2026-09-13, SCRIP 202d8bfff -- read as history, never as current state):
#   SCRIP'S PROLOG HAS NO WALL CLOCK AT ALL, AND THAT IS REPORTED, NOT PAPERED OVER
#   (MEASURED by execution, hq_P 2026-09-13, SCRIP 202d8bfff).  The row that sent this work up said the
#   defect was an ARITY mismatch -- wall_us registered at 0, called at 1.  It is worse than that: all
#   SIX spellings the three engines use raise on SCRIP --
#       wall_us/1 . wall_ms/1 . statistics/2 . real_time/1 . get_time/1  -> existence_error(procedure)
#       X is cputime . X is realtime                                     -> type_error(evaluable)
#   The `nargs == 0` wall_us/wall_ms at by_name_dispatch.c:2842 is SNOBOL4's BY-NAME dispatch and is not
#   reachable from Prolog at any arity, so registering a /1 twin there would not reach Prolog either.
#   ⭐ CONSEQUENCE FOR THE BASIS: the two-number WORK/OVERHEAD basis has NO work number on SCRIP's Prolog
#   arm.  Only the process wrapper (angle 3, external total) can produce a Prolog number on SCRIP today,
#   and an external total is a TOTAL -- it carries startup and may never share a column with a rival's
#   self-measured work (RULES.md, apples-to-apples: a SLOPE is not a TOTAL).
#   ⛔ So for --engine=scrip this script emits the counted form WITHOUT a bracket and says
#   work_us=UNAVAILABLE in the BENCH line.  It does NOT emit a bracket that raises and exits 0, which is
#   what the checked-in sources did: existence_error(wall_us/1) printed to stderr, no answer on stdout,
#   rc=0 -- a sweep counted that as a run.  A missing instrument is reported as missing.
set -u
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SELF/../.." && pwd)"
# ⛔ TWO DIFFERENT ROOTS, AND CONFUSING THEM COSTS A SILENT FALSE ANSWER: ROOT is the SIBLING root (the
# parent of SCRIP/ and corpus/), STREE is the SCRIP CHECKOUT.  The clock probe needs the BINARY, which
# lives in the checkout -- `$ROOT/scrip` does not exist, and a probe that cannot find the binary answers
# "no clock" in exactly the same voice as a binary that has none.  (Measured here: the first cut of the
# probe used $ROOT and reported no-clock on a binary that had just answered the witness by hand.)
STREE="$(cd "$SELF/../../SCRIP" && pwd)"
PRO="$ROOT/corpus/benchmarks/prolog"
MODE=single; N=""; BUD=1000; OUT=""; ENGINE=scrip; KPL=""
for a in "$@"; do
  case "$a" in
    --mode=*)   MODE="${a#*=}" ;;
    --n=*)      N="${a#*=}" ;;
    --bud=*)    BUD="${a#*=}" ;;
    --engine=*) ENGINE="${a#*=}" ;;
    -o)         OUT="__NEXT__" ;;
    *)          if [ "$OUT" = "__NEXT__" ]; then OUT="$a"; else KPL="$a"; fi ;;
  esac
done
[ -n "$KPL" ] && [ -f "$KPL" ] || { echo "⛔ REFUSED: no kernel source given (usage in the header)" >&2; exit 2; }
case "$MODE" in single|iter|time) ;; *) echo "⛔ REFUSED: unknown --mode=$MODE" >&2; exit 2 ;; esac
case "$ENGINE" in scrip|gnu|swi) ;; *) echo "⛔ REFUSED: unknown --engine=$ENGINE" >&2; exit 2 ;; esac
[ "$MODE" = iter ] && [ -z "$N" ] && { echo "⛔ REFUSED: --mode=iter needs --n=<iterations>" >&2; exit 2; }
# ⭐ CLOCK is the per-engine wall-clock capability the two-number basis needs, and it is PROBED, NEVER
#   ASSUMED.  This spot used to read `CLOCK=1; [ "$ENGINE" = scrip ] && CLOCK=0` directly beneath a
#   comment that said "Measured, not assumed." -- a HARDCODED CAPABILITY ASSUMPTION that was true the day
#   it was written and became FALSE the moment the cto landed wall_us/1 and wall_ms/1 as real Prolog
#   builtins (SCRIP 05317a5fb).  It is replaced by a PROBE and not by the opposite constant on purpose:
#   a constant with the right value is the SAME DEFECT holding a luckier number, and the next capability
#   change would need another edit right here.  After this, it needs none.
#   ⛔ EACH ENGINE IS ASKED AT ITS OWN PROVIDER, because that is where the capability actually comes from:
#     gnu / swi -- the clock is supplied by the prelude THIS SCRIPT cats in, so the PRELUDE FILE is what
#                  is asked; a prelude that lost the definition is caught here instead of at run time.
#     scrip     -- nothing is catted in, so the BINARY is asked, by compiling and running a witness that
#                  carries NO prelude.  ⛔ A prelude-bearing witness can never testify about the builtin:
#                  it answers with get_time/1 out of the prelude and reads as a pass (hq_P made exactly
#                  this mistake once this row and nearly recorded the builtin as proven).
#   ⛔ BOTH MODES MUST ANSWER.  --engine=scrip names ONE generated artifact that angle 2 then runs under
#   m3 AND m4, so the clock must exist under both or the emitted bracket raises in whichever mode lacks
#   it -- which is precisely the existence_error-and-exit-0 silence this entire row exists to end.
#   The answer is cached under a fingerprint of the binary and the runtime it links, so a rebuild
#   re-probes by itself and the 23-kernel sweep pays for the probe once rather than 23 times.
clock_probe_prelude() {  # $1 = prelude path; the provider for the rival engines
  [ -s "$1" ] || return 1
  grep -qE '^[[:space:]]*wall_us\(' "$1" && grep -qE '^[[:space:]]*wall_ms\(' "$1"
}
clock_probe_scrip() {    # ask the BINARY, no prelude, in BOTH modes; cache on the binary fingerprint
  local bin="${SCRIP:-$STREE/scrip}" rt="${RT_DIR:-$STREE/out}" fp cache w pl ok=1
  [ -x "$bin" ] || return 1
  fp="$( { stat -c '%s %Y' "$bin" "$rt/libscrip_rt.so" 2>/dev/null; } | md5sum 2>/dev/null | cut -c1-16)"
  cache="${TMPDIR:-/tmp}/.scrip_prolog_clock.${fp:-nofp}"
  if [ -s "$cache" ]; then [ "$(cat "$cache")" = yes ]; return $?; fi
  w="$(mktemp -d -t clockprobe_XXXXXX)" || return 1
  pl="$w/w.pl"
  { echo ":- initialization(main)."
    echo "main :- wall_us(A), wall_ms(B), integer(A), integer(B), write(clockok), nl."; } > "$pl"
  [ "$(cd "$w" && timeout -k 5 30 "$bin" --run "$pl" </dev/null 2>/dev/null | head -1)" = clockok ] || ok=0
  if [ "$ok" = 1 ]; then
    if (cd "$w" && timeout -k 5 60 "$bin" --compile --target=x86 "$pl" </dev/null >"$w/w.s" 2>/dev/null) && [ -s "$w/w.s" ] \
       && as --64 -o "$w/w.o" "$w/w.s" 2>/dev/null \
       && gcc -no-pie -o "$w/w.bin" "$w/w.o" "$rt/libscrip_rt.so" -lm -lstdc++ -Wl,-rpath,"$rt" 2>/dev/null; then
      [ "$(cd "$w" && timeout -k 5 30 "$w/w.bin" </dev/null 2>/dev/null | head -1)" = clockok ] || ok=0
    else ok=0; fi
  fi
  rm -rf "$w"
  [ "$ok" = 1 ] && echo yes > "$cache" || echo no > "$cache"
  [ "$ok" = 1 ]
}
case "$ENGINE" in
  gnu)   clock_probe_prelude "$PRO/prelude_gplc.pl"  && CLOCK=1 || CLOCK=0 ;;
  swi)   clock_probe_prelude "$PRO/prelude_swipl.pl" && CLOCK=1 || CLOCK=0 ;;
  scrip) clock_probe_scrip                           && CLOCK=1 || CLOCK=0 ;;
esac
if [ "$CLOCK" = 0 ] && [ "$MODE" = time ]; then
  echo "⛔ REFUSED: --mode=time needs a wall clock and SCRIP's Prolog has none (see the header)." >&2
  echo "   Use --mode=iter with a fixed --n and time the whole process from OUTSIDE (angle 3)." >&2; exit 2; fi
# ⛔ THE CONTRACT IS CHECKED, NOT ASSUMED: a kernel that does not carry it would silently produce a
# wrapper whose bracket encloses nothing, and the harness would publish the startup cost as the work.
K="$(sed -n 's/^% \*BENCH kernel=\([A-Za-z0-9_]*\).*/\1/p' "$KPL" | head -1)"
[ -n "$K" ] || { echo "⛔ REFUSED: $KPL carries no '% *BENCH kernel=<name>' marker" >&2; exit 2; }
grep -qE '^bench_work\(' "$KPL" || { echo "⛔ REFUSED: $KPL defines no bench_work/1 -- the bracket would enclose nothing" >&2; exit 2; }
if sed 's/^%.*//' "$KPL" | grep -qE '\b(wall_us|wall_ms|statistics|real_time|get_time)\s*\('; then
  echo "⛔ REFUSED: $KPL is NOT PRISTINE -- it carries a timing builtin (CEO-567)" >&2; exit 2; fi
[ -n "$OUT" ] || OUT="$(mktemp -t "bench_${K}_XXXXXX.pl")"
{
  echo "% GENERATED by ../harness/scripts/bench_prolog_wrap.sh from $KPL -- DO NOT CHECK IN."
  echo "% mode=$MODE engine=$ENGINE${N:+ n=$N}${MODE:+ }kernel=$K"
  echo "% ⛔ The kernel source below is VERBATIM. Everything outside it is the wrapper, and the wrapper"
  echo "% is the only thing that knows about time or about iteration counts (CEO-567)."
  case "$ENGINE" in
    gnu) cat "$PRO/prelude_gplc.pl" ;;
    swi) cat "$PRO/prelude_swipl.pl" ;;
    scrip) if [ "$CLOCK" = 1 ]; then
             echo "% no prelude, and none is needed: wall_us/1 and wall_ms/1 are REAL SCRIP BUILTINS (cto,"
             echo "% SCRIP 05317a5fb), PROBED on this very binary before this file was written -- so the"
             echo "% bracket below is SCRIP's own clock and not a prelude's get_time/1 wearing its name."
           else
             echo "% no prelude, and the PROBE of this binary found no wall_us/1 + wall_ms/1 pair, so this"
             echo "% generated program carries NO timing bracket and says work_us=UNAVAILABLE out loud."
           fi ;;
  esac
  # the kernel verbatim, minus its own main/0 and its initialization directive -- the wrapper supplies both
  sed -e '/^:- *initialization(main)\./d' -e '/^main *:- *bench_work(Res), *write(Res), *nl\./d' "$KPL"
  echo ":- initialization(main)."
  # ⛔ one write per iteration ON PURPOSE in --mode=iter: lib_prolog_bench.sh's loop_check() compares
  # stdout against N copies of the .ref, which is the ONLY proof the loop ran N times before the
  # time is divided by N. MEASURED s-history: without it, a wrapper that stopped after TWO iterations was
  # divided by N=65536 and published m3 at 3,102,442 iter/s against gprolog's 485 -- and angle 1 and
  # angle 2 AGREED on the fabrication to within 1%, because they shared the defect.
  case "$MODE" in
    single) [ "$CLOCK" = 1 ] \
      && { echo "main :- wall_us(T0), wall_ms(M0), bench_work(Res), wall_us(T1), wall_ms(M1),"
           echo "        write(Res), nl, W is T1 - T0, WM is M1 - M0,"
           echo "        format(user_error, \"BENCH kernel=$K mode=single work_us=~w work_ms=~w~n\", [W, WM])."; } \
      || { echo "main :- bench_work(Res), write(Res), nl,"
           echo "        format(user_error, \"BENCH kernel=$K mode=single work_us=UNAVAILABLE work_ms=UNAVAILABLE engine=$ENGINE-has-no-wall-clock~n\", [])."; } ;;
    iter)
      # ⛔⭐ once/1 AROUND THE KERNEL, AND IT IS THE DIFFERENCE BETWEEN ITERATING N TIMES AND ENUMERATING
      #   A SOLUTION SET (hq_P 2026-09-13, measured on 4 of 23 kernels).  This is a FAILURE-DRIVEN loop:
      #   the trailing `fail` backtracks, and Prolog retries the MOST RECENT choice point first -- which
      #   is bench_work's, not between/3's.  So for a NONDETERMINISTIC kernel the loop walks that kernel's
      #   whole solution set before it ever asks between/3 for iteration 2.  MEASURED: queens on m3 ran
      #   120 s emitting 18,297 solution lines where gnu answers in 11 ms, and queens_8/ham printed 92
      #   lines at N=1.  All four read NA on every engine and vanished from angle 1's board.
      #   ⭐ THE LOOP-OUTPUT CHECK IS WHAT CAUGHT IT AND IT BEHAVED EXACTLY AS DESIGNED -- it refused with
      #   LOOP-OUTPUT-MISMATCH(lines=92/1) rather than dividing a time by an N the loop never ran.  The
      #   fabrication it prevented is the one its own header records: a wrapper that stopped after two
      #   iterations divided by N=65536 and published m3 at 3,102,442 iter/s.
      #   ⛔ COMMITTING TO THE FIRST SOLUTION IS SEMANTICALLY TRANSPARENT ON A DETERMINISTIC KERNEL, which
      #   is what the other 19 are -- their .ref is a single answer, so taking the first solution is
      #   what the reference already says the program computes.  It is not a tolerance and it hides no
      #   red: a kernel whose FIRST solution is wrong still fails the loop-output check against .ref.
      #   ⛔⭐ AND IT IS A CUT IN A ONE-LINE HELPER, NOT once/1, FOR A MEASURED REASON -- once/1 WAS TRIED
      #   FIRST AND REGRESSED 18 GREEN KERNELS (hq_P 2026-09-13).  On m3/m4 a failure-driven loop calling
      #   once/1 dies after exactly 121 iterations: nrev at N=64 printed 64 lines rc=0, at N=256 printed
      #   121 lines rc=1, at N=1024 the same 121 and rc=1.  The cut form runs 64/256/1024 clean.  The two
      #   are ISO-equivalent (once(G) IS call(G), !), so this is a SCRIP once/1 defect the wrapper must
      #   not stand on -- routed to the Prolog lane, NOT worked around silently.  ⛔ Do not "simplify"
      #   this back to once/1 without re-running nrev at N=1024 on m3.
      echo "bench__one(Res) :- bench_work(Res), !."
      echo "bench__loop(N) :- between(1, N, _), bench__one(Res), write(Res), nl, fail."
      echo "bench__loop(_)."
      [ "$CLOCK" = 1 ] \
      && { echo "main :- wall_us(T0), wall_ms(M0), bench__loop($N), wall_us(T1), wall_ms(M1),"
           echo "        W is T1 - T0, WM is M1 - M0,"
           echo "        format(user_error, \"BENCH kernel=$K mode=iter n=$N work_us=~w work_ms=~w~n\", [W, WM])."; } \
      || { echo "main :- bench__loop($N),"
           echo "        format(user_error, \"BENCH kernel=$K mode=iter n=$N work_us=UNAVAILABLE work_ms=UNAVAILABLE engine=$ENGINE-has-no-wall-clock~n\", [])."; } ;;
    time)
      # ⛔ between/3 + cut, NOT a recursive counter. MEASURED hq_P 2026-09-13: the recursive form
      # (bench__until(D,I0,I) :- ... bench__until(D,I1,I)) builds one frame per iteration and gprolog
      # died at "global stack overflow (reached: 32765 Kb)" on nrev before the 1000 ms budget was spent --
      # the deadline arm was measuring how fast the engine could exhaust its own stack. between/3 is
      # constant space on all three engines and yields the iteration count for free, with no assert.
      # ⛔⭐ THE ANSWER IS PRINTED AND EVERY REPETITION IS HELD TO IT (CEO-1221, Lon: "The reason to force a benchmark to also be
      #   a test is to guarantee it is not vacuous."). The first solution is written once -- stdout is byte-comparable with
      #   <name>.ref, like single -- and each repetition's result must be == to it or the run throws bench__mismatch and
      #   fails, so a repetition that computed something else, or nothing, can never be counted. bench__one/1 commits to the
      #   first solution for the reason the iter arm records. == is sound here: every bench/*.ref is ground (measured, 23/23).
      echo "bench__one(Res) :- bench_work(Res), !."
      echo "bench__until(Deadline, R0, I) :- between(1, 1000000000, I), bench__one(R), ( R == R0 -> true ; throw(bench__mismatch(I, R)) ), wall_ms(M), M >= Deadline, !."
      echo "main :- bench__one(R0), write(R0), nl, wall_ms(M0), wall_us(T0), Deadline is M0 + $BUD,"
      echo "        ( bench__until(Deadline, R0, I) -> true ; I = exhausted ),"
      echo "        wall_us(T1), wall_ms(M1), W is T1 - T0, WM is M1 - M0,"
      echo "        format(user_error, \"BENCH kernel=$K mode=time bud_ms=$BUD iters=~w mismatched=0 work_us=~w work_ms=~w~n\", [I, W, WM])." ;;
  esac
} > "$OUT" || exit 2
echo "$OUT"
