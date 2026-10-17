#!/usr/bin/env bash
# test_gate_blocking_set_shards_agree_with_sequential.sh -- A SHARDED RUN REDS THE SAME NAME SET AS A SEQUENTIAL ONE
# (coo 2026-09-17, ceo CEO-829, from the cfo's economy measurement; row instrument-the-blocking-set-shards-and-a-
# sharded-run-reds-the-same-name-set-as-a-sequential-one).
#
# WHY THE ACCEPTANCE IS NOT A SPEEDUP.  The 338-arm set costs about 35 minutes while origin/main took 22 landings
# today -- and the gaps between the last twelve ran 0,2,2,9,4,0,3,3,322,1,3,49 minutes, so the average hides the
# shape: landings arrive in BURSTS and a 35-minute set cannot fit inside one at all.  Sharding is the obvious
# answer and the obvious answer is where the lie gets in: a fan-out changes the box's load, the working directory
# two arms share, and whether two boards run at once.  So the gate does not ask "was it faster".  It asks whether
# the RED NAME SET and the REFUSED NAME SET are the same ones (CEO-825 clause 1: two readings can agree on a count
# and disagree on membership).  An arm whose verdict changes with HOW it was run is THE FINDING.
#
#   (a) PARTITION, over the REAL 337-arm declaration and without running one of them: every shard's arms plus the
#       declared serial arms reconstruct the declaration EXACTLY ONCE -- nothing doubled, nothing dropped
#   (b) NAME-SET IDENTITY, on a fixture set that really runs: sequential vs --shards 3, same red names, same
#       refused names, same green count, same total
#   (c) A DECLARED SERIAL ARM IS IN NO SHARD and is still RUN by the fan-out -- excluded from the slice, not from
#       the set, which is the difference between a hazard and a hole
#   (d) REPORTED arms (leading -) do not change a sharded verdict, exactly as they do not change a sequential one
#   (e) a shard that would hold ZERO arms REFUSES rc=2 rather than printing the success shape
#   (f) the fan-out REFUSES rc=2 if its merged arm count does not equal the declared one -- a set that cannot
#       account for its own arms is not a measurement
# FAIL_ONCE=1 corrupts the fixture's sequential reading before (b) asserts, to prove the arm trips.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE/../../SCRIP" || exit 2
D="$HERE/run_blocking_set.sh"
refuse(){ echo "⛔ REFUSED-TO-GRADE (rc=2): $*"; exit 2; }
[ -f "$D" ] || refuse "no driver at $D"
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
W="$(mktemp -d)" || refuse "no temp dir"; trap 'rm -rf "$W"' EXIT
echo "=== gate: the blocking set shards, and a sharded run reds the same NAME SET as a sequential one ==="

# ---- (a) the partition, over the real declaration, running nothing
SER="$HERE/blocking_set_serial_arms.txt"
[ -f "$SER" ] || refuse "no declared serial-arm list at $SER -- the fan-out's hazard set must be declared, not sniffed"
bash "$D" --list > "$W/all.list" 2>&1 || refuse "the driver could not list the declaration"
sed -n 's/^ *[0-9]* *\(BLOCKING\|REPORTED\) *//p' "$W/all.list" | sort > "$W/all.arms"
: > "$W/shards.arms"
for k in 1 2 3 4; do
  bash "$D" --shard "$k/4" --list 2>/dev/null | sed -n 's/^ *[0-9]* *\(BLOCKING\|REPORTED\) *//p' >> "$W/shards.arms"
done
grep -vE '^\s*(#|$)' "$SER" > "$W/pats" || true
grep -F -f "$W/pats" "$W/all.arms" | sort > "$W/serial.arms" || true
cat "$W/shards.arms" "$W/serial.arms" | sort > "$W/rebuilt.arms"
n_all=$(wc -l < "$W/all.arms"); n_re=$(wc -l < "$W/rebuilt.arms"); n_ser=$(wc -l < "$W/serial.arms")
if diff -q "$W/all.arms" "$W/rebuilt.arms" >/dev/null; then
  ck ok "(a) 4 shards + $n_ser declared serial arm(s) reconstruct all $n_all declared arms EXACTLY ONCE"
else
  ck no "(a) the shards do not partition the declaration: declared=$n_all rebuilt=$n_re; first differences: $(diff "$W/all.arms" "$W/rebuilt.arms" | head -3 | tr '\n' ';')"
fi
dupes=$(sort "$W/shards.arms" | uniq -d | wc -l)
[ "$dupes" -eq 0 ] && ck ok "(a2) no arm appears in two shards (a doubled arm is a doubled verdict)" \
  || ck no "(a2) $dupes arm(s) appear in more than one shard: $(sort "$W/shards.arms" | uniq -d | head -2 | tr '\n' ';')"

