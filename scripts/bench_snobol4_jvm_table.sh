#!/usr/bin/env bash
# bench_snobol4_jvm_table.sh -- snobol4jvm against pristine SPITBOL and CSNOBOL4, one INSTRUCTION-COUNT table over the SnoBench kernels (hq_jvm, row
# jvm-bench-every-snobench-kernel-is-counted-in-instructions-for-the-jar-spitbol-and-csnobol4-in-one-table; Lon 2026-10-31 17:4x CDT, R-2091 relayed by the
# cto, verbatim: "Keep the HQ-JVM and HQ-DOTNET doing their benchmarks and speed improvements.").
# THE BASIS is R-2035's: perf stat -e instructions:u, user-space instructions retired by the process and every thread it starts (the JIT and the collector
# included). OVERHEAD is an empty program (END alone); WORK is the kernel's total less OVERHEAD; each is the median of N runs. The jar and SPITBOL are counted by
# util_instr_count.sh (their declared sizes, the output-equality refusal); CSNOBOL4 (/home/resources/csnobol4/snobol4) is counted here by the same perf and its
# output must equal the kernel's .ref, else the cell is REFUSED, never counted. A multiple is the jar's WORK over the other engine's WORK (the larger the slower).
# USE:  bash harness/scripts/bench_snobol4_jvm_table.sh [-n N] [--out FILE] [kernel-stem ...]   measure (all kernels of corpus/benchmarks/snobol4 by default),
#                                                                                              print the table, write it to FILE when --out is given
#       bash harness/scripts/bench_snobol4_jvm_table.sh --check [FILE]                         grade a written table (default .github/findings/JVM-BENCH-TABLE.md):
#                                                                                              rc 0 every kernel now in corpus/benchmarks/snobol4 has a row with
#                                                                                              three numeric works; rc 1 a kernel is missing or a cell is not a number;
#                                                                                              rc 2 the corpus or the table cannot be read
# EXIT (measure): 0 the table printed with every cell counted; 1 printed with at least one REFUSED cell; 2 could not measure at all.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
KDIR="$ROOT/corpus/benchmarks/snobol4"
PAGE_DEFAULT="$ROOT/.github/findings/JVM-BENCH-TABLE.md"
CSN=/home/resources/csnobol4/snobol4
N=3; OUT=""; CHECK=0; PAGE=""; STEMS=(); NOTE_ONLY=0
while [ $# -gt 0 ]; do
    case "$1" in
        -n) N="$2"; shift 2;;
        --out) OUT="$2"; shift 2;;
        --check) CHECK=1; shift; if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then PAGE="$1"; shift; fi;;
        --note) NOTE_ONLY=1; shift;;
        -h|--help) sed -n '2,19p' "$0"; exit 0;;
        -*) echo "REFUSE(2): unknown option $1"; exit 2;;
        *) STEMS+=("$1"); shift;;
    esac
