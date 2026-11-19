#!/usr/bin/env bash
# bench_snobol4dotnet_bar.sh -- the witness of a snobol4dotnet speed row: a program's instruction count on the shipped build must be at or under the row's bar. The count
# is util_instr_count.sh's, beside this script, (perf stat instructions:u, the median of 3; WORK is the program's count less OVERHEAD, the count of
# END alone), so it holds at any load, unlike a clock.
#
#   bench_snobol4dotnet_bar.sh work <bar> <program.sno> [stdin [N]]   WORK at or under <bar> instructions (stdin read N times over, as a workhorse scales)
#   bench_snobol4dotnet_bar.sh overhead <bar>                         OVERHEAD (END alone) at or under <bar> instructions
#
# The build measured is the one Snobol4.csproj ships: Release with its ReadyToRun pass (an iterating build made with -p:ReadyToRunBuild=false
# JIT-compiles the engine at every start and counts about twice the OVERHEAD), built here first and refused when the ReadyToRun copies are
# not the ones in bin. Prints PASS or RED with the count and the bar. The port is the clone S4E_DOTNET_ROOT names (default
# /home/claude_dotnet, the dotnet seat's root), as run_snobol4dotnet.sh reads it. (Moved here from snobol4dotnet's scripts/instr_bar.sh,
# 2026-11-19, on Lon's word: the port's scripts live in harness.)
# Exit: 0 at or under the bar, 1 over it, 2 could not measure (no clone, no build, no perf, a program that fails).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENGINE="${S4E_DOTNET_ROOT:-/home/claude_dotnet}"
COUNT="$HERE/util_instr_count.sh"
OUT="$ENGINE/Snobol4/bin/Release/net10.0"
R2R="$ENGINE/Snobol4/obj/readytorun"
field="${1:-}"; bar="${2:-}"
case "$field" in work) [ "$#" -ge 3 ] || field="";; overhead) ;; *) field="";; esac
case "$bar" in ''|*[!0-9]*) field="";; esac
[ -n "$field" ] || { echo "usage: $0 work <bar> <program.sno> [stdin [N]] | $0 overhead <bar>"; exit 2; }
[ -f "$COUNT" ] || { echo "REFUSE(2): no util_instr_count.sh beside $0"; exit 2; }
[ -f "$ENGINE/Snobol4/Snobol4.csproj" ] || { echo "REFUSE(2): no snobol4dotnet clone at $ENGINE (S4E_DOTNET_ROOT)"; exit 2; }
t="$(mktemp -d)"; trap 'rm -rf "${t:?}"' EXIT
if [ "$field" = work ]; then
    prog="$3"; in="${4:-/dev/null}"; scale="${5:-1}"
    case "$scale" in ''|*[!0-9]*|0) echo "REFUSE(2): the scale is a positive whole number"; exit 2;; esac
else
    prog="$t/empty.sno"; in=/dev/null; printf 'END\n' > "$prog"
fi
[ -f "$prog" ] && [ -r "$in" ] || { echo "REFUSE(2): no program $prog or no input $in"; exit 2; }
if [ "${scale:-1}" -gt 1 ]; then
    for _ in $(seq 1 "$scale"); do cat "$in"; done > "$t/in"; in="$t/in"
fi
dotnet build "$ENGINE/Snobol4/Snobol4.csproj" -c Release -m:2 -nodeReuse:false -v:q > /dev/null 2>&1 || { echo "REFUSE(2): Snobol4 does not build"; exit 2; }
cmp -s "$OUT/Snobol4.Common.dll" "$R2R/Snobol4.Common.dll" && cmp -s "$OUT/Snobol4.dll" "$R2R/Snobol4.dll" \
    || { echo "REFUSE(2): the Release build in $OUT is not its ReadyToRun copy"; exit 2; }
line="$(bash "$COUNT" -n 3 dotnet "$prog" < "$in" 2>&1 | tail -n 1)"
n="$(printf '%s\n' "$line" | sed -n "s/.* $field=\([0-9][0-9]*\).*/\1/p")"
[ -n "$n" ] || { echo "REFUSE(2): no count: $line"; exit 2; }
if [ "$n" -le "$bar" ]; then echo "PASS $field=$n bar=$bar $(basename "$prog")"; exit 0; fi
echo "RED $field=$n bar=$bar $(basename "$prog")"
exit 1
