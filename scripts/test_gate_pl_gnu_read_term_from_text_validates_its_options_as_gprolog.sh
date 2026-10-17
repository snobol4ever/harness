#!/usr/bin/env bash
# test_gate_pl_gnu_read_term_from_text_validates_its_options_as_gprolog.sh -- read_term_from_atom/chars/codes IN THE GNU DIALECT VALIDATE THEIR OPTION LIST AS gprolog 1.4.5 DOES
# (cfo 2026-10-15, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/const_io_driver).
#
# read_term_from_atom/3, read_term_from_chars/3 and read_term_from_codes/3 took any option list: an unknown option was ignored, a non-list option
# argument was ignored and syntax_error(fail) still raised. Outside the SWI dialect ($dialect is swi for a program with a module/use_module
# directive or a dict) they now go through the checks read_term/2,3 already ran on a stream (pl_read_opts_ball, pl_read_syntax_mode): an unknown option is
# domain_error(read_option, O), a non-list is type_error(list, L), a bad syntax_error value is domain_error(read_option, syntax_error(V)), and
# syntax_error(fail) makes a read of ill-formed text fail quietly. The SWI dialect is untouched. (gprolog's syntax_error(error) MESSAGE carries a
# stream name, a char position and a reason -- 'constant term stream:1 (char:3) expression expected' -- and is the family still open, not graded here.)
#
# THE ARM: one program, seven lines, the reference cut from gprolog 1.4.5 (2026-10-15) minus the open message line, mode 3 and mode 4.
# FAIL-ONCE, measured on the parent rebuilt: 3 of 6 lines differ (unknown option, syntax_error(fail), non-list option); with the cure 6 of 6 as gprolog.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_read_term_from_text_validates_its_options_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true),
        (   var(E) -> R = L ;   E = error(F, _) -> R = error(F) ;   R = ball(E) ),
        \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
:- initialization(main).
main :- t(read_term_from_atom('a.', _, [nope])),
  t(read_term_from_atom('f(X, Y, X).', _, [variable_names(_)])),
  t(read_term_from_chars([h,'(','.'], _, [syntax_error(fail)])),
  t(read_term_from_chars([h,'(','.'], _, [syntax_error(bad)])),
  t(read_term_from_codes("k(a).", _, foo)),
  t(read_term_from_codes("k(a).", _, [])).
PL
want="$(cat <<'WANT'
read_term_from_atom('a.',A,[nope]) => error(domain_error(read_option,nope))
read_term_from_atom('f(X, Y, X).',A,[variable_names(B)]) => [read_term_from_atom('f(X, Y, X).',f(C,D,C),[variable_names(['X'=C,'Y'=D])])]
read_term_from_chars([h,'(','.'],A,[syntax_error(fail)]) => []
read_term_from_chars([h,'(','.'],A,[syntax_error(bad)]) => error(domain_error(read_option,syntax_error(bad)))
read_term_from_codes([107,40,97,41,46],A,foo) => error(type_error(list,foo))
read_term_from_codes([107,40,97,41,46],A,[]) => [read_term_from_codes([107,40,97,41,46],k(a),[])]
WANT
)"
m4ok=1
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --dialect=gnu -o w.s w.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 6 of 6 lines as gprolog"
    else echo "  $label RED: $n of 6 gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run --dialect=gnu w.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
