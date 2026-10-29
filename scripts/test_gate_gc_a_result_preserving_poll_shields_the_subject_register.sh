#!/usr/bin/env bash
# test_gate_gc_a_result_preserving_poll_shields_the_subject_register.sh -- EVERY RESULT-PRESERVING POLL SHIELDS r13 THE WAY THE
# PLAIN POLL DOES, CONTEXT-FREE (cfo ruling 2026-10-04, on hq_templates' finding at c869d57c1).
#
# THE LOSS THIS HOLDS: c869d57c1 gave the baked by-name call arms x86_rt_gc_poll_res, which spilled rax:rdx and called rt_gc_poll; the plain
# poll's slow road (rt_gc_poll_slow) also pushes r13, the match or scan subject Sigma, and hands it to gc_point_arr_body as the saved subject,
# which rewrites it when it aliases Sigma or scan_subj.  rt_gc_poll did not, so a subject held in r13 across the new poll went stale
# (ZGC-STALE, holder never visited): corpus/benchmarks/icon/tgrlink.icn rc 139 in both modes and the Icon pre-step on two programs.
# x86_rt_gc_poll_res now spills the r13 word BELOW the sweep floor and the result cell AT it, and calls rt_gc_point_arr_probe_c with the
# r13 word as the saved subject.
#
# (a) THE SHAPE in the emitted mode-4 text of a witness whose poll_res runs inside a match: the r13 store at [rsp+0], the result stores at
#     [rsp+16] and [rsp+24], rdx = rsp, rcx = rsp+16, the probe call, the three reloads.
# (b) THE PROPERTY, both modes: hb_nested_match_outer_subject.sno answers its ref at stress points 1..6 with the displacement plant on
#     (SCRIP_GC_PLANT_SHIFT=1024 moves every collected block, so a stale r13 is a wrong answer and not a lucky one).
# (c) THE PLANT: the same witness's mode-4 text with the saved-subject argument taken away (mov rdx, rsp -> xor edx, edx) is an unshielded
#     poll_res, and it LOSES at 4 or more of the 6 points -- so (b) is a measurement and not a pass by construction.
# FAIL_ONCE=1 runs (b) against the planted text.
#
# THE RECORD FORM (hq_icon 2026-10-11, row icon-a-trapped-substring-...-ceo-1660): x86_rt_gc_poll_rec_res, the record poll of 23 box sites
# (field get, subscript, assign_var_sub, assign_global, call_fn, to_by, rev_assign_var, glue_flat), called rt_gc_point_arr_c with r0 = NULL,
# so a collection at a field store inside an Icon scan left r13 stale: Jcon tgrlink read 0xdb poison under every SCRIP_GC_STRESS setting on
# SCRIP 60b7e1572, and rc 139 at the default window once one more trapped variable moved collection #1 into crack()'s scan. It now keeps its
# result in arr[0] and hands the saved r13 to rt_gc_point_arr_probe_c. (d) the record shape reads in the Icon witness's mode-4 text and the
# plant (lea rdx, [rsp + 16] -> xor edx, edx) edits exactly those sites; (e) the witness answers its iconx ref at stress 1..8 under the
# displacement plant, both modes; (f) the planted text LOSES at 3 or more of the 8 points (measured 5 of 8 when the arm was cut).
# RE-CUT 2026-10-15 (hq_icon): the witness's field store alone read 0 of 8 once 52f822b69 made a store-only field a bare cell -- it allocates nothing, so the allocation
# that sets g_gc_pending (SCRIP_GC_STRESS counts allocations) is serviced by the poll after the record constructor's call, before the scan is entered, and the record poll
# after the field never found a collection pending. The witness now also takes line[3] || line[4] inside the scan: the subscript builds its string inside its own
# record-form box, so the collection lands at the record poll with r13 live (measured 7 of 8 with both; the unplanted text answers its ref at all 8, both modes).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
WD="$ROOT/../harness/scripts/gc_witnesses"; W="$WD/hb_nested_match_outer_subject"
[ -s "$W.sno" ] && [ -s "$W.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: witness or .ref missing under gc_witnesses"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0
( cd "$T" && "$SCRIP" --compile --out=w.s "$W.sno" < /dev/null > /dev/null 2> c.err ) || { echo "⛔ GATE REFUSE(2) [$G]: the witness did not compile in mode 4: $(head -1 "$T/c.err")"; exit 2; }
sed 's/^\( *\)mov  *rdx, rsp$/\1xor edx, edx/' "$T/w.s" > "$T/wp.s"
nplant=$(diff "$T/w.s" "$T/wp.s" | grep -c '^<')
shape=$(awk '
  /mov +qword ptr \[rsp \+ 0\], r13/ { a=NR }
  /mov +qword ptr \[rsp \+ 16\], rax/ && a && NR-a<=2 { b=NR }
  /mov +qword ptr \[rsp \+ 24\], rdx/ && b && NR-b<=2 { c=NR }
  /mov +rdx, rsp/ && c && NR-c<=8 { d=NR }
  /lea +rcx, \[rsp \+ 16\]/ && d && NR-d<=2 { e=NR }
  /call +rt_gc_point_arr_probe_c/ && e && NR-e<=8 { f=NR }
  /mov +r13, qword ptr \[rsp \+ 0\]/ && f && NR-f<=8 { g=NR }
  /mov +rdx, qword ptr \[rsp \+ 24\]/ && g && NR-g<=4 { n++; a=b=c=d=e=f=g=0 }
  END { print n+0 }' "$T/w.s")
if [ "$shape" -gt 0 ] && [ "$nplant" = "$shape" ]; then echo "  ok   (a) the poll_res shape reads whole $shape time(s) in the witness's mode-4 text: r13 below the floor, the result cell at it, rdx = the r13 word, rcx = the floor, the probe call, three reloads"
else echo "  FAIL (a) the poll_res shape reads $shape time(s) and the plant edits $nplant line(s) in the witness's mode-4 text -- x86_rt_gc_poll_res no longer hands r13 to rt_gc_point_arr_probe_c"; RC=1; fi
SRC="w"; [ "${FAIL_ONCE:-0}" = 1 ] && SRC="wp"
gcc -m64 -no-pie -rdynamic "$T/$SRC.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$T/$SRC.bin" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: the mode-4 text did not link"; exit 2; }
gcc -m64 -no-pie -rdynamic "$T/wp.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$T/wp.bin" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: the planted text did not link"; exit 2; }
band=""; bad=0; pband=""; phit=0
for st in 1 2 3 4 5 6; do
  ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=512 SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=$st timeout -k 5 60s "$SCRIP" --run "$W.sno" < /dev/null > m3_$st.out 2> m3_$st.err ); r3=$?
  if [ $r3 = 0 ] && cmp -s "$T/m3_$st.out" "$W.ref"; then band="$band m3_s$st:ref"; else band="$band m3_s$st:LOSS"; bad=1; fi
  ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=512 SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=$st timeout -k 5 60s "./$SRC.bin" < /dev/null > m4_$st.out 2> m4_$st.err ); r4=$?
  if [ $r4 = 0 ] && cmp -s "$T/m4_$st.out" "$W.ref"; then band="$band m4_s$st:ref"; else band="$band m4_s$st:LOSS"; bad=1; fi
  ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=512 SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=$st timeout -k 5 60s ./wp.bin < /dev/null > p_$st.out 2> p_$st.err ); rp=$?
  if [ $rp != 0 ] || ! cmp -s "$T/p_$st.out" "$W.ref"; then pband="$pband s$st:LOSS"; phit=$((phit+1)); else pband="$pband s$st:ref"; fi
