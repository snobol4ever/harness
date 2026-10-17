#!/usr/bin/env bash
# test_gate_gc_the_spine_cell_grid_is_anchored_at_the_region_base.sh -- THE LICENCE FOR A COLLECTOR THAT DOES NOT
# GUESS WHERE A SPINE CELL BEGINS (cto 2026-09-20; row gc-the-planner-gives-a-call-result-live-across-a-safe-
# point-a-mapped-slot-...; law RULES.md FACT RULE THE COLLECTOR GUESSES NOTHING, CEO-812; ARCH-GC section 2b Rule
# 1a and section 7 F1).
#
# WHAT IS BEING HELD HERE, IN ONE SENTENCE.  ARCH-GC says the collector "walks the spine from RSP to its base as an
# array of cells, reading tags: precise, path-independent, no map, no sniff, no guess".  gc_heap.c's gc_walk_words
# does not walk an array -- it steps EIGHT bytes at a time and tries gc_cell_visit at every step, so which words it
# reads as a descriptor depends on where the walk happened to land.  That walk is available to the collector as an
# ARRAY only if the emitter puts every cell start on one 16-byte grid anchored at the region base.  Whether it does
# is a property of EMITTED CODE, which is this seat's lane, and this gate is where it is measured rather than
# assumed.  MEASURED: 403 of 403 decidable SNOBOL4 call sites ON-GRID, 0 OFF-GRID.
#
# ⛔ WHAT A GREEN HERE DOES NOT SAY, WRITTEN FIRST SO NO READER TAKES IT FOR MORE.  It does not say the collector
# walks the grid -- it does not, today.  It does not say the spine is safe: a tag gc_cell_visit does not know is
# still a lost value (that is the DT_X ask, the cfo's file, CFO-141).  It says only that the emitted side supplies
# the anchor and the stride a grid walk would need, so the guessing in gc_walk_words is a CHOICE the collector can
# stop making, and not a necessity forced on it by the code the emitter produces.
#
# ⛔ AND THE ARTIFACT THAT THE FIRST READING OF THIS PROPERTY PRODUCED, kept here because the next reader will meet
# it again: the first grid pass read TWELVE off-grid sites at floor=-8, all in .Lclassspec/.Lclassnm labels.  They
# were not off the grid -- they were not the graph at all.  SNOBOL4 lays `module_init` immediately after main's
# last arm (`main_ω: mov edi,1 / call exit@PLT`), the CFG gives a `call` a fallthrough successor because a call
# returns, `exit` does not return, and main's rsp fixpoint walked into a different activation.  The census now
# drops the fallthrough edge into any label a `call` names.  A census that grades one frame's displacement against
# another frame's code reads defects that are not there, which is the same failure class as reading zero.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
ROOT="$PWD"
# ⛔ THE FRESHNESS GUARD, AND IT IS HERE BECAUSE THIS GATE'S OWN CLASS OF DEFECT REACHED THE GATES BUILT TO CHASE
# IT (the coo, 2026-09-21).  They built at 15:01:58, the cto landed a cure at 15:01:39, they started a 381-arm
# set at 15:03:52 without rebuilding, and 260 arms refused one at a time for that one reason -- while the DARK
# run finished in HALF the wall clock of the honest one, so a seat optimising for a quick gate was being
# rewarded for measuring nothing.  A gate that grades ./scrip with no guard will one day grade a binary older
# than the cure it is testing and call it green.  One line, and the staleness rule itself lives in exactly one
# place (gate_require_fresh in lib_gate.sh) -- this is its calling convention, never a second copy of it.
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
CENSUS="$ROOT/../harness/scripts/util_gc_unmapped_store_census.py"
SCRIP="$ROOT/scrip"
WIT="$ROOT/../harness/scripts/gc_witnesses/hb_mkexpr_unmapped_spine_store.sno"
# ⛔ THE RATCHET FLOOR, MOVED IN THE LANDING THAT EARNED IT (cto 2026-09-21, 5339 -> 6012).  Two cures in one
# landing, A/B'd against HEAD site by site in one process: 683 more call sites decided, 0 LOST, 0 DISAGREEMENTS
# over the 5339 sites both readings decide, off_grid 0 on BOTH sides.
#
# (1) THE FIXED-SYMBOL BASE FACT.  A store through a register loaded from a GOT slot -- `mov rax, qword ptr
# [rip + g_line@GOTPCREL]` then `mov qword ptr [rax + 0], 4` -- addresses a DEFINED SYMBOL, and no symbol is
# defined on a machine stack, so it cannot alias the spine and the anchor shadow survives it.  That is the same
# address-space fact slot_effect already places for a direct `[rip + sym]` store, reached through one
# indirection.  ⛔ AND THE ROAD THE PRIOR FLOOR'S OWN COMMENT PROPOSED WAS MEASURED EMPTY BEFORE IT WAS BUILT:
# it named a points-to fact about a NAMED ALLOCATOR'S RETURN, to be checked against the runtime.  Of the 2044
# unplaceable stores over these witnesses the base register is defined by a call ZERO times; it is a GOTPCREL
# load 1303 times and a rip-relative `lea` 284 times.  The allocator road would have been built and checked for
# nobody.  ⛔ The distinction is sound rather than convenient, and FOUR sites prove it: `lea r, [rsp + K]` puts
# a STACK address in a general register and is still feared, so a rule that placed every lea base would compute
# wrong depths at exactly those four while printing them as discoveries.
#
# (2) THE WIDENING NO LONGER THROWS AWAY THE ANSWER.  Going over DELTA_CAP used to collapse the whole state to
# BOTTOM, and BOTTOM is (rsp=None, rbp=None) -- so the cap destroyed the spine depth and the frame base to bound
# a set whose SHADOWS were what grew.  Enriching the shadows therefore bought grid sites while LOSING reach
# elsewhere: the fact alone took RBP-NOT-A-FRAME-BASE-HERE from 4 shielded stores to 116 across four Icon
# witnesses, a regression hiding underneath a 400-site improvement.  The widening now drops the shadows first
# and the values only if that is not enough, which is sound because a shadow can only ever turn an unknown rsp
# into a known one.  Reach restored to 4, and the grid floor went 5729 -> 6012 on top of it.
#
# ⛔⭐ ARM (b) STILL MEANS off_grid == 0, AND PAD-ALIGNED IS NOT AN AMNESTY.  Ten of the newly graded sites sit
# at floor=-8 residue=8 -- the fingerprint of the arithmetic slip that once announced 142 false OFF-GRID sites --
# so they were taken to the emitted text before anywhere else.  All ten are one shape in one graph: `sub rsp, 8`,
# stores to fixed symbols only, `call`, `add rsp, 8`.  The floor really is off the grid, so calling them ON-GRID
# would be a lie; the eight bytes are a bracketed System V pad with NOTHING STORED INTO THEM, so no descriptor
# cell lives there and calling them emitter defects would be a different lie.  The census names them PAD-ALIGNED
# with the three conditions checked, and arm (c)'s planted 8-byte PUSH still reads 30 OFF-GRID, which is what
# proves the pad verdict did not swallow the detector.
BASE_ON_GRID=6012
POP="${GRID_POP:-$(echo "$ROOT"/../harness/scripts/gc_witnesses/*.icn "$ROOT"/../harness/scripts/gc_witnesses/*.sno "$ROOT"/../harness/scripts/gc_witnesses/*.pl "$ROOT"/../harness/scripts/gc_witnesses/*.raku)}"
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
refuse() { echo "⛔ GATE REFUSED(2) [gc_the_spine_cell_grid_is_anchored_at_the_region_base]: $1"; exit 2; }

