#!/usr/bin/env bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_gc_a_bare_deferred_expression_name_survives_every_collection_point.sh
#   hq_snobol4 2026-09-20, row `snobol4-the-pattern-replacement-class-prints-a-wrong-answer-under-collection-
#   and-changes-its-fingerprint-per-poll-set` (ceo CEO-979 GC-only, MODE TENET condition 1).
#
# WHAT IT GATES.  A SNOBOL4 pattern variable whose whole value is a BARE DEFERRED EXPRESSION (`lvl2 = *lvl1`)
# makes `SNO$MKEXPR` mint a `DT_X` name string with `rt_heap_strdup_c` IN THE COLLECTED HEAP, and the defer road
# reads it back after the allocating call's safe point.  If a collection lands between the mint and the read, the
# block is reclaimed IN PLACE (address identical at mint and at use in all seven readings) and `NV_GET_fn` answers
# the null string, so THE WHOLE MATCH FAILS SILENTLY WITH rc=0.  This gate walks a STRESS BAND at the tiny arena
# and grades every point against the ORACLE, because the failure is a plausible wrong answer and no rc can see it.
#
# ⛔ WHY THE REFS ARE CUT LIVE FROM THE ORACLE INSTEAD OF BEING COMMITTED BESIDE THE WITNESSES.  Two reasons, and
# the second is the one that decided it.  (1) A committed `.ref` is a snapshot of the oracle, and a gate that
# re-cuts cannot drift from it.  (2) ⭐ MEASURED 2026-09-20, BEFORE LANDING: putting these ten witnesses in
# `../harness/scripts/gc_witnesses/` would have moved `test_gate_gc_a_safe_point_stores_into_a_mapped_slot.sh`'s ratchet from
# members=162 undecidable=42 to members=192 undecidable=50, because that arm's population is a DIRECTORY GLOB
# (`../harness/scripts/gc_witnesses/*.sno` and friends) -- so it would have printed "THE CLASS GREW ... a new safe point
# stores outside its frame map" when nothing of the kind happened and nine test files had arrived.  A ratchet whose
# population is a glob cannot tell a compiler regression from a colleague's witness.  Reported to the `cto`, whose
# row owns that gate, with the measured delta; these witnesses stay self-contained until they rule.
#
# THE POPULATION, ten programs, all ten graded against `sbl -bf`'s own answer in this same run:
#   w         the witness -- the bare deferred expression.  ORACLE: match
#   nodefer   THE CONTROL -- the witness with the ONE load-bearing ingredient removed (`lvl2 = lvl1`).  A red here
#             is not this defect: it says the whole road is broken, and the gate says so by name.
#   a_dupl a_trim a_replace a_substr    the same four allocating builtins called PLAINLY (no defer road)
#   d_dupl d_trim d_substr d_replace    the same four called INSIDE `*(...)` on the defer road
# ⭐ The eight siblings are what make the witness's reds a WITNESS and not a class: they share the allocator, the
# unrooted `out` descriptor and a byte-identical emitted window, and they are green at every point of the band.
#
# ⛔ THE UNIT IS A RED NAME SET, NEVER A COUNT, AND THE TWO MODES DIVERGE IN *WHERE*.  On base at 2026-09-20 the
# reds are m3 {1,2,4,8} and m4 {1,2}: a band point is a property of WHERE THE COLLECTION LANDS, not of the defect
# (modes 3 and 4 may diverge as optimization choices, Lon 2026-08-28).  So this gate never asserts a count and
# never asserts a particular point -- it asserts that every witness answers its oracle at every point it walks.
#
# THE CURE THIS GATE IS WAITING ON IS NOT IN A SNOBOL4 FILE, SAID HERE SO THE NEXT READER IS NOT SENT AT THE WRONG
# ONE (hq_snobol4 2026-09-20, verified A/B/A by the `cto`, taken by the `cfo` as CFO-138): `gc_heap.c` spells
# "which descriptor kinds carry a heap payload" TWICE and the copies disagree by two kinds -- `gc_visit_one` (the
# heap visitor) has `DT_X`, `gc_cell_visit` (the EMITTED-STACK cell recognizer) does not, and `DT_X` occurs in the
# whole file exactly once.  Adding it to `gc_cell_visit`'s first arm took the 340-arm band from 6 red to 0 red with
# nothing traded.  ⛔ DO NOT ALSO ADD `DT_SNUL`: it is `0x00` with NO heap payload, `gc_cell_visit` is applied
# SPECULATIVELY at every 8-byte step of the spine walk, and admitting a zero tag would make any zero word pair
# whose second word lands in the arena look like a cell -- the collector GUESSING, which CEO-812 froze out.  That
# half is an ARGUMENT from the tag layout and NOT a measurement, and it is labelled as one wherever it appears.
#
# ⭐ IT IS ALREADY RUN, AND SAYING SO IS THE POINT -- `make test-arena` SWEEPS EVERY `../harness/scripts/test_gate_gc_*.sh`
# (Makefile:152), so this gate joins Lon's mandatory tiny-arena pass the moment it lands: NOT UNREACHED, JUST NOT
# IN THE BLOCKING SET.  That pass's own recipe line says every RED in it is a collector finding that owes a ROW,
# and this one owes exactly that -- the row is this seat's, the cure is the `cfo`'s CFO-138, and the receipt is in
# the finding named below.  ⭐ It also does not change that pass's verdict today: `test_gate_gc_a_safe_point_stores_
# into_a_mapped_slot.sh` arm (f) is ALREADY red on this tree for THIS SAME defect, 4 of 12 stress points, measured
# here before this gate was committed.  A second, wider reading of one live defect is not a second defect.
#
# ⭐ WIRED INTO `make test` -- THE BLOCKING SET -- ON 2026-09-20, AND THE HOLD-OUT BEFORE IT WAS THE POINT.  This
# gate landed UNWIRED and said so on the day it landed: the blocking set is essentially serial and shared by ten
# seats (MODE TENET condition 2), so a knowingly-red arm ahead of its cure charges every one of them and buys
# nothing.  It was wired the sitting `DT_X` reached origin in `gc_cell_visit` (the `cfo` at 83b8bc9d2, CFO-138,
# four spellings) and NOT ON THE ARGUMENT THAT IT WOULD NOW BE GREEN -- it was RE-WALKED ON THAT TREE FIRST, at
# `GC_BAND_FULL=1`: 340 arms, 6 red -> 0 red, and the 334 that were already green STAYED GREEN, nothing traded.
# ⛔ THE HOLD-OUT IS THE REUSABLE PART, NOT THE WIRING: a gate held out of the blocking set must say so in its own
# header, name the cure it waits on, and carry the one line that wires it -- otherwise it is the CEO-381 class, a
# gate that exists and grades nothing, and no reader can tell that from an oversight.  This block is what that
# declaration looks like after it is discharged; the wiring line now lives in `test-sequential` beside the other
# `test_gate_gc_*` arms, with its measured duration and this same history in its provenance comment.
#
# BAND: default 0 1 2 3 4 5 6 8 16 25.  `GC_BAND_FULL=1` walks the full 17 points to 50, for a base-vs-head
# reading rather than a per-landing arm.
# ⛔⭐ WHY 16 AND 25 ARE IN THE DEFAULT THOUGH NO RED ON THIS POPULATION HAS EVER BEEN ABOVE 8 (ceo CEO-1024,
# measured by hq_raku and paid for by reversing their own green): the fleet graded GC health at stress 1, 3 and
# 5; hq_raku went to 16 on the raku rungs at the tiny arena and lost 65 gradings over 36 DISTINCT PROGRAMS,
# every one exit 0 with a plausible wrong answer.  A BAND THAT ENDS WHERE THE KNOWN DEFECTS START MEASURES THE
# BAND AND NOT THE COMPILER.  The two extra points cost ten arms per witness pair and would have caught that
# class on this population; they are cheap exactly because this gate's witnesses are small.
set -u
cd "$(dirname "$0")/../../SCRIP" || exit 2
G=gc_a_bare_deferred_expression_name_survives_every_collection_point
refuse(){ echo "⛔ GATE REFUSES(2) [$G]: $*"; exit 2; }
[ -x ./scrip ] || refuse "no ./scrip binary -- run make"
LIBDIR="$(pwd)/out"
[ -f "$LIBDIR/libscrip_rt.so" ] || refuse "no out/libscrip_rt.so -- the m4 arms could not be built"
# shellcheck source=../harness/scripts/lib_oracle_flags.sh
. ../harness/scripts/lib_oracle_flags.sh 2>/dev/null || refuse "../harness/scripts/lib_oracle_flags.sh did not load -- the oracle is reached by accessor, never by a PATH probe"
SBL="$(sbl_correctness_bin)" || refuse "the GRADING oracle is not reachable by its accessor; a missing oracle prints a full, plausible, entirely false all-FAIL table"
FLAGS="$(sbl_lang_flags)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
WIT=../harness/scripts/gc_witnesses
# ⛔⭐ ONE SPELLING OF EACH WITNESS, AND THAT IS WHY THEY ARE FILES AND NOT HEREDOCS.  The first version of this
# gate MINTED all ten inline, to keep them out of a ratchet whose population was a directory glob; the `cto`
# cured that ratchet to a PER-WITNESS baseline the same hour (SCRIP b11071af1) and invited them in.  Keeping the
# heredocs as well would have left ONE WITNESS SPELLED TWICE -- the defect this whole row is about, one level up
# (gc_visit_one and gc_cell_visit spell "which kinds carry a heap payload" twice and disagree by two kinds).  So
# the files are the one spelling, the shared censuses can see them, and this gate reads them.
# THE REF IS STILL CHECKED AGAINST THE LIVE ORACLE EVERY RUN, which is the half a committed .ref cannot do: a
# shipped expectation that has drifted from `sbl -bf` is graded against nothing, and a ref is cut from the oracle
# and never from our output.  A mismatch REFUSES rc=2 and prints both answers.
NAMES="hb_mkexpr_unmapped_spine_store hb_deferexpr_nodefer hb_deferexpr_a_dupl hb_deferexpr_a_trim hb_deferexpr_a_replace hb_deferexpr_a_substr hb_deferexpr_d_dupl hb_deferexpr_d_trim hb_deferexpr_d_substr hb_deferexpr_d_replace"
if [ "${GC_BAND_FULL:-0}" = 1 ]; then PTS="0 1 2 3 4 5 6 8 10 12 16 20 25 30 35 40 50"; else PTS="0 1 2 3 4 5 6 8 16 25"; fi
for n in $NAMES; do
  [ -f "$WIT/$n.sno" ] || refuse "witness $WIT/$n.sno is missing -- a shorter population is not a greener gate"
  [ -f "$WIT/$n.ref" ] || refuse "witness $WIT/$n.ref is missing -- there is nothing to grade $n against"
  cp "$WIT/$n.sno" "$T/$n.sno"
  "$SBL" $FLAGS "$T/$n.sno" > "$T/$n.live" 2>&1 || refuse "the oracle did not run $n cleanly -- nothing here is graded against our own output"
  [ -s "$T/$n.live" ] || refuse "the oracle's answer for $n is EMPTY; an empty expectation makes every arm pass"
  if ! cmp -s "$T/$n.live" "$WIT/$n.ref"; then
    refuse "the committed ref for $n has DRIFTED from the oracle -- committed [$(tr '\n' '|' < "$WIT/$n.ref")] vs live [$(tr '\n' '|' < "$T/$n.live")]; a ref is cut from the oracle, never from our output"
  fi
  cp "$WIT/$n.ref" "$T/$n.ref"
  ( cd "$T" && timeout -k 5 60s "$OLDPWD/scrip" --compile -o "$n.s" "$n.sno" < /dev/null > /dev/null 2>&1 \
      && gcc -m64 -no-pie -rdynamic "$n.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$n.x4" 2> "$n.ld.log" ) \
      || refuse "mode-4 compile or link failed for $n, so every m4 arm measured nothing ($(head -c 160 "$T/$n.ld.log" 2>/dev/null))"
