#!/usr/bin/env bash
# test_sno_pat_bb_probe.sh — PB-RB build/run probes for the SNOBOL4 native pattern ladder
# (GOAL-SNOBOL4-BB SESSION RUNG #0 SBL-PAT-BB / REBUILT LADDER PB-RB). Each probe builds a
# four-port flat chain directly, JITs it via sno_flat_chain_build, runs it with rt_frame,
# and (PB-RB-1) confirms REF_INVARIANT loads a sealed IR_PAT_LIT head into a ζ-slot — stackless,
# no value stack. Run after `bash ../harness/scripts/build_scrip.sh && make libscrip_rt`.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SRC="$ROOT/../corpus/tests/scrip_test/snobol4/pat_bb"
OUT="$ROOT/out"
. "$HERE/lib_build_flags.sh"; build_flags_load "$ROOT" || { echo "REFUSE(2): lib_build_flags.sh could not read the build's include list"; exit 2; }
read -r -a INC <<< "$BF_RT_INCS"
PASS=0; FAIL=0
run_probe() {
    local name="$1" expect="$2"
    local bin; bin="$(mktemp /tmp/sno_probe_XXXXXX)"
    if ! gcc -O0 -g -w "${INC[@]}" -DDYN_ENGINE_LINKED -DIR_DEFINE_NAMES \
         "$SRC/$name.c" -L "$OUT" -lscrip_rt -lm -lstdc++ -Wl,-rpath,"$OUT" -o "$bin" 2>/dev/null; then
        echo "  FAIL $name (compile)"; FAIL=$((FAIL+1)); return
    fi
    local got; got="$(LD_LIBRARY_PATH="$OUT" timeout -k 5 8 "$bin" < /dev/null 2>/dev/null)"
    rm -f "$bin"
    if echo "$got" | grep -q "$expect"; then echo "  PASS $name"; PASS=$((PASS+1));
    else echo "  FAIL $name (got: $(echo "$got" | tail -1))"; FAIL=$((FAIL+1)); fi
}
echo "=== SNOBOL4 PAT-BB probes (modes 3 native JIT) ==="
run_probe probe_pb_rb_1_ref_invariant "ran fn(rt_frame(),0) without crash"
run_probe probe_pb_rb_3_match "MATCH SUCCEEDED"
run_probe probe_pb_rb_3_match_fail "PB-RB-3 EDGES OK"
run_probe probe_pb_rb_4_cat "PB-RB-4 CAT OK"
run_probe probe_pb_rb_4_alt "PB-RB-4 ALT OK"
run_probe probe_pb_rb_conv_alt_lowered "PB-RB-CONV ALT-LOWERED OK"
run_probe probe_pb_rb_conv_cat_lowered "PB-RB-CONV CAT-LOWERED OK"
run_probe probe_pb_rb_5_capture "PB-RB-5 CAPTURE OK"
echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
