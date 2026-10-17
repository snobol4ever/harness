#!/usr/bin/env bash
# test_one_witness.sh — ONE program, m3 + m4 end-to-end vs the LIVE x64 sbl oracle.
# Usage: SCRIP_ARBNO_RBP=<arm> bash ../harness/scripts/test_one_witness.sh <file.sno> [tag]
# Keeps the built .s/.bin in $W so a following gdb run uses the SAME artifact.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -u
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
. "$ROOT/../harness/scripts/lib_oracle_flags.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_oracle_flags.sh -- the ONE oracle-flag authority (s200/s255)." >&2; exit 3; }
. "$ROOT/../harness/scripts/lib_gate.sh" 2>/dev/null || { echo "REFUSING: cannot load lib_gate.sh -- the ONE gate-honesty authority." >&2; exit 3; }
SBL="${SBL:-$S4A/x64/bin/sbl}"   # CORRECTNESS oracle -- single-witness check, not timing
F="$1"; TAG="${2:-run}"
b=$(basename "$F" .sno)
W=/tmp/onew.$TAG; mkdir -p "$W"
"$SBL" $(sbl_lang_flags) "$F" < /dev/null > "$W/$b.ora" 2>/dev/null; orc=$?
timeout -k 5 15 "$ROOT/scrip" --run "$F" < /dev/null > "$W/$b.m3" 2>"$W/$b.m3.err"; m3rc=$?
if gate_oracle_stdout_match "$W/$b.ora" "$W/$b.m3" "$W/$b.m3.err" "$m3rc"; then m3="PASS"; else m3="rc=$m3rc/$orc"; cmp -s "$W/$b.ora" "$W/$b.m3" || m3="$m3,DIFF"; fi
s=$(timeout -k 5 15 "$ROOT/scrip" --compile "$F" < /dev/null 2>/dev/null)
if [ -z "$s" ]; then m4="EMITFAIL"; else
    printf '%s' "$s" > "$W/$b.s"
    if as -o "$W/$b.o" "$W/$b.s" 2>"$W/$b.aserr" && gcc -no-pie -o "$W/$b.bin" "$W/$b.o" "$ROOT/out/libscrip_rt.so" -Wl,-rpath,"$ROOT/out" 2>"$W/$b.lderr"; then
        timeout -k 5 15 "$W/$b.bin" < /dev/null > "$W/$b.m4" 2>"$W/$b.m4.err"; m4rc=$?
        if gate_oracle_stdout_match "$W/$b.ora" "$W/$b.m4" "$W/$b.m4.err" "$m4rc"; then m4="PASS"; else m4="rc=$m4rc/$orc"; cmp -s "$W/$b.ora" "$W/$b.m4" || m4="$m4,DIFF"; fi
    else m4="ASM/LINK"; fi
fi
printf '%-28s arm=%-3s m3=%-12s m4=%-12s (oracle rc=%s, artifacts %s)\n' "$b" "${SCRIP_ARBNO_RBP:-default}" "$m3" "$m4" "$orc" "$W"
