#!/usr/bin/env bash
# test_gate_blocking_set_parallel_agrees_with_serial.sh -- THE PARALLEL BLOCKING SET AGREES WITH THE SERIAL ONE
# ARM FOR ARM, AND AN ARM THAT RACED ANOTHER ARM IS rc=2 AND NEVER A RED.
# (coo 2026-09-20, row instruments-the-blocking-set-is-367-serial-arms-and-it-caps-every-seat-in-the-fleet,
# minted by the ceo on Lon's TENET condition 2.)
#
# THE MEASUREMENT THIS EXISTS FOR.  The blocking set declares 370 arms, all of them blocking, and it is
# essentially SERIAL: the cfo read 227 arms after 22 minutes at load 4.5-5.0, 850 arm-seconds inside 862
# seconds of wall at the halfway mark.  Ten seats on one 16-core box do not make a serial set faster, they
# QUEUE through it -- and on 2026-09-20 two seats independently claimed the same row inside one hour, which is
# the fleet feeling one wall from two directions.  run_blocking_set.sh --shards N already fans the set out.
# What was missing is the thing that makes a fan-out SAFE TO BELIEVE.
#
# ⛔⭐ AND THE REFUSAL MATTERS MORE THAN THE SPEED, which is the clause this gate is built around.  A parallel
# set that turns a COLLISION into a RED manufactures an UNATTRIBUTABLE FINDING: the arm does not reproduce
# serially, so a seat either chases a defect that is not there or learns to discount reds.  Under ten seats
# that is unaffordable.  So a raced arm is rc=2 COULD-NOT-MEASURE, named with the other arm and the path --
# and the two failure directions of that rule are BOTH measured here in every run, not asserted:
#   M1 UNWIRED -- the race reads as a flaky red (the state this row cures)
#   M2 GREEDY  -- convicting on time alone buries an innocent red or green under a refusal, and a set that
#                 cannot report a defect any more is worth less than the slow one it replaced.
#
# THE ARMS
#   (a) ARM FOR ARM: sequential and --shards 3 produce the IDENTICAL arm->rc map over one fixture, and the
#       same exit code.  Name sets agree AND every arm's own verdict agrees -- two readings can agree on a
#       count and disagree on membership (CEO-825 clause 1), and on membership while disagreeing per arm.
#   (b) A RACE IS REFUSED AND NAMES BOTH ARMS: two arms that rendezvous and move the same watched path are
#       BOTH rc=2, both named with the path, and the run exits 2 (UNPROVEN) rather than 1 (RED).
#   (c) A GENUINE RED SURVIVES A RACE: an independent red arm in the same run is still RED and still decides
#       the exit code.  A detector that buries reds is the worse defect.
#   (d) NO FALSE COLLISION: two concurrent arms that touch NOTHING on the watched surface stay GREEN, exit 0.
#   (e) THE MUTANTS, RUN AND MEASURED HERE: M1 reds the race; M2 refuses the innocent pair.
#   (f) THE REAL DECLARATION PARTITIONS: every declared arm is in exactly one shard or is declared serial --
#       which is what carries (a)'s fixture result onto the 370 arms nobody can run twice inside a gate.
#   (g) BOTH SHAPES STAMP wall, load, tree and detector state, spelled identically, so "both arms of the same
#       tree" is checkable by a reader instead of remembered by a runner.
#   (h) AN UNREADABLE SURFACE DECLARATION REFUSES rc=2, and a MISSING one turns the detector off and SAYS SO.
#       "I could not read the hazard list" and "the hazard list is empty" are facts a driver must never conflate.
#
# FAIL_ONCE=1 runs the primary arms against M1 (detector unwired) -- (b) and (c) must fail.
# FAIL_ONCE=2 runs them against M2 (greedy) -- (d) must fail.
# A mutant that does not mutate proves nothing, so a sed that matches no anchor REFUSES rc=2.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE/../../SCRIP" || exit 2
D0="$HERE/run_blocking_set.sh"
refuse(){ echo "⛔ REFUSED-TO-GRADE (rc=2): $*"; exit 2; }
[ -f "$D0" ] || refuse "no driver at $D0"
[ -f "$HERE/blocking_set_shared_surfaces.txt" ] || refuse "no declared watched surface at $HERE/blocking_set_shared_surfaces.txt -- the detector's surface must be declared, not sniffed, and its absence is not an empty declaration"
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
W="$(mktemp -d)" || refuse "no temp dir"; trap 'rm -rf "$W"' EXIT
echo "=== gate: the parallel blocking set agrees with the serial one ARM FOR ARM, and a raced arm is rc=2 ==="

