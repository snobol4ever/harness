#!/usr/bin/env bash
# ../harness/scripts/test_gate_gc_the_stack_is_completely_accounted_at_every_collection.sh -- THE STACK COMPLETENESS
# GATE (coo, CEO-1099 rank 0, 2026-09-21).
#
# THERE ARE ONLY TWO WAYS TO MAKE A HARDWARE-STACK REGION TRAVERSABLE: DELETE IT OR DECLARE IT.  Eight
# classes sit on the stack at a collection -- emitted box frames, the zeta-SPINE on RSP, gcc C frames, our
# own asm shim frames, jmp_buf register copies, live callee-saved registers, coroutine stacks, and the
# sanctioned driver frames below main.  Today NOTHING accounts for every byte, which is why COMPLETE is an
# opinion rather than a verdict.  This gate is the verdict.
#
# ⛔ IT COUNTS NOTHING OF ITS OWN.  gc_walk_print (src/runtime/rt/gc_heap.c) already prints, behind
# SCRIP_GC_MAPS, the five quantities that ARE completeness -- nomap, notab, i_raw_heap, h_raw_heap,
# s_raw_heap -- on its [GC-WALK] line.  This gate PARSES that line, the way test_gate_no_c_to_bb_ratchet.sh
# parses the gate it depends on.  A second reader of one quantity drifts, and the drift then prints as a
# property of the world rather than of the reader.
#
# ⛔⭐ WHY IT IS A RATCHET AND NOT A PASS/FAIL, AND THE HONEST ANSWER TO "CAN THIS COUNT REACH ZERO BY
# DESIGN?" (test_gate_term_wordref_ratchet.sh's question, which is what makes this shape legitimate):
# YES -- every unaccounted region is DEBT that is to be deleted or declared, and 0 is the intended terminal
# value.  But it is NOT zero today and pretending otherwise would be the false clearance this row exists to
# prevent: MEASURED 2026-09-21 over all 826 icon rungs entries at 64 KB / stress 1, 149 programs carry a
# nonzero completeness counter across 163 DISTINCT NAMED FRAMES and 133648 raw-heap word sites, the largest
# single region being the SPINE of `main` (33633 sites across 100 programs).  So the gate pins the named
# remainder and goes RED when a NEW frame appears or a pinned one grows.
#
# ⛔ WHEN IT GOES RED IT NAMES THE FRAME, NEVER A COUNT.  A count without names cannot be triaged.  The frame
# name is the `graph=` field of the [GC-WALK-SPINE|HEADER|RAW] site lines, which is exactly where each of the
# three raw-heap counters is incremented (gc_heap.c:1130 s_raw_heap->SPINE, :1130 h_raw_heap->HEADER,
# :1147 i_raw_heap->RAW).
#
# ⛔ DEPTH IS PART OF THE VERDICT (CEO-1099).  A shallow witness reads nomap=0 and proves nothing: the ceo
# measured frames=1 nomap=0 i_raw_heap=0 on bench_icnstr_concat_table.icn and that is NOT evidence about deep
# stacks.  This gate DECLARES the depth its population reaches and REFUSES rc=2 if the run does not reach it,
# so a population that quietly got shallower cannot read clean.
# ⛔ AND A POPULATION THAT NEVER COLLECTED REFUSES rc=2 (CEO-1044).
GATE_NAME="test_gate_gc_the_stack_is_completely_accounted_at_every_collection"
. "$(dirname "$0")/lib_gate.sh"
gate_parse_args "$@"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$REPO/.." && pwd)}"
PINS="$REPO/../harness/scripts/gc_stack_accounting_pins.tsv"

gate_require_fresh || exit 2

