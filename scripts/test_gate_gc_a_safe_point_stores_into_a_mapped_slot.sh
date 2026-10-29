#!/usr/bin/env bash
# test_gate_gc_a_safe_point_stores_into_a_mapped_slot.sh -- ARCH-GC SECTION 3's "INTO A MAPPED SLOT" CLAUSE, MADE
# CHECKABLE (cto 2026-09-20; row gc-the-planner-gives-a-call-result-live-across-a-safe-point-a-mapped-slot-...;
# CEO-996 the finding, CEO-1006 the re-lane, CEO-997 the grading rule; law RULES.md FACT RULE THE COLLECTOR
# GUESSES NOTHING, CEO-812).
#
# WHAT THIS GATE IS FOR, AND WHY IT IS RED THE DAY IT LANDS.  ARCH-GC section 3 has read, since the page was
# written, that a safe point is "placed AFTER the call's result has been stored to its mapped slot".  Section 3b is
# the finding that NOTHING HAS EVER ENFORCED THE CLAUSE -- and a design sentence stating a property the emitter is
# never checked against is indistinguishable, to every reader and every instrument, from a property the emitter
# has.  This gate is the thing that makes it distinguishable.  The property is FALSE on this tree, so arm (f) is
# RED and the gate is RED; that is the measurement, not a defect in the gate.  It goes green when the CURE lands.
#
# ⛔ WHY NOT AN rc-SHAPED ARM (CEO-997 on this exact road, CEO-556).  The failure this class produces exits 0 with
# a plausible wrong answer: the collector sweeps a live block, the arena re-issues it IN PLACE, the defer road
# resolves a garbage name and the program prints something.  No rc can tell a cure from a silencing, so the
# property is graded by ORACLE DIFF against a ref cut from BOTH SNOBOL4 oracles, and the POPULATION is graded off
# the emitted text by ../harness/scripts/util_gc_unmapped_store_census.py.
#
# ⛔ WHAT THE CENSUS CANNOT SEE, NAMED SO NOBODY READS ITS ZEROES AS COVERAGE -- AND THE LIST GREW BY A WHOLE ROAD
# ON 2026-09-20.  Class 3 of section 3c -- a raw heap pointer returned in a REGISTER PAIR (cfo CFO-134) -- presents
# no store target, because a frame map describes memory.  302 sites over the shared witness set are UNDECIDABLE
# rather than green: the wired regime enters those boxes through an indirect jump, so no path from the frame's own
# prologue reaches them.  ⛔ AND 6690 STORES -- against 972 the census grades -- SHIELD THEIR VALUE AT A SAFE POINT
# INTO A FIXED SYMBOL (`g_rtccb`, the runtime's caller-saved spill block) RATHER THAN INTO THE FRAME.  No frame map
# can cover those and no planner cure can reach them; their safety rests entirely on the collector's ROOT SET, and
# rt_gc_root_range_add_seamsafe registers that block as a root range which gc_heap.c's only walk over the range
# table SKIPS (`if (g_gc_rrng[i].hi) continue;`).  Measured the same evening: 47 witnesses at the tiny arena,
# 0 slots holding a heap block pointer at any collection, so the hole is LATENT AND NOT LIVE -- reported to the
# cfo, whose file it is.  Arms (d), (i) and (j) exist because "0 members" for Prolog, for Raku and for a language
# the census never read are three different statements and only one of them is clean.
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
WIT="$ROOT/../harness/scripts/gc_witnesses/hb_mkexpr_unmapped_spine_store.sno"
REF="$ROOT/../harness/scripts/gc_witnesses/hb_mkexpr_unmapped_spine_store.ref"
SCRIP="$ROOT/scrip"
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
refuse() { echo "⛔ GATE REFUSED(2) [gc_a_safe_point_stores_into_a_mapped_slot]: $1"; exit 2; }