[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- build before grading"
[ -f "$CENSUS" ] || refuse "the census $CENSUS is missing -- nothing to grade"
[ -f "$WIT" ] || refuse "the row's witness $WIT is missing"
echo "ARENA SCRIP_HEAP_KB=${SCRIP_HEAP_KB:-64} (the tiny arena of GC testing is the 64 KB floor -- CEO-1146: the old MB=1 knob is a 1024 KB window, eight times the shipped 128 KB, and ran the collector ZERO times on a 3000-string witness; the count of collections is read from the run, never assumed from the knob)"
echo "POPULATION (declared): $(printf '%s\n' $POP | wc -w) witness(es), the shared GC witness set in four"
echo "languages -- MEASURED at 4.8s for the whole gate, which is why it is the WHOLE set and not a sample"
echo "(MODE TENET CONDITION 2: the landing gate is the shared resource; a cheap arm may be wide). GRID_POP= narrows it."

# (a) the instrument grades itself before it grades the tree
st="$(timeout -k 5 120s python3 "$CENSUS" --selftest 2>&1)"; src=$?
n="$(printf '%s\n' "$st" | sed -n 's/^SELFTEST \([0-9]*\)\/\([0-9]*\) arms green/\1 \2/p')"
set -- ${n:-0 0}
if [ "$src" = 0 ] && [ "${1:-0}" -ge 16 ] && [ "${1:-0}" = "${2:-x}" ]; then
  ck ok "(a) the census passes its own selftest, ${1} of ${2} arms, four of them the grid arithmetic"
else
  ck no "(a) the census selftest did not hold (rc=$src): $(printf '%s\n' "$st" | tail -3 | tr '\n' ' ')"
fi

# (b) THE READING: every decidable call site begins its collection on the grid
pop="$(SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-64}" timeout -k 5 900s python3 "$CENSUS" $POP 2>&1)"; prc=$?
[ "$prc" = 2 ] && refuse "the census refused over the declared population: $(printf '%s\n' "$pop" | grep -m1 REFUSED)"
gl="$(printf '%s\n' "$pop" | grep -m1 '^CENSUS unmapped-store GRID calls=')"
ong="$(printf '%s\n' "$gl" | sed -n 's/.* on_grid=\([0-9]*\) .*/\1/p')"
offg="$(printf '%s\n' "$gl" | sed -n 's/.* off_grid=\([0-9]*\) .*/\1/p')"
if [ "${offg:-x}" = 0 ] && [ "${ong:-0}" -ge "$BASE_ON_GRID" ] 2>/dev/null; then
  ck ok "(b) every decidable call site is ON-GRID -- $gl"
