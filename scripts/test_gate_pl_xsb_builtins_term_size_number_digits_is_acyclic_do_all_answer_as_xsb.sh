#!/usr/bin/env bash
# test_gate_pl_xsb_builtins_term_size_number_digits_is_acyclic_do_all_answer_as_xsb.sh -- XSB'S OWN BUILTINS, AS XSB ANSWERS THEM (hq_icon 2026-10-28, row prolog-xsbtests-to-100-the-58-failing-programs-ceo-1926; ARCH-PROLOG-DIALECTS.md sec 5, THE CONFLICTING BUILTINS live in xsb_builtins.pl).
#
# term_to_atom/2,3 and term_to_codes/2,3 (XSB's string.P: write-only, canonical, variables _h0.._hN, the quoted, ignore_ops and numbervars options and their four error forms) join the
# witness, with the renaming import (:- import append/3 from basics as myappend/3.), replacing SWI's parsing term_to_atom/2 in the XSB dialect (lower_prolog.c pl_xsb_library_replaces).
# term_size/2 (XSB's term_sizew: an atom, an integer, a variable or [] is 1, a float 4, a compound or list cell 1 plus its arguments' sizes), number_digits/2 (digits as the integers
# 0 to 9, '-' '.' 'e' '+' as atoms; syntax_error and type_error(digit|list|number) carry the whole list or the culprit as XSB raises them), is_acyclic/1 and do_all/1,2 with if_none
# (findall over the variables Gen and Do share, sorted, once each) are XSB's, measured on XSB 5.0.0. xsb_builtins is selected ONLY in the XSB dialect (prolog_parse.c
# pl_lib_dialect_ok), so its term_size/2 replaces library(terms)' there (the generator's SHADOWS row) and a SWI program keeps swipl's count, and swipl's term_to_atom/2 (quoting, and parsing
# text when the term is unbound): arm swi.
#
# THE REFS ARE THE ORACLES' OUTPUT, cut when the gate was written: XSB 5.0.0 (xsb_bin) and swipl 9; each is re-cut when its oracle is on the box and the gate refuses rc=2 on disagreement.
# RED BEFORE (measured on SCRIP 44274bf58, hq_icon 2026-10-28): term_size, number_digits, is_acyclic and do_all raised existence_error or counted SWI's cells (xsb_tests prolog_tests_test_term_size
# read 200/300/20 for 101/201/15, prolog_tests_n2c lacked number_digits). GREEN AFTER: m3 and m4 byte-identical to XSB's 77 lines, and the SWI program byte-identical to swipl's 4.
#
# Usage: bash ../harness/scripts/test_gate_pl_xsb_builtins_term_size_number_digits_is_acyclic_do_all_answer_as_xsb.sh
set -uo pipefail
GATE_NAME=test_gate_pl_xsb_builtins_term_size_number_digits_is_acyclic_do_all_answer_as_xsb
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
RT="${RT_DIR:-$HERE/../../SCRIP/out}"
. "$HERE/lib_gate.sh"
. "$HERE/lib_oracle_flags.sh"
gate_parse_args "$@"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
command -v gcc >/dev/null || { echo "⛔ REFUSED(2) [$GATE_NAME]: no gcc -- the mode-4 arm cannot be linked"; exit 2; }
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/w.pl" <<'PL'
:- import term_to_atom/2, term_to_atom/3, term_to_codes/2, term_to_codes/3 from string.
:- import append/3 from basics as myappend/3.
:- op(1150, fx, do_all).
p(1,a). p(2,b). p(1,c).
sz(I, T) :- term_size(T, S), write(sz(I, S)), nl.
nd(N) :- number_digits(N, L), write(digits(L)), nl, number_digits(M, L), write(back(M)), nl.
ne(L) :- ( catch(number_digits(_, L), error(E, _), (write(caught(E)), nl, fail)) -> write(ok), nl ; write(no), nl ).
pr(X, Y) :- write(X), write(' '), write(Y), nl.
main1 :- sz(1,a), sz(2,1), sz(3,1.5), sz(4,_), sz(5,f(a)), sz(6,f(_)), sz(7,f(1.5)), sz(8,[]), sz(9,[a]), sz(10,[a,b]), sz(11,[1.5]), sz(12,f(a,b)), sz(13,f(f(a))), sz(14,[a,1,_,f(a),1.1]),
    nd(-23), nd(0.0), nd(23), nd(1.5), ne([1,a]), ne([1,'.']), ne([]), ne([10]), ne(foo), ne([5,'.',0,0,'F']),
    ( is_acyclic(f(a,[b])) -> write(acyclic), nl ; write(cyclic), nl ),
    do_all(p(X,_), (write(X), nl)), do_all(p(9,Y), if_none(write(Y), (write(none), nl))), do_all(p(X1,_), if_none(write(X1), write(none))), nl,
    ( do_all (p(X2,Y2), pr(X2,Y2)) ), write(done), nl.
