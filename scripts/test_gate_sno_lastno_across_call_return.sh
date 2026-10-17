#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the SNOBOL4 statement instrumentation (the --stlimit switch; Lon 2026-09-24 16:0x: the feature is off by default and never inferred from the source, the correctness graders turn it on because the oracle always has it)
# test_gate_sno_lastno_across_call_return.sh -- &LASTNO (backed by g_stno) is never saved/restored across a
# CALL/RETURN boundary in any calling convention. Real SPITBOL semantics: after a call returns, &LASTNO reads
# the CALLER's own last-executed statement number, not the callee's. rt_stmt_enter (src/runtime/keywords.c)
# fires only at a textual statement boundary; nothing saves or restores g_stno at a call boundary.
#
# Row: gstno-lastno-not-restored-across-call-return-boundary (hq_U). Witness minted and oracle-verified by
# seat11 2026-09-05; this gate is the runnable criterion for it (the row was minted with the placeholder
# DONE-WHEN and was therefore UNPICKABLE -- ceo census 19:02).
#
# ⛔ GENERAL AND TRACE-INDEPENDENT: the witness below uses no TRACE at all. A cure that only fixes the SIG
# shim (bb_define_sr) and not the other conventions (bb_call_proc_staged ab3b_z/fn_cell and the generic-slim
# fallbacks, bb_define_activate/bb_define_bind, xa_flat CLASS-C) leaves the class open -- NO PER-OP FILTER.
#
# Graded in BOTH modes against /home/resources/x64/bin/sbl -bf. rc=0 both modes match the oracle, rc=1 either
# diverges, rc=2 could not measure (no oracle, no binary, build/link failure, zero programs graded).
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
GATE_NAME="$(basename "${BASH_SOURCE[0]}")"
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unavailable"; exit 2; }
. "$HERE/lib_gate.sh"          || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_gate.sh unavailable"; exit 2; }
gate_parse_args "$@"
O="$(sbl_correctness_bin)" || exit 2
gate_require_exec "$ROOT/scrip" "the scrip binary"
# ⛔ FRESHNESS IS NOT OPTIONAL: without this a gate grades whatever binary happens to be in the tree and
# stamps its verdict with a git SHA that is not evidence about it. Omitted on the first cut of this file and
# caught by test_gate_runners_refuse_on_a_stale_binary.sh (census arm: gates that execute ./scrip with no
# freshness guard) before it could ever publish a false reading -- the blocking set doing exactly its job.
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
T="$(mktemp -d)" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
W="$T/lastno.sno"
{ printf '        DEFINE("G(Y)")                          :(START)\n'
  printf 'G       G = Y                                   :(RETURN)\n'
  printf 'START   N = G(9)\n'
  printf '        OUTPUT = "lastno=" &LASTNO\n'
  printf 'END\n'; } > "$W"
ORA="$( cd "$T" && timeout -k 5 30s "$O" -bf lastno.sno </dev/null 2>/dev/null )"; orc=$?
case "$ORA" in *lastno=*) : ;; *) echo "GATE UNPROVEN(2) [$GATE_NAME]: oracle produced no lastno= line (rc=$orc)"; exit 2;; esac
M3="$( cd "$T" && timeout -k 5 30s "$ROOT/scrip" lastno.sno </dev/null 2>/dev/null )"
( cd "$T" && timeout -k 5 30s "$ROOT/scrip" --compile -o lastno.s lastno.sno </dev/null >/dev/null 2>&1 ) \
  || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mode-4 compile failed"; exit 2; }
( cd "$T" && gcc -no-pie lastno.s -o lastno.bin -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
  || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mode-4 link failed"; exit 2; }
M4="$( cd "$T" && timeout -k 5 30s ./lastno.bin </dev/null 2>/dev/null )"
red=0; examined=0
for tag in m3 m4; do
    eval "got=\$$(echo "$tag" | tr 'a-z' 'A-Z')"
    examined=$((examined+1))
    if [ "$got" = "$ORA" ]; then echo "PASS $tag: $got (oracle: $ORA)"
    else echo "RED  $tag: got [$got] oracle [$ORA]"; red=$((red+1)); fi
done
gate_floor "$examined" 2 "modes graded"
gate_verdict "$red" "mode(s) whose &LASTNO disagrees with the oracle across a call/return boundary"
