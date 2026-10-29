#!/usr/bin/env bash
# test_gate_sno_a_call_and_return_trace_handler_is_entered_by_the_define_shim_box_and_its_chain_reads_clean.sh
#
# THE ROW (the remainder of ceo CEO-1533, minted 2026-10-09): the CALL, RETURN and FRETURN trace handlers of a DEFINEd function were entered from the DEFINE shim's three hook
# blocks through rt_trace_{call,return,fail}_hook_i -> rt_trace_event_args_ip -> rt_trace_apply_island -> APPLY_fn, with the C frames live for the handler's whole life (the
# C2BB trace read descr.tiny TF once per event). THE CURE, the pattern of the VALUE and ACCESS taps: each hook block carves a trace_pend_t (112 bytes, zeroed) on the spine, calls
# rt_trace_{call,return,fail}_hook_p, which FILLS the pend instead of calling the handler, and bb_glue_trace_pend_run enters the handler through rt_apply_open / the c2bb glue /
# rt_apply_land as a box call, then closes the pend. The glue lands INSIDE a rule-9 shim-self site, so (hq_zetas, hq_collector, 2026-10-09) the emitter's rsp tracker keeps ONE saved
# cell, mark9 (tags M and N, zero bytes), the shim's mark: a rule-9 site measures its distance d against mark9 while it is set, so R plus d still reaches the shim's base from every
# site inside the glue and the section-13 chain walker follows the glue's landing as a rule-9 site. Without that cell the same run reads frameless=3360 (mode 3) and mismatch=3360
# (mode 4) under SCRIP_GC_CHAIN_CHECK=1 -- the cell is what ARCH-GC-COMPILE-TIME-FRAME-MAPS.md section 13 STEP B (the marker machinery's deletion) needs.
# ARMS, each both modes, expectations cut from sbl -bf AT RUN TIME: (A) the C2BB trace of the CALL/RETURN/ACCESS witness holds an apply.open per event and NO C-entered line --
# REFUSED when SCRIP_C2BB_TRACE writes nothing; (B) output equals sbl on the witness, on nested traced calls, on a failing return (the FRETURN block) and on traced functions of 12, 39 and 41 formals (the three hook
# blocks take compact blocks of internal label ids after the omega chain; a block that overlapped a per-formal chain defined a label twice at 10 or more formals -- found by hq_snocone's
# test_gate_sno_tracing_does_not_change_a_match_result on the bootstrap parsers; past BB_SHIM_TRACE_NF_MAX = 39 the one-byte id space is full, so a TRACED call of such a function dies with a named bomb (the C-entered hook it would otherwise take is deleted, CEO-1576) while the same function untraced still agrees with sbl -- arms m41 and m41u); (C) a handler that
# allocates under SCRIP_GC_STRESS=1 with SCRIP_GC_CHAIN_CHECK=1: output equals sbl and the chain check reads frameless=0 mismatch=0 nosite=0, with ok>0 and roadhops>0 as the
# positive control (REFUSED when the summary line is absent).
# NOT COVERED, NAMED: the LABEL, KEYWORD and FUNCTION kinds, and the two NV_GET_fn reads of bb_rev_assign_global.cpp (the ACCESS pattern applies unchanged).
# FAIL-ONCE, MEASURED (2026-10-09, SCRIP 86763386e without and with this landing): without it arm A reads 1 apply.open and 2 C-entered lines (descr.tiny TF rt_call_proc_descr)
# in each mode and the chain arm fails its positive control (roadhops=0: the road is never walked); with it 3 apply.open, 0 C-entered, ok=3606 roadhops=3360 frameless=0
# mismatch=0 nosite=0 in both modes. Without the mark9 cell (the first cut of this patch, measured by hq_zetas) the same run read frameless=3360 in mode 3 and mismatch=3360 in mode 4.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- the expectations are cut from it at run time"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
RT="$B/out"; RC=0; n=0
ok()  { n=$((n + 1)); echo "  ok    $*"; }
red() { n=$((n + 1)); RC=1; echo "  RED   $*"; }
m3() { (cd "$D" && env $2 timeout -k 5 120 "$B/scrip" --stlimit "$1.sno" < /dev/null 2>"$D/$1.m3.err"); }
m4() { "$B/scrip" --stlimit --compile --out="$D/$1.s" "$D/$1.sno" < /dev/null > /dev/null 2>&1 && gcc -no-pie -o "$D/$1.bin" "$D/$1.s" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> /dev/null \
      || { echo "M4-BUILD-FAILED"; return; }; (cd "$D" && env $2 timeout -k 5 120 "./$1.bin" < /dev/null 2>"$D/$1.m4.err"); }
