#!/bin/bash
# util_crosscheck_two_oracle_census.sh — 4-way census over corpus/crosscheck:
#   SCRIP mode-3  vs  SPITBOL (sbl -bf)  vs  CSNOBOL4 (snobol4 -b)  vs  the checked-in .ref
#
# WHY THIS EXISTS (s191 seat5, row prototype-array-dim): a .ref pinned from the WRONG oracle is
# invisible to every single-oracle harness — the program is red forever and looks like a compiler
# bug. This answers "which engine does each pin actually agree with", corpus-wide, in one sweep.
#
# ⛔ TWO INVOCATION RULES THIS SCRIPT EXISTS TO ENCODE. Both were learned by getting them WRONG and
# manufacturing a clean, plausible, entirely FALSE defect class each time (FINDING s191 §5):
#   1. RUN FROM THE CORPUS ROOT. Relative "-include 'lib/...'" resolves from there, not from the
#      program's own directory. Get this wrong and every -include program fails under BOTH oracles.
#   2. FEED EACH PROGRAM ITS OWN .input. That is what the harness's run_one does. Get this wrong and
#      every stdin-reading program disagrees with a .ref that was pinned WITH input.
# A census is a harness: copy run_one's invocation, never re-derive it.
#
# ⛔ RUN ON A PRISTINE BUILD AT A PULLED HEAD. On a stale binary this reports other seats' ALREADY
# FIXED defects as live ones (measured: 216_indirect_goto_computed, fixed by seat3 at s190).
#
# TAG = 4 chars:  [S]=SCRIP==SPITBOL  [C]=SCRIP==CSNOBOL4  [R]=SCRIP==.ref ('-' = no .ref)  [=|x]=oracles agree?
#   SCR=  green, fully corroborated          S.Rx  correct: SPITBOL is the authority and the pin agrees
#   .CRx  oracle gap — SPITBOL cannot run it (pin is fine)     ...=  ⛔ GENUINE SCRIP DEFECT (both oracles agree)
#   S..x  ⛔ THE PIN IS FROM THE WRONG ORACLE                  ..-x  no .ref at all — nothing grades it
#
# usage: bash ../harness/scripts/util_crosscheck_two_oracle_census.sh [out.tsv]
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: sibling root
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
. "$S4E/harness/scripts/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255)." >&2; exit 3; }
CC="$S4E/corpus/crosscheck"; SBL="${SBL:-$S4A/x64/bin/sbl}"; CSN="${CSNOBOL4:-/usr/local/bin/snobol4}"; SCRIP="$S4E/SCRIP/scrip"
out="${1:-/tmp/crosscheck_two_oracle_census.tsv}"
for r in "$SBL" "$CSN" "$SCRIP"; do [ -x "$r" ] || { echo "MISSING: $r"; echo "⛔ without both oracles this prints a plausible all-FAIL table — refusing"; exit 2; }; done
[ -d "$CC" ] || { echo "MISSING: $CC"; exit 2; }
cd "$S4E/corpus" || exit 2
: > "$out"
while IFS= read -r f; do
    rel="${f#./}"; ref="${f%.sno}.ref"; inp="${f%.sno}.input"; [ -f "$inp" ] || inp=/dev/null
    m=$(timeout -k 5 10s "$SCRIP" "$rel" < "$inp" 2>/dev/null)
    s=$(timeout -k 5 10s "$SBL" $(sbl_lang_flags) "$rel" < "$inp" 2>/dev/null)
    c=$(timeout -k 5 10s "$CSN" -b   "$rel" < "$inp" 2>/dev/null)
    tag=""; [ "$m" = "$s" ] && tag="${tag}S" || tag="${tag}."
    [ "$m" = "$c" ] && tag="${tag}C" || tag="${tag}."
    if [ -f "$ref" ]; then [ "$m" = "$(cat "$ref")" ] && tag="${tag}R" || tag="${tag}."; else tag="${tag}-"; fi
    [ "$s" = "$c" ] && tag="${tag}=" || tag="${tag}x"
    printf '%s\t%s\n' "$tag" "${rel#crosscheck/}" >> "$out"
done < <(find ./crosscheck -name '*.sno' | sort)
echo "== census: $out  (SCRIP $(git -C "$S4E/SCRIP" rev-parse --short HEAD 2>/dev/null), corpus $(git rev-parse --short HEAD 2>/dev/null)) =="
cut -f1 "$out" | sort | uniq -c | sort -rn
echo "== rows needing attention =="
grep -P '^S\.\.x|^\.\.\.=|^\.\.\.x|^\.\.-x' "$out" || echo "  (none)"
