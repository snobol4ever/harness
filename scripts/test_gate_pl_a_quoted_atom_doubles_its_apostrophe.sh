#!/usr/bin/env bash
# test_gate_pl_a_quoted_atom_doubles_its_apostrophe.sh -- INSIDE A QUOTED TOKEN THE APOSTROPHE DOUBLES (ISO
# 6.4.2.1), in every writer and in BOTH MODES (row prolog-logtalk-write-term-print-and-write-canonical-family,
# hq_R 2026-09-13, on the coo's rungs-board diagnosis of entry format_directive_6).
#
# THE DEFECT THIS PINS. plc_wt_atom escaped the apostrophe as \' -- the swipl spelling. gprolog, SICStus and the
# Prolog rungs' OWN REF all double it: the ref reads  it's|'it''s'  and we printed  it's|'it\'s'. One character,
# one site, and it reached writeq/1, print/1, write_canonical/1, write_term/2,3 and format ~q at once, because all
# five go through that one function.
#
# ⛔⭐ WHY IT SURVIVED FOR MONTHS, WHICH IS THE PART WORTH KEEPING. BOTH SPELLINGS READ BACK AS ONE APOSTROPHE, so
# the one property anyone thinks to test of a quoted writer -- that writeq's output reads back equal, the round trip
# -- IS EXACTLY THE PROPERTY THIS DEFECT PRESERVES. It cannot be caught by a self-consistency test of any kind; only
# a ref diff or an oracle diff can see it. ⭐ The general form: when a defect is invisible to the strongest test a
# module can run ON ITSELF, the missing arm is never a better self-test -- it is an external witness. So this gate
# pins the BYTES against the oracle's spelling, and keeps the round trip only as the arm proving the cure did not
# trade readability for the ref (both must hold; either alone is satisfiable by a wrong writer).
#
# ⛔ AND THE NEIGHBOURS ARE GRADED, because a one-character switch in a switch statement is exactly the shape that
# takes a sibling case with it: \\ must still be a backslash pair, \n \t must still be the control escapes, an
# unquoted write/1 must still print the bare text, and a quote-only atom '''' must still come out as four quotes.
# rc 0 green · 1 red · 2 could not measure.
set -uo pipefail
GATE_NAME=test_gate_pl_a_quoted_atom_doubles_its_apostrophe
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"
RT="${RT_DIR:-$ROOT/out}"
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: no scrip at $SCRIP -- a missing binary prints a plausible all-FAIL board"; exit 2; }
"$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
D=$(mktemp -d) || { echo "⛔ REFUSE(2) [$GATE_NAME]: no tmpdir"; exit 2; }
trap 'rm -rf "$D"' EXIT
PASS=0; FAIL=0; N=0
# goal <TAB> want.  The want is the EXACT bytes between two @ markers, so "wrote nothing" and "wrote the wrong
# thing" and "died before printing" stay three distinguishable outcomes rather than one diff.
# print/1 is GNU's unquoted write (SCRIP 5b6ebef7c; gprolog 1.6.0 prints it's) -- its arm pins the bare text, and the
# doubling is graded on the five writers that quote: writeq, write_canonical, write_term quoted(true), format ~q.
W=$(cat <<'TEOF'
writeq('it''s')	'it''s'
print('it''s')	it's
write_canonical('it''s')	'it''s'
write_term('it''s', [quoted(true)])	'it''s'
format("~q", ['it''s'])	'it''s'
writeq(f('it''s', 1))	f('it''s',1)
writeq(['it''s'])	['it''s']
writeq('''')	''''
write('it''s')	it's
write_term('it''s', [quoted(false)])	it's
writeq('a\\b')	'a\\b'
writeq('a\nb')	'a\nb'
writeq('a\tb')	'a\tb'
writeq('hello world')	'hello world'
writeq(abc)	abc
TEOF
)
run_mode() {          # run_mode <mode> <program-file> -> prints stdout, returns the program's rc
    local mode="$1" prog="$2"
    if [ "$mode" = m3 ]; then timeout -k 5 20 "$SCRIP" "$prog" </dev/null 2>&1; return $?; fi
    timeout -k 5 40 "$SCRIP" --compile -o "$D/e.s" "$prog" </dev/null >"$D/cc.log" 2>&1 || { echo "COMPILEFAIL $(tail -1 "$D/cc.log")"; return 3; }
    gcc -m64 -no-pie "$D/e.s" -o "$D/e.bin" -L "$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm >"$D/ld.log" 2>&1 || { echo "LINKFAIL $(tail -1 "$D/ld.log")"; return 3; }
    timeout -k 5 20 "$D/e.bin" </dev/null 2>&1; return $?
}
for mode in m3 m4; do
  while IFS=$'\t' read -r goal want; do
    [ -n "$goal" ] || continue
    N=$((N+1))
    printf ':- initialization(main).\nmain :- write(user_output, @), %s, write(user_output, @), nl(user_output).\n' "$goal" > "$D/t.pl"
    got="$(run_mode "$mode" "$D/t.pl")"; rc=$?
    if [ $rc -ne 0 ]; then echo "  RED  $mode [$goal] rc=$rc -- the program did not run to its second marker: ${got:-<no output>}"; FAIL=$((FAIL+1)); continue; fi
    case "$got" in *@*@*) ;; *) echo "  RED  $mode [$goal] markers missing, so nothing can be concluded: got [$got]"; FAIL=$((FAIL+1)); continue ;; esac
    inner=${got#*@}; inner=${inner%@*}
    if [ "$inner" = "$want" ]; then PASS=$((PASS+1))
    else echo "  RED  $mode [$goal] wrote [$inner] want [$want]"; FAIL=$((FAIL+1)); fi
  done <<< "$W"
done
# ---- THE ROUND TRIP, both modes. It is NOT the arm that catches the defect (both spellings read back equal) --
# it is the arm that proves the cure kept what the wrong spelling also had, so neither can be dropped.
cat > "$D/rt.pl" <<'PL'
:- initialization(main).
main :- A = 'it''s', open('rtq.txt', write, S), writeq(S, A), write(S, '.'), nl(S), close(S),
	open('rtq.txt', read, R), read(R, B), close(R),
	( A == B -> write(user_output, '@roundtrip_ok@') ; write(user_output, '@roundtrip_broken@'), writeq(user_output, B) ), nl(user_output).
PL
for mode in m3 m4; do
    N=$((N+1))
    got="$(cd "$D" && run_mode "$mode" "$D/rt.pl")"; rc=$?
    case "$got" in
        *"@roundtrip_ok@"*) PASS=$((PASS+1)) ;;
        *) echo "  RED  $mode [round trip] writeq's own output did not read back as the same atom (rc=$rc): ${got:-<no output>}"; FAIL=$((FAIL+1)) ;;
    esac
