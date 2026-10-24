#!/bin/bash
# test_gate_pl_a_float_literal_past_the_double_range_reads_as_syntax_error_float_overflow_unless_the_flag_is_infinity.sh -- THE READER'S FLOAT OVERFLOW (ceo CEO-1959; row
# prolog-swi-core-test-read-every-case-agrees-with-swipl-in-both-modes-ceo-1664, SWI core/test_read.pl read_numbers:float_overflow#1). A decimal float literal that does not fit a
# double ('1.797693134862316e+308', 1.0e999, 2.5e400) is syntax_error(float_overflow) from term_string/3, term_to_atom/2 and atom_to_term/3 while the flag float_overflow is
# `error` (its default); under `infinity` it reads 1.0Inf; the largest double and the spelled 1.0Inf are literals that always read. SCRIP read every such literal as inf.
# The program is the witness and its ref was cut from swipl 10.1.5 (/home/resources/swipl-mon/bin/swipl) -- swipl 9.0.4 raises the error under `infinity` too, an oracle defect
# its upstream has fixed (EXCLUDED_CASES.tsv, core/test_read.pl read_numbers:float_overflow#2).
# rc 0 both modes equal the swipl-cut ref; rc 1 a mode differs; rc 2 cannot measure (no ./scrip, or no witness runner).
HERE="$(cd "$(dirname "$0")" && pwd)"
T="$HERE/../../.scratch/fovf-$$"; mkdir -p "$T"; trap 'rm -rf "$T"' EXIT
cat > "$T/fovf.pl" <<'PL'
:- initialization(main).
show(G) :- catch((G -> true ; write(failed), nl), error(E, _), (writeq(E), nl)).
main :-
    show((term_string(F1, '1.797693134862316e+308', []), writeq(F1), nl)),
    show((term_to_atom(T1, '1.0e999'), writeq(T1), nl)),
    show((atom_to_term('foo(2.5e400)', T2, _), writeq(T2), nl)),
    current_prolog_flag(float_overflow, Old), writeq(Old), nl,
    set_prolog_flag(float_overflow, infinity),
    show((term_string(F2, '1.797693134862316e+308', []), writeq(F2), nl)),
    set_prolog_flag(float_overflow, Old),
    show((term_string(F3, '1.7976931348623157e+308', []), writeq(F3), nl)),
    show((term_string(F4, '1.0Inf', []), writeq(F4), nl)).
PL
cat > "$T/fovf.ref" <<'REF'
syntax_error(float_overflow)
syntax_error(float_overflow)
syntax_error(float_overflow)
error
1.0Inf
1.7976931348623157e+308
1.0Inf
REF
cd "$HERE/../../SCRIP" 2>/dev/null || { echo "REFUSE(2): no SCRIP beside the harness"; exit 2; }
out="$(bash "$HERE/test_witness_both_modes.sh" "$T/fovf.pl" "$T/fovf.ref" 2>&1)"; rc=$?
echo "$out" | tail -3
case $rc in 0) echo "GATE OK -- both modes read an out-of-range float literal as syntax_error(float_overflow) and honour the flag, as swipl"; exit 0;; 2) echo "REFUSE(2): the witness runner could not measure"; exit 2;; *) echo "GATE FAIL -- a float literal past the double range does not read as swipl reads it"; exit 1;; esac
