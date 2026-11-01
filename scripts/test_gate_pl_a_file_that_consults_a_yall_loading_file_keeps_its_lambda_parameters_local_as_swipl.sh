#!/usr/bin/env bash
# test_gate_pl_a_file_that_consults_a_yall_loading_file_keeps_its_lambda_parameters_local_as_swipl.sh -- A LAMBDA'S PARAMETERS ARE LOCAL ONCE library(yall) IS LOADED,
# ALSO WHEN THE LOADING IS DONE BY A FILE THE PROGRAM CONSULTS (hq_prolog 2026-11-01, ProPuzzles p7_miscellaneous: van_koch/2 ran 264,000 steps in 90 s where swipl
# needs 15,000 in 2 s, because the foldl lambda [m(A,B,_),Es,Es1]>>(...) named two parameters Es and Es1 that are also variables of its clause).
#
# swipl compiles a lambda written as a meta-call argument into an auxiliary predicate once library(yall) is loaded (yall's system:goal_expansion), so a variable of
# the lambda that the clause also holds is a NEW variable in the lambda: the parameters shadow the clause's. Without yall loaded the lambda is copied at run time with
# its bound clause variables, and a parameter bound to the clause's list fails to unify with the accumulator. SCRIP renames the lambda's variables at lower time
# (prolog_lower.c pl_yall_lower_program) when the program holds :- use_module(library(yall)); a consulted file is lowered by itself AFTER the including program, so a
# use_module line in the consulted file was never seen and the including program's lambdas kept the run-time copy. Now prolog_driver.c reads the consulted file's
# directive lines before the including program is lowered (PlProgram.consults_yall).
#
# THE ARMS, each in mode 3 and mode 4, the wants cut from swipl 9.0.4 on 2026-11-01: the main file consults a helper that loads yall (q must answer yes(6)), and the
# same main file consulting a helper that does not (q must fail, as swipl's run-time copy does: the control that the rename is not applied everywhere); r holds a
# {Free}/ lambda that shares Es with the clause and answers the same in both arms.
# FAIL-ONCE, measured on the parent (SCRIP 06f3e7055): the yall arm prints q(no) where swipl prints q(yes(6)), in both modes.
# rc=0 every arm agrees with swipl · rc=1 a divergence · rc=2 REFUSAL (no build, no gcc).  ~25 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_a_file_that_consults_a_yall_loading_file_keeps_its_lambda_parameters_local_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
printf ':- use_module(library(yall)).\n:- use_module(library(apply)).\n' > "$D/lam_yall.pl"
printf ':- use_module(library(apply)).\n' > "$D/lam_plain.pl"
cat > "$D/main.tmpl" <<'PL'
:- ensure_loaded(lam_HELPER).
q(Es, Out) :- Es = [a,b], foldl([X,Es,Es1]>>(Es1 is Es+X), [1,2,3], 0, Out).
r(Es, Out) :- Es = [a,b], maplist({Es}/[X,Y]>>(Y = Es-X), [1,2], Out).
:- initialization((catch((q(_, O) -> R = yes(O) ; R = no), Ex, R = ex(Ex)), writeq(q(R)), nl)).
:- initialization((catch((r(_, O) -> R = yes(O) ; R = no), Ex, R = ex(Ex)), writeq(r(R)), nl)).
PL
for h in yall plain; do sed "s/HELPER/$h/" "$D/main.tmpl" > "$D/m_$h.pl"; done
want_yall="$(printf '%s\n' 'q(yes(6))' 'r(yes([[a,b]-1,[a,b]-2]))')"
want_plain="$(printf '%s\n' 'q(no)' 'r(yes([[a,b]-1,[a,b]-2]))')"
red=0; arms=0
arm() {
    local label="$1" want="$2" got
    arms=$((arms+1))
    got="$(cd "$D" && "${@:3}" 2>/dev/null | grep .)"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: equal to swipl"
    else echo "  $label RED: differs from swipl"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=$((red+1)); fi
}
for h in yall plain; do
    w="want_$h"
    arm "m_$h m3" "${!w}" timeout -k 5 60 "$B/scrip" --run "m_$h.pl" < /dev/null
    if ( cd "$D" && timeout -k 5 120 "$B/scrip" --compile --out="m_$h.s" "m_$h.pl" < /dev/null > /dev/null 2>&1 && [ -s "m_$h.s" ] \
         && gcc -m64 -no-pie "m_$h.s" -o "m_$h.bin" -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
        arm "m_$h m4" "${!w}" timeout -k 5 60 "./m_$h.bin" < /dev/null
    else echo "  m_$h m4 RED: the program did not compile or link in mode 4"; red=$((red+1)); arms=$((arms+1)); fi
done
echo "PL_YALL_THROUGH_CONSULT_BOARD arms=$arms red=$red (tree $(git -C "$B" rev-parse --short HEAD))"
[ "$red" = 0 ] && { echo "GATE OK [$G]: $arms arms equal to swipl"; exit 0; }
echo "GATE FAIL [$G]: $red of $arms arms differ from swipl"; exit 1
