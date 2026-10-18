#!/usr/bin/env bash
# test_gate_a_blocking_set_death_names_its_killer.sh -- A RUN THAT DIES SAYS WHAT ENDED IT: SIGNAL, ARM REACHED,
# ELAPSED, AND THE SENDER -- OR SAYS IN WORDS THAT THE KILLER LEFT NO RECORD.
# (coo 2026-09-20, row instruments-a-blocking-set-run-is-killed-from-outside-and-no-seat-completed-one-today,
# minted by the ceo on the cfo's CFO-147.)
#
# THE MEASUREMENT THIS EXISTS FOR. 2026-09-20: the cfo's blocking set died at ARM 103 with SIGTERM and again at
# ARM 166 with SIGKILL DESPITE BEING setsid-DETACHED; hq_prolog's died at ARM 6 after THIRTY SECONDS; hq_raku's
# reached 18 and 61. FIVE DEATHS, THREE SEATS, ONE AFTERNOON -- and NOT ONE OF THEM SAID WHAT ENDED IT, so the
# fleet spent the afternoon arguing between a wall-clock ceiling (proposed by the cfo, refuted by hq_prolog's
# thirty seconds, withdrawn by the cfo), an OOM, and another seat's pkill. TEN SEATS SHARE ONE UNIX USER: a
# `pkill -f` keyed on a script name reaches every other seat's run, and the cto signalled eleven pids over
# shared patterns at 01:4x and reported it unprompted. The mechanism is real; what was missing was the RECORD.
#
# ⛔ THE TWO HALVES, BECAUSE ONE MECHANISM CANNOT COVER BOTH:
#   · CATCHABLE signals are trapped by the victim, which prints the signal, the arm it reached, the elapsed and
#     the sender looked up in the kill ledger s4e_kill_mine.sh writes.
#   · SIGKILL CANNOT BE TRAPPED. Nothing inside a victim ever reports it -- so the RUNSTATE makes it legible
#     AFTER the fact: the next run in that root postmortems a state file that never recorded a completion. A
#     design that only handles the signals you can catch handles the ones that do not happen.
#
# THE ARMS
#   (a) a trapped death names SIGNAL, ARM REACHED of N, and ELAPSED, and exits 128+signal
#   (b) an UNLOGGED killer is NAMED AS UNLOGGED -- the instrument refuses to guess a sender it cannot see
#   (c) a kill sent through s4e_kill_mine.sh NAMES ITS SENDER to the victim: seat, root, pid, signal, time
#   (d) SIGKILL: the victim says nothing (it cannot) and THE NEXT RUN POSTMORTEMS IT with pid, arm and verdict
#   (e) a COMPLETED run leaves NO postmortem -- a death report after a clean run is a false alarm, which is the
#       same defect wearing the other sign
#   (f) --explain-only RECORDS NOTHING: it signals nothing, so a ledger line would record an event that did not
#       happen -- a false green in ledger clothing
#   (g) a SHARD CHILD ended by a signal is named "WAS ENDED BY SIG..., its slice is UNMEASURED", never a bare rc
#   (h) THE RUNSTATE IS NEVER UNDER THE CHECKOUT: a state file under out/ or the root would move a watched path
#       on every arm and make the race detector convict every concurrent arm -- one instrument sabotaging its
#       sibling, one directory apart
#   (i) NO RAW BOX-WIDE KILL IN A TRACKED SCRIPT: pkill/killall outside s4e_kill_mine.sh is the reach itself,
#       measured at ZERO executable sites today and pinned there
#   (j) THE LEDGER ROW IS WRITTEN BEFORE THE SIGNAL -- structural and deterministic, because the defect is a
#       RACE and a race arm that happens to win on a quiet box proves nothing. THE DETECTOR of this class.
#   (k) SEVERAL VICTIMS IN ONE KILL all name the same sender and none accuses an unlogged rogue -- end-to-end
#       corroboration that the lookup and the per-pid loop still agree; measured NOT to red on the old order
#       at four victims, so a green here is not evidence the race is closed
#   (l) A SET THAT CANNOT MEASURE REFUSES BEFORE IT SPENDS THE BOX -- the other half of this row. 260 of 381
#       arms once refused one at a time, over 387s, for one reason discovered 260 times
# FAIL_ONCE=1 unwires the traps -- (a), (b) and (c) must fail.
# FAIL_ONCE=2 makes the ledger lookup name somebody for any pid -- (b) must fail, because slandering an unlogged
# killer is worse than admitting the record is missing.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE/../../SCRIP" || exit 2
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
D0="$HERE/run_blocking_set.sh"; K="$HERE/s4e_kill_mine.sh"
refuse(){ echo "⛔ REFUSED-TO-GRADE (rc=2): $*"; exit 2; }
[ -f "$D0" ] || refuse "no driver at $D0"
[ -f "$K" ]  || refuse "no scoped kill tool at $K -- the ledger this gate reads is written there"
fails=0; checks=0
ck(){ checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
W="$(mktemp -d)" || refuse "no temp dir"; trap 'rm -rf "$W"' EXIT
echo "=== gate: a blocking set that dies names what ended it -- signal, arm, elapsed, sender ==="

MUT=""
mutant(){ # mutant <dir> <sed-expr> <anchor>
  mkdir -p "$W/$1" && cp "$D0" "$W/$1/run_blocking_set.sh" || refuse "cannot build mutant $1"
  grep -q -- "$3" "$W/$1/run_blocking_set.sh" || refuse "mutant $1 has no anchor '$3' -- a mutant that does not mutate proves nothing"
  sed -i "$2" "$W/$1/run_blocking_set.sh"
  grep -q -- "$3" "$W/$1/run_blocking_set.sh" && refuse "mutant $1 left its anchor in place -- the sed matched nothing"
  MUT="$W/$1/run_blocking_set.sh"
}
mutant m1 "/^trap 'death_report/d" "trap 'death_report TERM; exit 143' TERM"; M1="$MUT"
mutant m2 's/\$6 == pid/1/' '$6 == pid'; M2="$MUT"
D="$D0"; LIVE="the shipped driver"
case "${FAIL_ONCE:-}" in
  1) D="$M1"; LIVE="MUTANT M1 (traps unwired) -- (a), (b) and (c) MUST fail" ;;
  2) D="$M2"; LIVE="MUTANT M2 (the lookup names anybody) -- (b) MUST fail" ;;
