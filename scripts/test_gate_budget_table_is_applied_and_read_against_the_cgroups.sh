#!/usr/bin/env bash
# test_gate_budget_table_is_applied_and_read_against_the_cgroups.sh -- DESIGN-PLAN box-budget step 2 (the cto, CTO-474/478; the shared-box skill
# section 7; the cqo's row box-budget-step-2-one-declared-budget-table-applied-to-the-cgroups-cto-478). ONE declared budget table,
# /home/resources/postoffice/BUDGET.tsv: util_seat_census.py --budget-check reads every declared knob against the live cgroup file, and the appliers
# take their numbers from the table, never from a constant of their own. Plant a cgroup tree, SEATS.tsv and a table under scratch and read: GREEN
# when they agree; RED naming the unit, file, live and declared value on each planted drift (a slice weight, a seat's quota, a seat's memory.high, a
# slice absent, Lon's weight); REFUSE(2) with no table; --budget-props prints a row's systemd properties; s4e_session_start.sh --props and
# util_fleet_settings.sh's dry run print the table's numbers (a planted 300% quota and a planted 301 weight, values no constant holds).
# Hermetic: no real cgroup, no systemctl write. rc 0 every arm as expected; rc 1 an arm read wrong; rc 2 cannot measure.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; G=budget_table_is_applied_and_read_against_the_cgroups
CENSUS="$HERE/util_seat_census.py"; [ -f "$CENSUS" ] && [ -f "$HERE/s4e_session_start.sh" ] && [ -f "$HERE/util_fleet_settings.sh" ] && command -v python3 >/dev/null || { echo "⛔ GATE REFUSE(2) [$G]: util_seat_census.py, s4e_session_start.sh, util_fleet_settings.sh or python3 absent"; exit 2; }
T=$(mktemp -d /tmp/s4e-budget-gate.XXXXXX); trap 'rm -rf "$T"' EXIT
plant() {   # plant <dir> <grader_weight> <seat_cpu_max> <seat_memory_high> <batch 0|1> <lon_weight>
python3 -I - "$@" <<'PY'
import sys, os
d, gw, smax, shigh, batch, lw = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], int(sys.argv[5]), sys.argv[6]
svc = d + "/root/user@1000.service"
def unit(rel, **files):
    p = os.path.join(svc, rel); os.makedirs(p, exist_ok=True)
    for k, v in files.items():
        open(os.path.join(p, k.replace("_", ".")), "w").write(v + "\n")
unit("app.slice", cpu_weight="100")
unit("s4e.slice", cpu_weight="100")
unit("app.slice/app-org.gnome.Terminal.slice", cpu_weight="100", memory_high=str(20 << 30), memory_max=str(24 << 30))
unit("s4e.slice/s4e-grader.slice", cpu_weight=gw, memory_max=str(10 << 30))
if batch:
    unit("s4e.slice/s4e-batch.slice", cpu_weight="50", memory_max=str(12 << 30))
seat = dict(cpu_weight="100", cpu_max=smax, memory_high=shigh, memory_max=str(8 << 30), memory_swap_max=str(1 << 30), pids_max="2048")
unit("app.slice/app-org.gnome.Terminal.slice/vte-a.scope", **seat)
unit("app.slice/app-org.gnome.Terminal.slice/vte-b.scope", **seat)
unit("app.slice/app-org.gnome.Terminal.slice/vte-lon.scope", cpu_weight=lw)
pre = "/user.slice/user-1000.slice/user@1000.service/app.slice/app-org.gnome.Terminal.slice/"
open(d + "/SEATS.tsv", "w").write("utc\tseat\tclass\tscope\tpid\tstart\tweighted\n" + "".join("2026-11-04T00:00:00Z\t%s\t%s\t%s%s\t1\t?\tyes\n" % (s, c, pre, sc) for s, c, sc in (("a", "SEAT", "vte-a.scope"), ("b", "SEAT", "vte-b.scope"), ("lon", "LON", "vte-lon.scope"), ("gone", "SEAT", "vte-gone.scope"))))
H = "name\tunit\tCPUWeight\tCPUQuota\tMemoryHigh\tMemoryMax\tMemorySwapMax\tTasksMax\tapplied_by\truling\n"
rows = [("sessions-top", "app.slice", "100", "-", "-", "-", "-", "-"), ("loops-top", "s4e.slice", "100", "-", "-", "-", "-", "-"),
        ("sessions", "app-org.gnome.Terminal.slice", "100", "-", "20G", "24G", "-", "-"), ("grader", "s4e-grader.slice", "300", "-", "-", "10G", "-", "-"),
        ("batch", "s4e-batch.slice", "50", "-", "-", "12G", "-", "-"), ("seat", "@SEAT", "100", "400%", "4G", "8G", "1G", "2048"), ("lon", "@LON", "1000", "-", "-", "-", "-", "-")]
