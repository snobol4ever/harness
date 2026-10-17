#!/usr/bin/env bash
# test_gate_logtalk_population_is_named_and_sums.sh — the invariant gate for the logtalk_iso instrument
# (row prolog-logtalk-iso-3268-conformance-cases-have-no-runner, hq_R 2026-09-12).
#
# ⛔ WHAT IT PROTECTS, AND IT IS NOT THE SCORE. The number on that board will move every week and must be
# free to. What must never move is the three properties that make the number mean anything:
#   (1) THE POPULATION IS WHOLE — every case in every tests.lgt is in exactly one bucket, and the buckets
#       reconcile with the count that was globbed. A case in no bucket is invisible in every number, which
#       is the "never graded business" the package lockdown exists to end.
#   (2) A FILE THAT CANNOT BE PARSED REFUSES rc=2 AND IS NAMED — never dropped, never a shorter denominator.
#   (3) THE ISO HEX ESCAPE IS READ CORRECTLY. This is a REGRESSION PIN on a measured 31-case hole, not a
#       hypothetical: `{writeq('\x2\')}` ends its atom with a backslash (ISO 6.4.2.1), every "backslash
#       escapes the next character" scanner ate the closing quote, and predicates/write_term_3 silently
#       lost cases 115..145. ⭐ It lost them in the file whose whole subject is escapes — a suite is most
#       likely to break the instrument reading it at exactly the construct that suite exists to test — and
#       it lost them WITHOUT AN ERROR, so only a second, independent count could see it.
#
# ⭐ EVERY ARM RUNS ON A SCRATCH FIXTURE IN mktemp, NOT ON THE VENDORED SUITE. A gate that needs the real
# 3617-case run to fire costs two and a half minutes and nobody puts it in make test; these cost under a
# second and are offline. The vendored suite is graded by its runner, which is a board, not a gate.
#
# Usage: bash ../harness/scripts/test_gate_logtalk_population_is_named_and_sums.sh
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GATE=test_gate_logtalk_population_is_named_and_sums
violations=0; arms=0
TD="$(mktemp -d "${TMPDIR:-/tmp}/lgtgate.XXXXXX")"; trap 'rm -rf "$TD"' EXIT
fail() { echo "GATE FAIL [$GATE]: $*"; violations=$((violations+1)); }

for f in util_logtalk_extract.py util_logtalk_grade.py lib_logtalk_lgtunit.pl test_prolog_logtalk_suite.sh; do
    [ -f "$HERE/$f" ] || { echo "⛔ REFUSED(2) [$GATE]: $HERE/$f is missing -- this gate cannot measure an instrument that is not here"; exit 2; }
done

# ---- ARM 1 — the population is whole, and the parser agrees with an independent line count.
arms=$((arms+1))
mkdir -p "$TD/a/grp"
cat > "$TD/a/grp/tests.lgt" <<'LGT'
support(1).
:- object(tests, extends(lgtunit)).
	test(t_true, true) :-
		{support(1)}.
	test(t_false, false) :-
		{support(2)}.
	test(t_err, error(type_error(evaluable, nope/0))) :-
		{_X is nope}.
	succeeds(t_legacy_succ) :-
		{support(1)}.
	fails(t_legacy_fail) :-
		{support(2)}.
	throws(t_legacy_throw, error(type_error(evaluable, nope/0), _)) :-
		{_Y is nope}.
	helper(ok).
:- end_object.
LGT
out="$(python3 "$HERE/util_logtalk_extract.py" --census "$TD/a" 2>&1)"; rc=$?
case "$out" in
    *"files=1 cases=6"*) : ;;
    *) fail "ARM 1: the six head forms did not census as 6 cases (rc=$rc): $out" ;;
esac

# ---- ARM 2 — a clause the object body defines is DATABASE, not a dropped line. 373 false reds rode on this.
arms=$((arms+1))
got="$(GATE_SCRIPTS="$HERE" python3 - "$TD/a/grp/tests.lgt" <<'PY'
import sys, os
sys.path.insert(0, os.environ["GATE_SCRIPTS"])
import util_logtalk_extract as ex
print(" ".join(sorted(c.split("(")[0] for c in ex.parse_file(sys.argv[1]).db)))
PY
)"
[ "$got" = "helper support" ] || fail "ARM 2: the database is '$got', want 'helper support' -- a support predicate defined INSIDE the object was dropped, which turns every case that calls it into a plausible existence_error red the harness manufactured"