# ---- the mutants, always cut from the REAL driver so FAIL_ONCE cannot make (e) compare a mutant with itself
# ⛔ NOT A COMMAND SUBSTITUTION.  `M1="$(mutant ...)"` would run refuse() in a SUBSHELL: the refusal would be
# CAPTURED as the mutant's path and the gate would sail on grading a filename made of an error message.  MUT is
# a global and the refusal exits the gate, which is the whole difference between a guard and a decoration.
MUT=""
mutant(){ # mutant <dir> <sed-expr> <anchor-line> -- sets MUT
  # ⛔ THE MUTANT SITS AMONG ITS SIBLINGS (the coo 2026-09-28): the driver sources lib_fanout.sh beside itself since 7c75f8b0a, so a lone
  # copy in a scratch directory refused rc 2 before it ran an arm -- (e1) and (e2) read rc=2 ARMRACE=0 in every pass from that landing on,
  # a refusal of the mutant, not a verdict on the detector. Every sibling is linked in, so the next library it sources is found too.
  . "$HERE/lib_fixture_root.sh" || exit 2; fixture_root "$W/$1" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot stage a copied root at $W/$1"; exit 2; }; rm -f "$W/$1/harness/scripts/run_blocking_set.sh"
  cp "$D0" "$W/$1/harness/scripts/run_blocking_set.sh" || refuse "cannot build mutant $1"
  grep -q "^$3\$" "$W/$1/harness/scripts/run_blocking_set.sh" || refuse "mutant $1 has no anchor '$3' in the driver -- a mutant that does not mutate proves nothing"
  sed -i "$2" "$W/$1/harness/scripts/run_blocking_set.sh"
  grep -q "^$3\$" "$W/$1/harness/scripts/run_blocking_set.sh" && refuse "mutant $1 left its anchor '$3' in place -- the sed matched nothing"
  MUT="$W/$1/harness/scripts/run_blocking_set.sh"
}
mutant m1 's/^RACE_DETECT=1  /RACE_DETECT=0  /' 'RACE_DETECT=1              # ⛔ MUTANT ANCHOR M1 -- 0 unwires the detector, and a race then reads as a flaky RED'; M1="$MUT"
mutant m2 's/^RACE_NEEDS_SHARED_PATH=1  /RACE_NEEDS_SHARED_PATH=0  /' 'RACE_NEEDS_SHARED_PATH=1   # ⛔ MUTANT ANCHOR M2 -- 0 convicts on time alone, and every concurrent arm is refused'; M2="$MUT"
D="$D0"; LIVE="the shipped driver"
case "${FAIL_ONCE:-}" in
  1) D="$M1"; LIVE="MUTANT M1 (detector unwired) -- (b) and (c) MUST fail" ;;
  2) D="$M2"; LIVE="MUTANT M2 (convicts on time alone) -- (d) MUST fail" ;;
esac
echo "  driver under test: $LIVE"

# ---- the fixture.  Two racers RENDEZVOUS before they write, so the overlap is GUARANTEED rather than hoped
# for: a fan-out on a box at load 15 can start two shards seconds apart, and a fixture whose two arms merely
# sleep would stop exercising the detector on exactly the loaded box the detector exists for.  A rendezvous
# that times out is a REFUSAL -- the detector was not exercised, which is not the same as not tripping.
SURF="$W/surface"; RV="$W/rv"; mkdir -p "$SURF" "$RV"
printf '%s\n' "$SURF" > "$W/surfaces.txt"
: > "$W/noserial.txt"
cat > "$W/racer.sh" <<'EOR'
#!/usr/bin/env bash
# racer.sh <id> <rc> <path-to-touch> <rendezvous-dir> <expected-party-count>
id="$1"; rc="$2"; p="$3"; rv="$4"; want="$5"; n=0
touch "$rv/$id"
while [ "$(ls "$rv" | grep -c . )" -lt "$want" ]; do
    n=$((n + 1)); [ "$n" -gt 200 ] && { : > "$rv/NO-RENDEZVOUS"; break; }
    sleep 0.05