done
[ -d "$KDIR" ] || { echo "REFUSE(2): no kernel directory $KDIR"; exit 2; }
if [ "$CHECK" = 1 ]; then
    PAGE="${PAGE:-$PAGE_DEFAULT}"
    [ -r "$PAGE" ] || { echo "RED: no table at $PAGE yet"; exit 1; }
    ls "$KDIR"/*.sno >/dev/null 2>&1 || { echo "REFUSE(2): no kernels under $KDIR"; exit 2; }
    bad=0; n=0
    for f in "$KDIR"/*.sno; do
        s="$(basename "$f" .sno)"; n=$((n + 1))
        row="$(grep -E "^\| $s \|" "$PAGE" | head -1)"
        [ -n "$row" ] || { echo "RED: kernel $s has no row in $PAGE"; bad=$((bad + 1)); continue; }
        echo "$row" | awk -F'|' '{ ok = 1; for (i = 3; i <= 5; i++) { v = $i; gsub(/ /, "", v); if (v !~ /^[0-9]+(\.[0-9]+)?$/) ok = 0 } exit !ok }' \
            || { echo "RED: kernel $s has a REFUSED or non-numeric work cell: $row"; bad=$((bad + 1)); }
    done
    echo "BENCH_TABLE kernels=$n red=$bad page=$PAGE"
    [ "$bad" -eq 0 ]; exit
fi
exec < /dev/null
reading_note() {
cat <<'NOTE'
## How to read it

- **A multiple here is the cost of running one small program once.** Each SnoBench kernel is millisecond-sized, so the jar's WORK is mostly one-time cost (parsing the source with instaparse, compiling, class loading, the first run, the JIT), not loop iterations; a board entry pays exactly this. The kernels that iterate longest read lowest (arith_loop_twin, fib_recur, name_indirection, table_access).
- **OVERHEAD is a separate number.** An empty program costs the jar about 6.2 to 6.8 G instructions on every run (16.5 to 17 G before 2026-10-31's compiled grammar, the launcher's -XX:CompileThresholdScaling=4 and -XX:-DontCompileHugeMethods; a bare JVM is 0.06 G, a bare Clojure runtime 4.2 G, SPITBOL and CSNOBOL4 under 1 M). Every board entry pays it.
- **Steady-state speed is not in this table.** Scaled loops, instruction counts on 2026-10-31 (jar 4cd6529 through the launcher; sbl, csnobol4): 1.5M arithmetic iterations 117.5 G against 0.67 G and 2.73 G (176 and 43 times); 300k pattern matches 116.8 G against 1.72 G and 2.29 G (68 and 51 times); 40k string concatenations 15.9 G against 0.07 G and 0.63 G; a 40k-entry table 19.4 G against 0.04 G and 20.1 G (parity with csnobol4); fib(24), 75k calls, 24.7 G against 0.05 G and 0.21 G (525 and 118 times; 281 G before RETURN stopped reading a stack trace). Not a board.
- **Noise.** The jar's total moves 0.2 to 13 percent run to run (the note column); two multiples within 15 percent of each other are not different. SPITBOL's count is stable to a few instructions; CSNOBOL4 is about five times SPITBOL's work in total.
- **Correctness first.** A kernel whose output differs from the oracle's is REFUSED, never counted; CSNOBOL4's output must equal the kernel's .ref.
NOTE
}
[ "$NOTE_ONLY" = 1 ] && { reading_note; exit 0; }
PERF=""
for p in perf /usr/lib/linux-tools-*/perf; do
    command -v "$p" >/dev/null 2>&1 || [ -x "$p" ] || continue
    "$p" stat -x, -e instructions:u -o /dev/null true >/dev/null 2>&1 && { PERF="$p"; break; }