[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- build before grading"
[ -f "$CENSUS" ] || refuse "the census $CENSUS is missing -- nothing to grade"
[ -f "$WIT" ] || refuse "the row's witness $WIT is missing"
[ -f "$REF" ] || refuse "the witness has no oracle-cut ref at $REF -- a ref is cut from the oracle, never from our output"
echo "ARENA SCRIP_HEAP_KB=${SCRIP_HEAP_KB:-64} (the tiny arena of GC testing is the 64 KB floor -- CEO-1146: the old MB=1 knob is a 1024 KB window, eight times the shipped 128 KB, and ran the collector ZERO times on a 3000-string witness; the count of collections is read from the run, never assumed from the knob)"

# (a) the instrument grades itself before it grades the tree
st="$(timeout -k 5 120s python3 "$CENSUS" --selftest 2>&1)"; src=$?
n="$(printf '%s\n' "$st" | sed -n 's/^SELFTEST \([0-9]*\)\/\([0-9]*\) arms green/\1 \2/p')"
set -- ${n:-0 0}
if [ "$src" = 0 ] && [ "${1:-0}" -ge 12 ] && [ "${1:-0}" = "${2:-x}" ]; then
  ck ok "(a) the census passes its own selftest, ${1} of ${2} arms -- the arithmetic and the refusals are held against hand-built inputs"
else
  ck no "(a) the census selftest did not hold (rc=$src): $(printf '%s\n' "$st" | tail -3 | tr '\n' ' ')"
fi

# (b) the class is REAL and the instrument SEES it -- proven red on the row's witness before any cure
w="$(timeout -k 5 300s python3 "$CENSUS" "$WIT" 2>&1)"; wrc=$?
if [ "$wrc" = 1 ] && printf '%s\n' "$w" | grep -qE '(MEMBER|SPILL-6\.5B) BELOW-REGION .* graph=main .* off=-24 '; then
  ck ok "(b) the census NAMES the row's witness (since 2026-10-04 as the 6.5b result cell it is, on its own SPILL-6.5B line): $(printf '%s\n' "$w" | grep -m1 'off=-24 ' | sed 's/^CENSUS unmapped-store //' | cut -c1-110)"
else
  ck no "(b) the census did not name the witness at off=-24 on graph=main (rc=$wrc) -- SCRIP_GC_MAPS=1 prints [GC-WALK-SPINE] graph=main off=-24 at this very site, so an instrument that misses it is measuring something else"
fi

# (c) PLANTED: the mangling fact of ARCH-GC 6.2d, withheld, must REFUSE rather than read zero
plant="$(timeout -k 5 300s python3 - "$CENSUS" "$SCRIP" "$WIT" <<'PY' 2>&1
import sys, os, subprocess, tempfile, importlib.util
census_path, scrip, wit = sys.argv[1], sys.argv[2], sys.argv[3]
spec = importlib.util.spec_from_file_location("uc", census_path)
uc = importlib.util.module_from_spec(spec); spec.loader.exec_module(uc)
with tempfile.TemporaryDirectory() as wd:
    asm, rep, err = uc.emit_and_read(scrip, wit, wd)
    if err: print("PLANT-REFUSED-TO-SET-UP", err); sys.exit(3)
    doctored = "\n".join(l for l in rep.split("\n") if "graph=main " not in l)
    m, u, ex, refusal, *_rest = uc.census_asm(asm, doctored, "planted")
    print("PLANT-RESULT", "REFUSED" if refusal else f"ACCEPTED members={len(m or [])}", refusal or "")
PY
)"
if printf '%s\n' "$plant" | grep -q '^PLANT-RESULT REFUSED'; then
  ck ok "(c) PLANTED -- withholding main's [GC-MAP] line makes the census REFUSE, not read zero members for main: $(printf '%s\n' "$plant" | sed 's/^PLANT-RESULT REFUSED //' | cut -c1-96)"
elif ! printf '%s\n' "$plant" | grep -q '^PLANT-RESULT '; then
  refuse "(c) THE PLANT DID NOT RUN, AND A PLANT THAT DID NOT RUN IS NOT A VERDICT ABOUT THE CENSUS. It printed no PLANT-RESULT line at all, so the ACCEPTED branch below would have reported a DEFECT IN THE SUBJECT on the strength of a setup that never reached it -- hq_P's law, a null result bounds the PROBE and not the thing probed. THIS ARM PAID FOR THE RULE: the cto grew census_asm's return tuple by one value on 2026-09-21 and this plant, which unpacked exactly six, died on the unpack and printed a census defect that did not exist. The unpack is now tolerant of a growing tuple and the silence is a REFUSAL. What came back: $plant"
