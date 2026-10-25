#!/bin/bash
# test_gate_pl_number_chars_codes_and_atom_number_read_a_zero_quote_character_literal_in_any_script_as_swipl.sh -- A 0'C CHARACTER-CODE LITERAL IN TEXT (hq_packages, ceo CEO-1959; found on Trealla's
# issues_test0763, issues_test0779 and issues_test0903: number_chars(N, "0'<U+1D11E>") raised syntax_error(illegal_number) where swipl answers 119070).
# THE REGRESSION (mine, 367370215): pl_parse_number sent every text carrying a non-ASCII byte through the Unicode-decimal-digit converter (pl_digits_to_ascii), which refuses a text that is not all digits, so
# number_chars/number_codes/atom_number refused 0'e-acute, 0'<euro>, 0'<U+1D11E> and 0'<Arabic-Indic digit>; term_to_atom and the source reader (the lexer) were not on that road and kept reading them.
# CURED: a text that begins (after layout) with 0' is a character literal and skips the digit conversion. The witness has the literals in four widths (1, 2, 3 and 4 UTF-8 bytes), the quote itself, a
# bare 0', a 0' with two characters (syntax error in all three number readers, operator_expected in term_to_atom), a 0x number and a decimal one as controls, and number_codes/number_chars over a string text.
# The ref was cut from swipl 9.0.4 and swipl 10.1.5 reads it byte-identically. Divergences of the same readers that are NOT this regression and are not in the witness: 0'\n as text (swipl refuses it in
# the three number readers, SCRIP reads it), leading blanks in atom_number, writeq of an atom that starts with a Unicode digit (swipl quotes it), term_to_atom of 0' followed by a space.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/zqc-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/zqc.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
r(G, R) :- catch(( call(G) -> R = yes ; R = no ), error(syntax_error(S), _), R = syntax(S)).
one(A) :-
    r(atom_number(A, N1), R1), ( R1 == yes -> true ; N1 = - ),
    atom_codes(A, Cs), r(number_codes(N2, Cs), R2), ( R2 == yes -> true ; N2 = - ),
    atom_chars(A, Hs), r(number_chars(N3, Hs), R3), ( R3 == yes -> true ; N3 = - ),
    r(term_to_atom(N4, A), R4), ( R4 == yes -> true ; N4 = - ),
    writeq(A-[R1/N1, R2/N2, R3/N3, R4/N4]), nl.
main :- forall(member(A, ['0\'a', '0\'é', '0\'€', '0\'𝄞', '0\'\'\'', '0\'', '0\'ab', '0\'éa', '0\'𝄞𝄞', '0\'٣', '0x1F', '12']), one(A)),
    forall(member(S, ["0'é", "0'𝄞", "0'a"]), ( number_codes(N, S), writeq(N), nl )),
    forall(member(S, ["0'é", "0'€"]), ( string_chars(S, Hs), number_chars(N, Hs), writeq(N), nl )).
PL
cat > "$T/zqc.ref" <<'REF'
'0\'a'-[yes/97,yes/97,yes/97,yes/97]
'0\'é'-[yes/233,yes/233,yes/233,yes/233]
'0\'€'-[yes/8364,yes/8364,yes/8364,yes/8364]
'0\'𝄞'-[yes/119070,yes/119070,yes/119070,yes/119070]
'0\'\'\''-[yes/39,yes/39,yes/39,yes/39]
'0\''-[no/(-),syntax(illegal_number)/(-),syntax(illegal_number)/(-),syntax(end_of_file)/(-)]
'0\'ab'-[no/(-),syntax(illegal_number)/(-),syntax(illegal_number)/(-),syntax(operator_expected)/(-)]
'0\'éa'-[no/(-),syntax(illegal_number)/(-),syntax(illegal_number)/(-),syntax(operator_expected)/(-)]
'0\'𝄞𝄞'-[no/(-),syntax(illegal_number)/(-),syntax(illegal_number)/(-),syntax(operator_expected)/(-)]
'0\'٣'-[yes/1635,yes/1635,yes/1635,yes/1635]
'0x1F'-[yes/31,yes/31,yes/31,yes/31]
'12'-[yes/12,yes/12,yes/12,yes/12]
233
119070
97
233
8364
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/zqc.pl" "$T/zqc.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes read a 0'C character literal of any width as swipl does in number_chars, number_codes, atom_number and term_to_atom"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a number reader refused or misread a 0'C character literal"; exit 1;; esac