ab = lambda r: "box_controller.sh moves the quota under this ceiling" if (os.environ.get("CEIL") and r[0] == "seat") else "gate"
open(d + "/BUDGET.tsv", "w").write("# the gate's table\n" + H + "".join("\t".join(r) + "\t" + ab(r) + "\tgate\n" for r in rows))
odd = [r if r[0] != "seat" else r[:3] + ("300%",) + r[4:] for r in rows]
odd = [r if r[0] != "grader" else r[:2] + ("301",) + r[3:] for r in odd]
open(d + "/ODD.tsv", "w").write(H + "".join("\t".join(r) + "\tgate\tgate\n" for r in odd))
PY
}
fail=0; n=0
say() { if [ "$1" = ok ]; then echo "  ok   ARM $n: $2"; else echo "  RED  ARM $n: $2 -- $3"; fail=1; fi; }
arm() {   # arm <name> <dir> <want_rc> <want_text> -- <census args>
  local name="$1" d="$2" want="$3" text="$4"; shift 5; n=$((n + 1))
  local out rc; out="$(python3 -I "$CENSUS" "$@" --budget "$d/BUDGET.tsv" --root "$d/root" --seats "$d/SEATS.tsv" 2>&1)"; rc=$?
  if [ "$rc" = "$want" ] && printf '%s\n' "$out" | grep -F -- "$text" >/dev/null; then say ok "$name"; else say red "$name" "rc $rc wanted $want, looking for '$text' in: $(printf '%s' "$out" | head -4 | tr '\n' '|')"; fi
}
G4=$((4 << 30)); G3=$((3 << 30))
plant "$T/good" 300 "400000 100000" "$G4" 1 1000
plant "$T/grader" 100 "400000 100000" "$G4" 1 1000
plant "$T/quota" 300 "max 100000" "$G4" 1 1000
plant "$T/high" 300 "400000 100000" "$G3" 1 1000
plant "$T/nobatch" 300 "400000 100000" "$G4" 0 1000
plant "$T/lon" 300 "400000 100000" "$G4" 1 100
arm "the planted box agrees with its table: GREEN over 5 slices, 2 live seats and Lon (the gone seat's scope not read)" "$T/good" 0 "rows=7 units=8 knobs=22 gaps=0" -- --budget-check
CEIL=1 plant "$T/ceil_under" 300 "200000 100000" "$G4" 1 1000
CEIL=1 plant "$T/ceil_over" 300 "500000 100000" "$G4" 1 1000
arm "box-scheduler step 26: a controller-moved quota UNDER its declared ceiling (200% of 400%) reads GREEN" "$T/ceil_under" 0 "gaps=0" -- --budget-check
arm "box-scheduler step 26 FAIL-ONCE: the same knob ABOVE its ceiling (500% of 400%) reads RED naming the ceiling" "$T/ceil_over" 1 "seat a: cpu.max reads 500000 100000, above the declared CEILING CPUQuota=400%" -- --budget-check
arm "box-scheduler step 26: a quota the table declares exactly (no controller) still reads RED when it moves" "$T/quota" 1 "seat a: cpu.max reads max 100000, the table declares CPUQuota=400% (400000 100000)" -- --budget-check
arm "FAIL-ONCE: the grader slice at weight 100 reads RED naming it" "$T/grader" 1 "s4e-grader.slice: cpu.weight reads 100, the table declares CPUWeight=300 (300)" -- --budget-check
arm "FAIL-ONCE: a seat scope with no quota reads RED naming the seat" "$T/quota" 1 "seat a: cpu.max reads max 100000, the table declares CPUQuota=400% (400000 100000)" -- --budget-check
arm "FAIL-ONCE: a seat scope's memory.high at 3G reads RED naming both seats" "$T/high" 1 "seat b: memory.high reads $G3, the table declares MemoryHigh=4G ($G4)" -- --budget-check
arm "FAIL-ONCE: a declared slice with no cgroup reads RED as absent" "$T/nobatch" 1 "batch (s4e-batch.slice): absent" -- --budget-check
arm "FAIL-ONCE: Lon's scope at weight 100 reads RED naming Lon" "$T/lon" 1 "lon lon: cpu.weight reads 100, the table declares CPUWeight=1000" -- --budget-check
n=$((n + 1)); out="$(python3 -I "$CENSUS" --budget-check --budget "$T/none.tsv" --root "$T/good/root" --seats "$T/good/SEATS.tsv" 2>&1)"; rc=$?
[ "$rc" = 2 ] && printf '%s' "$out" | grep -F "REFUSED(2): no budget table" >/dev/null && say ok "no table REFUSES" || say red "no table REFUSES" "rc $rc: $out"
arm "--budget-props NAME prints the seat row's systemd properties" "$T/good" 0 "CPUWeight=100 CPUQuota=400% MemoryHigh=4G MemoryMax=8G MemorySwapMax=1G TasksMax=2048" -- --budget-props seat
arm "--budget-props alone prints one line per slice row" "$T/good" 0 "s4e-grader.slice CPUWeight=300 MemoryMax=10G" -- --budget-props
n=$((n + 1)); out="$(S4E_BUDGET="$T/good/ODD.tsv" bash "$HERE/s4e_session_start.sh" --props 2>&1)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -F "SEAT_PROPS=CPUWeight=100,CPUQuota=300%,MemoryHigh=4G" >/dev/null && printf '%s' "$out" | grep -F "LON_PROPS=CPUWeight=1000 TERM_WEIGHT=100" >/dev/null && say ok "s4e_session_start.sh applies the table's @SEAT row (a planted 300% quota)" || say red "s4e_session_start.sh does not read the table" "rc $rc: $out"
n=$((n + 1)); out="$(S4E_BUDGET="$T/none.tsv" bash "$HERE/s4e_session_start.sh" --props 2>&1)"; rc=$?
[ "$rc" = 2 ] && printf '%s' "$out" | grep -F "SEAT_PROPS=- LON_PROPS=- TERM_WEIGHT=-" >/dev/null && say ok "s4e_session_start.sh with no table holds no numbers of its own" || say red "s4e_session_start.sh with no table" "rc $rc: $out"
n=$((n + 1)); out="$(S4E_BUDGET="$T/good/ODD.tsv" bash "$HERE/util_fleet_settings.sh" 2>&1)"; rc=$?
[ "$rc" = 0 ] && printf '%s' "$out" | grep -F "systemctl --user set-property s4e-grader.slice CPUWeight=301 MemoryMax=10G" >/dev/null && say ok "util_fleet_settings.sh sets the table's slice rows (a planted 301 weight)" || say red "util_fleet_settings.sh does not read the table" "rc $rc: $(printf '%s' "$out" | grep -A3 'SLICES it' | tr '\n' '|')"
n=$((n + 1)); out="$(S4E_BUDGET="$T/none.tsv" bash "$HERE/util_fleet_settings.sh" 2>&1)"; rc=$?
[ "$rc" = 2 ] && printf '%s' "$out" | grep -F "REFUSE(2): no slice row in the budget table" >/dev/null && say ok "util_fleet_settings.sh with no table REFUSES before it changes anything" || say red "util_fleet_settings.sh with no table" "rc $rc: $(printf '%s' "$out" | head -2)"
echo "BUDGET_GATE_BOARD arms=$n fail=$fail (tree $(git -C "$HERE" rev-parse --short HEAD 2>/dev/null || echo -))"
[ "$fail" = 0 ] && { echo "GATE OK [$G]: one declared table, read against the planted cgroups by name, and the appliers carry its numbers"; exit 0; }
echo "GATE FAIL [$G]"; exit 1
