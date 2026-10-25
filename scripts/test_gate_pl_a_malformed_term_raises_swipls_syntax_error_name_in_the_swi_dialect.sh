#!/bin/bash
# test_gate_pl_a_malformed_term_raises_swipls_syntax_error_name_in_the_swi_dialect.sh -- THE SWI SYNTAX-ERROR VOCABULARY (ceo CEO-1959, hq_packages; SWI core/test_syntax.pl op_3, op_5, quote_1, number_2).
# SCRIP raised syntax_error(cannot_start_term) for EVERY malformed text; swipl names the culprit: operator_expected (a term where an operator was due: "a b", "f(a", "[a ", "(a b)"), operator_clash (two
# non-associative operators: "a :- b :- c", "a = b = c", "fx600 fx600 1"), operator_balance (an operand missing: "1 + ", "a |", "a:-"), end_of_clause (end of text right after a separator or an opener: "f(a,", "[a|", "f("),
# cannot_start_term (a stray closer: "a )", "f(a ]"), quoted_punctuation (a comma where a term starts: "f(,a)", "[,]"), list_rest ("[a|b|c]"), illegal_number ("0x", "0b2"), end_of_file ("2'" and "0'" at the end of the
# text), end_of_file_in_quoted(Q) (an unterminated 'atom, "string or `code string), end_of_file_in_block_comment, undefined_char_escape(C) ("'\x'", "'\q'") and the atom 'Illegal \u or \U sequence'.
# The lexer's own errors carry the culprit (Token.swi); the parser names the rest from the offending token and the one before it (prolog_parse.c swi_syn: SYN_CLOSE, SYN_END, SYN_LIST, SYN_OPERAND), the reader's early
# balance check reports its reason (pl_text_is_unbalanced), and rt_pl_ball_kind1 builds a compound culprit from "name\001arg". It applies ONLY in the SWI dialect (a program holding a :- module/2 or :- use_module/1
# marker), so ISO and GNU programs see the generic atom they always saw. The witness is 73 malformed texts through term_string/2, the culprit printed; the ref was cut from swipl 9.0.4 and swipl 10.1.5 reads it
# byte-identically. NOT in it, older rows: a NUL inside a text ("\000\x" truncates a C string), dict and . terms, the punct(',','.') oddity of "a,", writeq spacing of - - 1.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/synn-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/synn.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
:- op(600, fx, fx600).
t(S) :- catch(( term_string(T, S), ( T = _ -> writeq(ok) ; true ) ), error(E, _), ( E = syntax_error(M) -> writeq(M) ; writeq(other) )), nl.
main :- forall(member(S, ["a:-b:-c", "fx600 fx600 1", "'\\x'", "'\\q'", "'\\u12'", "'\\U1234567'", "2'", "0'", "a b", "f(a", "f(a))", "[a|b|c]", "(a", "'abc", "\"abc", "foo bar baz", "X = = Y", "a :- :- b", "{a", "f(,)", "0x", "0b2", "1e", ")", "a 1", "a \"s\"", "a X", "a (", "a [", "a {", "a )", "a ]", "a }", "a |", "f(a b)", "f(a ]", "f(a }", "f(a,", "[a b]", "[a ", "[a,", "[a|", "[a|b", "{a b}", "{a", "(a b)", "(a ]", "f(", "a = b = c", "1 + ", "a ? b", "f(a)(b)", "X Y", "'a' 'b'", "\"a\" \"b\"", "f(a) g(b)", "a$", "!a", "a !", "[]a", "{}a", "a[]", "(a)(b)", "foo(", "foo(a)b", "f(,a)", "f(a,)", "[,]", "[a,]", "{,}", "a:-", "a b c d", "a :- b :- c"]), t(S)).
PL
cat > "$T/synn.ref" <<'REF'
operator_clash
operator_clash
undefined_char_escape(x)
undefined_char_escape(q)
'Illegal \\u or \\U sequence'
'Illegal \\u or \\U sequence'
end_of_file
end_of_file
operator_expected
operator_expected
cannot_start_term
list_rest
operator_expected
end_of_file_in_quoted('\'')
end_of_file_in_quoted('"')
operator_expected
operator_expected
operator_clash
operator_expected
quoted_punctuation
illegal_number
illegal_number
operator_expected
cannot_start_term
operator_expected
operator_expected
operator_expected
operator_expected
operator_expected
operator_expected
cannot_start_term
cannot_start_term
cannot_start_term
operator_balance
operator_expected
cannot_start_term
cannot_start_term
end_of_clause
operator_expected
operator_expected
end_of_clause
end_of_clause
operator_expected
operator_expected
operator_expected
operator_expected
cannot_start_term
end_of_clause
operator_clash
operator_balance
operator_expected
operator_expected
operator_expected
operator_expected
operator_expected
operator_expected
operator_expected
operator_expected
operator_expected
operator_expected
operator_expected
operator_expected
operator_expected
end_of_clause
operator_expected
quoted_punctuation
cannot_start_term
quoted_punctuation
cannot_start_term
quoted_punctuation
operator_balance
operator_expected
operator_clash
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/synn.pl" "$T/synn.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes name a malformed term's syntax error as swipl does, in the SWI dialect"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a malformed term raises a syntax error whose name differs from swipl's"; exit 1;; esac
