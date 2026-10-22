#!/usr/bin/env bash
# test_gate_gc_the_pending_prolog_ball_is_a_rooted_cell.sh -- the Prolog ball in flight from throw to catch lived in a
# CALLEE-SAVED REGISTER, and a register is invisible to every root walk, so the collector reclaimed the ball and the
# structured catcher stopped catching (cfo CFO-119, 2026-09-20; escalated and independently diagnosed by hq_prolog, who
# released the claim rather than build it, because the shape choice was an officer's and the storage needed a ruling).
#
# MEASURED, seven-line witness, a catch whose catcher is the structured term error(type_error(evaluable, foo/0), _):
# swipl and SCRIP at stress 0 print caught_type_error; SCRIP under collection printed NOTHING on stdout and one stderr
# line naming the ball as an UNBOUND VARIABLE, so it no longer unified with the catcher, catch/3 did not catch, and the
# process EXITED 0 WITH THE WRONG STDOUT -- invisible to every rc-shaped instrument. Ragged and NOT a threshold:
# 46 of 68 arms red (17 stress points 0..50 x 2 modes x arenas 1 and 512 MB), green at 0/20/40/50, and m3 and m4
# DISAGREE at 25, 30 and 35 -- the same program, the same stress point, a different answer per mode.
#
# THE MECHANISM, PRINTED IN gdb BOTH WAYS RATHER THAN ARGUED. Ball built at 0x7ffeece13630, header size=32 type=214
# (HB_DVEC), valid at the first collection; on the PRE-CURE binary the header at that address read size=3688618971
# type=56283 at the SECOND collection -- the block was gone and its space re-carved -- while r15 still held the old
# address. CURED, the same probe prints slot=0x7ffeece135f0 against r15=0x7ffeece13630 at that same collection: the
# block SURVIVES and the collector FORWARDED it 0x40 bytes. So the VALUE READS MUST TAKE THE SLOT: a mirror that kept
# reading r15 would still have taken the stale address. gc_type_moves(HB_DVEC) is 1; the ball moves; a register cannot
# be told.
#
# ⛔ THE HOME IS THE TRAIL, NOT A GLOBAL, AND THAT IS THE LAW AND NOT A PREFERENCE. RULES.md line 231 forbids a new
# global without Lon's in-chat grant that session, and ../harness/scripts/test_gate_pl_no_new_global.sh prints the sanctioned
# alternative in its own refusal text: put the state in a FRAME CELL or the TRAIL. The trail arena is Prolog's ONE
# runtime spine, it is seeded once by the root graph and is live for the rest of the run (xa_flat.cpp guards the seed on
# root_graph), its 32-byte header already exists with only word 0 in use, and it is ALREADY registered with the collector
# as a topword root range. So the pending ball lives at PL_TR_BALL_OFF in that header, reached through r12, and the
# range walk visits it. A first cure held it in a new hidden global and measured IDENTICALLY (68 arms, 0 red, the same
# 0x40 forward) -- it was discarded for the storage, not the mechanism.
# ⛔ AND IT IS A ROOT, NEVER AN INVALIDATION (hq_snobol4 via hq_prolog): a later read must return the SAME ball because
# a handler matches its shape, so a generation-checked cache here would only convert garbage into a silent forget.
#
# Arms: (1) BEHAVIOUR -- the witness answers its oracle in BOTH modes across a 16-point band (CEO-1024: never {0,1,3,5}).
#           THIS IS ALSO THE INERTNESS DETECTOR: hq_snobol4 landed this same class with the visit behind an early return,
#           measured the whole band byte-identical to base, and an inert cure reads as "I rooted it and nothing moved".
#       (2) LOCKSTEP -- rtx_plunify.s may write the ball only through PL_BALL_ARM/PL_BALL_DROP and read its VALUE only
#           through PL_BALL_GET, so a future edit cannot arm the register and forget the rooted slot (the CFO-117
#           sibling-spelling shape); the single pendency test on r15 is allowed and named here.
#       (3) THE ROOT IS JOINED -- the collector's root-range walk must reach the trail header's ball slot, and the visit
#           must use rt_gc_visit_raw, which both marks the block and registers the slot for forwarding.
#       (4) THE HOME IS STILL THE TRAIL -- the ball macros must reach the slot through r12 and must NOT name a
#           rip-relative global, or the cure has quietly become the thing RULES.md line 231 refuses.
# FAIL_ONCE=1 plants a bare arm, drops the visit and rewrites the home as a global, and must trip arms 2, 3 and 4.
# ⛔ EVERY PATH HERE IS ANCHORED ON THIS CHECKOUT (hq_prolog 2026-09-20, D-17 PORTABLE-HOME: a criterion hardcoded to a
# sibling root grades your neighbour's checkout and reports PASS or REFUSE for reasons nobody in this lane can act on).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
unset SCRIP_HEAP_MB; : "${SCRIP_HEAP_KB:=128}"; export SCRIP_HEAP_KB
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ REFUSE(2): no scrip at $SCRIP"; exit 2; }
ASM="$ROOT/src/runtime/rtx/rtx_plunify.s"; TRC="$ROOT/src/runtime/rt/rt_pl_trail.c"; GCH="$ROOT/src/runtime/rt/gc_heap.c"
for f in "$ASM" "$TRC" "$GCH"; do [ -f "$f" ] || { echo "⛔ REFUSE(2): $f absent -- this gate is measuring nothing"; exit 2; }; done
command -v gcc >/dev/null || { echo "⛔ REFUSE(2): no gcc, so the mode 4 half cannot be built"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
cat > "$T/w.pl" <<'PL'
:- initialization(main).
main :- catch(( X is foo + 1, write(X) ), error(type_error(evaluable, foo/0), _), write(caught_type_error)), nl.
PL
RC=0; examined=0
echo "ARM 1 -- BEHAVIOUR: the structured catcher catches under collection (arena SCRIP_HEAP_KB=$SCRIP_HEAP_KB)"
"$SCRIP" --compile -o "$T/w.s" "$T/w.pl" >/dev/null 2>&1 || { echo "⛔ REFUSE(2): --compile refused the witness"; exit 2; }
gcc "$T/w.s" -L "$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" -o "$T/w.bin" 2>/dev/null \
  || { echo "⛔ REFUSE(2): the mode 4 witness would not link"; exit 2; }
nred=0
for ST in 0 1 2 3 4 5 8 10 13 16 20 25 30 35 45 50; do
  for M in m3 m4; do
    examined=$((examined+1))
    if [ "$M" = m3 ]; then o=$(SCRIP_GC_STRESS="$ST" timeout -k 5 30 "$SCRIP" "$T/w.pl" 2>/dev/null); r=$?
    else o=$(SCRIP_GC_STRESS="$ST" timeout -k 5 30 "$T/w.bin" 2>/dev/null); r=$?; fi
    if [ "$o" = "caught_type_error" ] && [ "$r" = 0 ]; then continue; fi
    echo "  FAIL stress=$ST $M rc=$r stdout=[$o] -- the ball did not survive to the catcher"; nred=$((nred+1)); RC=1
  done
done
echo "  band=32 arms red=$nred (pre-cure, over the wider two-arena band: 46 red of 68)"
echo "ARM 2 -- LOCKSTEP: the ball is written only through the macros and read for its VALUE only through PL_BALL_GET"
nw=0; nbad=0
LINES="$T/asm.lines"; grep -n 'r15\|PL_BALL_' "$ASM" > "$LINES" || true
[ -n "${FAIL_ONCE:-}" ] && echo "9999:    mov     r15, rax" >> "$LINES"
while IFS= read -r nl; do
  line=${nl#*:}
  case "$line" in '#define PL_BALL_'*) continue ;; '#define CTX_SAVE '*) echo "  note the leaf context save copies r15 into the frame's CTX_R15 word for the generator road's register image (2fa1fcd5c): r15 is only ever tested there for pendency, the ball's value is read through PL_BALL_GET"; continue ;; esac
  nw=$((nw+1)); examined=$((examined+1))
  case "$line" in
    *'test'*'r15, r15'*) ;;
    *'PL_BALL_ARM'*|*'PL_BALL_DROP'*|*'PL_BALL_GET'*) ;;
    *) echo "  FAIL bare r15 at line ${nl%%:*}: $(echo "$line" | sed 's/^ *//' | cut -c1-90) -- arm the rooted slot too"; nbad=$((nbad+1)); RC=1 ;;
  esac
