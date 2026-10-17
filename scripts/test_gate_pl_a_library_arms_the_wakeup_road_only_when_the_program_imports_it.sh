#!/usr/bin/env bash
# test_gate_pl_a_library_arms_the_wakeup_road_only_when_the_program_imports_it.sh -- A VENDORED LIBRARY WHOSE OWN CODE
# NAMES put_attr OR freeze ARMS THE ATTRIBUTED-VARIABLE WAKE-UP ROAD ONLY WHEN THE PROGRAM IMPORTS IT; library(pio) IMPORTS
# library(pure_input) (cfo 2026-10-14, the cto's red: GNU indexing_driver and type_inl_driver crossed the loop's 60 s, bisected
# to the cfo's a78d3f64e).
#
# a78d3f64e armed '$wakeup' for EVERY selected library whose source names put_attr or freeze, so library(pure_input)'s lazy list
# wakes its attr_unify_hook. But a library is also selected by a data term that matches an export by name and arity: GNU's
# Pl2Wam/indexing.pl writes the term label(L), clpfd exports label/1, and clpfd names put_attr, so the program armed the
# wake-up road it never uses -- dif, when and the attribute hooks pulled in, the mode-4 asm 133 MB -> 226 MB (the cto's
# reading), indexing_driver 9.5 s -> 36 s. A program that USES clpfd imports it (:- use_module(library(clpfd)), the atom
# clpfd arms the road through pl_attv_api's clpfd/0 as before). The cure (prolog_parse.c pl_libs_append) arms from a library
# only when the program imports it by use_module, and pl_collect_imported_libs records pure_input for library(pio), which
# re-exports it as swipl's does.
#
# THE ARMS, each cut against swipl in this run and measured on the injected program (scrip --dump-ast: the parse and the
# prelude injection, no emission):
#   ARM 1: a program naming clpfd's label/1 only as data answers as swipl and its injected program names no '$wakeup'.
#     FAIL-ONCE on the parent 10ca40892 rebuilt: 2 '$wakeup' lines (the road armed), the answer as swipl.
#   ARM 2: a program importing library(pio) reads an empty file as swipl in both modes -- phrase_from_file("a", F) fails,
#     phrase_from_file([], F) succeeds -- and its injected program names '$wakeup'. FAIL-ONCE on the cure without the pio
#     mapping: "a" succeeded on the empty file (SWI library/test_pio null#2 red), 0 '$wakeup' lines.
# rc=0 green · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~10 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_a_library_arms_the_wakeup_road_only_when_the_program_imports_it
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/data.pl" <<'PL'
:- initialization(main).
main :- T = label(_), functor(T, N, A), writeq(N/A), nl.
PL
cat > "$D/pio.pl" <<'PL'
:- use_module(library(pio)).
:- initialization(main).
main :- F = 'pio_null.txt', open(F, write, S), close(S),
    ( phrase_from_file("a", F) -> writeq(a-yes) ; writeq(a-no) ), nl,
    ( phrase_from_file([], F) -> writeq(empty-yes) ; writeq(empty-no) ), nl,
    delete_file(F).
PL
red=0
for p in data pio; do
    want="$(cd "$D" && timeout -k 5 20 "$SW" -q $p.pl -t halt < /dev/null 2>/dev/null | grep .)"
    [ -n "$want" ] || refuse "swipl gave no answer for $p.pl"
    wk="$(cd "$D" && timeout -k 5 120 "$B/scrip" --dump-ast $p.pl < /dev/null 2>/dev/null | grep -c 'wakeup')"
    got3="$(cd "$D" && timeout -k 5 120 "$B/scrip" --run $p.pl < /dev/null 2>/dev/null | grep .)"
    got4=""
    if ( cd "$D" && timeout -k 5 120 "$B/scrip" --compile -o $p.s $p.pl < /dev/null > /dev/null 2>&1 && [ -s $p.s ] \
         && gcc -m64 -no-pie $p.s -o $p.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
        got4="$(cd "$D" && timeout -k 5 120 ./$p.bin < /dev/null 2>/dev/null | grep .)"
    fi
    if [ "$p" = data ]; then arm="ARM 1"; wk_ok=$([ "$wk" = 0 ] && echo 1 || echo 0); else arm="ARM 2"; wk_ok=$([ "$wk" -gt 0 ] && echo 1 || echo 0); fi
    if [ "$got3" = "$want" ] && [ "$got4" = "$want" ] && [ "$wk_ok" = 1 ]; then echo "  $arm GREEN: $p.pl as swipl in m3 and m4, $wk '\$wakeup' line(s) in the injected program"
    else echo "  $arm RED: $p.pl swipl=[$(echo $want)] m3=[$(echo $got3)] m4=[$(echo $got4)], $wk '\$wakeup' line(s)"; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