esac
echo "  driver under test: $LIVE"

# ---- the fixture: 60 short arms, so a trap fires within a third of a second of the signal.  Bash defers a trap
# while a foreground arm runs, so a fixture of long arms would measure the deferral and not the report.
for _i in $(seq 1 60); do echo 'bash -c "sleep 0.3"'; done > "$W/arms.txt"
: > "$W/nos.txt"
export S4E_KILL_LEDGER="$W/kills.tsv"
export S4E_BLOCKING_RUNSTATE="$W/runstate"
# ⛔ NOT A FUNCTION RETURNING $! THROUGH A COMMAND SUBSTITUTION. `p=$(run_bg ...)` starts the job inside a
# SUBSHELL, which then exits and orphans it -- and `wait "$p"` in this shell answers 127 "not a child", which
# reads exactly like the driver failing to start. Every run below is started in THIS shell, on purpose.
start(){ :; }
# ⛔ EVERY WAIT IS ON A CONDITION WITH A CEILING THAT REFUSES, NEVER A FIXED SLEEP READ AS A RED (coo 2026-09-25, row
# instruments-the-blocking-set-death-gate-reds-under-load-...). Arm (d) killed its postmortem run one second after
# starting it, and the driver's pre-start currency check (a git ls-files stat scan) runs BEFORE the postmortem: at
# load 21-24 on 62a21f70f the run died before it spoke, and (d) read postmortem=0 -- a red about the load, not the
# driver. A ceiling that passes is could-not-measure (rc=2) and names the load; a condition that arrives is graded.
CEIL="${DEATH_GATE_CEILING_S:-120}"
load1(){ cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo '?'; }
wait_for(){ local f="$1" re="$2" t0=$SECONDS; while [ $((SECONDS - t0)) -lt "$CEIL" ]; do grep -qE -- "$re" "$f" 2>/dev/null && return 0; sleep 0.1; done; return 1; }
wait_started(){ wait_for "$1" '^\['; }

