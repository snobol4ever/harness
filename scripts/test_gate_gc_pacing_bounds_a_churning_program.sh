#!/usr/bin/env bash
# test_gate_gc_pacing_bounds_a_churning_program.sh -- storage regeneration is PACED, not exhaustion-only (GC-7, ceo CEO-639).
#
# MEASURED 2026-09-12 on f8421f4bd: `every 1 to 3000000 do image("ab\tcd")` reached 564 MB RSS in both modes -- the first
# regeneration fired only when the 512 MB arena was exhausted (the seam-side line sat at half the arena and the assembly
# fast path carved inline against the arena END, never seeing any line), so a program with a few KB of live data touched
# every page of the arena and CEO-605's micro.icn aborted on the pinned-allocation ceiling. Cure: the collection line sits
# min(128 MB, half of what remains) past the top (SCRIP_GC_LINE_MB, default 128 -- 64 cost ~60% wall on the churniest Icon
# benchmark, 128 reads at parity with the old policy; 0 = the old half-of-arena seam policy; since CEO-1264 the room is fifteen
# sixteenths of what remains, SPITBOL's spend-the-window rule, so 0 now puts the line at 15/16 of the window and the 128 MB bound is
# what arm 1 still grades at this 512 MB window), the
# fast region carries that line at offset 48 and rtx_alloc.s carves inline only up to it, and c_rt_gcheap_alloc collects
# at the line through the same conservative path exhaustion already used. Arms: (1) the churning witness stays under
# 256 MB RSS (the row's own bound) in mode 3 and mode 4 and prints ok; (2) CONTROL: SCRIP_GC_LINE_MB=0 reproduces the old behaviour, RSS above
# 400 MB -- the control arm proves the pacing is what bounds the RSS and that the seam still selects the old policy.
# FAIL_ONCE=1 plants the control arm's RSS into arm 1 to prove the bound trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
# ⛔⭐ THIS GATE NAMES ITS OWN ARENA, AND THAT IS THE RULE, NOT AN EXEMPTION (Lon 2026-09-19, ceo CEO-938; RULES.md
# § THE INSTRUMENT LAWS, TWENTY-EIGHTH BATCH CLAUSE 2).  The tiny arena is the default of all GC testing and the Makefile
# exports SCRIP_HEAP_MB=1 to every gate run through make -- but THIS gate measures an arena-dependent quantity: the
# pacing line is min(SCRIP_GC_LINE_MB, half of what remains) past the top and both arms grade RSS against a 256 MB bound
# calibrated at the shipped 512 MB window.  At a 1 MB window the program collects every megabyte, RSS never approaches
# the bound, the control arm stops discriminating and the gate reads FAIL for a reason that is not the thing it tests
# (measured: FAIL under an inherited SCRIP_HEAP_MB=1, PASS at 512).  So it pins the arena it was calibrated at, in the
# open, where a reader sees it.  A gate that measures an arena-dependent quantity does the same; one that does not must
# NOT pin, because inheriting the tiny arena is how the fleet finds collector defects in every other gate.
export SCRIP_HEAP_MB=512
unset SCRIP_HEAP_KB   # ⛔ THE PIN HOLDS ONLY WITH THIS LINE (cfo 2026-09-26, row gc-four-collector-gates-...): rt_gcheap_init reads SCRIP_HEAP_MB and THEN SCRIP_HEAP_KB, which overwrites the window, so the test-arena export SCRIP_HEAP_KB=128 silently beat the export above
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
command -v /usr/bin/time >/dev/null || { echo "⛔ REFUSE(2): /usr/bin/time is the RSS instrument and it is absent"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
printf 'procedure main()\n   every 1 to 3000000 do image("ab\\tcd");\n   write("ok");\nend\n' > "$T/churn.icn"
rss_of() { grep -o 'RSS=[0-9]*' "$1" | tail -1 | cut -d= -f2; }
RC=0; examined=0
( cd "$T" && /usr/bin/time -f 'RSS=%M' timeout -k 5 120 "$SCRIP" churn.icn ) >"$T/m3.out" 2>"$T/m3.err"; r3=$(rss_of "$T/m3.err")
( cd "$T" && timeout -k 5 30 "$SCRIP" --compile -o churn.s churn.icn </dev/null && gcc churn.s -o churn.bin -L"$ROOT/out" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ REFUSE(2): mode-4 witness did not build"; exit 2; }
( cd "$T" && LD_LIBRARY_PATH="$ROOT/out" /usr/bin/time -f 'RSS=%M' timeout -k 5 120 ./churn.bin ) >"$T/m4.out" 2>"$T/m4.err"; r4=$(rss_of "$T/m4.err")
( cd "$T" && SCRIP_GC_LINE_MB=0 /usr/bin/time -f 'RSS=%M' timeout -k 5 120 "$SCRIP" churn.icn ) >"$T/c.out" 2>"$T/c.err"; rc_=$(rss_of "$T/c.err")
[ -n "${FAIL_ONCE:-}" ] && r3="$rc_"
for M in m3 m4; do
  examined=$((examined+1)); v=$([ "$M" = m3 ] && echo "$r3" || echo "$r4"); out=$(head -1 "$T/$M.out")
  if [ "$out" = ok ] && [ -n "$v" ] && [ "$v" -lt 262144 ]; then echo "  $M PASS (ok, RSS ${v} KB under 256 MB with 3M dead image results)"
  else echo "  $M FAIL (out=[$out] RSS=[${v:-?}] KB, bound 262144)"; RC=1; fi
done
examined=$((examined+1))
# ⛔ THE CONTROL ARM ASSERTS A RATIO, NOT AN ABSOLUTE RSS (ceo CEO-885, 2026-09-18). It read -gt 409600 -- above 400 MB -- and went RED ON ORIGIN FOR EVERY SEAT the day the
# collector got BETTER: the cfo took HB_ARR and HB_DINST out of the conservative sniff (F6 step 5, SCRIP 48d5a1a5e), a precise visit frees what a conservative sniff retained,
# and the exhaustion-only control fell from above 400 MB to 290 MB. THE SEAM IS INTACT AND THAT WAS MEASURED, NOT ASSUMED: gc_line_paced() is false at LINE_MB=0 so the line
# goes to g_hp_end, and the witness still collects 3 times by exhaustion against 7 when paced. What died was the THRESHOLD, which was a property of how much the sniff LEAKED.
# An absolute number anchored on a measured artifact dies the day someone cures the artifact (CEO-554), and this one took every seat down with it.
# The property the arm exists to prove is PACING IS WHAT BOUNDS THE RSS, and that is a RATIO. Measured at this landing: paced 150936 KB, control 289712 KB = 192%.
# Bar: 150% of the paced arm AND above 200 MB -- so a collector that improves BOTH arms still discriminates, and a control that collapses onto the paced arm still reds.
# Both numbers and the ratio are PRINTED, never collapsed to a verdict.
ctl_min=$(( ${r3:-0} * 3 / 2 ))
if [ "$(head -1 "$T/c.out")" = ok ] && [ -n "$rc_" ] && [ -n "$r3" ] && [ "$rc_" -gt 204800 ] && [ "$rc_" -gt "$ctl_min" ]; then echo "  control PASS (SCRIP_GC_LINE_MB=0 selects the exhaustion-only policy: control ${rc_} KB against paced ${r3} KB = $(( rc_ * 100 / r3 ))%, bar 150% and 200 MB)"
else echo "  control FAIL (control RSS=[${rc_:-?}] KB against paced [${r3:-?}] KB -- bar is 150% of the paced arm AND above 200 MB; below it the seam no longer selects the old policy and the paced arms prove nothing)"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$(basename "${BASH_SOURCE[0]}" .sh)]: regeneration is paced at the 128 MB line in both modes and the seam still selects the old policy (examined $examined arms)"
else echo "GATE FAIL(1) [$(basename "${BASH_SOURCE[0]}" .sh)]: pacing does not bound a churning program, or the control arm no longer discriminates (examined $examined arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
