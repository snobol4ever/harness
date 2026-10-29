#!/usr/bin/env bash
# test_gate_gc_the_chain_hops_a_function_body_nested_in_a_match_in_the_mapped_main_block.sh
#
# WHAT THIS GATE HOLDS (hq_collector 2026-10-11, row gc-the-chain-visits-a-frame-entered-through-the-c2bb-glue-from-a-deferred-call-inside-a-match-the-glue-subject-cell-is-walked-ceo-1688,
# measured on SnoRungs demo_porter): a SNOBOL4 function body is emitted inline in the program's main block, so its sites belong to the MAPPED main graph. A poll inside a pattern match
# nested in such a body (the body's own statement frame, `stem P`, `token p`) is a rule 6 site with enclosing kind 0: the enclosing frame is fp + 8 + depth, and the word there is the define
# shim's exit label (the body is a frameless activation) or a caller's landing. The map-less case hopped through that word since 7abc44233; the mapped case took the sum as main's frame, 0x98
# bytes below the real one, so the chain named main at a base the marker scan did not find (kind 258/257 rule 6 depth 32, `MISMATCH`) and the walk list read `missing`. The hop now runs for a
# mapped block too, continuing with the saved rbp the anchor holds.
#
# THE WITNESS: gc_witnesses/hb_sno_a_poll_inside_a_match_nested_in_a_function_body_called_from_a_deferred_pattern_call_is_found_by_the_chain.sno, five words through the Porter step 1b stage
# of demo_porter (a stemmer function whose pattern p1b calls *g_vis() and *g_m_gt_0() deferred, the c2bb glue enters them, and their bodies run `stem P`, `last ANY(...)` and nested calls).
# Its ref is cut from the SPITBOL oracle. At the commit before the cure it reads 44 MISMATCH and `missing` 19 (mode 3) and 17 (mode 4) at 64 KB stress 1, arms (3) and (4) red; with the cure 0 and 0, 2 s.
#
# ARMS, per mode (3 and 4): (1) the output equals the oracle's ref; (2) SCRIP_GC_CHAIN_CHECK=3 prints both summaries; (3) `[CHAIN-CHECK] SUMMARY` reads mismatch=0 with ok > 0 and fnhops > 0
# (the function hop ran); (4) `[CHAIN-WALK] SUMMARY` reads missing=0, nosite=0, frameless=0 (every marker frame the chain list lacks is a PTR_GC blob the cto's poison falsifier calls dead, the
# class `extra-blob-ptrgc` this gate does not grade).
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
"$ROOT/../harness/scripts/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
SCRIP="$ROOT/scrip"
G="test_gate_gc_the_chain_hops_a_function_body_nested_in_a_match_in_the_mapped_main_block"
refuse() { echo "⛔ GATE REFUSED(2) [$G]: $1"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- build before grading"
[ -f "$ROOT/out/libscrip_rt.so" ] || refuse "no runtime library at $ROOT/out/libscrip_rt.so -- build before grading"
WD="$ROOT/../harness/scripts/gc_witnesses"
N="hb_sno_a_poll_inside_a_match_nested_in_a_function_body_called_from_a_deferred_pattern_call_is_found_by_the_chain"
for e in sno in ref; do [ -f "$WD/$N.$e" ] || refuse "witness file $WD/$N.$e is missing"; done
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
run_env() { env -u SCRIP_HEAP_MB -u SCRIP_HEAP_CAP_KB -u SCRIP_HEAP_MAX_MB SCRIP_HEAP_KB=64 SCRIP_GC_CHAIN_CHECK=3 SCRIP_GC_STRESS=1 "$@"; }
num() { printf '%s\n' "$1" | sed -n "s/.* $2=\([0-9]*\).*/\1/p"; }
( cd "$W" && run_env timeout -k 5 300 "$SCRIP" "$WD/$N.sno" > o3 2> e3 < "$WD/$N.in" )
( cd "$W" && timeout -k 5 300 "$SCRIP" --compile --out=w.s "$WD/$N.sno" > /dev/null 2> c4 < /dev/null ) || refuse "mode 4 could not compile the witness: $(head -c 200 "$W/c4")"
gcc "$W/w.s" -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o "$W/w.x" 2> "$W/ld4" || refuse "mode 4 link failed: $(head -c 200 "$W/ld4")"
( cd "$W" && run_env timeout -k 5 300 ./w.x > o4 2> e4 < "$WD/$N.in" )
for m in 3 4; do
  if cmp -s "$W/o$m" "$WD/$N.ref"; then ck ok "(1) mode $m: the output equals the oracle's ref"; else ck no "(1) mode $m: the output differs from the oracle's ref"; fi
  c="$(grep -a '^\[CHAIN-CHECK\] SUMMARY ' "$W/e$m" | tail -1)"; s="$(grep -a '^\[CHAIN-WALK\] SUMMARY ' "$W/e$m" | tail -1)"
  if [ -z "$c" ] || [ -z "$s" ]; then ck no "(2) mode $m: a summary line is missing -- the level-3 check did not run, nothing was measured"; continue; fi
  ck ok "(2) mode $m: both summaries printed"
  mm="$(num "$c" mismatch)"; ok="$(num "$c" ok)"; fh="$(num "$c" fnhops)"
  if [ "$mm" = 0 ] && [ "${ok:-0}" -gt 0 ] && [ "${fh:-0}" -gt 0 ]; then ck ok "(3) mode $m: chain check ok=$ok mismatch=0 fnhops=$fh"
  else ck no "(3) mode $m: chain check ok=${ok:-?} mismatch=${mm:-?} fnhops=${fh:-?} -- the chain named a frame the marker scan did not find"; fi
  mi="$(num "$s" missing)"; ns="$(num "$s" nosite)"; fl="$(num "$s" frameless)"
  if [ "$mi" = 0 ] && [ "$ns" = 0 ] && [ "$fl" = 0 ]; then ck ok "(4) mode $m: walk list missing=0 nosite=0 frameless=0"
  else ck no "(4) mode $m: walk list missing=${mi:-?} nosite=${ns:-?} frameless=${fl:-?} -- the chain list lacks a frame the marker scan found"; fi
done
echo "population: $checks arm(s) graded, $fails FAIL"
if [ "$fails" = 0 ]; then echo "GATE PASS(0) [$G]"; exit 0; fi
echo "⛔ GATE RED [$G]: $fails of $checks arms FAIL"; exit 1