done
echo "=== gate: a bare deferred expression's DT_X name survives every collection point ==="
echo "    oracle $SBL $FLAGS (refs cut live, this run) · SCRIP_HEAP_KB=128 · band: $PTS · modes m3 m4"
printf '    %-11s %-3s' "" ""; for N in $PTS; do printf '%4s' "$N"; done; echo
arms=0; red=0; redset=""; wit_red=0; sib_red=0; ctl_red=0
for n in $NAMES; do
  want="$(cat "$T/$n.ref")"
  for m in m3 m4; do
    printf '    %-11s %-3s' "$n" "$m"; row=""
    for N in $PTS; do
      if [ "$m" = m3 ]; then got="$(cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_HEAP_MAX_MB=512 SCRIP_GC_STRESS="$N" timeout -k 5 60s "$OLDPWD/scrip" "$n.sno" < /dev/null 2>&1)"; rc=$?
      else got="$(cd "$T" && env -u SCRIP_HEAP_MB SCRIP_HEAP_KB=128 SCRIP_HEAP_MAX_MB=512 SCRIP_GC_STRESS="$N" timeout -k 5 60s "./$n.x4" < /dev/null 2>&1)"; rc=$?; fi
      arms=$((arms+1))
      if [ "$got" = "$want" ] && [ "$rc" = 0 ]; then row="$row   ."
      else
        row="$row   X"; red=$((red+1)); redset="$redset $n/$m/$N(rc=$rc)"
        case "$n" in
          hb_mkexpr_unmapped_spine_store) wit_red=$((wit_red+1));;
          hb_deferexpr_nodefer)           ctl_red=$((ctl_red+1));;
          hb_deferexpr_*)                 sib_red=$((sib_red+1));;
          *) refuse "witness $n is in the population but in none of the three classes -- a classifier that cannot place a member will misfile it silently (this arm caught exactly that when the witnesses were renamed out of heredocs into files: every red was counted a SIBLING and the gate printed the WRONG conclusion, green-looking and plausible)";;
        esac
      fi
    done
    echo "$row"
  done
