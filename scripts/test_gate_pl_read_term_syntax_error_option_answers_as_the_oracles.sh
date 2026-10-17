#!/usr/bin/env bash
# test_gate_pl_read_term_syntax_error_option_answers_as_the_oracles.sh -- read_term/2,3 honour the syntax-error option in
# both spellings, both modes (row prolog-read-term-accepts-the-syntax-error-option, minted by the ceo 2026-10-02 from the
# Logtalk 3.103.0-b01 run: the GNU adapter passes syntax_error(error), and SCRIP refused it with
# domain_error(read_option, syntax_error(error))).
#
# WHAT THIS PINS, CUT 2026-10-03 FROM gprolog 1.4.5 (the GNU rows) AND swipl 9.0.4 (the SWI rows), the exact program below:
#   GNU syntax_error(V): error raises (the ISO default), fail fails, warning prints one stdout line and fails; any other V
#     is domain_error(read_option, syntax_error(V)) and an unbound V is instantiation_error -- both BEFORE the stream moves,
#     so the next read raises on the same bad term.
#   SWI syntax_errors(V): error raises, fail and quiet fail, dec10 skips the bad term and returns the next one.
#   After a failed read the stream sits past the bad term's end token, so the next read returns the following term.
# ⛔ THE CONTROLS ARE THE POINT: variable_names(_) keeps the default (raise) on the option road, a good term under fail and
#   dec10 is read back (a cure that fails every read passes the fail rows alone), and a term cut by end of file obeys the
#   option and then reads end_of_file (dec10 must not spin there).
# ⛔ THE WARNING TEXT IS NOT GRADED: gprolog names file, line and char, which SCRIP's reader does not know; the gate grades
#   that the warning row prints exactly one line beginning "warning: syntax error" on stdout and the fail row prints none.
# FAIL-ONCE: on the pre-cure binary every syntax_error row read D (the option was refused) and syntax_errors(fail|quiet|dec10)
#   read as error.
# Usage: bash ../harness/scripts/test_gate_pl_read_term_syntax_error_option_answers_as_the_oracles.sh
set -uo pipefail
GATE_NAME=test_gate_pl_read_term_syntax_error_option_answers_as_the_oracles
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="$HERE/../../SCRIP/scrip"
OUT="${RT_DIR:-$HERE/../../SCRIP/out}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: no scrip binary at $SCRIP -- run make first"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$OUT/libscrip_rt.so" || exit 2
d=$(mktemp -d) || exit 2
trap 'rm -rf "$d"' EXIT
printf 'foo(. \nok_term.\nbar)) .\nlast.\n' > "$d/bad.txt"
printf 'good(1).\n' > "$d/good.txt"
printf 'foo(' > "$d/eof.txt"
cat > "$d/w.pl" <<'PL'
:- initialization(main).
w('bad.txt', syntax_error(error)).
w('bad.txt', syntax_error(fail)).
w('bad.txt', syntax_error(warning)).
w('bad.txt', syntax_error(quiet)).
w('bad.txt', syntax_error(_)).
w('bad.txt', variable_names(_)).
w('good.txt', syntax_error(fail)).
w('eof.txt', syntax_error(fail)).
w('eof.txt', syntax_error(error)).
w('bad.txt', syntax_errors(error)).
w('bad.txt', syntax_errors(fail)).
w('bad.txt', syntax_errors(quiet)).
w('bad.txt', syntax_errors(dec10)).
w('good.txt', syntax_errors(dec10)).
w('eof.txt', syntax_errors(dec10)).
w('eof.txt', syntax_errors(fail)).
main :- w(F, O), open(F, read, R), r1(R, O), r2(R), close(R), write('--'), nl, fail.
main.
r1(R, O) :- catch((read_term(R, T, [O]) -> (write('T:'), writeq(T)) ; write('F')), E, cls(E)), nl.
r2(R) :- catch((read_term(R, T, []), write('T:'), writeq(T)), E, cls(E)), nl.
cls(error(syntax_error(_), _)) :- !, write('E').
cls(error(domain_error(read_option, _), _)) :- !, write('D').
cls(error(instantiation_error, _)) :- !, write('I').
cls(E) :- write(other(E)).
PL
cat > "$d/want" <<'WANT'
E
T:ok_term
--
F
T:ok_term
--
W
F
T:ok_term
--
D
E
--
I
E
--
E
T:ok_term
--
T:good(1)
T:end_of_file
--
F
T:end_of_file
--
E
T:end_of_file
--
E
T:ok_term
--
F
T:ok_term
--
F
T:ok_term
--
T:ok_term
E
--
T:good(1)
T:end_of_file
--
T:end_of_file
T:end_of_file
--
F
T:end_of_file
--
WANT
norm() { sed 's/^warning: syntax error.*/W/'; }
fails=0; graded=0
(cd "$d" && timeout -k 5 20 "$SCRIP" w.pl </dev/null 2>/dev/null) > "$d/m3.raw"; rc3=$?
norm < "$d/m3.raw" > "$d/m3"; graded=$((graded + 1))
if [ $rc3 -ne 0 ] || ! cmp -s "$d/want" "$d/m3"; then fails=$((fails + 1)); echo "  m3 rc=$rc3 differs:"; diff "$d/want" "$d/m3" | head -20; fi
if (cd "$d" && timeout -k 5 60 "$SCRIP" --compile -o w.s w.pl </dev/null >/dev/null 2>&1 && gcc -m64 -no-pie w.s -L"$OUT" -lscrip_rt -lm -lpthread -Wl,-rpath,"$OUT" -o w.bin 2>/dev/null); then
    (cd "$d" && timeout -k 5 20 ./w.bin </dev/null 2>/dev/null) > "$d/m4.raw"; rc4=$?
    norm < "$d/m4.raw" > "$d/m4"; graded=$((graded + 1))
    if [ $rc4 -ne 0 ] || ! cmp -s "$d/want" "$d/m4"; then fails=$((fails + 1)); echo "  m4 rc=$rc4 differs:"; diff "$d/want" "$d/m4" | head -20; fi
else
    graded=$((graded + 1)); fails=$((fails + 1)); echo "  m4 did not compile or link"
fi
[ "$(grep -c '' "$d/want")" -eq 49 ] || { echo "⛔ REFUSED(2) [$GATE_NAME]: the expectation table is not the 16 witnesses it names (15 x 3 lines + the warning row 4)"; exit 2; }
echo "PLRTSYNOPT_BOARD witnesses=16 modes=2 graded=$graded PASS=$((graded - fails)) FAIL=$fails"
[ $fails -eq 0 ] || exit 1
exit 0