done
touch "$p"; sleep 0.4; touch "$p"
echo "racer $id done"; exit "$rc"
EOR
cat > "$W/quiet.sh" <<'EOQ'
#!/usr/bin/env bash
# quiet.sh <id> <rc> <rendezvous-dir> <expected-party-count> -- concurrent, and touches NOTHING on the surface
id="$1"; rc="$2"; rv="$3"; want="$4"; n=0
touch "$rv/$id"
while [ "$(ls "$rv" | grep -c . )" -lt "$want" ]; do
    n=$((n + 1)); [ "$n" -gt 200 ] && { : > "$rv/NO-RENDEZVOUS"; break; }
    sleep 0.05
done
sleep 0.4
echo "quiet $id done"; exit "$rc"
EOQ
run(){ bash "$D" --serial-arms "$W/noserial.txt" --shared-surfaces "$W/surfaces.txt" "$@"; }
rendezvous_held(){ [ ! -f "$1/NO-RENDEZVOUS" ]; }

# ---- (a) arm for arm, over a fixture that really runs and touches nothing shared
cat > "$W/agree.txt" <<EOA
bash -c "echo armGREEN1; exit 0"
bash -c "echo armRED1; exit 1"
bash -c "echo armGREEN2; exit 0"
bash -c "echo armREFUSE1; exit 2"
bash -c "echo armGREEN3; exit 0"
bash -c "echo armRED2; exit 1"
bash -c "echo armGREEN4; exit 0"
-bash -c "echo armREPORTEDRED; exit 1"
bash -c "echo armGREEN5; exit 0"
EOA
run --arms-from "$W/agree.txt" > "$W/seq.out" 2>&1; seq_rc=$?
run --arms-from "$W/agree.txt" --shards 3 > "$W/par.out" 2>&1; par_rc=$?
armmap(){ grep '^ARMRESULT	' "$1" | awk -F'\t' '{print $5 "\t" $2}' | sort; }
armmap "$W/seq.out" > "$W/seq.map"; armmap "$W/par.out" > "$W/par.map"
[ -n "${FAIL_ONCE:-}" ] && [ "${FAIL_ONCE}" = 3 ] && sed -i '1s/\t0/\t1/' "$W/par.map"
n_map=$(wc -l < "$W/seq.map")
if diff -q "$W/seq.map" "$W/par.map" >/dev/null && [ "$n_map" -eq 9 ]; then
  ck ok "(a) ARM FOR ARM: all $n_map arms carry the same rc sequential and over 3 shards -- not only the same red NAMES, the same verdict per arm"
else
  ck no "(a) the arm->rc maps differ (seq $n_map arms, parallel $(wc -l < "$W/par.map")): $(diff "$W/seq.map" "$W/par.map" | head -4 | tr '\n' ';')"
fi
[ "$seq_rc" = "$par_rc" ] && ck ok "(a2) both shapes exit the same code (rc=$seq_rc) over one fixture" \
  || ck no "(a2) sequential exited $seq_rc and the fan-out exited $par_rc over one fixture"

