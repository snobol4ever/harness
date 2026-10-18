#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_gc_pas_heap_cells_survive_forced_movement.sh -- row pascal-gc-the-pas-heap-cell-table-holds-collected-heap-strings-and-the-collector-never-visits-it
# (minted ceo 2026-09-20 CEO-mint; PREMISE MEASURED FALSE AND THE ROW REWRITTEN BY hq_pascal THE SAME DAY -- see THE PREMISE below).
# THE MECHANISM, read out of the code rather than recalled: new(p) is rewritten by the parser (pascal.y) into __pas_alloc_rec(nfields); the runtime arm
# (by_name_dispatch.c) does TWO allocations -- pas_heap_take() returns an INTEGER INDEX and pas_heap_cell(n,1) hands back a DESCR_t slot in the Pascal-private
# side table g_pas_heap, while the record's fields are built as an SOH-separated string by rt_str_alloc, which IS rt_gcheap_alloc(DT_S) on the COLLECTED,
# SLIDING heap.  So a Pascal pointer VALUE is an integer handle and every record's field payload is a collected heap string held by that side table.
# ⛔⭐ THE PREMISE THE ROW WAS MINTED ON IS FALSE ON THIS TREE AND WAS ALREADY FALSE WHEN IT WAS MINTED.  The row says gc_heap.c contains ZERO references to
# pas_heap, which is literally true and is not the question: the collector reaches the table through a function named pas_gc_roots, NOT through the string
# pas_heap.  pas_gc_roots is defined in by_name_dispatch.c, walks g_pas_heap[1..top] with rt_gc_visit_descr plus the g_pas_tf text-file buffers, is a strong
# global symbol (nm reads T pas_gc_roots; there is no weak fallback), and is called UNCONDITIONALLY in the root phase of gc_heap.c beside core_gc_roots and
# pl_gc_roots.  It landed 2026-09-13 in f0d0adf5b (subject: the heap table is a movable root the collector walks) and was hardened the same day by bcf75511a
# (subject: the collector's Pascal root hook is a strong symbol) -- SEVEN DAYS BEFORE THE ROW WAS MINTED.  ⭐ A grep for pas_heap inside gc_heap.c answers
# "is the string there", not "does the collector visit the table", and the visiting function does not carry the string.  This gate exists so that the answer
# is MEASURED on every run instead of re-derived from a grep by the next seat who asks.
# ⛔ BEING CALLED IS NOT BEING CORRECT, which is why this gate forces movement rather than hoping for it.  Under a sliding collector a root that is VISITED
# but not FORWARDED is still corruption, and a null result bounds the probe rather than the thing probed (the ceo's own honest half of the mint).  So:
#   SCRIP_GC_STRESS=N   forces a collection every Nth allocation -- UNSET IS ZERO FORCED COLLECTIONS, which is why ARM 1 exists.
#   SCRIP_GC_PLANT_SHIFT forces a deterministic shift every collection, so live blocks MOVE even when they would otherwise stay put.
#   SCRIP_GC_POISON is ON BY DEFAULT (gc_heap.c) and fills vacated space with 0xDB, so an unforwarded cell reads garbage rather than stale-but-plausible bytes.
# ⛔⭐ ARM 1 IS THE ONE THIS GATE EXISTS FOR AND IT IS hq_snocone's, CREDITED (2026-09-20, their snocone GC row, same mechanism in their lane): "THE RUNGS IS
# CLEAN AT ONE MEGABYTE" CAN BE TRUE AND MEAN NOTHING.  Measured in the Pascal lane the same day: all 246 Pascal rungs entries at SCRIP_HEAP_MB=1 with NO
# stress read PASS=246 FAIL=0 with collectors=0 non_collectors=246 regenerations=0 -- a perfect green over a population that never ran a collector once.  No rc,
# no denominator and no FAIL=0 anywhere in a pass/fail instrument can say so.  THEREFORE the liveness question is asked SEPARATELY, FIRST, and AT EVERY BAND
# POINT (a HIGHER plant collects LESS often, so a high point can be inert for the same reason the tiny arena was), and a point that did not collect REFUSES
# rc=2 rather than reporting green.
# ⛔ WHAT THIS GATE DOES NOT PROVE, said plainly so a green is not over-read: the witnesses are hand-cut record shapes (a record with integer fields and a
# packed array field; a linked list threaded through pointer fields), NOT the Pascal rungs.  A green here is a statement about those shapes at those band
# points at THIS path length, and per hq_raku 2026-09-20 a stress band is a property of (program, runner, PATH LENGTH) -- the argv string is allocated and the
# stress plant counts allocations, so the pathname decides which allocation a collection lands on.  The path length is printed on the first line for that reason.
# Whatever a band finds is a LOWER BOUND, never a population (hq_prolog 2026-09-20: their window is ragged and non-monotonic, wrong at 1,2,3,5,10,25 and right
# at 0,20,40,50 -- a sample of {20,40,50} would have called it clean).
set -u
# ⛔ CEO-1680 (ceo 2026-10-17): the detector arm that ran each witness under SCRIP_TEST_PLANT_PAS_ROOT_SKIP=1 is GONE with the seam it read -- no switch
# in SCRIP exists so a test can fail. The root walk's fail-once is a PROPER test: the same witnesses on a worktree of f0d0adf5b^ (the commit before
# pas_gc_roots visited the heap table) read red under this band, measured once at the landing that deleted the seam; each run's own fail-once is the
# oracle comparison below, which reads RED on any wrong answer, over a collector the INERT and NO-MOVE arms prove live and moving.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SCRIP="${SCRIP:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)/scrip}"
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "$SCRIP" "the scrip compiler"
FPC=/usr/bin/fpc
[ -x "$FPC" ] || { echo "REFUSE(2) [$(basename "$0" .sh)]: the Pascal oracle $FPC is absent -- a missing oracle does not blank a board, it prints a full and entirely false one"; exit 2; }
BAND="${PAS_GC_BAND:-3 16}"
SHIFTS="${PAS_GC_SHIFTS:-1}"
W=$(mktemp -d) || exit 2
KEEP=0
cat > "$W/pasrec.pas" <<'FIX'
program pasrec(output);
type
  pp = ^prec;
  prec = record
    a, b, c, d: integer;
    tag: packed array[1..40] of char
  end;
