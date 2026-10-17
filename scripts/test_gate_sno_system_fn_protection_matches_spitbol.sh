#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_system_fn_protection_matches_spitbol.sh -- SCRIP protects exactly the system-function names SPITBOL protects.
# For every name SCRIP lists as a system function (src/runtime/snobol4_system_fns.h) PLUS the 18 names the 2026-09-04
# measurement FREED (so removing a name from the list is tested, never assumed),
# three witnesses are cut LIVE from the oracle -- DEFINE('NAME(X)'), OPSYN('NAME','SIZE') and DATA('NAME(X)') -- and SCRIP (mode 3) must give
# the same verdict: ERROR 248 or a clean run. The set is never hard-coded: the oracle is the authority each run.
# Measured 2026-09-04 (ceo, row snobol4-gimpel-class-rc1-compilefail): SPITBOL protects 77 of SCRIP's 95 names; the 18 it
# leaves free (ABORT ALT ARB BAL CONCAT FAIL FUNCTION LABEL LCASE NAME NUMERIC PLS REAL REM SUCCEED UCASE VALUE VDIFFER)
# are what gimpel's BAL/LABEL-defining programs need.
# EXIT 0 every name agrees in both witnesses · 1 any disagreement (named) · 2 REFUSED (no oracle, no scrip, no list).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_oracle_flags.sh" || { echo "⛔ GATE REFUSE(2) [sno-system-fn-protection]: cannot source lib_oracle_flags.sh"; exit 2; }
O="$(sbl_correctness_bin)" || { echo "⛔ GATE REFUSE(2) [sno-system-fn-protection]: no correctness oracle"; exit 2; }
SCRIP="${SCRIP:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [sno-system-fn-protection]: $SCRIP not built"; exit 2; }
H="$ROOT/src/runtime/snobol4_system_fns.h"; [ -f "$H" ] || { echo "⛔ GATE REFUSE(2) [sno-system-fn-protection]: $H missing"; exit 2; }
FREED_2026_09_04="ABORT ALT ARB BAL CONCAT FAIL FUNCTION LABEL LCASE NAME NUMERIC PLS REAL REM SUCCEED UCASE VALUE VDIFFER"
NAMES="$( { grep -o '"[A-Z_0-9]*"' "$H" | tr -d '"'; printf '%s\n' $FREED_2026_09_04; } | sort -u)"
[ -n "$NAMES" ] || { echo "⛔ GATE REFUSE(2) [sno-system-fn-protection]: no names in $H"; exit 2; }
W=$(mktemp -d); trap 'rm -rf "$W"' EXIT
verdict() { # $1=binary $2=file -> PROT | FREE | ODD
    local out; out="$(timeout -k 5 5 "$1" $3 "$2" </dev/null 2>&1)"
    if printf '%s' "$out" | grep -qi 'error 248'; then echo PROT; elif printf '%s' "$out" | grep -q '^ok'; then echo FREE; else echo "ODD($(printf '%s' "$out" | grep -oi 'error [0-9]*' | head -1))"; fi
}
n=0; bad=0
for nm in $NAMES; do
    printf "\tDEFINE('%s(X)')\n\tOUTPUT = 'ok'\nEND\n%s\t%s = X\n\t:(RETURN)\n" "$nm" "$nm" "$nm" > "$W/d.sno"
    printf "\tOPSYN('%s','SIZE')\n\tOUTPUT = 'ok'\nEND\n" "$nm" > "$W/o.sno"
    printf "\tDATA('%s(X)')\n\tOUTPUT = 'ok'\nEND\n" "$nm" > "$W/t.sno"
    for w in d o t; do
        n=$((n+1)); o="$(verdict "$O" "$W/$w.sno" -bf)"; s="$(verdict "$SCRIP" "$W/$w.sno" "")"
        [ "$o" = "$s" ] || { bad=$((bad+1)); lbl="OPSYN"; [ "$w" = d ] && lbl="DEFINE"; [ "$w" = t ] && lbl="DATA"; printf 'DIVERGE %-10s %s: oracle=%s scrip=%s\n' "$nm" "$lbl" "$o" "$s"; }
    done
done
echo "SNO_SYSTEM_FN_PROTECTION names=$(echo "$NAMES" | wc -w) witnesses=$n diverge=$bad oracle=$O"
[ $bad -eq 0 ] && { echo "✅ GATE PASS(0) [sno-system-fn-protection]: SCRIP protects exactly what SPITBOL protects, DEFINE, OPSYN and DATA"; exit 0; }
echo "⛔ GATE FAIL(1) [sno-system-fn-protection]: $bad of $n witnesses diverge from the oracle"; exit 1