# ---- ARM 3 — THE ISO HEX ESCAPE REGRESSION PIN. The three cases after it must still be seen.
arms=$((arms+1))
mkdir -p "$TD/b/grp"
{
  printf ':- object(tests, extends(lgtunit)).\n'
  printf '\ttest(esc_hex, true) :-\n\t\t{writeq('"'"'\\x2\\'"'"')}.\n'
  printf '\ttest(esc_oct, true) :-\n\t\t{writeq('"'"'\\101\\'"'"')}.\n'
  printf '\ttest(after_the_escapes, true) :-\n\t\t{true}.\n'
  printf ':- end_object.\n'
} > "$TD/b/grp/tests.lgt"
out="$(python3 "$HERE/util_logtalk_extract.py" --census "$TD/b" 2>&1)"
case "$out" in
    *"files=1 cases=3"*) : ;;
    *) fail "ARM 3: an ISO numeric escape (\\x2\\ / \\101\\) swallowed the cases after it -- census said: $out
    This is the measured 31-case hole in predicates/write_term_3. A scanner that treats backslash as 'skip the next character' lands ON the escape's terminating backslash and eats the closing quote." ;;
esac

# ---- ARM 4 — an unparseable case REFUSES rc=2 and NAMES the file. Never a shorter denominator.
arms=$((arms+1))
mkdir -p "$TD/c/grp"
{
  printf ':- object(tests, extends(lgtunit)).\n'
  printf '\ttest(fine, true) :-\n\t\t{true}.\n'
  printf '\ttest(unbalanced, true :-\n\t\t{true}.\n'
} > "$TD/c/grp/tests.lgt"
out="$(python3 "$HERE/util_logtalk_grade.py" --suite "$TD/c" --scrip "$HERE/../../SCRIP/scrip" --modes m3 2>&1)"; rc=$?
if [ "$rc" -ne 2 ]; then
    fail "ARM 4: an unparseable tests.lgt exited $rc, want 2 -- a board that publishes over a file it could not read is publishing a denominator it invented"
elif ! printf '%s' "$out" | grep -q "grp/tests.lgt"; then
    fail "ARM 4: the refusal did not NAME the file it could not parse: $out"
fi

# ---- ARM 5 — the buckets reconcile with the globbed population, and the runner says so on its own line.
arms=$((arms+1))
if [ -x "$HERE/../../SCRIP/scrip" ]; then
    out="$(python3 "$HERE/util_logtalk_grade.py" --suite "$TD/a" --scrip "$HERE/../../SCRIP/scrip" --modes m3 2>&1)"; rc=$?
    pop="$(printf '%s' "$out" | sed -n 's/.*population=\([0-9]*\).*/\1/p' | head -1)"
    ident="$(printf '%s' "$out" | grep -c 'identity m3:.*== 6 ✓')"
    if [ "$rc" -ne 0 ] || [ "$pop" != "6" ] || [ "$ident" -ne 1 ]; then
        fail "ARM 5: the six-case fixture did not print a reconciling identity over population 6 (rc=$rc pop=$pop): $out"
    fi
else
    echo "    ARM 5 SKIPPED: no scrip binary at $HERE/../../SCRIP/scrip -- the identity arm needs a compiler to grade with"
fi

# ---- ARM 6 — the supported-helper list is READ FROM THE SHIM, never a second list that can disagree.
arms=$((arms+1))
if grep -qE '^SUPPORTED[ =]|^SHIM_HELPERS[ =]' "$HERE/util_logtalk_grade.py"; then
    fail "ARM 6: util_logtalk_grade.py carries a typed list of supported helpers. Two lists that can disagree about what is implemented is the same defect as two counts that can disagree about a population -- read lib_logtalk_lgtunit.pl."