done
[ -n "$PERF" ] || { echo "REFUSE(2): no perf that counts instructions:u on this kernel"; exit 2; }
[ -x "$CSN" ] || { echo "REFUSE(2): no CSNOBOL4 at $CSN"; exit 2; }
[ -x "$HERE/util_instr_count.sh" ] || { echo "REFUSE(2): no util_instr_count.sh beside this script"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/bench_jvm_table.XXXXXX")" || { echo "REFUSE(2): mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
printf 'END\n' > "$W/empty.sno"
if [ ${#STEMS[@]} -eq 0 ]; then
    for f in "$KDIR"/*.sno; do STEMS+=("$(basename "$f" .sno)"); done
fi
csn_count() {
    local prog="$1" want="$2" i c
    ( cd "$(dirname "$prog")" && timeout -k 5 600 "$PERF" stat -x, -e instructions:u -o "$W/csn.stat" "$CSN" "$prog" < /dev/null > "$W/csn.out" 2> "$W/csn.err" ) || return 2
    [ -z "$want" ] || cmp -s "$W/csn.out" "$want" || return 3
    c="$(awk -F, '$3 ~ /^instructions/ {print $1; exit}' "$W/csn.stat")"
    case "$c" in ''|*[!0-9]*) return 2;; esac
    echo "$c"
}
median() { sort -n | awk '{v[NR]=$1} END{ print (NR%2) ? v[(NR+1)/2] : int((v[NR/2]+v[NR/2+1])/2) }'; }
csn_median() {
    local prog="$1" want="$2" i c vals=""
    for i in $(seq 1 "$N"); do c="$(csn_count "$prog" "$want")" || return $?; vals="$vals$c"$'\n'; done
    printf '%s' "$vals" | median
}
G() { awk -v v="$1" 'BEGIN { printf "%.3f", v / 1e9 }'; }
M() { awk -v v="$1" 'BEGIN { printf "%.3f", v / 1e6 }'; }
X() { awk -v a="$1" -v b="$2" 'BEGIN { if (b > 0) printf "%.1f", a / b; else printf "n/a" }'; }
refused=0; ndone=0; sumj=0; sums=0; sumc=0
rows="$W/rows"; : > "$rows"
CSN_OV="$(csn_median "$W/empty.sno" "")" || CSN_OV=""
for s in "${STEMS[@]}"; do
    prog="$KDIR/$s.sno"; ref="$KDIR/$s.ref"
    [ -f "$prog" ] || { echo "REFUSE(2): no kernel $prog"; exit 2; }
    line="$(bash "$HERE/util_instr_count.sh" -n "$N" --vs sbl jvm "$prog" 2>&1 | grep -E '^(INSTR|REFUSE)' | tail -1)"
    case "$line" in
        INSTR*) jw="$(echo "$line" | sed -n 's/.* work=\([0-9]*\) .*/\1/p')"; jo="$(echo "$line" | sed -n 's/.* overhead=\([0-9]*\) .*/\1/p')"
                sw="$(echo "$line" | sed -n 's/.* sbl_work=\([0-9]*\).*/\1/p')"; sp="$(echo "$line" | sed -n 's/.* spread_total=\([0-9.]*\)%.*/\1/p')";;
        *) printf '| %s | REFUSED | REFUSED | REFUSED | | | | %s |\n' "$s" "$(echo "$line" | cut -c1-120 | tr '|' '/')" >> "$rows"; refused=$((refused + 1)); continue;;
    esac
    ct="$(csn_median "$prog" "$ref")"; crc=$?
    if [ "$crc" -ne 0 ] || [ -z "$CSN_OV" ]; then
        printf '| %s | %s | %s | REFUSED | %s | | | %s |\n' "$s" "$(G "$jw")" "$(M "$sw")" "$(X "$jw" "$sw")" "csnobol4 output differs from the ref or did not count (rc $crc)" >> "$rows"
        refused=$((refused + 1)); continue
    fi
    cw=$(( ct - CSN_OV )); [ "$cw" -gt 0 ] || { printf '| %s | %s | %s | REFUSED | | | | csnobol4 work not positive |\n' "$s" "$(G "$jw")" "$(M "$sw")" >> "$rows"; refused=$((refused + 1)); continue; }
    printf '| %s | %s | %s | %s | %s | %s | %s | jar spread %s%% |\n' "$s" "$(G "$jw")" "$(M "$sw")" "$(M "$cw")" "$(X "$jw" "$sw")" "$(X "$jw" "$cw")" "$(G "$jo")" "$sp" >> "$rows"
    ndone=$((ndone + 1)); sumj=$((sumj + jw)); sums=$((sums + sw)); sumc=$((sumc + cw))
done
{
    echo "# JVM-BENCH-TABLE -- snobol4jvm against pristine SPITBOL and CSNOBOL4, in instructions"
    echo
    echo "Measured $(date '+%F %H:%M %Z') by bench_snobol4_jvm_table.sh -n $N; snobol4jvm $(git -C "$ROOT/snobol4jvm" rev-parse --short HEAD 2>/dev/null), load $(cut -d' ' -f1-3 /proc/loadavg); corpus $(git -C "$ROOT/corpus" rev-parse --short HEAD 2>/dev/null)."
    echo "Basis: perf stat -e instructions:u (R-2035), median of $N runs; WORK is the kernel's total less an empty program's. SPITBOL is /home/resources/spitbol-bench-oracle/sbl, CSNOBOL4 is /home/resources/csnobol4/snobol4 (output must equal the kernel's .ref)."
    echo
    echo "| kernel | jar work (G) | sbl work (M) | csnobol4 work (M) | jar / sbl | jar / csnobol4 | jar overhead (G) | note |"
    echo "|---|---|---|---|---|---|---|---|"
    cat "$rows"
    echo "| TOTAL (counted kernels) | $(G "$sumj") | $(M "$sums") | $(M "$sumc") | $(X "$sumj" "$sums") | $(X "$sumj" "$sumc") | | $ndone kernels counted, $refused refused |"
    echo
    echo "Empty-program overhead: jar see the column; csnobol4 $( [ -n "$CSN_OV" ] && M "$CSN_OV" || echo n/a ) M."
    echo
    reading_note
} > "$W/table.md"
cat "$W/table.md"
[ -z "$OUT" ] || { mkdir -p "$(dirname "$OUT")" && cp "$W/table.md" "$OUT"; }
[ "$refused" -eq 0 ]