# ⛔ THE LEDGER IS SEEDED WITH SOMEBODY ELSE'S KILL BEFORE ARM (b) RUNS, AND THAT SEED IS LOAD-BEARING. A
# lookup graded against an EMPTY ledger cannot tell "refuses to guess" from "had nothing to guess with": the
# greedy mutant M2 passed arm (b) silently for exactly that reason until this line existed. It is also the real
# shape of the file -- ten seats share it, so a victim's lookup always runs against other seats' entries.
printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "2026-09-20T00:00:00Z" "someoneelse" "/home/claude_other" "999998" "TERM" "999999" \
    "some other seat's process" "/home/claude_other/SCRIP" "unrelated-pattern" > "$W/kills.tsv"

# ---- (a) + (b) a trapped death, with no ledger entry for it
bash "$D" --arms-from "$W/arms.txt" --serial-arms "$W/nos.txt" --shared-surfaces "$W/nosurf.txt" > "$W/a.out" 2>&1 & p=$!
wait_started "$W/a.out" || { kill -TERM "$p" 2>/dev/null; wait "$p" 2>/dev/null; refuse "the fixture run never reached its first arm inside ${CEIL}s at load $(load1) -- nothing was exercised"; }
sleep 1; kill -TERM "$p" 2>/dev/null; wait "$p" 2>/dev/null; a_rc=$?
if [ "$a_rc" = 143 ] && grep -q 'KILLED BY SIGTERM' "$W/a.out" \
   && grep -qE 'arm reached : [0-9]+ of 60' "$W/a.out" && grep -qE 'elapsed +: [0-9]+s' "$W/a.out"; then
  ck ok "(a) a trapped death names SIGTERM, the arm it reached of 60, and its elapsed, and exits 143 -- $(grep -m1 'arm reached' "$W/a.out" | sed 's/^ *//')"
else
  ck no "(a) the trapped death did not report: rc=$a_rc (want 143), report=$(grep -c 'KILLED BY' "$W/a.out")"
fi
if grep -q 'NO LEDGER ENTRY' "$W/a.out" && grep -q 'UNLOGGED KILLER' "$W/a.out"; then
  ck ok "(b) a bare kill is named as an UNLOGGED KILLER -- the instrument refuses to guess a sender it cannot see"
else
  ck no "(b) the unlogged case was not named: $(grep -m1 'SENDER' "$W/a.out" | cut -c1-120)"
fi

# ---- (c) a recorded kill names its sender
bash "$D" --arms-from "$W/arms.txt" --serial-arms "$W/nos.txt" --shared-surfaces "$W/nosurf.txt" > "$W/c.out" 2>&1 & p=$!
wait_started "$W/c.out" || { kill -TERM "$p" 2>/dev/null; wait "$p" 2>/dev/null; refuse "the fixture run never started for the sender arm inside ${CEIL}s at load $(load1)"; }
sleep 1
S4E_SEAT=gatefixture bash "$K" --root "$(dirname "$ROOT")" -- "$(basename "$W")" > "$W/kill.out" 2>&1
wait "$p" 2>/dev/null; c_rc=$?
if grep -q 'SENDER    : seat=gatefixture' "$W/c.out" && grep -q 'sender_pid=' "$W/c.out" && grep -q 'signal=SIGTERM' "$W/c.out"; then
  ck ok "(c) a kill sent through s4e_kill_mine.sh NAMES ITS SENDER to the victim -- seat, root, pid, signal and time, from the ledger"
else
  ck no "(c) the sender was not named (victim rc=$c_rc): $(grep -m1 'SENDER' "$W/c.out" | cut -c1-140); ledger lines=$(wc -l < "$W/kills.tsv" 2>/dev/null || echo 0)"
fi

