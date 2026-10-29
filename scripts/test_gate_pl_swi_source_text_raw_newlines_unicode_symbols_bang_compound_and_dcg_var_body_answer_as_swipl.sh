#!/usr/bin/env bash
# test_gate_pl_swi_source_text_raw_newlines_unicode_symbols_bang_compound_and_dcg_var_body_answer_as_swipl.sh -- SWI SOURCE TEXT THE LEXER AND THE PRELUDE USED TO REFUSE: A RAW NEWLINE INSIDE A QUOTED ITEM, A UNICODE SYMBOL AS AN ATOM,
# A NO-BREAK SPACE AS LAYOUT, !(A) AS A COMPOUND, A DCG BODY THAT IS A VARIABLE (hq_prolog 2026-10-15, row prolog-every-suite-to-100-under-tenet-ceo-1562;
# the ProRosetta crawl: abbreviations-easy, align-columns, calendar, csv-to-html-translation-1/3, strip-comments-from-a-string-1, json-pointer-1,
# generate-chess960-starting-position-1, sieve-of-eratosthenes-12, lunar-arithmetic, parsing-rpn-calculator-algorithm, odd-word-problem, balanced-ternary-2).
# THE CURE: (1) a program that carries the SWI dialect marker (a use_module/2 or module/2 directive, prolog_lower.c pl_dialect_marker) lexes a raw newline inside a
# quoted atom, string or back-quoted string as the character, as swipl 9.0.4 does (ISO source without the marker still refuses it); (2) a Unicode space (U+00A0,
# U+2000-200A, U+3000 ...) is layout and any other non-letter Unicode symbol is a symbol character, so a lone symbol like the chess king is an atom and writeq/1
# prints it unquoted; (3) a bare cut directly followed by an argument list is the compound !(A), not a cut and a parenthesis; (4) a DCG body that is a variable
# translates to phrase/3 and the prelude's '$phrase'/3 is pulled in by that reference.  A module-qualified `:- system:set_prolog_flag(double_quotes, chars)` directive
# takes effect (prolog_lower.c pl_dq_directive_mode unwraps M:Goal), which the ProRosetta headers use.
# THE ARM: one witness cut against swipl -q in this run and diffed in mode 3 and mode 4.  RED BEFORE (the parent e6febb41a): a parse error stops the witness.
# rc=0 both modes agree with swipl · rc=1 a divergence · rc=2 REFUSAL (no swipl, no build).  ~3 s.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
GATE=test_gate_pl_swi_source_text_raw_newlines_unicode_symbols_bang_compound_and_dcg_var_body_answer_as_swipl
refuse() { echo "⛔ REFUSED(2) [$GATE]: $*"; exit 2; }
command -v swipl >/dev/null 2>&1 || refuse "no swipl on PATH -- the oracle"
[ -x "$B/scrip" ] || refuse "$B/scrip is not built"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate $GATE || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/w.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
t(T, G) :- catch((call(G) -> \+ \+ (numbervars(T, 0, _), writeq(T)) ; writeq(no)), error(E, _), \+ \+ (numbervars(E, 0, _), writeq(caught(E)))), nl.
chess(♔, ♕).
chess(Q, K) :- Q = K.
bang(!(A), r(A)) :- !.
bang(X, X).
dcgv(St) --> St.
sym(X) :- X = ♔, true.
nbsp(A, B) :- A = foo, B = bar.
main :-
    t(X1, X1 = "ab
cd"),
    t(X2, X2 = 'ef
gh'),
    t(X3, X3 = `ij
kl`),
    t(L4, (L4 = "line1
line2", atom_length(L4, _))),
    t(S, (sym(S))),
    t(N, (X5 = ♔ , atom_length(X5, N))),
    t(r(A,B), nbsp(A, B)),
    t(R, bang(!(3), R)),
    t(R2, bang(!, R2)),
    t(R3, (dcgv([a], [a|T3], T3), R3 = ok)),
    t(R4, (dcgv(foo, S4, []), R4 = S4)),
    t(r(Q,K), chess(Q, K)),
    t(Len, (atom_codes('♔♕', Cs), length(Cs, Len))),
    t(Ts, (findall(X, member(X, [♔, '♕♖', a]), Ts))).
foo --> [x].
PL
( cd "$D" && timeout -k 5 30 swipl -q -t halt w.pl < /dev/null > want 2> /dev/null )
[ -s "$D/want" ] || refuse "swipl printed nothing for the witness"
( cd "$D" && timeout -k 5 30 "$B/scrip" --run w.pl < /dev/null > m3 2> m3.err )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile --out=w.s w.pl < /dev/null 2> m4.err && gcc -no-pie w.s -L"$B/out" -lscrip_rt -lm -Wl,-rpath,"$B/out" -o w 2>> m4.err && timeout -k 5 30 ./w < /dev/null > m4 2>> m4.err )
n=$(wc -l < "$D/want"); red=0
for m in m3 m4; do
    if cmp -s "$D/want" "$D/$m"; then echo "  $m GREEN: $n of $n lines as swipl"
    else echo "  $m RED: $(diff "$D/want" "$D/$m" 2>/dev/null | grep -c '^<') of $n lines differ from swipl"; diff "$D/want" "$D/$m" 2>/dev/null | head -10 | sed 's/^/    /'; red=1; fi
done
[ "$red" = 0 ] && echo "PASS $GATE"
exit "$red"
