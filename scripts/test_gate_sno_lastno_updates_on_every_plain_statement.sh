#!/usr/bin/env bash
# test_gate_sno_lastno_updates_on_every_plain_statement.sh -- bb_stmt_mark (src/templates/bb/bb_stmt_mark.cpp), the inline x86
# marker every SNOBOL4 statement compiles to in BOTH modes, wrote the new statement number straight into g_stno/g_line and
# NEVER shifted the old value into g_lastno/g_lastline -- only the C helper rt_stmt_enter did that shift, and bb_stmt_mark's
# inline marker is what a DEFAULT build (no --stlimit) actually runs. So on a default build &LASTNO/&LASTLINE never move off
# 0 (or whatever a CALL boundary's APPLY_fn save-restore, core.c:4195, last left there) no matter how many plain statements run.
#
# ⛔ GRADED UNDER --stlimit ON LON'S WORD (2026-10-02, in-chat to the cto, choosing how this gate grades: "Grade under
# --stlimit"; ceo CEO-1243, Lon 2026-09-24: "It is invalid to trigger off source content, since an EVAL or CODE can do
# the same without you knowing." and "The &STLIMIT feature with trace instrumentation should be controlled by a
# command-line switch."): &STNO/&LASTNO/&LINE/&LASTLINE are the instrumentation switch's, a default build carries no
# per-statement store and none is inferred from the source, so the witness is graded with --stlimit in both modes, and a
# CONTROL arm runs it without the switch, where &LASTNO must NOT match the oracle -- the switch is what supplies it, and
# the comparison can say no. The default-build premise this header first carried (an inline bb_stmt_mark in every
# default build) no longer holds: no statement marker is emitted without --stlimit.
#
# hq_snobol4, CEO-1295(ii) follow-on: found bisecting spitbol_testpgms/test1.spt under THE MONITOR (once
# test_gate_monitor_run_accepts_spt_and_sbl_extensions.sh unblocked it) -- run plain (no --stlimit; the package's own
# declared compile_args, so the suite's own grading is unaffected), a SETEXIT(.ERRORS) diagnostic handler reported
# "ERROR AT 58" for all 24 of its errors, real statement numbers 72..260 in the oracle. Still a real default-build defect:
# a SPITBOL program reading &LASTNO/&LASTLINE without --stlimit gets silently wrong answers, forever, after the first CALL.
#
# THE WITNESS: two plain assignments then two &LASTNO/&LASTLINE reads with no call in between -- the simplest shape that
# exercises bb_stmt_mark's own marker with nothing else in the picture. Graded in BOTH modes against sbl -bf.
set -u
unset SCRIP_SNO_STMTKW SCRIP_MON_VARS MONITOR_BIN   # the default (non-instrumented) road is the one under test
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
GATE_NAME="$(basename "${BASH_SOURCE[0]}")"
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unavailable"; exit 2; }
. "$HERE/lib_gate.sh"          || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_gate.sh unavailable"; exit 2; }
gate_parse_args "$@"
O="$(sbl_correctness_bin)" || exit 2
gate_require_exec "$ROOT/scrip" "the scrip binary"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
T="$(mktemp -d)" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
W="$T/lastno_plain.sno"
{ printf '        S1 = 5\n'
  printf '        S2 = 10\n'
  printf '        OUTPUT = "lastno1=" &LASTNO " lastline1=" &LASTLINE\n'
  printf '        S3 = 15\n'
  printf '        OUTPUT = "lastno2=" &LASTNO " lastline2=" &LASTLINE\n'
  printf 'END\n'; } > "$W"
ORA="$( cd "$T" && timeout -k 5 30s "$O" -bf lastno_plain.sno </dev/null 2>/dev/null )"; orc=$?
case "$ORA" in *lastno1=*) : ;; *) echo "GATE UNPROVEN(2) [$GATE_NAME]: oracle produced no lastno1= line (rc=$orc)"; exit 2;; esac
M3="$( cd "$T" && timeout -k 5 30s "$ROOT/scrip" --stlimit lastno_plain.sno </dev/null 2>/dev/null )"
C3="$( cd "$T" && timeout -k 5 30s "$ROOT/scrip" lastno_plain.sno </dev/null 2>/dev/null )"
( cd "$T" && timeout -k 5 30s "$ROOT/scrip" --compile --stlimit -o lastno_plain.s lastno_plain.sno </dev/null >/dev/null 2>&1 ) \
  || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mode-4 compile failed"; exit 2; }
( cd "$T" && gcc -no-pie lastno_plain.s -o lastno_plain.bin -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
  || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mode-4 link failed"; exit 2; }
M4="$( cd "$T" && timeout -k 5 30s ./lastno_plain.bin </dev/null 2>/dev/null )"
red=0; examined=0
for tag in m3 m4; do
    eval "got=\$$(echo "$tag" | tr 'a-z' 'A-Z')"
    examined=$((examined+1))
    if [ "$got" = "$ORA" ]; then echo "PASS $tag: $got (oracle: $ORA)"
    else echo "RED  $tag: got [$got] oracle [$ORA]"; red=$((red+1)); fi
done
examined=$((examined+1))
if [ "$C3" != "$ORA" ]; then echo "PASS control m3 without --stlimit: $C3 differs from the oracle -- the switch supplies the keywords"
else echo "RED  control m3 without --stlimit EQUALS the oracle -- either the default build infers instrumentation from the source (ruled out) or the witness grades nothing"; red=$((red+1)); fi
gate_floor "$examined" 3 "arms graded"
gate_verdict "$red" "mode(s) whose &LASTNO/&LASTLINE do not advance across plain statements with no call between them"
