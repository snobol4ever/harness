#!/usr/bin/env bash
export SCRIP_DIAG=0   # benchmarks run with every diagnostic off (Lon 2026-09-25, ceo CEO-1262)
# bench_icon_ir_bar.sh -- THE ICON IR BAR (ceo CEO-1777; Lon 2026-10-15 10:5x, in-chat to the ceo, verbatim: "We can have HQ-ICON work calgrind and
# optimize based on instruction count."): the load-invariant twin of bench_icon_bar.sh. ONE kernel under corpus/benchmarks/icon is run ONCE under
# callgrind in Arizona iconx 9.5.25a and ONCE in SCRIP mode 4, each Ir total read through lib_ir_measure.sh, and the bare multiple is printed
# through lib_perf_fmt.sh: iconx Ir / SCRIP Ir (the FACT RULE's unit, reference over ours -- 2.00x is half the instructions, 0.50x is twice them).
# Instruction counts do not move with the box's load, so this bar reads on a busy machine and needs no load guard; it is the working instrument of
# the Icon speed rows and the published multiples stay bench_icon_bar.sh's three-angle time bars (the two-number basis).
#   kernel K BAR   K is the kernel's file stem under the Icon benchmark tree (rate/ excluded; the stem must be unique). The kernel runs AS SHIPPED
#                  (not the harness's iterating wrapper), on its own stdin sidecar (NAME.in, else NAME.stdin, else NAME.dat) and NAME.argv; SCRIP at
#                  the heap and stack NAME.heap and NAME.stack declare (-d<kb>k -s<kb>k leading the binary's argv, never SCRIP_HEAP_KB, the window),
#                  iconx in the environment NAME.oracle_env declares. SCRIP builds with `--compile` and a default (PIE) gcc link against out/libscrip_rt.so.
#   demo jtran BAR the JCON translator (17 modules, corpus/demos/icon/jcon/jtran.icn) built by icont and by SCRIP mode 4, its preprocessor stage on JCON's
#                  own gen_bc.icn to stdout (the workload bench_icon_bar.sh demo jtran times), one callgrind run each, outputs byte-compared; the same multiple.
#   --list         names every kernel and runs nothing.
# EXIT 0 at or above the bar (GREEN), 1 below it (RED, the row is open), 2 REFUSED: no binary, no oracle, no valgrind, an unknown or ambiguous kernel,
#   a kernel with no .ref, a build that fails, or a run that dies, times out or prints anything but the .ref (ir_measure voids a dead run; the .ref
#   cmp voids a wrong answer -- an Ir count of a program that did not do the work is not a measurement).
# ENV   IR_TMO seconds per callgrind run (default 1200)   ICON_BENCH_DIR the kernel tree   SCRIP the scrip binary
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"; SCRIP="${SCRIP:-$ROOT/scrip}"; RT="$ROOT/out"; BD="${ICON_BENCH_DIR:-$S4E/corpus/benchmarks/icon}"
refuse() { echo "⛔ bench_icon_ir_bar REFUSE(2): $*"; exit 2; }
for L in lib_perf_fmt lib_ir_measure lib_oracle_flags lib_icon_ipl_isolation lib_declared_arena; do . "$HERE/$L.sh" 2>/dev/null || refuse "cannot load $L.sh -- the ONE authority for its job, never a private copy"; done
kernels() { find "$BD" -name '*.icn' ! -path '*/rate/*' | LC_ALL=C sort | while IFS= read -r f; do grep -q '^[[:space:]]*procedure[[:space:]]\+main' "$f" && echo "$f"; done; }
if [ "${1:-}" = --list ]; then kernels | while IFS= read -r f; do printf '%s\t%s\n' "$(basename "$f" .icn)" "${f#"$BD"/}"; done; exit 0; fi
[ $# -eq 3 ] && { [ "$1" = kernel ] || [ "$1" = demo ]; } || { echo "usage: $0 kernel <stem> <bar> | demo jtran <bar> | --list"; exit 2; }
KIND=$1; NAME=$2; BAR=$3
case "$BAR" in ''|*[!0-9.]*|*.*.*) refuse "the bar '$BAR' is not a number";; esac
[ -x "$SCRIP" ] || refuse "no scrip at $SCRIP (make first)"
[ -r "$RT/libscrip_rt.so" ] || refuse "no $RT/libscrip_rt.so (make first)"
ICONT="$(icont_bin)" || refuse "no icont oracle"; ICONX="$(iconx_bin)" || refuse "no iconx oracle"
ir_have_valgrind || refuse "callgrind and callgrind_annotate are required (valgrind is absent)"
if [ "$KIND" = demo ]; then
  [ "$NAME" = jtran ] || refuse "the only demo this bar knows is jtran"
  PKG="$S4E/corpus/packages/icon/jcon-compiler"; D="$S4E/corpus/demos/icon/jcon"; T="$(mktemp -d "${TMPDIR:-/tmp}/icnirbar.XXXXXX")" || refuse "mktemp"; trap 'rm -rf "$T"' EXIT
  export IR_TMO="${IR_TMO:-1800}"
  MODS=$(sed -n 's/^[[:space:]]*link[[:space:]]*"\([^"]*\)".*$/\1/p' "$D/jtran.icn" | sed 's|.*/||' | sed "s|^|$PKG/|; s|$|.icn|" | tr '\n' ' ')
  ( cd "$T" && "$ICONT" -s -o "$T/jtran.oracle" $MODS ) > "$T/icont.log" 2>&1 || { tail -3 "$T/icont.log"; refuse "icont did not build the jtran oracle"; }
  ( cd "$D" && "$SCRIP" --compile -o "$T/jtran.s" jtran.icn < /dev/null && gcc -o "$T/jtran.m4" "$T/jtran.s" -L"$RT" -lscrip_rt -lm -lpthread -Wl,-rpath,"$RT" ) > "$T/m4.log" 2>&1 || { grep -v 'TEXTREL\|read-only section' "$T/m4.log" | tail -3; refuse "jtran did not build in mode 4"; }
  cp "$PKG/gen_bc.icn" "$T/gen_bc.icn"
  IX="$( cd "$T" && IR_PROG_OUT="$T/ix.out" IR_PROG_ERR="$T/ix.err" ir_measure "$ICONX" "$T/jtran.oracle" preproc "$T/gen_bc.icn" : stdout < /dev/null )"
  ir_is_number "$IX" || refuse "jtran under iconx: $(ir_cell "$IX") -- $(ir_reason "$IX")"
  [ -s "$T/ix.out" ] || refuse "the iconx jtran printed nothing"
  M4="$( cd "$T" && unset SCRIP_HEAP_KB SCRIP_HEAP_MB && IR_VG_FLAGS=--smc-check=all-non-file IR_PROG_OUT="$T/m4.out" IR_PROG_ERR="$T/m4.err" ir_measure "$T/jtran.m4" preproc "$T/gen_bc.icn" : stdout < /dev/null )"
  ir_is_number "$M4" || { tail -3 "$T/m4.err" 2>/dev/null; refuse "jtran under SCRIP mode 4: $(ir_cell "$M4") -- $(ir_reason "$M4")"; }
  cmp -s "$T/ix.out" "$T/m4.out" || refuse "jtran preproc: mode-4 output differs from iconx's (an Ir count of a wrong answer is not a measurement)"
  X="$(perf_mult "$IX" "$M4" "jtran Ir")" || exit 2; X="${X%% *}"
  awk -v ix="$IX" -v m4="$M4" -v bar="$BAR" 'BEGIN{exit !(ix/m4 >= bar)}'; RC=$?
  printf 'demo jtran (preproc gen_bc.icn): iconx %s Ir, m4 %s Ir (callgrind, no clock); reads %s iconx by instruction count in mode 4 (bar %.2fx): %s · %s\n' "$IX" "$M4" "$X" "$BAR" "$([ "$RC" = 0 ] && echo GREEN || echo RED)" "$(perf_build_stamp)"
  exit "$RC"
