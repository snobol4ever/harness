#!/usr/bin/env bash
# util_gc_demo_porter_chain_reading.sh -- the chain check read on SnoRungs demo_porter, whole program, both modes (hq_collector 2026-10-11, row
# gc-the-chain-visits-a-frame-entered-through-the-c2bb-glue-from-a-deferred-call-inside-a-match-the-glue-subject-cell-is-walked-ceo-1688; ARCH-GC section 13).
#   usage: util_gc_demo_porter_chain_reading.sh      rc 0 = GREEN, 1 = RED (a chain-check mismatch or a wrong output), 2 = could not measure
# demo_porter is the corpus program whose mode-4 run crashed (SIGSEGV on a stale subject pointer after collection 10) once a spine change moved a frame (SCRIP ea957ffc5, reverted); this reads
# the program as it stands, with no such change: (a) the natural run, whole input; (b) a collection at every fifth safe point over the first 300 input lines. Per run, in mode 3 and mode 4:
# the output equals the ref, and `[CHAIN-CHECK] SUMMARY` reads mismatch=0 (the chain's first mapped frame is the marker scan's, or the marker scan's is a dead sibling's: ghost=N, counted apart).
# The tree's own marker scan reads a dead sibling's frame (ghost) in about a third of the stressed collections; that is the marker scan's defect, retired with it at STEP B, and not graded here.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
HOME_DIR="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
C="$HOME_DIR/corpus"
SCRIP="$ROOT/scrip"
[ -x "$SCRIP" ] && [ -f "$ROOT/out/libscrip_rt.so" ] || { echo "REFUSE(2): no scrip binary or runtime library under $ROOT"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
python3 "$ROOT/../harness/scripts/corpus_suite_harness.py" extract "$C/tests/snobol4/ALL.sno" "$C/tests/snobol4/ALL.ref" demo_porter "$W/w.sno" --out-ref "$W/w.ref" --out-in "$W/w.in" > /dev/null 2>&1 || { echo "REFUSE(2): demo_porter is not extractable from $C"; exit 2; }
head -300 "$W/w.in" > "$W/w.small.in"
( cd "$W" && "$SCRIP" --compile --out=w.s w.sno > /dev/null 2>&1 < /dev/null && gcc w.s -L"$ROOT/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$ROOT/out" -o w4 2> /dev/null ) || { echo "REFUSE(2): mode 4 could not build demo_porter"; exit 2; }
num() { printf '%s\n' "$1" | sed -n "s/.* $2=\([0-9]*\).*/\1/p"; }
bad=0
for run in natural stress; do
  for m in 3 4; do
    in="$W/w.in"; st=0; [ $run = stress ] && { in="$W/w.small.in"; st=5; }
    if [ $m = 3 ]; then ( cd "$W" && SCRIP_GC_STRESS=$st SCRIP_GC_CHAIN_CHECK=1 timeout -k 5 300 "$SCRIP" -d131072k -s4096k --stlimit w.sno < "$in" > "o.$run.$m" 2> "e.$run.$m" ); rc=$?
    else ( cd "$W" && SCRIP_GC_STRESS=$st SCRIP_GC_CHAIN_CHECK=1 timeout -k 5 300 ./w4 -d131072k -s4096k --stlimit -- < "$in" > "o.$run.$m" 2> "e.$run.$m" ); rc=$?; fi
    s="$(grep -a '^\[CHAIN-CHECK\] SUMMARY ' "$W/e.$run.$m" | tail -1)"
    [ -n "$s" ] || { echo "REFUSE(2): $run mode $m printed no [CHAIN-CHECK] SUMMARY (rc=$rc)"; exit 2; }
    mm="$(num "$s" mismatch)"; ok="$(num "$s" ok)"; gh="$(num "$s" ghost)"
    if [ $run = natural ]; then cmp -s "$W/o.$run.$m" "$W/w.ref" && same=yes || same=NO; else same=n/a; fi
    echo "demo_porter $run mode $m: rc=$rc ok=$ok mismatch=$mm ghost=${gh:-0} output==ref $same"
    [ "$mm" = 0 ] && [ "$rc" = 0 ] && [ "$same" != NO ] || bad=1
  done
done
[ $bad = 0 ] && { echo "GREEN: the chain agrees with the marker scan on every frame demo_porter's collections cross"; exit 0; }
echo "RED: the chain does not visit every frame demo_porter's collections cross"; exit 1