elif [ "${offg:-x}" != 0 ]; then
  ck no "(b) $offg call site(s) begin a collection with the spine floor OFF the region-base grid, so no array-of-cells walk is available there and the 8-byte guess is the only road: $(printf '%s\n' "$pop" | grep -m3 'GRID OFF-GRID' | tr '\n' ' ')"
else
  ck no "(b) the decidable population fell to on_grid=${ong:-?} against a baseline of $BASE_ON_GRID -- fewer graded sites is a census losing its reach, not a tree getting better; move the baseline in the landing that earns it. $gl"
fi

# (c) PLANTED: an odd push below the base must be NAMED off-grid, not absorbed
plant="$(timeout -k 5 300s python3 - "$CENSUS" "$SCRIP" "$WIT" <<'PY' 2>&1
import sys, tempfile, importlib.util
census_path, scrip, wit = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("uc", census_path)
uc = importlib.util.module_from_spec(spec); spec.loader.exec_module(uc)
with tempfile.TemporaryDirectory() as wd:
    asm, rep, err = uc.emit_and_read(scrip, wit, wd)
    if err:
        print("PLANT-REFUSED-TO-SET-UP", err); sys.exit(3)
    lines, out, done = open(asm, encoding="utf-8").read().split("\n"), [], False
    for ln in lines:
        out.append(ln)
        if not done and "GCANCHOR .Lgcmap_main" in ln:
            done = True
        elif done and ln.strip().startswith("mov") and "rsp" in ln and "]," in ln:
            out.append("                        push             rax"); done = False
    doctored = asm + ".planted.s"
    open(doctored, "w", encoding="utf-8").write("\n".join(out))
    m, u, ex, refusal, grid, *_rest = uc.census_asm(doctored, rep, "planted")
    if refusal:
        print("PLANT-RESULT REFUSED", refusal); sys.exit(0)
    off = [r for r in grid[0] if r[5] == "OFF-GRID"]
    print(f"PLANT-RESULT off_grid={len(off)} on_grid={sum(1 for r in grid[0] if r[5] == 'ON-GRID')}")
