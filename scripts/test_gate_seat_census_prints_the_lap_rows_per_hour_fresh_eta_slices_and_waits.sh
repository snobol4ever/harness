#!/usr/bin/env bash
# test_gate_seat_census_prints_the_lap_rows_per_hour_fresh_eta_slices_and_waits.sh -- DESIGN-PLAN box-budget step 1 (the cto, CTO-474/478; the
# shared-box skill section 7; the cqo's row box-budget-step-1-the-ledger-prints-the-lap-every-tick-cto-478). util_seat_census.py --lap is the lap
# every tick: plant a loop directory (loop8.sh's ROT, idle_units), the population cache, results.tsv, LOAD.tsv and SLOT_WAITS.tsv under scratch with
# answers known by construction, and read each line's numbers: the loop's rows per hour (the coo's rr=1 or req= readings only), fresh=F/T by
# util_round_robin_freshness.py's rule over 72 h, the ETA of the stale rows and the lap's length, each class's and seat's mean cores over the window,
# and the slot waits; a window with no reading reads eta=never; no results.tsv or no rotation REFUSES; `run` appends the LAP line to LOAD.tsv.
# Hermetic: no real ledger, no from-progress call (the cache is planted fresh). rc 0 every arm as expected; rc 1 an arm read wrong; rc 2 cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; G=seat_census_prints_the_lap_rows_per_hour_fresh_eta_slices_and_waits
CENSUS="$HERE/util_seat_census.py"; [ -f "$CENSUS" ] && [ -f "$HERE/util_round_robin_freshness.py" ] && command -v python3 >/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: util_seat_census.py, util_round_robin_freshness.py or python3 absent"; exit 2; }
T=$(mktemp -d /tmp/s4e-lap-gate.XXXXXX); trap 'rm -rf "$T"' EXIT
plant() {   # plant <dir> <readings_in_the_hour 0|1>
python3 -I - "$@" <<'PY'
import sys, os, time
d, hour = sys.argv[1], int(sys.argv[2]); os.makedirs(d + "/loop", exist_ok=True); now = int(time.time())
st = lambda s: time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(s))
open(d + "/loop/loop8.sh", "w").write('ROT=(\n"master|snobol4"\n"pkg|swi|x|y|swi"\n)\n')
open(d + "/loop/idle_units", "w").write("# none idle\n")
open(d + "/pop.tsv", "w").write("# key\tat\tdb_suite\ttotal\nsno-rungs\t%d\tsnobol4-rungs\t100\nswi\t%d\tswi\t50\n" % (now, now))
H = ["ts_utc", "scrip", "corpus", "measurer", "class", "suite", "lang", "program", "mode", "outcome", "secs", "note", "fingerprint", "config"]
row = lambda t, who, suite, prog, mode, cfg: "\t".join([st(t), "abc", "def", who, "rungs", suite, "x", prog, mode, "PASS", "0.1", "-", "0", cfg])
R = ["\t".join(H)]
for i in range(30):
    for m in ("m3", "m4"):
        R.append(row(now - 600 if hour else now - 7200, "coo", "snobol4-rungs", "p%d.sno" % i, m, "partition=entry:p%d,rr=1" % i))
for i in range(20):
    R.append(row(now - 30 * 3600, "coo", "snobol4-rungs", "q%d.sno" % i, "m3", "partition=entry:q%d,req=hq_snobol4" % i))
for i in range(10):
    for m in ("m3", "m4"):
        R.append(row(now - 80 * 3600, "coo", "swi", "s%d" % i, m, "partition=entry:s%d,rr=1" % i))
R.append(row(now - 100, "coo", "swi", "board", "m3", "partition=core"))
R.append(row(now - 100, "cqo", "swi", "mine", "m3", "partition=entry:mine,rr=1"))
open(d + "/results.tsv", "w").write("\n".join(R) + "\n")
su = lambda s: st(s) + "Z"
L = ["\t".join(["utc", "kind", "class", "name", "cores", "mem_mb", "mem_peak_mb", "oom_kills", "pids", "cc_slots", "run_slots", "tmp_mb"])]
for t, g in ((now - 300, 3.0), (now - 900, 3.0), (now - 7200, 100.0)):
    L.append("\t".join([su(t), "UNIT", "SEAT", "a", "0.60", "1", "1", "0", "1", "0", "0", "0"]))
    L.append("\t".join([su(t), "UNIT", "SEAT", "b", "0.40", "1", "1", "0", "1", "0", "0", "0"]))
    L.append("\t".join([su(t), "CLASS", "SEAT", "seat", "1.00", "-", "-", "-", "-", "-", "-", "-"]))
    L.append("\t".join([su(t), "CLASS", "GRADER", "grader", "%.2f" % g, "-", "-", "-", "-", "-", "-", "-"]))
open(d + "/LOAD.tsv", "w").write("\n".join(L) + "\n")
W = ["# at_utc\tseat\tkind\twait_s\tcmd", "\t".join([su(now - 200), "a", "cc", "3.0", "gcc"]), "\t".join([su(now - 250), "a", "cc", "5.0", "gcc"]),
     "\t".join([su(now - 300), "b", "run", "10.0", "scrip"]), "\t".join([su(now - 7200), "b", "run", "999.0", "scrip"])]
