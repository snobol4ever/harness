#!/usr/bin/env bash
# test_gate_gc_every_asm_entry_shim_tags_its_callee_saved_pushes.sh -- A HAND-WRITTEN BOX ENTRY HANDS THE WALKER A
# TAG, NOT A RAW WORD (cto 2026-09-21; row prolog-every-asm-entry-shim-pushes-callee-saved-registers-as-tagged-
# cells-not-raw-words, ceo CEO-1099; law RULES.md FACT RULE THE COLLECTOR GUESSES NOTHING, CEO-812; ARCH-GC 6.2i).
#
# WHAT IS HELD HERE, IN ONE SENTENCE.  bb_glue_enter_c2bb saves the registers it spills as TAGGED CELLS so the
# walker reads them as data; the hand-written asm entry shims push the same registers RAW, into a region no
# compile-time frame map describes.  Of the five, exactly one is heap-bearing by the tree's own convention -- r13
# is the Σ subject pointer and r15d its length, which is why the glue stores that PAIR as one DT_S cell -- so a
# raw push of r13 puts a live heap pointer where the walker can only guess at it, and where a MOVING collector
# will never relocate it.
#
# ⛔⭐ THE RUN ARM THIS GATE DOES NOT HAVE, AND THE MEASUREMENT THAT TOOK IT AWAY.  The obvious arm is to count
# the walker's raw spine words and ratchet them down.  THAT COLUMN DOES NOT DISCRIMINATE THE CURE AND THIS GATE
# WOULD HAVE SHIPPED A FLAPPING RATCHET IF IT HAD USED ONE.  Measured 2026-09-21 on ONE unchanged binary and ONE
# witness whose CONTENT never changed, varying only the LENGTH OF THE PATH the program was invoked by:
#     UNCURED build:  pathlen+1 -> s_raw_heap=3   +5 -> 6   +10 -> 3   +20 -> 3   +30 -> 6   +40 -> 3   +60 -> 6
#     CURED   build:  pathlen+1 -> s_raw_heap=6   +5 -> 6   +30 -> 3
# The quantity is BISTABLE between two stack-layout states (3 and 6, subject-pointing 2 and 5), it flips on an
# input that has nothing to do with the collector, and the cured and uncured builds BOTH span both states.  The
# answer is byte-identical to the oracle at every point.  A ratchet on that column grades which layout the run
# happened to land in.  ⛔ THIS MATTERS BEYOND THIS GATE: s_raw_heap is one of the columns the stack-completeness
# measure asserts to zero, so that measure needs a layout-invariant statistic or it will flap for the same reason.
#
# ⭐ SO ARM B GRADES WHAT IS INVARIANT AND REFUSES THE REST.  It proves the run was NOT INERT (the road fired, a
# collection really happened -- CEO-1044) and that the witness answers its ORACLE.  It does not grade a count it
# has just shown to be noise.  A gate that reports a number it cannot trust is the failure the INSTRUMENT LAWS
# exist against, and reporting NO number is the honest form of not having one yet.
#
# ⛔ WHAT A GREEN HERE DOES NOT SAY.  It does not say the shim frames are fully described: rbx, r12 and r14 are
# still saved raw under a DECLARED CONVENTION (r12 a pointer clamped into the dcap region, rbx the live frontier,
# r14 tagged DT_I by the glue), and the census NAMES them on every run rather than letting "raw" go silent.  It
# does not say the raw push was ever observed to produce a wrong answer -- it was not, on this witness.  It says
# the one word the tree agrees is heap-bearing is handed to the walker tagged instead of guessed at.
#
# ⭐ FAIL-ONCE, BY THE POPULATION RATHER THAN BY A PLANT.  Arm A is RED on the shims still owed and GREEN on each
# one cured, so the detector is proven to discriminate on real members every time it runs.
# ⛔ ARM B GRADES THROUGH corpus_suite_harness.classify AND NOT THROUGH ITS OWN COMPARISON, because a seat
# grading GC work with a bare cmp or diff is minting phantom reds right now (the coo, relayed by the ceo at
# CEO-1100): classify rstrips both sides, honours a declared want_rc, applies line masks, and -- the reason it
# matters here -- SEPARATES HANG FROM FAIL, which is exactly the distinction CEO-1098 requires a loaded box to
# preserve. This gate's witness is simple enough that a direct string compare happened to agree; relying on that
# is the reasoning the fleet fact warns against, so it does not.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT="$PWD"
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
CENSUS="$ROOT/../harness/scripts/util_gc_asm_shim_tag_census.py"
# ⛔ THE COLLECTION COUNT RUNS UNDER SCRIP_GC_STRESS=3 (ceo CEO-1261): the witness allocates ~94 KB in all, so it collected twice at the
# old 128 KB shipped window and never at SPITBOL's 1 MB (Lon 2026-09-25: "Let's set our default stack size and heap size for SCRIP to
# be the same as SPITBOL."); the exasperation knob is STRESS, never the arena (33rd batch, clause 1) -- 105 collections at stress 3.
WIT="$ROOT/../harness/scripts/gc_witnesses/hb_eval_chain_shim_saves_sigma.sno"
REF="$ROOT/../harness/scripts/gc_witnesses/hb_eval_chain_shim_saves_sigma.ref"
rc=0
TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
for f in "$CENSUS" "$WIT" "$REF" "$ROOT/scrip"; do
  [ -e "$f" ] || { printf 'GATE REFUSE(2) [%s]: %s is absent -- this gate grades nothing it cannot read\n' "$(basename "$0" .sh)" "$f"; exit 2; }