else
  ck no "(c) the census ACCEPTED a report whose map label matches no graph -- every site under that label would read green by accident, which is the mangling fact of ARCH-GC 6.2d going unheld: $plant"
fi

# (d) an undecidable site is never folded into a green count
pop="$(timeout -k 5 900s python3 "$CENSUS" "$ROOT"/../harness/scripts/gc_witnesses/*.icn "$ROOT"/../harness/scripts/gc_witnesses/*.sno "$ROOT"/../harness/scripts/gc_witnesses/*.pl "$ROOT"/../harness/scripts/gc_witnesses/*.raku 2>&1)"; prc=$?
[ "$prc" = 2 ] && refuse "the census refused over the shared witness set: $(printf '%s\n' "$pop" | grep -m1 REFUSED)"
bad=0
while read -r lang mem und unrd; do
  [ -z "${lang:-}" ] && continue
  if [ "$mem" = 0 ] && { [ "$und" != 0 ] || [ "${unrd:-0}" != 0 ]; }; then
    printf '%s\n' "$pop" | grep -q "LANG $lang .*ZERO MEMBERS HERE IS NOT A CLEAN READING" || bad=$((bad+1))
  fi
done <<EOF
$(printf '%s\n' "$pop" | sed -n 's/^CENSUS unmapped-store LANG \([a-z]*\) witnesses=[0-9]* members=\([0-9]*\) undecidable=\([0-9]*\) shielded=[0-9]* unread_static=\([0-9]*\).*/\1 \2 \3 \4/p')
EOF
if [ "$bad" = 0 ]; then
  ck ok "(d) every language reading zero members over an UNMEASURED population says so in its own line, on BOTH roads -- undecidable sites and stores shielded into a fixed symbol -- $(printf '%s\n' "$pop" | grep -c '^CENSUS unmapped-store LANG ') language rows printed"
else
  ck no "(d) $bad language row(s) printed zero members over an unmeasured population without saying so -- that is a zero nobody could have failed"
fi

# (e) THE RATCHET, PER WITNESS AND NEVER A TOTAL.
# ⛔ IT WAS A TOTAL UNTIL 2026-09-20 21:4x AND THAT WAS A DEFECT hq_snobol4 MEASURED AGAINST THIS GATE BEFORE
# LANDING RATHER THAN DISCOVERING AFTERWARDS.  The population is a DIRECTORY GLOB over ../harness/scripts/gc_witnesses, so
# their nine oracle-cut siblings arriving would have moved members from 162 to 192 and this arm would have printed
# THE CLASS GREW -- naming a compiler regression it never measured, over nine files that had just been added.  A
# well-formed answer to a question nobody asked.  A TOTAL CANNOT TELL A COMPILER REGRESSION FROM A FILE ARRIVING,
# and only a name set can; which is this row's own NAME-NEVER-A-COUNT rule applied one level down from where the
# census first applied it.  The baseline is ../harness/scripts/gc_unmapped_store_baseline.tsv, one line per witness, rewritten
# by `util_gc_unmapped_store_census.py <witnesses> --write-baseline <that file>` in the landing that earns a move.
BASE="$ROOT/../harness/scripts/gc_unmapped_store_baseline.tsv"
[ -f "$BASE" ] || refuse "the per-witness baseline $BASE is missing -- a ratchet with no floor is not a ratchet"
rat="$(printf '%s\n' "$pop" | timeout -k 5 60s python3 "$ROOT/../harness/scripts/util_gc_unmapped_store_ratchet.py" "$BASE" 2>&1)"
rl="$(printf '%s\n' "$rat" | grep -m1 '^RATCHET ')"
rmoved="$(printf '%s\n' "$rl" | sed -n 's/.* moved=\([0-9]*\) .*/\1/p')"
rgone="$(printf '%s\n' "$rl" | sed -n 's/.* gone=\([0-9]*\) .*/\1/p')"
rnew="$(printf '%s\n' "$rl" | sed -n 's/.* new=\([0-9]*\)$/\1/p')"
sum="$(printf '%s\n' "$pop" | grep -m1 '^CENSUS unmapped-store witnesses=')"
mem="$(printf '%s\n' "$sum" | sed -n 's/.* members=\([0-9]*\) .*/\1/p')"
und="$(printf '%s\n' "$sum" | sed -n 's/.* undecidable=\([0-9]*\) .*/\1/p')"
if [ "${rmoved:-x}" = 0 ] && [ "${rgone:-x}" = 0 ] && [ "${rnew:-x}" = 0 ]; then
  ck ok "(e) THE RATCHET HOLDS PER WITNESS -- $rl, totalling members=$mem undecidable=$und"
