#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_keyword_spelling_is_case_sensitive.sh -- row
# snobol4-keyword-names-are-case-folded-so-lowercase-ampersand-alphabet-resolves-where-spitbol-refuses-it.
#
# SCRIP is specified CASE-SENSITIVE and `sbl -bf` is the only oracle arm that matches that spelling rule.
# A SNOBOL4 keyword therefore resolves ONLY in its canonical (upper-case) spelling: &ALPHABET resolves,
# &alphabet and &Alphabet are undefined keyword names. Measured against /home/resources/x64/bin/sbl -bf
# (hq_P 2026-09-11): read AND write of a folded spelling raise ERROR 251 in the oracle, both engines.
#
# ⛔ The 251 is a RUNTIME error, never a compile-time one -- proven against the oracle: a statement before
# the bad read still prints, and a folded spelling on an unreached line raises nothing at all. That is why
# rt_kw_index must merely DECLINE a folded spelling (returning -1 so no static slot/direct cell is taken)
# rather than diagnose it: the diagnosis belongs to the runtime read/write path the declined slot falls back to.
#
# ⭐ The arm is run with &USER_DECLARED_CONSTANTS = 0. With udc ON (SCRIP's default) an undefined keyword
# reaches the user-constant namespace and raises 342, not 251 -- that gap is the SEPARATE sibling row
# snobol4-unknown-keyword-assignment-not-detected and is deliberately NOT graded here.
# Exit: 0 = every arm as specified; 1 = a divergence; 2 = cannot measure.
set -uo pipefail
SCRIP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
SCRIP_BIN="${SCRIP_BIN:-$SCRIP_DIR/scrip}"
[ -x "$SCRIP_BIN" ] || { echo "⛔ GATE REFUSES: no built ./scrip at $SCRIP_BIN -- this gate cannot measure"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
printf '\t&USER_DECLARED_CONSTANTS = 0\n\tOUTPUT = "S" &alphabet\nEND\n'        > "$W/read_folded.sno"
printf '\t&USER_DECLARED_CONSTANTS = 0\n\tOUTPUT = "S" &Alphabet\nEND\n'        > "$W/read_mixed.sno"
printf '\t&USER_DECLARED_CONSTANTS = 0\n\t&alphabet = "x"\nEND\n'               > "$W/write_folded.sno"
printf '\t&USER_DECLARED_CONSTANTS = 0\n\t&anchor = 1\nEND\n'                   > "$W/write_anchor.sno"
printf '\t&USER_DECLARED_CONSTANTS = 0\n\tOUTPUT = "LEN=" SIZE(&ALPHABET)\nEND\n' > "$W/read_canon.sno"
printf '\t&USER_DECLARED_CONSTANTS = 1\n\t&Tag = "hello"\n\tOUTPUT = "UDC=" &Tag\nEND\n' > "$W/udc_mixed.sno"
run_mode() {   # $1 = program, $2 = 3|4 -- prints the program's own stdout+stderr
    if [ "$2" = "3" ]; then timeout -k 5 15 "$SCRIP_BIN" "$1" < /dev/null 2>&1; return 0; fi
    timeout -k 5 15 "$SCRIP_BIN" --compile --out="$W/m4.s" "$1" < /dev/null > /dev/null 2>&1 || { echo "<compile-failed>"; return 0; }
    gcc -m64 -no-pie "$W/m4.s" -Wl,-rpath,"$SCRIP_DIR/out" -L"$SCRIP_DIR/out" -lscrip_rt -lm -o "$W/m4.bin" 2>/dev/null || { echo "<link-failed>"; return 0; }
    timeout -k 5 15 "$W/m4.bin" < /dev/null 2>&1
}
FAIL=0; TOTAL=0
check() {   # $1 = program stem, $2 = extended regex the output MUST match, $3 = english
    local stem="$1" want="$2" what="$3" m out
    for m in 3 4; do
        TOTAL=$((TOTAL + 1)); out="$(run_mode "$W/$stem.sno" "$m")"
        if printf '%s' "$out" | grep -qE "$want"; then printf '  ok   m%s %-14s %s\n' "$m" "$stem" "$what"
        else FAIL=$((FAIL + 1)); printf '  FAIL m%s %-14s %s -- got: %s\n' "$m" "$stem" "$what" "$(printf '%s' "$out" | head -2 | tr '\n' '|')"; fi
    done
}
echo "[gate] SNOBOL4 keyword spelling is case-sensitive (oracle: sbl -bf)"
check read_folded   'error 251:'  'a folded read raises 251'
check read_mixed    'error 251:'  'a mixed-case read raises 251'
check write_folded  'error 251:'  'a folded write raises 251'
check write_anchor  'error 251:'  'a folded write to a live keyword raises 251'
check read_canon    'LEN=256'    'the canonical spelling still resolves'
check udc_mixed     'UDC=hello'  'a mixed-case USER-DECLARED constant is untouched'
if [ "$FAIL" -eq 0 ]; then echo "GATE GREEN [sno_keyword_spelling_is_case_sensitive]: $TOTAL/$TOTAL arms"; exit 0; fi
echo "⛔ GATE RED [sno_keyword_spelling_is_case_sensitive]: $FAIL of $TOTAL arms diverge"; exit 1