open(d + "/SLOT_WAITS.tsv", "w").write("\n".join(W) + "\n")
open(d + "/SEATS.tsv", "w").write("utc\tseat\tclass\tscope\n")
PY
}
cen() { local d="$1"; shift; python3 -I "$CENSUS" "$@" --results "$d/results.tsv" --load "$d/LOAD.tsv" --waits "$d/SLOT_WAITS.tsv" --loop-dir "$d/loop" --pop-cache "$d/pop.tsv" --seats "$d/SEATS.tsv" 2>&1; }
fail=0; n=0
arm() {   # arm <name> <dir> <want_rc> <want_text> -- <census args>
  local name="$1" d="$2" want="$3" text="$4"; shift 5; n=$((n + 1))
  local out rc; out="$(cen "$d" "$@")"; rc=$?
  if [ "$rc" = "$want" ] && printf '%s\n' "$out" | grep -F -- "$text" >/dev/null; then echo "  ok   ARM $n: $name"
  else echo "  RED  ARM $n: $name -- rc $rc wanted $want, looking for '$text':"; printf '%s\n' "$out" | sed 's/^/         /' | head -5; fail=1; fi
}
plant "$T/day" 1; plant "$T/idle" 0
arm "the LAP line reads the loop's 60 rows (30 programs, both modes) in the hour, the cqo's and the untagged board's left out" "$T/day" 0 "LAP window=3600s rows_per_hour=60 programs=30 rows_per_test=2.00 fresh=50/150 (33%)" -- --lap 3600
arm "the ETA is the 100 stale tests at two rows each over 60 an hour, the lap 150 of them" "$T/day" 0 "stale=100 eta=+3.3h(" -- --lap 3600
arm "the 80-hour-old swi readings are stale, the 30-hour-old requests fresh, the untagged board reading counted outside" "$T/day" 0 "lap_h=5.0 outside=1 unresolved=0" -- --lap 3600
arm "LAP_SLICES: each class's mean cores over the window's two runs, the two-hour-old run left out" "$T/day" 0 "LAP_SLICES window=3600s runs=2 cores=4.00 GRADER=3.00c(75%) SEAT=1.00c(25%)" -- --lap 3600
arm "LAP_SEATS: each seat's mean cores" "$T/day" 0 "LAP_SEATS window=3600s a=0.60c b=0.40c" -- --lap 3600
arm "LAP_WAITS: the slot waits in the window by kind and by seat, the old 999 s wait left out" "$T/day" 0 "LAP_WAITS window=3600s cc=2/8s/max5s run=1/10s/max10s by_seat=b:10s,a:8s" -- --lap 3600
n=$((n + 1)); out="$(cen "$T/day" --lap 3600)"
if printf '%s\n' "$out" | grep -E '^LAP .*rows_per_hour=[0-9]+.*fresh=[0-9]+/[0-9]+.*eta=' >/dev/null; then echo "  ok   ARM $n: the step-1 probe of STEPS.tsv matches the LAP line"; else echo "  RED  ARM $n: the step-1 probe does not match: $(printf '%s' "$out" | head -1)"; fail=1; fi
arm "FAIL-ONCE: no reading in the hour reads rows_per_hour=0 and eta=never" "$T/idle" 0 "rows_per_hour=0 programs=0 rows_per_test=2.00 fresh=50/150 (33%) fresh_window=72h stale=100 eta=never lap_h=never" -- --lap 3600
arm "the longer window takes the idle plant's two-hour-old readings: 60 rows in three hours" "$T/idle" 0 "rows_per_hour=20 programs=30" -- --lap 10800
mkdir -p "$T/nores"; cp -r "$T/day/loop" "$T/day/pop.tsv" "$T/day/LOAD.tsv" "$T/day/SLOT_WAITS.tsv" "$T/day/SEATS.tsv" "$T/nores/"
arm "no results.tsv REFUSES" "$T/nores" 2 "REFUSED(2): no results.tsv" -- --lap 3600
mkdir -p "$T/norot"; cp "$T/day/results.tsv" "$T/day/pop.tsv" "$T/day/LOAD.tsv" "$T/day/SLOT_WAITS.tsv" "$T/day/SEATS.tsv" "$T/norot/"; mkdir -p "$T/norot/loop"
arm "a loop directory with no loop8.sh REFUSES" "$T/norot" 2 "REFUSED(2): no live rotation member" -- --lap 3600
mkdir -p "$T/root"; cp "$T/day/LOAD.tsv" "$T/day/LOAD.before"
n=$((n + 1)); out="$(cen "$T/day" run --root "$T/root")"; rc=$?; last="$(tail -1 "$T/day/LOAD.tsv")"
if [ "$rc" = 0 ] && printf '%s' "$last" | grep -F "	LAP	LAP	lap	window=3600s rows_per_hour=60 programs=30" >/dev/null; then echo "  ok   ARM $n: every tick (run) appends the LAP line to LOAD.tsv"; else echo "  RED  ARM $n: run rc $rc did not append the LAP line: $last $out"; fail=1; fi
echo "LAP_GATE_BOARD arms=$n fail=$fail (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null || echo -))"
[ "$fail" = 0 ] && { echo "GATE OK [$G]: --lap reads the loop's rate, freshness, ETA, slices, seats and waits from the planted ledgers, and the tick appends it"; exit 0; }
echo "GATE FAIL [$G]"; exit 1
