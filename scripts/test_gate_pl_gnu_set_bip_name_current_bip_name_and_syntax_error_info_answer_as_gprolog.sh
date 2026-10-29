#!/usr/bin/env bash
# test_gate_pl_gnu_set_bip_name_current_bip_name_and_syntax_error_info_answer_as_gprolog.sh -- set_bip_name/2, current_bip_name/2 AND syntax_error_info/4
# EXIST AND ANSWER AS gprolog (cfo 2026-10-15, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: BipsPl/pl_error_driver).
#
# GNU Prolog's error-context built-ins were absent from SCRIP (existence_error for all three). gnu_builtins.pl now defines them as gprolog's error_supp.c
# does: set_bip_name/2 reads its name with an atom check and its arity with an integer check (a variable is an instantiation_error, the name first), stores
# Name/Arity destructively (nb_setval, so backtracking keeps it) and stores an arity over gprolog's MAX_ARITY 255 as -1; current_bip_name/2 checks its
# arguments as atom-or-variable and integer-or-variable and unifies them with the stored name; syntax_error_info/4 checks its four arguments (atom, integer,
# integer, atom, each or a variable) and answers the last syntax error the reader recorded, failing when none was. THE RECORDING IS NOT HERE: SCRIP's
# reader does not yet record a GNU syntax error with gprolog's position and message, so the two lines of BipsPl/pl_error_driver that read a recorded error
# stay red until the read family lands.
#
# THE ARM: one program (no SWI marker), seventeen lines, the reference cut from gprolog 1.6.0 (2026-10-15), mode 3 and mode 4.
# FAIL-ONCE, measured on the parent (SCRIP bb2a750ef, the prelude change reverted and rebuilt): all 17 lines differ in both modes.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~4 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_set_bip_name_current_bip_name_and_syntax_error_info_answer_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- initialization(main).
t(G) :- copy_term(G, C), catch(findall(C, C, L), E, true), ( var(E) -> R = L ; E = error(F, _) -> R = error(F) ; R = ball(E) ), \+ \+ ( numbervars(G-R, 0, _), writeq(G), write(' => '), writeq(R), nl ).
main :- t(syntax_error_info(_, _, _, _)),
  t((set_bip_name(foo, 2), current_bip_name(_, _))), t((set_bip_name(bar, 0), current_bip_name(bar, _))), t((set_bip_name(foo, 2), current_bip_name(foo, 3))),
  t((set_bip_name(wide, 300), current_bip_name(_, _))), t(((set_bip_name(kept, 1), fail ; true), current_bip_name(_, _))),
  t(set_bip_name(_, 1)), t(set_bip_name(foo, _)), t(set_bip_name(1, _)), t(set_bip_name(foo, a)), t(set_bip_name(foo, 2.0)),
  t((set_bip_name(foo, 2), current_bip_name(1, _))), t((set_bip_name(foo, 2), current_bip_name(_, a))),
  t(syntax_error_info(3, _, _, _)), t(syntax_error_info(_, a, _, _)), t(syntax_error_info(_, _, b, _)), t(syntax_error_info(_, _, _, 4)).
PL
want="$(cat <<'WANT'
syntax_error_info(A,B,C,D) => []
set_bip_name(foo,2),current_bip_name(A,B) => [(set_bip_name(foo,2),current_bip_name(foo,2))]
set_bip_name(bar,0),current_bip_name(bar,A) => [(set_bip_name(bar,0),current_bip_name(bar,0))]
set_bip_name(foo,2),current_bip_name(foo,3) => []
set_bip_name(wide,300),current_bip_name(A,B) => [(set_bip_name(wide,300),current_bip_name(wide,-1))]
(set_bip_name(kept,1),fail;true),current_bip_name(A,B) => [((set_bip_name(kept,1),fail;true),current_bip_name(kept,1))]
set_bip_name(A,1) => error(instantiation_error)
set_bip_name(foo,A) => error(instantiation_error)
set_bip_name(1,A) => error(type_error(atom,1))
set_bip_name(foo,a) => error(type_error(integer,a))
set_bip_name(foo,2.0) => error(type_error(integer,2.0))
set_bip_name(foo,2),current_bip_name(1,A) => error(type_error(atom,1))
set_bip_name(foo,2),current_bip_name(A,a) => error(type_error(integer,a))
syntax_error_info(3,A,B,C) => error(type_error(atom,3))
syntax_error_info(A,a,B,C) => error(type_error(integer,a))
syntax_error_info(A,B,b,C) => error(type_error(integer,b))
syntax_error_info(A,B,C,4) => error(type_error(atom,4))
WANT
)"
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 17 of 17 lines as gprolog"
    else echo "  $label RED: $n of 17 gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run g.pl < /dev/null
if ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=g.s g.pl < /dev/null > /dev/null 2>&1 && [ -s g.s ] \
     && gcc -m64 -no-pie g.s -o g.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ); then
    arm m4 timeout -k 5 20 ./g.bin < /dev/null
else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
