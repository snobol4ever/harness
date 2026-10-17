#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: the rebus shard below is a runner invoked as an INSTRUMENT FIXTURE and never a board -- it exists only to make corpus_suite_harness.py print its ARENA line, its result is discarded, and without this the one-runner guard makes the gate grade green for the ceo and FAIL(1) for every other seat (the cfo reproduced it as seat cfo; CEO-956, CEO-523)"
# test_gate_gc_the_tiny_arena_is_the_default_of_gc_testing.sh -- LON'S RULE HELD BY ITS MECHANISM, NOT BY DISCIPLINE.
# ⛔⭐ SINCE 2026-09-25 THE SHIPPED DEFAULT IS SPITBOL'S -i1m -d128m (Lon, in-chat to the ceo: "Let's set our default stack size and
# heap size for SCRIP to be the same as SPITBOL."; ceo CEO-1261), so the 128 KB window is again ONLY the GC-testing arena: `make
# test-arena` exports it, and arms 2 and 4 read the shipped default out of gc_heap.c (#define GC_HEAP_KB) rather than repeating a number.
#
# ⛔⭐ THE RULE (Lon 2026-09-19 16:1x CDT, in-chat to the ceo, verbatim: "Actually, for all GC testing all seats should
# use a tiny arena to exasperate all the problems all the time. Do you not agree?"; ceo CEO-931/934/938, RULES.md
# ⛔⭐ THE DEFAULT IS 128 KB SINCE 2026-09-21 17:3x (Lon, in-chat to the ceo: "So let's take the default GC arena down to 128 KB."; ceo CEO-1095). It is COMPILED IN as GC_HEAP_KB, so it travels with the
# binary and the blanket `export SCRIP_HEAP_MB ?= 1` arm 1 refuses is RETIRED rather than re-argued. MEASURED on two allocating witnesses: 128 KB is the PEAK of exasperation, NOT the floor -- icon concat reads
# 1613 collections at 1 MB, 7533 at 256 KB, 21362 at 128 KB, then DOWN to 5429 at 64 KB because the live set stops fitting and the window GROWS. Below the peak, smaller is LESS exasperating. stdout byte-identical
# at every point. SCRIP_HEAP_KB is the knob and it REFUSES below 64 KB rather than clamping, because a run that grades at a size it was not asked for is a false reading.
# § THE INSTRUMENT LAWS, TWENTY-EIGHTH BATCH CLAUSE 2).  The committed window is SCRIP_HEAP_KB (rt_gcheap_init); at 1 MB
# a program collects wherever it allocates a megabyte -- measured on corpus/benchmarks/icon/bench_icnstr_concat_table.icn:
# ⛔ THE PROBE VALUES ARE KB AND MUST CLEAR THE 64 KB FLOOR: they were 1 and 7 when the knob was MEGABYTES, and as KB they abort
# every scrip invocation, which reads as "the harness printed no ARENA line" rather than as "the floor refused" -- a probe that
# cannot run is not a negative result about the thing probed.  256 and 512 are used, both distinct from the 128 default.
# 1614 collections at 1 MB, 788 at 2, 389 at 4, SIX at the shipped 512, stdout byte-identical at every size.  That is the
# exasperation Lon asked for, and it found real defects the same afternoon (SnoRungs 1959/1974 at 1 MB against 1963 at 512;
# IcnRungs 824/826 against 826).
#
# ⛔ WHY A GATE AND NOT A PARAGRAPH: this rule is a DEFAULT, and a default that lives only in prose is one forgetful
# recipe away from being off for everybody, silently, with every board still printing a number.  Three mechanisms carry
# it and this gate holds all three:
#   (1) `make test-arena` IS the pass -- a target-specific export of SCRIP_HEAP_MB_TINY over every gc gate and every
#       frontend smoke, announcing its arena first (`make arena`), mandatory per collector landing, its every red a ROW;
#       and the BLANKET export of the first cut stays out, because a landing gate grades the configuration we ship;
#   (2) corpus_suite_harness.py PRINTS the arena it ran under (the ARENA line and the SUITE_BOARD arena_kb= field),
#       because the same suite legitimately reads two populations on one binary and a number without its arena is not a
#       measurement -- the harness REPORTS, it does not default, since a silent default would change what every existing
#       published number means with no line of evidence anywhere;
#   (3) a gate that measures an ARENA-DEPENDENT quantity pins its own arena in the open, and the set of such gates is
#       DECLARED here, so a pin cannot spread quietly and turn the rule off one gate at a time.
#
# ⛔ THE FAIL-ONCE IS BUILT IN RATHER THAN PLANTED: arms 1, 2 and 4 read the SAME mechanism at THREE arenas (an override,
# the default, and unset) and require the reported value to TRACK.  A hardcoded "1" -- the failure this gate exists to
# catch, an instrument that reports the rule instead of measuring it -- passes a single-arena arm and fails these.
# FAIL_ONCE=1 additionally plants a phantom name into arm 3's declared set and requires arm 3 to red.
# ⭐ EVERY ARM WAS PROVEN BOTH WAYS BEFORE THIS GATE LANDED (ceo, 2026-09-19, plants reverted from backups and the tree
# rebuilt after each): `:=` in place of `?=` on SCRIP_HEAP_MB_TINY reads TINY=3 as 1 and reds arm 1; re-landing the blanket
# `export SCRIP_HEAP_MB ?= 1` reds arm 1 on its own clause; a hardcoded `_arena_mb = "1"` in the harness reds arms 2 AND 4;
# FAIL_ONCE=1 reds arm 3.  Pass-once on the landed tree: 4 of 4 arms, 5 seconds at load ~1.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
G="$(basename "${BASH_SOURCE[0]}" .sh)"
S4E="$(cd "$ROOT/.." && pwd)"
[ -f "$S4E/corpus/tests/rebus/ALL.reb" ] && [ -f "$S4E/corpus/tests/rebus/ALL.ref" ] || { echo "⛔ REFUSE(2) [$G]: no rebus rungs at $S4E/corpus/tests/rebus/ALL.reb -- this gate needs one graded entry to make the harness print a board"; exit 2; }
command -v make >/dev/null || { echo "⛔ REFUSE(2) [$G]: make is arm 1's instrument and it is absent"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
# ⛔ A SCRATCH COPY OF THE REBUS RUNGS, NEVER THE RUNGS ITSELF (ceo CEO-1302 (c), coo 2026-09-27): the fixture exemption no longer
# admits the shared corpus, so the harness refused a shard of corpus/tests/rebus/ALL.reb and printed no ARENA line. The copy, beside
# its ALL.csv and sidecars, sits outside every checkout: the same entries, the same shard, and no board.
cp -a "$S4E/corpus/tests/rebus" "$T/rebus" || { echo "⛔ REFUSE(2) [$G]: could not copy the rebus rungs to a scratch directory"; exit 2; }
SUITE="$T/rebus/ALL.reb"; SREF="$T/rebus/ALL.ref"
RC=0; examined=0
# ARM 1 -- the tiny arena is A PASS OF ITS OWN (make test-arena), it announces its arena, the arena TRACKS its knob,
# and the blanket export that was tried first is NOT back.  ⛔ WHY THE SHAPE CHANGED, MEASURED (ceo CEO-939): the first
# cut of this rule put `export SCRIP_HEAP_MB ?= 1` in the Makefile, so every arm of `make test` inherited a 1 MB window.
# The full 360-arm set then read 326 green / 32 red / 2 refused, and classifying the reds says the shape was wrong, not
# the rule: gates that grade the SHIPPED configuration's behaviour flipped red for an arena nobody ships (gc2's Arizona
# witness and the co-expression frame image are green at 512, red at 1 MB) while other reds were standing reds the export
# would have been blamed for.  A LANDING GATE GRADES WHAT WE SHIP; the tiny arena is the mandatory SECOND pass and every
# red it finds is a ROW.  This arm holds both halves: the pass exists and tracks its knob, and the blanket export stays out.
examined=$((examined + 1))
a1=""; a1bad=0
for want in "" 3; do
    if [ -z "$want" ]; then got=$( (cd "$ROOT" && make --no-print-directory arena 2>/dev/null) | grep -oE '^ARENA SCRIP_HEAP_KB=[0-9]+' | grep -oE '[0-9]+$' ); exp=128; lbl=default
    else got=$( (cd "$ROOT" && make --no-print-directory arena SCRIP_HEAP_KB_TINY="$want" 2>/dev/null) | grep -oE '^ARENA SCRIP_HEAP_KB=[0-9]+' | grep -oE '[0-9]+$' ); exp="$want"; lbl="TINY=$want"; fi
    a1="$a1 ${lbl}->${got:-none}"
    [ "${got:-none}" = "$exp" ] || a1bad=1
done
grep -qE '^test-arena: *export SCRIP_HEAP_KB' "$ROOT/Makefile" || { a1="$a1 [no test-arena export]"; a1bad=1; }
grep -qE '^\.PHONY:.*[ 	]test-arena([ 	]|$|\\)' "$ROOT/Makefile" || { a1="$a1 [test-arena not phony]"; a1bad=1; }
if grep -qE '^export SCRIP_HEAP_MB[ 	]*[?:]?=' "$ROOT/Makefile"; then a1="$a1 [BLANKET EXPORT IS BACK]"; a1bad=1; fi
if [ "$a1bad" = 0 ]; then echo "  arm 1 PASS: the tiny arena is its own pass, announces its arena and tracks its knob ($a1), and the blanket export that took the 360-arm set to 32 red is not back"
else echo "  arm 1 FAIL: the tiny-arena pass is missing, does not announce a tracking arena, or the blanket export is back --$a1 (wanted default->128 TINY=3->3, a test-arena target-specific export, test-arena in .PHONY, and NO bare 'export SCRIP_HEAP_MB' anywhere in the Makefile)"; RC=1; fi
# ARM 2 -- the harness NAMES the arena it ran under, tracking the knob at three arenas.
examined=$((examined + 1))
a2=""; a2bad=0
run_one() { # $1 = arena or "unset"; prints the harness's stdout for ONE graded entry
    if [ "$1" = unset ]; then ( cd "$ROOT" && env -u SCRIP_HEAP_MB -u SCRIP_HEAP_KB S4E_PROGRESS_DB="$T/p.tsv" timeout -k 5 300 python3 ../harness/scripts/corpus_suite_harness.py run "$SUITE" "$SREF" --lang rebus --modes m3 --shard 1/43 2>&1 )
    else ( cd "$ROOT" && SCRIP_HEAP_KB="$1" S4E_PROGRESS_DB="$T/p.tsv" timeout -k 5 300 python3 ../harness/scripts/corpus_suite_harness.py run "$SUITE" "$SREF" --lang rebus --modes m3 --shard 1/43 2>&1 ); fi
}
SHIPPED=$(sed -n 's/^#define[[:space:]]\+GC_HEAP_KB[[:space:]]\+\([0-9]\+\).*/\1/p' "$ROOT/src/runtime/rt/gc_heap.c" | head -1)
[ -n "$SHIPPED" ] || { echo "⛔ REFUSE(2) [$G]: could not read #define GC_HEAP_KB out of gc_heap.c"; exit 2; }
for want in 256 512 unset; do
    exp="$want"; [ "$want" = unset ] && exp="$SHIPPED"
    run_one "$want" > "$T/h_$want.txt" 2>&1
    got=$(grep -oE '^ARENA SCRIP_HEAP_KB=[0-9]+' "$T/h_$want.txt" | grep -oE '[0-9]+$')
    a2="$a2 ${want}->${got:-none}"
    [ "${got:-none}" = "$exp" ] || a2bad=1
done
if [ "$a2bad" = 0 ]; then echo "  arm 2 PASS: every board names the arena it ran under and the line tracks the knob (ARENA read$a2; unset reports the shipped $SHIPPED)"
else echo "  arm 2 FAIL: the harness's ARENA line is missing or does not track the knob (read$a2, wanted 256->256 512->512 unset->$SHIPPED)"; RC=1; fi
# ARM 3 -- the DECLARED set of gates that PIN an arena, so a pin cannot spread and turn the rule off gate by gate.
# ⛔ A PIN IS NOT A DEFAULT, and conflating them made this arm red for a landing that OBEYED the rule (ceo CEO-956):
# `export SCRIP_HEAP_MB=512` overrides its caller and turns the tiny-arena rule OFF for that gate, which is the thing
# that must be declared; `export SCRIP_HEAP_MB="${SCRIP_HEAP_MB:-1}"` YIELDS to any outer value and merely applies the
# rule when the gate is run directly rather than through make. Only the first spelling is a pin and only it is counted.
examined=$((examined + 1))
DECLARED="test_gate_gc_pacing_bounds_a_churning_program.sh test_gate_gc_no_pinned_lifetime_class.sh test_gate_gc_every_credited_bare_poll_site_has_a_zero_collection_witness.sh test_gate_gc_record_type_table_is_rooted_not_blanket_marked.sh test_gate_gc_the_mark_walk_is_a_worklist_not_recursion_per_cell.sh"
[ "${FAIL_ONCE:-0}" = 1 ] && DECLARED="$DECLARED test_gate_that_does_not_exist_planted_by_fail_once.sh"
found=$(cd "$HERE" && grep -lE '^export SCRIP_HEAP_MB=' test_gate_*.sh 2>/dev/null | while read -r f; do grep -qE '^export SCRIP_HEAP_MB="\$\{SCRIP_HEAP_MB:-' "$f" || printf '%s\n' "$f"; done | sort | tr '\n' ' ' | sed 's/ $//')
want=$(printf '%s\n' $DECLARED | sort | tr '\n' ' ' | sed 's/ $//')
if [ "$found" = "$want" ]; then echo "  arm 3 PASS: exactly the declared gate(s) PIN an arena: ${found:-none} (each measures an arena-dependent quantity and says so at its pin; a ${SCRIP_HEAP_MB:-N} default is the rule applied, not a pin, and is not counted)"
else echo "  arm 3 FAIL: the set of gates pinning an arena is not the declared set -- found [${found:-none}] declared [${want:-none}]. A new pin needs its reason at the pin and its name here; a missing one means the rule is off for that gate."; RC=1; fi
# ARM 3b -- EVERY DECLARED PIN MUST HOLD (cfo 2026-09-26, row gc-four-collector-gates-read-red-at-the-128-kb-...). rt_gcheap_init reads
# SCRIP_HEAP_MB and THEN SCRIP_HEAP_KB, which overwrites the window, so `export SCRIP_HEAP_MB=512` alone pins NOTHING once make test-arena
# exports SCRIP_HEAP_KB=128: record_type_table, pacing_bounds and no_pinned_lifetime_class graded the inherited tiny arena for days and read
# RED "at the tiny arena" for the arena, not for the property. A pin holds only beside an `unset SCRIP_HEAP_KB` line. FAIL_ONCE plants a pin
# that does not hold.
examined=$((examined + 1))
defeated=$(cd "$HERE" && for f in $found; do grep -qE '^unset SCRIP_HEAP_KB' "$f" || printf '%s ' "$f"; done)
[ "${FAIL_ONCE:-0}" = 1 ] && defeated="${defeated}test_gate_planted_pin_without_the_unset_by_fail_once.sh "
if [ -z "$defeated" ]; then echo "  arm 3b PASS: every declared pin also unsets SCRIP_HEAP_KB, so the pin holds under the tiny-arena export (${found:-none})"
else echo "  arm 3b FAIL: a declared pin is DEFEATED -- SCRIP_HEAP_KB is read after SCRIP_HEAP_MB and overwrites the window, so these gates grade the inherited arena, not their own: ${defeated% }"; RC=1; fi
# ARM 4 -- the board line itself carries the arena, so an archived board line is readable years later.
examined=$((examined + 1))
b1=$(grep -oE 'arena_kb=[0-9]+' "$T/h_256.txt" | head -1); b7=$(grep -oE 'arena_kb=[0-9]+' "$T/h_512.txt" | head -1); bd=$(grep -oE 'arena_kb=[0-9]+' "$T/h_unset.txt" | head -1)
if [ "$b1" = "arena_kb=256" ] && [ "$b7" = "arena_kb=512" ] && [ "$bd" = "arena_kb=$SHIPPED" ]; then echo "  arm 4 PASS: the SUITE_BOARD line carries its arena and tracks it ($b1 / $b7 / $bd) -- an archived board line stays readable without its command"
else echo "  arm 4 FAIL: the SUITE_BOARD line does not carry a tracking arena_kb= field (read [${b1:-none}] [${b7:-none}] [${bd:-none}])"; RC=1; fi
if [ "$RC" = 0 ]; then echo "GATE PASS(0) [$G]: the tiny arena is the standing default of GC testing by mechanism -- make exports it as a default, every board names the arena it ran under and the name tracks the knob, and exactly the declared arena-dependent gate pins its own (examined $examined arms)"
else echo "GATE FAIL(1) [$G]: the tiny-arena default is not held by its mechanism (examined $examined arms)"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
