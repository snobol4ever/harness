#!/usr/bin/env bash
# test_gate_every_c_to_bb_box_entry_carries_its_hit.sh -- THE C->BB POPULATION IS COUNTED OVER HOOKED SITES ONLY,
# SO AN UNHOOKED ENTRY AND A DEAD ENTRY READ THE SAME. THIS GATE MAKES THAT IMPOSSIBLE TO REPEAT.
#
# ⛔⭐ WHY THIS EXISTS, MEASURED AND NOT ARGUED (cto 2026-09-21, CTO-88, under the C->BB->C->BB eradication,
# Lon 2026-09-21 17:0x / RULES.md line 238 FACT RULE / CEO-1086).  The ceo swept the whole SNOBOL4 rungs under
# SCRIP_C2BB_TRACE and reported 1062 live transitions over six live site names, with FOUR static sites reading
# ZERO and correctly called BOUNDED rather than dead.  That census could not see the roads that carry no
# rt_c2bb_hit AT ALL.  THREE SUCH ROADS EXISTED AND ALL THREE WERE IN THE cto's HALF:
#   * rk_gram_run_native / rk_gram_enter_box (by_name_dispatch.c, rt_gram_trampoline.S) -- a SECOND non-tail
#     C-frame entry into a box, holding char fb[256] on the C stack across the entry and choosing the port in C
#     with (r.v != DT_FAIL).  The ceo's telegram named rt.c:1194 as THE LAST non-tail C-frame call in the tree;
#     it was the last HOOKED one.  This road was never in any census because it was never hooked.
#     ⭐ DELETED 2026-09-21 on Lon's order, and NOT on a zero trace -- on the MECHANISM.  Under gdb, on a program
#     carrying both a grammar and a sub, rt_proc_set_fn fires for the sub and NEVER for the grammar rule, while
#     rt_proc_get_fn("gram__G__TOP") RETURNS NULL: lower_raku builds those graphs but nothing registers them, so
#     bf was null on every path and both guarded calls were unreachable by construction.  The NFA road is the
#     working implementation.  rt_gram_trampoline.S went with it, hence its absence from ENTRY_PRIMS below.
#     ⛔ IT WAS DEAD BECAUSE A FEATURE WAS BUILT AND NEVER WIRED, not because it was retired -- the unwired
#     gram__ graphs are hq_raku's question and are deliberately NOT resolved by this deletion.
#   * rt_chain_enter / rt_chain_enter_v -- the EVAL/CODE and computed-GOTO road, FIVE call sites in
#     runtime_eval.c, all unhooked.  MEASURED LIVE the moment it was hooked: a six-line SNOBOL4 program whose
#     only dynamic construct is EVAL('3 + 4') fires chain.eval.v.  That transition was invisible to the 1062.
# ⛔ THE ERROR CLASS IS THE ONE LON FIRED A SEAT OVER AT CEO-1069 -- "0 of 49 is a STATIC site count and a zero
# over it is a BLINDFOLD, not a clean bill" -- reappearing INSIDE the job created to cure it.  A zero from an
# instrument nobody proved live is not evidence, and the cure for that is a check, never a paragraph.
#
# ⭐ WHAT THE GATE ASSERTS: every CALL SITE of a primitive that enters a box from C carries an rt_c2bb_hit on its
# own line or within the three lines above it.  The primitive list is DECLARED below rather than discovered, so a
# NEW entry primitive is a deliberate edit to this file and not a silent addition.
# ⛔ THE SANCTIONED EXCEPTIONS ARE DECLARED BY NAME AND ARE THE ONLY ONES (CEO-970): the coroutine start
# (genp.spine / genp.spine.n2), scrip.c's main invocation through rt_outer_call, and scrip_coexpr_trampoline_entry.
# An exception is a NAME here, never a pattern, because a pattern quietly admits its next sibling.
#
# ⭐ FAIL-ONCE IS BUILT IN: FAIL_ONCE=1 strips the hit from one real site in a scratch copy and requires the gate
# to red on it.  A census that cannot fail is the instrument this gate exists to catch.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT" || exit 2

ENTRY_PRIMS='rt_proc_enter|rt_proc_enter_named|rt_tiny_record_enter|rt_chain_enter|rt_chain_enter_v'
# ⛔ ceo 2026-10-09 (CEO-1576, Lon: "stop the show and remove all of them"): when the tree DEFINES none of the entry primitives, every site this gate
# graded is deleted and there is nothing to carry a hit; the guard reads the tree, so a primitive put back re-arms the whole gate by itself.
if ! grep -rqaE "\.globl ($ENTRY_PRIMS)\\\\n" src/runtime 2>/dev/null; then echo "✅ no C->BB entry primitive remains in the tree (CEO-1576, the C-to-BB removal): rt_proc_enter, rt_proc_enter_named, rt_tiny_record_enter, rt_chain_enter and rt_chain_enter_v are deleted; nothing enters a box from C"; exit 0; fi
SCAN_DIRS="src/runtime src/driver"
WINDOW=3
# The program-initiating entry and the coroutine start -- the ONLY entries that may carry no hit (CEO-970).
SANCTIONED='rt_outer_call rt_genp_spine_enter'

SRC_ROOT="$ROOT"
if [ "${FAIL_ONCE:-0}" = "1" ]; then
  SRC_ROOT="$(mktemp -d)"; trap 'rm -rf "$SRC_ROOT"' EXIT
  mkdir -p "$SRC_ROOT/src"; cp -r src/runtime src/driver "$SRC_ROOT/src/" 2>/dev/null
  sed -i 's/rt_c2bb_hit("chain.goto", name); //' "$SRC_ROOT/src/runtime/runtime_eval.c"
  echo "FAIL_ONCE: stripped the chain.goto hit from a scratch copy; this run MUST red."