done
echo "------------------------------------------------------------"
echo "    arms=$arms red=$red  (witness $wit_red · siblings $sib_red · control $ctl_red)"
[ "$red" = 0 ] || echo "    RED NAME SET:$redset"
if [ "$red" = 0 ]; then
  echo "✅ GATE PASS [$G]: all $arms arms answer the oracle -- the DT_X name survives every collection point walked"
  exit 0
fi
[ "$ctl_red" != 0 ] && echo "    ⛔ THE CONTROL IS RED. nodefer carries no deferred expression, so this is NOT the DT_X recognizer hole -- do not cure that; something wider is broken and this gate's population can no longer isolate anything."
[ "$ctl_red" = 0 ] && [ "$sib_red" != 0 ] && echo "    ⛔ A SIBLING IS RED WITH THE CONTROL GREEN: the defect is no longer confined to the bare-deferred-expression road. Re-ablate before curing -- the witness is no longer a witness for a single ingredient."
[ "$ctl_red" = 0 ] && [ "$sib_red" = 0 ] && echo "    ⭐ WITNESS-ONLY REDS WITH EIGHT SIBLINGS AND THE CONTROL GREEN: this is the expected shape of the defect. The cure is DT_X in gc_cell_visit (the cfo's file, CFO-138) -- see this gate's header, and do NOT add DT_SNUL with it."
echo "⛔ GATE FAIL [$G]: $red of $arms arms diverge from the oracle at SCRIP_HEAP_KB=128"
exit 1
