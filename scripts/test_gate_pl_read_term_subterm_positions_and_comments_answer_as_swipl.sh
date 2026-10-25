#!/bin/bash
# test_gate_pl_read_term_subterm_positions_and_comments_answer_as_swipl.sh
# -- READ_TERM'S subterm_positions AND comments (ceo CEO-1959; ARCH-PROLOG-DATABASE.md sec 11; row prolog-swi-core-test-read-every-case-agrees-with-swipl-in-both-modes-ceo-1664, SWI core/test_read.pl
# 16 valid_position_* cases, position#1, pos_block). The byte extent of every term is a field of every tree_t node (start, end: the two padding holes, sizeof unchanged), the lexer's token carries
# its start and end, the parser's reduce stamps each node from its first token and its last consumed token, and read_term builds the position term in one walk over the tree: From-To, string_position
# for every double_quotes form, list_position, brace_term_position, term_position (functor token found by lexing the gap for an infix or postfix operator), minus the 7 bytes of the reader's
# '$rd'(( wrapper, in CHARACTER offsets. comments(C) lists '$stream_position'(Char, Line0, Column, 0)-"text" for each skipped comment, as swipl does. The program is the witness (forty-two reads) and
# its ref was cut from swipl 10.1.5 (/home/resources/swipl-mon/bin/swipl); swipl 9.0.4 prints the same lines. NOT HERE, and not in the witness: parentheses_term_position, a() zero-arity compounds, dict
# positions, the - 1 versus -1 reading, and double_quotes=codes of a non-ASCII string (SCRIP yields the UTF-8 bytes).
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, or no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/posw-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/posw.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
p(S) :- catch(( term_string(_, S, [subterm_positions(P), comments(C)]), print(S-P-C), nl ), error(E, _), (print(S-err(E)), nl)).
q(Flag, S) :- current_prolog_flag(double_quotes, Old), set_prolog_flag(double_quotes, Flag),
    catch(( term_string(_, S, [subterm_positions(P)]), print(Flag-S-P), nl ), error(E, _), (print(Flag-err(E)), nl)),
    set_prolog_flag(double_quotes, Old).
main :-
    p("Var"), p("'Atom'"), p(" 123 "), p(" -123.45     "), p(" [   ] "), p("foo"),
    p(" { foo, bar } "), p(" [ foo, [bar] ] "), p(" [ foo,123 | bar] "), p("[X|Xs]"), p("{x}"), p("[a,b,c]"),
    p("a(X,y)"), p("call(X):[adder]"), p("f(a, g(b, c), 'q r')"), p("'a b'(x)"), p("f(-1)"),
    p("1+2*3"), p("- a"), p("-a"), p("\\+ foo(bar)"), p("a:-b,c"), p("a = b"), p("p :- q ; r"),
    p("\"abc\""), p("é+ü"), p("'é ü'(ö)"), p("[é, ü|ö]"),
    q(string, "\"abc\""), q(codes, "\"abc\""), q(chars, "\"abc\""), q(atom, "\"abc\""), q(codes, "f(\"é\", x)"),
    p("%hello\ntrue"), p("a % c1\n+ b"), p("/* c2 */ foo"), p("foo /* c3 */"), p("f(a, /* in */ b)"),
    p("  % lead\n\n  % second\n x"), p("é = % ü\nx"), p("/* é\n ü */ y"), p("x").
PL
cat > "$T/posw.ref" <<'REF'
"Var"-(0-3)-[]
"'Atom'"-(0-6)-[]
" 123 "-(1-4)-[]
" -123.45     "-(1-8)-[]
" [   ] "-(1-6)-[]
"foo"-(0-3)-[]
" { foo, bar } "-brace_term_position(1,13,term_position(3,11,6,7,[3-6,8-11]))-[]
" [ foo, [bar] ] "-list_position(1,15,[3-6,list_position(8,13,[9-12],none)],none)-[]
" [ foo,123 | bar] "-list_position(1,17,[3-6,7-10],13-16)-[]
"[X|Xs]"-list_position(0,6,[1-2],3-5)-[]
"{x}"-brace_term_position(0,3,1-2)-[]
"[a,b,c]"-list_position(0,7,[1-2,3-4,5-6],none)-[]
"a(X,y)"-term_position(0,6,0,1,[2-3,4-5])-[]
"call(X):[adder]"-term_position(0,15,7,8,[term_position(0,7,0,4,[5-6]),list_position(8,15,[9-14],none)])-[]
"f(a, g(b, c), 'q r')"-term_position(0,20,0,1,[2-3,term_position(5,12,5,6,[7-8,10-11]),14-19])-[]
"'a b'(x)"-term_position(0,8,0,5,[6-7])-[]
"f(-1)"-term_position(0,5,0,1,[2-4])-[]
"1+2*3"-term_position(0,5,1,2,[0-1,term_position(2,5,3,4,[2-3,4-5])])-[]
"- a"-term_position(0,3,0,1,[2-3])-[]
"-a"-term_position(0,2,0,1,[1-2])-[]
"\\+ foo(bar)"-term_position(0,11,0,2,[term_position(3,11,3,6,[7-10])])-[]
"a:-b,c"-term_position(0,6,1,3,[0-1,term_position(3,6,4,5,[3-4,5-6])])-[]
"a = b"-term_position(0,5,2,3,[0-1,4-5])-[]
"p :- q ; r"-term_position(0,10,2,4,[0-1,term_position(5,10,7,8,[5-6,9-10])])-[]
"\"abc\""-string_position(0,5)-[]
"é+ü"-term_position(0,3,1,2,[0-1,2-3])-[]
"'é ü'(ö)"-term_position(0,8,0,5,[6-7])-[]
"[é, ü|ö]"-list_position(0,8,[1-2,4-5],6-7)-[]
string-"\"abc\""-string_position(0,5)
codes-"\"abc\""-string_position(0,5)
chars-"\"abc\""-string_position(0,5)
atom-"\"abc\""-string_position(0,5)
codes-"f(\"é\", x)"-term_position(0,9,0,1,[string_position(2,5),7-8])
"%hello\ntrue"-(7-11)-['$stream_position'(0,0,0,0)-"%hello"]
"a % c1\n+ b"-term_position(0,10,7,8,[0-1,9-10])-['$stream_position'(2,0,2,0)-"% c1"]
"/* c2 */ foo"-(9-12)-['$stream_position'(0,0,0,0)-"/* c2 */"]
"foo /* c3 */"-(0-3)-['$stream_position'(4,0,4,0)-"/* c3 */"]
"f(a, /* in */ b)"-term_position(0,16,0,1,[2-3,14-15])-['$stream_position'(5,0,5,0)-"/* in */"]
"  % lead\n\n  % second\n x"-(22-23)-['$stream_position'(2,0,2,0)-"% lead",'$stream_position'(12,2,2,0)-"% second"]
"é = % ü\nx"-term_position(0,9,2,3,[0-1,8-9])-['$stream_position'(4,0,4,0)-"% ü"]
"/* é\n ü */ y"-(11-12)-['$stream_position'(0,0,0,0)-"/* é\n ü */"]
"x"-(0-1)-[]
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/posw.pl" "$T/posw.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes answer read_term's subterm_positions and comments as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- subterm_positions or comments do not answer as swipl"; exit 1;; esac
