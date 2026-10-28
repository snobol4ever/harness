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
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
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
# ⭐ PARALLEL (hq_prolog 2026-10-28, row prolog-gate-quad-regs-does-not-finish-in-400-seconds-at-head-ceo-1663): the population is every rung, demo and benchmark program (about 750 now that they compile,
# each emitting ~15 MB of prelude-heavy asm); one compile at a time and one scanner over all of it took more than 900 s unloaded and never reached its verdict. Each program is compiled by its own
# worker (QUAD_JOBS, default 6) and each worker prints ONE result line; the counts below are read from those lines, so the verdict is the sequential gate's, only sooner.
# every worker holds ONE box-wide run slot for its job (CEO-1894: harness children go through S4E_RUN_SLOTS, default 8, slots under /tmp/s4e-run-slots; the kernel frees the lock when the worker exits)
quad_slot() { local n="${S4E_RUN_SLOTS:-8}" i; mkdir -p /tmp/s4e-run-slots 2>/dev/null || return 0
  for i in $(seq 0 $((n - 1))); do exec 9>"/tmp/s4e-run-slots/slot$i" || return 0; flock -n 9 && return 0; done
  exec 9>"/tmp/s4e-run-slots/slot$(( $$ % n ))" && flock 9; }
compile_one() {
  quad_slot; f="$1"; b=$(printf '%s' "$f" | sed 's#^.*/corpus/##; s#^.*/src/##' | tr '/' '_')
  if timeout -k 5 "$T" "$SCRIP" --compile -o "$W/s/$b.s" "$f" </dev/null >/dev/null 2>"$W/s/$b.err" && [ -s "$W/s/$b.s" ]; then echo "C"
  else rm -f "$W/s/$b.s"
    if grep -q 'not on the ladder yet' "$W/s/$b.err" 2>/dev/null; then printf 'R\t%s: %s\n' "$b" "$(head -1 "$W/s/$b.err" | cut -c1-110)"
    else printf 'O\t%s: %s\n' "$b" "$(head -1 "$W/s/$b.err" | cut -c1-110)"; fi
  fi
}
export -f compile_one quad_slot; export W T SCRIP
printf '%s\0' "${srcs[@]}" | xargs -0 -n1 -P "${QUAD_JOBS:-6}" bash -c 'compile_one "$1"' _ > "$W/compile.res"
compiled=$(grep -c '^C$' "$W/compile.res"); refused=$(grep -c '^R' "$W/compile.res"); other=$(grep -c '^O' "$W/compile.res")
grep '^R' "$W/compile.res" | sed 's/^R\t//' | sort > "$W/refused.txt"; grep '^O' "$W/compile.res" | sed 's/^O\t//' | sort > "$W/other.txt"
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
# --- (c4) the two shapes enrolled for the inline header-open and the trail tidy admit ONLY their shape: each synthetic box below is scanned alone ---
# (hq_prolog 2026-10-28) `lea r13, [rsp|rbp + N]` is B := the construct's own choice header only when the store of the old B comes right before it (pl_header_open inline); `mov r12, rdi` is TR := the
# compacted top only right after the tidy loop's `cmp rsi, r12; jb` (pl_tr_tidy inline). The same instruction without its context is the scratch write this gate exists to catch, and must read RED.
quad_syn() { printf '.type n1_bound_bx, @function\nn1_bound_bx:\nn1_bound_α: %s\n%s\n' "$1" "$2" > "$W/syn.s"; python3 "$SCAN" "$W/syn.s" > "$W/syn.out" 2>&1; return $?; }
c4=""
quad_syn 'lea r13, [rsp + 8]' 'ret' && c4="$c4 lea-without-bank-admitted"
quad_syn 'mov qword ptr [rsp + 16], r13' 'lea r13, [rsp + 0]' || c4="$c4 bank-then-lea-refused"
quad_syn 'mov qword ptr [rsp + 16], r13' 'lea r13, [rip + foo]' && c4="$c4 lea-rip-admitted"
quad_syn 'mov r12, rdi' 'ret' && c4="$c4 bare-mov-r12-rdi-admitted"
quad_syn 'cmp rsi, r12; jb .Lx' 'mov r12, rdi' || c4="$c4 tidy-top-refused"
quad_syn 'cmp rsi, r12; jb .Lx' 'mov rax, 1
mov r12, rdi' && c4="$c4 tidy-with-intervening-insn-admitted"
[ -z "$c4" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: canary c4 (the enrolled header-open and tidy shapes admit exactly their context) failed:$c4"; gate_stamp; exit 2; }
echo "canaries: c1 injected-scratch-write RED ok · c2 reachable-rtx-write RED ok · c3 empty-input REFUSE(2) ok · c4 header-open and tidy shapes admit only their context ok"
# --- the real run ---
[ -z "${QUAD_HELPER_RX:-}" ] || echo "QUAD_HELPER_RX='$QUAD_HELPER_RX' (rtx routine names enrolled as the TR helper)"
# the scan is also chunked: every program is scanned on its own, so independent chunks (QUAD_CHUNK files each, QUAD_JOBS at a time) give the same violations; the rtx part is reachability from each chunk's calls,
# so an rtx routine that violates is reported by every chunk that reaches it and the count may repeat, never vanish. A chunk the scanner REFUSES (rc 2) makes the gate UNPROVEN.
mkdir -p "$W/scan"; ls "$W"/s/*.s | xargs -n "${QUAD_CHUNK:-60}" -P "${QUAD_JOBS:-6}" bash -c 'quad_slot; o=$(mktemp "$0/scan.XXXXXX"); python3 "$1" --rtx-dir "$2" "${@:3}" > "$o" 2>&1; echo "rc=$?" >> "$o"' "$W/scan" "$SCAN" "$RTX"
cat "$W"/scan/scan.* | grep -v '^rc=' > "$W/scan.out"
rc=0; grep -q '^rc=2$' "$W"/scan/scan.* && rc=2; [ "$rc" -ne 0 ] || { grep -q '^rc=1$' "$W"/scan/scan.* && rc=1; }
grep -v '^quad-scan:' "$W/scan.out" | awk '/^rtx reachable/{ if (r++) next } { print }'
fa=0; wr=0; en=0; vi=0; rd=0; rr=0; rw=0; rv=0
while read -r a b c d e f g h; do fa=$((fa+${a#files=})); wr=$((wr+${b#writes=})); en=$((en+${c#enrolled=})); vi=$((vi+${d#violations=})); rd=${e#rtx-defined=}; rr=$((rr+${f#rtx-reachable=})); rw=$((rw+${g#rtx-writes=})); rv=$((rv+${h#rtx-violations=})); done < <(grep -h '^quad-scan: files=' "$W/scan.out" | sed 's/^quad-scan: //')
echo "quad-scan: files=$fa writes=$wr enrolled=$en violations=$vi rtx-defined=$rd rtx-reachable=$rr rtx-writes=$rw rtx-violations=$rv" >> "$W/scan.out"
sum=$(grep '^quad-scan: files=' "$W/scan.out" | tail -1); echo "$sum"
[ -n "$sum" ] && [ "$rc" -ne 2 ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: the scanner did not produce a summary (rc=$rc)"; gate_stamp; exit 2; }
v1=$(printf '%s' "$sum" | sed -nE 's/.* violations=([0-9]+) .*/\1/p'); v2=$(printf '%s' "$sum" | sed -nE 's/.*rtx-violations=([0-9]+).*/\1/p')
bad=$(( ${v1:-0} + ${v2:-0} ))
GATE_EXAMINED="$compiled"; gate_verdict "$bad" "unenrolled r12-r15 writes (mode-4 TEXT + reachable rtx; compiled witnesses=$compiled)"
