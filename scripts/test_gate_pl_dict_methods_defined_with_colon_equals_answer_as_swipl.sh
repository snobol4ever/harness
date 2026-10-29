#!/usr/bin/env bash
# test_gate_pl_dict_methods_defined_with_colon_equals_answer_as_swipl.sh -- SWI DICT METHODS: Self.f() := V [:- Body] DEFINES A FUNCTION
# ON THE DICTS OF THE DEFINING MODULE'S TAG, AND Dict.f() / Dict.f(Args) CALLS IT, AS swipl DOES (cfo 2026-10-14, row
# prolog-swi-core-test-dict-every-case-agrees-with-swipl-in-both-modes-ceo-1709: test_dict define_functions na, aa, a2, qna, qa2).
#
# The reader had no := operator (swipl: 990 xfx), so every definition was a parse error. The reader already keeps f() apart from
# the atom f (a TT_FNC with no children), and the cure keeps that distinction to the call: lower_prolog.c pl_dot_fn makes the
# function of Dict.f() the internal method key '$dict_m0'(f), so Dict.f() is a method call where Dict.f stays a key lookup. Each
# definition -- a clause of :=/2, renamed M::=/2 by the module flattener, or carrying an Other: qualifier on its head -- becomes a
# clause '$dict_method'(Module, F, Self, V) :- Body (pl_dict_method_clause, one '$dict_method'/4 for the program), and library(dicts)'
# '$dict_fn'/3 dispatches a method key or a compound function on the dict's tag. NOT HERE: a method of a tag no module defines raises
# swipl's existence_error; here it fails.
#
# THE ARMS: one module, seven lines (zero- and one-argument methods, a body, a definition in another module, a method of a bound
# dict, and a key that shares a method's name), stdout cut against swipl in this run, mode 3 and mode 4. FAIL-ONCE, measured on the
# parent b8b0cc26f rebuilt: 7 of 7 lines missing in both modes (the := clauses do not parse); with the cure 7 of 7 as swipl.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_dict_methods_defined_with_colon_equals_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- module(tm, [go/0]).
_.test_na() := 1.
D.test_aa() := D.a.
D.test_a2() := X :- X is D.a^2.
D.plus(N) := X :- X is D.a + N.
other:_.test_na() := 7.
go :- writeq(na-tm{}.test_na()), nl, writeq(aa-tm{a:2}.test_aa()), nl, writeq(a2-tm{a:3}.test_a2()), nl,
    writeq(plus-tm{a:2}.plus(5)), nl, writeq(other_module-other{}.test_na()), nl,
    D = tm{a:4}, X = D.test_aa(), writeq(bound_dict-X), nl,
    writeq(key_not_method-tm{test_na:k}.test_na), nl.
:- initialization(go).
PL
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>/dev/null | grep .)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 7 ] || refuse "swipl did not answer the seven lines: [$want]"
m4ok=1   # a program SCRIP refuses to compile is this gate's red, never a refusal
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 7 of 7 lines as swipl"
    else echo "  $label RED: $n of 7 swipl lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