elif [ "${rmoved:-0}" != 0 ]; then
  ck no "(e) A WITNESS'S OWN READING MOVED, which is the thing this row exists to catch and is NOT a file arriving: $(printf '%s\n' "$rat" | grep '^MOVED ' | head -3 | tr '\n' ' ')"
elif [ "${rgone:-0}" != 0 ]; then
  ck no "(e) a witness left the population without its baseline line leaving with it -- a ratchet cannot grade what it cannot see: $(printf '%s\n' "$rat" | grep '^GONE ' | head -3 | tr '\n' ' ')"
else
  ck no "(e) ${rnew:-?} WITNESS(ES) ARRIVED THAT THE BASELINE DOES NOT KNOW. ⛔ THIS IS A FILE ADDITION AND NOT A COMPILER REGRESSION, and the arm says so rather than naming a cause it did not measure (hq_snobol4 2026-09-20, who measured exactly this against this gate before landing). Add the line(s) to ../harness/scripts/gc_unmapped_store_baseline.tsv in the same commit that lands the witness, or rewrite the file with --write-baseline: $(printf '%s\n' "$rat" | grep '^NEW ' | sed 's/^NEW //' | head -12 | tr '\n' ';')"
fi

# (e2) THE 6.5b RESULT CELLS ARE COUNTED APART AND NEVER DROPPED (the cfo's ruling of 2026-10-04 on the coo's bisect of
# the arm (e) move to c869d57c1): the census no longer counts the two stores of the result-preserving poll as members
# or as shielded stores, so this arm fails the day the census stops printing how many it set apart.
sp="$(printf '%s\n' "$pop" | grep -m1 '^CENSUS unmapped-store SPILL-6.5B-SUMMARY ')"
if [ -n "$sp" ]; then
  ck ok "(e2) the ARCH-GC 6.5b result cells are counted apart and printed, never folded into the members: $(printf '%s\n' "$sp" | cut -d' ' -f3-6)"
else
  ck no "(e2) the census printed no SPILL-6.5B-SUMMARY line -- the result cells the members no longer count would go uncounted"
fi