done
printf -- '-- ARM A: every box-entry shim hands r13 over as a DT_S cell (static, NAMED) --\n'
python3 "$CENSUS" > "$TD/census.txt" 2>&1; crc=$?
cat "$TD/census.txt"
# ⛔ ceo 2026-10-09 (CEO-1576, Lon: "stop the show and remove all of them"): the shims this gate censused are DELETED. When the census finds no asm block with an
# indirect jump AND the tree defines none of the five box-entry shims, the population is empty BY DESIGN and the gate passes by name; the guard reads the tree,
# so a shim put back (a .globl of one of the five) re-arms the census and this gate by itself.
if grep -q 'no __asm__ block with an indirect jump' "$TD/census.txt" && ! grep -rqaE '\.globl (rt_proc_enter|rt_proc_enter_named|rt_tiny_record_enter|rt_chain_enter|rt_chain_enter_v)\\n' src/runtime 2>/dev/null; then
  printf '✅ GATE PASS [%s]: no box-entry asm shim remains in the tree (CEO-1576, the C-to-BB removal): rt_proc_enter, rt_proc_enter_named, rt_tiny_record_enter, rt_chain_enter and rt_chain_enter_v are deleted, nothing hands r13 over a C frame any more\n' "$(basename "$0" .sh)"; exit 0
fi
if [ "$crc" != 0 ]; then printf 'GATE REFUSE(2): the census refused rc=%s -- COULD NOT MEASURE\n' "$crc"; exit 2; fi
HEAD_LINE="$(grep -m1 '^CENSUS asm-shim-tag' "$TD/census.txt")"
TAGGED="$(printf '%s' "$HEAD_LINE" | sed -nE 's/.*tagged=([0-9]+).*/\1/p')"
SHIMS="$(printf '%s' "$HEAD_LINE" | sed -nE 's/.*shims=([0-9]+).*/\1/p')"
[ -n "${SHIMS:-}" ] && [ "${SHIMS:-0}" -gt 0 ] || { printf 'GATE REFUSE(2): the census named no shims -- an instrument that lost its reach reads the same as a cured tree\n'; exit 2; }
if [ "$TAGGED" != "$SHIMS" ]; then
  printf 'ARM A RED: %s of %s box-entry shim(s) hand r13 over TAGGED; the RAW rows above are the population still owed\n' "$TAGGED" "$SHIMS"; rc=1
