#!/usr/bin/env bash
# test_gate_pl_an_uncaught_error_holding_a_float_is_reported_not_a_crash.sh
#
# THE DEFECT (the cfo 2026-10-07, found working prolog-swi-ieee-float-flags-and-the-evaluables-ceil-lgamma-powm): a Prolog
# program whose goal raised an uncaught error died of SIGSEGV in mode 3 whenever the ball held a float -- in snprintf's
# aligned SSE store, under rt_pl_root_omega -> rt_pl_ball_report. The pinned root's omega wire was rt_pl_root_omega itself,
# a C function entered by a jump with no return address pushed, so its body ran 8 bytes off the ABI's alignment; the
# other roots' exit wires are naked stubs that align first. Mode 4's root omega called it without aligning either and
# survived only where the landing happened to be aligned.
# THE CURE: mode 3's wire is the naked stub pl_root_ω (and $-16, %rsp; push $0; jmp), mode 4's omega aligns before its call.
#
# Four programs x two modes: the report line swipl-style SCRIP prints, rc 2, never a signal.
# THE FIXTURE IS initialization(main, main) (hq_prolog 2026-10-15, CEO-1766): since SCRIP bb7cfbe56 a raising initialization/1 goal is a warning
# and the program goes on at rc 0, as swipl -q and gprolog 1.6.0 both do, so it never reaches the root omega; the main/2 form still does, and
# swipl 9.0.4 exits 2 on all four goals here as SCRIP does.
# rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
n=0; red=0
one() {
    local name="$1" goal="$2" want="$3"
    printf ':- initialization(main, main).\nmain :- %s.\n' "$goal" > "$D/$name.pl"
    ( cd "$D" && timeout -k 5 30 "$B/scrip" "$name.pl" < /dev/null > "$name.m3" 2>&1; echo $? > "$name.rc3" )
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out="$name.s" "$name.pl" < /dev/null > /dev/null 2>&1 && gcc -no-pie "$name.s" -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o "$name.bin" 2>/dev/null ) || refuse "$name.pl: mode 4 did not build"
    ( cd "$D" && timeout -k 5 30 "./$name.bin" < /dev/null > "$name.m4" 2>&1; echo $? > "$name.rc4" )
    for m in 3 4; do
        n=$((n + 1)); got="$(head -1 "$D/$name.m$m")"; rc="$(cat "$D/$name.rc$m")"
        if [ "$got" = "$want" ] && [ "$rc" = 2 ]; then echo "  ok   $name m$m: rc 2, $got"
        else echo "  FAIL $name m$m: rc $rc, got [$got] want [$want]"; red=$((red + 1)); fi
    done
}
one float_in_type_error 'throw(error(type_error(atom, 1.5), foo))' 'Warning: goal raised exception: error(type_error(atom,1.5),foo)'
one float_ball 'throw(foo(2.5))' 'Warning: goal raised exception: foo(2.5)'
one builtin_raises_on_a_float 'succ(_, 1.5)' 'Warning: goal raised exception: error(type_error(integer,1.5),_G0)'
one atom_ball 'throw(bar)' 'Warning: goal raised exception: bar'
if [ $red -eq 0 ]; then echo "GATE PASS(0): an uncaught Prolog error is reported with rc 2 in both modes, floats included, $n arm(s)"; exit 0; fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