fi
cd "$SRC_ROOT" || exit 2

fails=0; sites=0
while IFS= read -r hit; do
  f="${hit%%:*}"; rest="${hit#*:}"; ln="${rest%%:*}"
  case "$f" in *".c") ;; *) continue ;; esac
  line="$(sed -n "${ln}p" "$f")"
  # ⛔ STRIP INLINE DECLARATIONS, DO NOT SKIP THE WHOLE LINE (cto 2026-09-21, second instance of this class in one
  # day).  The first version skipped any line containing "extern", which silently hid EVERY entry whose call shares
  # a line with its own extern declaration -- scrip.c:1764's rt_outer_call is exactly that shape.  A blanket skip is
  # a false NEGATIVE in a census, which is the failure this gate exists to catch, so it now removes the declaration
  # text and re-asks whether a CALL remains.
  probe="$(printf '%s' "$line" | sed -E 's/extern[^;]*;//g')"
  printf '%s' "$probe" | grep -qE "\b($ENTRY_PRIMS)[[:space:]]*\(" || continue
  case "$line" in
    *"DESCR_t rt_proc_enter"*|*"void rt_chain_enter"*) continue ;;
  esac
  # ⛔ THE SANCTIONED EXCEPTIONS ARE NOW CODE, NOT PROSE (CEO-970).  They were declared in the header above and
  # never implemented, which meant the header claimed a policy the gate did not enforce.
  skip=0
  for ex in $SANCTIONED; do case "$line" in *"$ex"*) skip=1;; esac; done
  [ "$skip" = 1 ] && continue
  sites=$((sites+1))
  lo=$(( ln > WINDOW ? ln - WINDOW : 1 ))
  ctx="$(sed -n "${lo},${ln}p" "$f" | grep -v 'extern void rt_c2bb_hit')"
  case "$ctx" in
    *rt_c2bb_hit*) ;;
    *) fails=$((fails+1)); printf '  ⛔ UNHOOKED C->BB ENTRY  %s:%s\n     %s\n' "$f" "$ln" "$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-140)" ;;
  esac
done < <(grep -rnE "\b($ENTRY_PRIMS)[[:space:]]*\(" $SCAN_DIRS --include=*.c 2>/dev/null)

dfn="$(grep -nE 'p->fn\(\(void \*\)' src/runtime/rt/rt.c 2>/dev/null | head -1)"
if [ -n "$dfn" ]; then
  dl="${dfn%%:*}"; sites=$((sites+1))
  lo=$(( dl > WINDOW ? dl - WINDOW : 1 ))
  if ! sed -n "${lo},${dl}p" src/runtime/rt/rt.c | grep -v 'extern void rt_c2bb_hit' | grep -q 'rt_c2bb_hit'; then
    fails=$((fails+1)); printf '  ⛔ UNHOOKED C->BB ENTRY (direct box fn pointer)  src/runtime/rt/rt.c:%s\n' "$dl"
  fi
fi

printf 'C->BB entry sites examined: %d   unhooked: %d\n' "$sites" "$fails"
# ⛔⭐ THE FLOOR WAS A COUNT OF THE THING THE WORK EXISTS TO REMOVE, AND IT REFUSED THE WORK.  Until 2026-09-21 this read
# `if [ "$sites" -lt 10 ]` against "the 13 that existed at CTO-88".  The C->BB eradication is DESIGNED to drive that number to
# zero -- the ceo took it 22->21 at bc6650ba3 and the cfo 21->19 and 19->18 the same evening -- so the guard fired on a correct
# landing and blocked `make preflight` for every seat.  ⭐ THE GUARD'S REASON IS RIGHT AND ONLY ITS KEY WAS WRONG: "a census
# that finds nothing grades everything green" is exactly the failure to prevent.  So the blindness check no longer COUNTS call
# sites, which are supposed to vanish; it asserts every name in ENTRY_PRIMS is still DEFINED somewhere in the tree, as an asm
# `.globl` or as a C declaration.  If the regex goes stale or a primitive is renamed, this REFUSES; if the call sites reach
# zero, that is the eradication finishing and the gate says so.  (Third guard in one day keyed on a population designed to
# expire -- see the auditor gate's arm d3 and DECLARED_OPEN in test_gate_gc_collector_visits_only_mapped_slots.sh.)
blind=""
# ⛔ THE LIST COMES FROM $ENTRY_PRIMS ITSELF -- a self-test that re-types its own input drifts from it, which is the rot this arm exists to stop.
for prim in $(printf %s "$ENTRY_PRIMS" | tr "|" " "); do
  grep -rqE "\.globl $prim\\\\n|[A-Za-z_][A-Za-z_0-9 ]*\\**$prim[[:space:]]*\\(" $SCAN_DIRS --include=*.c 2>/dev/null || blind="$blind $prim"
done
if [ -n "$blind" ]; then
  echo "⛔ GATE REFUSES: ENTRY_PRIMS names primitive(s) the tree no longer defines --$blind. The regex is stale, so this census is BLIND and its zero would grade everything green."
  exit 2
fi
if [ "$sites" = 0 ]; then
  echo "⭐ the C->BB entry-site census is EMPTY and the blindness check passed: every ENTRY_PRIM is still defined and nothing in C calls one. That is the eradication FINISHED, not a broken census."
fi
if [ "$fails" -gt 0 ]; then
  echo "⛔ GATE FAILED: $fails C->BB box entry site(s) carry no rt_c2bb_hit. An unhooked entry is INVISIBLE to every SCRIP_C2BB_TRACE sweep and reads as zero for the same reason a dead site does (CTO-88)."
  exit 1
fi
echo "✅ every C->BB box entry site carries its hit ($sites sites)"
exit 0