# ---- (d) SIGKILL: untrappable, and legible from the next run
bash "$D0" --arms-from "$W/arms.txt" --serial-arms "$W/nos.txt" --shared-surfaces "$W/nosurf.txt" > "$W/d1.out" 2>&1 & p=$!
wait_started "$W/d1.out" || { kill -KILL "$p" 2>/dev/null; wait "$p" 2>/dev/null; refuse "the fixture run never started for the SIGKILL arm inside ${CEIL}s at load $(load1)"; }
sleep 1; kill -KILL "$p" 2>/dev/null; wait "$p" 2>/dev/null; d_rc=$?
said_nothing=1; grep -q 'KILLED BY' "$W/d1.out" && said_nothing=0
bash "$D0" --arms-from "$W/arms.txt" --serial-arms "$W/nos.txt" --shared-surfaces "$W/nosurf.txt" > "$W/d2.out" 2>&1 & p2=$!
# the driver prints its header on the line after runstate_postmortem returns, so the header is the condition that the
# postmortem phase is over -- whatever it printed or failed to print, which is what this arm grades
wait_for "$W/d2.out" '^=== blocking set' || { kill -TERM "$p2" 2>/dev/null; wait "$p2" 2>/dev/null; refuse "the postmortem run never passed its postmortem inside ${CEIL}s at load $(load1) -- arm (d) was NOT EXERCISED, which is a could-not-measure and not a pass"; }
kill -TERM "$p2" 2>/dev/null; wait "$p2" 2>/dev/null
if [ "$d_rc" = 137 ] && [ "$said_nothing" = 1 ] && grep -q 'POSTMORTEM OF THE PREVIOUS RUN' "$W/d2.out" \
   && grep -qE "pid=$p started .* reached arm [0-9]+ of 60" "$W/d2.out"; then
  ck ok "(d) SIGKILL is untrappable and the victim said NOTHING, and THE NEXT RUN postmortemed it by pid and arm -- $(grep -m1 'reached arm' "$W/d2.out" | sed 's/^ *//' | cut -c1-90)"
else
  ck no "(d) the SIGKILL path: victim rc=$d_rc (want 137), victim silent=$said_nothing (want 1), postmortem=$(grep -c 'POSTMORTEM' "$W/d2.out")"
fi

# ---- (e) a completed run leaves no postmortem
printf 'bash -c "exit 0"\n' > "$W/one.txt"
bash "$D0" --arms-from "$W/one.txt" --serial-arms "$W/nos.txt" --shared-surfaces "$W/nosurf.txt" > "$W/e1.out" 2>&1
bash "$D0" --arms-from "$W/one.txt" --serial-arms "$W/nos.txt" --shared-surfaces "$W/nosurf.txt" > "$W/e2.out" 2>&1
if ! grep -q 'POSTMORTEM' "$W/e2.out"; then
  ck ok "(e) a COMPLETED run leaves no postmortem -- a death report after a clean run is the same defect wearing the other sign"
else
  ck no "(e) a clean run was postmortemed by the next one: $(grep -m1 -A1 'POSTMORTEM' "$W/e2.out" | tr '\n' ' ' | cut -c1-120)"
fi

# ---- (f) --explain-only records nothing
before=$(wc -l < "$W/kills.tsv" 2>/dev/null || echo 0)
bash "$K" --explain-only --root "$(dirname "$ROOT")" -- "$(basename "$W")" > "$W/f.out" 2>&1
after=$(wc -l < "$W/kills.tsv" 2>/dev/null || echo 0)
if [ "$before" = "$after" ] && grep -q 'SIGNALLING NOTHING' "$W/f.out"; then
  ck ok "(f) --explain-only signals nothing and RECORDS nothing -- a ledger line for an event that did not happen is a false green in ledger clothing (ledger held at $after line(s))"
else
  ck no "(f) --explain-only moved the ledger from $before to $after line(s)"
fi

