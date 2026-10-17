#!/usr/bin/env bash
# test_gate_sno_an_access_trace_callback_is_entered_by_the_variable_read_box_and_not_by_c.sh
#
# THE ROW (the remainder of ceo CEO-1533, minted 2026-10-09): an ACCESS trace handler -- TRACE(name,'ACCESS',tag,fn) -- was entered from NV_GET_fn: the variable read box
# called the C reader, which raised rt_trace_event(TRK_ACCESS) and ran the handler through APPLY_fn with the C frames live for the handler's whole life (the C2BB trace
# read descr.tiny TF rt_call_proc_descr, once per read). THE CURE, the pattern of the VALUE tap (SCRIP e18f52cbb): in a trace build the generic path of bb_var_global
# carves a trace_pend_t on the spine and calls NV_GET_open, which reads the variable exactly as NV_GET_fn does and, where a handler is due, FILLS the pend (and keeps
# the value in its cell) instead of calling it; the box enters the handler through bb_glue_trace_pend_run (rt_apply_open, the c2bb glue, rt_apply_land) as a box call,
# closes the pend (trace state restored) and reloads the value from the cell, which the collector relocates. A handler the open road declines runs in C as before.
# ARMS, each both modes, expectations cut from sbl -bf AT RUN TIME: (A) the C2BB trace of the first program holds an apply.open line (the box entered) and no C-entered
# line -- REFUSED when SCRIP_C2BB_TRACE writes nothing; (B) a tag and several reads; (C) a handler that allocates 25 KB per event under SCRIP_GC_STRESS=1 (the value
# survives the handler); (D) a handler that FRETURNs and reads the traced name itself (no nested event fires).
# NOT COVERED, NAMED: the LABEL, KEYWORD and FUNCTION kinds, and the two bb_rev_assign_global reads. The CALL and RETURN handlers of the DEFINE shim are
# test_gate_sno_a_call_and_return_trace_handler_is_entered_by_the_define_shim_box_and_its_chain_reads_clean.sh.
# FAIL-ONCE, MEASURED: on the trace-callback witness (CALL, RETURN and ACCESS handlers, X read once) the C2BB trace read 3 descr.tiny lines before this landing and 2 after (the ACCESS one
# gone, an apply.open in its place); arm A reads 0 C-entered lines and an apply.open per read on a program with an ACCESS handler alone.
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
m3() { (cd "$D" && env $2 timeout -k 5 60 "$B/scrip" --stlimit "$1.sno" < /dev/null 2>/dev/null); }
m4() { "$B/scrip" --stlimit --compile -o "$D/$1.s" "$D/$1.sno" < /dev/null > /dev/null 2>&1 && gcc -no-pie -o "$D/$1.bin" "$D/$1.s" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> /dev/null \
      || { echo "M4-BUILD-FAILED"; return; }; (cd "$D" && env $2 timeout -k 5 60 "./$1.bin" < /dev/null 2>/dev/null); }
arm() {
  local name="$1" env="$2" want got
  want="$(cd "$D" && timeout -k 5 60 "$SBL" -bf "$name.sno" < /dev/null 2>&1)"
  [ -n "$want" ] || refuse "arm $name: the oracle printed nothing -- the expectation cannot be cut"
  for m in m3 m4; do
    got="$($m "$name" "$env")"
    if [ "$got" = "$want" ]; then ok "$name $m${env:+ ($env)}: $(printf '%s' "$want" | tr '\n' '|' | cut -c1-70)"; else red "$name $m${env:+ ($env)}: want [$(printf '%s' "$want" | tr '\n' '|' | cut -c1-90)] got [$(printf '%s' "$got" | tr '\n' '|' | cut -c1-90)]"; fi
  done
}
cat > "$D/a.sno" <<'SNO'
        DEFINE('TF(NAME,TAG)')                    :(TFEND)
TF      OUTPUT = 'access ' NAME ' tag=' TAG       :(RETURN)
TFEND   TRACE('X','ACCESS','AT','TF')
        &TRACE = 100
        X = 'one'
        Y = X
        OUTPUT = 'y=' Y
        Y = X X
        OUTPUT = 'again ' Y
        OUTPUT = SIZE(X)
END
SNO
cat > "$D/c.sno" <<'SNO'
        DEFINE('TF(NAME,TAG)J')                    :(TFEND)
TF      J = 0
TF.L    J = J + 1
        S = S 'abcdefghij'
        LT(J, 40)                                 :S(TF.L)
        OUTPUT = 'access ' NAME ' size ' SIZE(S) ' x=' X       :(RETURN)
TFEND   TRACE('X','ACCESS','','TF')
        &TRACE = 100
        S = ''
        X = DUPL('pq', 500)
        Y = X
        Z = X
        OUTPUT = 'done ' SIZE(Y) ' ' SIZE(Z) ' ' SIZE(S)
END
SNO
cat > "$D/d.sno" <<'SNO'
        DEFINE('TF(NAME,TAG)')                    :(TFEND)
TF      T = 'inside ' X
        OUTPUT = 'access ' NAME ' ' T                  :(FRETURN)
TFEND   TRACE('X','ACCESS','','TF')
        &TRACE = 100
        X = 'v'
        Y = X
        OUTPUT = 'y=' Y
END
SNO
cp "$D/a.sno" "$D/b.sno"
for mode in m3 m4; do
  tr="$D/c2bb_$mode.tr"; : > "$tr"
  if [ "$mode" = m3 ]; then (cd "$D" && SCRIP_C2BB_TRACE="$tr" timeout -k 5 60 "$B/scrip" --stlimit a.sno < /dev/null > /dev/null 2>&1)
  else "$B/scrip" --stlimit --compile -o "$D/a.s" "$D/a.sno" < /dev/null > /dev/null 2>&1 && gcc -no-pie -o "$D/a.bin" "$D/a.s" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> /dev/null && (cd "$D" && SCRIP_C2BB_TRACE="$tr" timeout -k 5 60 ./a.bin < /dev/null > /dev/null 2>&1); fi
  [ -s "$tr" ] || refuse "the control program wrote no C2BB line in $mode -- SCRIP_C2BB_TRACE is not honoured, so arm A cannot see the road it grades"
  c=$(grep -vc '^[a-z_.]*\.open\b' "$tr"); o=$(grep -c '^apply\.open' "$tr")
  if [ "$c" = 0 ] && [ "$o" -ge 3 ]; then ok "A road $mode: $o apply.open (the box entered), $c C-entered line(s)"; else red "A road $mode: $o apply.open, $c C-entered: $(grep -v '^[a-z_.]*\.open\b' "$tr" | cut -f1-3 | sort -u | tr '\n' ' ' | cut -c1-120)"; fi
done
arm a ""
arm c ""
arm c "SCRIP_GC_STRESS=1"
arm d ""
[ "$RC" -eq 0 ] && echo "GREEN: $n arms" || echo "RED: an ACCESS trace handler is entered from C, or its output differs from sbl"
exit "$RC"