# ---- (b) a race is REFUSED and NAMES BOTH ARMS
rm -f "$RV"/*; cat > "$W/race.txt" <<EOB
bash $W/racer.sh A 1 $SURF/shared $RV 2
bash $W/racer.sh B 0 $SURF/shared $RV 2
EOB
run --arms-from "$W/race.txt" --shards 2 > "$W/race.out" 2>&1; race_rc=$?
rendezvous_held "$RV" || refuse "the two racing arms never met inside 10s, so the detector was NOT EXERCISED -- that is a could-not-measure and not a pass (box load $(cut -d' ' -f1 /proc/loadavg))"
n_race=$(grep -c '^ARMRACE	' "$W/race.out")
racedA=$(grep -c '^ARMRESULT	2	.*racer.sh A' "$W/race.out")
racedB=$(grep -c '^ARMRESULT	2	.*racer.sh B' "$W/race.out")
if [ "$race_rc" = 2 ] && [ "$racedA" -ge 1 ] && [ "$racedB" -ge 1 ] && grep -q "path $SURF/shared" "$W/race.out"; then
  ck ok "(b) the racing pair is rc=2 for BOTH arms, both named with the shared path, and the run exits 2 UNPROVEN -- the rc=1 arm was NOT reported as a red"
else
  ck no "(b) the race was not refused as a pair: rc=$race_rc (want 2), armA-refused=$racedA armB-refused=$racedB, ARMRACE lines=$n_race, $(grep -m1 '^blocking set:' "$W/race.out")"
fi

# ---- (c) a genuine red survives beside a race, and still decides the exit code
rm -f "$RV"/*; cat > "$W/racered.txt" <<EOC
bash $W/racer.sh A 1 $SURF/shared $RV 2
bash $W/racer.sh B 0 $SURF/shared $RV 2
bash -c "echo armHONESTRED; exit 1"
EOC
run --arms-from "$W/racered.txt" --shards 2 > "$W/racered.out" 2>&1; rr_rc=$?
rendezvous_held "$RV" || refuse "the racing pair never met in the (c) fixture -- the detector was not exercised"
if [ "$rr_rc" = 1 ] && grep -q '^ARMRESULT	1	.*armHONESTRED' "$W/racered.out" && grep -q '^ARMRACE	' "$W/racered.out"; then
  ck ok "(c) the independent red is STILL RED beside a raced pair and still decides the run (rc=1) -- the detector refuses arms, it does not bury findings"
else
  ck no "(c) red-beside-race wrong: rc=$rr_rc (want 1), honest red line=$(grep -c 'armHONESTRED' "$W/racered.out"), ARMRACE=$(grep -c '^ARMRACE	' "$W/racered.out")"
fi

# ---- (d) no false collision: concurrent arms that touch nothing shared stay green
rm -f "$RV"/*; cat > "$W/quiet.txt" <<EOD
bash $W/quiet.sh A 0 $RV 2
bash $W/quiet.sh B 0 $RV 2
EOD
run --arms-from "$W/quiet.txt" --shards 2 > "$W/quiet.out" 2>&1; q_rc=$?
rendezvous_held "$RV" || refuse "the two quiet arms never met -- concurrency was not achieved and (d) proves nothing"
if [ "$q_rc" = 0 ] && ! grep -q '^ARMRACE	' "$W/quiet.out" && [ "$(grep -c '^ARMRESULT	0	' "$W/quiet.out")" = 2 ]; then
  ck ok "(d) two CONCURRENT arms that touch nothing on the watched surface stay green and exit 0 -- overlap in time is not a collision"
else
  ck no "(d) an innocent concurrent pair was convicted: rc=$q_rc (want 0), ARMRACE=$(grep -c '^ARMRACE	' "$W/quiet.out"), $(grep -m1 '^blocking set:' "$W/quiet.out")"
fi

# ---- (e) the two failure directions, MEASURED here rather than asserted
rm -f "$RV"/*
bash "$M1" --serial-arms "$W/noserial.txt" --shared-surfaces "$W/surfaces.txt" --arms-from "$W/race.txt" --shards 2 > "$W/m1.out" 2>&1; m1_rc=$?
if [ "$m1_rc" = 1 ] && ! grep -q '^ARMRACE	' "$W/m1.out" && grep -q '^ARMRESULT	1	' "$W/m1.out"; then
  ck ok "(e1) M1 (detector unwired) reports the SAME race as a flaky RED, rc=1 -- the pre-state this row cures is visible, so the cure is not decoration"
else
  ck no "(e1) M1 did not read the race as a red: rc=$m1_rc, ARMRACE=$(grep -c '^ARMRACE	' "$W/m1.out")"
fi
rm -f "$RV"/*
bash "$M2" --serial-arms "$W/noserial.txt" --shared-surfaces "$W/surfaces.txt" --arms-from "$W/quiet.txt" --shards 2 > "$W/m2.out" 2>&1; m2_rc=$?
if [ "$m2_rc" = 2 ] && grep -q '^ARMRACE	' "$W/m2.out"; then
  ck ok "(e2) M2 (convicts on time alone) refuses the INNOCENT concurrent pair, rc=2 -- the greedy direction is visible too, and it is the one that would hide every red"
else
  ck no "(e2) M2 did not convict the innocent pair: rc=$m2_rc, ARMRACE=$(grep -c '^ARMRACE	' "$W/m2.out")"
fi

# ---- (f) the real declaration partitions: shards + declared serial arms == the declaration, exactly once
SER="$HERE/blocking_set_serial_arms.txt"
bash "$D0" --list > "$W/all.list" 2>&1 || refuse "the driver could not list the real declaration"
sed -n 's/^ *[0-9]* *\(BLOCKING\|REPORTED\) *//p' "$W/all.list" | sort > "$W/all.arms"
: > "$W/shards.arms"
for k in 1 2 3 4 5; do
  bash "$D0" --shard "$k/5" --list 2>/dev/null | sed -n 's/^ *[0-9]* *\(BLOCKING\|REPORTED\) *//p' >> "$W/shards.arms"
