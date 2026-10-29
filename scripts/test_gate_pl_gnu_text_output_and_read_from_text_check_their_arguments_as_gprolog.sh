#!/usr/bin/env bash
# test_gate_pl_gnu_text_output_and_read_from_text_check_their_arguments_as_gprolog.sh -- GNU's write_to_atom/codes/chars FAMILY TYPE-CHECKS
# ITS OUTPUT ARGUMENT AND read_from_atom/codes/chars READ EMPTY TEXT AS end_of_file, AS gprolog 1.6.0 DOES (cfo 2026-10-14, row
# prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks: GNU BipsPl/const_io_driver).
#
# gnu_builtins.pl (SCRIP's own GNU text) built each Kind_to_atom/codes/chars predicate as with_output_to(Kind(Out), Goal), so an
# output argument of the wrong type simply failed to unify where gprolog raises type_error(atom, X) (an atom variant) or
# type_error(list, X) (codes or chars: a partial list is accepted). Each now checks it first ('$gnu_b_oa'/2, '$gnu_b_ol'/2), and
# read_from_atom/codes/chars answer end_of_file on empty or blank text ('$gnu_b_read'/2) where read_term_from_atom/3 raised a syntax
# error; read_from_atom/2 of an unbound atom is instantiation_error.
# NOT HERE: GNU's own format/2 error terms (domain_error(non_empty_list, []), domain_error(format_control_sequence, C)) and
# read_term's option checks (domain_error(read_option, O), type_error(list, O)) -- the format and read families of the drivers row.
#
# THE ARM: one program, eighteen lines, the reference cut from gprolog 1.6.0 (the pristine oracle, 2026-10-14) and written out here,
# mode 3 and mode 4. FAIL-ONCE, measured on the parent 42382e1a5 rebuilt: 13 of 18 lines differ in both modes; with the cure
# 18 of 18 as gprolog in both modes.
# rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_text_output_and_read_from_text_check_their_arguments_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
t(G) :- catch((G -> R = G ; R = no), error(E, _), R = err(E)), writeq(R), nl.
:- initialization(main).
main :- t(write_to_atom(f(x), a)), t(write_to_atom(abc, a)), t(writeq_to_atom(1, a)), t(write_to_codes(foo, a)),
  t(write_to_codes([0'a|x], a)), t(write_to_chars(f(y), a)), t(format_to_atom(1, '~w', [x])), t(write_term_to_atom(g(1), a, [])),
  t(write_to_codes(_, f(a))), t(write_term_to_codes(x, a, [])), t(print_to_chars([a|_], b)), t(read_from_atom(_, _)),
  t(read_from_atom('', _)), t(read_from_atom('   ', _)), t(read_from_codes([], _)), t(read_from_chars([], _)),
  t(read_from_codes(_, _)), t(read_from_chars('', _)).
PL
want="$(cat <<'WANT'
err(type_error(atom,f(x)))
no
err(type_error(atom,1))
err(type_error(list,foo))
err(type_error(list,[97|x]))
err(type_error(list,f(y)))
err(type_error(atom,1))
err(type_error(atom,g(1)))
write_to_codes([102,40,97,41],f(a))
err(type_error(list,x))
no
err(instantiation_error)
read_from_atom('',end_of_file)
read_from_atom('   ',end_of_file)
read_from_codes([],end_of_file)
read_from_chars([],end_of_file)
err(instantiation_error)
err(type_error(list,''))
WANT
)"
m4ok=1
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null > /dev/null 2>&1 && [ -s w.s ] \
  && gcc -m64 -no-pie w.s -o w.bin -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" > /dev/null 2>&1 ) || m4ok=0
red=0
arm() {
    local label="$1"; shift
    local got n
    got="$(cd "$D" && "$@" 2>/dev/null | grep .)"
    n="$(diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | grep -c '^<')"
    if [ "$got" = "$want" ]; then echo "  $label GREEN: 18 of 18 lines as gprolog"
    else echo "  $label RED: $n of 18 gprolog lines missing or different"; diff <(printf '%s\n' "$want") <(printf '%s\n' "$got") | sed 's/^/    /'; red=1; fi
}
arm m3 timeout -k 5 20 "$B/scrip" --run w.pl < /dev/null
if [ "$m4ok" = 1 ]; then arm m4 timeout -k 5 20 ./w.bin < /dev/null; else echo "  m4 RED: the program did not compile or link in mode 4"; red=1; fi
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