fi
n="$(GATE_SCRIPTS="$HERE" python3 - <<'PY'
import os, sys
sys.path.insert(0, os.environ["GATE_SCRIPTS"])
import util_logtalk_grade as g
print(len(g.shim_helpers()))
PY
)"
[ "${n:-0}" -ge 15 ] || fail "ARM 6: shim_helpers() read $n names out of lib_logtalk_lgtunit.pl -- an empty or tiny set silently marks every helper-using case UNGRADED and the board still reconciles"

# ---- ARM 7 — A DATABASE CLAUSE IN LOGTALK-ONLY SYNTAX IS DROPPED, AND THE FILE STILL GRADES. Measured
# 2026-09-12 against the ceo's independent emulation: one `cleanup :- ^^clean_text_input.` helper travels
# with every case of its file, so the generated program was a PARSE ERROR and all 49 predicates/is_2 cases
# came back `nooutput` -- a verdict on the harness wearing the shape of an arithmetic red. 40 files and
# 1486 of 3617 cases were graded that way. ⭐ The defect could only ever produce reds, which is why it did
# not look like a defect: a board of failures is what a young frontend is expected to print.
arms=$((arms+1))
mkdir -p "$TD/d/grp"
cat > "$TD/d/grp/tests.lgt" <<'LGT'
cleanup :-
	^^clean_text_input.
support(1).
:- object(tests, extends(lgtunit)).
	test(t_plain, true) :-
		{support(1)}.
:- end_object.
LGT
if [ -x "$HERE/../../SCRIP/scrip" ]; then
    out="$(python3 "$HERE/util_logtalk_grade.py" --suite "$TD/d" --scrip "$HERE/../../SCRIP/scrip" --modes m3 2>&1)"; rc=$?
    case "$out" in
        *"m3_pass=1"*) : ;;
        *) fail "ARM 7: a file whose database carries a Logtalk-only helper (^^/::) did not grade its plain case (rc=$rc): $out
    The clause cannot be expressed in Prolog, so it must be DROPPED from the generated program -- not emitted, where it makes every case of that file a parse error and reports the construct under test as the failure." ;;
    esac
else
    echo "    ARM 7 SKIPPED: no scrip binary at $HERE/../../SCRIP/scrip"
fi

# ---- ARM 8 — THE TESTER-LOADED PROLOG FILE IS INLINED, GUARDS INTACT. Seven directories ship a tester.lgt
# whose initialization loads a plain-Prolog file before the tests run; every predicate the cases call lives
# there. ⛔ It goes in VERBATIM: drop its :- if/endif guards while keeping both branches and the 31 cases
# that exist to prove a branch was NOT compiled all start succeeding -- the harness answering the question
# the suite was asking.
arms=$((arms+1))
mkdir -p "$TD/e/grp"
cat > "$TD/e/grp/file.pl" <<'PL'
:- dynamic(gated_off/0).
:- if(true).
gated_on.
:- endif.
:- if(fail).
gated_off.
:- endif.
PL
cat > "$TD/e/grp/tester.lgt" <<'LGT'
:- initialization((
	logtalk_load_context(directory, Directory),
	atom_concat(Directory, 'file.pl', File),
	'$lgt_load_prolog_file'(File),
	tests::run
)).
LGT
cat > "$TD/e/grp/tests.lgt" <<'LGT'
:- object(tests, extends(lgtunit)).
	test(kept_branch_is_defined, true) :-
		{gated_on}.
	test(dropped_branch_is_not, false) :-
		{gated_off}.
:- end_object.
LGT
if [ -x "$HERE/../../SCRIP/scrip" ]; then
    out="$(python3 "$HERE/util_logtalk_grade.py" --suite "$TD/e" --scrip "$HERE/../../SCRIP/scrip" --modes m3 2>&1)"; rc=$?
    case "$out" in
        *"m3_pass=2"*) : ;;
        *) fail "ARM 8: the file the directory's tester.lgt loads was not inlined with its conditional-compilation guards intact (rc=$rc): $out
    Without it every case raises existence_error on a predicate that is defined -- and with its guards dropped, the branch the suite proves was NOT compiled becomes defined and the case wrongly passes." ;;
    esac
else
    echo "    ARM 8 SKIPPED: no scrip binary at $HERE/../../SCRIP/scrip"
fi

