#!/usr/bin/env bash
# test_gate_fanout_width_reads_cpu_pressure_not_load1.sh -- THE FAN-OUT WIDTH READS THE MACHINE'S CPU DEMAND, NEVER load1 (ceo CEO-1394 on
# the coo's COO-241 measurement; row instruments-the-fan-out-width-reads-cpu-pressure-or-procs-running-never-load1-which-coexpression-thread-
# bursts-inflated-to-1219-at-3-percent-cpu). MEASURED CAUSE: at 2026-10-01 15:00 CDT load1 read 1219 while PSI cpu read 3 percent (three SCRIP
# Icon programs each held 8k to 16k co-expression pthreads), and lib_fanout.sh's max(2, min(4, cores - load1)) put every fan-out on the box at
# width 2 on an idle machine. The shape stands; its input is the CPU demand (lib_fanout.sh's header). WHAT THIS GATE HOLDS, over planted
# machines under FANOUT_PROC (a scratch /proc of loadavg, pressure/cpu and stat): (1) the 15:00 machine -- load1 1219, pressure 3 percent --
# reads min(4, cores - 0.03 cores), 4 on this 16-core box, in the shell helper and the python mirror; (2) FAIL-ONCE: a planted helper whose
# demand is load1 again (the pre-cure reader) reads 2 on the same machine, so arm 1 would red on it; (3) PASS-ONCE: pressure at saturation
# (100 percent) reads 2 in both mirrors; (4) a kernel without PSI falls back to procs_running less the reader, in both mirrors; (5)
# FANOUT_TEST_LOAD still plants the demand; (6) the live reading is 2..4 and names its source; (7) no runner's clamp message names load1 as
# the reason it clamped. rc 2 when the helper or its mirror is missing, or on a box under 6 cores, where 4 and 2 cannot be told apart.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; cd "$HERE/../../SCRIP" || { echo "⛔ REFUSE(2): cannot cd to SCRIP root" >&2; exit 2; }
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "⛔ REFUSE(2): no lib_gate.sh" >&2; exit 2; }
GATE_NAME=fanout_width_reads_cpu_pressure_not_load1; gate_parse_args "$@" 2>/dev/null || true
LIB="$HERE/lib_fanout.sh"; PY="$HERE/lib_fanout.py"
[ -f "$LIB" ] || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: $LIB is missing -- the width has no instrument"; exit 2; }
[ -f "$PY" ]  || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: $PY is missing -- the python runners have no mirror"; exit 2; }
unset FANOUT_TEST_LOAD FANOUT_PROC
. "$LIB"
command -v fanout_demand >/dev/null || { echo "⛔ GATE FAIL(1) [$GATE_NAME]: lib_fanout.sh defines no fanout_demand -- the width still reads load1"; gate_stamp; exit 1; }
cores=$(fanout_cores)
[ "$cores" -ge 6 ] || { echo "⛔ GATE REFUSE(2) [$GATE_NAME]: $cores core(s) -- below 6 the planted machines' widths of 4 and 2 coincide and the fail-once cannot trip"; exit 2; }
red=0; n=0
arm() { n=$((n+1)); if [ "$2" = "$3" ]; then echo "  ok   $n $1: $2"; else echo "  FAIL $n $1: got '$2' want '$3'"; red=$((red+1)); fi; }
clamp() { awk -v d="$1" -v c="$cores" 'BEGIN { w = int(c - d); if (w > 4) w = 4; if (w < 2) w = 2; print w }'; }
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
machine() {  # <dir> <load1> <pressure avg10, or - for a kernel without PSI> <procs_running>
    mkdir -p "$1/pressure"; printf '%s %s %s 3/20000 4242\n' "$2" "$2" "$2" > "$1/loadavg"
    [ "$3" = - ] || printf 'some avg10=%s avg60=%s avg300=%s total=1\nfull avg10=0.00 avg60=0.00 avg300=0.00 total=0\n' "$3" "$3" "$3" > "$1/pressure/cpu"
    printf 'cpu  1 2 3 4\nprocs_running %s\nprocs_blocked 0\n' "$4" > "$1/stat"
}
machine "$T/idle1219" 1219.00 3.00 3
machine "$T/saturated" 52.60 100.00 60
machine "$T/nopsi_busy" 2.00 - 15
machine "$T/nopsi_idle" 2.00 - 2
want_idle=$(clamp "$(awk -v c="$cores" 'BEGIN { printf "%.2f", c * 3 / 100 }')")
echo "--- the 15:00 machine: load1 1219, PSI cpu some avg10 3 percent, $cores cores ---"
arm "shell width on the 15:00 machine (load1 1219, pressure 3 percent)" "$(FANOUT_PROC=$T/idle1219 fanout_width)" "$want_idle"
arm "python width on the 15:00 machine" "$(FANOUT_PROC=$T/idle1219 python3 "$PY")" "$want_idle"
arm "its source is the pressure file" "$(FANOUT_PROC=$T/idle1219 fanout_source)" pressure
arm "load1 is still reported" "$(FANOUT_PROC=$T/idle1219 fanout_load1)" 1219.00
{ cat "$LIB"; printf '\nfanout_demand() { fanout_load1; }  # FAIL-ONCE: the pre-cure reader, load1 as the demand\n'; } > "$T/lib_fanout_load1.sh"
pl=$(. "$T/lib_fanout_load1.sh"; FANOUT_PROC=$T/idle1219 fanout_width); n=$((n+1))
if [ "$pl" = 2 ] && [ "$want_idle" = 4 ]; then echo "  ok   $n FAIL-ONCE: the planted helper reading load1 as the demand reads $pl on the 15:00 machine where the rule says $want_idle -- arm 1 would red on it"
else echo "  FAIL $n FAIL-ONCE did not trip: the load1 helper read '$pl', the rule '$want_idle' -- this gate could not tell the pre-cure reader from the cure"; red=$((red+1)); fi
echo "--- PASS-ONCE and the fallback ---"
arm "shell width at saturation (pressure 100 percent)" "$(FANOUT_PROC=$T/saturated fanout_width)" 2
arm "python width at saturation" "$(FANOUT_PROC=$T/saturated python3 "$PY")" 2
arm "shell width without PSI, procs_running 15 (demand 14)" "$(FANOUT_PROC=$T/nopsi_busy fanout_width)" "$(clamp 14)"
arm "python width without PSI, procs_running 15" "$(FANOUT_PROC=$T/nopsi_busy python3 "$PY")" "$(clamp 14)"
arm "shell width without PSI, procs_running 2 (demand 1)" "$(FANOUT_PROC=$T/nopsi_idle fanout_width)" "$(clamp 1)"
arm "python width without PSI, procs_running 2" "$(FANOUT_PROC=$T/nopsi_idle python3 "$PY")" "$(clamp 1)"
arm "the fallback names its source" "$(FANOUT_PROC=$T/nopsi_busy fanout_source)" procs_running
arm "FANOUT_TEST_LOAD still plants the demand, over a machine that says otherwise" "$(FANOUT_TEST_LOAD=52 FANOUT_PROC=$T/idle1219 fanout_width)" 2
echo "--- the live box and the runners ---"
live=$(fanout_width); src=$(fanout_source); n=$((n+1))
if [ "$live" -ge 2 ] && [ "$live" -le 4 ] 2>/dev/null && [ "$src" != none ]; then echo "  ok   $n live width $live from $src (demand $(fanout_demand), load1 $(fanout_load1), $cores cores)"
else echo "  FAIL $n live width '$live' from source '$src' -- outside 2..4, or the box offered no demand reading"; red=$((red+1)); fi
named=$(grep -lE 'clamped to .* at load1' ../harness/scripts/*.sh ../harness/scripts/*.py 2>/dev/null | grep -v "/${0##*/}$"); n=$((n+1))
if [ -z "$named" ]; then echo "  ok   $n no runner's clamp message names load1 as its reason"; else echo "  FAIL $n a clamp message still names load1: $(echo $named)"; red=$((red+1)); fi
GATE_EXAMINED=$n
echo "population: $n arm(s) over 4 planted machines and the live box ($cores cores)"
if [ "$red" -eq 0 ]; then echo "GATE PASS(0) [$GATE_NAME]: the fan-out width reads the CPU demand (PSI, else procs_running) in the shell helper and its python mirror, never load1; the fail-once trips"; gate_stamp; exit 0; fi
echo "GATE FAIL(1) [$GATE_NAME]: $red of $n arms red"; gate_stamp; exit 1