var
  p: array[1..40] of pp;
  q: pp;
  i, j, s: integer;
begin
  for i := 1 to 40 do
    begin
      new(p[i]);
      p[i]^.a := i; p[i]^.b := i * 2; p[i]^.c := i * 3; p[i]^.d := i * 4;
      p[i]^.tag := 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA'
    end;
  for j := 1 to 300 do
    begin
      new(q); q^.a := j;
      q^.tag := 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB';
      dispose(q)
    end;
  s := 0;
  for i := 1 to 40 do s := s + p[i]^.a + p[i]^.b + p[i]^.c + p[i]^.d;
  writeln(s); writeln(p[1]^.tag); writeln(p[40]^.tag)
end.
FIX
cat > "$W/paslist.pas" <<'FIX'
program paslist(output);
type
  pp = ^prec;
  prec = record
    f: integer;
    ael, inx: pp;
    tag: packed array[1..24] of char
  end;
var
  head, cur, junk: pp;
  i, j, s: integer;
begin
  head := nil;
  for i := 1 to 120 do
    begin
      new(cur); cur^.f := i;
      cur^.tag := 'LLLLLLLLLLLLLLLLLLLLLLLL';
      cur^.ael := head; cur^.inx := nil; head := cur
    end;
  for j := 1 to 400 do
    begin
      new(junk); junk^.f := j;
      junk^.tag := 'GGGGGGGGGGGGGGGGGGGGGGGG';
      dispose(junk)
    end;
  s := 0; cur := head;
  while cur <> nil do
    begin
      s := s + cur^.f;
      if cur^.tag <> 'LLLLLLLLLLLLLLLLLLLLLLLL' then s := s + 100000;
      cur := cur^.ael
    end;
  writeln(s); writeln(head^.tag)
end.
FIX
WITNESSES="pasrec paslist"
for w in $WITNESSES; do
  ( cd "$W" && "$FPC" -Miso "$w.pas" >"$W/$w.fpclog" 2>&1 ) || { echo "REFUSE(2) [$(basename "$0" .sh)]: the oracle could not compile $w.pas"; tail -3 "$W/$w.fpclog"; exit 2; }
  ( cd "$W" && "./$w" > "$w.ref" 2>/dev/null ) || { echo "REFUSE(2) [$(basename "$0" .sh)]: the oracle could not run $w"; exit 2; }
  [ -s "$W/$w.ref" ] || { echo "REFUSE(2) [$(basename "$0" .sh)]: the oracle produced an EMPTY ref for $w -- an empty ref makes every wrong answer a match"; exit 2; }
  ( cd "$W" && timeout -k 5 120 "$SCRIP" --compile -o "$w.s" "$w.pas" >/dev/null 2>&1 ) || { echo "REFUSE(2) [$(basename "$0" .sh)]: scrip could not emit asm for $w"; exit 2; }
  ( cd "$W" && gcc -o "${w}_m4" "$w.s" -L"$(dirname "$SCRIP")/out" -lscrip_rt -Wl,-rpath,"$(dirname "$SCRIP")/out" >/dev/null 2>&1 ) || { echo "REFUSE(2) [$(basename "$0" .sh)]: mode-4 link failed for $w"; exit 2; }
