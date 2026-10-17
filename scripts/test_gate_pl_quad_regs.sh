#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_pl_quad_regs.sh -- THE QUAD GATE: no r12-r15 write reachable from a Prolog graph outside the TR/B/ROOT/BALL helpers,
# in emitted mode-4 .s and in the rtx asm it reaches (ARCH-PROLOG-BYRD-BOX-TRANSLATION.md § E instrument lane; RULES.md § THE
# PROLOG REBUILD GATE clause 5 -- the instrument lane never touches src/; minted by hq_P 2026-09-02, row
# prolog-quad-gate-no-r12-r15-write-outside-tr-b-root-ball).  Lon's grant: r12 = TR (the trail), r13 = B (youngest live choice
# frame), r14 = ROOT (the ζ-STANDING record), r15 = the ball or 0 -- live for the whole run.  The analysis is pl_quad_regs_scan.py
# (read its header: the enrolment table IS the contract; a rung that adds a legitimate B/TR/BALL writer enrols ONE shape there).
# POPULATION: every origin `ladder__rungNN_*` of corpus/tests/prolog/ALL.csv (all rungs, or --to N) and every `probe_plz` origin,
# materialised out of the rungs by lib_rungs_extract.sh, PLUS every .pl under corpus/demos/prolog and corpus/benchmarks/prolog
# (recursive: bench/, vanroy/, src/swi-*, the preludes).  Each is compiled to
# mode-4 TEXT (`scrip --compile -o`).  During the rebuild most corpus programs REFUSE with "not on the ladder yet -- rung N lands
# it"; those are COUNTED and printed, never graded and never green.  A witness that compiles is graded; zero compiled witnesses
# is UNPROVEN rc=2.  ⛔ Only mode-4 TEXT is read (MODES MAY DIVERGE: the verdict names its mode and does not bind mode 3).
# FAIL-ONCE IS BUILT IN, EVERY RUN, BEFORE THE REAL RUN IS TRUSTED (INSTRUMENT LAWS; a guard and its canary must not share a
# failure mode): (c1) the first compiled witness with `mov r13, rax` injected inside its first box must scan RED; (c2) a synthetic
# rtx routine that writes r14, reached by an injected `call`, must scan RED; (c3) the scanner with no input must REFUSE rc=2.
# A canary that does not turn red makes the gate UNPROVEN(2) -- a scanner that cannot say no certifies nothing.
# SUPERSEDES the label-allow-list version this seat minted at 4253dd88 (born red, QUAD_HELPER_RX over emitted LABELS, opt-in
# --self-test, not in make test): at rung 0 that design could go green only by naming `main`/`main_α` -- which admits ANY write
# under those labels -- and its ASCII-only awk did not follow the Greek-lettered rtx routines (rt_gen_spine_pass_γ/ω) in the
# reachability arm.  What survives: QUAD_HELPER_RX is still honoured, now as the rtx ROUTINE-name allow-list (the rung-1 brief's
# wording; a whole asm routine whose job is the trail IS the helper); emitted-code enrolment is a (site, register, shape) row.
# MEASURED at mint (SCRIP db299d41 / corpus 9c6489879, the rung-0 tree): ladder=12 probe_plz=9 corpus=145 -> compiled=1 (rung 0 hello),
# refused(not-on-the-ladder-yet)=163, other-compile-fail=2 (a parse error in the two swi det.pl copies, the ladder runner's
# business); writes=5, all five ROOT seeds (driver `mov r12,[0x70000000]` + `xor r14d,r14d`; root-α
# `xor r13d,r13d` `xor r15d,r15d` `lea r14,[rsp+64]`); rtx reachable=3 (rt_gen_spine_pass_γ/ω, rt_gen_spine_resume_enter),
# rtx writes=0.  The tree-wide informational sweep (`--rtx-scan-all`) finds the ONLY r12-r15 writers in all 47 rtx routines are
# three push/pop-bracketed scratch uses of r12 in rt_match_replace (SNOBOL4), preserved for the caller.
# EXIT: 0 clean · 1 a violation · 2 UNPROVEN (cannot measure: no binary, no rungs, zero compiled witnesses, a canary not red).
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT"
. "$HERE/lib_gate.sh"
TO=""; ARGS=(); while [ $# -gt 0 ]; do case "$1" in --to) TO="${2:-}"; shift 2;; --to=*) TO="${1#--to=}"; shift;; *) ARGS+=("$1"); shift;; esac; done; set -- "${ARGS[@]+"${ARGS[@]}"}"
case "$TO" in ""|*[!0-9]*) [ -z "$TO" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: --to wants a rung number, got '$TO'"; gate_stamp; exit 2; };; esac
gate_parse_args "$@"
SCRIP="${SCRIP:-$ROOT/scrip}"; RT="${RT_DIR:-$ROOT/out}"; T="${TIMEOUT:-20}"; SCAN="$HERE/pl_quad_regs_scan.py"; RTX="$ROOT/src/runtime/rtx"
RUNGS_DIR="$S4E/corpus/tests/prolog"; RUNGS_EXT=.pl; export RUNGS_DIR RUNGS_EXT
gate_require_exec "$SCRIP" "scrip binary"
gate_require "$RT/libscrip_rt.so" "runtime library"
gate_require "$SCAN" "scanner pl_quad_regs_scan.py"
gate_require "$RTX/rtx_abi.inc" "rtx asm tree"
gate_require "$RUNGS_DIR/ALL.pl" "Prolog rungs suite"
gate_require "$RUNGS_DIR/ALL.csv" "Prolog rungs suite index"
command -v python3 >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: python3 not found"; gate_stamp; exit 2; }
. "$HERE/lib_rungs_extract.sh" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot source lib_rungs_extract.sh"; gate_stamp; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT; mkdir -p "$W/src" "$W/s" "$W/rtx"
origins=$(rungs_origins_of_family ladder 2>/dev/null) || origins=""
[ -n "$origins" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: no ladder origins in $RUNGS_DIR/ALL.csv -- the witnesses moved; re-point, never skip"; gate_stamp; exit 2; }
plz=$(rungs_origins_of_family probe_plz 2>/dev/null) || plz=""
nl=0; np=0; declare -a srcs=()
for o in $(printf '%s\n' $origins | sort); do
  nn=$(printf '%s\n' "$o" | sed -nE 's/^ladder__rung0*([0-9]+)_.*/\1/p'); [ -n "$nn" ] || continue
  [ -z "$TO" ] || [ "$nn" -le "$TO" ] || continue
  rungs_extract_origin "$o" "$W/src/$o.pl" "$W/src/$o.ref" >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot extract $o from the rungs suite"; gate_stamp; exit 2; }
  srcs+=("$W/src/$o.pl"); nl=$((nl+1))
done
for o in $(printf '%s\n' $plz | sort); do
  rungs_extract_origin "$o" "$W/src/$o.pl" "$W/src/$o.ref" >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$GATE_NAME]: cannot extract $o from the rungs suite"; gate_stamp; exit 2; }
  srcs+=("$W/src/$o.pl"); np=$((np+1))
done
nc=0
for f in $(find "$S4E/corpus/demos/prolog" "$S4E/corpus/benchmarks/prolog" -name '*.pl' 2>/dev/null | sort); do srcs+=("$f"); nc=$((nc+1)); done
[ "${#srcs[@]}" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: zero .pl sources (ladder=$nl probe_plz=$np corpus=$nc)"; gate_stamp; exit 2; }
compiled=0; refused=0; other=0; : > "$W/refused.txt"; : > "$W/other.txt"
for f in "${srcs[@]}"; do
  b=$(printf '%s' "$f" | sed 's#^.*/corpus/##; s#^.*/src/##' | tr '/' '_')
  if timeout -k 5 "$T" "$SCRIP" --compile -o "$W/s/$b.s" "$f" </dev/null >/dev/null 2>"$W/s/$b.err" && [ -s "$W/s/$b.s" ]; then compiled=$((compiled+1))
  else rm -f "$W/s/$b.s"
    if grep -q 'not on the ladder yet' "$W/s/$b.err" 2>/dev/null; then refused=$((refused+1)); printf '%s: %s\n' "$b" "$(head -1 "$W/s/$b.err" | cut -c1-110)" >> "$W/refused.txt"
    else other=$((other+1)); printf '%s: %s\n' "$b" "$(head -1 "$W/s/$b.err" | cut -c1-110)" >> "$W/other.txt"; fi
  fi
done
echo "population: ladder=$nl probe_plz=$np corpus=$nc -> compiled=$compiled refused(not-on-the-ladder-yet)=$refused other-compile-fail=$other  (mode-4 TEXT; refusals are counted, never graded)"
[ "$other" -eq 0 ] || { echo "  other compile failures (informational -- this gate grades register writes, not compilation; the ladder runner owns these):"; sed 's/^/    /' "$W/other.txt" | head -10; }
[ "$compiled" -gt 0 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: zero witnesses compiled (refused=$refused other=$other) -- nothing to examine"; gate_stamp; exit 2; }
first=$(ls "$W"/s/*.s | head -1)
# --- (c1) injected scratch write inside a box must be RED ---
awk 'BEGIN{d=0} {print} d==0 && /^n[0-9]+_[^:]*_α:/{print "                        mov              r13, rax"; d=1}' "$first" > "$W/canary1.s"
grep -q 'mov              r13, rax' "$W/canary1.s" || { echo "GATE UNPROVEN(2) [$GATE_NAME]: canary c1 could not be injected (no nN_*_α: label in $(basename "$first"))"; gate_stamp; exit 2; }
python3 "$SCAN" "$W/canary1.s" > "$W/c1.out" 2>&1; c1=$?
{ [ "$c1" -eq 1 ] && grep -q '^VIOLATION.*r13(B)' "$W/c1.out"; } || { echo "GATE UNPROVEN(2) [$GATE_NAME]: canary c1 (injected mov r13,rax in a box) did NOT turn the scanner red (rc=$c1) -- a scanner that cannot say no certifies nothing"; sed 's/^/    /' "$W/c1.out" | tail -4; gate_stamp; exit 2; }
# --- (c2) a reachable rtx routine writing r14 must be RED ---
printf '#include "rtx_abi.inc"\nRTX_FUNC(rt_quad_canary_helper)\n    mov     r14, rax\n    ret\nRTX_ENDF(rt_quad_canary_helper)\n' > "$W/rtx/rtx_canary.s"
{ cat "$first"; printf '                        call             rt_quad_canary_helper@PLT\n'; } > "$W/canary2.s"
python3 "$SCAN" --rtx-dir "$W/rtx" "$W/canary2.s" > "$W/c2.out" 2>&1; c2=$?
{ [ "$c2" -eq 1 ] && grep -q '^VIOLATION.*rtx=rt_quad_canary_helper' "$W/c2.out"; } || { echo "GATE UNPROVEN(2) [$GATE_NAME]: canary c2 (rtx routine writing r14, reached by call) did NOT turn the scanner red (rc=$c2)"; sed 's/^/    /' "$W/c2.out" | tail -4; gate_stamp; exit 2; }
# --- (c3) no input must REFUSE ---
python3 "$SCAN" >/dev/null 2>&1; c3=$?
[ "$c3" -eq 2 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: canary c3 (scanner with no input) exited $c3, not 2 -- an instrument that cannot measure must refuse"; gate_stamp; exit 2; }
echo "canaries: c1 injected-scratch-write RED ok · c2 reachable-rtx-write RED ok · c3 empty-input REFUSE(2) ok"
# --- the real run ---
[ -z "${QUAD_HELPER_RX:-}" ] || echo "QUAD_HELPER_RX='$QUAD_HELPER_RX' (rtx routine names enrolled as the TR helper)"
python3 "$SCAN" --rtx-dir "$RTX" "$W"/s/*.s > "$W/scan.out" 2>&1; rc=$?
cat "$W/scan.out"
sum=$(grep '^quad-scan:' "$W/scan.out" | tail -1)
[ -n "$sum" ] && [ "$rc" -ne 2 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the scanner did not produce a summary (rc=$rc)"; gate_stamp; exit 2; }
v1=$(printf '%s' "$sum" | sed -nE 's/.* violations=([0-9]+) .*/\1/p'); v2=$(printf '%s' "$sum" | sed -nE 's/.*rtx-violations=([0-9]+).*/\1/p')
bad=$(( ${v1:-0} + ${v2:-0} ))
GATE_EXAMINED="$compiled"; gate_verdict "$bad" "unenrolled r12-r15 writes (mode-4 TEXT + reachable rtx; compiled witnesses=$compiled)"
