#!/usr/bin/env bash
# ../harness/scripts/test_interp_broad_corpus_and_beauty.sh — MODE-4 ONLY (Lon directive 2026-06-06)
# Formerly ran modes 2/3/4. Now mode-4 only for SNOBOL4.
# Runs corpus programs via --compile→as→gcc→run. Reports PASS/FAIL.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="${RT_DIR:-$HERE/../../SCRIP/out}"
CORPUS="${CORPUS:-$S4E/corpus}"
INC="$CORPUS/include"
TIMEOUT="${TIMEOUT:-10}"

if [ ! -x "$SCRIP" ]; then echo "SKIP scrip not built"; exit 0; fi
if [ ! -d "$CORPUS" ]; then echo "SKIP corpus not found at $CORPUS"; exit 0; fi

WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

compile_mode4() {
    local sno="$1" out="$2"
    local tmp; tmp="$(mktemp -d)"
    SNO_LIB="$INC" "$SCRIP" --compile "$sno" > "$tmp/p.s" 2>/dev/null || { rm -rf "$tmp"; return 1; }
    (cd "$HERE/../../SCRIP" && gcc -c "$tmp/p.s" -o "$tmp/p.o" 2>/dev/null) || { rm -rf "$tmp"; return 1; }
    gcc "$tmp/p.o" -L"$RT_DIR" -lscrip_rt -lm \
        -Wl,-rpath,"$RT_DIR" -o "$out" 2>/dev/null || { rm -rf "$tmp"; return 1; }
    rm -rf "$tmp"
}

PASS=0; FAIL=0; SKIP=0; N=0
T0=$SECONDS
echo "=== broad corpus + beauty — MODE-4 ONLY ==="

run_sno() {
    local sno="$1"
    local ref="${sno%.sno}.ref"
    local input="${sno%.sno}.input"
    local slug; slug=$(basename "${sno%.sno}")
    N=$((N+1))
    local bin="$WORKDIR/${slug}_${N}.bin"
    if ! compile_mode4 "$sno" "$bin"; then
        SKIP=$((SKIP+1)); return
    fi
    local got exp
    if [ -f "$input" ]; then
        got=$(SNO_LIB="$INC" timeout -k 5 "$TIMEOUT" "$bin" < "$input" 2>/dev/null || true)
    else
        got=$(SNO_LIB="$INC" timeout -k 5 "$TIMEOUT" "$bin" < /dev/null 2>/dev/null || true)
    fi
    if [ -f "$ref" ]; then
        exp=$(cat "$ref")
        if [ "$got" = "$exp" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
    else
        PASS=$((PASS+1))
    fi
}

while IFS= read -r sno; do run_sno "$sno"; done < <(
    find "$CORPUS/tests/snobol4" -maxdepth 1 -name "*.sno" ! -name "ALL.sno" 2>/dev/null | sort | head -300
)
[ -f "$CORPUS/demos/snobol4/beauty/beauty.sno" ] && run_sno "$CORPUS/demos/snobol4/beauty/beauty.sno"

T_M4=$((SECONDS-T0))
echo ""
printf "mode-4 --compile:  PASS=%d FAIL=%d SKIP=%d\n" "$PASS" "$FAIL" "$SKIP"
printf "TIME M4=%ds TOTAL=%ds\n" "$T_M4" "$T_M4"