PY
)"
pn="$(printf '%s\n' "$plant" | sed -n 's/^PLANT-RESULT off_grid=\([0-9]*\) .*/\1/p')"
if [ -z "$pn" ]; then
  refuse "(c) THE PLANT DID NOT PRODUCE A VERDICT, AND THAT IS A REFUSAL RATHER THAN A FINDING ABOUT THE CENSUS. Without this branch an empty reading fell through to \${pn:-0} and was graded as the census ABSORBING the planted push -- a defect in the subject reported on the strength of a probe that never ran, which is the same conflation twice in one file. A census REFUSAL of the doctored asm lands here too, and belongs here: the plant then measured nothing about the grid. What came back: $plant"
elif [ "$pn" -gt 0 ] 2>/dev/null; then
  ck ok "(c) PLANTED -- one 8-byte push below the region base takes $pn call site(s) OFF-GRID and the census NAMES them: $plant"
else
  ck no "(c) the census absorbed a planted 8-byte push below the region base and still read every site on-grid ($plant) -- an instrument that cannot fail here cannot pass here either"
fi

# (d) THE SECOND ROAD: the anchor read from the RUNNING collector, not from the text
rt="$(SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-64}" SCRIP_GC_MAPS=3 SCRIP_GC_STRESS=1 timeout -k 5 180s "$SCRIP" "$WIT" 2>&1 | grep -m4 '^\[GC-WALK-CELL\]')"
bad=0; seen=0
while read -r line; do
  [ -z "$line" ] && continue
  cell="$(printf '%s\n' "$line" | sed -n 's/.* cell=0x\([0-9a-f]*\) .*/\1/p')"
  moff="$(printf '%s\n' "$line" | sed -n 's/.* value_bytes=\([0-9]*\) .*/\1/p')"
  [ -z "$cell" ] && continue
  seen=$((seen+1))
  r="$(python3 -c "import sys; print((int(sys.argv[1],16)-int(sys.argv[2]))%16)" "$cell" "$moff")"
  [ "$r" = 0 ] || bad=$((bad+1))
done <<EOF
$rt
EOF
if [ "$seen" -gt 0 ] && [ "$bad" = 0 ]; then
  ck ok "(d) THE SECOND ROAD AGREES: $seen live region base(s) read from the running collector (cell - value_bytes) are 16-aligned, so the grid the static census measures is the grid the walker would step"
else
  ck no "(d) the runtime road did not confirm the anchor: $seen [GC-WALK-CELL] line(s) read, $bad with a region base that is not 16-aligned -- a static grid anchored at an address the collector cannot share is not a licence for anything"
fi

# (e) a zero is only a reading when the unmeasured part is named
if printf '%s\n' "$gl" | grep -q 'undecidable=' && printf '%s\n' "$gl" | grep -q 'unreached=' \
   && printf '%s\n' "$pop" | grep -q 'GRID MEANS EXACTLY THIS AND NOT THAT THE CLASS IS CURED'; then
  ck ok "(e) the grid line carries its undecidable and unreached terms and the census states what a green means -- $(printf '%s\n' "$gl" | sed 's/^CENSUS unmapped-store //')"
else
  ck no "(e) the census printed a grid verdict without naming the sites it could not reach -- zero off-grid over a population nobody could have failed is not a measurement"
fi

# (f) an instrument nobody runs is not an instrument
if grep -q 'test_gate_gc_the_spine_cell_grid_is_anchored_at_the_region_base.sh' "$ROOT/Makefile" 2>/dev/null; then
  ck ok "(f) this gate is named in the Makefile"
else
  ck no "(f) this gate is not named in the Makefile -- a gate in no runner is not measuring (RULES.md THE INSTRUMENT LAWS)"
fi

echo "population: $checks arm(s) graded, $fails FAIL; census rc=$prc"
[ "$fails" = 0 ] && { echo "GATE PASS [gc_the_spine_cell_grid_is_anchored_at_the_region_base]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [gc_the_spine_cell_grid_is_anchored_at_the_region_base]: $fails of $checks arms FAIL"; exit 1