tt(I, T) :- term_to_atom(T, A), write(tt(I)), write(' '), write(A), nl.
to(I, T, O) :- term_to_atom(T, A, O), write(to(I)), write(' '), write(A), nl.
tc(I, T) :- term_to_codes(T, C), write(tc(I)), write(' '), write(C), nl.
er(I, G) :- ( catch(G, error(E, _), (write(er(I)), write(' '), write(E), nl)) -> true ; write(er(I)), write(' failed'), nl ).
main2 :- tt(1, f(X,Y,X,'a b',[1,2.5],'$VAR'(3),-(1),1+2)), tt(2, [a|b]), tt(3, []), tt(4, 'A b'), tt(6, a:b), tt(7, {a}), tt(8, f(_,_,_)), tt(9, [a,[b,c],d]), tt(10, 1.0e10), tt(11, -3), tt(13, "str"), tt(14, 'don''t'), tt(15, (a:-b,c)), tt(16, f(g(h(_)))), tt(17, '$VAR'(_)),
    to(1, 'A b', [quoted(true)]), to(2, f('A b',[x,'Y'],'it''s','[]',[]), [quoted(true), ignore_ops(true)]), to(3, '$VAR'(27), [numbervars(true)]), to(4, f('$VAR'(1),'$VAR'(30)), [numbervars(true)]), to(5, f('$VAR'(1)), []), to(6, f('$VAR'(1)), [quoted(true)]), to(7, [a,b], [ignore_ops(true)]), to(8, [a,b], [ignore_ops(canonical)]), to(9, 'hello', [quoted(true)]), to(10, 'Hello', [quoted(false)]),
    tc(1, f(a,_)), tc(2, [a|b]), tc(3, abc),
    er(1, term_to_atom(f, _, [bad(1)])), er(2, term_to_atom(f, _, [quoted(maybe)])), er(3, term_to_atom(f, _, _)), er(4, term_to_atom(f, _, foo)),
    write(done), nl.
ia :- myappend([a],[b,c],L), write(ia(L)), nl, ( catch(myappend(x,y,_), _, fail) -> write(ia_bad) ; write(ia_ok) ), nl.
main :- main1, main2, ia.
PL
cat > "$T/s.pl" <<'PL'
:- use_module(library(lists)).
main :- term_size(a(1,2,3), S), write(S), nl, term_size(f(a), S2), write(S2), nl, term_size([a,b], S3), write(S3), nl, term_size(f(_), S4), write(S4), nl,
    term_to_atom(f(a,'B c',1+2), A1), write(A1), nl, term_to_atom(T, 'g(h,Z,1+2)'), T = g(H, _, E), write(H), nl, write(E), nl.