# ── THE DECLARED POPULATION.  Deep witnesses, named, from the icon rungs.  Chosen by measured frame depth
#    (see the ONE_LINER at the foot), never by looking like they might recurse.
# ⛔⭐ THE POPULATION IS CURATED AGAINST THE RUNTIME'S OWN LINE CAP, AND THAT COST IS REAL.  gc_walk_site
#    stops after GC_WALK_LINE_CAP=48 site lines PER COLLECTION and reports the rest as `suppressed`, so a
#    deep-but-chatty witness names almost nothing: measured 2026-09-21, procedure_every_suspend_replace_7
#    reaches 36 frames over 216 collections and SUPPRESSES 204221 site lines while naming just 2 frames.
#    Witnesses are therefore chosen for DEPTH PER COLLECTION, not depth alone.  Measured candidates:
#      procedure_coexpr_every_replace_1   frames=11 coll=14   suppressed=23     rc=0   <- kept
#      procedure_every_suspend_replace_3  frames=6  coll=72   suppressed=0      rc=0   <- kept
#      procedure_coexpr_suspend_replace_3 frames=6  coll=262  suppressed=5      rc=1   <- kept
#      procedure_every_suspend_replace_7  frames=36 coll=216  suppressed=204221 rc=139 <- REJECTED, crashes
#      procedure_record_every_replace_4   frames=8  coll=2246 suppressed=117287 rc=0   <- REJECTED, chatty
# ⛔ A CRASHING WITNESS IS REJECTED ON PURPOSE: its evidence stops at an unknown point, so a clean reading
#    from it cannot be distinguished from a reading that never got deep enough to see anything.
# GC_STACK_WITNESSES overrides the population FOR THE FAIL-ONCE ARMS ONLY -- a detector arm that has never
# tripped reads as "there was never a bug here", and it is detector arms that fail OPEN (CEO-1099).
# ⛔⭐⭐ A WITNESS TOKEN IS name[:stress] AND THE STRESS IS PER WITNESS, WHICH IS A MEASUREMENT AND NOT A
#   PREFERENCE (coo 2026-09-22).  SCRIP_GC_STRESS=n arms a collection at every n-th allocation
#   (gc_heap.c:283) and the collection is TAKEN AT THE NEXT SAFE POINT -- so a run's collection count is a
#   property of HOW MANY POLLS THE TREE EMITS, and the fleet's own order of work raises that number every
#   landing.  MEASURED: procedure_coexpr_suspend_replace_3 ran 262 collections when this gate landed on
#   2026-09-21 and runs 3222 on origin HEAD today, on identical program text (corpus ALL.icn last touched
#   09-13) -- which took the witness from ~2s to 169s and pushed it straight through a 60s ceiling.
#   ⛔ THE COST IS NOT AN ARENA ARTEFACT, CONTROLLED BEFORE IT WAS BLAMED: the same witness reads 3222
#   collections at BOTH 256 KB (grew=412, 168.9s) and at the 4096 KB cap (grew=0, 171.5s).
#   ⭐ ITS NAME SET IS INVARIANT ACROSS THE STRESS AXIS, WHICH IS THE ONLY REASON ITS STRESS MAY MOVE:
#   measured at stress 1, 4, 8 and 16 (3222/822/428/230 collections, 169/39/20/10s) the observed set is
#   BYTE-IDENTICAL at all four -- {RAW/textgen, SPINE/bingen, SPINE/main, SPINE/testio, SPINE/textgen}.  So
#   stress is a COST knob for THIS witness and not a verdict knob.
#   ⛔ AND IT IS NOT A COST KNOB FOR THE OTHER TWO -- MEASURED BEFORE RELYING ON IT, WHICH IS THE WHOLE
#   REASON IT IS PER WITNESS RATHER THAN GLOBAL: at stress 16 procedure_coexpr_every_replace_1 collapses
#   from frames=11 to frames=1 with an EMPTY name set, and procedure_every_suspend_replace_3 loses
#   SPINE/param and SPINE/stat.  A global stress bump would have bought its speed by deleting the
#   population's depth and three of its pinned names, and a collection COUNT would never have said so.
WITNESSES="${GC_STACK_WITNESSES:-procedure_coexpr_every_replace_1:1 procedure_every_suspend_replace_3:1 procedure_coexpr_suspend_replace_3:16}"
DEFAULT_STRESS="${GC_STACK_STRESS:-1}"        # for a token written without its :stress suffix
CEILING="${GC_STACK_TIMEOUT:-120}"            # per-witness wall-clock ceiling; a hit is a TIMEOUT, never a crash
DEPTH_FLOOR="${GC_STACK_DEPTH_FLOOR:-10}"     # max frames the population MUST reach, or the reading is shallow
# ⛔⭐⭐ THE WITNESS ARENA IS A VARIABLE BECAUSE THE HARD CAP IS COMING AND 64 KB DOES NOT SURVIVE IT.
#   Lon 2026-09-21, in-chat to the ceo, verbatim: "Place a hard cap on the GC HEAP. Do not extend it."  The
#   ceo's working tree already carries it, and MEASURED AGAINST THAT BUILD (read-only, their binary, 2026-09-21
#   19:3x): procedure_coexpr_every_replace_1 and procedure_every_suspend_replace_3 complete at 64, 128, 256 and
#   1024 KB, while procedure_coexpr_suspend_replace_3 ABORTS rc=134 at BOTH 64 and 128 KB -- "[ZHP] HARD CAP
#   REACHED ... THIS REQUEST wanted 32767 payload bytes of block kind 215" -- and completes at 256 and 1024.
#   With the arena hardcoded at 64 this gate would read UNPROVEN(2) on every capped tree FOREVER, because a
#   crashing witness is rejected by design two blocks below.  That is how the gate's own DONE-WHEN refused on
#   the ceo's root today.  ⛔ AND THE DISTINCTION THE CAP FORCES EVERYWHERE: an abort that says HARD CAP
#   REACHED is a CAPACITY verdict about the arena, never a defect in the collector -- an item-4 band that
#   counts it as a grading lost will publish hundreds of false losses the day the cap lands.
#   ⭐ THE DEFAULT MOVES TO 256 AND THE EVIDENCE IS UNCHANGED, WHICH IS THE ONLY REASON IT MAY MOVE: measured
#   here on this tree at 64 and at 256, both read 348 collections across 3 witnesses, max frames 11 against a
#   floor of 10, THE SAME SEVEN NAMES, and PASS(0) -- only the word counts move (testio 879 vs 993, main 715
#   vs 763), which is the spread this gate already refuses to pin.  Set GC_STACK_ARENA_KB=64 to reproduce the
#   pre-cap reading.
ARENA_KB="${GC_STACK_ARENA_KB:-256}"
export RUNGS_EXT=".icn" RUNGS_DIR="$S4E/corpus/tests/icon"
. "$REPO/../harness/scripts/lib_rungs_extract.sh" >/dev/null 2>&1 || {
    echo "GATE UNPROVEN(2) [$GATE_NAME]: ../harness/scripts/lib_rungs_extract.sh is absent -- this gate materializes witnesses through the ONE authority and invents no extractor of its own"; exit 2; }