want_of() { local w; w="$(cd "$D" && timeout -k 5 60 "$SBL" -bf "$1.sno" < /dev/null 2>&1)"; [ -n "$w" ] || refuse "arm $1: the oracle printed nothing -- the expectation cannot be cut"; printf '%s' "$w"; }
arm() {
  local name="$1" env="$2" want got
  want="$(want_of "$name")"
  for m in m3 m4; do
    got="$($m "$name" "$env")"
    if [ "$got" = "$want" ]; then ok "$name $m${env:+ ($env)}: $(printf '%s' "$want" | tr '\n' '|' | cut -c1-70)"; else red "$name $m${env:+ ($env)}: want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-90)] got [$(printf '%s' "$got" | tr '\n' '|' | cut -c1-90)]"; fi
  done
}
cat > "$D/a.sno" <<'SNO'
        DEFINE('TF(NAME,TAG)')                    :(TFEND)
TF      OUTPUT = 'trace ' NAME ' tag=' TAG       :(RETURN)
TFEND   DEFINE('F(A)')                            :(FEND)
F       F = A                                     :(RETURN)
FEND    TRACE('F','CALL','','TF')
        TRACE('F','RETURN','','TF')
        TRACE('X','ACCESS','','TF')
        &TRACE = 100
        X = 1
        Y = F(2)
        Z = X
        OUTPUT = 'done ' Y Z
END
SNO
cat > "$D/n.sno" <<'SNO'
        DEFINE('TF(NAME,TAG)')                    :(TFEND)
TF      OUTPUT = 'trace ' NAME ' tag=' TAG       :(RETURN)
TFEND   DEFINE('F(A)')                            :(FEND)
F       F = A + 1                                 :(RETURN)
FEND    DEFINE('G(A)')                            :(GEND)
G       G = F(A) + F(A)                           :(RETURN)
GEND    TRACE('F','CALL','','TF')
        TRACE('G','CALL','','TF')
        TRACE('G','RETURN','','TF')
        &TRACE = 100
        OUTPUT = G(3)
END
SNO
cat > "$D/f.sno" <<'SNO'
        DEFINE('TF(NAME,TAG)')                    :(TFEND)
TF      OUTPUT = 'trace ' NAME ' tag=' TAG ' v=' $NAME   :(RETURN)
TFEND   DEFINE('G(A)')                            :(GEND)
G       EQ(A,1)                                   :F(FRETURN)
        G = 'ok' A                                :(RETURN)
GEND    TRACE('G','CALL','CT','TF')
        TRACE('G','RETURN','RT','TF')
        &TRACE = 100
        OUTPUT = G(1)
        OUTPUT = IDENT(G(2)) 'fail-seen'
        OUTPUT = 'end'
END
SNO
cat > "$D/w.sno" <<'SNO'
        DEFINE('F(X)Y')
        DEFINE('H(N,T)S,K')
        TRACE('F','CALL',,'H')
        TRACE('F','RETURN',,'H')
        &TRACE = 100000
                                                 :(MAIN)
F       Y = X X X
        F = SIZE(Y)                              :(RETURN)
H       HN = HN + 1
        S = DUPL('ab',50) T N
        K = 0
H1      K = LT(K,20) K + 1                       :F(RETURN)
        S = S DUPL('z',K)                        :(H1)
MAIN    I = 0
L       I = LT(I,40) I + 1                       :F(DONE)
        Z = Z F(DUPL('q',I))                     :(L)
DONE    OUTPUT = SIZE(Z) " " HN
END
SNO
many() {  # many <name> <nformals> [untraced]: a traced (unless "untraced") DEFINEd function with <nformals> formals, called with all of them
  local name="$1" k="$2" f="" a="" i tr="TRACE('M','CALL','','TF')\n        TRACE('M','RETURN','','TF')\n        &TRACE = 100\n"
  [ "${3:-}" = untraced ] && tr=""
  for i in $(seq 1 "$k"); do f="$f${f:+,}A$i"; a="$a${a:+,}$i"; done
  { printf "        DEFINE('TF(NAME,TAG)')                    :(TFEND)\n"
    printf "TF      OUTPUT = 'trace ' NAME ' tag=' TAG       :(RETURN)\n"
    printf "TFEND   DEFINE('M(%s)')                            :(MEND)\n" "$f"
    printf "M       M = A1 + A%s                                 :(RETURN)\n" "$k"
    printf "MEND    X = 0\n"; printf "        $tr"
    printf "        OUTPUT = M(%s)\n        OUTPUT = 'again ' M(%s)\nEND\n" "$a" "$a"; } > "$D/$name.sno"; }
