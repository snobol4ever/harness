#!/usr/bin/env bash
# test_gate_icn_gc_a_scanned_subject_with_an_embedded_nul_keeps_its_length_across_a_collection.sh -- hq_icon, 2026-09-24, MODE
# DECTET; row icon-gc-g-scan-subj-ptr-is-not-relocated-so-rt-scan-subj-len-falls-back-to-strlen-and-loses-an-embedded-nul-length
# (ceo CEO-1152, named by the cfo at fa1dc84a5).
#
# WHAT WAS THERE, AND IT WAS TWO HOLDERS OF ONE ADDRESS AGAIN. rt_scan_subj_len() answers the scan subject's length from a cache
# keyed on the subject's ADDRESS (g_scan_subj_ptr / g_scan_subj_len). gen_gc_roots moved g_scan_subj at every collection and never
# the cache, so the first collection after a scan began left the key naming the pre-move address, the lookup missed, and the
# function fell back to strlen() -- which stops at an embedded NUL. A callee reading its caller's subject (it has no scan
# registers of its own) then saw *&subject = 2 and image(&subject) = "ab" for "ab\x00cdeee", rc=0, both modes, at every stress
# level including the shipped arena. Independently the by-name tab() arm measured the subject with strlen() and returned an
# unmeasured STRVAL even with no collection at all, so tab(0) in a callee read "b" and &pos 3.
#
# WHAT IS HERE. The cache is registered as a slot of its own when it aliases the subject at the collection (rt_gc_visit_raw
# fixes up every registered slot after the move -- assigning it from g_scan_subj right after the visit would copy the OLD
# address, which is what the first cut of this cure measured), and is left alone when it does not. Every writer of g_scan_subj
# sets the length -- the co-expression ScanState now carries it, the resets and the reenter paths set it, the empty subject is
# one shared object -- so the strlen() fallback is DELETED: a subject whose length was not carried is an internal error that
# aborts loudly, never a shorter answer. tab(), move() and pos() read the carried length and tab() returns it with BSTRVAL.
#
# ARMS. (1) STRUCTURE, both directions: rt_scan_subj_len has no strlen and aborts on a miss; gen_gc_roots registers the cache
# slot under the alias test; no strlen(g_scan_subj) is left anywhere under src/runtime. (2) BAND, both media: the witness matches
# its iconx-cut ref at stress 0,1,3,5 under in a 128 KB arena, and EVERY arm reports collections>0 from the
# run's own report. (3) NO COLLECTION: in a 64 MB arena the same witness matches in both media -- the tab() arm's own path.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
GR="$ROOT/src/runtime/builtins/gen_runtime.c"
WIT="$HERE/gc_witnesses/hb_scan_subject_embedded_nul_across_a_collection.icn"; REF="${WIT%.icn}.ref"
for f in "$GR" "$WIT" "$REF"; do [ -f "$f" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing $f"; exit 2; }; done
echo "  HOLDS: a scan subject with an embedded NUL keeps its carried length across a collection that moves it, and a callee's tab/move/pos/&subject read that length"
body="$(sed -n '/^long rt_scan_subj_len(void) {/,/^}/p' "$GR")"
fb=$(printf '%s\n' "$body" | grep -c 'strlen')
ab=$(printf '%s\n' "$body" | grep -c 'abort()')
sl=$(grep -cF 'g_runtime.abi.scan_subj_ptr == g_runtime.abi.scan_subj) rt_gc_visit_raw(&g_runtime.abi.scan_subj_ptr);' "$GR")
ms=$(grep -rnF -e 'strlen(g_scan_subj)' -e 'strlen(g_runtime.abi.scan_subj)' "$ROOT/src/runtime" | wc -l)
if [ -n "$body" ] && [ "$fb" = 0 ] && [ "$ab" = 1 ] && [ "$sl" = 1 ] && [ "$ms" = 0 ]; then
  echo "  arm 1 PASS: rt_scan_subj_len has no strlen and aborts on a miss, gen_gc_roots registers the cache slot under the alias test, no strlen(g_scan_subj) left under src/runtime"
else echo "  arm 1 FAIL: body_found=$([ -n "$body" ] && echo 1 || echo 0) strlen_in_body=$fb abort_in_body=$ab cache_slot_registered=$sl strlen_of_scan_subj_sites=$ms"; RC=1; fi
"$SCRIP" --compile -o "$T/w.s" "$WIT" </dev/null >/dev/null 2>&1 && gcc -no-pie "$T/w.s" -o "$T/w4" -L"$ROOT/out" -lscrip_rt -lm -lstdc++ -lpthread -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 \
  || { echo "⛔ GATE REFUSE(2) [$G]: the witness does not build in mode 4"; exit 2; }
want="$(cat "$REF")"; band=""; bad=0
for st in 0 1 3 5; do
  for md in m3 m4; do
    if [ "$md" = m3 ]; then out="$(cd "$T" && env SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=$st SCRIP_GC_EXERCISE=1 timeout -k 5 120 "$SCRIP" "$WIT" 2>"$T/e" </dev/null)"
    else out="$(cd "$T" && env SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=$st SCRIP_GC_EXERCISE=1 timeout -k 5 120 "$T/w4" 2>"$T/e" </dev/null)"; fi
    n=$(grep -m1 -oE 'collections=[0-9]+' "$T/e" | head -1 | cut -d= -f2)
    if [ "$out" = "$want" ] && [ "${n:-0}" -gt 0 ]; then band="$band @$st$md:ok($n)"; else band="$band @$st$md:RED(collections=${n:-0})"; bad=1; fi
  done
done
if [ "$bad" = 0 ]; then echo "  arm 2 PASS: the callee reads the whole NUL-carrying subject after every block has moved, both media --$band"
else echo "  arm 2 FAIL: the subject's length or bytes were lost across a collection, or the collector never ran --$band"; RC=1; fi
o3="$(cd "$T" && env SCRIP_HEAP_KB=65536 timeout -k 5 120 "$SCRIP" "$WIT" 2>/dev/null </dev/null)"
o4="$(cd "$T" && env SCRIP_HEAP_KB=65536 timeout -k 5 120 "$T/w4" 2>/dev/null </dev/null)"
if [ "$o3" = "$want" ] && [ "$o4" = "$want" ]; then echo "  arm 3 PASS: with no collection a callee's tab/move/pos keep the embedded NUL, both media"
else echo "  arm 3 FAIL: with no collection the callee still measures the subject -- m3=[$(printf '%s' "$o3" | cat -v | tr '\n' '|')] m4=[$(printf '%s' "$o4" | cat -v | tr '\n' '|')]"; RC=1; fi
[ "$RC" = 0 ] && echo "✅ GATE PASS [$G]: 3 of 3 arms hold" || echo "⛔ GATE FAIL [$G]"
exit $RC
