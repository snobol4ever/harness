#!/usr/bin/env bash
# test_gate_pl_text_and_quoted_tokens_read_as_swipl.sh
#
# THE ROWS: prolog-a-one-character-string-evaluates-to-its-character-code-in-arithmetic-as-swipl-does-eliza-demo and
# prolog-a-raw-tab-inside-a-quoted-atom-string-or-backquoted-token-is-a-parse-error-where-swipl-reads-it-eliza-demo (hq_pascal's,
# found vendoring ELIZA; hq_prolog 2026-10-10), and the code-point defect found curing them: a double-quoted text read as codes or
# chars, a backquoted text and a DCG string terminal were built BYTE by byte, so "é" read [195,169] where swipl reads [233].
# THE CURES: the arithmetic evaluator (by_name_dispatch.c pl_ax_eval) evaluates a string of exactly one character to its code; the
# lexer (prolog_lex.c) reads a raw tab inside a quoted token as text, and refuses it only under set_prolog_flag(iso, true), ISO's
# reading, which the Logtalk ISO suite runs under; u8_decode moves to prolog_lex.h and the three text-to-list sites
# (prolog_parse.c's backquote token and dcg_dq_codes, prolog_lower.c's prolog_dq_lower) decode UTF-8 code points.
#
# THE ARM: 12 lines -- codes, chars, a DCG terminal and a backquoted text holding non-ASCII characters; a one-character string in
# is/2, in a comparison and in =:=; an atom is still not evaluable; a raw tab inside '...', "..." and `...` -- the ref cut from
# SWI-Prolog 9.0.4 with each clause's double_quotes flag set explicitly, in both modes. rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/g.pl" <<'PL'
:- set_prolog_flag(double_quotes, codes).
w1("é€a😀").
:- set_prolog_flag(double_quotes, chars).
w2("é€a").
:- set_prolog_flag(double_quotes, codes).
q --> "é", "b".
:- set_prolog_flag(double_quotes, string).
s1("A").
s2("é").
s3("z").
:- initialization(main).
main :-
  w1(A), write(A), nl, w2(B), write(B), nl, phrase(q, C), write(C), nl, X = `é€`, write(X), nl,
  s1(S1), V1 is S1 + 0, write(V1), nl, ( 66 >= S1 -> write(yes) ; write(no) ), nl,
  s2(S2), V2 is S2 * 2, write(V2), nl, s3(S3), ( S3 =:= 0'z -> write(eq) ; write(ne) ), nl,
  catch((W is a + 0, write(W)), error(E, _), write(E)), nl,
  atom_length('a	b', N1), write(N1), nl,
  atom_codes(A2, "p	q"), atom_length(A2, N2), write(N2), nl,
  atom_codes(A3, `r	s`), atom_length(A3, N3), write(N3), nl,
  halt.
PL
cat > "$D/g.ref" <<'REF'
[233,8364,97,128512]
[é,€,a]
[233,98]
[233,8364]
65
yes
466
eq
type_error(evaluable,a/0)
3
3
3
REF
( cd "$D" && timeout -k 5 60 "$B/scrip" g.pl < /dev/null > g.m3 2>&1 )
( cd "$D" && timeout -k 5 60 "$B/scrip" --compile -o g.s g.pl < /dev/null > /dev/null 2>&1 && gcc -no-pie g.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o g.bin 2>/dev/null ) || refuse "g.pl: mode 4 did not build"
( cd "$D" && timeout -k 5 60 ./g.bin < /dev/null > g.m4 2>&1 )
red=0
for m in m3 m4; do
    if cmp -s "$D/g.ref" "$D/g.$m"; then echo "  ok   $m: 12 of 12 lines read and evaluate as swipl"
    else echo "  FAIL $m: diverges from swipl:"; diff "$D/g.ref" "$D/g.$m" | head -12; red=$((red + 1)); fi
done
if [ $red -eq 0 ]; then echo "GATE PASS(0): text and quoted tokens read as swipl in both modes"; exit 0; fi
echo "GATE FAIL(1): $red of 2 mode(s) diverge"; exit 1