done
grep -vE '^\s*(#|$)' "$SER" > "$W/pats" || true
grep -F -f "$W/pats" "$W/all.arms" | sort > "$W/serial.arms" || true
cat "$W/shards.arms" "$W/serial.arms" | sort > "$W/rebuilt.arms"
n_all=$(wc -l < "$W/all.arms"); n_ser=$(wc -l < "$W/serial.arms")
if diff -q "$W/all.arms" "$W/rebuilt.arms" >/dev/null; then
  ck ok "(f) 5 shards + $n_ser DECLARED-SERIAL arm(s) reconstruct all $n_all declared arms exactly once -- the fixture's arm-for-arm agreement carries onto the real set by construction"
else
  ck no "(f) the parallel shape does not partition the real declaration: declared=$n_all rebuilt=$(wc -l < "$W/rebuilt.arms"); $(diff "$W/all.arms" "$W/rebuilt.arms" | head -3 | tr '\n' ';')"
fi

# ---- (g) both shapes stamp wall, load, tree and detector state, spelled identically
sst="$(grep -m1 '^blocking set stamp:' "$W/seq.out")"; pst="$(grep -m1 '^blocking set stamp:' "$W/par.out")"
okstamp=1
for f in shape= arms= wall= load= tree= detector= raced=; do
  case "$sst" in *"$f"*) : ;; *) okstamp=0 ;; esac
  case "$pst" in *"$f"*) : ;; *) okstamp=0 ;; esac
done
if [ "$okstamp" = 1 ]; then
  ck ok "(g) both shapes stamp shape/arms/wall/load/tree/detector/raced -- a before-and-after pair is a measurement only when both arms name the tree and the load they ran at"
else
  ck no "(g) the stamp line is missing or incomplete: sequential='$sst' parallel='$pst'"
fi

# ---- (h) an unreadable surface declaration refuses; a missing one turns the detector off and says so
printf '%s\n' "$SURF" > "$W/unreadable.txt"; chmod 000 "$W/unreadable.txt"
bash "$D0" --serial-arms "$W/noserial.txt" --shared-surfaces "$W/unreadable.txt" --arms-from "$W/quiet.txt" --shards 2 > "$W/unread.out" 2>&1; u_rc=$?
chmod 644 "$W/unreadable.txt"
bash "$D0" --serial-arms "$W/noserial.txt" --shared-surfaces "$W/does-not-exist.txt" --arms-from "$W/agree.txt" > "$W/nosurf.out" 2>&1; ns_rc=$?
if [ "$u_rc" = 2 ] && grep -q 'unreadable surface declaration is not an empty one' "$W/unread.out" \
   && grep -q 'detector=no-surface-declared' "$W/nosurf.out"; then
  ck ok "(h) an UNREADABLE surface declaration refuses rc=2, and a MISSING one turns the detector off and stamps 'no-surface-declared' -- never a silent raced=0"
else
  ck no "(h) surface-declaration handling: unreadable rc=$u_rc, missing-file stamp='$(grep -m1 '^blocking set stamp:' "$W/nosurf.out")'"
fi

# ---- the measurement this gate carries in its own population line
w_seq="$(grep -m1 -oE 'wall=[0-9]+s' "$W/seq.out" || true)"; w_par="$(grep -m1 -oE 'wall=[0-9]+s' "$W/par.out" || true)"
echo "population: $checks arm(s) graded, $fails FAIL; fixture 9 arms sequential ${w_seq:-?} vs 3 shards ${w_par:-?}; real declaration $n_all arms, $n_ser declared serial; load $(cut -d' ' -f1 /proc/loadavg)"
if [ "$fails" -eq 0 ]; then
  echo "GATE PASS [blocking_set_parallel_agrees_with_serial]: $checks of $checks arms hold"; exit 0
fi
echo "⛔ GATE RED [blocking_set_parallel_agrees_with_serial]: $fails of $checks arms FAIL"; exit 1