TD="$(mktemp -d)"; trap 'rm -rf "$TD"' EXIT
LOG="$TD/walk.log"; : > "$LOG"
NCOLL=0; MAXFRAMES=0; SUPPRESSED=0; NRUN=0; TRUNCATED=""; RUNPLAN=""
# ⛔⭐⭐ A CRASH AND A TIMEOUT ARE NOT THE SAME VERDICT, AND COLLAPSING THEM COST THIS GATE ITS OWN RED
#   (coo 2026-09-22, measured).  The single line this loop used to carry -- `[ "$wrc" -ge 128 ] || [ "$wrc"
#   -eq 124 ]` into one UNPROVEN(2) reading "its stack evidence stops at an unknown point" -- fired on origin
#   HEAD 4a1cecc84 against a witness that COMPLETES rc=0 in 169s.  The sentence was FALSE about that run
#   (nothing stopped; the ceiling did), and because the refusal came BEFORE the verdict it HID two genuinely
#   new unaccounted regions this gate exists to name.  A refusal that outranks a finding the instrument
#   ALREADY HOLDS is the instrument law's own failure shape wearing an rc=2.
# ⭐ THE ASYMMETRY THAT REPLACES IT, AND IT IS THE POINT.  "This frame is unaccounted" is an EXISTENCE claim
#   and a partial log settles it, so A TRUNCATED RUN CAN PROVE A RED.  "No unpinned frame exists" is a
#   UNIVERSAL claim over the whole run, so A TRUNCATED RUN CAN NEVER PROVE A GREEN.  The gate therefore KEEPS
#   a timed-out witness's evidence, reds on it when it already names one, and refuses rc=2 only when the
#   truncated population came back clean.
for tok in $WITNESSES; do
    case "$tok" in
        *:*) w="${tok%%:*}"; wstress="${tok##*:}" ;;
        *)   w="$tok";       wstress="$DEFAULT_STRESS" ;;
    esac
    src="$TD/$w.icn"
    rungs_extract_name "$w" "$src" "$TD/$w.ref" >/dev/null 2>&1 || {
        echo "GATE UNPROVEN(2) [$GATE_NAME]: could not materialize witness '$w' from $RUNGS_DIR -- a population that cannot be built is not a clean reading"; exit 2; }
    t0=$(date +%s)
    ( cd "$TD" && env SCRIP_GC_MAPS=1 SCRIP_HEAP_KB="$ARENA_KB" SCRIP_GC_STRESS="$wstress" SCRIP_GC_EXERCISE=1 \
        timeout -k 5 "$CEILING" "$REPO/scrip" "$src" >/dev/null 2>>"$LOG" </dev/null )
    wrc=$?
    el=$(( $(date +%s) - t0 ))
    RUNPLAN="$RUNPLAN $w(stress=$wstress,${el}s,rc=$wrc)"
    if [ "$wrc" -ge 128 ]; then
        echo "GATE UNPROVEN(2) [$GATE_NAME]: witness '$w' CRASHED rc=$wrc (signal $((wrc - 128))) after ${el}s of its ${CEILING}s ceiling at stress=$wstress -- its stack evidence stops at an unknown point, and a clean reading from a truncated run cannot be told from a run that never got deep enough to see anything"; exit 2; fi
    if [ "$wrc" -eq 124 ]; then
        TRUNCATED="$TRUNCATED $w"
        echo "  ⛔ witness '$w' HIT THE CEILING: ${el}s of ${CEILING}s at stress=$wstress. rc=124 is a TIMEOUT, NOT a crash."
        echo "     Its partial evidence is KEPT and still counts toward a RED below; it cannot support a GREEN."
        echo "     Cures in order: lower this witness's :stress suffix (its name set is invariant on that axis,"
        echo "     measured at 1/4/8/16), or raise GC_STACK_TIMEOUT.  Do NOT drop the witness -- it is the sole"
        echo "     source of three pinned names, and shrinking the population to get green is the defect."
    fi
    NRUN=$((NRUN + 1))