# (i) THE CENSUS'S OWN REACH IS A MEASUREMENT AND NOT AN ASSUMPTION.
# ⛔ THIS ARM EXISTS BECAUSE THE SELFTEST ARM THAT PROVED THE BLIND SPOT IS THE ARM THAT SHOULD HAVE COUNTED IT.
# `disp_of refuses a rip-relative operand` has held since this census landed, with `[rip + g_rtccb+40]` as its very
# example -- the refusal is correct, because a frame map describes memory IN A FRAME and no planner cure can reach
# a fixed symbol.  What was never measured is the CONSEQUENCE: a language whose shielding rides that road reads
# `members=0 undecidable=0`, which is spelled exactly like clean.  Raku read CLEAN AND DECIDED COMPLETELY in three
# published cursor entries on EIGHT graded frame stores while 207 of its shielded stores went unread, and the
# language it certified was losing 65 gradings at SCRIP_GC_STRESS=16 in another seat's rungs the same evening.
# Over the shared witness set the two roads are 972 graded against 6690 unread: this census grades about an
# eighth of the shielding at its own safe points, and now says so on every run.
reach="$(printf '%s\n' "$pop" | grep -m1 '^CENSUS unmapped-store REACH ')"
rst="$(printf '%s\n' "$reach" | sed -n 's/.* static_shielded=\([0-9]*\) .*/\1/p')"
rfr="$(printf '%s\n' "$reach" | sed -n 's/.* frame_shielded=\([0-9]*\) .*/\1/p')"
# ⛔⭐ STRENGTHENED 2026-09-21 ON CEO-1042's CONDITION, AND THE OLD FORM OF THIS ARM IS WHY IT NEEDED IT.  It
# grepped for `symbol=g_rtccb ` and passed on the presence of ONE line naming ONE SYMBOL over 6825 stores.  A symbol
# is a SIZE, not a name: it cannot say WHICH WORD a collector would have to visit, so this arm certified that the
# road was named while the naming could not adjudicate anything.  Keyed by WORD the whole road is THREE -- g_rtccb+40,
# g_rtccb+56, g_rtccb+64, slots 5, 7 and 8 of rtx/rtcc.h, r8/r10/r11 spilled at x86_asm.h 386-389 -- each at all 2275
# safe points.  ⛔ AND THE ARM NOW CHECKS THE ACCOUNTING RATHER THAN THE PRESENCE: the per-word stores must SUM to
# static_shielded exactly.  Without that a word silently dropped from the naming reads identically to a road with
# no such word in it, which is this gate's own defect class one level down.  The census's own summary line carries
# the totals so the two roads cannot be computed from different readings.
words="$(printf '%s\n' "$pop" | grep -m1 '^CENSUS unmapped-store UNREAD-ROAD symbols=')"
wsum="$(printf '%s\n' "$words" | sed -n 's/.* stores=\([0-9]*\) .*/\1/p')"
wn="$(printf '%s\n' "$words" | sed -n 's/.* words=\([0-9]*\) .*/\1/p')"
nmd="$(printf '%s\n' "$pop" | grep -c '^CENSUS unmapped-store UNREAD-ROAD symbol=')"
# ⛔ RE-CUT 2026-10-09 BY hq_collector, ON hq_runtime's 4daa72f89 (the rtcc bracket carries r9 alone): the r8, r10 and
# r11 write-backs into g_rtccb retired, so the static road is EMPTY, not unread -- unread_static read 0 on all 104
# baseline rows and the old arm, which demanded a non-empty road, went red on a win. A CLOSED road passes only on
# an INDEPENDENT reading: the census's own accounting reads 0 words summing to 0, its frame road is non-empty (it
# was looking), and the emitted text of hb_aggt.icn -- 57 unread static stores in the old baseline -- carries no
# rip-relative store at all. A census blind to a road that still exists reads 0 here and fails on the third clause.
ripst=x
if [ "${rst:-x}" = 0 ]; then
  ags="$(mktemp --suffix=.s)"
  timeout -k 5 120 "$ROOT/scrip" --compile --out="$ags" "$ROOT/../harness/scripts/gc_witnesses/hb_aggt.icn" < /dev/null > /dev/null 2>&1 && [ -s "$ags" ] && ripst="$(grep -cE '^[[:space:]]*mov[a-z]*[[:space:]]+[a-z]+ ptr \[rip \+ [^]]+\],' "$ags")"
  rm -f "$ags"
fi
if [ "${rst:-x}" = 0 ] && [ "${wsum:-x}" = 0 ] && [ "${wn:-x}" = 0 ] && [ "${nmd:-x}" = 0 ] && [ "${rfr:-0}" -gt 0 ] && [ "$ripst" = 0 ]; then
  ck ok "(i) the static road is CLOSED, read independently: the census accounts 0 words summing to 0 while reading frame_shielded=$rfr, and the emitted text of hb_aggt.icn (57 unread static stores in the old baseline) carries 0 rip-relative stores"
elif [ -n "${rst:-}" ] && [ "${rst:-0}" -gt 0 ] && [ "${wsum:-x}" = "${rst:-y}" ] && [ "${wn:-0}" = "${nmd:-x}" ] && [ "${wn:-0}" -gt 0 ]; then
  ck ok "(i) the census reports its OWN reach and NAMES the unread road BY WORD, and the naming ACCOUNTS FOR ALL OF IT -- frame_shielded=$rfr static_shielded=$rst, $wn word(s) named summing to $wsum: $(printf '%s\n' "$pop" | grep -o '^CENSUS unmapped-store UNREAD-ROAD symbol=[A-Za-z_][A-Za-z0-9_.$+]*' | sed 's/.*symbol=//' | tr '\n' ' ')-- a zero from this census is now a zero with its denominator beside it, and the denominator is a NAME SET rather than a size"
