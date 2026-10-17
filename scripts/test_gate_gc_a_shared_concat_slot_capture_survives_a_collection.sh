#!/usr/bin/env bash
# test_gate_gc_a_shared_concat_slot_capture_survives_a_collection.sh -- cfo, 2026-09-22, MODE DECTET;
# CEO-1131 ("RULED, OPTION ONE, LAND IT NOW"), on hq_snocone's FINDING-2026-09-22-hq_snocone-c6009782-...
#
# WHAT WAS THERE. c60097828 put a BARE POLL (x86_rt_gc_poll) after the shared DESCR store at four templates.
# At bb_binop_concat_slot.cpp:69 that poll made a SILENT WRONG ANSWER: pattern captures assigned through the
# concat-slot road came back as runs of 0xDB -- the byte gc_heap.c memsets over VACATED ground after compaction --
# so the block was RECLAIMED, not moved-and-missed, and the DESCR length word survived while the payload did not.
# No ZGC-STALE fires even under SCRIP_GC_RELOC=1, because the read lands on poisoned-but-MAPPED ground rather than
# quarantined ground. rc=0 throughout: a wrong answer with no diagnostic.
#
# WHY THE LINE CAME OUT RATHER THAN CHANGING FORM. The site takes NO poll form at all: measured one bit per suspect,
# a rebuild between each -- poll_res DIFFs, poll_res plus a re-store into ZRES(0)/ZRES(8) DIFFs, and the poll moved
# after rtcc_rl DIFFs. A site that refuses every poll form is a DIAGNOSTIC SIGNAL, not a stubborn site: it says the
# value there is held by something the collector never visits (CEO-1131). The holder hunt is its own row; this gate
# only holds the ground that the revert won back, so the poll cannot return without a red.
#
# ARMS. (1) BAND: the witness matches its oracle-cut ref at stress 0, 1, 3 and 5 at the mandatory tiny arena,
# and every arm prints the run's OWN collections count -- a tiny arena states a configuration, only a count states
# an exercise (CEO-934). (2) EXERCISE: at least one stress point must report collections>0, so the band cannot go
# green by never collecting. (3) POSITIVE: the emitted code for the witness must still contain the concat-slot
# runtime call, so a green cannot be bought by deleting the road or by a witness that stopped reaching it --
# an absence criterion is paired with a positive arm proving the emitter still exists.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
R="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"; cd "$R" || exit 2
W=../harness/scripts/gc_witnesses/hb_concat_slot_capture_across_a_collection.sc
REF=../harness/scripts/gc_witnesses/hb_concat_slot_capture_across_a_collection.ref
[ -f "$W" ] && [ -f "$REF" ] || { echo "REFUSE(2): witness or ref missing"; exit 2; }
TMP=$(mktemp -d) || exit 2; trap 'rm -rf "$TMP"' EXIT
fail=0; collected=0
for st in 0 1 3 5; do
  env -u SCRIP_HEAP_MB SCRIP_GC_EXERCISE=1 SCRIP_HEAP_KB=128 SCRIP_GC_STRESS=$st timeout -k 5 60 ./scrip "$W" < /dev/null > "$TMP/o.$st" 2> "$TMP/e.$st"
  rc=$?
  col=$(grep -o 'collections=[0-9]*' "$TMP/e.$st" | tail -1); col=${col#collections=}; col=${col:-0}
  [ "${col:-0}" -gt 0 ] && collected=1
  if [ $rc -ne 0 ]; then echo "RED stress=$st rc=$rc collections=$col"; fail=1
  elif ! diff -q "$TMP/o.$st" "$REF" > /dev/null 2>&1; then
    echo "RED stress=$st WRONG ANSWER collections=$col ($(diff "$TMP/o.$st" "$REF" | grep -c '^<') line(s) differ)"; fail=1
  else echo "ok  stress=$st PASS collections=$col"; fi
done
[ "$collected" = 1 ] || { echo "RED no stress point reported collections>0 -- the band measured a configuration, not an exercise"; fail=1; }
if timeout -k 5 60 ./scrip --compile -o "$TMP/w.s" "$W" < /dev/null 2>/dev/null; then
  n=$(grep -cE '\b(str_concat_d|str_concat_fracdigit_d|rt_icn_lconcat_d|sno_concat_d)\b' "$TMP/w.s")
  if [ "${n:-0}" -gt 0 ]; then echo "ok  POSITIVE the concat-slot road is still emitted for this witness ($n call site(s))"
  else echo "RED the witness no longer emits a concat-slot runtime call -- the band is measuring nothing"; fail=1; fi
else echo "RED could not compile the witness to assembly for the positive arm"; fail=1; fi
[ $fail = 0 ] && echo "GREEN a shared concat-slot capture survives a collection at the tiny arena in all four stress points"
exit $fail
