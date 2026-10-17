#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# CN-4 GATE -- &USER_DECLARED_CONSTANTS (GOAL-SNOBOL4-100).
# Proves the declaration keyword in BOTH MEDIA (m3 --run BINARY, m4 --compile+gcc TEXT) and BOTH KW killswitch arms.
# ORACLE NOTE: every witness here is ORACLE_FAIL BY CONSTRUCTION -- stock SPITBOL answers error 251 for
# &USER_DECLARED_CONSTANTS exactly as for any undefined &name (measured s148), so refs are SCRIP-pinned, never sbl-diffed.
# g-cn2 (s153): the EVAL/CODE BOUNDARY is gated here too. cn_t1_eval sweeps BOTH T1 arms in BOTH media because the
# defect it guards was arm- AND mode-asymmetric: a runtime fragment inherited the main compile's seal table, so m3 with
# T1 on folded &N against a foreign tree_t and printed EMPTY while m4 -- compiling its fragments in another process --
# printed the value. All four cells must agree, and they must agree with the SEALED CELL, never with the fold.
# WITNESS-AUTHORING TRAP (measured s148): do NOT capture 2>&1 on a witness that both prints and errors -- m4 buffers
# stdout to exit while m3 does not, so the INTERLEAVING differs while both streams are byte-identical. Error witnesses
# therefore carry the .err_sno extension (repo convention) and no .ref, and are checked stream-by-stream below.
#
# ⭐ seat16 2026-08-27: 10 of the 11 witnesses below moved into the shared suite file
# tests/snobol4/tests/snobol4/probe_loose/cn.sno/.ref (probe-consolidate-m1-and-small) and are read back out one at a time via
# corpus_suite_harness.py's `extract` subcommand -- this gate is now JUST ANOTHER CONSUMER of that shared
# file, not a second copy of the witness text. `cn_udc_closed` (.err_sno, no .ref, stream-separated
# checking) does NOT fit the suite's one-.ref-per-entry model and stays a loose file permanently -- see
# tests/snobol4/probe_loose/cn/KEEP.md. Byte-equal-or-no-delete already proved each moved witness's suite form matches its
# original under the DEFAULT arm at conversion time; cn_t1_eval/cn_t2_eval_boundary/cn_t1_scalar_fold were
# ADDITIONALLY hand-verified (both T1 arms, both media, extracted form vs the pre-move original) before
# their loose files were deleted, since the harness's own convert step only ever exercises one arm.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
SCRIP="${SCRIP:-$S4E/SCRIP/scrip}"
RT="${RT:-$S4E/SCRIP/out}"
RUNGS_LANG="${RUNGS_LANG:-snobol4}" . "$(dirname "$0")/lib_rungs_extract.sh"
pass=0; fail=0
chk() { if [ "$1" = 0 ]; then pass=$((pass+1)); else fail=$((fail+1)); echo "  FAIL: $2"; fi; }
# ⛔ SUITE_SNO/SUITE_REF/HARNESS RETIRED (row dead-suite-path-consumer-sweep): the dedicated cn.sno/cn.ref
# pair this script used to extract from is gone -- Lon's one-flat-suite ruling absorbed it into the rungs
# ALL.sno/.ref/.csv under family probe_cn (confirmed: all 10 witness names below are present as
# probe_cn__<name> origins in ALL.csv). lib_rungs_extract.sh's rungs_extract_origin is the modern
# replacement for exactly this old dedicated-suite-file consumer shape (its own header names this pattern).
# Materializes suite entry $1 into /tmp/gate_x_$1.sno (+ .ref) and sets EX_SNO/EX_REF. Returns nonzero
# (and records a FAIL itself) if the name isn't in the rungs suite -- callers just `|| continue`.
extract_witness() {
  local w="$1"
  EX_SNO="/tmp/gate_x_$w.sno"; EX_REF="/tmp/gate_x_$w.ref"
  if ! rungs_extract_origin "probe_cn__$w" "$EX_SNO" "$EX_REF" 2>/tmp/gate_x_err.txt; then
    echo "  FAIL: extract $w (origin probe_cn__$w) from the rungs suite failed: $(cat /tmp/gate_x_err.txt)"; fail=$((fail+1)); return 1
  fi
}
# ⛔ CN IS ASSEMBLED, NOT A FIXED TREE: cn_udc_closed is the one witness that deliberately stayed a loose
# .err_sno file (no .ref, stream-separated checking -- doesn't fit the suite's one-.ref-per-entry model,
# per this file's own header comment) rather than moving into the rungs suite. It now lives under
# tests/snobol4/config/, prefixed probe_loose_cn_ -- confirmed via find, not assumed. Override honoured as-is.
if [ -z "${CN:-}" ]; then
    CN="$(mktemp -d)"
    trap 'rm -rf "$CN"' EXIT
    cp "$S4E/corpus/tests/snobol4/config/probe_loose_cn_cn_udc_closed.err_sno" "$CN/cn_udc_closed.err_sno"
