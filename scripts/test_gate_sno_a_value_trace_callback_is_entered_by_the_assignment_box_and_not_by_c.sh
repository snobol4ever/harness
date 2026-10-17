#!/usr/bin/env bash
# test_gate_sno_a_value_trace_callback_is_entered_by_the_assignment_box_and_not_by_c.sh
#
# THE ROW (ceo CEO-1533, the cfo's reach map of 2026-10-07): snobol4-a-trace-callback-function-is-entered-from-c-by-the-trace-hook-mid-assignment-
# the-non-tail-c-to-bb-road-ceo-1533. A TRACE(name,'VALUE',tag,fn) callback was entered by comm_var -> comm_var_hook -> rt_trace_event_args -> APPLY_fn: a C frame sat
# between the assignment and the handler for the whole life of the handler (the C2BB trace read descr.tiny TF rt_call_proc_descr, once per event).
# THE CURE: the assignment box's tap (bb_assign_global.cpp mon_var_trace_tap) asks comm_var_open to do everything but the call -- it fills a trace_pend_t of seven DESCR
# cells on the spine (the handler's name, NAME(name), the tag, the saved g_trace and kw_ftrace, the value, the hook) and returns -- then enters the handler through
# the APPLY open/land road (rt_apply_open, bb_glue_try_enter, rt_apply_land) as a box call and continues on its gamma, where rt_trace_pend_close restores the trace
# state and runs the tail (the --stlimit banner, the monitor send) it would have run after the callback. A handler the open road declines (a builtin name) runs
# in C through rt_trace_pend_run, as before.
# ARMS, each both modes, expectations cut from sbl -bf AT RUN TIME: (A) the row's witness, and the C2BB trace holds an apply.open line (the box entered) and no
# line of any C-entered road -- REFUSED when SCRIP_C2BB_TRACE writes nothing for the control program; (B) a tag and a statement after the traced one; (C) a handler
# that FRETURNs; (D) a handler that allocates 25 KB per event while the program runs under SCRIP_GC_STRESS=1 (the pend cells must survive and relocate); (E) a handler
# that is a builtin name (the decline road); (F) a handler that assigns another traced name (no nested event fires while the handler runs).
# FAIL-ONCE, MEASURED: arm A read 6 descr.tiny lines (three events x two modes) on 0b8e936c0 and reads 0 C-entered lines with 6 apply.open lines here.
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
TF      OUTPUT = 'trace ' NAME ' = ' X        :(RETURN)
TFEND   TRACE('X','VALUE','','TF')
        &TRACE = 100
        X = 1
        X = X + 1
        X = 'three'
        OUTPUT = 'done ' X
END
SNO
cat > "$D/b.sno" <<'SNO'
        DEFINE('TF(NAME,TAG)')                    :(TFEND)
TF      OUTPUT = 'trace ' NAME ' = ' X ' tag=' TAG       :(RETURN)
TFEND   TRACE('X','VALUE','TAG1','TF')
        &TRACE = 100
        X = 1
        Y = 'plain'
        X = X + 1
        X = DUPL('ab', 3)
        OUTPUT = 'done ' X
END
SNO
cat > "$D/c.sno" <<'SNO'
        DEFINE('TF(NAME,TAG)')                    :(TFEND)
TF      OUTPUT = 'trace ' NAME ' = ' X                  :(FRETURN)
TFEND   TRACE('X','VALUE','','TF')
        &TRACE = 100
        X = 1
        X = 'two'
        OUTPUT = 'done ' X
END
SNO
cat > "$D/d.sno" <<'SNO'
        DEFINE('TF(NAME,TAG)J')                    :(TFEND)
TF      J = 0
TF.L    J = J + 1
        S = S 'abcdefghij'
        LT(J, 50)                                 :S(TF.L)
        OUTPUT = 'trace ' NAME ' = ' X ' size ' SIZE(S)       :(RETURN)
TFEND   TRACE('X','VALUE','','TF')
        &TRACE = 100
        S = ''
        X = 1
        X = DUPL('xy', 2000)
        X = 3
        OUTPUT = 'done ' SIZE(S)
END
SNO
cat > "$D/e.sno" <<'SNO'
        TRACE('X','VALUE','','IDENT')
        &TRACE = 100
        X = 1
        X = 'two'
        OUTPUT = 'done ' X
END
SNO
cat > "$D/f.sno" <<'SNO'
        DEFINE('TF(NAME,TAG)')                    :(TFEND)
TF      Y = 'inner'
        OUTPUT = 'trace ' NAME ' = ' X ' y=' Y       :(RETURN)
TFEND   TRACE('X','VALUE','','TF')
        TRACE('Y','VALUE','','TF')
        &TRACE = 100
        X = 1
        X = 2
        OUTPUT = 'done ' X Y
END
SNO
for mode in m3 m4; do
  tr="$D/c2bb_$mode.tr"; : > "$tr"
  if [ "$mode" = m3 ]; then (cd "$D" && SCRIP_C2BB_TRACE="$tr" timeout -k 5 60 "$B/scrip" --stlimit a.sno < /dev/null > /dev/null 2>&1)
  else "$B/scrip" --stlimit --compile -o "$D/a.s" "$D/a.sno" < /dev/null > /dev/null 2>&1 && gcc -no-pie -o "$D/a.bin" "$D/a.s" -L "$RT" -lscrip_rt -lm -Wl,-rpath,"$RT" 2> /dev/null && (cd "$D" && SCRIP_C2BB_TRACE="$tr" timeout -k 5 60 ./a.bin < /dev/null > /dev/null 2>&1); fi
  [ -s "$tr" ] || refuse "the control program wrote no C2BB line in $mode -- SCRIP_C2BB_TRACE is not honoured, so arm A cannot see the road it grades"
  c=$(grep -vc '^[a-z_.]*\.open\b' "$tr"); o=$(grep -c '^apply\.open' "$tr")
  if [ "$c" = 0 ] && [ "$o" -ge 3 ]; then ok "A road $mode: $o apply.open (the box entered), $c C-entered line(s)"; else red "A road $mode: $o apply.open, $c C-entered: $(grep -v '^[a-z_.]*\.open\b' "$tr" | cut -f1-3 | sort -u | tr '\n' ' ' | cut -c1-120)"; fi
done
for a in a b c e f; do arm "$a" ""; done
arm d ""
arm d "SCRIP_GC_STRESS=1"
[ "$RC" -eq 0 ] && echo "GREEN: $n arms" || echo "RED: a VALUE trace callback is entered from C, or its output differs from sbl"
exit "$RC"