else
  ck no "(i) the census printed no REACH line, or its per-word naming does not ACCOUNT for the road -- static_shielded=${rst:-?} against ${wn:-?} word(s) summing to ${wsum:-?}, ${nmd:-?} word line(s) printed. An instrument that silently drops a whole shielding road, or names part of one and reports the whole, is success reported while it is not looking, which is the failure THE INSTRUMENT LAWS exist to catch: $reach"
fi

# (j) PLANTED: THE RATCHET GRADES THE REACH COLUMN, so coverage MOVING from the graded road to the unread one is a
# red rather than an improvement.  ⛔ THAT MOVE IS INVISIBLE TO EVERY OTHER NUMBER HERE: when a store stops being
# shielded into the frame and starts being shielded into a fixed symbol, `members` falls and `shielded` falls, and
# arms (e) and (h) both read a win.  The plant doctors the FIFTH COLUMN ALONE of one baseline row and requires MOVED.
# ⛔⭐ THE PLANT IS DIFFERENTIAL AND NOT ABSOLUTE, CORRECTED BY THE cto 2026-09-22 AFTER IT GRADED THE WRONG THING FOR
# 92 COMMITS.  It asserted an ABSOLUTE `MOVED == 1`, which is true only while the tree's own reading matches the
# baseline exactly -- so on a drifted tree it reads the DRIFT (17 rows on this origin, every one of them .icn,
# every one shielded UP and unread_static UP) and reds for a reason that has nothing to do with the detector it
# exists to prove.  Worse in the other direction: the instant anyone re-bases the floor the absolute form goes
# GREEN WITHOUT THE DETECTOR EVER HAVING BEEN EXERCISED, which is an instrument reporting success while doing
# nothing -- the failure THE INSTRUMENT LAWS exist to catch, in the arm written to catch it.  The plant now
# doctors a row that has NOT already moved and requires exactly ONE MORE than the undoctored reading, with the
# doctored witness NAMED; and when no unmoved row exists it REFUSES rather than grading, because a plant that
# cannot be run has not passed.
mvf="$(mktemp)"; rdf="$(mktemp)"; pl5="$(mktemp)"; trap 'rm -f "$mvf" "$rdf" "$pl5"' EXIT
printf '%s\n' "$rat" | sed -n 's/^MOVED \([^ ]*\) .*/\1/p' > "$mvf"
printf '%s\n' "$pop" | sed -n 's/^CENSUS unmapped-store WITNESS \([^ ]*\) .*/\1/p' > "$rdf"
cand="$(awk -F'\t' -v mvf="$mvf" -v rdf="$rdf" '
  FILENAME==mvf { if ($0!="") mv[$0]=1; next }
  FILENAME==rdf { if ($0!="") rd[$0]=1; next }
  /^#/ { next }
  NF>=5 && !mv[$1] && rd[$1] { print $1; exit }' "$mvf" "$rdf" "$BASE")"
p4="$(mktemp)"; cut -f1-4 "$BASE" > "$p4"
printf '%s\n' "$pop" | timeout -k 5 60s python3 "$ROOT/../harness/scripts/util_gc_unmapped_store_ratchet.py" "$p4" >/dev/null 2>&1; p4rc=$?
rm -f "$p4"
if [ -z "$cand" ]; then
  ck no "(j) THE PLANT COULD NOT BE RUN AND THAT IS A REFUSAL, NOT A PASS: every baseline witness present in this reading has ALREADY MOVED (moved=${rmoved:-?} of $(grep -vc '^#' "$BASE") baseline row(s)), so there is no unmoved row to doctor and the fifth column's detector cannot be exercised on this tree at all. Cure arm (e) first -- a floor re-based while this plant is blind is how an exemption list becomes the new floor"
elif ! printf '%s' "${rmoved:-x}" | grep -q '^[0-9][0-9]*$'; then
  ck no "(j) the undoctored ratchet reading arm (e) took carries no numeric moved= count (${rmoved:-?}), so a differential plant has no base to differ from -- the ratchet REFUSED or printed no summary line"