else
  printf 'ARM A PASS: %s of %s box-entry shim(s) hand r13 over as a DT_S cell\n' "$TAGGED" "$SHIMS"
fi
printf -- '\n-- ARM B: the cured road runs, really collects, and answers its oracle --\n'
VERD="$(python3 - "$ROOT/../harness/scripts/corpus_suite_harness.py" "$ROOT/scrip" "$WIT" "$REF" <<'PYA'
import sys, pathlib
sys.path.insert(0, str(pathlib.Path(sys.argv[1]).parent))
import corpus_suite_harness as H
exp = open(sys.argv[4], encoding='utf-8', errors='replace').read()
v = H.classify([sys.argv[2], sys.argv[3]], 300, exp)
print('%s\t%s' % (v.kind, (getattr(v, 'detail', '') or '').replace('\t', ' ').replace('\n', ' ')[:200]))
PYA
)"
VKIND="${VERD%%	*}"; VDET="${VERD#*	}"
case "$VKIND" in
  PASS) printf 'answer: graded PASS by corpus_suite_harness.classify against the ORACLE ref (%s)\n' "$(cat "$REF")" ;;
  HANG|UNPROVEN) printf 'GATE REFUSE(2): the witness graded %s -- COULD NOT MEASURE, never a FAIL (RULES.md FACT RULE, ceo CEO-1098). Re-run this entry. %s\n' "$VKIND" "$VDET"; exit 2 ;;
  *) printf 'ARM B RED: the witness graded %s against its ORACLE ref. %s\n' "$VKIND" "$VDET"; rc=1 ;;
esac
SCRIP_C2BB_TRACE="$TD/tr.tsv" timeout -k 5 300s "$ROOT/scrip" "$WIT" >/dev/null 2>&1
FIRED="$(awk -F'\t' '$1=="chain.eval.v"{n++} END{print n+0}' "$TD/tr.tsv" 2>/dev/null)"
if [ "${FIRED:-0}" -lt 1 ]; then printf 'GATE REFUSE(2): chain.eval.v never fired -- the witness did not reach the tagged shim, so arm B measured NOTHING (non-inert clause, CEO-1044)\n'; exit 2; fi
printf 'road: chain.eval.v fired %s time(s) -- the tagged shim was entered, so this arm is NOT inert\n' "$FIRED"
SCRIP_GC_STRESS=3 SCRIP_GC_MAPS=1 timeout -k 5 600s "$ROOT/scrip" "$WIT" >/dev/null 2>"$TD/maps.txt"
COLL="$(grep -c '^\[GC-WALK\] pop=' "$TD/maps.txt" 2>/dev/null)"
if [ "${COLL:-0}" -lt 1 ]; then printf 'GATE REFUSE(2): the witness collected ZERO times -- a population that never collected refuses (CEO-1044)\n'; exit 2; fi
printf 'collections: %s -- the walker really ran over a stack carrying this shim frame\n' "$COLL"
printf 'raw-spine column: NOT GRADED HERE, and the header says why -- it is bistable on an unchanged binary\n'
printf -- '\npopulation: examined %s box-entry shim(s) over 2 source file(s), 1 witness, %s collection(s) (floor 1)\n' "$SHIMS" "$COLL"
if [ "$rc" = 0 ]; then printf 'GATE PASS(0) [%s]\n' "$(basename "$0" .sh)"
else printf 'GATE FAIL(1) [%s]: arm A %s (%s of %s shim(s) tagged, %s owed), arm B %s\n' "$(basename "$0" .sh)" \
    "$([ "$TAGGED" = "$SHIMS" ] && echo green || echo RED)" "$TAGGED" "$SHIMS" "$((SHIMS - TAGGED))" \
    "$([ "${VKIND:-}" = PASS ] && echo green || echo "RED (${VKIND:-unrun})")"; fi
printf '    tree: SCRIP=%s  measured %s\n' "$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)" "$(date -u +%Y-%m-%dT%H:%MZ)"
exit $rc
