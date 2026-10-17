#!/bin/bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pas_frame_pairing.sh — PAS-ZF-10 structural prison
# For every emitted proc_* region, assert push_rbp==pop_rbp and mov_rbp_rsp==mov_rsp_rbp
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
CORPUS="${CORPUS:-$S4E/corpus/tests/pascal}"
FAIL=0; PASS=0
WITNESSES="${WITNESSES:-emptyproc p2 nestvar varparam}"
# ⭐ V2-5 GATE HONESTY: examining nothing must exit UNPROVEN(2), never read as a pass.
. "$(dirname "$0")/lib_gate.sh"
gate_require_exec "${SCRIP:-${SCRIP_BIN:-$(dirname "$0")/../../SCRIP/scrip}}" "the scrip compiler"
gate_require "${RT_DIR:-$(dirname "$0")/../../SCRIP/out}/libscrip_rt.so" "the runtime shared object out/libscrip_rt.so"
for name in $WITNESSES; do
    pas="$CORPUS/$name.pas"
    [ -f "$pas" ] || { echo "SKIP $name (not found)"; continue; }
    asm=$(timeout -k 5 8s "$SCRIP" --compile "$pas" < /dev/null 2>/dev/null) || { echo "FAIL $name (compile error)"; FAIL=$((FAIL+1)); continue; }
    # Split by proc_* region and count push/pop/mov rbp pairs
    ok=1
    while IFS= read -r region; do
        rname=$(echo "$region" | grep -o 'proc_[a-zA-Z0-9_]*' | head -1)
        [ -z "$rname" ] && continue
        push_rbp=$(echo "$region" | grep -c 'push.*rbp' || true)
        pop_rbp=$(echo "$region"  | grep -c 'pop.*rbp'  || true)
        mov_br=$(echo "$region"   | grep -c 'mov.*rbp,rsp' || true)
        mov_rb=$(echo "$region"   | grep -c 'mov.*rsp,rbp' || true)
        if [ "$push_rbp" -ne "$pop_rbp" ] || [ "$mov_br" -ne "$mov_rb" ]; then
            echo "UNPAIRED $name/$rname: push_rbp=$push_rbp pop_rbp=$pop_rbp mov_rbp_rsp=$mov_br mov_rsp_rbp=$mov_rb"
            ok=0; FAIL=$((FAIL+1))
        fi
    done < <(echo "$asm" | awk '/proc_[a-zA-Z0-9_]+:/{r=$0;next} r{r=r"\n"$0} /^[a-zA-Z_][a-zA-Z0-9_]*:/{if(r)print r; r=""}')
    [ $ok -eq 1 ] && { echo "PAIRED $name"; PASS=$((PASS+1)); }
done
echo "frame-pairing: PASS=$PASS FAIL=$FAIL"
[ $FAIL -eq 0 ]