done
echo "pas-heap-forced-movement: workdir=$W path_len=${#W} band='$BAND' shifts='$SHIFTS' modes='m3 m4' poison=on-by-default (a band is a property of program, runner AND path length -- hq_raku 2026-09-20)"
RED=0; INERT=0; NOMOVE=0; GRADED=0; MATCH=0; NOSTART=0; UNPLANTED=0
for w in $WITNESSES; do
  REF=$(cat "$W/$w.ref")
  for st in $BAND; do
    for sh in $SHIFTS; do
      for mode in m3 m4; do
        if [ "$mode" = m3 ]; then out=$( cd "$W" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=512 SCRIP_GC_STRESS="$st" SCRIP_GC_PLANT_FLIP="$sh" SCRIP_ZETA_TELEM=1 timeout -k 5 300 "$SCRIP" "$w.pas" < /dev/null 2>"$W/err.txt" ); rc=$?
        else out=$( cd "$W" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=512 SCRIP_GC_STRESS="$st" SCRIP_GC_PLANT_FLIP="$sh" SCRIP_ZETA_TELEM=1 timeout -k 5 300 "./${w}_m4" < /dev/null 2>"$W/err.txt" ); rc=$?; fi
        col=$(grep -c 'regeneration #' "$W/err.txt"); col=${col:-0}
        mv=$(grep -o 'moved=[0-9]*B' "$W/err.txt" | grep -o '[0-9]*' | awk '{s+=$1} END{print s+0}')
        GRADED=$((GRADED+1))
        tag="$w/$mode/stress:$st/flip:$sh"
        if [ "$rc" -eq 127 ]; then echo "NOSTART $tag -- rc=127: the runner never started, so this point measured nothing. It is NOT a red and NOT an inert population -- naming the two apart is the whole point (a variable expansion cannot serve as an env-assignment prefix; bash resolves assignments at parse time, so a VAR=val built at runtime becomes a COMMAND NAME. Measured in this lane 2026-09-20: it turned a working census into a plausible PASS=0 FAIL=246 board)"; NOSTART=$((NOSTART+1)); continue; fi
        if [ "$col" -eq 0 ]; then echo "INERT   $tag -- collections=0: this point never ran a collector, so its answer is a statement about the program and not about the collector"; INERT=$((INERT+1)); continue; fi
        if [ "$mv" -eq 0 ]; then echo "NO-MOVE $tag -- collections=$col but moved=0B: nothing relocated, so forwarding was never exercised"; NOMOVE=$((NOMOVE+1)); continue; fi
        pl=$(grep -c '^\[GC-FLIP\] plant:' "$W/err.txt"); pl=${pl:-0}
        if [ "$sh" -ne 0 ] && [ "$pl" -eq 0 ]; then echo "UNPLANTED $tag -- collections=$col moved=${mv}B but the flip plant applied ZERO times: gc_plant_shift_bytes() returns 0 whenever the arena headroom is not strictly greater than the shift, and it used to do so SILENTLY. This point relocated blocks by ordinary compaction alone, which is the very thing the plant exists to go beyond, so it is NOT a green and NOT a no-move. Measured by the cto 2026-09-21 on the cfo's flag, pasrec at a 1024 KB window (the MB-spelled pin of the day, which the CEO-1146 sweep retired; this figure is CITED at the configuration it was measured under and not re-measured here) stress 3: shift 4096 applies 495 times, 65536 applies 466, 262144 applies 373, 1048576 applies ZERO with rc=0 and byte-identical stdout -- so before this arm existed, a big-enough shift under the mandated tiny arena made this gate PASS having planted nothing at all"; UNPLANTED=$((UNPLANTED+1)); continue; fi
        if [ "$rc" -ne 0 ]; then echo "RED     $tag -- rc=$rc collections=$col moved=${mv}B"; RED=$((RED+1)); continue; fi
        if [ "$out" = "$REF" ]; then MATCH=$((MATCH+1)); else echo "RED     $tag -- ORACLE DIFF, collections=$col moved=${mv}B"; echo "$out" | head -3 | sed 's/^/          got: /'; echo "$REF" | head -3 | sed 's/^/          want:/'; RED=$((RED+1)); fi
      done
    done
  done
done
echo "pas-heap-forced-movement: graded=$GRADED match=$MATCH red=$RED inert=$INERT no_move=$NOMOVE unplanted=$UNPLANTED nostart=$NOSTART (denominator: match+red+inert+no_move+unplanted+nostart = $((MATCH+RED+INERT+NOMOVE+UNPLANTED+NOSTART)) of $GRADED)"
if [ "$INERT" -gt 0 ] || [ "$NOMOVE" -gt 0 ] || [ "$UNPLANTED" -gt 0 ] || [ "$NOSTART" -gt 0 ] || [ "$GRADED" -eq 0 ]; then
  echo "REFUSE(2) [$(basename "$0" .sh)]: this run COULD NOT MEASURE what it claims to measure (inert=$INERT no_move=$NOMOVE unplanted=$UNPLANTED nostart=$NOSTART graded=$GRADED). Workdir PRESERVED at $W -- a refusal that deletes its own evidence destroys the diagnosis with the same motion (hq_prolog 2026-09-20)."
  KEEP=1; exit 2
fi
if [ "$RED" -gt 0 ]; then echo "GATE RED [$(basename "$0" .sh)]: $RED of $GRADED graded points disagree with fpc -Miso under forced collection AND forced movement. Workdir PRESERVED at $W."; KEEP=1; exit 1; fi
rm -rf "$W"
echo "GATE PASS(0) [$(basename "$0" .sh)]: $MATCH of $GRADED points match the oracle, every one with a live collector and real relocation; the pas_heap cell table IS visited and forwarded (lower bound over these shapes, this band, this path length -- never a population)"
exit 0