done

NCOLL=$(grep -c '^\[GC-WALK\] pop=' "$LOG" 2>/dev/null || echo 0)
MAXFRAMES=$(sed -n 's/^\[GC-WALK\] pop=[^ ]* *frames=\([0-9]*\) .*/\1/p' "$LOG" | sort -n | tail -1)
MAXFRAMES="${MAXFRAMES:-0}"
SUPPRESSED=$(sed -n 's/^\[GC-WALK\] site lines suppressed=\([0-9]*\) .*/\1/p' "$LOG" | awk '{s+=$1} END{print s+0}')

# ⛔ CEO-1044: a population that never collected proves nothing about the collector.
if [ "$NCOLL" -eq 0 ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: $NRUN witness(es) ran and produced ZERO collections -- a population that never collected proves nothing (CEO-1044)"; exit 2; fi
# ⛔ CEO-1099: declare the depth, and refuse a reading that did not reach it.
if [ "$MAXFRAMES" -lt "$DEPTH_FLOOR" ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: population reached only frames=$MAXFRAMES, below the declared floor of $DEPTH_FLOOR -- a shallow stack reads clean and is not evidence about deep ones (CEO-1099)"; exit 2; fi

# ── THE FIVE COMPLETENESS QUANTITIES, summed over every collection, from the runtime's own line.
read -r NOMAP NOTAB IRH HRH SRH <<EOF
$(awk '/^\[GC-WALK\] pop=/ {
    for (i=1;i<=NF;i++){split($i,a,"="); v[a[1]]=a[2]}
    nm+=v["nomap"]; nt+=v["notab"]; ir+=v["i_raw_heap"]; hr+=v["h_raw_heap"]; sr+=v["s_raw_heap"]
} END{printf "%d %d %d %d %d\n", nm+0, nt+0, ir+0, hr+0, sr+0}' "$LOG")
EOF
TOTAL=$((NOMAP + NOTAB + IRH + HRH + SRH))

# ⛔ THE VERDICT LINE MUST CARRY A POPULATION, AND THIS GATE'S WAS READING "(examined 0)" BECAUSE IT NEVER
#   CALLED gate_floor -- the population printed below was true and the machine-readable one was zero, which
#   is the shape lib_gate.sh exists against. The population is COLLECTIONS WALKED, never the number of
#   unaccounted frames: the day this tree is COMPLETE that count is 0, and a floor on it would refuse the
#   very reading the gate is built to earn.
gate_floor "$NCOLL" 1 "collection(s) walked across $NRUN witness(es)"
echo "── population: $NRUN witness(es), $NCOLL collection(s), max frames=$MAXFRAMES (floor $DEPTH_FLOOR) ──"
# ⛔ A NUMBER IS NOT LABELLED UNTIL IT CARRIES THE CONFIGURATION THAT PRODUCED IT (RULES.md INSTRUMENT LAWS).
#    The per-witness stress is part of this gate's reading and used to be invisible, so two runs of the same
#    gate could differ by a knob no line of the output named.
printf "   configuration: arena=%s KB, ceiling=%ss, per-witness%s\n" "$ARENA_KB" "$CEILING" "$RUNPLAN"
echo "── the five completeness quantities, summed over every collection ──"
printf '   nomap=%-7s notab=%-7s i_raw_heap=%-8s h_raw_heap=%-8s s_raw_heap=%-8s  TOTAL=%s\n' \
    "$NOMAP" "$NOTAB" "$IRH" "$HRH" "$SRH" "$TOTAL"
if [ "$SUPPRESSED" -gt 0 ]; then
    echo "   ⛔ $SUPPRESSED site line(s) SUPPRESSED by the runtime's per-collection cap -- THE NAME SET BELOW IS"
    echo "      INCOMPLETE and this gate says so rather than reporting a truncated set as the whole of it."
fi

# ── THE NAMED FRAMES.  cls+graph, from the site lines the same counters emit.
OBS="$TD/observed.tsv"
sed -n 's/^\[GC-WALK-\(SPINE\|HEADER\|RAW\)\] pop=[^ ]* graph=\([^ ]*\) .*/\1\t\2/p' "$LOG" \
    | sort | uniq -c | awk '{printf "%s\t%s\t%s\n", $2, $3, $1}' | sort -k1,1 -k2,2 > "$OBS"
NFRAMES=$(wc -l < "$OBS")
echo "── $NFRAMES distinct named frame(s) carrying unaccounted raw-heap words ──"

if [ ! -f "$PINS" ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: $PINS is absent -- a ratchet with no pins cannot say whether the population grew. Regenerate with the ONE_LINER at the foot of this file."; exit 2; fi

# ⛔⭐⭐ THE cto FALSIFIED THE COLUMN AND THE RATCHET SURVIVED IT -- BOTH HALVES BELONG HERE (2026-09-21).
#    THEIR SWEEP: one binary, never rebuilt, one witness whose CONTENT never changed, varying ONLY THE LENGTH
#    OF THE INVOKING FILESYSTEM PATH, s_raw_heap read 3, 6, 3, 3, 6, 3, 6 -- bistable between two stack
#    layouts, on an input that has nothing to do with the collector, and they retracted a claimed cure of
#    6 down to 3 that was only two samples of those two states.  A gate asserting that column equals zero
#    would flap, and they deleted their own column arm rather than keep a number they could not trust.
#    ⭐ RE-RUN HERE AGAINST THIS GATE'S OWN RATCHET, because a finding about a statistic is not yet a finding
#    about a verdict: procedure_coexpr_suspend_replace_3, one binary, seven invoking-path lengths from 60 to
#    120 characters, s_raw_heap = 1602, 1745, 1602, 1783, 1641, 1642, 1735 -- THE COUNT MOVES BY 11% AND THE
#    NAME SET IS BYTE-IDENTICAL AT ALL SEVEN: {SPINE/main, SPINE/testio, SPINE/textgen}.  The whole gate,
#    run under TMPDIR path lengths 4 and 142, reads PASS(0) at both with every pinned count different
#    (main 756 vs 763, testio 956 vs 994, param 3 vs 4, stat 3 vs 2) and the same seven names.
#    ⛔ SO THE COLUMN IS NOT TRUSTWORTHY AND IS PRINTED, NEVER PINNED; the cto's own recommendation -- key the
#    verdict on a NAMED FRAME rather than a whole-stack sum -- is what this gate already does, and their
#    sweep is the strongest evidence yet that it is the right axis.  If a count is ever pinned it needs a
#    tolerance derived from that spread, not a number copied off one run.
# ⛔⭐ THE RATCHET IS ON THE NAME SET, NOT ON THE COUNTS, AND THAT IS A MEASUREMENT AND NOT A PREFERENCE.
#    Three identical runs of this exact population on one tree (2026-09-21): SPINE/testio read 853, 946 and
#    994; SPINE/main 775, 765, 763; SPINE/gen 16, 18, 18.  The COUNTS ARE NOT REPRODUCIBLE -- they follow
#    where the stress collector happens to fire -- so a count pin would flap red on an unchanged tree, and a
#    gate that cries wolf is worse than no gate.  THE NAME SET WAS BYTE-IDENTICAL ACROSS ALL THREE.  So a NEW
#    FRAME NAME is the regression this gate catches, and the counts are printed as the REMAINDER, labelled,
#    and deliberately not ratcheted.  If a count pin is ever wanted it needs a tolerance derived from this
#    variance, not a number copied off one run.
VIOL=0; TIGHTEN=""
while IFS=$'\t' read -r cls graph n; do
    [ -z "$graph" ] && continue
    if ! awk -F'\t' -v c="$cls" -v g="$graph" '$1==c && $2==g {f=1} END{exit !f}' "$PINS"; then
        printf '  ⛔ %-7s graph=%-40s %7d word(s)   A FRAME NOT IN THE BASELINE IS A NEW UNACCOUNTED REGION\n' "$cls" "$graph" "$n"
        VIOL=$((VIOL + 1))
    else
        printf '     %-7s graph=%-40s %7d word(s)   pinned remainder\n' "$cls" "$graph" "$n"
    fi
done < "$OBS"
# ⭐ A PINNED FRAME THAT VANISHED IS PROGRESS AND MUST STILL BE REPORTED, or the pin lingers as dead slack
#   that a later regression into the same frame would silently inherit.
while IFS=$'\t' read -r cls graph; do
    [ -z "$graph" ] && continue
    awk -F'\t' -v c="$cls" -v g="$graph" '$1==c && $2==g {f=1} END{exit !f}' "$OBS" && continue
    printf '  ⭐ %-7s graph=%-40s       0 word(s)   ACCOUNTED FOR NOW -- drop this pin\n' "$cls" "$graph"
    TIGHTEN="$TIGHTEN $cls/$graph"
done < "$PINS"

echo "── REMAINDER: $TOTAL unaccounted word(s) over $NFRAMES named frame(s). COMPLETE means this reads 0. ──"
echo "   (the word COUNT is informational and varies run to run by design of the stress collector;"
echo "    the NAME SET is what is ratcheted, and it is stable.)"
[ -n "$TIGHTEN" ] && { echo "  ⭐ TIGHTEN AVAILABLE (a pinned frame is accounted for now -- drop it in the commit that earned it):"; for t in $TIGHTEN; do echo "        $t"; done; }

# ONE_LINER -- regenerate the pins; never retype a number you did not produce (RULES.md § TRANSCRIPTION).
#   cd "$S4E_HOME/SCRIP" && bash ../harness/scripts/test_gate_gc_the_stack_is_completely_accounted_at_every_collection.sh --informational 2>&1 \
#     | sed -n 's/^[^A-Z]*\([A-Z][A-Z]*\)  *graph=\([^ ]*\).*/\1\t\2/p' | sort -u > ../harness/scripts/gc_stack_accounting_pins.tsv
# ⛔⭐⭐ DO NOT RUN THAT ONE_LINER TO MAKE A RED GO AWAY, AND IT IS LIVE BAIT TODAY, NOT A HYPOTHETICAL (coo
#   2026-09-22).  On origin HEAD this gate is RED naming RAW/textgen and SPINE/bingen; the one-liner scrapes
#   the SAME output it reds on, so running it right now would write both new frames into the baseline and
#   return PASS(0) having measured nothing and cured nothing -- a false clearance minted by the gate's own
#   documentation.  PINS ARE REGENERATED ONLY IN THE COMMIT THAT EARNED THE TIGHTENING, never to clear a red.
#   ⛔ AND `--informational` IS NOT A FLAG THIS SCRIPT PARSES -- there is no argument handling here at all, so
#   the word is inert and the pipeline scrapes an ordinary run.  Named rather than quietly deleted, because a
#   documented flag that does nothing is how a reader concludes a mode exists that does not.
# ⛔ A TRUNCATED POPULATION MAY NOT RETURN A CLEAN VERDICT -- the asymmetry declared at the witness loop.
#    This is the ONLY place a timeout still refuses, and it refuses for the reason that is actually true:
#    not "the evidence stopped somewhere unknown", but "the surviving evidence named nothing and a partial
#    run cannot carry a universal claim".
if [ -n "$TRUNCATED" ] && [ "$VIOL" -eq 0 ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: witness(es)$TRUNCATED hit the ${CEILING}s ceiling and the surviving population named NO unpinned frame -- a truncated run can prove a red and can never prove a green, so this reads COULD NOT MEASURE and not a clean stack"; exit 2; fi
gate_verdict "$VIOL" "named frame(s) newly unaccounted on the hardware stack"
