#!/usr/bin/env bash
# test_gate_sno_errtype_and_errtext_are_set_before_a_fatal_error_exits.sh -- core_runtime_error's fatal path (the
# terminal/fatal/default exit(1) arms in src/runtime/core/core.c) printed SCRIP's own error voice and exited
# WITHOUT ever calling rt_kw_publish_error, so &ERRTYPE and &ERRTEXT still read 0 and '' at the moment of exit --
# only the two SURVIVABLE branches (SETEXIT and the errlimit-survives arm) called it. This is invisible for most
# fatal errors because nothing runs after them, but a program with &DUMP=2 active gets its keyword-value dump
# printed by the atexit hook (rt_dump_atexit_arm/var_dump_at_exit) AFTER the fatal error, and that dump names
# &ERRTYPE/&ERRTEXT -- which then lied about the very error that just killed the program.
#
# hq_snobol4, found bisecting spitbol_testpgms test6/test7 (error 248, attempted redefinition of a system function
# via DATA, which IS genuinely fatal in real SPITBOL by default -- confirmed in isolation, not a control-flow bug)
# against sbl -bf's own crash-time dump: every field but &ERRTYPE/&ERRTEXT already matched.
#
# THE WITNESS: DATA() redefines a system function name (error 248, unconditionally fatal, no SETEXIT/ERRLIMIT in
# the witness) with &DUMP=2 set first, so the atexit dump's keyword section is reachable and readable. Graded in
# BOTH modes against sbl -bf's own dump lines for &ERRTYPE and &ERRTEXT.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
GATE_NAME="$(basename "${BASH_SOURCE[0]}" .sh)"
. "$HERE/lib_oracle_flags.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_oracle_flags.sh unavailable"; exit 2; }
. "$HERE/lib_gate.sh"          || { echo "GATE UNPROVEN(2) [$GATE_NAME]: lib_gate.sh unavailable"; exit 2; }
gate_parse_args "$@"
O="$(sbl_correctness_bin)" || exit 2
gate_require_exec "$ROOT/scrip" "the scrip binary"
gate_require_fresh "$ROOT" src "$ROOT/scrip" "$ROOT/out/libscrip_rt.so"
T="$(mktemp -d)" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mktemp failed"; exit 2; }
trap 'rm -rf "$T"' EXIT
W="$T/errtype_fatal.sno"
{ printf '        &DUMP = 2\n'
  printf '        DATA("SIZE(X)")\n'
  printf 'END\n'; } > "$W"
ORA="$( cd "$T" && timeout -k 5 30s "$O" -bf errtype_fatal.sno </dev/null 2>/dev/null )"; orc=$?
ORA_ERRTYPE="$(printf '%s\n' "$ORA" | grep -m1 '^&ERRTYPE = ')"
ORA_ERRTEXT="$(printf '%s\n' "$ORA" | grep -m1 '^&ERRTEXT = ')"
[ -n "$ORA_ERRTYPE" ] && [ -n "$ORA_ERRTEXT" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: oracle produced no &ERRTYPE/&ERRTEXT dump line (rc=$orc) -- witness moved, re-measure"; exit 2; }
case "$ORA_ERRTYPE" in "&ERRTYPE = 0") echo "GATE UNPROVEN(2) [$GATE_NAME]: oracle's own &ERRTYPE reads 0 -- witness no longer raises a real error"; exit 2;; esac
M3="$( cd "$T" && timeout -k 5 30s "$ROOT/scrip" errtype_fatal.sno </dev/null 2>/dev/null )"
( cd "$T" && timeout -k 5 30s "$ROOT/scrip" --compile --out=errtype_fatal.s errtype_fatal.sno </dev/null >/dev/null 2>&1 ) \
  || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mode-4 compile failed"; exit 2; }
( cd "$T" && gcc -no-pie errtype_fatal.s -o errtype_fatal.bin -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
  || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mode-4 link failed"; exit 2; }
M4="$( cd "$T" && timeout -k 5 30s ./errtype_fatal.bin </dev/null 2>/dev/null )"
red=0; examined=0
for tag in m3 m4; do
    eval "got=\$$(echo "$tag" | tr 'a-z' 'A-Z')"
    examined=$((examined+1))
    got_errtype="$(printf '%s\n' "$got" | grep -m1 '^&ERRTYPE = ')"
    got_errtext="$(printf '%s\n' "$got" | grep -m1 '^&ERRTEXT = ')"
    if [ "$got_errtype" = "$ORA_ERRTYPE" ] && [ "$got_errtext" = "$ORA_ERRTEXT" ]; then
        echo "PASS $tag: $got_errtype / $got_errtext"
    else
        echo "RED  $tag: want [$ORA_ERRTYPE / $ORA_ERRTEXT] got [$got_errtype / $got_errtext]"; red=$((red+1))
    fi
done
# ⛔ THE CAP ARM (the cfo's bisect of 572981e49, 2026-09-27): the first cut published &ERRTEXT on the fatal arms with rt_kw_publish_error,
# which copies the text onto the GC heap. When the fatal error IS the heap at its hard cap (Icon 307, SNOBOL4 204), that copy asks the
# full heap for more, raises the same error again, and recursed 3904 times into ERROR 246 with 4.9 MB of stderr -- in every frontend,
# since core_runtime_error is shared. The fatal arms now publish without a copy (rt_kw_publish_error_at_exit, kwb_error's own shape);
# nothing runs after them but the atexit dump. The cfo's witness fills an 8 MB cap with small blocks: 307 exactly once, no 246.
mkdir -p "$T/cap"; printf 'procedure main()\n   local i, L;\n   L := [];\n   every i := 1 to 400000 do put(L, [i, i+1, i+2]);\n   write("done ", *L);\nend\n' > "$T/cap/grow.icn"
( cd "$T/cap" && SCRIP_HEAP_KB=128 SCRIP_HEAP_MB=8 SCRIP_HEAP_MAX_MB=8 timeout -k 5 120 "$ROOT/scrip" grow.icn > out 2> err ); crc=$?
n307="$(grep -c 'error 307' "$T/cap/err")"; n246="$(grep -c 'error 246' "$T/cap/err")"
examined=$((examined+1))
if [ "$crc" = 1 ] && [ "$n307" = 1 ] && [ "$n246" = 0 ]; then echo "PASS cap: a heap-full fatal error is reported once (307 x1, 246 x0, rc 1)"
else echo "RED  cap: rc=$crc, error 307 x$n307, error 246 x$n246, stderr $(wc -c < "$T/cap/err") bytes -- publishing the error must not allocate on a full heap"; red=$((red+1)); fi
gate_floor "$examined" 3 "arms graded (two modes and the cap arm)"
gate_verdict "$red" "arm(s) red: &ERRTYPE/&ERRTEXT against the oracle's crash-time dump, or a heap-full fatal error that recurses"