fi
mapfile -t HIT < <(kernels | awk -v n="$NAME" '{b=$0; sub(/.*\//,"",b); sub(/\.icn$/,"",b); if (b==n) print}')
[ "${#HIT[@]}" -eq 1 ] || refuse "kernel '$NAME' matches ${#HIT[@]} kernels under $BD (--list names them)"
K="${HIT[0]}"; KD="$(dirname "$K")"; B="${K%.icn}"; REF="$B.ref"
[ -s "$REF" ] || refuse "$NAME has no .ref: a kernel with no expected output is vacuous"
IN=/dev/null; for X in in stdin dat; do [ -f "$B.$X" ] && { IN="$B.$X"; break; }; done
SW="$(declared_switches_beside "$K")" || refuse "$NAME: a malformed .heap or .stack sidecar (the reader said why above)"
declare -a SWA=(); [ -n "$SW" ] && read -r -a SWA <<<"$SW"
OE="$(declared_oracle_env_beside "$K")" || refuse "$NAME: a malformed .oracle_env sidecar (the reader said why above)"
declare -a OENV=(); [ -n "$OE" ] && read -r -a OENV <<<"$OE"
declare -a AV=(); if [ -f "$B.argv" ]; then ipl_argv_read "$K" AV || refuse "$NAME: a malformed .argv sidecar"; fi
T="$(mktemp -d "${TMPDIR:-/tmp}/icnirbar.XXXXXX")" || refuse "mktemp"; trap 'rm -rf "$T"' EXIT
export IR_TMO="${IR_TMO:-1200}"
cp "$K" "$T/$NAME.icn"
( cd "$T" && "$ICONT" -s -o w.x "$NAME.icn" ) > "$T/icont.log" 2>&1 || { tail -3 "$T/icont.log"; refuse "$NAME did not build under icont"; }
( cd "$T" && "$SCRIP" --compile -o w.s "$NAME.icn" < /dev/null && gcc -o w4 w.s -L"$RT" -lscrip_rt -lm -lpthread -Wl,-rpath,"$RT" ) > "$T/m4.log" 2>&1 || { grep -v 'TEXTREL\|read-only section' "$T/m4.log" | tail -3; refuse "$NAME did not build in mode 4"; }
declare -a M4CMD=("$T/w4" ${SWA[@]+"${SWA[@]}"}); [ "${#AV[@]}" -gt 0 ] && { [ "${#SWA[@]}" -gt 0 ] && M4CMD+=(--); M4CMD+=("${AV[@]}"); }
# one reading per engine, each from a subshell in the kernel's own directory; the status rides in the value (lib_ir_measure.sh), never in a global
IX="$( cd "$KD" && { [ "${#OENV[@]}" -gt 0 ] && export "${OENV[@]}"; IR_PROG_OUT="$T/ix.out" IR_PROG_ERR="$T/ix.err" ir_measure "$ICONX" "$T/w.x" ${AV[@]+"${AV[@]}"} < "$IN"; } )"
ir_is_number "$IX" || refuse "$NAME under iconx: $(ir_cell "$IX") -- $(ir_reason "$IX")"
cmp -s "$T/ix.out" "$REF" || refuse "$NAME: iconx's output is not the .ref (the oracle and the ref disagree; no multiple over an unmatched answer)"
M4="$( cd "$KD" && unset SCRIP_HEAP_KB SCRIP_HEAP_MB && IR_VG_FLAGS=--smc-check=all-non-file IR_PROG_OUT="$T/m4.out" IR_PROG_ERR="$T/m4.err" ir_measure "${M4CMD[@]}" < "$IN" )"
ir_is_number "$M4" || { tail -3 "$T/m4.err" 2>/dev/null; refuse "$NAME under SCRIP mode 4: $(ir_cell "$M4") -- $(ir_reason "$M4")"; }
cmp -s "$T/m4.out" "$REF" || refuse "$NAME: SCRIP mode 4's output is not the .ref (an Ir count of a wrong answer is not a measurement)"
X="$(perf_mult "$IX" "$M4" "$NAME Ir")" || exit 2; X="${X%% *}"
awk -v ix="$IX" -v m4="$M4" -v bar="$BAR" 'BEGIN{exit !(ix/m4 >= bar)}'; RC=$?
printf 'kernel %s: iconx %s Ir, m4 %s Ir (callgrind, no clock); reads %s iconx by instruction count in mode 4 (bar %.2fx): %s · %s\n' "$NAME" "$IX" "$M4" "$X" "$BAR" "$([ "$RC" = 0 ] && echo GREEN || echo RED)" "$(perf_build_stamp)"
exit "$RC"