else
  awk -F'\t' -v w="$cand" 'BEGIN{OFS="\t"} !/^#/ && NF>=5 && $1==w {$5=$5+1} {print}' "$BASE" > "$pl5"
  pout="$(printf '%s\n' "$pop" | timeout -k 5 60s python3 "$ROOT/../harness/scripts/util_gc_unmapped_store_ratchet.py" "$pl5" 2>&1)"
  pmv="$(printf '%s\n' "$pout" | grep -c '^MOVED ')"
  pnm="$(printf '%s\n' "$pout" | grep -c "^MOVED $cand ")"
  pwant="$((rmoved + 1))"
  if [ "${pmv:-0}" = "$pwant" ] && [ "${pnm:-0}" = 1 ] && [ "${p4rc:-0}" = 2 ]; then
    ck ok "(j) PLANTED BOTH WAYS, DIFFERENTIALLY -- doctoring the reach column of ONE UNMOVED row ($cand) takes MOVED from $rmoved to $pmv and NAMES that witness, and a four-column baseline is REFUSED(2) rather than silently graded on four of its five facts"
  else
    ck no "(j) the ratchet did not grade its fifth column: doctoring UNMOVED row $cand read MOVED=${pmv:-?} (want $pwant, one more than the undoctored $rmoved) and named it ${pnm:-?} time(s) (want 1), four-column baseline rc=${p4rc:-?} (want 2). A floor that cannot see shielding move to the unread road reads that loss of coverage as a win"
  fi
fi

# (f) THE PROPERTY ITSELF, graded by ORACLE DIFF and not by rc (CEO-997), over a band that goes WELL ABOVE 5.
# ⛔ THE BAND WAS [0 1 2 3 4] UNTIL 2026-09-20 21:3x AND THAT WAS A DEFECT IN THIS GATE, not a conservative choice
# (CEO-1024, hq_raku's measurement: the raku rungs at the tiny arena loses 65 gradings over 36 DISTINCT PROGRAMS
# at SCRIP_GC_STRESS=16 that a 1-3-5 band calls green -- every one exit 0, no diagnostic, plausible wrong answer).
# A band that ends where the defects start does not measure the tree, it measures the band. The cto's own A/B/A at
# CTO-101 had already read this witness at twelve points and its BASE band is `. X X . X . . X . . . .` -- the X at
# stress 8 sits OUTSIDE the old band, so a cure that closed 0..4 alone would have turned this arm green with the
# witness still wrong. The points below are that measurement's own band PLUS 25, which hq_snobol4 added on
# their own evidence the same evening: their ERRTEXT witness is RED at m4 stress 25 while GREEN at 10, 12, 16,
# 20, 35 and 50, so a band is not made honest by going higher -- it is made honest by not being a straight line
# through the points somebody already knew about. Thirteen points, 3.2 seconds of the gate's 4.6.
want="$(cat "$REF")"
diffs=0; band=""
for s in 0 1 2 3 4 5 6 8 10 12 16 20 25; do
  got="$(SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-64}" SCRIP_GC_STRESS=$s timeout -k 5 120s "$SCRIP" "$WIT" 2>/dev/null)"
  if [ "$got" = "$want" ]; then band="$band ."; else band="$band X"; diffs=$((diffs+1)); fi
done
if [ "$diffs" = 0 ]; then
  ck ok "(f) THE PROPERTY HOLDS: the witness answers its oracle-cut ref at every stress point in the band [0 1 2 3 4 5 6 8 10 12 16 20 25] --$band"
else
  ck no "(f) THE PROPERTY IS FALSE: the witness diverges from its oracle-cut ref at $diffs of 13 stress points --$band (want '$want'). ⛔ AND THE CURE THAT CLOSES THIS BAND IS NOT THIS ROW'S -- SAID HERE SO THE NEXT READER IS NOT SENT AT THE WRONG FILE (hq_snobol4 2026-09-20, VERIFIED A/B/A by the cto): gc_heap.c spells 'which kinds carry a heap payload' TWICE and the two copies disagree by two kinds -- gc_visit_one (the heap visitor) handles DT_X and DT_SNUL, gc_cell_visit (the emitted-stack cell recognizer) does not. Adding both to gc_cell_visit takes this witness from '. X X . X . . X . . . .' to TWELVE OF TWELVE GREEN over stress 0..20, and reverting restores the base band byte for byte. That is the cfo's file and an ASK, not this row's landing. ⭐ WHAT THIS ROW STILL OWNS, AND WHY THE CENSUS IS NOT INVALIDATED BY THAT: a store outside the map is NECESSARY BUT NOT SUFFICIENT for loss, because gc_walk_words tries gc_cell_visit on every below-base word first -- so the 162 members are safe points whose correctness rests on a TAG-RECOGNIZER HEURISTIC instead of on the frame map ARCH-GC section 3 says should cover them. When the recognizer fix lands this arm goes green with the members still at 162, and THAT reading -- green band, 162 unmapped stores -- is exactly the residual risk this row exists to remove."