# ---- the fixture set: green, red, refusal, a REPORTED red, and one arm declared serial
cat > "$W/arms.txt" <<'EOA'
bash -c "echo armGREEN1; exit 0"
bash -c "echo armRED1; exit 1"
bash -c "echo armGREEN2; exit 0"
bash -c "echo armREFUSE1; exit 2"
bash -c "echo armGREEN3; exit 0"
bash -c "echo armRED2; exit 1"
bash -c "echo armGREEN4; exit 0"
-bash -c "echo armREPORTEDRED; exit 1"
bash -c "echo armSERIALME; exit 0"
EOA
printf 'armSERIALME\n' > "$W/serialpat.txt"
run(){ bash "$D" --arms-from "$W/arms.txt" --serial-arms "$W/serialpat.txt" "$@" ; }
run > "$W/seq.out" 2>&1; seq_rc=$?
run --shards 3 > "$W/sh.out" 2>&1; sh_rc=$?
names(){ grep '^ARMRESULT	' "$1" | awk -F'	' -v want="$2" '($2==want){print $5}' | sort; }
[ -n "${FAIL_ONCE:-}" ] && sed -i 's/armRED2/armRED2_CORRUPTED/' "$W/seq.out"
names "$W/seq.out" 1 > "$W/seq.red"; names "$W/sh.out" 1 > "$W/sh.red"
names "$W/seq.out" 2 > "$W/seq.ref"; names "$W/sh.out" 2 > "$W/sh.ref"
names "$W/seq.out" 0 > "$W/seq.green"; names "$W/sh.out" 0 > "$W/sh.green"
if diff -q "$W/seq.red" "$W/sh.red" >/dev/null && [ -s "$W/seq.red" ]; then
  ck ok "(b1) the RED NAME SET is identical, sequential vs 3 shards ($(wc -l < "$W/seq.red") name(s), not just $(wc -l < "$W/seq.red") count(s))"
else
  ck no "(b1) the red NAME SETS differ (seq $(wc -l < "$W/seq.red"), sharded $(wc -l < "$W/sh.red")): $(diff "$W/seq.red" "$W/sh.red" | head -3 | tr '\n' ';')"
fi
diff -q "$W/seq.ref" "$W/sh.ref" >/dev/null && [ -s "$W/seq.ref" ] \
  && ck ok "(b2) the REFUSED NAME SET is identical too -- a refusal is its own class in both shapes" \
  || ck no "(b2) the refused name sets differ: $(diff "$W/seq.ref" "$W/sh.ref" | head -3 | tr '\n' ';')"
diff -q "$W/seq.green" "$W/sh.green" >/dev/null \
  && ck ok "(b3) the GREEN name set is identical -- no arm was quietly greened by the fan-out, which is the failure worth more than the speed" \
  || ck no "(b3) the green name sets differ: $(diff "$W/seq.green" "$W/sh.green" | head -3 | tr '\n' ';')"
[ "$seq_rc" = "$sh_rc" ] && ck ok "(b4) both shapes exit the same code (rc=$seq_rc) over the same fixture" \
  || ck no "(b4) sequential exited $seq_rc and the fan-out exited $sh_rc over one fixture"

# ---- (c) the serial arm: in no shard, and still run
insh=0
for k in 1 2 3; do
  bash "$D" --arms-from "$W/arms.txt" --serial-arms "$W/serialpat.txt" --shard "$k/3" --list 2>/dev/null | grep -q armSERIALME && insh=1
done
if [ "$insh" = 0 ] && grep -q 'armSERIALME' "$W/sh.out"; then
  ck ok "(c) the declared serial arm is in NO shard and is still RUN by the fan-out -- excluded from the slice, not from the set"
else
  ck no "(c) serial arm handling wrong: in a shard=$insh, present in the fan-out's report=$(grep -c armSERIALME "$W/sh.out")"
fi

# ---- (d) REPORTED arms do not change a sharded verdict
if grep -q 'armREPORTEDRED' "$W/sh.out" && grep -q '(REPORTED)' "$W/sh.out"; then
  ck ok "(d) a REPORTED red is printed in its class by the fan-out and does not decide the run (rc=$sh_rc came from the blocking reds)"
else
  ck no "(d) the fan-out did not print the REPORTED arm in its class"
fi

# ---- (e) a shard that would be empty refuses
bash "$D" --arms-from "$W/serialpat_none.txt" --shard 9/9 --list > "$W/empty.out" 2>&1; erc=$?
printf 'bash -c "exit 0"\n' > "$W/one.txt"
bash "$D" --arms-from "$W/one.txt" --shard 9/9 > "$W/empty2.out" 2>&1; erc2=$?
{ [ "$erc" = 2 ] && [ "$erc2" = 2 ] && grep -q 'ZERO arms' "$W/empty2.out"; } \
  && ck ok "(e) a missing arms file and an empty shard each REFUSE rc=2 -- a slice that graded nothing must never print the success shape" \
  || ck no "(e) empty-shard handling: missing-file rc=$erc, empty-shard rc=$erc2 ($(head -1 "$W/empty2.out"))"

# ---- (f) the merged count must equal the declared one
if grep -qE 'blocking set: arms=9 .*\(.*=9\)' "$W/sh.out"; then
  ck ok "(f) the fan-out's merged arm count equals the declared one and the denominator identity is printed"
else
  ck no "(f) the fan-out did not close its own denominator: $(grep -m1 'blocking set: arms=' "$W/sh.out")"
fi
w_seq=$(grep -m1 -oE 'wall=[0-9]+s' "$W/sh.out" || true)
echo "population: $checks arm(s) graded, $fails FAIL; fixture 9 arms, real declaration $n_all arms over 4 shards + $n_ser serial ${w_seq:+(fan-out $w_seq)}"
if [ "$fails" -eq 0 ]; then
  echo "GATE PASS [blocking_set_shards_agree_with_sequential]: $checks of $checks arms hold"; exit 0
fi
echo "⛔ GATE RED [blocking_set_shards_agree_with_sequential]: $fails of $checks arms FAIL"; exit 1