# ---- ARM 9 — A DEVELOPMENT AID THAT GRADED NOTHING REFUSES. `--group predicates/sub_atom_5` (the path,
# where the group is the basename) matched no file and the grader printed a complete board reading
# population=0, identity 0 == 0 ✓, AND per case 0/0: the success shape over an empty measurement, which is
# the one thing every instrument in this tree is forbidden to do.
arms=$((arms+1))
out="$(python3 "$HERE/util_logtalk_grade.py" --suite "$TD/a" --scrip "$HERE/../../SCRIP/scrip" --modes m3 --group no/such/group 2>&1)"; rc=$?
if [ "$rc" -ne 2 ]; then
    fail "ARM 9: --group matching no file exited $rc, want 2 -- it printed a board over a population of zero"
elif ! printf '%s' "$out" | grep -q "Known groups"; then
    fail "ARM 9: the refusal did not name the groups it does know: $out"
fi

# ---- ARM 10..13 — THE ORDER-DEPENDENT CASE MECHANISM (lib_logtalk_sequenced.tsv). A handful of cases in
# this suite are written against the database their file's EARLIER cases leave behind (hq_C,
# FINDING-2026-09-13, claim 2: predicates/retract_1 cases 04 and 05). Standalone they cannot pass WHATEVER
# THE ENGINE DOES, and they arrive as FAIL -- the one bucket that means the engine got it wrong and the one
# bucket a seat drives to zero, so they get picked up, ablated and handed back unsolved. ⭐ A FAIL NO CURE CAN
# CLEAR IS A DEFECT OF THE INSTRUMENT. The cure is a DECLARED prefix, and what these arms protect is not the
# prefix but the POLICING: a table nobody checks is a silencer with a comment on top.
mkdir -p "$TD/f/seq"
cat > "$TD/f/seq/tests.lgt" <<'LGT'
:- dynamic(v/1).
v(1).
v(2).
:- object(tests, extends(lgtunit)).
	test(s_01, true) :-
		{retract(v(X)), X == 1}.
	test(s_02, true(L == [2])) :-
		{findall(X, v(X), L)}.
	test(s_03, true) :-
		{atom(a)}.
