#!/usr/bin/env bash
export SCRIP_SNO_STMTKW=1   # this grader asks for the SNOBOL4 statement instrumentation (the --stlimit switch; Lon 2026-09-24 16:0x: the feature is off by default and never inferred from the source, the correctness graders turn it on because the oracle always has it)
# test_gate_sno_proc_own_name_byname_mid_return.sh -- a DEFINE'd proc's own name reads BLANK through an
# external by-name ($NAME) lookup while that proc is in the middle of returning.
#
# Row: defined-proc-own-name-blank-via-byname-lookup-mid-return (hq_U). Witness minted and oracle-verified by
# seat11 2026-09-05; this gate is the runnable criterion for it (the row carried the placeholder DONE-WHEN and
# was therefore UNPICKABLE -- ceo census 19:02).
#
# ⛔ WHAT THIS IS NOT (seat11 ruled these out; do not re-derive them):
#   - NOT the retval threaded through rt_trace_return_hook: rt_trace_event's registered-callback branch never
#     reads its own value parameter, so that plumbing is correct but INERT here.
#   - NOT an RTCC_GLOBAL_R9_GVA vs absolute-addressing split: an ordinary global's own by-name read through the
#     identical NAMEVAL path, in the identical callback, resolves correctly.
#   F differs only in being the name of the procedure CURRENTLY ACTIVE/returning at the instant of the lookup.
#
# TRACE is the INSTRUMENT here, not the subject: it is currently the only way to run code at the exact instant
# of a return before it completes. A cure is a symbol-resolution fix, not a TRACE fix.
#
# Graded in BOTH modes against /home/resources/x64/bin/sbl -bf. rc=0 both match, rc=1 either diverges,
# rc=2 could not measure (no oracle, no binary, build/link failure, zero programs graded).
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
W="$T/ownname.sno"
{ printf '        &TRACE = 10\n'
  printf '        DEFINE("TF(NAME,TAG)")\n'
  printf '        DEFINE("F(X)")                          :(START)\n'
  printf 'TF      OUTPUT = TAG " " NAME " = " $NAME       :(RETURN)\n'
  printf 'F       F = X                                   :(RETURN)\n'
  printf 'START   TRACE("F","RETURN","tagR",.TF)\n'
  printf '        N = F(2)\n'
  printf 'END\n'; } > "$W"
V="$T/retval.sno"
# ⛔ THE SECOND WITNESS IS THE DISCRIMINATOR, AND IT IS THE REASON THIS GATE EXISTS IN THIS SHAPE.
# The first witness grades the TARGET (the by-name mid-return read). It is satisfiable by a cure that
# moves the return-value staging earlier and clobbers the ordinary return path on the way -- which is
# exactly what d067ceae4 did: this gate read PASS while every DEFINE'd function returned blank, and the
# landing was reverted fleet-wide (CEO-333). A DONE-WHEN that names one output line cannot notice what
# the cure spent to get it. So the plain return value is graded here too, in both modes, against the
# same oracle: a cure that buys the tagR line by breaking ordinary returns now reds its own gate.
{ printf '        DEFINE("G(X)")                          :(GEND)\n'
  printf 'G       G = 7                                   :(RETURN)\n'
  printf 'GEND\n'
  printf '        OUTPUT = G("ignored")\n'
  printf '        OUTPUT = "tail"\n'
  printf 'END\n'; } > "$V"
ORA="$( cd "$T" && timeout -k 5 30s "$O" -bf ownname.sno </dev/null 2>/dev/null )"; orc=$?
case "$ORA" in *tagR*) : ;; *) echo "GATE UNPROVEN(2) [$GATE_NAME]: oracle produced no tagR line (rc=$orc)"; exit 2;; esac
ORB="$( cd "$T" && timeout -k 5 30s "$O" -bf retval.sno </dev/null 2>/dev/null )"; brc=$?
case "$ORB" in *7*) : ;; *) echo "GATE UNPROVEN(2) [$GATE_NAME]: oracle produced no return value for the discriminator (rc=$brc)"; exit 2;; esac
M3="$( cd "$T" && timeout -k 5 30s "$ROOT/scrip" ownname.sno </dev/null 2>/dev/null )"
B3="$( cd "$T" && timeout -k 5 30s "$ROOT/scrip" retval.sno </dev/null 2>/dev/null )"
for src in ownname retval; do
    ( cd "$T" && timeout -k 5 30s "$ROOT/scrip" --compile -o $src.s $src.sno </dev/null >/dev/null 2>&1 ) \
      || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mode-4 compile failed ($src)"; exit 2; }
    ( cd "$T" && gcc -no-pie $src.s -o $src.bin -L"$ROOT/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/out" >/dev/null 2>&1 ) \
      || { echo "GATE UNPROVEN(2) [$GATE_NAME]: mode-4 link failed ($src)"; exit 2; }
done
M4="$( cd "$T" && timeout -k 5 30s ./ownname.bin </dev/null 2>/dev/null )"
B4="$( cd "$T" && timeout -k 5 30s ./retval.bin </dev/null 2>/dev/null )"
red=0; examined=0
grade() {
    examined=$((examined+1))
    if [ "$2" = "$3" ]; then echo "PASS $1: [$2]"
    else echo "RED  $1: got [$2] oracle [$3]"; red=$((red+1)); fi
}
grade "m3 byname-mid-return" "$M3" "$ORA"
grade "m4 byname-mid-return" "$M4" "$ORA"
grade "m3 ordinary-return-value(discriminator)" "$B3" "$ORB"
grade "m4 ordinary-return-value(discriminator)" "$B4" "$ORB"
gate_floor "$examined" 4 "witness/mode pairs graded"
gate_verdict "$red" "witness/mode pair(s) where a returning proc diverges from the oracle (target: own name via by-name lookup; discriminator: the ordinary return value)"
