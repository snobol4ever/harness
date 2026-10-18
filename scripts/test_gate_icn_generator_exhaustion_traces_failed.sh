#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the instrumentation switch (--stlimit): Icon &trace rides the call/return hooks that are off by default since SCRIP 2026-09-24 (Lon: monitor hooks behind the switch)
# test_gate_icn_generator_exhaustion_traces_failed.sh -- a traced generator that EXHAUSTS prints "NAME failed".
#
# WHY THIS EXISTS (CEO-459): under &trace, iconx prints five lines for a generator -- call, suspended,
# resumed, failed, and the caller's own failure. SCRIP printed TWO: the generator's exhaustion emitted no
# trace event at all, because the N-2 generator RETIRE branch had no tap. This gate covers the retire tap.
#
# ⛔ IT ASSERTS PRESENCE, NOT THE WHOLE LINE SET, AND THAT IS DELIBERATE. `suspended` and `resumed` are
# still missing and are owed (they need the yielded value at a zeta-addressed slot, and a CALLER-side tap,
# both frame work held under CEO-447). A gate that pinned "exactly these three lines" would go RED the day
# those two land -- it would freeze the incomplete state into a criterion and make finishing the feature
# look like a regression. So each arm asserts that a specific correct line IS produced, with its exact
# line number, bar depth and text cut from iconx, and says nothing about lines not yet emitted.
#
# ⛔ &trace WRITES ONLY TO stderr, and lib_ladder.sh runs with 2>/dev/null -- which is why the ladder rung
# for this family is red only through an exit code and would go green on a crash fix alone (hq_B). This
# gate captures stderr explicitly for exactly that reason.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
NAME=icn_generator_exhaustion_traces_failed
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
cat > "$TD/gen.icn" <<'EOF'
procedure main();
    &trace := -1;
    every write(g());
end
procedure g();
    suspend 1;
end
EOF
cat > "$TD/nongen.icn" <<'EOF'
procedure main();
    &trace := -1;
    write(h());
end
procedure h();
    return 1;
end
EOF
GRADED=0; FAIL=0
want() { # $1 witness, $2 mode, $3 human label, $4 exact trailing text the line must end with
  GRADED=$((GRADED+1))
  if printf '%s\n' "$5" | grep -qF -- "$4"; then echo "  PASS m$2 $1: $3"
  else echo "  FAIL m$2 $1: $3 -- no line ending [$4] in [$(printf '%s' "$5" | tr '\n' '/' | cut -c1-90)]"; FAIL=$((FAIL+1)); fi
}
for w in gen nongen; do
  for m in 3 4; do
    if [ "$m" = 3 ]; then err="$(timeout -k 5 20s "$SCRIP" "$TD/$w.icn" </dev/null 2>&1 >/dev/null)"
    else
      "$SCRIP" --compile -o "$TD/$w.s" "$TD/$w.icn" </dev/null >/dev/null 2>&1 || refuse "$w: mode-4 compile failed -- cannot measure"
      gcc -no-pie "$TD/$w.s" -o "$TD/$w.bin" -L "$ROOT/out" -Wl,-rpath,"$ROOT/out" -lscrip_rt -lm -lpthread >/dev/null 2>&1 || refuse "$w: mode-4 link failed -- cannot measure"
      err="$(timeout -k 5 20s "$TD/$w.bin" </dev/null 2>&1 >/dev/null)"
    fi
    [ -n "$err" ] || refuse "$w m$m: &trace produced NO stderr at all -- tracing is not running, so this gate measured nothing"
    if [ "$w" = gen ]; then
      want "$w" "$m" "generator exhaustion traces failed"   ":    7  | g failed"    "$err"
      want "$w" "$m" "the call line is unchanged"           ":    3  | g()"         "$err"
      want "$w" "$m" "the caller's own failure is unchanged" ":    4  main failed"  "$err"
    else
      want "$w" "$m" "a NON-generator still returns, not fails" ":    6  | h returned 1" "$err"
      want "$w" "$m" "the NON-generator trace is byte-identical to iconx" ":    3  | h()" "$err"
    fi
  done
done
[ "$GRADED" -eq 0 ] && refuse "graded zero assertions"
echo "graded=$GRADED FAIL=$FAIL (every expected line cut from icont+iconx; the nongen arm is the control that the retire tap did not fire on an ordinary procedure, and the call/main-failed arms are the two lines that were ALREADY correct, so the gate is not red-by-default)"
if [ "$FAIL" -ne 0 ]; then echo "GATE FAIL(1) [$NAME]: FAIL=$FAIL of $GRADED"; exit 1; fi
echo "GATE PASS(0) [$NAME]: $GRADED/$GRADED"
exit 0
