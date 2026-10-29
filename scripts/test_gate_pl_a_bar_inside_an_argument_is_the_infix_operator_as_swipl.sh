#!/usr/bin/env bash
# test_gate_pl_a_bar_inside_an_argument_is_the_infix_operator_as_swipl.sh -- A `|` INSIDE AN ARGUMENT IS THE 1100 INFIX
# OPERATOR, AS swipl READS IT; ONLY A LIST ELEMENT ENDS AT IT (cfo 2026-10-14, row
# prolog-swi-library-test-main-every-case-agrees-with-swipl-in-both-modes-ceo-1664).
#
# SWI's library(optparse) writes opt_convert(A|B, ...) and the DCG rule type(A|B) --> ..., and swipl reads both: an argument
# is read at 1200 in the SWI dialect and `|` is the infix operator '|'/2 there. SCRIP's reader (prolog_parse.c pt_term)
# refused the bar whenever p->in_args > 0, one counter for two contexts -- a list element, where `|` is the tail bar, and an
# argument, where it is an operator -- so every such clause was a parse error ("expected ) to close argument list"). The
# cure keeps the innermost context in p->in_list: pt_list sets it, pt_args, a parenthesized term and a brace term clear it,
# each restoring the outer one, and only a list element stops at the bar. The ISO reading (p->iso, arguments at 999) is
# unchanged: the bar's 1100 still exceeds an ISO argument's priority.
#
# THE ARMS: one program, nine lines (a clause head t(A|B, ...), a goal argument f(a|b), [a|b], (a|b) and its =.., a bar in
# a list element's own argument [f(a|b)], a DCG head type(A|B), and read_term_from_atom/term_to_atom at run time), stdout
# cut against swipl in this run, mode 3 and mode 4. FAIL-ONCE, measured on the parent af2cb1dff rebuilt: the reader refuses
# the clauses, main/0 is never defined, 9 of 9 lines missing in both modes; with the cure 9 of 9 as swipl in both modes.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_a_bar_inside_an_argument_is_the_infix_operator_as_swipl
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh unloadable -- the one accessor of the oracle binaries"
SW="$(swipl_bin)"; [ -x "$SW" ] || refuse "no swipl at $SW -- the oracle (swipl_bin)"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- initialization(main).
t(A|B, A-B).
type(A|B) --> [A], [B].
main :- ( t(p|q, R) -> writeq(head-R) ; writeq(head-no) ), nl,
    X = f(a|b), writeq(X), nl, X = f(Y), functor(Y, N, Ar), writeq(N/Ar), nl,
    Z = [a|b], writeq(Z), nl,
    W = (a|b), W =.. L, writeq(L), nl,
    E = [f(a|b), c], writeq(E), nl,
    ( phrase(type(u|v), [u, v]) -> writeq(dcg-yes) ; writeq(dcg-no) ), nl,
    read_term_from_atom('f(a|b)', T, []), writeq(read(T)), nl,
    term_to_atom(T2, 'g([x|y], (p|q), {r|s})'), writeq(T2), nl.
PL
want="$(cd "$D" && timeout -k 5 20 "$SW" -q w.pl -t halt < /dev/null 2>/dev/null | grep .)"
[ "$(printf '%s\n' "$want" | grep -c .)" = 9 ] || refuse "swipl did not answer the nine lines: [$want]"
m4ok=1   # a reader that refuses the program may refuse its mode-4 compile too: that is this gate's red, never a refusal
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 9 of 9 lines as swipl"
    else echo "  $label RED: $n of 9 swipl lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
