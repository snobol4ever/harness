#!/bin/bash
# test_gate_pl_read_term_from_atom_of_the_atom_nil_reads_the_text_brackets_not_end_of_file.sh
# -- THE ATOM [] AS READER TEXT (ceo CEO-1959; row prolog-swi-core-test-read-every-case-agrees-with-swipl-in-both-modes-ceo-1664). term_string/3 and read_term_from_atom/3 given the atom [] as
# their text read the empty code list -- the empty text -- and answered end_of_file where swipl reads the two characters "[]" as the term []; term_string/2, term_to_atom/2 and atom_to_term/3
# already did. The program is the witness (nine reads: five entry points, a spaced nil, f([]), the brace atom and [](a)) and its ref was cut from swipl 10.1.5
# (/home/resources/swipl-mon/bin/swipl); swipl 9.0.4 prints the same nine lines.
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, or no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/nil-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/nil.pl" <<'PL'
:- use_module(library(lists)).
:- initialization(main).
p(G) :- catch((G -> true ; writeln(failed)), error(E,_), (writeq(err(E)), nl)).
main :- p((term_string(T1, '[]'), writeq(t1(T1)), nl)),
    p((term_string(T2, '[]', []), writeq(t2(T2)), nl)),
    p((term_to_atom(T3, '[]'), writeq(t3(T3)), nl)),
    p((read_term_from_atom('[]', T4, []), writeq(t4(T4)), nl)),
    p((atom_to_term('[]', T5, _), writeq(t5(T5)), nl)),
    p((term_string(T6, '[ ]', []), writeq(t6(T6)), nl)),
    p((term_string(T7, 'f([])', []), writeq(t7(T7)), nl)),
    p((term_string(T8, '{}', []), writeq(t8(T8)), nl)),
    p((term_string(T9, '[](a)', []), writeq(t9(T9)), nl)).
PL
cat > "$T/nil.ref" <<'REF'
t1([])
t2([])
t3([])
t4([])
t5([])
t6([])
t7(f([]))
t8({})
t9([](a))
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/nil.pl" "$T/nil.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes read the atom [] as the text of the term [], as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- the atom [] does not read as the term [] from every reader entry"; exit 1;; esac
