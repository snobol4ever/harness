#!/usr/bin/env bash
# test_gate_the_run_slot_wait_rescans_every_slot_and_never_pins_one.sh -- a run that finds every box run slot held WAITS BY RESCANNING ALL OF THEM, never by
# queueing on one (coo 2026-10-30 12:4x CDT; the instruments lane; CEO-1894's pool, CEO-2033). MEASURED: the loop's xsb request (corpus_suite_harness.py
# run) started while all eight /tmp/s4e-run-slots were held, took the fallback slot (its pid modulo 8 = slot3) and blocked on that one lock for 17 minutes,
# the holder being a serial regrade script that keeps its slot for hours, while slots 1 and 4 to 7 stood free; every request behind it waited too. The old
# fallback was `flock slot<pid%N>` in corpus_suite_harness.py:_run_slot and util_run_slot.sh (test_design_*.sh and test_gate_pl_quad_regs.sh carry copies).
# ARMS (all in a mktemp pool named by S4E_RUN_SLOT_DIR, the real pool is never touched):
#   A  corpus_suite_harness.py:_run_slot with all eight slots held, then ONE slot that is not pid%8 released: the waiter has it within 6 s.
#   B  util_run_slot.sh with all eight held, then one released: the wrapped command runs within 6 s.
#   C  with the pool free both take a slot at once (< 2 s).
#   D  under S4E_RUN_SLOT_HELD both take none and do not wait, whatever the pool holds.
# RED BEFORE: 219d416 (the parent) reads RED on A and B -- run the gate with GATE_HARNESS_PY / GATE_RUN_SLOT_SH naming copies of the parent's two files whose
# pool path /tmp/s4e-run-slots was sed into the fixture directory (the parents know no seam), the waiter sits on slot pid%8 until the gate kills it.
# rc 0 every arm holds; 1 an arm is red; 2 cannot measure.
GATE_NAME=test_gate_the_run_slot_wait_rescans_every_slot_and_never_pins_one
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
H="${GATE_HARNESS_PY:-$HERE/corpus_suite_harness.py}"
W="${GATE_RUN_SLOT_SH:-$HERE/util_run_slot.sh}"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
command -v flock > /dev/null || refuse "no flock"
[ -f "$H" ] || refuse "no harness at $H"
[ -f "$W" ] || refuse "no wrapper at $W"
T="$(mktemp -d)"; HOLD=()
cleanup() { local p; for p in "${HOLD[@]}"; do kill "$p" 2> /dev/null; done; wait 2> /dev/null; rm -rf "$T"; }
trap cleanup EXIT
export S4E_RUN_SLOT_DIR="$T/slots" S4E_RUN_SLOTS=8
unset S4E_RUN_SLOT_HELD
mkdir -p "$S4E_RUN_SLOT_DIR"
red=0; total=0
arm() { total=$((total + 1)); if [ "$2" = ok ]; then echo "  ok   $1"; else echo "  RED  $1 -- $3"; red=$((red + 1)); fi; }
drop_all() { local p; for p in "${HOLD[@]}"; do kill "$p" 2> /dev/null; done; wait 2> /dev/null; HOLD=(); }
hold_all() { local i; drop_all; for i in 0 1 2 3 4 5 6 7; do ( exec 9> "$S4E_RUN_SLOT_DIR/slot$i"; flock -x 9; exec sleep 120 ) & HOLD[$i]=$!; done; sleep 0.6; }
release() { kill "${HOLD[$1]}" 2> /dev/null; wait "${HOLD[$1]}" 2> /dev/null; unset "HOLD[$1]"; }
wait_for() { local f="$1" pat="$2" n=0; while [ "$n" -lt 24 ]; do grep -q "$pat" "$f" 2> /dev/null && return 0; sleep 0.25; n=$((n + 1)); done; return 1; }
PYWAIT='import importlib.util, os, sys, time
sys.path.insert(0, os.path.dirname(sys.argv[1]))
sp = importlib.util.spec_from_file_location("h", sys.argv[1]); m = importlib.util.module_from_spec(sp); sp.loader.exec_module(m)
t = time.time(); f = m._run_slot()
print("GOT", "none" if f is None else os.path.basename(f.name), round(time.time() - t, 2), flush=True)'
hold_all
python3 -I -c "$PYWAIT" "$H" > "$T/a.out" 2>&1 &
wp=$!; sleep 1.2
k=$(( (wp + 3) % 8 )); release "$k"
if wait_for "$T/a.out" "GOT slot$k "; then arm "A the harness waiter takes the one slot released (slot$k, its fallback was slot$((wp % 8)))" ok
else arm "A the harness waiter takes the one slot released" red "slot$k was freed and the waiter (pid $wp, pid%8 = slot$((wp % 8))) never got it: $(head -c 120 "$T/a.out")"; kill "$wp" 2> /dev/null; fi
wait "$wp" 2> /dev/null
hold_all
bash "$W" bash -c 'echo GOT $$' > "$T/b.out" 2>&1 &
wp=$!; sleep 1.2
release 5
if wait_for "$T/b.out" "GOT "; then arm "B util_run_slot.sh runs its command once any slot is released" ok
else arm "B util_run_slot.sh runs its command once any slot is released" red "slot5 was freed and the wrapper never ran its command"; kill "$wp" 2> /dev/null; fi
wait "$wp" 2> /dev/null
drop_all
s=$(date +%s.%N); python3 -I -c "$PYWAIT" "$H" > "$T/c1.out" 2>&1; bash "$W" bash -c 'echo GOT' > "$T/c2.out" 2>&1; e=$(date +%s.%N)
if grep -q '^GOT slot' "$T/c1.out" && grep -q '^GOT' "$T/c2.out" && awk -v a="$s" -v b="$e" 'BEGIN{exit !(b - a < 2)}'; then arm "C a free pool is taken at once" ok
else arm "C a free pool is taken at once" red "$(head -c 100 "$T/c1.out") / $(head -c 100 "$T/c2.out")"; fi
hold_all
s=$(date +%s.%N); S4E_RUN_SLOT_HELD=1 python3 -I -c "$PYWAIT" "$H" > "$T/d1.out" 2>&1; S4E_RUN_SLOT_HELD=1 bash "$W" bash -c 'echo GOT' > "$T/d2.out" 2>&1; e=$(date +%s.%N)
if grep -q '^GOT none' "$T/d1.out" && grep -q '^GOT' "$T/d2.out" && awk -v a="$s" -v b="$e" 'BEGIN{exit !(b - a < 2)}'; then arm "D a run under a held slot takes none and does not wait" ok
else arm "D a run under a held slot takes none and does not wait" red "$(head -c 100 "$T/d1.out") / $(head -c 100 "$T/d2.out")"; fi
echo "[$GATE_NAME] arms=$total red=$red (harness=$(basename "$H") wrapper=$(basename "$W"), pool=8 slots in a mktemp dir)"
[ "$red" = 0 ] && exit 0 || exit 1
