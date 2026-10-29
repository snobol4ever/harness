#!/usr/bin/env bash
# test_gate_pas_heap_table_is_a_movable_root.sh -- Pascal new/dispose records are ORDINARY MOVABLE BLOCKS reached through the heap table, which the collector walks as a root
#
# RULED CEO-648 on the coo's finding of 2026-09-12 19:02 CDT and Lon's word ("We do not allow pinning in our heap since we
# slide"): since ac044419d four block types were marked live unconditionally and never moved, and Pascal new() records were
# among them -- Pascal pointer stability was a side effect of that exemption, not a design. Pascal pointers are integer
# handles into a heap table, so the table is the right place for the invariant: the table itself now lives OUTSIDE the
# collector arena (ct_arena, a never-collected bump allocator -- NOT malloc, which CEO-832 forbids anywhere in SCRIP, so it never competes for the 512 MB slab), every live cell is visited by pas_gc_roots,
# which the collector calls beside core_gc_roots and gen_gc_roots, every record payload and every set is allocated through
# rt_str_alloc as an ordinary movable block, and dispose returns the handle to a free list so the table is reused.
#
# THE WITNESS: a linked list of 300 records, each holding a second record through a mate pointer, is built and kept
# reachable ONLY through the heap table; 20000 further records are allocated and disposed to churn the heap; then the kept
# list is walked and every field re-read. Under a forced collection the payloads MOVE, so a single missed root or a missed
# slot fix-up shows up as a wrong field. Graded byte-identical to fpc -Miso in both modes, plain and under forced
# collection. The last arm is the one the row is actually about: the collector must RECLAIM Pascal record bytes. If the
# records were still pinned, every regeneration would report reclaimed 0 and the arm fails. FAIL_ONCE=1 corrupts the
# node count of the first mode's plain arm to prove the diff arm trips.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
RT_DIR="${RT_DIR:-$ROOT/out}"; [ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no runtime at $RT_DIR/libscrip_rt.so"; exit 2; }
FPC="${FPC_BIN:-/usr/bin/fpc}"; [ -x "$FPC" ] || { echo "⛔ GATE REFUSE(2) [$G]: no fpc at $FPC -- the ref is CUT FROM THE ORACLE, never pinned by hand"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.pas" <<'PAS'
program w(output);
const
  keep = 300;
  churn = 20000;
type
  link = ^node;
  node = record
    id: integer;
    tag: char;
    mate: link;
    next: link
  end;
var
  head, p, q, m: link;
  i, n, sum, bad: integer;
begin
  head := nil;
  bad := 0;
  for i := 1 to keep do
  begin
    new(p);
    p^.id := i;
    p^.tag := chr(ord('a') + i mod 26);
    new(m);
    m^.id := i * 1000;
    m^.tag := 'm';
    m^.mate := nil;
    m^.next := nil;
    p^.mate := m;
    p^.next := head;
    head := p
  end;
  for i := 1 to churn do
  begin
    new(q);
    q^.id := i;
    q^.tag := 'z';
    q^.mate := nil;
    q^.next := nil;
    if q^.id <> i then bad := bad + 1;
    if q^.tag <> 'z' then bad := bad + 1;
    dispose(q)
  end;
  n := 0;
  sum := 0;
  p := head;
  while p <> nil do
  begin
    n := n + 1;
    sum := sum + p^.id;
    if p^.tag <> chr(ord('a') + p^.id mod 26) then bad := bad + 1;
    if p^.mate^.id <> p^.id * 1000 then bad := bad + 1;
    if p^.mate^.tag <> 'm' then bad := bad + 1;
    p := p^.next
  end;
  writeln('nodes ', n:1, ' sum ', sum:1, ' churn ', churn:1, ' bad ', bad:1);
  p := head;
  while p <> nil do
  begin
    q := p^.next;
    dispose(p^.mate);
    dispose(p);
    p := q
  end;
  new(p);
  p^.id := 7;
  p^.tag := 'k';
  writeln('reused ', p^.id:1, ' ', p^.tag)
end.
PAS
( cd "$T" && "$FPC" -Miso -v0 w.pas >/dev/null 2>&1 && ./w ) > "$T/w.ref" 2>&1
grep -q '^nodes 300 sum 45150 churn 20000 bad 0$' "$T/w.ref" || { echo "⛔ GATE REFUSE(2) [$G]: the oracle did not produce the kept-list line this gate pins -- the oracle moved: $(head -1 "$T/w.ref")"; exit 2; }
( cd "$T" && timeout -k 5 60 "$SCRIP" --compile --out=w.s w.pas </dev/null && gcc w.s -o w.bin -L"$RT_DIR" -lscrip_rt -lm -lpthread ) >/dev/null 2>&1 || { echo "⛔ GATE REFUSE(2) [$G]: the mode-4 witness did not build"; exit 2; }
RC=0
for M in m3 m4; do
  for ARM in plain forced; do
    if [ "$ARM" = forced ]; then PRE=(env SCRIP_GC_STRESS=2000); else PRE=(env); fi
    if [ "$M" = m3 ]; then ( cd "$T" && "${PRE[@]}" timeout -k 5 120 "$SCRIP" --run w.pas </dev/null ) >"$T/$M.$ARM.out" 2>&1
    else ( cd "$T" && "${PRE[@]}" LD_LIBRARY_PATH="$RT_DIR" timeout -k 5 120 ./w.bin </dev/null ) >"$T/$M.$ARM.out" 2>&1
    fi
    if [ -n "${FAIL_ONCE:-}" ] && [ "$M" = m3 ] && [ "$ARM" = plain ]; then sed -i '1s/^nodes 300/nodes 299/' "$T/$M.$ARM.out"; fi
    if diff -u "$T/w.ref" "$T/$M.$ARM.out" >"$T/$M.$ARM.diff"; then echo "  $M $ARM PASS ($(wc -l <"$T/w.ref") lines byte-identical to fpc -Miso)"
    else echo "  $M $ARM FAIL ($(grep -c '^[-+][^-+]' "$T/$M.$ARM.diff") diff lines)"; sed -n '1,10p' "$T/$M.$ARM.diff" | sed 's/^/      /'; RC=1; fi
  done
done
( cd "$T" && env SCRIP_GC_STRESS=2000 SCRIP_ZETA_TELEM=1 timeout -k 5 120 "$SCRIP" --run w.pas </dev/null ) >"$T/telem.out" 2>&1
RUNS=$(grep -c 'regeneration #' "$T/telem.out"); RUNS=${RUNS:-0}
RECL=$(grep -o 'reclaimed [0-9]*' "$T/telem.out" | awk '{s+=$2} END {print s+0}')
PINMAX=$(grep -o 'pinned [0-9]*' "$T/telem.out" | awk '{if ($2+0>m) m=$2+0} END {print m+0}')
if [ "$RUNS" -lt 5 ]; then echo "  reclaim FAIL (only $RUNS regenerations ran under SCRIP_GC_STRESS=2000 -- the Pascal record path is not reaching the collector at all)"; RC=1
elif [ "$RECL" -le 0 ]; then echo "  reclaim FAIL ($RUNS regenerations reclaimed $RECL bytes -- Pascal records are still immortal blocks, which is exactly what CEO-648 retired)"; RC=1
elif [ "$PINMAX" -gt 5000 ]; then echo "  reclaim FAIL ($RUNS regenerations, high-water pinned $PINMAX blocks -- the Pascal record path is still minting pinned blocks)"; RC=1
else echo "  reclaim PASS ($RUNS regenerations reclaimed $RECL bytes, high-water pinned $PINMAX blocks, records moved and the table was fixed up)"
fi
if [ "$RC" = 0 ]; then echo "GATE PASS [$G]: Pascal new/dispose records are movable blocks reached through the heap table, survive a forced collection byte-identical to fpc -Miso in both modes, and their bytes are reclaimed"
else echo "GATE FAIL(1) [$G]: the Pascal heap table is not a movable root (examined 2 modes x 2 arms plus the reclaim arm)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  oracle: $FPC $($FPC -iV 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