done < "$LINES"
[ "$nw" -ge 20 ] || { echo "⛔ REFUSE(2): only $nw pending-ball sites in $(basename "$ASM"), expected >= 20 -- the convention was renamed and this arm is measuring nothing (the CFO-111 shape: a census keyed on one spelling of a name misses its sibling)"; exit 2; }
echo "  ball sites=$nw bare=$nbad"
echo "ARM 3 -- THE ROOT IS JOINED: the root-range walk reaches the trail header's ball slot"
vis=$(sed -n '/^void pl_tr_gc_root_ball/,/^}/p' "$TRC"); call=$(grep -c 'pl_tr_gc_root_ball(g_runtime\.gc\.gc_rrng\[i\]\.lo)' "$GCH" || true)
examined=$((examined+2))
if [ -n "${FAIL_ONCE:-}" ]; then vis="${vis//rt_gc_visit_raw/rt_gc_nothing}"; call=0; fi
case "$vis" in *'rt_gc_visit_raw((const char **)slot)'*) echo "  ok   the visit marks the block AND registers the slot, so a moved ball is forwarded" ;;
  *) echo "  FAIL pl_tr_gc_root_ball does not visit the slot with rt_gc_visit_raw -- a marked ball that moves would still be read stale"; RC=1 ;; esac
if [ "$call" -ge 1 ]; then echo "  ok   gc_heap.c's root walk calls it for every topword range ($call site)"
else echo "  FAIL gc_heap.c's root walk never calls pl_tr_gc_root_ball -- the slot is registered with nobody and the ball is back in a register"; RC=1; fi
echo "ARM 4 -- THE HOME IS STILL THE TRAIL, NOT A GLOBAL (RULES.md line 231)"
macros=$(grep -E '^#define PL_BALL_(ARM|DROP|GET)' "$ASM"); examined=$((examined+2))
[ -n "${FAIL_ONCE:-}" ] && macros="#define PL_BALL_ARM(r)  mov r15, r; mov qword ptr [rip + g_pl_ball_root], r"
if [ "$(printf '%s\n' "$macros" | grep -c 'r12')" -ge 3 ]; then echo "  ok   all three macros reach the slot through r12, the trail register"
else echo "  FAIL a ball macro no longer reaches the slot through the trail -- $(printf '%s' "$macros" | tr '\n' ' ' | cut -c1-120)"; RC=1; fi
if printf '%s\n' "$macros" | grep -q 'rip *+'; then
  echo "  FAIL a ball macro names a rip-relative global -- that is the storage RULES.md line 231 refuses without Lon's in-chat grant"; RC=1
else echo "  ok   no ball macro names a global; the cure adds no g_ symbol at all"; fi
echo "examined=$examined"
[ "$RC" = 0 ] && echo "PASS -- the pending ball is a rooted, forwarded cell in the trail header, in both modes across the band" || echo "FAIL($RC)"
exit $RC