:- initialization((main, halt)).
PL
cat > "$T/xsb.ref" <<'REF'
sz(1,1)
sz(2,1)
sz(3,4)
sz(4,1)
sz(5,2)
sz(6,2)
sz(7,5)
sz(8,1)
sz(9,3)
sz(10,5)
sz(11,6)
sz(12,3)
sz(13,3)
sz(14,15)
digits([-,2,3])
back(-23)
digits([0,.,0])
back(0.0)
digits([2,3])
back(23)
digits([1,.,5])
back(1.5)
caught(syntax_error([1,a]))
no
ok
caught(syntax_error([]))
no
caught(type_error(digit,[10]))
no
caught(type_error(list,foo))
no
caught(syntax_error([5,.,0,0,F]))
no
acyclic
1
2
none
12
1 a
2 b
1 c
done
tt(1) f(_h0,_h1,_h0,a b,[1,2.5],$VAR(3),-(1),+(1,2))
tt(2) .(a,b)
tt(3) []
tt(4) A b
tt(6) :(a,b)
tt(7) {}(a)
tt(8) f(_h0,_h1,_h2)
tt(9) [a,[b,c],d]
tt(10) 10000000000.0
tt(11) -3
tt(13) [115,116,114]
tt(14) don't
tt(15) :-(a,,(b,c))
tt(16) f(g(h(_h0)))
tt(17) $VAR(_h0)
to(1) 'A b'
to(2) f('A b','.'(x,'.'('Y',[])),'it''s',[],[])
to(3) BB
to(4) f(B,EB)
to(5) f($VAR(1))
to(6) f('$VAR'(1))
to(7) .(a,.(b,[]))
to(8) [a,b]
to(9) hello
to(10) Hello
tc(1) [102,40,97,44,95,104,48,41]
tc(2) [46,40,97,44,98,41]
tc(3) [97,98,99]
er(1) domain_error(write_option,bad(1))
er(2) domain_error(write_option,quoted(maybe))
er(3) instantiation_error
er(4) type_error(list,foo)
done
ia([a,b,c])
ia_ok
REF
cat > "$T/swi.ref" <<'REF'
4
2
6
2
f(a,'B c',1+2)
h
1+2
REF
recut() { cmp -s "$T/$1.out" "$T/$1.ref" || { echo "⛔ REFUSED(2) [$GATE_NAME]: $2 no longer prints the carried $1.ref -- re-cut it from the oracle, never from SCRIP"; diff "$T/$1.ref" "$T/$1.out" | head -4; exit 2; }; }
if xb="$(xsb_bin 2>/dev/null)"; then ( cd "$T" && timeout -k 5 60 "$xb" --noprompt --quietload --nobanner -e "consult(w), main, halt." < /dev/null 2>/dev/null | grep -v '^\[' > xsb.out ); recut xsb "XSB 5.0.0"; fi
if command -v swipl > /dev/null; then ( cd "$T" && timeout -k 5 60 swipl -q s.pl < /dev/null > swi.out 2>/dev/null ); recut swi "swipl"; fi
{ echo ':- compiler_options([]).'; echo ':- op(1050, fy, import).'; echo ':- op(1040, xfx, from).'; echo ':- op(1045, xfx, as).'; cat "$T/w.pl"; echo ':- initialization((main, halt)).'; } > "$T/x.pl"
fail=0
arm() {
    local name=$1 src=$2 ref=$3
    ( cd "$T" && timeout -k 5 30 "$SCRIP" "$src" < /dev/null > "$name.m3" 2>&1 ); local rc3=$?
    if cmp -s "$T/$name.m3" "$T/$ref"; then echo "  ok   ($name m3) the witness prints $ref"; else echo "  FAIL ($name m3) rc=$rc3, first difference:"; diff "$T/$ref" "$T/$name.m3" | head -6 | sed 's/^/         /'; fail=1; fi
    if ( cd "$T" && "$SCRIP" --compile --out="$name.s" "$src" < /dev/null > /dev/null 2>&1 && gcc -o "$name.bin" "$name.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> /dev/null ); then
        ( cd "$T" && timeout -k 5 30 "./$name.bin" < /dev/null > "$name.m4" 2>&1 ); local rc4=$?
        if cmp -s "$T/$name.m4" "$T/$ref"; then echo "  ok   ($name m4) the same, from the standalone build"; else echo "  FAIL ($name m4) rc=$rc4, first difference:"; diff "$T/$ref" "$T/$name.m4" | head -6 | sed 's/^/         /'; fail=1; fi
    else echo "  FAIL ($name m4) the witness did not compile or link in mode 4"; fail=1; fi
}
arm xsb x.pl xsb.ref
arm swi s.pl swi.ref
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: m3 and m4 answer term_size/2, number_digits/2, is_acyclic/1, do_all/1,2 and term_to_atom/term_to_codes as XSB, and a SWI program keeps swipl's term_size/2"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1
