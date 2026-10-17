#!/usr/bin/env bash
# test_gate_pl_gnu_terms_to_and_from_text_answer_as_gprolog.sh -- GNU PROLOG'S TERMS-TO-AND-FROM-TEXT BUILTINS ANSWER AS GPROLOG, IN BOTH
# MODES (cfo 2026-10-11, row prolog-gnu-builtins-the-drivers-find-128-predicates-gnu-defines-and-scrip-lacks, family 1 of five).
#
# THE LAYER.  src/parsers/prolog/prelude/gnu_builtins.pl is SCRIP's own text, embedded by the prelude generator's LOCAL mode and parsed
# only when a program names one of its exports: write, writeq, print, display and write_canonical into an atom, codes or chars;
# write_term and format into the same three; read_from_atom/codes/chars; number_atom/2; lower_upper/2 (a code is
# type_error(character, Code)); new_atom/1,2.  Each is the SWI primitive the GNU name stands for (with_output_to/2,
# read_term_from_atom/3), and SCRIP's print, display and write_canonical already write as gprolog's do (print unquoted, display and
# write_canonical in dotted canonical form).
#
# THE ARM: one witness of 22 lines cut against gplc in this run and diffed in mode 3 and mode 4 (it prints no fresh variable).
# FAIL-ONCE, measured on origin 70b456479: existence errors on the GNU names, 20 of 22 lines differ in both modes; on
# the cure 22 of 22 as gprolog.  rc=0 both modes agree with gprolog · rc=1 a divergence · rc=2 REFUSAL (no gplc, no build).  ~6 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
G=test_gate_pl_gnu_terms_to_and_from_text_answer_as_gprolog
refuse() { echo "⛔ REFUSED(2) [$G]: $*"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || refuse "lib_oracle_flags.sh unreadable"
GPLC=$(gplc_bin) || refuse "no gplc -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$G" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- initialization(main).
t(N, G) :- ( catch(G, E, (write(N-caught(E)), nl)) -> true ; write(N-failed), nl ).
main :- T = f('A b', [1,2], "s", -(1), 1+2*3, 'x'),
    t(w_atom, (write_to_atom(A1, T), writeq(A1), nl)), t(q_atom, (writeq_to_atom(A2, T), writeq(A2), nl)), t(c_atom, (write_canonical_to_atom(A3, T), writeq(A3), nl)),
    t(d_atom, (display_to_atom(A4, T), writeq(A4), nl)), t(p_atom, (print_to_atom(A5, T), writeq(A5), nl)),
    t(w_codes, (write_to_codes(C1, g(x)), writeq(C1), nl)), t(q_chars, (writeq_to_chars(C2, g('Y')), writeq(C2), nl)),
    t(wt_atom, (write_term_to_atom(A6, h('Q', [a]), [quoted(true)]), writeq(A6), nl)), t(wt_codes, (write_term_to_codes(C3, h(1), []), writeq(C3), nl)),
    t(f_codes, (format_to_codes(C4, "~w+~a", [x, y]), writeq(C4), nl)), t(f_chars, (format_to_chars(C5, "~d", [42]), writeq(C5), nl)),
    t(r_atom, (read_from_atom('foo(X, bar). ', R1), R1 = foo(V1, B1), var(V1), writeq(B1), nl)), t(r_codes, (read_from_codes("k(1, 2).", R2), writeq(R2), nl)), t(r_chars, (atom_chars('z.', Zs), read_from_chars(Zs, R3), writeq(R3), nl)),
    t(numatom1, (number_atom(42, NA), writeq(NA), nl)), t(numatom2, (number_atom(N2, '3.5'), writeq(N2), nl)),
    t(lu1, (lower_upper(a, U1), writeq(U1), nl)), t(lu2, (lower_upper(L2, 'B'), writeq(L2), nl)), t(lu3, (lower_upper(0'c, U3), writeq(U3), nl)), t(lu4, (lower_upper('1', U4), writeq(U4), nl)),
    t(newatom, (new_atom(NA1), new_atom(NA2), (NA1 \== NA2 -> write(distinct) ; write(same)), nl)), t(newatom2, (new_atom(pre_, NB), atom_concat(pre_, _, NB), write(prefixed), nl)).
PL
( cd "$D" && timeout -k 5 120 "$GPLC" --no-top-level -o w.gnu w.pl > /dev/null 2>&1 && timeout -k 5 30 ./w.gnu < /dev/null > want 2>&1 ) || refuse "gprolog itself fails on the witness"
[ -s "$D/want" ] || refuse "gprolog printed nothing for the witness"
( cd "$D" && timeout -k 5 30 "$B/scrip" --run w.pl < /dev/null > m3 2>&1 )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o w.s w.pl < /dev/null 2> m4.err && gcc -no-pie w.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o w 2>> m4.err && timeout -k 5 30 ./w < /dev/null > m4 2>&1 )
n=$(wc -l < "$D/want"); red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  $m GREEN: $n of $n lines as gprolog"
    else echo "  $m RED: $(diff "$D/want" "$D/$m" 2>/dev/null | grep -c '^<') of $n lines differ from gprolog"; diff "$D/want" "$D/$m" 2>/dev/null | head -6 | sed 's/^/    /'; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $G"
exit "$red"
