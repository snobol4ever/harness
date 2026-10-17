#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_out_sweep_flaky.sh — NEGATIVE TEST for util_out_sweep.sh face (c), the intermittent-crash false mover.
#   bash ../harness/scripts/test_gate_out_sweep_flaky.sh          (no args; ~10s; needs ./scrip built)
# ⛔ WHY BY INJECTION AND NOT BY THE LIVE WITNESS.  The natural witness is `141_pat_eval_double_fn_arbno` (seat1
# s170: m3 rc=0 serially, intermittent load-dependent rc=139 under a parallel sweep).  Measured s185 at SCRIP
# ffbc1425 on 16 cpus it is DORMANT — 14 full sweeps (8 sequential + 6 concurrent, 8162 rows) and 648 direct runs
# at up to 32-way parallelism produced ZERO instances.  A defence validated by a flake that only sometimes appears
# is a defence validated sometimes, so the flakiness is INJECTED here: an arm wrapper stands in for $SCRIP and
# alternates 141 between rc=139 and the real run on a shared counter.  The alternation is COUNTER-DRIVEN, never
# random — a nondeterministic gate for a nondeterminism defence would be the same mistake one level up.
# ⭐ THE INJECTION IS NOT MERELY THE SAME SHAPE, IT IS THE SAME TWO VALUES: seat1's s170 FINDING §7b records 141
# flipping `RUN_RC_139` ↔ md5 `027851e5…`, and that is exactly the pair this gate's assertion 1 prints.  The real
# run supplies the md5 (only the crash face is faked), so the reproduction stays anchored to the live compiler.
# THE THREE ASSERTIONS (all three must hold, and 3 is the one that keeps the cure from becoming a blindfold):
#   1 REPRODUCED  — at REPS=1 the false mover appears, in BOTH directions (crash→md5 and md5→crash), from ONE arm
#                   compared against ITSELF.  This is the s170 instrument gap, on demand.
#   2 CAUGHT      — at REPS=3 both arms label it RUN_FLAKY, the diff is EMPTY, and both `.flaky` sidecars name it.
#   3 NOT BLINDED — a program the injected arm STABLY changes still reads as a mover at REPS=3, and a genuinely
#                   stable program still reads as no-mover.  RUN_FLAKY suppresses the coin flip, not the signal.
#   4 PIN         — a pinned flake prints `pinned`, a pin whose program came back stable prints `stale pin`.  The
#                   pin file is REPORTING ONLY; assertion 3 is what proves it never becomes an exclusion list.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; SC="$(cd "$HERE/../../SCRIP" && pwd)"
REAL="${SCRIP:-$SC/scrip}"; CORPUS="${CORPUS:-$S4E/corpus}"; SWEEP="${SWEEP:-$HERE/util_out_sweep.sh}"   # overridable so the gate can be pointed at a DEFENCE-REMOVED copy and proven to go RED (see the meta-test in the FINDING)
[ -x "$REAL" ] || { echo "GATE RED: no scrip binary at $REAL (make -j4 scrip)"; exit 1; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# ⛔ crosscheck/patterns/ is GONE -- converted into the tests/snobol4/ALL.{sno,ref,csv} rungs
# (corpus da0987478 lineage). Extract by ORIGIN (never re-point at a surviving directory -- that
# would grade a different population and look green either way, hq_P's FINDING-2026-08-30 on this
# exact class). Origins confirmed against ALL.csv's own family/origin columns before use.
RUNGS_LANG="${RUNGS_LANG:-snobol4}" source "$HERE/lib_rungs_extract.sh" || { echo "GATE RED: could not load lib_rungs_extract.sh"; exit 1; }
FLAKY="$W/141_pat_eval_double_fn_arbno.sno"; MOVED="$W/140_pat_eval_double_fn_trick.sno"; STABLE="$W/038_pat_literal.sno"
rungs_extract_origin crosscheck_patterns__141_pat_eval_double_fn_arbno "$FLAKY" || { echo "GATE RED: could not extract 141_pat_eval_double_fn_arbno from the rungs"; exit 1; }
rungs_extract_origin crosscheck_patterns__140_pat_eval_double_fn_trick "$MOVED" || { echo "GATE RED: could not extract 140_pat_eval_double_fn_trick from the rungs"; exit 1; }
rungs_extract_origin crosscheck_patterns__038_pat_literal "$STABLE" || { echo "GATE RED: could not extract 038_pat_literal from the rungs"; exit 1; }
printf '%s\n%s\n%s\n' "$FLAKY" "$MOVED" "$STABLE" | sort > "$W/list"
cat > "$W/arm" <<'ARMEOF'
#!/usr/bin/env bash
p="${!#}"; n="$(cat "$FLAKY_CTR" 2>/dev/null || echo 0)"
if [ "$p" = "$FLAKY_PROG" ]; then echo $((n + 1)) > "$FLAKY_CTR"
  [ $((n % 2)) -eq 0 ] && { printf 'INJECTED partial stdout before the crash\n'; exit 139; }; fi
[ "$p" = "${MOVED_PROG:-}" ] && { printf 'INJECTED stable different answer\n'; exit 0; }
exec "$REAL_SCRIP" "$@"
ARMEOF
chmod +x "$W/arm"; export REAL_SCRIP="$REAL" FLAKY_PROG="$FLAKY" FLAKY_CTR="$W/ctr"
PINF="$W/nopins"   # ⛔ HERMETIC: the gate must never read the CHECKED-IN ../harness/scripts/util_out_sweep.pins, or a future real pin flips assertion 2 red
armA() { MOVED_PROG="" REPS="$1" SWEEP_PIN="$PINF" SCRIP="$W/arm" bash "$SWEEP" "$2" "$W/list" >/dev/null 2>"$2.err"; }
armB() { MOVED_PROG="$MOVED" REPS="$1" SWEEP_PIN="$PINF" SCRIP="$W/arm" bash "$SWEEP" "$2" "$W/list" >/dev/null 2>"$2.err"; }
val() { grep -F "	$2" "$1" | cut -f1; }
fail=0; say() { echo "  $*"; }
echo 0 > "$W/ctr"; armA 1 "$W/d1A"; armB 1 "$W/d1B"
a1="$(val "$W/d1A" "$FLAKY")"; b1="$(val "$W/d1B" "$FLAKY")"
echo 1 > "$W/ctr"; armA 1 "$W/d2A"; armB 1 "$W/d2B"
a2="$(val "$W/d2A" "$FLAKY")"; b2="$(val "$W/d2B" "$FLAKY")"
say "1 REPRODUCED  dir1 A=$a1 B=$b1 | dir2 A=$a2 B=$b2"
[ "$a1" = "RUN_RC_139" ] && [ "$b1" != "RUN_RC_139" ] && [ "$b1" != "RUN_FLAKY" ] || { echo "  ⛔ RED: REPS=1 did not manufacture the crash→md5 false mover"; fail=1; }
[ "$a2" != "RUN_RC_139" ] && [ "$a2" != "RUN_FLAKY" ] && [ "$b2" = "RUN_RC_139" ] || { echo "  ⛔ RED: REPS=1 did not manufacture the md5→crash false mover"; fail=1; }
grep -q 'DISARMED' "$W/d1A.err" || { echo "  ⛔ RED: REPS=1 did not warn that the defence is disarmed"; fail=1; }
echo 0 > "$W/ctr"; armA 3 "$W/rA"; armB 3 "$W/rB"
fa="$(val "$W/rA" "$FLAKY")"; fb="$(val "$W/rB" "$FLAKY")"
say "2 CAUGHT      A=$fa B=$fb  diff-rows=$(diff "$W/rA" "$W/rB" | grep -c '^[<>]')"
[ "$fa" = "RUN_FLAKY" ] && [ "$fb" = "RUN_FLAKY" ] || { echo "  ⛔ RED: REPS=3 did not label the intermittent program RUN_FLAKY in both arms"; fail=1; }
diff "$W/rA" "$W/rB" | grep -q "^[<>].*$FLAKY" && { echo "  ⛔ RED: the flaky program still reads as a mover at REPS=3"; fail=1; }
grep -qF "$FLAKY" "$W/rA.flaky" && grep -qF "$FLAKY" "$W/rB.flaky" || { echo "  ⛔ RED: the .flaky sidecar does not name the flaky program in both arms"; fail=1; }
grep -q 'NEW' "$W/rB.err" || { echo "  ⛔ RED: a new flake was not reported on stderr"; fail=1; }
ma="$(val "$W/rA" "$MOVED")"; mb="$(val "$W/rB" "$MOVED")"; sa="$(val "$W/rA" "$STABLE")"; sb="$(val "$W/rB" "$STABLE")"
say "3 NOT BLINDED moved A=$ma B=$mb | stable A=$sa B=$sb"
[ -n "$ma" ] && [ "$ma" != "$mb" ] && [ "$ma" != "RUN_FLAKY" ] && [ "$mb" != "RUN_FLAKY" ] || { echo "  ⛔ RED: a REAL mover was swallowed by the flaky defence"; fail=1; }
[ -n "$sa" ] && [ "$sa" = "$sb" ] || { echo "  ⛔ RED: a stable program did not compare equal across the two arms"; fail=1; }
printf '%s\n%s\n' "$FLAKY" "$STABLE" > "$W/pins"; PINF="$W/pins"; echo 0 > "$W/ctr"; armA 3 "$W/pA"
say "4 PIN         $(grep -c 'pinned\|stale pin' "$W/pA.err") pin line(s) reported"
grep -qF "pinned $FLAKY" "$W/pA.err" || { echo "  ⛔ RED: a PINNED flake did not print as pinned (the pin file is not being read)"; fail=1; }
grep -q "stale pin.*$STABLE" "$W/pA.err" || { echo "  ⛔ RED: a STALE pin (pinned but stable across all reps) was not reported"; fail=1; }
[ "$fail" -eq 0 ] && { echo "GATE GREEN — false mover reproduced at REPS=1 in both directions, caught at REPS=3, real mover still visible"; exit 0; }
echo "GATE RED"; exit 1
