#!/usr/bin/env bash
# test_arbno_witnesses.sh — the EARN-4 named witness set vs the LIVE x64 sbl oracle, m3 + m4 end-to-end.
# Rows: arb1 · 181_pat_arbno_defer_tail_stressors · N22..N33 · earn0_disc_arbno_star_fence_{positive,poisoned}.
# m4 is the honest medium for the stack-slot class (s66 law: m3 exit 0 is not exoneration).
# Usage: SCRIP_ARBNO_RBP=<0|1> bash ../harness/scripts/test_arbno_witnesses.sh <tag>
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -u
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
CORPUS="${CORPUS:-$S4E/corpus}"
. "$ROOT/../harness/scripts/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255)." >&2; exit 3; }
SBL="${SBL:-$S4A/x64/bin/sbl}"   # CORRECTNESS oracle -- witness set vs live oracle, not timing
TAG="${1:-run}"
W=/tmp/arbw.$TAG; mkdir -p "$W"
# ⭐ corpus-crosscheck-probe-total-conversion (2026-08-28/29): every witness below now lives only
# inside a suite file (tests/snobol4/crosscheck/patterns.{sno,ref}, tests/snobol4/probe/earn0.{sno,ref},
# tests/snobol4/probe/bb_probes.{sno,ref} -- the last from probe-consolidate-bb, concurrent this same
# day; tests/snobol4/probe/arb1.{sno,ref} converted 2026-08-29, seat12) -- this tool needs each as a
# standalone file to feed sbl/scrip directly, so extract() materializes one per run into $W.
extract() { rungs_extract_origin "$1__$2" "$W/$2.sno"; }   # re-pointed to THE RUNGS by origin (zero-subfolders cutover, ceo s283h)
RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$(dirname "${BASH_SOURCE[0]}")/lib_rungs_extract.sh"
extract crosscheck_patterns 181_pat_arbno_defer_tail_stressors
extract probe_earn0 earn0_disc_arbno_star_fence_positive
extract probe_earn0 earn0_disc_arbno_star_fence_poisoned
extract probe_arb1 arb1
FILES="$W/arb1.sno $W/181_pat_arbno_defer_tail_stressors.sno"
for n in 22 23 24 25 26 27 28 29 30 31 32 33; do
    extract probe_bb_probes "N$n"
    FILES="$FILES $W/N$n.sno"
done
FILES="$FILES $W/earn0_disc_arbno_star_fence_positive.sno $W/earn0_disc_arbno_star_fence_poisoned.sno"
printf '%-46s %-8s %-8s\n' witness m3 m4
for f in $FILES; do
    b=$(basename "$f" .sno)
    [ -f "$f" ] || { printf '%-46s MISSING\n' "$b"; continue; }
    "$SBL" $(sbl_lang_flags) "$f" < /dev/null > "$W/$b.ora" 2>/dev/null; orc=$?
    timeout -k 5 15 "$ROOT/scrip" --run "$f" < /dev/null > "$W/$b.m3" 2>/dev/null; m3rc=$?
    if [ $m3rc -eq $orc ] && cmp -s "$W/$b.ora" "$W/$b.m3"; then m3="PASS"; else m3="rc=$m3rc/$orc"; cmp -s "$W/$b.ora" "$W/$b.m3" || m3="$m3,DIFF"; fi
    s=$(timeout -k 5 15 "$ROOT/scrip" --compile "$f" < /dev/null 2>/dev/null)
    if [ -z "$s" ]; then m4="EMITFAIL"; else
        printf '%s' "$s" > "$W/$b.s"
        if as -o "$W/$b.o" "$W/$b.s" 2>"$W/$b.aserr" && gcc -no-pie -o "$W/$b.bin" "$W/$b.o" "$ROOT/out/libscrip_rt.so" -Wl,-rpath,"$ROOT/out" 2>"$W/$b.lderr"; then
            timeout -k 5 15 "$W/$b.bin" < /dev/null > "$W/$b.m4" 2>/dev/null; m4rc=$?
            if [ $m4rc -eq $orc ] && cmp -s "$W/$b.ora" "$W/$b.m4"; then m4="PASS"; else m4="rc=$m4rc/$orc"; cmp -s "$W/$b.ora" "$W/$b.m4" || m4="$m4,DIFF"; fi
        else m4="ASM/LINK"; fi
    fi
    printf '%-46s %-8s %-8s\n' "$b" "$m3" "$m4"
done