:- end_object.
LGT
printf 'seq\ts_02\tthe one-element answer is the state case 01 leaves\n' > "$TD/f/ok.tsv"
printf 'seq\ts_03\tdeclared but it passes standalone and needs no prefix\n' > "$TD/f/unearned.tsv"
printf 'seq\ts_99\tno case of this name\n' > "$TD/f/stale.tsv"
printf 'seq\ts_01\tthe first case in its file has no prefix\n' > "$TD/f/first.tsv"
printf 'seq s_02 spaces where the format says tabs\n' > "$TD/f/malformed.tsv"
G="python3 $HERE/util_logtalk_grade.py --suite $TD/f --scrip $HERE/../../SCRIP/scrip --modes m3"
if [ -x "$HERE/../../SCRIP/scrip" ]; then
    # ARM 10 — UNDECLARED, the order-dependent case is a red nobody can cure; DECLARED, it grades, and the
    # board PRINTS the weakening: what it scored with its file's prefix AND what it scores alone.
    arms=$((arms+1))
    out="$($G --sequenced /dev/null 2>&1)"
    case "$out" in *"m3_pass=2 m3_fail=1"*) : ;; *) fail "ARM 10: the fixture's order-dependent case did not read as the one red with no declaration -- the defect this mechanism exists for is not reproduced, so the arms below prove nothing: $out" ;; esac
    out="$($G --sequenced "$TD/f/ok.tsv" 2>&1)"; rc=$?
    case "$out" in *"m3_pass=3 m3_fail=0"*) : ;; *) fail "ARM 10: a DECLARED order-dependent case did not grade with its file's earlier cases run first (rc=$rc): $out" ;; esac
    printf '%s' "$out" | grep -q "SEQUENCED 1 case" || fail "ARM 10: the board did not NAME the sequenced case. The weakening is the whole cost of this mechanism and belongs beside the number, never only in the data file: $out"
    printf '%s' "$out" | grep -q "standalone: m3 FAIL" || fail "ARM 10: the board did not print the case's STANDALONE outcome beside its verdict, so a reader cannot see that the prefix was needed: $out"
    # ⭐ AND THE PREFIX GOALS' VARIABLES STAY LOCAL. The fixture's case 01 binds X and case s_02 names X too:
    # spliced textually they are ONE variable and s_02 measures a different program, so this arm passes only
    # because each prefix goal is emitted as its own clause.
    # ARM 11 — a declaration the suite does not need REFUSES. Without this arm the table silences reds.
    arms=$((arms+1))
    out="$($G --sequenced "$TD/f/unearned.tsv" 2>&1)"; rc=$?
    if [ "$rc" -ne 2 ]; then
        fail "ARM 11: declaring a case that PASSES STANDALONE exited $rc, want 2 -- every declared case must be re-run standalone on the same board, or one line per red turns this table into a silencer and every verdict it touches is weaker than the suite supports"
    elif ! printf '%s' "$out" | grep -q "do not need a prefix"; then
        fail "ARM 11: the refusal did not say the prefix is unnecessary: $out"
    fi
    # ARM 12 — a stale or impossible declaration REFUSES and names itself: a renamed case, and a case that is
    # FIRST in its file and therefore has no prefix at all.
    arms=$((arms+1))
    out="$($G --sequenced "$TD/f/stale.tsv" 2>&1)"; rc=$?
    { [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q "s_99"; } || fail "ARM 12: a declaration naming a case its graded group does not have exited $rc and did not name the case: $out"
    out="$($G --sequenced "$TD/f/first.tsv" 2>&1)"; rc=$?
    { [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q "FIRST case"; } || fail "ARM 12: declaring the FIRST case of a file exited $rc -- there is no prefix to run, so the line grades nothing differently and tells a reader something untrue: $out"
    out="$($G --sequenced "$TD/f/malformed.tsv" 2>&1)"; rc=$?
    [ "$rc" -eq 2 ] || fail "ARM 12: a malformed declaration line exited $rc, want 2 -- a line this instrument cannot read must never be skipped in silence"
    # ARM 13 — THE SWEEP IS A DIAGNOSTIC AND NEVER A GRADING PATH. It names the candidate and leaves the red
    # standing: an automatic retry-with-prefix that counted as a pass would turn a real engine defect green
    # the first time a neighbour's state happened to mask it.
    arms=$((arms+1))
    out="$($G --sequenced /dev/null --sweep-sequenced 2>&1)"; rc=$?
    printf '%s' "$out" | grep -q "SWEEP: 1 red case" || fail "ARM 13: the sweep did not name the undeclared order-dependent case as a candidate (rc=$rc): $out"
    case "$out" in *"m3_pass=2 m3_fail=1"*) : ;; *) fail "ARM 13: the sweep MOVED THE BOARD. It may only name candidates for a human to declare with a reason: $out" ;; esac
else
    echo "    ARM 10..13 SKIPPED: no scrip binary at $HERE/../../SCRIP/scrip"
fi

# ---- ARM 14 — THE SHIPPED DECLARATIONS STILL POINT AT REAL CASES, checked against the vendored suite with
# no compiler. Offline, so the table cannot rot between two full board runs.
arms=$((arms+1))
SUITE_REAL="${S4E_CORPUS:-$(cd "$HERE/../.." && pwd)/corpus}/packages/prolog/logtalk_iso"
if [ -d "$SUITE_REAL" ]; then
    miss="$(GATE_SCRIPTS="$HERE" SUITE_REAL="$SUITE_REAL" python3 - <<'PY'
import os, sys
sys.path.insert(0, os.environ["GATE_SCRIPTS"])
import util_logtalk_grade as g, util_logtalk_extract as ex
table, bad = g.load_sequenced()
if bad:
    print("TABLE " + "; ".join(w for _p, w in bad)); sys.exit(0)
files, _b = ex.parse_suite(os.environ["SUITE_REAL"])
have = {(fc.group, c.name) for fc in files for c in fc.cases}
print(" ".join("%s:%s" % k for k in sorted(table) if k not in have))
PY
)"
    [ -z "$miss" ] || fail "ARM 14: lib_logtalk_sequenced.tsv declares case(s) the vendored suite does not have: $miss"
else
    echo "    ARM 14 SKIPPED: no vendored suite at $SUITE_REAL"
fi