done
# ---- THE REF ARM. The rungs entry the coo's board lost on this defect, graded against its OWN ref bytes rather
# than against a string typed in here -- a gate that retypes the expected output is a gate that can drift from it.
RUNGS="${S4E_CORPUS:-$ROOT/../corpus}/tests/prolog"
if [ -f "$RUNGS/ALL.pl" ] && [ -f "$RUNGS/ALL.ref" ]; then
    if python3 "$HERE/corpus_suite_harness.py" extract "$RUNGS/ALL.pl" "$RUNGS/ALL.ref" format_directive_6 \
            "$D/fd6.pl" --out-ref "$D/fd6.ref" >/dev/null 2>&1 && [ -s "$D/fd6.ref" ]; then
        grep -q "it''s" "$D/fd6.ref" || { echo "⛔ REFUSE(2) [$GATE_NAME]: format_directive_6's ref no longer carries the doubled apostrophe, so this arm is grading something else -- read the ref before changing this gate"; exit 2; }
        for mode in m3 m4; do
            N=$((N+1))
            got="$(cd "$D" && run_mode "$mode" "$D/fd6.pl")"; rc=$?
            printf '%s\n' "$got" > "$D/fd6.$mode"
            if [ $rc -eq 0 ] && diff -q "$D/fd6.ref" "$D/fd6.$mode" >/dev/null; then PASS=$((PASS+1))
            else echo "  RED  $mode [rungs format_directive_6] does not match its own ref (rc=$rc):"; diff "$D/fd6.ref" "$D/fd6.$mode" | head -6; FAIL=$((FAIL+1)); fi
        done
    else
        echo "⛔ REFUSE(2) [$GATE_NAME]: could not extract format_directive_6 from the Prolog rungs -- the entry was renamed or the harness moved, and an arm that cannot measure must not report a verdict"; exit 2
    fi
else
    echo "⛔ REFUSE(2) [$GATE_NAME]: no Prolog rungs at $RUNGS -- the ref arm is this gate's external witness and there is no substitute for it here"; exit 2
fi
[ "$N" -gt 0 ] || { echo "⛔ REFUSE(2) [$GATE_NAME]: graded ZERO shapes -- a runner that cannot measure must never print the success shape"; exit 2; }
echo "PL QUOTED APOSTROPHE: PASS=$PASS FAIL=$FAIL / $N arms graded (m3+m4, shapes + round trip + the rungs ref)"
[ "$FAIL" -eq 0 ] && { echo "verdict=GREEN -- the apostrophe doubles in every writer and both modes, the neighbouring escapes are untouched, writeq's output reads back equal, and the rungs entry matches its own ref"; exit 0; }
echo "verdict=RED"; exit 1
