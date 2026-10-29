#!/usr/bin/env bash
# test_gate_icn_byname_generator_region_is_not_on_the_arena.sh -- A BY-NAME ICON GENERATOR DELIVERS ITS
# SEQUENCE FROM ITS OWN COROUTINE STACK, IN BOTH MEDIA (SCRIP 0981d75df: "carve the by-name generator's
# region on its own coroutine stack, not the ZLS arena").
#
# ⛔ WHAT THIS GATE USED TO DO AND WHY IT HAD TO CHANGE (COO-80, 2026-09-19, row
# instrument-the-nineteen-non-gc-blocking-arms, CEO-944/949). It ran each witness with SCRIP_ZETA_TELEM=1,
# captured 2>&1 into one string, stripped the lines beginning `[ZLS]`, compared the remainder to "1 2 3" and
# RED if any `[ZLS]` line survived -- an activation served from the ZLS arena. TWO SEPARATE THINGS HAVE SINCE
# GONE WRONG WITH THAT, and it read RED for every seat with the compiler behaving perfectly:
#
#   (1) ⛔ THE ZLS ARM IS A RETIRED CRITERION, MEASURING A DELETED INSTRUMENT. SCRIP 74010795d (CEO-448/454,
#       Lon: "get rid of all that ZLS and ZETA #define's") DELETED the arena itself -- zeta_alloc.c gone, the
#       never-pushed zls2 arena and the collector's chain walk gone, every ZC_/ZLS_ name gone. NOTHING UNDER
#       src/ HAS PRINTED A `[ZLS]` LINE SINCE, so that count has been structurally 0 and the arm could not
#       have failed whatever the compiler did: a green over an empty measurement, which is the shape this
#       tree refuses everywhere else. The property it stood for did not go with it -- it became a SOURCE
#       property, held by test_gate_no_zeta_frame_switches.sh (zero ZC_/ZLS identifiers and no rt_zls store
#       symbol under src/). This gate does NOT restate that census; it REFUSES rc=2 if that holder is gone,
#       so the property cannot quietly lose both its keepers at once.
#
#   (2) THE OUTPUT ARM WAS A STALE FIXTURE. Folding stderr into stdout and stripping ONE known prefix means
#       any new stderr instrument reds the gate, and one arrived: SCRIP_ZETA_TELEM gained a second consumer
#       in rt_gcheap_report (gc_heap.c), whose `[ZHP] arena=512MB blocks=... verify=OK` line landed in the
#       compared body and made all four witnesses read `output [1 2 3 [ZHP] ...] != 1 2 3`. The witness was
#       correct in every one of those runs. ⭐ THE CURE IS THE STREAMS, NOT A SECOND PREFIX: the criterion is
#       about the PROGRAM'S STDOUT, so stdout is captured and graded on its own and stderr is kept beside it
#       for the failure report. A prefix filter would have to be extended by every future instrument; this
#       does not. SCRIP_ZETA_TELEM is no longer set here at all -- it was only ever on to make the retired
#       `[ZLS]` line appear, and it is what dragged `[ZHP]` in.
#
# WHAT IS LEFT IS A REAL BEHAVIOURAL WITNESS AND IT STILL EARNS ITS PLACE: byname is the cured path (p := gen;
# every x := p()), direct is the control that was always on the stack, each in mode 3 and mode 4, and a
# regression in the by-name region carve shows up as a wrong sequence, a crash or a hang in the byname pair
# while direct stays clean.
# rc 0 green · 1 red · 2 could not measure.
set -u
GATE=icn_byname_generator_region_is_not_on_the_arena
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
refuse() { echo "GATE REFUSE(2) [$GATE]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
. "$HERE/lib_gate.sh"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"

# ---- THE RETIREMENT IS HELD, NOT ASSUMED: the arena's absence is a SOURCE property now and it has exactly
# one keeper. If that keeper disappears this gate must not carry on reporting on a property nobody checks.
ZKEEP="$HERE/test_gate_no_zeta_frame_switches.sh"
[ -f "$ZKEEP" ] || refuse "test_gate_no_zeta_frame_switches.sh is gone -- it is the sole holder of the ZLS-arena-is-deleted property (SCRIP 74010795d, CEO-448/454) that this gate's retired arm used to watch at runtime, and with it absent that property has NO keeper; restore it or re-home the census before grading this witness"
grep -q 'rt_zls\|ZLS' "$ZKEEP" || refuse "test_gate_no_zeta_frame_switches.sh no longer mentions the ZLS/rt_zls names -- the source census this gate defers to has changed subject, so the arena-absence property is unheld; re-home it before grading this witness"

TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
cat > "$TD/byname.icn" <<'EOF'
procedure gen()
    suspend 1 | 2 | 3;
end
procedure main()
    local p, x;
    p := gen;
    every x := p() do write(x);
end
EOF
cat > "$TD/direct.icn" <<'EOF'
procedure gen()
    suspend 1 | 2 | 3;
end
procedure main()
    local x;
    every x := gen() do write(x);
end
EOF
GRADED=0; FAIL=0
for w in byname direct; do
  for m in 3 4; do
    if [ "$m" = 3 ]; then
      out="$(timeout -k 5 20s "$SCRIP" "$TD/$w.icn" </dev/null 2>"$TD/err.$w.$m")"; rc=$?
    else
      "$SCRIP" --compile --out="$TD/$w.s" "$TD/$w.icn" </dev/null >/dev/null 2>&1 || refuse "$w: mode-4 compile failed -- cannot measure"
      gcc -no-pie "$TD/$w.s" -o "$TD/$w.bin" -L "$ROOT/out" -lscrip_rt -lm >/dev/null 2>&1 || refuse "$w: mode-4 link failed -- cannot measure"
      out="$(LD_LIBRARY_PATH="$ROOT/out" timeout -k 5 20s "$TD/$w.bin" </dev/null 2>"$TD/err.$w.$m")"; rc=$?
    fi
    GRADED=$((GRADED+1))
    if [ "$rc" -ne 0 ]; then
      echo "  FAIL m$m $w: rc=$rc$([ "$rc" = 124 ] && echo ' (timeout fired at 20s -- a duration, not proof of a hang)')"
      [ -s "$TD/err.$w.$m" ] && sed -n '1,4p' "$TD/err.$w.$m" | sed 's/^/        stderr: /'
      FAIL=$((FAIL+1)); continue
    fi
    if [ "$(printf '%s' "$out" | tr -d ' \n')" != "123" ]; then
      echo "  FAIL m$m $w: stdout [$(printf '%s' "$out" | tr '\n' ' ')] != 1 2 3"
      [ -s "$TD/err.$w.$m" ] && sed -n '1,4p' "$TD/err.$w.$m" | sed 's/^/        stderr (not graded, shown for diagnosis): /'
      FAIL=$((FAIL+1)); continue
    fi
    echo "  PASS m$m $w: stdout is 1 2 3"
  done
done
[ "$GRADED" -eq 4 ] || refuse "graded $GRADED witnesses, wanted 4 (byname and direct, each in mode 3 and mode 4)"
echo "graded=$GRADED FAIL=$FAIL (byname=the cured by-name carve, direct=the control that was always on the stack; the ZLS runtime count is RETIRED -- the arena was deleted at SCRIP 74010795d and its absence is held by test_gate_no_zeta_frame_switches.sh)"
if [ "$FAIL" -ne 0 ]; then echo "GATE FAIL(1) [$GATE]: FAIL=$FAIL of $GRADED"; exit 1; fi
echo "GATE PASS(0) [$GATE]: $GRADED/$GRADED, the by-name generator delivers its sequence in both media"
exit 0