# ---- (g) a shard child ended by a signal is named as ENDED, not as a bare rc
bash "$D0" --arms-from "$W/arms.txt" --serial-arms "$W/nos.txt" --shared-surfaces "$W/nosurf.txt" --shards 3 > "$W/g.out" 2>&1 &
gp=$!; gk=""; g_t0=$SECONDS
while [ $((SECONDS - g_t0)) -lt "$CEIL" ]; do
  for c in $(pgrep -P "$gp" 2>/dev/null); do
    for gc in $(pgrep -P "$c" 2>/dev/null); do
      ( tr '\0' ' ' < "/proc/$gc/cmdline" ) 2>/dev/null | grep -q -- '--shard' && { gk="$gc"; break; }
    done
    [ -n "$gk" ] && break
  done
  [ -n "$gk" ] && break
  sleep 0.1
done
if [ -z "$gk" ]; then
  kill -TERM "$gp" 2>/dev/null; wait "$gp" 2>/dev/null
  refuse "could not identify a shard child inside ${CEIL}s at load $(load1) -- arm (g) was NOT EXERCISED, which is a could-not-measure and not a pass"
fi
kill -KILL "$gk" 2>/dev/null; wait "$gp" 2>/dev/null; g_rc=$?
if grep -q 'WAS ENDED BY SIGKILL' "$W/g.out" && grep -q 'UNMEASURED, not green and not red' "$W/g.out"; then
  ck ok "(g) a shard child ended by a signal is named ENDED BY SIGKILL with its slice UNMEASURED -- never a bare rc a reader has to decode"
else
  ck no "(g) the killed shard was not named (run rc=$g_rc): $(grep -m1 'shard 1/3\|shard 2/3\|shard 3/3' "$W/g.out" | cut -c1-110)"
fi

# ---- (h) the runstate is never under the checkout
dflt="$(grep -m1 'RUNSTATE="\${S4E_BLOCKING_RUNSTATE' "$D0" || true)"
case "$dflt" in
  *"/tmp/si_blockingset"*) ck ok "(h) the default RUNSTATE is /tmp per root and never under the checkout -- a state file under out/ or the root would move a watched path on every arm and make the race detector convict every concurrent arm" ;;
  *) ck no "(h) the RUNSTATE default is not clearly outside the checkout: ${dflt:-<not found>}" ;;
esac