# ---- ARM 15 — EVERY CASE IS GRADED OR EXCLUDED BY NAME (Lon 2026-10-05, in-chat to the ceo, verbatim: "We do want ALL test programs to
# run. We have NO expected failures. We expect to have ALL features." and "Mark the Windows dependent tests as Excluded." and "Mark the
# bounded-integer tests as Excluded."; ceo CEO-1518..1520, withdrawing CEO-1235 (3) option (a) and the CEO-1266 probe). Five properties on
# one fixture: the coinduction case is IN the population (the feature is declared supported); both branches of an engine guard are graded,
# never probed; a Windows-branch case named WINDOWS_ONLY in EXCLUDED_CASES.tsv leaves and its unix twin is graded; a bounded-integers case
# named BOUNDED_INTEGERS_ONLY leaves without running, its heap/stack declaration no orphan; and the board prints excluded=2. Then the two
# refusals: a guarded-out case no row names, and a row naming no such case, each rc=2 and named.
arms=$((arms+1))
if [ -x "$HERE/../../SCRIP/scrip" ]; then
    mkdir -p "$TD/g/grp"
    cat > "$TD/g/grp/tests.lgt" <<'LGT'
:- object(tests, extends(lgtunit)).
	:- if(current_logtalk_flag(coinduction, supported)).
		test(t_cyc, true) :- true.
	:- endif.
	:- if(catch(no_such_predicate_q, _, fail)).
		test(t_probe, true) :- fail.
	:- else.
		test(t_probe, true) :- true.
	:- endif.
	:- if(os::operating_system_type(windows)).
		test(t_win, true) :- fail.
	:- else.
		test(t_win, true) :- true.
	:- endif.
	test(t_bnd, true, [condition(current_prolog_flag(bounded,true))]) :- fail.
	test(t_plain, true) :- true.