done
pa=$(cat "$T"/m3_*.err "$T"/m4_*.err "$T"/p_*.err 2>/dev/null | grep -c '^\[GC-FLIP\] plant:')
if [ "${pa:-0}" -ge 3 ]; then echo "  ok   (a2) THE SHIFT PLANT APPLIED: $pa banner line(s) over the m3, m4 and planted runs -- the band below grades forced movement, not an unplanted run"
else echo "  FAIL (a2) the flip plant printed its applied banner ${pa:-0} time(s) -- the band below may grade a run nothing moved"; RC=1; fi
if [ "$bad" = 0 ]; then echo "  ok   (b) THE PROPERTY: the witness answers its ref at stress 1..6 under the displacement plant, both modes --$band"
else echo "  FAIL (b) a poll_res inside a match lost the subject --$band"; RC=1; fi
if [ "$phit" -ge 4 ]; then echo "  ok   (c) PLANTED: with the saved-subject argument taken away the same text loses at $phit of 6 points --$pband -- so (b) measures the shield"
else echo "  FAIL (c) the unshielded plant lost at only $phit of 6 points ($pband) -- the witness no longer holds a subject in r13 across a poll_res, and (b) proves nothing"; RC=1; fi
RW="$WD/hb_icn_record_poll_inside_a_scan_keeps_its_subject"
[ -s "$RW.icn" ] && [ -s "$RW.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the record-form witness or its .ref is missing under gc_witnesses"; exit 2; }
( cd "$T" && "$SCRIP" --compile --out=r.s "$RW.icn" < /dev/null > /dev/null 2> rc.err ) || { echo "⛔ GATE REFUSE(2) [$G]: the record-form witness did not compile in mode 4"; exit 2; }
sed 's/^\( *\)lea  *rdx, \[rsp + 16\]$/\1xor edx, edx/' "$T/r.s" > "$T/rp.s"
rplant=$(diff "$T/r.s" "$T/rp.s" | grep -c '^<')
rshape=$(awk '
  /mov +qword ptr \[rsp \+ 16\], r13/ { a=NR }
  /lea +rdx, \[rsp \+ 16\]/ && a && NR-a<=3 { b=NR }
  /call +rt_gc_point_arr_probe_c/ && b && NR-b<=4 { c=NR }
  /mov +r13, qword ptr \[rsp \+ 16\]/ && c && NR-c<=4 { n++; a=b=c=0 }
  END { print n+0 }' "$T/r.s")
if [ "$rshape" -gt 0 ] && [ "$rplant" = "$rshape" ]; then echo "  ok   (d) the record form reads whole $rshape time(s) in the Icon witness's mode-4 text: r13 spilled beside the arr cell, rdx = its word, the probe call, the r13 reload"
else echo "  FAIL (d) the record form reads $rshape time(s) and the plant edits $rplant line(s) -- x86_rt_gc_poll_rec_res no longer hands r13 to rt_gc_point_arr_probe_c"; RC=1; fi
RSRC="r"; [ "${FAIL_ONCE:-0}" = 1 ] && RSRC="rp"
gcc -m64 -no-pie -rdynamic "$T/$RSRC.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$T/$RSRC.bin" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: the record-form text did not link"; exit 2; }
gcc -m64 -no-pie -rdynamic "$T/rp.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$T/rp.bin" 2>/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: the planted record-form text did not link"; exit 2; }
rband=""; rbad=0; rpband=""; rphit=0
for st in 1 2 3 4 5 6 7 8; do
  ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=512 SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=$st timeout -k 5 60s "$SCRIP" --run "$RW.icn" < /dev/null > rm3_$st.out 2> /dev/null ); r3=$?
  if [ $r3 = 0 ] && cmp -s "$T/rm3_$st.out" "$RW.ref"; then rband="$rband m3_s$st:ref"; else rband="$rband m3_s$st:LOSS"; rbad=1; fi
  ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=512 SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=$st timeout -k 5 60s "./$RSRC.bin" < /dev/null > rm4_$st.out 2> /dev/null ); r4=$?
  if [ $r4 = 0 ] && cmp -s "$T/rm4_$st.out" "$RW.ref"; then rband="$rband m4_s$st:ref"; else rband="$rband m4_s$st:LOSS"; rbad=1; fi
  ( cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=512 SCRIP_GC_PLANT_FLIP=1 SCRIP_GC_STRESS=$st timeout -k 5 60s ./rp.bin < /dev/null > rp_$st.out 2> /dev/null ); rp=$?
  if [ $rp != 0 ] || ! cmp -s "$T/rp_$st.out" "$RW.ref"; then rpband="$rpband s$st:LOSS"; rphit=$((rphit+1)); else rpband="$rpband s$st:ref"; fi
done
if [ "$rbad" = 0 ]; then echo "  ok   (e) THE PROPERTY: a field store and a string subscript inside an Icon scan keep the subject at stress 1..8 under the displacement plant, both modes --$rband"
else echo "  FAIL (e) a record poll inside a scan lost the subject --$rband"; RC=1; fi
if [ "$rphit" -ge 3 ]; then echo "  ok   (f) PLANTED: with the record form's saved-subject argument taken away the same text loses at $rphit of 8 points --$rpband -- so (e) measures the shield"
else echo "  FAIL (f) the unshielded record plant lost at only $rphit of 8 points ($rpband) -- the witness no longer holds a subject in r13 across a record poll, and (e) proves nothing"; RC=1; fi
echo "population: 6 arm(s) graded"
if [ $RC = 0 ]; then echo "✅ GATE PASS(0) [$G]: x86_rt_gc_poll_res and the record form x86_rt_gc_poll_rec_res hand the subject register to the collector as the plain poll does, and each plant shows the loss it would otherwise be"
else echo "⛔ GATE FAIL(1) [$G]: a result-preserving poll does not shield r13"; fi
exit $RC
