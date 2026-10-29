#!/usr/bin/env bash
# test_gate_sno_a_fence_after_a_live_deferred_thunk_finds_its_own_slots.sh -- A FENCE(P) AFTER A DEFERRED PATTERN WHOSE THUNK STAYS
# LIVE READS AND WRITES ITS OWN SLOTS (cfo 2026-09-30, found closing the ARBNO-then-FENCE hang row at SCRIP 32b404921/a7ed5c111).
# THE DEFECT, measured under gdb in mode 4 on the fixture: rsp falls 0x90 from the defer's alpha to the FENCE's alpha -- the 16-byte
# defer cell, the two continuations it pushes, and the frame of a thunk that stays live because P = ARBNO(' b') can recede -- while
# the depth tracker counts 16 for IR_MATCH_DEFER. FENCE1's zls slots are spelled [rsp+N] for the static depth, so its alpha stores
# land 128 bytes away among other nodes' fields; here the match head then retries from cursor 1 forever (sbl -bf: no).
# THE LAYOUT IS THE WITNESS: one statement fewer and the misplaced stores fall on dead slots and the program answers. The parent of
# the cursor cure (b1cde82b2) hangs 8 of 8; the cure hangs 4 of 6 with ASLR and 3 of 3 without -- so both arms run under
# setarch -R, where the reading is deterministic.
# THE CURE (cfo 2026-10-01, emit.cpp fence_frame_candidate): a FENCE1 that a DEFER of the same match can reach (a walk over gamma and
# operand edges from the DEFER, inside the match's node range) takes its frame cell in the match frame, [rbp - 64 - 16k], which no
# live thunk below it can move; a FENCE1 before every DEFER keeps its zls slots. RED (HANG, both modes) on the parent 4cfd7e0f4.
# ARMS: (1) mode 3 and (2) mode 4 print the ref cut from sbl -bf (../harness/scripts/fixtures/pattern/deferred_pattern_then_fence.{sno,ref})
# within 10 s. rc 0 both agree · 1 a hang or a diff · 2 no binary, no fixture, no setarch.
set -u
here=$(cd "$(dirname "$0")" && pwd); W=$(cd "$here/../../SCRIP" && pwd); G=sno_a_fence_after_a_live_deferred_thunk_finds_its_own_slots
[ -x "$W/scrip" ] || { echo "GATE REFUSE(2) [$G]: no $W/scrip"; exit 2; }
command -v setarch > /dev/null || { echo "GATE REFUSE(2) [$G]: no setarch -- the reading is ASLR-dependent without it"; exit 2; }
F="$W/scripts/fixtures/pattern/deferred_pattern_then_fence.sno"; R="${F%.sno}.ref"
[ -s "$F" ] && [ -s "$R" ] || { echo "GATE REFUSE(2) [$G]: fixture or ref missing"; exit 2; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
rc=0
timeout -k 5 10 setarch -R "$W/scrip" "$F" < /dev/null > "$T/m3.out" 2>&1; r3=$?
if [ $r3 -eq 124 ]; then echo "  m3: HANG (10 s)"; rc=1
elif ! cmp -s "$T/m3.out" "$R"; then echo "  m3: DIFF from the oracle's answer"; diff "$T/m3.out" "$R" | head -4; rc=1
else echo "  m3: agrees with sbl -bf"; fi
if "$W/scrip" --compile "$F" --out="$T/w.s" < /dev/null > /dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/w.s" -Wl,-rpath,"$W/out" -L"$W/out" -lscrip_rt -lm -lpthread -o "$T/w" 2>/dev/null; then
    timeout -k 5 10 setarch -R "$T/w" < /dev/null > "$T/m4.out" 2>&1; r4=$?
    if [ $r4 -eq 124 ]; then echo "  m4: HANG (10 s)"; rc=1
    elif ! cmp -s "$T/m4.out" "$R"; then echo "  m4: DIFF from the oracle's answer"; rc=1
    else echo "  m4: agrees with sbl -bf"; fi
else echo "  m4: could not build"; rc=1; fi
[ $rc -eq 0 ] && { echo "GATE PASS(0) [$G]: a FENCE after a live deferred thunk answers as SPITBOL does in both modes"; exit 0; }
echo "GATE FAIL(1) [$G]: a FENCE after a live deferred thunk does not answer as SPITBOL does (see above)"; exit 1
