#!/usr/bin/env bash
# test_gate_pl_xsb_builtins_term_size_number_digits_is_acyclic_do_all_answer_as_xsb.sh -- XSB'S OWN BUILTINS, AS XSB ANSWERS THEM (hq_icon 2026-10-28, row prolog-xsbtests-to-100-the-58-failing-programs-ceo-1926; ARCH-PROLOG-DIALECTS.md sec 5, THE CONFLICTING BUILTINS live in xsb_builtins.pl).
#
# term_size/2 (XSB's term_sizew: an atom, an integer, a variable or [] is 1, a float 4, a compound or list cell 1 plus its arguments' sizes), number_digits/2 (digits as the integers
# 0 to 9, '-' '.' 'e' '+' as atoms; syntax_error and type_error(digit|list|number) carry the whole list or the culprit as XSB raises them), is_acyclic/1 and do_all/1,2 with if_none
# (findall over the variables Gen and Do share, sorted, once each) are XSB's, measured on XSB 5.0.0. xsb_builtins is selected ONLY in the XSB dialect (prolog_parse.c
# pl_lib_dialect_ok), so its term_size/2 replaces library(terms)' there (the generator's SHADOWS row) and a SWI program keeps swipl's count: arm swi.
#
# THE REFS ARE THE ORACLES' OUTPUT, cut when the gate was written: XSB 5.0.0 (xsb_bin) and swipl 9; each is re-cut when its oracle is on the box and the gate refuses rc=2 on disagreement.
# RED BEFORE (measured on SCRIP 44274bf58, hq_icon 2026-10-28): term_size, number_digits, is_acyclic and do_all raised existence_error or counted SWI's cells (xsb_tests prolog_tests_test_term_size
# read 200/300/20 for 101/201/15, prolog_tests_n2c lacked number_digits). GREEN AFTER: m3 and m4 byte-identical to XSB's 42 lines, and the SWI program byte-identical to swipl's 4.
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
:- op(1150, fx, do_all).
p(1,a). p(2,b). p(1,c).
sz(I, T) :- term_size(T, S), write(sz(I, S)), nl.
nd(N) :- number_digits(N, L), write(digits(L)), nl, number_digits(M, L), write(back(M)), nl.
ne(L) :- ( catch(number_digits(_, L), error(E, _), (write(caught(E)), nl, fail)) -> write(ok), nl ; write(no), nl ).
pr(X, Y) :- write(X), write(' '), write(Y), nl.
main :- sz(1,a), sz(2,1), sz(3,1.5), sz(4,_), sz(5,f(a)), sz(6,f(_)), sz(7,f(1.5)), sz(8,[]), sz(9,[a]), sz(10,[a,b]), sz(11,[1.5]), sz(12,f(a,b)), sz(13,f(f(a))), sz(14,[a,1,_,f(a),1.1]),
    nd(-23), nd(0.0), nd(23), nd(1.5), ne([1,a]), ne([1,'.']), ne([]), ne([10]), ne(foo), ne([5,'.',0,0,'F']),
    ( is_acyclic(f(a,[b])) -> write(acyclic), nl ; write(cyclic), nl ),
    do_all(p(X,_), (write(X), nl)), do_all(p(9,Y), if_none(write(Y), (write(none), nl))), do_all(p(X1,_), if_none(write(X1), write(none))), nl,
    ( do_all (p(X2,Y2), pr(X2,Y2)) ), write(done), nl.
PL
cat > "$T/s.pl" <<'PL'
:- use_module(library(lists)).
main :- term_size(a(1,2,3), S), write(S), nl, term_size(f(a), S2), write(S2), nl, term_size([a,b], S3), write(S3), nl, term_size(f(_), S4), write(S4), nl.
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
REF
cat > "$T/swi.ref" <<'REF'
4
2
6
2
REF
recut() { cmp -s "$T/$1.out" "$T/$1.ref" || { echo "⛔ REFUSED(2) [$GATE_NAME]: $2 no longer prints the carried $1.ref -- re-cut it from the oracle, never from SCRIP"; diff "$T/$1.ref" "$T/$1.out" | head -4; exit 2; }; }
if xb="$(xsb_bin 2>/dev/null)"; then ( cd "$T" && timeout -k 5 60 "$xb" --noprompt --quietload --nobanner -e "consult(w), main, halt." < /dev/null 2>/dev/null | grep -v '^\[' > xsb.out ); recut xsb "XSB 5.0.0"; fi
if command -v swipl > /dev/null; then ( cd "$T" && timeout -k 5 60 swipl -q s.pl < /dev/null > swi.out 2>/dev/null ); recut swi "swipl"; fi
{ echo ':- compiler_options([]).'; cat "$T/w.pl"; echo ':- initialization((main, halt)).'; } > "$T/x.pl"
fail=0
arm() {
    local name=$1 src=$2 ref=$3
    ( cd "$T" && timeout -k 5 30 "$SCRIP" "$src" < /dev/null > "$name.m3" 2>&1 ); local rc3=$?
    if cmp -s "$T/$name.m3" "$T/$ref"; then echo "  ok   ($name m3) the witness prints $ref"; else echo "  FAIL ($name m3) rc=$rc3, first difference:"; diff "$T/$ref" "$T/$name.m3" | head -6 | sed 's/^/         /'; fail=1; fi
    if ( cd "$T" && "$SCRIP" --compile -o "$name.s" "$src" < /dev/null > /dev/null 2>&1 && gcc -o "$name.bin" "$name.s" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2> /dev/null ); then
        ( cd "$T" && timeout -k 5 30 "./$name.bin" < /dev/null > "$name.m4" 2>&1 ); local rc4=$?
        if cmp -s "$T/$name.m4" "$T/$ref"; then echo "  ok   ($name m4) the same, from the standalone build"; else echo "  FAIL ($name m4) rc=$rc4, first difference:"; diff "$T/$ref" "$T/$name.m4" | head -6 | sed 's/^/         /'; fail=1; fi
    else echo "  FAIL ($name m4) the witness did not compile or link in mode 4"; fail=1; fi
}
arm xsb x.pl xsb.ref
arm swi s.pl swi.ref
[ "$fail" = 0 ] && { echo "✅ GATE PASS [$GATE_NAME]: m3 and m4 answer term_size/2, number_digits/2, is_acyclic/1 and do_all/1,2 as XSB, and a SWI program keeps swipl's term_size/2"; exit 0; }
echo "⛔ GATE RED [$GATE_NAME]"; exit 1
