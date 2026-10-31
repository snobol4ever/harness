#!/usr/bin/env bash
# util_instr_count.sh -- A BENCHMARK IS AN INSTRUCTION COUNT, NEVER A WALL CLOCK (ceo CEO-1912; Lon 2026-10-22 15:0x CDT, in-chat to the ceo, verbatim:
# "Let HQ-JVM and HQ-DOTNET run their own tests. Forget about benchmarking based on wall clock; instead use instruction counts from calgrind and other
# techniques."). callgrind cannot follow a JIT runtime at a usable speed, so the counter here is the CPU's own: perf stat -e instructions:u, user-space
# instructions retired by the process and every thread it starts (the JIT compiler and the collector included), the SAME counter for every engine so a
# multiple compares like with like. A count does not move with the box's load, so it runs at any time, unlike a clock.
# THE TWO NUMBERS (RULES.md § THE TWO-NUMBER BENCHMARK BASIS, as counts): OVERHEAD is the engine's count on an empty program (END alone: start-up, the
# runtime's own load, shut-down); WORK is the program's count less OVERHEAD. Each is the median of N runs; the spread (max-min over median) is printed
# because a JIT's count moves run to run (measured 2026-10-22 on arith_loop: sbl +-1 instruction, snobol4dotnet 0.1 percent, snobol4jvm 1.4 percent).
# USE: bash harness/scripts/util_instr_count.sh [-n N] [--vs sbl [--allow-diff "why"]] <engine> <program.sno> [< input]
#        engine: sbl (the clean benchmark oracle, -bf), dotnet, jvm (their port runners), scrip (./scrip mode 3), scrip4 (./scrip --compile, linked, mode 4: the IR bar's basis; the compile is not counted)
#        --vs sbl: also count sbl on the same program and print WORK's multiple, sbl over the engine (lib_perf_fmt.sh perf_mult; 2.000x = half sbl's)
# SIZES AND THE ANSWER (ceo CEO-2050, hq_dotnet's find: 12 of 23 SnoDemo workhorses had been counted from an sbl that died of ERROR 246 at bare
# -bf with rc 0): sbl runs the program with its declared <stem>.oracle_args (declared_oracle_args_beside) and scrip with its declared -d/-s
# (declared_switches_beside), as the boards run them; under --vs sbl a count is REFUSED when the two engines' outputs differ, since a run
# that died is not a measurement; --allow-diff "why" admits a difference ruled by design (printed on the line as allow_diff=).
# PRINTS: INSTR engine=E prog=P runs=N total=<median> overhead=<median> work=<total-overhead> spread_total=<pct> spread_overhead=<pct> [x_vs_sbl=<mult>]
# EXIT: 0 counted; 2 could not count (no working perf, an engine that refuses, a program that fails, a count that is not a number).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
N=3; VS=""; ALLOW=""
while [ $# -gt 0 ]; do case "$1" in -n) N="$2"; shift 2;; --vs) VS="$2"; shift 2;; --allow-diff) ALLOW="$2"; shift 2;; -h|--help) sed -n '2,21p' "$0"; exit 0;; *) break;; esac; done
[ $# -ge 2 ] || { echo "REFUSE(2): usage: util_instr_count.sh [-n N] [--vs sbl] <engine> <program.sno>"; exit 2; }
ENG="$1"; PROG="$(cd "$(dirname "$2")" 2>/dev/null && pwd)/$(basename "$2")"
[ -f "$PROG" ] || { echo "REFUSE(2): no program $2"; exit 2; }
case "$N" in ''|*[!0-9]*|0) echo "REFUSE(2): -n takes a positive whole number"; exit 2;; esac
PERF=""
for p in perf /usr/lib/linux-tools-*/perf; do
    command -v "$p" >/dev/null 2>&1 || [ -x "$p" ] || continue
    "$p" stat -x, -e instructions:u -o /dev/null true >/dev/null 2>&1 && { PERF="$p"; break; }
done
[ -n "$PERF" ] || { echo "REFUSE(2): no perf that counts instructions:u on this kernel (perf_event_paranoid=$(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null))"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || { echo "REFUSE(2): lib_oracle_flags.sh unloadable"; exit 2; }
. "$HERE/lib_perf_fmt.sh" || { echo "REFUSE(2): lib_perf_fmt.sh unloadable"; exit 2; }
. "$HERE/lib_declared_arena.sh" || { echo "REFUSE(2): lib_declared_arena.sh unloadable"; exit 2; }
SBL_ARGS="$(declared_oracle_args_beside "$PROG")" || { echo "REFUSE(2): the oracle_args sidecar beside $PROG does not read"; exit 2; }
SCRIP_ARGS="$(declared_switches_beside "$PROG")" || { echo "REFUSE(2): the heap/stack sidecars beside $PROG do not read"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/instr_count.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
printf 'END\n' > "$W/empty.sno"
[ -t 0 ] && : > "$W/in" || cat > "$W/in"
engine_cmd() {
    case "$1" in
        sbl) echo "$(sbl_clean_bin) $(sbl_lang_flags snobol4) $([ "$2" = "$PROG" ] && echo "$SBL_ARGS")";;
        dotnet) echo "bash $HERE/run_snobol4dotnet.sh";;
        jvm) echo "bash $HERE/run_snobol4jvm.sh";;
        scrip) echo "$HERE/../../SCRIP/scrip $([ "$2" = "$PROG" ] && echo "$SCRIP_ARGS")";;
        scrip4) m4_binary "$2" || return 2; echo "$M4BIN $([ "$2" = "$PROG" ] && echo "$SCRIP_ARGS")";;
        *) return 2;;
    esac
}
m4_binary() {
    local key; key="$(printf '%s' "$1" | md5sum | cut -c1-12)"; M4BIN="$W/m4.$key"
    [ -x "$M4BIN" ] && return 0
    ( cd "$(dirname "$1")" && "$HERE/../../SCRIP/scrip" --compile --out="$W/m4.$key.s" "$1" < /dev/null 2> "$W/m4.err" && bash "$HERE/util_cc_slot.sh" gcc "$W/m4.$key.s" -L"$HERE/../../SCRIP/out" -lscrip_rt -lm -Wl,-rpath,"$HERE/../../SCRIP/out" -o "$M4BIN" 2>> "$W/m4.err" ) || { echo "REFUSE(2): scrip4 did not build $1 in mode 4: $(head -c 200 "$W/m4.err")" >&2; return 2; }
}
count_once() {
    local cmd parg="$2"; cmd="$(engine_cmd "$1" "$2")" || { echo "REFUSE(2): unknown engine $1 (sbl dotnet jvm scrip scrip4)" >&2; return 2; }
    [ "$1" = scrip4 ] && parg=""
    ( cd "$(dirname "$2")" && timeout -k 5 600 "$PERF" stat -x, -e instructions:u -o "$W/stat" $cmd $parg < "$W/in" > "$W/out" 2> "$W/err" ) || { echo "REFUSE(2): $1 failed on $2 (rc $?): $(head -c 200 "$W/err")" >&2; return 2; }
    local c; c="$(awk -F, '$3 ~ /^instructions/ {print $1; exit}' "$W/stat")"
    case "$c" in ''|*[!0-9]*) echo "REFUSE(2): no instruction count for $1 on $2" >&2; return 2;; esac
    echo "$c"
}
median_spread() { sort -n | awk '{v[NR]=$1} END{ m = (NR%2) ? v[(NR+1)/2] : int((v[NR/2]+v[NR/2+1])/2); printf "%d %.2f\n", m, (m>0 ? 100*(v[NR]-v[1])/m : 0) }'; }
measure() {
    local e="$1" i c
    : > "$W/t.$e"; : > "$W/o.$e"
    for i in $(seq 1 "$N"); do
        c="$(count_once "$e" "$PROG")" || exit 2; echo "$c" >> "$W/t.$e"; cp "$W/out" "$W/answer.$e"
        c="$(count_once "$e" "$W/empty.sno")" || exit 2; echo "$c" >> "$W/o.$e"
    done
    read -r TOT SPT < <(median_spread < "$W/t.$e"); read -r OVH SPO < <(median_spread < "$W/o.$e")
    WORK=$(( TOT - OVH ))
}
measure "$ENG"; T1=$TOT; O1=$OVH; W1=$WORK; S1=$SPT; SO1=$SPO
line="INSTR engine=$ENG prog=$(basename "$PROG") runs=$N total=$T1 overhead=$O1 work=$W1 spread_total=${S1}% spread_overhead=${SO1}%"
if [ "$VS" = sbl ]; then
    measure sbl
    [ "$W1" -gt 0 ] && [ "$WORK" -gt 0 ] || { echo "$line"; echo "REFUSE(2): a WORK count is not positive (engine $W1, sbl $WORK): the program's work is under the run-to-run spread; use a longer kernel"; exit 2; }
    if ! cmp -s "$W/answer.$ENG" "$W/answer.sbl"; then
        d="$(diff "$W/answer.$ENG" "$W/answer.sbl" | head -3 | tr '\n' ' ' | cut -c1-200)"
        if [ -z "$ALLOW" ]; then echo "$line"; echo "REFUSE(2): $ENG and sbl print different answers, so one of the counts is not a measurement (a run that died counts too; sbl args: ${SBL_ARGS:-none}): $d"; exit 2; fi
        line="$line allow_diff=\"$ALLOW\""
    fi
    line="$line sbl_work=$WORK x_vs_sbl=$(PERF_COLOR=0 perf_mult "$WORK" "$W1" "$ENG vs sbl" 2>/dev/null | head -1 | awk '{print $1}')"
fi
echo "$line"
