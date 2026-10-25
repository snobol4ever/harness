#!/bin/bash
# test_gate_pl_a_number_in_a_non_ascii_decimal_script_reads_as_the_number_in_one_script_only_as_swipl.sh -- THE READER'S UNICODE DECIMAL DIGITS (ceo CEO-1959; SWI core/test_unicode.pl numbers:read#1 and #2).
# swipl reads a number written in any Unicode decimal script (Nd: Arabic-Indic, Devanagari, ...) as the number: 0123456789 as ٠١٢٣٤٥٦٧٨٩, the rational 123456789r23, the float ١٢.٣٤٥e٢, digit groups with _ or a space -- under one rule: ALL
# the digits of one number (integer, fraction, exponent, rational denominator, separators) come from ONE script, so 12٣, ٣12, 3e٤, ٣r4 and 1_٠٠٠ are not one number (syntax error), and a minus folds into the next token only when it
# starts with an ASCII digit (-٣ is -(3), -3 is the integer -3). The lexer's number states looked at ASCII bytes only, so SCRIP read every such literal as an atom. The witness reads each form from the source and through term_string/2;
# term_string/2 and term_to_atom/2 also take a rational as their text (a rational is read back from its 1r3 text), which needed the runtime's text coercion to know rationals; errors are normalised to the word syntax and terms to their =.. shape, so only the digit rules are compared (the error NAME, writeq of -(3) and the list-cell functor are other, older rows). The ref was cut from swipl 9.0.4 and
# swipl 10.1.5 reads it byte-identically.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, or no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/ndig-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/ndig.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
kind(X, K) :- ( integer(X) -> K = int ; float(X) -> K = float ; rational(X) -> K = rat ; atom(X) -> K = atom ; string(X) -> K = string ; K = cmp ).
shape(T, float(R)) :- float(T), !, R is round(T * 100000).
shape(T, K-T) :- \+ compound(T), !, kind(T, K).
shape(T, list(L)) :- is_list(T), !, findall(S, ( member(A, T), shape(A, S) ), L).
shape(T, L) :- T =.. [F|As], findall(S, ( member(A, As), shape(A, S) ), Ss), L = [F|Ss].
t(S) :- catch(( term_string(T, S), shape(T, Sh), writeq(Sh), nl ), error(syntax_error(_), _), ( writeq(syntax), nl )).
main :-
    A = ٠١٢٣٤٥٦٧٨٩, B = ٠١٢٣٤٥٦٧٨٩r٢٣, C = ١٢.٣٤٥e٢, D = १२३, E is ٣ + ٤, X = f(٧, [٣,٤], -٣, ٣ - ١),
    shape([A, B, C, D, E], S1), writeq(S1), nl, shape(X, S2), writeq(S2), nl,
    term_string(N1, ٠١٢٣٤٥٦٧٨٩r٢٣), shape(N1, S3), writeq(S3), nl, term_string(N2, 1r3), shape(N2, S4), writeq(S4), nl, term_to_atom(N3, 123456789r23), shape(N3, S5), writeq(S5), nl,
    forall(member(S, ["٠١٢٣٤٥٦٧٨٩", "٠١٢٣٤٥٦٧٨٩r٢٣", "١٢.٣٤٥", "١٢.٣٤٥e٢", "١٢.٣٤٥e-٢", "१२३", "٣ + 4", "٣+٤", "٣_٤", "٣ ٤", "٣.٤e5", "٣.٤e٥", "٣r٤", "٣r4",
                       "3e٤", "٣e4", "1_٠٠٠", "12٣", "٣12", "3 ٤", "-٣", "- ٣", "-3", "a-٣", "1-٣", "[-٣]", "f(-٣)", "٣-١", "a٠", "'x٠'", "\"٠١\"", "٠٠٠", "١٢٣٤٥٦٧٨٩٠١٢٣٤٥٦٧٨٩٠١٢٣٤٥٦٧٨٩٠"]), t(S)).
PL
cat > "$T/ndig.ref" <<'REF'
list([int-123456789,rat-123456789r23,float(123450000),int-123,int-7])
[f,int-7,list([int-3,int-4]),[-,int-3],[-,int-3,int-1]]
rat-123456789r23
rat-1r3
rat-123456789r23
int-123456789
rat-123456789r23
float(1234500)
float(123450000)
float(12345)
int-123
[+,int-3,int-4]
[+,int-3,int-4]
int-34
int-34
syntax
float(34000000000)
rat-3r4
syntax
syntax
syntax
syntax
syntax
syntax
syntax
[-,int-3]
[-,int-3]
int- -3
[-,atom-a,int-3]
[-,int-1,int-3]
list([[-,int-3]])
[f,[-,int-3]]
[-,int-3,int-1]
atom-a٠
atom-x٠
string-"٠١"
int-0
int-123456789012345678901234567890
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/ndig.pl" "$T/ndig.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes read a number in a non-ASCII decimal script as swipl does, one script per number"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a Unicode-digit number does not read as swipl reads it"; exit 1;; esac
