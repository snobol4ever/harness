#!/usr/bin/env bash
# test_gate_pl_an_arithmetic_function_directive_expands_the_later_clauses_with_no_use_module_line_as_swipl.sh -- :- arithmetic_function(Name/Arity). LOADS library(arithmetic)
# BY AUTOLOAD, SO THE CLAUSES AFTER IT ARE EXPANDED, WITH NO use_module LINE (hq_prolog 2026-11-01, ProPuzzles p7_miscellaneous: its nonogram section prints
# error(type_error(evaluable,binomial/2)) where swipl prints the grid; the program declares :- arithmetic_function(binomial/2). and holds no use_module(library(arithmetic))).
#
# swipl autoloads library(arithmetic) when the directive calls arithmetic_function/1, and the library's goal_expansion then rewrites every later A is E (and the six
# comparisons) that names a declared function into the call that computes it followed by the native goal. SCRIP links the library when the program names one of its exports
# and expands only on the load road, which a use_module(library(arithmetic)) line starts (the library's goal_expansion clauses are gated to that line). Now a directive that
# names an export of a library with load hooks starts the same road at its own line (prolog_parse.c pl_libs_autoload_hook_lines).
#
# THE ARM, in mode 3 and mode 4, the want cut from swipl 9.0.4 on 2026-11-01: a program that carries the SWI dialect marker (use_module(library(lists))), declares
# arithmetic_function(binomial/2) with binomial/3 as the function, and evaluates R is binomial(3, 4) + 1 in a later clause: swipl prints 13. (A program with NO dialect marker
# is the ISO default and does not take the load road; it prints the type_error where swipl prints 13: not covered, recorded in the baton.)
# FAIL-ONCE, measured on the parent (SCRIP 40719c97e, which differs from the cure only in files this gate does not reach): the type_error warning, in both modes.
# rc=0 equal to swipl · rc=1 a divergence · rc=2 REFUSAL (no build, no gcc).  ~12 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_an_arithmetic_function_directive_expands_the_later_clauses_with_no_use_module_line_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/a.pl" <<'PL'
:- use_module(library(lists)).
:- arithmetic_function(binomial/2).
binomial(N, K, R) :- R is N * K.
t(R) :- R is binomial(3, 4) + 1.
:- initialization((t(R), writeln(R))).
PL
want="13"
red=0; arms=0
arm() {
    local label="$1" got
    arms=$((arms+1))
    got="$(cd "$D" && "${@:2}" 2>/dev/null | grep .)"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: equal to swipl"
    else echo "  $label RED: differs from swipl"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=$((red+1)); fi
}
arm "a.pl m3" timeout -k 5 60 "$B/scrip" --run a.pl < /dev/null
if ( cd "$D" && timeout -k 5 120 "$B/scrip" --compile --out=a.s a.pl < /dev/null > /dev/null 2>&1 && [ -s a.s ] \
     && gcc -m64 -no-pie a.s -o a.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
    arm "a.pl m4" timeout -k 5 60 ./a.bin < /dev/null
else echo "  a.pl m4 RED: the program did not compile or link in mode 4"; red=$((red+1)); arms=$((arms+1)); fi
echo "PL_ARITHMETIC_FUNCTION_AUTOLOAD_BOARD arms=$arms red=$red (tree $(git -C "$B" rev-parse --short HEAD))"
[ "$red" = 0 ] && { echo "GATE OK [$G]: $arms arms equal to swipl"; exit 0; }
echo "GATE FAIL [$G]: $red of $arms arms differ from swipl"; exit 1
