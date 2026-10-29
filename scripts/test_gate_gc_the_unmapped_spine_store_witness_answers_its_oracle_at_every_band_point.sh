#!/usr/bin/env bash
# test_gate_gc_the_unmapped_spine_store_witness_answers_its_oracle_at_every_band_point.sh -- THE PROPERTY ARM OF
# THE cto's UNMAPPED-STORE ROW, PROMOTED TO THE BLOCKING SET ON THE DAY IT WENT GREEN (cto 2026-09-20, MODE TENET).
#
# WHY THIS FILE EXISTS RATHER THAN A PROMOTION OF THE ROW'S OWN GATE.  test_gate_gc_a_safe_point_stores_into_a_
# mapped_slot.sh said in writing, in its arm (g) and in its Makefile line, that it "moves to a blocking arm the day
# arm (f) goes green".  Arm (f) went green today on the cfo's DT_X landing (83b8bc9d2).  ⛔ HONOURING THAT SENTENCE
# LITERALLY WOULD HAVE BEEN WRONG TWICE: that gate is still RED at arm (h) BY DESIGN -- (h) is the row's own score
# and exists so the DONE-WHEN cannot go green on another seat's cure -- and its census over 49 witnesses costs
# MINUTES, which under MODE TENET condition 2 is charged to ten seats through an essentially serial set.  So the
# PROPERTY was promoted and the CENSUS was not.  A gate that declares a promotion it should not perform is the same
# defect as a design page stating a property nothing enforces (CTO-99).
#
# WHAT IT GUARDS, AND WHY hq_snobol4's BLOCKING GATE DOES NOT ALREADY.  The class is one they own and cured the
# same evening -- SNO$MKEXPR mints a DT_X name string in the collected heap and gc_cell_visit, the emitted-stack
# cell recognizer, did not list DT_X -- and their test_gate_gc_a_bare_deferred_expression_name_survives_every_
# collection_point.sh walks 200 arms over ten witnesses of it, blocking, in 2.9s.  ⭐ THAT GATE DOES NOT RUN THIS
# WITNESS.  hb_mkexpr_unmapped_spine_store.sno is the cto's, cut for the unmapped-store row, and it reaches the
# class through a different program shape.  Two roads into one class are worth their cost when the cost is
# seconds; and this witness is the one whose store the census NAMES at off=-24 on graph=main, so a red here is
# attributable to a site rather than to a language.
#
# ⛔ THE BAND IS NOT A STRAIGHT LINE THROUGH THE POINTS SOMEBODY ALREADY KNEW ABOUT (CEO-1024; hq_prolog, hq_raku
# and hq_snobol4 each measured a piece of this the same evening).  The witness's historical BASE band was
# `. X X . X . . X . . . .` over stress 0..20, so the X at 8 sits outside the old [0..4] band a cure could have
# closed while leaving the witness wrong; hq_raku's map family lives at stress 1..6 and is INVISIBLE at 8 and
# above; hq_snobol4's ERRTEXT witness is red at 25 while green at 10, 12, 16, 20, 35 and 50.  The thirteen points
# below span all three regions.  BOTH MODES ARE WALKED because the modes diverge in WHERE: hq_snobol4 measured
# their family's base reds as m3 {1,2,4,8} and m4 {1,2}, so an arm that grades m3 alone is a band with a hole in it.
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
WIT="$ROOT/../harness/scripts/gc_witnesses/hb_mkexpr_unmapped_spine_store.sno"
REF="$ROOT/../harness/scripts/gc_witnesses/hb_mkexpr_unmapped_spine_store.ref"
SCRIP="$ROOT/scrip"
LIBDIR="$ROOT/out"
PTS="${GC_BAND:-0 1 2 3 4 5 6 8 10 12 16 20 25}"
checks=0; fails=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then echo "  ok   $2"; else fails=$((fails+1)); echo "  FAIL $2"; fi; }
refuse() { echo "⛔ GATE REFUSED(2) [gc_the_unmapped_spine_store_witness_answers_its_oracle_at_every_band_point]: $1"; exit 2; }

