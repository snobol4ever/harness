#!/usr/bin/env bash
# test_arbno_radius_ab.sh — m3 A/B over a program list, SCRIP_ARBNO_RBP ON vs OFF, vs the live oracle.
# Purpose: the s73 E-1 gate "m3 A/B over radius, 0 PASS->FAIL".  Prints per-class counts and names
# only the MOVERS, so the instrument never floods a session's context.
# Usage: bash ../harness/scripts/test_arbno_radius_ab.sh <listfile-of-corpus-relative-paths> [tag]
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
CORPUS="${CORPUS:-$S4E/corpus}"
. "$ROOT/../harness/scripts/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255)." >&2; exit 3; }
SBL="${SBL:-$S4A/x64/bin/sbl}"   # CORRECTNESS oracle -- A/B correctness sweep, not timing
LIST="${1:?usage: $0 <listfile> [tag]}"
TAG="${2:-ab}"
W=/tmp/radab.$TAG; mkdir -p "$W"
same=0; moved=0; : > "$W/movers.txt"
while read -r p; do
    [ -n "$p" ] || continue
    f="$CORPUS/$p"; b=$(echo "$p" | tr '/' '_')
    "$SBL" $(sbl_lang_flags) "$f" < /dev/null > "$W/$b.ora" 2>/dev/null; orc=$?
    SCRIP_ARBNO_RBP=1 timeout -k 5 20 "$ROOT/scrip" --run "$f" < /dev/null > "$W/$b.on" 2>/dev/null; onrc=$?
    SCRIP_ARBNO_RBP=0 timeout -k 5 20 "$ROOT/scrip" --run "$f" < /dev/null > "$W/$b.off" 2>/dev/null; offrc=$?
    von=FAIL; voff=FAIL
    [ $onrc  -eq $orc ] && cmp -s "$W/$b.ora" "$W/$b.on"  && von=PASS
    [ $offrc -eq $orc ] && cmp -s "$W/$b.ora" "$W/$b.off" && voff=PASS
    if [ "$von" = "$voff" ] && [ $onrc -eq $offrc ] && cmp -s "$W/$b.on" "$W/$b.off"; then
        same=$((same+1))
    else
        moved=$((moved+1))
        printf '%-58s OFF=%-4s(rc=%s)  ON=%-4s(rc=%s)\n' "$p" "$voff" "$offrc" "$von" "$onrc" >> "$W/movers.txt"
    fi
done < "$LIST"
echo "identical ON==OFF : $same"
echo "movers            : $moved"
if [ $moved -gt 0 ]; then
    echo "--- movers ---"; cat "$W/movers.txt"
    echo "PASS->FAIL (regressions): $(grep -c 'OFF=PASS.*ON=FAIL' "$W/movers.txt" || true)"
    echo "FAIL->PASS (repairs)    : $(grep -c 'OFF=FAIL.*ON=PASS' "$W/movers.txt" || true)"
fi
