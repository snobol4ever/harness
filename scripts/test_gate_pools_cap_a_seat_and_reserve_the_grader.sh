#!/usr/bin/env bash
# test_gate_pools_cap_a_seat_and_reserve_the_grader.sh -- THE POOLS WITH A SEAT'S SHARE (the cto, ARCH-SHARED-DEVELOPMENT.md 4.3 and 4.6,
# CEO-2041 step 3; Lon 2026-10-31: "Everyone is compiling at the same time"). Hermetic: scratch pool directories under mktemp (the takers'
# S4E_CC_SLOT_DIR / S4E_RUN_SLOT_DIR seam), a scratch SLOT_WAITS ledger, fixture seats by S4E_SEAT, sleep commands as the work.
#   arm 1  TWO SEATS CONTEND: seats A and B each start sixteen compiles (util_cc_slot.sh sleep) at pool 8, cap 4; sampled five times a second,
#          neither seat ever holds five pool slots, the pool never holds nine, and both seats hold at least one at the same instant (fairness)
#   arm 2  THE GRADER'S RESERVATION: eight run-slot holders of three ordinary seats fill slots 0..5 and wait for the rest; a grader claimant
#          (S4E_CLASS=grader) gets a slot within three seconds while an ordinary claimant started with it is still waiting
#   arm 3  THE PYTHON TAKER FOLLOWS THE SAME RULE: corpus_suite_harness._slot_knobs() equals lib_slots.sh's S4E_*_DEFAULT lines; with slots
#          0..5 held, a grader _run_slot() returns within three seconds and an ordinary one does not
#   arm 4  NO NESTED TAKE: under S4E_RUN_SLOT_HELD the run taker opens no slot file
# RED on the takers before the landing (S4E_SLOT_TAKERS_DIR=<a checkout of them>): a seat holds eight at once and the grader waits like anyone.
# rc 0 GREEN, 1 RED, 2 REFUSE (no takers, no flock, no python3).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
NAME=test_gate_pools_cap_a_seat_and_reserve_the_grader
TK="${S4E_SLOT_TAKERS_DIR:-$HERE}"
refuse() { echo "REFUSE(2): $*"; exit 2; }
[ -f "$TK/util_cc_slot.sh" ] && [ -f "$TK/util_run_slot.sh" ] || refuse "no takers under $TK"
command -v flock > /dev/null || refuse "no flock"
command -v python3 > /dev/null || refuse "no python3"
T="$(mktemp -d /tmp/s4e_pools_gate.XXXXXX)"
PIDS=""
cleanup() { [ -n "$PIDS" ] && kill $PIDS 2>/dev/null; pkill -P $$ 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT
export S4E_CC_SLOT_DIR="$T/cc" S4E_RUN_SLOT_DIR="$T/run" S4E_SLOT_WAITS="$T/waits.tsv" S4E_CC_SLOTS=8 S4E_RUN_SLOTS=8 S4E_CC_SEAT_CAP=4 S4E_RUN_SEAT_CAP=3 S4E_RUN_GRADER_RESERVED=2
unset S4E_RUN_SLOT_HELD S4E_CLASS
mkdir -p "$T/cc" "$T/run"
held() {   # <dir> <n> -- how many of slot0..n-1 are locked right now
    local d="$1" n="$2" i=0 c=0
    while [ "$i" -lt "$n" ]; do [ -e "$d/slot$i" ] && ! flock -n "$d/slot$i" true 2>/dev/null && c=$((c + 1)); i=$((i + 1)); done
    echo "$c"
}
held_by() {   # <dir> <pid>... -- how many pool slots these processes hold, read from /proc/<pid>/fd (a holder keeps its slot file open: kernel truth)
    local d="$1" c=0 p; shift
    for p in "$@"; do c=$((c + $(ls -l /proc/$p/fd 2>/dev/null | grep -c " $d/slot[0-9]*$"))); done
    echo "$c"
}
red=""
# arm 1: two seats, sixteen compiles each, pool 8 cap 4
PA=""; PB=""
for i in $(seq 1 16); do S4E_SEAT=seatA bash "$TK/util_cc_slot.sh" sleep 1 & PA="$PA $!"; done
for i in $(seq 1 16); do S4E_SEAT=seatB bash "$TK/util_cc_slot.sh" sleep 1 & PB="$PB $!"; done
PIDS="$PA $PB"
maxA=0; maxB=0; maxP=0; both=0
for t in $(seq 1 120); do
    a="$(held_by "$T/cc" $PA)"; b="$(held_by "$T/cc" $PB)"; p="$(held "$T/cc" 8)"
    [ "$a" -gt "$maxA" ] && maxA=$a; [ "$b" -gt "$maxB" ] && maxB=$b; [ "$p" -gt "$maxP" ] && maxP=$p
    [ "$a" -ge 1 ] && [ "$b" -ge 1 ] && both=1
    [ -z "$(jobs -rp)" ] && break
    sleep 0.2
done
wait 2>/dev/null; PIDS=""
[ "$maxA" -le 4 ] && [ "$maxB" -le 4 ] || red="$red arm1:a-seat-held-$maxA/$maxB-of-cap-4"
[ "$maxP" -le 8 ] || red="$red arm1:pool-held-$maxP-of-8"
[ "$both" = 1 ] || red="$red arm1:the-two-seats-never-held-at-once"
# arm 2: eight ordinary holders (three seats), then a grader claimant against an ordinary claimant
for s in seatA seatB seatC; do for i in 1 2 3; do S4E_SEAT=$s bash "$TK/util_run_slot.sh" sleep 40 & PIDS="$PIDS $!"; done; done
sleep 2
h="$(held "$T/run" 8)"
[ "$h" = 6 ] || red="$red arm2:ordinary-holders-took-$h-slots-not-6"
t0=$(date +%s.%N)
S4E_SEAT=grader_seat S4E_CLASS=grader timeout -k 1 10 bash "$TK/util_run_slot.sh" sh -c 'echo GRADER-GOT' > "$T/grader.out" 2>&1 &
gp=$!
S4E_SEAT=seatD timeout -k 1 6 bash "$TK/util_run_slot.sh" sh -c 'echo ORDINARY-GOT' > "$T/ordinary.out" 2>&1 &
op=$!
wait $gp; grc=$?; gt=$(awk -v a="$t0" -v b="$(date +%s.%N)" 'BEGIN{printf "%.1f", b-a}')
wait $op; orc=$?
grep -q GRADER-GOT "$T/grader.out" && [ "$grc" = 0 ] && awk -v g="$gt" 'BEGIN{exit !(g < 3.0)}' || red="$red arm2:grader-waited-${gt}s(rc$grc)"
grep -q ORDINARY-GOT "$T/ordinary.out" && red="$red arm2:an-ordinary-claimant-got-a-reserved-slot"
# arm 3: the python taker's knobs and reservation (the ordinary holders of arm 2 still hold slots 0..5)
knobs_sh="$(sed -n 's/^\(S4E_[A-Z_]*_DEFAULT\)=\([0-9]*\)\s*$/\1=\2/p' "$HERE/lib_slots.sh" | sort | tr '\n' ' ')"
knobs_py="$(cd "$HERE" && python3 -c 'import corpus_suite_harness as h; k=h._slot_knobs(); print(" ".join("%s=%d"%(a,k[a]) for a in sorted(k)))' 2>/dev/null) "
[ -n "$knobs_sh" ] && [ "$knobs_sh" = "$knobs_py" ] || red="$red arm3:knobs-differ(sh:$knobs_sh|py:$knobs_py)"
pyt='import corpus_suite_harness as h, time; t=time.time(); s=h._run_slot(); print("PY-GOT %.1f" % (time.time()-t)); s and s.close()'
pg="$(cd "$HERE" && S4E_SEAT=grader_seat S4E_CLASS=grader timeout -k 1 10 python3 -c "$pyt" 2>&1)"
case "$pg" in PY-GOT*) awk -v g="${pg#PY-GOT }" 'BEGIN{exit !(g < 3.0)}' || red="$red arm3:python-grader-waited-${pg#PY-GOT }s";; *) red="$red arm3:python-grader-got-nothing($pg)";; esac
po="$(cd "$HERE" && S4E_SEAT=seatE timeout -k 1 4 python3 -c "$pyt" 2>&1)"
case "$po" in PY-GOT*) red="$red arm3:python-ordinary-got-a-reserved-slot";; esac
# arm 4: no nested take
rm -rf "$T/run4"; S4E_RUN_SLOT_DIR="$T/run4" S4E_RUN_SLOT_HELD=1 S4E_SEAT=seatA bash "$TK/util_run_slot.sh" true
[ -z "$(ls "$T/run4" 2>/dev/null)" ] || red="$red arm4:a-nested-take-opened-a-slot-file"
kill $PIDS 2>/dev/null; wait 2>/dev/null; PIDS=""
echo "POOLS_SEAT_CAP_BOARD maxA=$maxA maxB=$maxB pool=$maxP grader_wait=${gt}s knobs=${knobs_sh% } (tree $(git -C "$ROOT/harness" rev-parse --short HEAD 2>/dev/null))"
if [ -z "$red" ]; then echo "GATE OK [$NAME]: two seats at pool 8 cap 4 held at most $maxA and $maxB, the grader took a reserved run slot in ${gt}s while an ordinary claimant waited, the python taker reads the same rule"; exit 0; fi
echo "GATE FAIL [$NAME]:$red"; exit 1