[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- build before grading"
[ -f "$WIT" ] || refuse "the witness $WIT is missing"
[ -f "$REF" ] || refuse "the witness has no committed ref at $REF -- a ref is cut from the oracle, never from our own output"
[ -f "$LIBDIR/libscrip_rt.so" ] || refuse "no out/libscrip_rt.so -- the m4 arm could not be built and would have measured nothing"
# shellcheck source=../harness/scripts/lib_oracle_flags.sh
. ../harness/scripts/lib_oracle_flags.sh 2>/dev/null || refuse "../harness/scripts/lib_oracle_flags.sh did not load -- the oracle is reached by its accessor, never by a PATH probe"
SBL="$(sbl_correctness_bin)" || refuse "the GRADING oracle is not reachable by its accessor; a missing oracle prints a full, plausible, entirely false table"
FLAGS="$(sbl_lang_flags)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
echo "ARENA SCRIP_HEAP_KB=${SCRIP_HEAP_KB:-64} (the tiny arena of GC testing is the 64 KB floor -- CEO-1146: the old MB=1 knob is a 1024 KB window, eight times the shipped 128 KB, and ran the collector ZERO times on a 3000-string witness; the count of collections is read from the run, never assumed from the knob)"
echo "    oracle $SBL $FLAGS (ref re-cut live, this run) · band: $PTS · modes m3 m4"

# (a) THE EXPECTATION IS THE ORACLE'S, RE-CHECKED LIVE.  A committed ref is a SNAPSHOT of the oracle, and a gate
# that grades a drifted snapshot is grading nothing (hq_snobol4's shape, taken whole).  A disagreement REFUSES
# with BOTH answers printed rather than picking one.
cp "$WIT" "$T/w.sno"
( cd "$T" && "$SBL" $FLAGS w.sno > w.live 2>&1 ) || refuse "the oracle did not run the witness cleanly -- nothing here would be graded against anything but our own output"
[ -s "$T/w.live" ] || refuse "the oracle's answer is EMPTY; an empty expectation makes every arm below pass"
want="$(cat "$REF")"
live="$(cat "$T/w.live")"
if [ "$want" = "$live" ]; then
  ck ok "(a) the committed ref still IS the oracle's answer, re-cut this run: '$live'"
else
  refuse "the committed ref and the live oracle DISAGREE -- ref '$want' vs $SBL '$live'. One of them is stale and this gate will not choose; re-cut the ref or fix the witness"
fi

# (b) THE COMPARATOR IS NOT VACUOUS.  ⛔ THE FAILURE THIS PLANTS AGAINST IS THE ONE THAT MAKES EVERY OTHER ARM
# USELESS: if the run produced empty output, or the comparison were against our own answer, every point would read
# `.` and the gate would pass while measuring nothing.  A deliberately wrong expectation must read X everywhere.
bad=""; badn=0
for s in $PTS; do
  got="$(SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-64}" SCRIP_GC_STRESS="$s" timeout -k 5 120s "$SCRIP" "$WIT" 2>/dev/null)"
  if [ "$got" = "${live}-PLANTED-NOT-THE-ORACLE" ]; then bad="$bad ."; else bad="$bad X"; badn=$((badn+1)); fi
done
np="$(printf '%s\n' $PTS | wc -l)"
if [ "$badn" = "$np" ]; then
  ck ok "(b) PLANTED -- graded against a deliberately wrong expectation the same run reads X at all $np points, so a green band below is a comparison that happened"
else
  ck no "(b) a doctored expectation still read '.' at $((np - badn)) of $np points -- the comparator is vacuous and every arm in this gate is worthless: $bad"
fi

# (c) MODE 3, the default road.
m3=""; d3=0
for s in $PTS; do
  got="$(SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-64}" SCRIP_GC_STRESS="$s" timeout -k 5 120s "$SCRIP" "$WIT" 2>/dev/null)"
  if [ "$got" = "$live" ]; then m3="$m3 ."; else m3="$m3 X"; d3=$((d3+1)); fi
done
if [ "$d3" = 0 ]; then
  ck ok "(c) m3: the witness answers the oracle at every point --$m3"
else
  ck no "(c) m3: the witness diverges from the oracle at $d3 of $np points --$m3 (oracle '$live'). ⛔ THIS EXITS 0 WITH A PLAUSIBLE WRONG ANSWER, so no rc-shaped arm anywhere will corroborate it. The cure that closed this band was gc_cell_visit learning DT_X (the cfo, 83b8bc9d2, CFO-138): gc_heap.c spells WHICH KINDS CARRY A HEAP PAYLOAD in five places and a kind missing from the emitted-stack recognizer loses the value silently. Check ../harness/scripts/util_gc_kind_sets.py before theorising."
fi

# (d) MODE 4, because the two modes diverge in WHERE a band is red, never in whether the class exists.
( cd "$T" && timeout -k 5 60s "$ROOT/scrip" --compile --out=w.s w.sno < /dev/null > /dev/null 2>&1 \
    && gcc -m64 -no-pie -rdynamic w.s -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o w.x4 2> w.ld.log ) \
    || refuse "mode-4 compile or link failed, so the m4 arm measured nothing ($(head -c 160 "$T/w.ld.log" 2>/dev/null))"
m4=""; d4=0
for s in $PTS; do
  got="$(SCRIP_HEAP_KB="${SCRIP_HEAP_KB:-64}" SCRIP_GC_STRESS="$s" timeout -k 5 120s "$T/w.x4" 2>/dev/null)"
  if [ "$got" = "$live" ]; then m4="$m4 ."; else m4="$m4 X"; d4=$((d4+1)); fi
done
if [ "$d4" = 0 ]; then
  ck ok "(d) m4: the witness answers the oracle at every point --$m4"
else
  ck no "(d) m4: the witness diverges from the oracle at $d4 of $np points --$m4 (oracle '$live'). The modes MAY diverge as an optimization choice and never as a semantic one, so an m4-only red is a codegen finding and is graded on its own."
fi

# (e) an instrument nobody runs is not an instrument
if grep -q 'test_gate_gc_the_unmapped_spine_store_witness_answers_its_oracle_at_every_band_point.sh' "$ROOT/Makefile" 2>/dev/null; then
  ck ok "(e) this gate is named in the Makefile as a BLOCKING arm -- which is the promotion arm (g) of the row's gate promised in writing, honoured for the PROPERTY and refused for the CENSUS that costs minutes"
else
  ck no "(e) this gate is not named in the Makefile -- a gate in no runner is not measuring (RULES.md THE INSTRUMENT LAWS), and a gate landed unwired is the CEO-381 class"
fi

echo "population: $checks arm(s) graded, $fails FAIL; $np band point(s) x 2 modes"
[ "$fails" = 0 ] && { echo "GATE PASS [gc_the_unmapped_spine_store_witness_answers_its_oracle_at_every_band_point]: $checks of $checks arms hold"; exit 0; }
echo "⛔ GATE RED [gc_the_unmapped_spine_store_witness_answers_its_oracle_at_every_band_point]: $fails of $checks arms FAIL"; exit 1