:- end_object.
LGT
    printf 'grp:t_win\tWINDOWS_ONLY\t:- if(os::operating_system_type(windows))\ngrp:t_bnd\tBOUNDED_INTEGERS_ONLY\tcondition(current_prolog_flag(bounded,true))\n' > "$TD/g/EXCLUDED_CASES.tsv"
    printf 'grp:t_bnd\t1024\t\n' > "$TD/g/decl.tsv"
    out="$(python3 "$HERE/util_logtalk_grade.py" --suite "$TD/g" --scrip "$HERE/../../SCRIP/scrip" --modes m3 --decl "$TD/g/decl.tsv" 2>&1)"; rc=$?
    pop="$(printf '%s' "$out" | sed -n 's/.*population=\([0-9]*\).*/\1/p' | head -1)"
    pass="$(printf '%s' "$out" | sed -n 's/.*m3_pass=\([0-9]*\).*/\1/p' | head -1)"
    if [ "$rc" -ne 0 ] || [ "$pop" != "5" ] || [ "$pass" != "4" ]; then
        fail "ARM 15: the fixture did not grade population 5 with 4 passing (t_cyc in, both t_probe branches in and one red, t_win's unix branch in, t_bnd out) (rc=$rc pop=$pop pass=$pass): $out"
    fi
    printf '%s' "$out" | grep -q '^BOARD_FOR_SHELL .* excluded=2$' || fail "ARM 15: the board line does not carry excluded=2: $out"
    printf '%s' "$out" | grep -q 'WINDOWS_ONLY.*grp:t_win' || fail "ARM 15: the Windows case left the population without being NAMED as excluded: $out"
    printf '%s' "$out" | grep -q 'BOUNDED_INTEGERS_ONLY.*grp:t_bnd' || fail "ARM 15: the bounded-integers case left the population without being NAMED as excluded: $out"
    printf '%s' "$out" | grep -q '^GUARD PROBED' && fail "ARM 15: a guard was probed on the binary -- one branch of its pair left the population: $out"
    printf 'grp:t_bnd\tBOUNDED_INTEGERS_ONLY\tcondition(current_prolog_flag(bounded,true))\n' > "$TD/g/EXCLUDED_CASES.tsv"
    out="$(python3 "$HERE/util_logtalk_grade.py" --suite "$TD/g" --scrip "$HERE/../../SCRIP/scrip" --modes m3 2>&1)"; rc=$?
    { [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'grp:t_win'; } || fail "ARM 15: a Windows-guarded case NO row names did not refuse rc=2 naming it (rc=$rc): $out"
    printf 'grp:t_win\tWINDOWS_ONLY\t:- if(os::operating_system_type(windows))\ngrp:t_bnd\tBOUNDED_INTEGERS_ONLY\tcondition(current_prolog_flag(bounded,true))\ngrp:t_gone\tBOUNDED_INTEGERS_ONLY\tcondition(current_prolog_flag(bounded,true))\n' > "$TD/g/EXCLUDED_CASES.tsv"
    out="$(python3 "$HERE/util_logtalk_grade.py" --suite "$TD/g" --scrip "$HERE/../../SCRIP/scrip" --modes m3 2>&1)"; rc=$?
    { [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'grp:t_gone'; } || fail "ARM 15: a row naming no such case did not refuse rc=2 naming it (rc=$rc): $out"
else
    echo "    ARM 15 SKIPPED: no scrip binary at $HERE/../../SCRIP/scrip"
fi

# ---- ARM 16 — THE SECOND DOT OF =.. IS NOT AN END TOKEN (ISO 6.4.8: a "." ends a clause only when it is not part of a longer symbol-character
# token). Before 2026-09-25 "V =.. [D, Ma| _]" split at the dot before the space and the case reached the engine as "V =., (...)", a parse error
# that failed its whole program (Logtalk current_prolog_flag_2 commons_17). Offline: the splitter alone, on a two-clause fixture.
arms=$((arms+1))
got="$(GATE_SCRIPTS="$HERE" python3 - <<'PY'
import os, sys
sys.path.insert(0, os.environ["GATE_SCRIPTS"])
import util_logtalk_extract as ex
print(len(ex.split_clauses("a :- V =.. [x, 1| _], b. c :- X = '.'.")))
PY
)"
[ "$got" = "2" ] || fail "ARM 16: a clause holding '=.. [' split into $got pieces, want 2 -- the second dot of =.. was read as the end of the clause"

# ---- ARM 17 — THE CASE RUNS AFTER THE FILE'S initialization GOALS, as lgtunit runs a test after loading. The fixture's tester-loaded file asserts
# k(1) in an initialization directive; a case driven by a plain directive ran before it and saw no k/1 (Logtalk initialization_1, 2026-09-25).
arms=$((arms+1))
if [ -x "$HERE/../../SCRIP/scrip" ]; then
    mkdir -p "$TD/h/grp"
    printf ':- dynamic(k/1).\n:- initialization(assertz(k(1))).\n' > "$TD/h/grp/file.pl"
    cat > "$TD/h/grp/tester.lgt" <<'LGT'
:- initialization((
	logtalk_load_context(directory, Directory),
	atom_concat(Directory, 'file.pl', File),
	'$lgt_load_prolog_file'(File),
	tests::run
)).
LGT
    cat > "$TD/h/grp/tests.lgt" <<'LGT'
:- object(tests, extends(lgtunit)).
	test(t_after_init, true(L == [1])) :-
		findall(X, {k(X)}, L).
:- end_object.
LGT
    out="$(python3 "$HERE/util_logtalk_grade.py" --suite "$TD/h" --scrip "$HERE/../../SCRIP/scrip" --modes m3 2>&1)"; rc=$?
    pass="$(printf '%s' "$out" | sed -n 's/.*m3_pass=\([0-9]*\).*/\1/p' | head -1)"
    [ "$rc" -eq 0 ] && [ "$pass" = "1" ] || fail "ARM 17: a case ran before its loaded file's initialization goal and saw no k/1 (rc=$rc): $out"
else
    echo "    ARM 17 SKIPPED: no scrip binary at $HERE/../../SCRIP/scrip"
fi

echo "[$GATE] arms=$arms violations=$violations"
[ "$violations" -eq 0 ] || exit 1
echo "GATE PASS [$GATE]: the population is whole, an unreadable file refuses and is named, the ISO numeric escape stays readable, Logtalk-only database clauses are dropped rather than emitted, the tester-loaded Prolog file is inlined with its guards, a group that matched nothing refuses, and every order-dependent declaration is earned -- policed standalone on the same board, named on the board line, stale or unnecessary lines refusing rc=2"
exit 0