fi
for w in cn_udc_declare cn_udc_reopen; do
  extract_witness "$w" || continue
  "$SCRIP" --compile "$EX_SNO" -o "/tmp/gate_$w.s" < /dev/null > /dev/null 2>&1
  gcc -no-pie "/tmp/gate_$w.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread -o "/tmp/gate_$w.bin" 2>/dev/null
  timeout -k 5 20 "$SCRIP" --run "$EX_SNO" < /dev/null > /tmp/gate_m3.txt 2>&1
  diff -q /tmp/gate_m3.txt "$EX_REF" > /dev/null 2>&1; chk $? "m3 $w"
  timeout -k 5 20 "/tmp/gate_$w.bin" < /dev/null > /tmp/gate_m4.txt 2>&1
  diff -q /tmp/gate_m4.txt "$EX_REF" > /dev/null 2>&1; chk $? "m4 $w"
  # KW-4 deleted SCRIP_KW_STATIC, so the old `for arm in 0 1` loop ran the SAME binary path twice and
  # counted it as two passes -- the vacuous-gate class.  One arm, graded once, honest count.
done
for w in cn_t1_eval cn_t2_eval_boundary cn_t1_scalar_fold; do   # ⭐ CN-11 added cn_t1_scalar_fold: it was pinned but only ever RUN in the default arm, and the T1=0 arm is where the shared-runtime keyword cascade shadowed a sealed &Pi with Icon's pi (3.141592653589793 vs the declared 3.14). A fold-tier witness must be swept in the arm where the fold is OFF -- that arm is the one that exercises the runtime read path the fold otherwise hides.
extract_witness "$w" || continue
for t1 in 0 1; do
  SCRIP_CONST_T1=$t1 timeout -k 5 20 "$SCRIP" --run "$EX_SNO" < /dev/null > /tmp/gate_m3.txt 2>/dev/null
  diff -q /tmp/gate_m3.txt "$EX_REF" > /dev/null 2>&1; chk $? "m3 $w CONST_T1=$t1"
  # ⛔ CN-11 -- THE m4 ARM WAS VACUOUS AND IS NOW REAL. The compile+link used to sit ABOVE this loop, so the .s was
  # produced ONCE at the DEFAULT arm and the loop then varied SCRIP_CONST_T1 on the already-built binary. T1 is a
  # LOWERING decision: by the time the binary exists the fold is baked into its instructions, so the env var moved
  # nothing and "m4 $w CONST_T1=0" re-tested the T1=1 program twice -- the s68 vacuous-gate class. Measured proof:
  # with the CN-11 defect present, m3 CONST_T1=0 went red while m4 CONST_T1=0 stayed green on the SAME program.
  # Compiling INSIDE the loop with the arm's env applied is what makes the m4 column a second real medium.
  SCRIP_CONST_T1=$t1 "$SCRIP" --compile "$EX_SNO" -o "/tmp/gate_$w.s" < /dev/null > /dev/null 2>&1
  gcc -no-pie "/tmp/gate_$w.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread -o "/tmp/gate_$w.bin" 2>/dev/null
  SCRIP_CONST_T1=$t1 timeout -k 5 20 "/tmp/gate_$w.bin" < /dev/null > /tmp/gate_m4.txt 2>/dev/null
  diff -q /tmp/gate_m4.txt "$EX_REF" > /dev/null 2>&1; chk $? "m4 $w CONST_T1=$t1"