fi

# (h) THE ROW'S OWN QUESTION, so this DONE-WHEN cannot go green on somebody else's cure
cells="$(printf '%s\n' "$pop" | sed -n 's/^CENSUS unmapped-store SPILL-6.5B-SUMMARY .* cells_unmapped=\([0-9]*\) .*/\1/p' | head -1)"
memh=$(( ${mem:-0} + ${cells:-0} ))
if [ "${mem:-x}" = 0 ] && [ "${cells:-x}" = 0 ]; then
  ck ok "(h) NO safe point stores outside its graph's frame map -- ARCH-GC section 3's clause is TRUE of this emitter, not merely written down"
else
  ck no "(h) $memh safe point store(s) still land outside their graph's frame map ($mem member(s) + ${cells:-?} 6.5b result-cell store(s), counted apart from the per-witness ratchet and never apart from this arm). ⛔ THIS ARM EXISTS BECAUSE ARM (f) ALONE WOULD LIE: the witness's band is closed by adding DT_X and DT_SNUL to gc_cell_visit (the cfo's file, measured 12/12 by the cto), and on that day (f) goes GREEN WITH THESE $mem STORES UNTOUCHED. A DONE-WHEN that a different seat's cure can satisfy is not this row's DONE-WHEN. ⭐ AND THE ROW'S SECOND CLAUSE IS REFUTED BY THIS VERY NUMBER (hq_snobol4 2026-09-20, confirmed here): 'the emitter REFUSES a safe point that stores outside the map' cannot be the enforcement floor, because storing outside the map is the ORDINARY CASE for the inter-frame gap population -- $mem of the shielded stores over the shared witness set do it, on programs that answer their oracles. A refusal keyed on that predicate does not fail narrowly, it fails BROADLY and on green programs. What is left is the PLANNER clause alone: give every call result that can be live across a safe point a slot the map covers."
fi

# (g) an instrument nobody runs is not an instrument
if grep -q 'test_gate_gc_a_safe_point_stores_into_a_mapped_slot.sh' "$ROOT/Makefile" 2>/dev/null; then
  ck ok "(g) this gate is named in the Makefile, as a REPORTED arm -- run and classified by every seat, blocking none of them while arm (h) is red BY DESIGN (CEO-513 declare-when-you-hold-one-out, CEO-463 a known-red blocking arm makes every seat pay for one open row). ⛔ THE PROMOTION THIS ARM ONCE PROMISED HAS BEEN PAID, AND NOT THE WAY IT WAS WORDED: arm (f) went green 2026-09-20 on the cfo DT_X landing, and what went BLOCKING is the PROPERTY ALONE -- test_gate_gc_the_unmapped_spine_store_witness_answers_its_oracle_at_every_band_point.sh, ~0.8s, both modes, the ref re-cut from the oracle every run and a vacuous comparator planted against. THE CENSUS DID NOT GO WITH IT: it costs minutes over 49 witnesses and MODE TENET condition 2 charges that to ten seats through an essentially serial set, and arm (h) is red by design so this gate cannot be blocking at all. A gate that declares a promotion it should not perform is the same defect as a design page stating a property nothing enforces (CTO-99)"
else
  ck no "(g) this gate is not named in the Makefile -- a gate in no runner is not measuring (RULES.md THE INSTRUMENT LAWS), and a gate landed unwired is the CEO-381 class (CEO-513)"
fi

echo "population: $checks arm(s) graded, $fails FAIL; census over the shared witness set rc=$prc, witness rc=$wrc"
[ "$fails" = 0 ] && { echo "GATE PASS [gc_a_safe_point_stores_into_a_mapped_slot]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [gc_a_safe_point_stores_into_a_mapped_slot]: $fails of $checks arms FAIL"; exit 1