many m12 12
many m39 39
many m41 41
many m41u 41 untraced
for mode in m3 m4; do
  tr="$D/c2bb_$mode.tr"; : > "$tr"
  if [ "$mode" = m3 ]; then (cd "$D" && SCRIP_C2BB_TRACE="$tr" timeout -k 5 60 "$B/scrip" --stlimit a.sno < /dev/null > /dev/null 2>&1)
  else "$B/scrip" --stlimit --compile --out="$D/a.s" "$D/a.sno" < /dev/null > /dev/null 2>&1 && gcc -no-pie -o "$D/a.bin" "$D/a.s" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> /dev/null && (cd "$D" && SCRIP_C2BB_TRACE="$tr" timeout -k 5 60 ./a.bin < /dev/null > /dev/null 2>&1); fi
  [ -s "$tr" ] || refuse "the control program wrote no C2BB line in $mode -- SCRIP_C2BB_TRACE is not honoured, so arm A cannot see the road it grades"
  c=$(grep -vc '^[a-z_.]*\.open\b' "$tr"); o=$(grep -c '^apply\.open' "$tr")
  if [ "$c" = 0 ] && [ "$o" -ge 3 ]; then ok "A road $mode: $o apply.open (CALL, RETURN and ACCESS entered by their boxes), $c C-entered line(s)"; else red "A road $mode: $o apply.open, $c C-entered: $(grep -v '^[a-z_.]*\.open\b' "$tr" | cut -f1-3 | sort -u | tr '\n' ' ' | cut -c1-120)"; fi
done
arm a ""
arm n ""
arm f ""
arm m12 ""
arm m39 ""
arm m41u ""
for mode in m3 m4; do
  got="$( { $mode m41 ""; } 2>/dev/null )"; err="$(cat "$D/m41.$mode.err" 2>/dev/null)"
  if printf '%s' "$err" | grep -q "more than 39 formals" && ! printf '%s' "$got" | grep -q 'again'; then ok "m41 $mode: a traced call of a 41-formal DEFINE dies with the named bomb (the C-entered hook is deleted, CEO-1576)"; else red "m41 $mode: no named bomb: out [$(printf '%s' "$got" | tr '\n' '|' | cut -c1-70)] err [$(printf '%s' "$err" | tr '\n' '|' | cut -c1-110)]"; fi
done
want="$(want_of w)"
for mode in m3 m4; do
  got="$($mode w "SCRIP_GC_STRESS=1 SCRIP_GC_CHAIN_CHECK=1")"
  sum="$(grep -h '^\[CHAIN-CHECK\] SUMMARY' "$D/w.$mode.err" | tail -1)"
  [ -n "$sum" ] || refuse "arm C $mode: no [CHAIN-CHECK] SUMMARY line -- SCRIP_GC_CHAIN_CHECK=1 is not honoured, so the chain cannot be graded"
  fld() { printf '%s' "$sum" | tr ' ' '\n' | sed -n "s/^$1=//p"; }
  okn=$(fld ok); fl=$(fld frameless); mi=$(fld mismatch); ns=$(fld nosite); rh=$(fld roadhops)
  if [ "$got" = "$want" ]; then ok "C output $mode (stress + chain check): $want"; else red "C output $mode: want [$want] got [$(printf '%s' "$got" | tr '\n' '|' | cut -c1-90)]"; fi
  if [ "${fl:-x}" = 0 ] && [ "${mi:-x}" = 0 ] && [ "${ns:-x}" = 0 ] && [ "${okn:-0}" -gt 0 ] && [ "${rh:-0}" -gt 0 ]; then ok "C chain $mode: ok=$okn roadhops=$rh frameless=0 mismatch=0 nosite=0"; else red "C chain $mode: $sum"; fi
done
[ "$RC" -eq 0 ] && echo "GREEN: $n arms" || echo "RED: a CALL/RETURN trace handler is entered from C, its output differs from sbl, or the chain check reads a frameless or mismatched frame"
exit "$RC"
