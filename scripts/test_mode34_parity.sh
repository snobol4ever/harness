#!/usr/bin/env bash
# ../harness/scripts/test_mode34_parity.sh — GOAL-MODE34-IDENTICAL M34-0a
# For every *.sno in a corpus dir, run mode-3 (--run) AND mode-4 (--compile->as->gcc->run),
# capture both stdouts, compare to each other and to .ref. Classify divergence.
# Usage: test_mode34_parity.sh [CORPUS_DIR] [--tsv FILE]
# Default CORPUS_DIR = /home/claude/corpus/crosscheck
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="${RT_DIR:-$HERE/../../SCRIP/out}"
CORPUS_ROOT="${CORPUS:-$S4E/corpus}"
INC="$CORPUS_ROOT/include"
TIMEOUT="${TIMEOUT:-10}"
DIR="${1:-$CORPUS_ROOT/crosscheck}"
TSV=""
[ "$2" = "--tsv" ] && TSV="$3"

if [ ! -x "$SCRIP" ]; then echo "SKIP scrip not built"; exit 0; fi
WORKDIR=$(mktemp -d); trap 'rm -rf "$WORKDIR"' EXIT

run_m3() {  # sno -> stdout on fd1 ; returns 0 if produced output
    local sno="$1"
    SNO_LIB="$INC" timeout -k 5 "$TIMEOUT" "$SCRIP" --run "$sno" < /dev/null 2>/dev/null
}
run_m4() {  # sno -> stdout on fd1 ; returns 1 if compile/link fails
    local sno="$1" tmp; tmp="$(mktemp -d)"
    SNO_LIB="$INC" "$SCRIP" --compile "$sno" > "$tmp/p.s" 2>/dev/null || { rm -rf "$tmp"; return 1; }
    (cd "$HERE/../../SCRIP" && gcc -c "$tmp/p.s" -o "$tmp/p.o" 2>/dev/null) || { rm -rf "$tmp"; return 1; }
    gcc -no-pie "$tmp/p.o" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$tmp/p.bin" 2>/dev/null || { rm -rf "$tmp"; return 1; }
    SNO_LIB="$INC" timeout -k 5 "$TIMEOUT" "$tmp/p.bin" < /dev/null 2>/dev/null; local rc=$?
    rm -rf "$tmp"; return 0
}

IDENT=0; DIFFER=0; M3MISS=0; M4MISS=0; BOTHFAIL=0; TOTAL=0
[ -n "$TSV" ] && echo -e "program\tclass\tm3_vs_m4\tm3_vs_ref\tm4_vs_ref" > "$TSV"
echo "=== mode-3 (--run) vs mode-4 (--compile) PARITY — $DIR ==="
while IFS= read -r sno; do
    [ -z "$sno" ] && continue
    slug=$(basename "${sno%.sno}"); ref="${sno%.sno}.ref"
    TOTAL=$((TOTAL+1))
    m3=$(run_m3 "$sno"); m3_has=$?
    m4=$(run_m4 "$sno"); m4_ok=$?
    # presence: mode-3 "miss" = empty output (soft-fall); mode-4 "miss" = compile/link fail
    m3_empty=0; [ -z "$m3" ] && m3_empty=1
    rclass="NOREF"; m3r="-"; m4r="-"; m34="-"
    if [ "$m4_ok" -ne 0 ] && [ "$m3_empty" -eq 1 ]; then rclass="BOTH-FAIL"; BOTHFAIL=$((BOTHFAIL+1));
    elif [ "$m4_ok" -ne 0 ]; then rclass="M4-MISS"; M4MISS=$((M4MISS+1));
    elif [ "$m3_empty" -eq 1 ]; then rclass="M3-MISS"; M3MISS=$((M3MISS+1));
    else
        if [ "$m3" = "$m4" ]; then m34="="; else m34="DIFF"; fi
        if [ -f "$ref" ]; then exp=$(cat "$ref"); [ "$m3" = "$exp" ] && m3r="=" || m3r="DIFF"; [ "$m4" = "$exp" ] && m4r="=" || m4r="DIFF"; fi
        if [ "$m34" = "=" ]; then rclass="IDENTICAL"; IDENT=$((IDENT+1)); else rclass="DIFFER"; DIFFER=$((DIFFER+1)); fi
    fi
    [ -n "$TSV" ] && echo -e "${slug}\t${rclass}\t${m34}\t${m3r}\t${m4r}" >> "$TSV"
    case "$rclass" in DIFFER|M3-MISS) echo "  $rclass  $slug (m3vm4=$m34 m3vref=$m3r m4vref=$m4r)";; esac
done < <(find "$DIR" -name "*.sno" 2>/dev/null | sort)

echo "---"
printf "TOTAL=%d  IDENTICAL=%d  DIFFER=%d  M3-MISS=%d  M4-MISS=%d  BOTH-FAIL=%d\n" \
    "$TOTAL" "$IDENT" "$DIFFER" "$M3MISS" "$M4MISS" "$BOTHFAIL"
[ -n "$TSV" ] && echo "TSV: $TSV"
# parity gate: any DIFFER is a hard failure (M3-MISS tracked separately as coverage)
[ "$DIFFER" -eq 0 ] && exit 0 || exit 1