done
done
# ⭐⭐ CN-DOLLAR-ORACLE (queue row `cn-oracle-rulings`, HQ-61 ORACLE-FAITHFUL CONFIRMED) added cn_indirect_rewrite and cn_indirect_seal to this loop.  The first is a LIVE-ORACLE .ref covering the half its
# sibling could not see -- cn_indirect_is_ordinary_var writes each indirect cell exactly ONCE, so it was green all along against a runtime that sealed the cell and raised 341 on the SECOND write.  The
# second is the s153 RULING-REQUEST pin, rewritten to the ruled table; it went red on the first run after the flip, which is exactly what s153 minted it to do.  Both ride the stderr-SILENT assertion too:
# the oracle assigns in total silence, and a 341 printed before an otherwise-correct stdout is a regression the .ref alone structurally cannot see.
for w in cn_t1_eval_undecl cn_eval_fails_not_aborts cn_indirect_is_ordinary_var cn_indirect_rewrite cn_indirect_seal; do
extract_witness "$w" || continue
"$SCRIP" --compile "$EX_SNO" -o "/tmp/gate_$w.s" < /dev/null > /dev/null 2>&1
gcc -no-pie "/tmp/gate_$w.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread -o "/tmp/gate_$w.bin" 2>/dev/null
timeout -k 5 20 "$SCRIP" --run "$EX_SNO" < /dev/null 2>/dev/null > /tmp/gate_u3.txt
timeout -k 5 20 "/tmp/gate_$w.bin" < /dev/null 2>/dev/null > /tmp/gate_u4.txt
diff -q /tmp/gate_u3.txt "$EX_REF" > /dev/null 2>&1; chk $? "m3 $w == ref"
diff -q /tmp/gate_u4.txt "$EX_REF" > /dev/null 2>&1; chk $? "m4 $w == ref"
timeout -k 5 20 "$SCRIP" --run "$EX_SNO" < /dev/null 2>/tmp/gate_ue3.txt > /dev/null
timeout -k 5 20 "/tmp/gate_$w.bin" < /dev/null 2>/tmp/gate_ue4.txt > /dev/null
[ -s /tmp/gate_ue3.txt ]; [ $? = 1 ]; chk $? "$w m3 stderr SILENT (a caught error is not reported)"
[ -s /tmp/gate_ue4.txt ]; [ $? = 1 ]; chk $? "$w m4 stderr SILENT (a caught error is not reported)"
done
# ⭐⭐ CN-EVAL-FAILS (queue row `cn-oracle-rulings`): this block USED to assert the opposite -- `grep 342 <stderr>` on cn_t1_eval_undecl.err_sno, pinning the ABORT that manual v3.7 p.131 forbids.
# s153 pinned it deliberately ("so KW-5 moves it deliberately rather than silently") and Lon's s168 oracle directive moved it: live sbl FAILS the EVAL and runs on, in total silence.  The three
# witnesses now ride ONE loop because the ruling gave them one shape: a real .sno with a .ref in both media, and an EMPTY stderr -- the silence assertion is not decoration, it is the half that
# catches a regression the .ref cannot see, since core_runtime_error printing before the conversion would leave stdout perfect and stderr full of errors the oracle never emits.
#
# ⛔ cn_udc_closed stays a LOOSE FILE, permanently -- .err_sno, no .ref, stream-separated m3==m4 checking
# (no oracle text to diff against at all). Structurally does not fit the suite's one-.ref-per-entry model;
# see tests/snobol4/probe_loose/cn/KEEP.md. Read directly from $CN, same as before this row.
w=cn_udc_closed
"$SCRIP" --compile "$CN/$w.err_sno" -o "/tmp/gate_$w.s" < /dev/null > /dev/null 2>&1
gcc -no-pie "/tmp/gate_$w.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm -lpthread -o "/tmp/gate_$w.bin" 2>/dev/null
timeout -k 5 20 "$SCRIP" --run "$CN/$w.err_sno" < /dev/null 2>/dev/null > /tmp/gate_o3.txt
timeout -k 5 20 "/tmp/gate_$w.bin" < /dev/null 2>/dev/null > /tmp/gate_o4.txt
diff -q /tmp/gate_o3.txt /tmp/gate_o4.txt > /dev/null 2>&1; chk $? "$w stdout m3==m4"
timeout -k 5 20 "$SCRIP" --run "$CN/$w.err_sno" < /dev/null 2>/tmp/gate_e3.txt > /dev/null
timeout -k 5 20 "/tmp/gate_$w.bin" < /dev/null 2>/tmp/gate_e4.txt > /dev/null
diff -q /tmp/gate_e3.txt /tmp/gate_e4.txt > /dev/null 2>&1; chk $? "$w stderr m3==m4"
grep -q "251" /tmp/gate_e3.txt; chk $? "$w raises 251 with the namespace closed"
grep -q "keyword operand is not name of defined keyword" /tmp/gate_e3.txt; chk $? "$w 251 text is oracle-verbatim"
echo "CN-4 GATE: PASS=$pass FAIL=$fail"
[ "$fail" = 0 ] || exit 1
