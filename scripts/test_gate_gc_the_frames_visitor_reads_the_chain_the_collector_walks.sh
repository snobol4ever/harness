#!/usr/bin/env bash
# test_gate_gc_the_frames_visitor_reads_the_chain_the_collector_walks.sh
#
# WHAT THIS GATE HOLDS (hq_collector 2026-10-09, on the cto's ask for the assertz-reclaim row
# prolog-the-code-assertz-generates-is-reclaimed-once-nothing-can-reference-it-lon-2026-09-27, ORDER (1)):
# int rt_gc_frames_visit(fn, a) in gc_heap.c calls fn once per live emitted frame, with its map and base, over every
# stack segment -- the running one entered from C through the unwinder, each parked co-expression from its park rbp --
# by the ARCH-GC section 13.4 chain walk, and returns 0 WITHOUT calling fn when any segment's chain stops short of ROOT
# (the running main stack) or of its own top (a co-expression), so a caller deciding liveness never reads a partial
# list. First cut: no choice links.
#
# THE INSTRUMENT: under SCRIP_GC_CHAIN_CHECK=3 every collection calls the visitor before it walks and compares the
# visitor's frame count and an order-sensitive sum of (base ^ map) with the frames the collector's own chain walk
# finds in the same collection; the [CHAIN-WALK] SUMMARY line carries "visitor: same= differ= refused=".
#
# ARMS: (1) per witness, mode 3 and mode 4: the summary is printed, same > 0, differ = 0, and refused is no larger
# than the collector's own short stops (nosite + frameless + unknown-depth + cycle + no-link + no-rise), i.e. the
# visitor refuses only where the collector's chain itself stopped short; (2) THE REFUSAL: on the SIG-shim witness, whose
# run-time fragment polls are frameless today, every collection with a frameless running chain is refused, never
# handed back as a shorter list (when the fragment class lands and frameless reads 0 the arm says there was nothing to
# refuse); (3) the visitor and its callback type are declared once, in gc_heap.h; (4) THE COROUTINE START (the ceo's
# order of 2026-10-09: rt_genp_spine_enter_n2 is the sanctioned coroutine start of a generator's co-expression thread, so
# the collector names it): on hb_coexpr_genp_scan every suspended body's chain that links to the stub's gamma or omega
# label (published in rt_genp_n2_conts, a read-only record, so no text symbol splits the stub) ends there as the segment's start, so nosite reads 0, coroutine-start > 0 and the visitor refuses nothing.
# (5) THE BALL IN CATCH (the cto's controls, 2026-10-09): a goal meta-called by catch through bb_call_value.cpp's
# pl_proto arm whose is/2 or unify cold road raises a ball polls inside the goal; the arm's gamma landing was no site, so
# the chain stopped there (nosite 6 of 53 and 30 of 221, both modes, predating the occurs-check landing). The landing is
# a site since this arm; both witnesses read whole and the visitor refuses nothing.
# Measured at landing over all 107 gc_witnesses, both modes, 64 KB, stress 1: same=733261 differ=0 refused=28 (the 28
# are hb_coexpr_genp_scan 13, hb_shim_rt_names 14, hb_cv_spine_plain_redo 1 -- the open nosite/frameless classes).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
"$ROOT/../harness/scripts/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
SCRIP="$ROOT/scrip"
G="test_gate_gc_the_frames_visitor_reads_the_chain_the_collector_walks"
refuse() { echo "⛔ GATE REFUSED(2) [$G]: $1"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- build before grading"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no runtime library at $ROOT/out/libscrip_rt.so -- build before grading"
WD="$ROOT/../harness/scripts/gc_witnesses"
WIT="hb_arr.sno hb_wsb_eval_define.sno hb_coexpr_create.icn hb_coexpr_parked.icn hb_pl_findall.pl hb_wsb_raku_sprintf_multi.raku hb_concat_slot_capture_across_a_collection.sc"
REF="hb_shim_rt_names_past_the_hidden_island_slots.sno"
for w in $WIT $REF; do [ -f "$WD/$w" ] || refuse "witness $WD/$w is missing"; done
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
run_env() { env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB SCRIP_HEAP_KB=64 SCRIP_GC_CHAIN_CHECK=3 SCRIP_GC_STRESS=1 "$@"; }
num() { printf '%s\n' "$1" | sed -n "s/.* $2=\([0-9]*\).*/\1/p"; }
run_both() {
  local w="$1" b="${1%.*}"
  ( cd "$W" && run_env timeout -k 5 300 "$SCRIP" "$WD/$w" > "$b.o3" 2> "$b.e3" < /dev/null )
  ( cd "$W" && timeout -k 5 300 "$SCRIP" --compile -o "$b.s" "$WD/$w" > /dev/null 2> "$b.c4" < /dev/null ) || refuse "mode 4 could not compile $w: $(head -c 200 "$W/$b.c4")"
  gcc "$W/$b.s" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$W/$b.x" 2> "$W/$b.ld4" || refuse "mode 4 link failed for $w: $(head -c 200 "$W/$b.ld4")"
  ( cd "$W" && run_env timeout -k 5 300 "./$b.x" > "$b.o4" 2> "$b.e4" < /dev/null )
}
for w in $WIT; do
  run_both "$w"
  for m in 3 4; do
    s="$(grep -a '^\[CHAIN-WALK\] SUMMARY ' "$W/${w%.*}.e$m" | tail -1)"
    [ -n "$s" ] || { ck no "(1) $w mode $m: no [CHAIN-WALK] SUMMARY line -- the level-3 check did not run, nothing was measured"; continue; }
    sa="$(num "$s" same)"; di="$(num "$s" differ)"; rf="$(num "$s" refused)"
    short=$(( $(num "$s" nosite) + $(num "$s" frameless) + $(num "$s" unknown-depth) + $(num "$s" cycle) + $(num "$s" no-link) + $(num "$s" no-rise) ))
    if [ -n "$sa" ] && [ "$sa" -gt 0 ] && [ "$di" = 0 ] && [ "${rf:-x}" -le "$short" ] 2>/dev/null; then
      ck ok "(1) $w mode $m: visitor same=$sa differ=0 refused=$rf (collector short stops $short)"
    else
      ck no "(1) $w mode $m: visitor same=${sa:-?} differ=${di:-?} refused=${rf:-?} against $short short stop(s) -- rt_gc_frames_visit does not hand back the frames the collector's chain finds"
    fi
  done
done
run_both "$REF"
for m in 3 4; do
  s="$(grep -a '^\[CHAIN-WALK\] SUMMARY ' "$W/${REF%.*}.e$m" | tail -1)"
  [ -n "$s" ] || { ck no "(2) $REF mode $m: no [CHAIN-WALK] SUMMARY line"; continue; }
  fl="$(num "$s" frameless)"; rf="$(num "$s" refused)"; di="$(num "$s" differ)"
  if [ "${fl:-0}" = 0 ] && [ "$di" = 0 ]; then ck ok "(2) $REF mode $m: frameless=0, nothing to refuse (the run-time fragment class is cured), differ=0"
  elif [ "${rf:-0}" -ge "$fl" ] && [ "$di" = 0 ]; then ck ok "(2) $REF mode $m: $fl frameless running chain(s), the visitor refused $rf collection(s) and handed back no partial list (differ=0)"
  else ck no "(2) $REF mode $m: frameless=$fl refused=${rf:-?} differ=${di:-?} -- a chain that stops short was handed to the caller as a list"; fi
done
GEN="hb_coexpr_genp_scan.icn"
[ -f "$WD/$GEN" ] || refuse "witness $WD/$GEN is missing"
run_both "$GEN"
for m in 3 4; do
  s="$(grep -a '^\[CHAIN-WALK\] SUMMARY ' "$W/${GEN%.*}.e$m" | tail -1)"
  [ -n "$s" ] || { ck no "(4) $GEN mode $m: no [CHAIN-WALK] SUMMARY line"; continue; }
  ns="$(num "$s" nosite)"; cs="$(num "$s" coroutine-start)"; rf="$(num "$s" refused)"; di="$(num "$s" differ)"
  if [ "$ns" = 0 ] && [ "${cs:-0}" -gt 0 ] && [ "$rf" = 0 ] && [ "$di" = 0 ]; then ck ok "(4) $GEN mode $m: $cs suspended-generator chain(s) end at the named coroutine start (the gamma and omega words of rt_genp_n2_conts), nosite=0, the visitor refused 0"
  else ck no "(4) $GEN mode $m: nosite=${ns:-?} coroutine-start=${cs:-?} refused=${rf:-?} differ=${di:-?} -- a generator segment's chain no longer ends at its coroutine start"; fi
done
printf '%s\n' ':- initialization(main).' 't(N, G) :- ( catch(G, error(_, _), (write(N-raised), nl, fail)) -> write(N-yes) ; write(N-no) ), nl.' \
  'loop(0) :- !.' 'loop(K) :- t(1, _ is 1 / 0), t(2, _ is foo + 1), t(3, _ is 2 + 3), K1 is K - 1, loop(K1).' 'main :- loop(3), halt.' > "$W/ballcatch.pl"
for wpl in "$W/ballcatch.pl" "$WD/hb_pl_occurs_check_error_raises_on_the_asm_unify_road.pl"; do
  [ -f "$wpl" ] || refuse "witness $wpl is missing"
  bn="$(basename "$wpl" .pl)"
  ( cd "$W" && run_env timeout -k 5 300 "$SCRIP" "$wpl" > "$bn.o3" 2> "$bn.e3" < /dev/null )
  ( cd "$W" && timeout -k 5 300 "$SCRIP" --compile -o "$bn.s" "$wpl" > /dev/null 2> "$bn.c4" < /dev/null ) || refuse "mode 4 could not compile $wpl"
  gcc "$W/$bn.s" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$W/$bn.x" 2> "$W/$bn.ld4" || refuse "mode 4 link failed for $wpl"
  ( cd "$W" && run_env timeout -k 5 300 "./$bn.x" > "$bn.o4" 2> "$bn.e4" < /dev/null )
  for m in 3 4; do
    s="$(grep -a '^\[CHAIN-WALK\] SUMMARY ' "$W/$bn.e$m" | tail -1)"
    ru="$(num "$s" runs)"; wh="$(num "$s" whole)"; ns="$(num "$s" nosite)"; rf="$(num "$s" refused)"; di="$(num "$s" differ)"
    if [ -n "$s" ] && [ "${ru:-0}" -gt 0 ] && [ "$wh" = "$ru" ] && [ "$ns" = 0 ] && [ "$rf" = 0 ] && [ "$di" = 0 ]; then
      ck ok "(5) $bn mode $m: a ball raised inside catch's meta-called goal leaves the chain whole ($wh of $ru), nosite=0, the visitor refused 0"
    else
      ck no "(5) $bn mode $m: whole=${wh:-?} of ${ru:-?} nosite=${ns:-?} refused=${rf:-?} differ=${di:-?} -- the pl_proto goal arm's gamma landing is not a site, so a poll inside the goal cannot climb back into its caller"
    fi
  done
done
hd="$(grep -cE '^(int rt_gc_frames_visit\(rt_gc_frame_fn fn, void \*a\);|typedef void \(\*rt_gc_frame_fn\)\(const void \*map, const char \*base, void \*a\);)$' "$ROOT/src/runtime/rt/gc_heap.h")"
el="$(grep -rlE 'int rt_gc_frames_visit[[:space:]]*\(|rt_gc_frame_fn\)[[:space:]]*\(' "$ROOT/src" | grep -vE '/src/runtime/rt/gc_heap\.(c|h)$' | sed "s#^$ROOT/##" | tr '\n' ' ')"
if [ "$hd" = 2 ] && [ -z "$el" ]; then ck ok "(3) rt_gc_frames_visit and rt_gc_frame_fn are declared once, in gc_heap.h"
else ck no "(3) gc_heap.h carries $hd of the 2 declarations; other declarations in: ${el:-none}"; fi
echo "population: $checks arm(s) graded, $fails FAIL"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$G]"; exit 0; fi
echo "⛔ GATE RED [$G]: $fails of $checks arms FAIL"; exit 1