# ---- (i) no raw box-wide kill in a tracked script
raw=""
for f in "$HERE"/*.sh "$HERE"/*.py "$ROOT/Makefile"; do
  case "$f" in *s4e_kill_mine.sh|*test_gate_a_blocking_set_death_names_its_killer.sh) continue ;; esac
  hit="$(grep -nE '(^|[;&|(` ])(pkill|killall)([ ]|$)' "$f" 2>/dev/null | grep -vE '^[0-9]+: *#' | grep -vE 'echo|printf|"' || true)"
  [ -n "$hit" ] && raw="$raw$f: $hit
"
done
if [ -z "$raw" ]; then
  ck ok "(i) ZERO executable pkill/killall sites outside s4e_kill_mine.sh -- the box-wide reach that signalled eleven pids has no home in a tracked script, and this pins it there"
else
  ck no "(i) raw box-wide kill(s) found: $(printf '%s' "$raw" | head -3 | tr '\n' ';')"
fi

# ---- (j) THE LEDGER ROW IS WRITTEN BEFORE THE SIGNAL, AND THIS ARM IS STRUCTURAL ON PURPOSE
# ⛔ WHY A STRUCTURAL ARM AND NOT ONLY THE END-TO-END ONE BELOW: the defect this pins is a RACE, and a race
# arm that happens to win proves nothing on a quiet box. The ORDER of the two statements is the invariant --
# it is deterministic, it is the whole cure, and it cannot pass by luck. (cfo 2026-09-20, proven on their own
# board: pid 783278 signalled 22:14:36Z, its trap read this ledger at 22:14:35Z and reported AN UNLOGGED
# KILLER about a kill that was correct, scoped and recorded. THE VICTIM LOST BY ONE SECOND.)
append_before_signal(){ # <kill-tool> -> 0 when the ledger append precedes the signal in the per-pid loop
  local f="$1" body ap sg
  body="$(sed -n '/^for pid in /,/^done$/p' "$f" | grep -vE '^[[:space:]]*#')"
  ap="$(printf '%s\n' "$body" | grep -n 'kill_ledger_append' | head -1 | cut -d: -f1)"
  sg="$(printf '%s\n' "$body" | grep -n 'kill -TERM' | head -1 | cut -d: -f1)"
  [ -n "$ap" ] && [ -n "$sg" ] && [ "$ap" -lt "$sg" ]
}
mkdir -p "$W/km"
awk '/^for pid in /{inloop=1}
     inloop && /kill_ledger_append "\$pid"/ && held=="" {held=$0; next}
     inloop && held!="" && /^  fi$/ {print; print held; held=""; next}
     {print}' "$K" > "$W/km/s4e_kill_mine.sh"
if append_before_signal "$W/km/s4e_kill_mine.sh"; then
  refuse "the arm (j) mutant did not reorder anything -- a mutant that does not mutate proves nothing, so this arm is UNEXERCISED and that is a could-not-measure"
fi
if append_before_signal "$K"; then
  ck ok "(j) s4e_kill_mine.sh appends the ledger row BEFORE it sends the signal -- a victim that dies promptly can still name its killer, and the same check REDS on a mutant with the order swapped"
else
  ck no "(j) the signal is sent BEFORE the ledger row is written -- every promptly-dying victim will read an empty ledger and accuse a phantom unlogged rogue"
fi

# ---- (k) SEVERAL VICTIMS IN ONE KILL: every one of them names its sender
# ⛔⭐ THIS ARM IS CORROBORATION AND ARM (j) IS THE DETECTOR, AND I AM SAYING SO BECAUSE I MEASURED IT RATHER
# THAN BECAUSE IT SOUNDS MODEST. Reverting the cure on this same tree (coo 2026-09-21, load 2.48) REDS ARM (j)
# AND LEAVES THIS ARM GREEN: at four victims on a quiet box the append still beat every trap. The cfo's real
# kill signalled NINETEEN pids, so their pid's append landed after eighteen other /proc probes -- the race is
# structural in the ORDER and its VISIBILITY scales with the target count and the load, which is exactly why
# the invariant is pinned by (j)'s deterministic check and not by this one's stopwatch.
# ⛔ SO WHAT THIS ARM IS FOR, STATED HONESTLY: it proves the END-TO-END path still agrees under concurrency --
# every victim of one scoped kill names the same sender -- and it would catch a cure that fixed the statement
# order while breaking the lookup, the field-6 key or the per-pid loop. A GREEN HERE IS NOT EVIDENCE THAT THE
# RACE IS CLOSED. Arm (j) is that evidence.
kv=(); ki=""
for i in 1 2 3 4; do
  bash "$D" --arms-from "$W/arms.txt" --serial-arms "$W/nos.txt" --shared-surfaces "$W/nosurf.txt" > "$W/k$i.out" 2>&1 & kv+=($!)
done
for i in 1 2 3 4; do wait_started "$W/k$i.out" || ki="$ki $i"; done
if [ -n "$ki" ]; then
  for p in "${kv[@]}"; do kill -TERM "$p" 2>/dev/null; wait "$p" 2>/dev/null; done
  refuse "fixture run(s)$ki never reached a first arm -- arm (k) was NOT EXERCISED, which is a could-not-measure and not a pass"
fi
sleep 1
S4E_SEAT=gatefixture bash "$K" --root "$(dirname "$ROOT")" -- "$(basename "$W")" > "$W/k.kill" 2>&1
for p in "${kv[@]}"; do wait "$p" 2>/dev/null; done
k_named=0; k_unlogged=0
for i in 1 2 3 4; do
  grep -q 'SENDER    : seat=gatefixture' "$W/k$i.out" && k_named=$((k_named+1))
  grep -q 'UNLOGGED KILLER' "$W/k$i.out" && k_unlogged=$((k_unlogged+1))
done
if [ "$k_named" = 4 ] && [ "$k_unlogged" = 0 ]; then
  ck ok "(k) one scoped kill over 4 concurrent victims: ALL 4 named seat=gatefixture with its pid, root and signal, and ZERO accused an unlogged killer"
else
  ck no "(k) $k_named of 4 victims named their sender and $k_unlogged accused an UNLOGGED KILLER over a kill that was recorded -- the signal is outrunning its own ledger row"
fi

# ---- (l) A RUN THAT CANNOT MEASURE REFUSES BEFORE IT SPENDS THE BOX, NOT 260 TIMES AFTER
# ⛔ THE MEASUREMENT THAT PUT THIS ARM HERE, and it is the other half of this row -- not "what ended it" but
# "why no seat completes one". A full set on this box at 6 shards, tree c8ba4567b: arms=381 green=110 red=11
# REFUSED=260, wall 387s. Every one of the 260 refused for the SAME reason, discovered 260 separate times: the
# binary predated the tree. AND THE CAUSE WAS THE DOCUMENTED LANDING SEQUENCE -- git pull --rebase replays a
# commit and rewrites its files with a NEW MTIME, identical bytes, so build/test/commit/rebase/push leaves the
# Makefile newer than a binary that is semantically current. Reflog: build 10:01:58, rebase pick 10:03:28, set
# started 10:03:52. Nothing was stale; every arm refused anyway.
# ⛔ AND rc=2 IS NOT RED, so the set completed and printed "6 blocking arm(s) failed, 256 refused" -- a
# two-thirds DARK gate reporting in the same shape as a two-thirds green one. CEO-582 inside the landing gate.
# ⭐ SCRIP_STALE_PROBE_SRC IS THE LIBRARY'S OWN SANCTIONED SCRATCH PROBE (lib_gate.sh): it names one extra
# candidate for "newest source" so a proof like this runs against a temp file instead of touching a tracked
# src/ file -- a proof that edits the tree it grades is how a green gate and a dirty checkout coexist. It can
# only make the verdict STRICTER, so it cannot smuggle a stale binary past anything.
printf 'bash -c "exit 0"\n' > "$W/l.arms"
touch "$W/l.probe"
l_t0=$(date +%s)
SCRIP_STALE_PROBE_SRC="$W/l.probe" bash "$D0" --arms-from "$W/l.arms" --serial-arms "$W/nos.txt" --shared-surfaces "$W/nosurf.txt" > "$W/l.out" 2>&1
l_rc=$?; l_el=$(( $(date +%s) - l_t0 ))
bash "$D0" --arms-from "$W/l.arms" --serial-arms "$W/nos.txt" --shared-surfaces "$W/nosurf.txt" > "$W/l2.out" 2>&1
l2_rc=$?
if [ "$l_rc" = 2 ] && grep -q 'REFUSES TO START' "$W/l.out" && ! grep -q '^blocking set: arms=' "$W/l.out" \
   && [ "$l2_rc" = 0 ] && grep -q '^blocking set: arms=1' "$W/l2.out"; then
  ck ok "(l) a set whose binary predates the tree REFUSES rc=2 BEFORE running any arm (${l_el}s, and it ran none), while the same set on a current binary runs -- 260 of 381 arms once refused one at a time over 387s for this one reason"
else
  ck no "(l) the pre-start refusal did not hold: stale rc=$l_rc (want 2, arms run=$(grep -c '^blocking set: arms=' "$W/l.out")), current rc=$l2_rc (want 0)"
fi

echo "population: $checks arm(s) graded, $fails FAIL; fixture 60 arms x 4 runs plus one 3-shard fan-out; every wait on a condition, ceiling ${CEIL}s; ledger $(wc -l < "$W/kills.tsv" 2>/dev/null || echo 0) line(s); load $(cut -d' ' -f1 /proc/loadavg)"
if [ "$fails" -eq 0 ]; then
  echo "GATE PASS [a_blocking_set_death_names_its_killer]: $checks of $checks arms hold"; exit 0
fi
echo "⛔ GATE RED [a_blocking_set_death_names_its_killer]: $fails of $checks arms FAIL"; exit 1
