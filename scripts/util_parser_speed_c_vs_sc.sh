#!/usr/bin/env bash
# util_parser_speed_c_vs_sc.sh [sample|corpus] [lang ...] -- PARSE SPEED, THE C PARSERS AGAINST THE SELF-HOSTED .sc PARSERS, EACH
# FILE ALONE (Lon 2026-09-27: "Compare the speed of PARSING the entire set of programs for each language in the corpus repo ... with
# Snocone running parser.sc program in SCRIP versus stand-alone SCRIP parser ... I want to claim that the Snocone parsers are
# FASTER than the C and Bison/flex parsers."; 2026-09-28: "So change from concat one big file to run each parser seperatly.").
# A MEASUREMENT, not the claim: published only on the ceo's word (CEO-1340), RT_OPT named.
# Two columns per language (Lon 2026-09-28: "forget mode 3 runs."), the SUM of wall clock over every file of the population, each
# file run alone on its own stdin: C = out/parser_<lang>; sc-m4 = the .sc chain compiled ONCE to a native binary (scrip --compile +
# gcc against out/libscrip_rt.so), each file's run timed.
# Beside each time the count of files that printed a tree (P) and that refused (R) or timed out (T), so a fast refusal cannot read
# as a win. The population is the tree gate's: corpus/benchmarks/<lang> (sample) or every corpus program of the language (corpus).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
SCRIP="$ROOT/scrip"; CORPUS="${CORPUS:-$S4E/corpus}"; LIBDIR="$ROOT/out"
POP="${1:-sample}"; shift || true; LANGS="${*:-snobol4 snocone icon prolog rebus pascal raku}"
B="$ROOT/bootstrap"; CHAIN="$B/global.sc $B/case.sc $B/assign.sc $B/match.sc $B/counter.sc $B/stack.sc $B/tree.sc $B/ShiftReduce.sc $B/tdump.sc $B/gen.sc $B/qize.sc $B/semantic.sc $B/omega.sc $B/trace.sc"
declare -A EXT=([snobol4]=sno [snocone]=sc [icon]=icn [prolog]=pl [rebus]=reb [raku]=raku [pascal]=pas)
TMO="${SPEED_TIMEOUT:-300}"
# The sc-m4 binary runs at the CHAIN's declared heap and stack (ceo CEO-1353, RULES.md clause 8 (g)(4)), never typed here:
# bootstrap/parser_<lang>.heap and .stack, read by lib_declared_arena.sh, leading the binary's own command line.
. "$HERE/lib_declared_arena.sh" || { echo "REFUSE(2): cannot load lib_declared_arena.sh"; exit 2; }
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
now() { date +%s.%N; }
add() { awk -v a="$1" -v b="$2" -v c="$3" 'BEGIN { printf "%.3f", a + (c - b) }'; }
tally() { if [ "$1" -eq 124 ]; then echo T; elif grep -q '^Parse Error' "$2" || [ "$1" -ge 2 ]; then echo R; elif grep -q -m1 '^(\|^Parsed' "$2"; then echo P; else echo R; fi; }
echo "PARSER SPEED C vs .sc, EACH FILE ALONE -- population=$POP, RT_OPT=$(grep -m1 '^RT_OPT' "$ROOT/Makefile" | sed 's/#.*//' | cut -d= -f2- | xargs), tree $(git -C "$ROOT" rev-parse --short HEAD), load $(cut -d' ' -f1-3 /proc/loadavg)"
printf '%-8s %6s %10s | %10s %-12s | %10s %-12s | %8s\n' lang files bytes "C s" "C P/R/T" "sc-m4 s" "m4 P/R/T" "m4/C"
for L in $LANGS; do
    ext=${EXT[$L]}; exe="$ROOT/out/parser_$L"; ( . "$HERE/lib_build_currency.sh" && assert_parser_current "$L" "$ROOT" ) || { echo "$L: $exe is missing or older than a source it was compiled from (named above) -- make parsers"; continue; }
    if [ "$POP" = corpus ]; then find "$CORPUS" -type f -name "*.$ext" -not -name 'ALL.*' -not -path '*/.git/*' -not -path "$CORPUS/library/*" | sort > "$T/$L.files"
    else ls "$CORPUS/benchmarks/$L"/*."$ext" 2>/dev/null | sort > "$T/$L.files"; fi
    nf=$(wc -l < "$T/$L.files"); nb=$(xargs -d '\n' cat < "$T/$L.files" | wc -c)
    cat $CHAIN "$B/parser_$L.sc" > "$T/$L.chain.sc"
    SW="$(declared_switches_beside "$B/parser_$L.sc")" && [ -n "$SW" ] || { echo "$L: bootstrap/parser_$L.sc declares no heap or stack (parser_$L.heap, .stack), or the declaration is refused"; continue; }
    m4=0; "$SCRIP" --compile "$T/$L.chain.sc" -o "$T/$L.s" </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie -rdynamic "$T/$L.s" -Wl,-rpath,"$LIBDIR" -L"$LIBDIR" -lscrip_rt -lm -lpthread -o "$T/$L.bin" 2>/dev/null && m4=1
    tc=0; t4=0; declare -A K=([cP]=0 [cR]=0 [cT]=0 [4P]=0 [4R]=0 [4T]=0)
    while IFS= read -r f; do
        a=$(now); ( cd "$(dirname "$f")"; SNO_LIB="$CORPUS/include" timeout -k 5 "$TMO" "$exe" - < "$f" > "$T/o" 2>/dev/null ); r=$?; tc=$(add "$tc" "$a" "$(now)"); k=$(tally $r "$T/o"); K[c$k]=$((K[c$k] + 1))
        if [ $m4 = 1 ]; then a=$(now); timeout -k 5 "$TMO" "$T/$L.bin" $SW < "$f" > "$T/o" 2>/dev/null; r=$?; t4=$(add "$t4" "$a" "$(now)"); k=$(tally $r "$T/o"); K[4$k]=$((K[4$k] + 1)); fi
    done < "$T/$L.files"
    [ $m4 = 1 ] || t4="no-m4"
    note=
    ratio=$(awk -v a="$t4" -v b="$tc" 'BEGIN { if (b > 0 && a + 0 == a) printf "%.1fx", a / b; else print "-" }')
    printf '%-8s %6d %10d | %10s %-12s | %10s %-12s | %8s%s\n' "$L" "$nf" "$nb" "$tc" "${K[cP]}/${K[cR]}/${K[cT]}" "$t4" "${K[4P]}/${K[4R]}/${K[4T]}" "$ratio" "$note"
    unset K
done
