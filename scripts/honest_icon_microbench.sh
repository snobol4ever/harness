#!/usr/bin/env bash
# honest_icon_microbench.sh — correctness-GATED Icon micro-benchmark timing.
# LAW (GOAL-ICON-100 DoD 3 / s164 rsg lesson): a timing number is only reported
# when SCRIP output is BYTE-IDENTICAL to the live Arizona iconx oracle for that
# program. Divergent or crashing programs report DIVERGE and are NOT timed.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255), Icon-aware since row icon-oracle-accessors-shared." >&2; exit 3; }
SCRIPDIR="${SCRIPDIR:-$S4E/SCRIP}"
SCRIP="$SCRIPDIR/scrip"
ICONT="${ICONT:-$(icont_bin)}" || exit 2
ICONX="${ICONX:-$(iconx_bin)}" || exit 2
CORPUS_SRC="${CORPUS_SRC:-$S4E/corpus/benchmarks/icon}"
REPS="${REPS:-3}"
WORK="$(mktemp -d /tmp/icn_micro_XXXXXX)"
export PATH="$(dirname "$ICONT"):$PATH"

# best-of-N wall clock in milliseconds
timeit() {
    local best=999999 t0 t1 ms i
    for ((i=0;i<REPS;i++)); do
        t0=$(date +%s%N)
        "$@" > /dev/null 2>&1 < /dev/null
        t1=$(date +%s%N)
        ms=$(( (t1-t0)/1000000 ))
        (( ms < best )) && best=$ms
    done
    echo "$best"
}

printf "%-38s | %-9s | %-9s | %-9s | %s\n" "BENCHMARK" "iconx" "SCRIP m4" "SPEEDUP" "VERDICT"
printf -- "---------------------------------------+-----------+-----------+-----------+---------\n"

PASSED=0; TOTAL=0
for src in "$CORPUS_SRC"/bench_icn*.icn; do
    name="$(basename "$src" .icn)"
    TOTAL=$((TOTAL+1))
    cp "$src" "$WORK/"

    # --- oracle: compile + run ---
    ( cd "$WORK" && "$ICONT" -s -o "$name.icx" "$name.icn" ) > /dev/null 2>&1
    if [ ! -f "$WORK/$name.icx" ]; then
        printf "%-38s | %-9s | %-9s | %-9s | %s\n" "$name" "-" "-" "-" "ORACLE-CFAIL"
        continue
    fi
    "$ICONX" "$WORK/$name.icx" > "$WORK/$name.ora" 2>/dev/null < /dev/null

    # --- SCRIP mode 4: --compile emits x86 TEXT asm on stdout, then gcc -no-pie + libscrip_rt ---
    ( cd "$WORK" && timeout -k 5 120 "$SCRIP" --compile --target=x86 "$name.icn" \
        > "$WORK/$name.s" 2> "$WORK/$name.cerr" < /dev/null )
    BIN="$WORK/$name.bin"
    if [ ! -s "$WORK/$name.s" ] || ! gcc -no-pie "$WORK/$name.s" -L"$SCRIPDIR/out" -lscrip_rt \
            -Wl,-rpath,"$SCRIPDIR/out" -o "$BIN" 2> "$WORK/$name.lerr"; then
        why=$(grep -m1 -oE 'FATAL[^\n]{0,30}' "$WORK/$name.cerr" | head -c30)
        printf "%-38s | %-9s | %-9s | %-9s | %s\n" "$name" "-" "-" "-" "EMITFAIL ${why}"
        continue
    fi
    LD_LIBRARY_PATH="$SCRIPDIR/out" timeout -k 5 120 "$BIN" > "$WORK/$name.scr" 2>/dev/null < /dev/null
    rc=$?

    # --- correctness gate ---
    if [ $rc -ne 0 ]; then
        printf "%-38s | %-9s | %-9s | %-9s | %s\n" "$name" "-" "-" "-" "SCRIP-rc=$rc"
        continue
    fi
    if ! cmp -s "$WORK/$name.ora" "$WORK/$name.scr"; then
        ol=$(wc -l < "$WORK/$name.ora"); sl=$(wc -l < "$WORK/$name.scr")
        printf "%-38s | %-9s | %-9s | %-9s | %s\n" "$name" "-" "-" "-" "DIVERGE(${ol}L vs ${sl}L)"
        continue
    fi

    # --- byte-identical: timing is now honest ---
    ot=$(timeit "$ICONX" "$WORK/$name.icx")
    st=$(LD_LIBRARY_PATH="$SCRIPDIR/out"; export LD_LIBRARY_PATH; timeit "$BIN")
    if [ "$st" -eq 0 ]; then st=1; fi
    sp=$(awk -v o="$ot" -v s="$st" 'BEGIN{printf "%.2fx", o/s}')
    printf "%-38s | %-9s | %-9s | %-9s | %s\n" "$name" "${ot}ms" "${st}ms" "$sp" "IDENTICAL"
    PASSED=$((PASSED+1))
done
printf -- "---------------------------------------+-----------+-----------+-----------+---------\n"
echo "correctness-gated: $PASSED/$TOTAL byte-identical (only these are timed)"
echo "workdir: $WORK"
