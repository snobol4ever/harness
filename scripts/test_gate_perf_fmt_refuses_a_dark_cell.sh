#!/usr/bin/env bash
# test_gate_perf_fmt_refuses_a_dark_cell.sh -- ⭐ THE DARK-CELL LAW, LOCKED (CEO-676; hq_P 2026-09-13).
#
# A benchmark arm that cannot measure its subject must REFUSE, naming the subject -- it must never
# emit a blank cell, and a grid must refuse to publish a column it could not fill.  This gate holds
# lib_perf_fmt.sh, THE ONE AUTHORITY for printing a multiple, to that law.
#
# ⛔ WHAT IT IS GUARDING AGAINST, MEASURED ON THIS TREE BEFORE THE CURE -- every one of these exited
# rc=0, so a caller, a grid and a reader all saw success:
#     perf_mult 100 0      -> "n/a"        a blank cell, read as a measurement that came back empty
#     perf_mult 0   100    -> "0.000x"     ⛔ FABRICATED: a NUMBER.  It sorts, it colours RED, it gets quoted
#     perf_mult 100 ERROR  -> "n/a"        awk's `v + 0` turned a string into 0 and then into a cell
#     perf_mult 100 -5     -> "-20.000x"   ⛔ a NEGATIVE multiple, printed and coloured like a reading
# The last two were found by this gate's own author while writing it, which is the argument for the gate.
#
# ⛔ THIS GATE REFUSES rc=2 RATHER THAN SKIPPING when it cannot measure (no lib, no bash): a test that
# cannot run must never report the same string as one that passed.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
LIB="$HERE/lib_perf_fmt.sh"
[ -r "$LIB" ] || { echo "⛔ GATE REFUSES: cannot read $LIB -- this gate proves nothing without it"; exit 2; }
# shellcheck source=/dev/null
. "$LIB" || { echo "⛔ GATE REFUSES: $LIB failed to source"; exit 2; }
export PERF_COLOR=0
PASS=0; FAIL=0
ok()  { PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
bad() { FAIL=$((FAIL+1)); printf '  FAIL %s\n     expected: %s\n     actual:   %s\n' "$1" "$2" "$3"; }
#-----------------------------------------------------------------------------------------------------
# A. A DARK CELL REFUSES: non-empty non-numeric token on stdout, rc=2, subject named on stderr.
dark() {
    local what="$1" ref="$2" ours="$3" subj="$4" out rc err
    err="$(mktemp)"; out="$(perf_mult "$ref" "$ours" "$subj" 2>"$err")"; rc=$?
    if [ "$rc" -ne 2 ]; then bad "$what: must exit 2" "rc=2" "rc=$rc (stdout='$out')"; rm -f "$err"; return; fi
    case "$out" in *REFUSED*) : ;; *) bad "$what: stdout must say REFUSED" "REFUSED" "'$out'"; rm -f "$err"; return ;; esac
    # ⛔ the cell must not be readable as a number -- that is shape (2), the fabricated multiple
    if printf '%s' "$out" | grep -Eq '^-?[0-9.]+x?$'; then bad "$what: cell is numeric" "non-numeric" "'$out'"; rm -f "$err"; return; fi
    if ! grep -q "$subj" "$err"; then bad "$what: stderr must NAME the subject" "mentions '$subj'" "$(tr '\n' ' ' <"$err")"; rm -f "$err"; return; fi
    rm -f "$err"; ok "$what refuses, names '$subj', cell='$out'"
}
echo "A. a subject that cannot be measured is REFUSED, never printed"
dark "zero ours (was n/a)"        100 0       "nreverse m3 vs gprolog"
dark "zero ref (was 0.000x)"      0   100     "deriv vs gprolog"
dark "non-numeric ours (was n/a)" 100 ERROR   "tak m4 vs swi"
dark "literal n/a ours"           100 n/a     "queens m3 vs gnu"
dark "empty ours"                 100 ""      "log10 m4 vs gnu"
dark "negative ours (was -20x)"   100 -5      "ham m3 vs swi"
dark "zero both"                  0   0       "crypt m3 vs gnu"
#-----------------------------------------------------------------------------------------------------
# B. A REAL MEASUREMENT IS UNTOUCHED.  ⛔ This half is why the gate can be trusted: a refusal rule that
# also broke live cells would be caught here, not in a grid three sessions later.
echo "B. a measurable subject still prints its multiple, unchanged"
# PERF_STAMP_OFF=1 HERE IS NOT THE TEST BEING BENT TO PASS -- it is this section testing the thing it was
# always about. CEO-743 welded a load stamp onto every standalone number, so a bare perf_mult now prints
# "2.000x   . load 3.21 on 16 cores"; B pins the VALUE FORMATTING, and PERF_STAMP_OFF is the documented
# composition path for a caller building its own line. The stamp law itself is pinned in section I below.
m() { local want="$1" got; got="$(PERF_STAMP_OFF=1 perf_mult "$2" "$3" 2>/dev/null)"
      [ "$got" = "$want" ] && ok "perf_mult $2 $3 = $want" || bad "perf_mult $2 $3" "$want" "$got"; }
m "2.000x"  100 50
m "0.500x"  50  100
m "1.000x"  7   7
m "1.628x"  1628 1000
p() { local want="$1" got; got="$(PERF_STAMP_OFF=1 perf_pct "$2" "$3" 2>/dev/null)"
      [ "$got" = "$want" ] && ok "perf_pct $2 $3 = $want" || bad "perf_pct $2 $3" "$want" "$got"; }
p "100.0% faster" 200 100
p "50.0% slower"  100 200
#-----------------------------------------------------------------------------------------------------
# C. A GRID REFUSES TO PUBLISH A COLUMN IT COULD NOT FILL, and cannot open without its load stamp.
echo "C. the grid refuses as a whole, and states the load it ran under"
hdr="$(perf_grid_begin "x vs gprolog · WORK basis · RT_OPT=-O0 · m4" 2>/dev/null)"
case "$hdr" in *load*core*) ok "perf_grid_begin states the load and the core count" ;;
               *) bad "perf_grid_begin must carry a load stamp" "contains 'load ... cores'" "$hdr" ;; esac
perf_grid_begin "x vs gprolog" >/dev/null 2>&1
perf_mult 100 50 "clean cell" >/dev/null 2>&1
out="$(perf_grid_end 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] && ok "a grid with no dark cell closes rc=0" || bad "clean grid must close rc=0" "rc=0" "rc=$rc ($out)"
perf_grid_begin "x vs gprolog" >/dev/null 2>&1
perf_mult 100 50 "clean cell"  >/dev/null 2>&1
perf_mult 100 0  "dark cell"   >/dev/null 2>&1
out="$(perf_grid_end 2>/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'GRID REFUSES'; then ok "a grid with one dark cell REFUSES rc=2 and says so"
else bad "grid with a dark cell must refuse" "rc=2 + 'GRID REFUSES'" "rc=$rc ($out)"; fi
#-----------------------------------------------------------------------------------------------------
# D. A MISSING OPERAND PRINTS A ROW RATHER THAN DELETING ONE -- shape (3), the invisible cell.
echo "D. a missing operand prints a refusing row instead of vanishing"
row="$(perf_row_or_refuse "nreverse m3 vs gnu" "" "" 2>/dev/null)"
if [ -n "$row" ] && printf '%s' "$row" | grep -q 'nreverse m3 vs gnu' && printf '%s' "$row" | grep -q 'REFUSED'
then ok "perf_row_or_refuse still prints the labelled row"; else bad "row must survive a missing operand" "a row naming the kernel + REFUSED" "'$row'"; fi
#-----------------------------------------------------------------------------------------------------
# E. ⛔ THE COMPOSITION -- AND IT IS THE ARM WHOSE ABSENCE LET A DEFECT SURVIVE INSIDE ITS OWN GATE.
# Arm C refuses a grid whose dark cell came from a DIRECT perf_mult call (parent shell, so the
# PERF_DARK_CELLS bump survives).  Arm D proves the row still prints.  NEITHER ARM COMPOSED THEM, and
# perf_row used to call perf_mult inside the printf's own $( ) -- a SUBSHELL, where the bump died.  So
# every refusal arriving through perf_row, WHICH IS THE PATH EVERY HARNESS ACTUALLY USES, was invisible
# to perf_grid_end and the grid closed rc=0 with a hole in it.  Both arms passed the whole time.
# ⭐ A SEAM BETWEEN TWO PASSING GUARDS IS WHERE A MECHANISM LEAKS -- test the composition, not the parts.
echo "E. a dark cell arriving through perf_row reaches the grid verdict (the subshell seam)"
perf_grid_begin "x vs rival" >/dev/null 2>&1
perf_row "kernel a m3 vs rival" 200 100 >/dev/null 2>&1
perf_row "kernel b m3 vs rival" 100 ""  >/dev/null 2>&1
out="$(perf_grid_end 2>/dev/null)"; rc=$?
if [ "$rc" -eq 2 ] && printf '%s' "$out" | grep -q 'GRID REFUSES'; then ok "a refusal through perf_row reaches perf_grid_end (rc=2)"
else bad "a refusal through perf_row must reach the grid verdict" "rc=2 + 'GRID REFUSES'" "rc=$rc ($out)"; fi
# ⭐ CONTROL ARM, and it is not optional: the cure must not make EVERY grid refuse.  Valid cells -> rc=0.
perf_grid_begin "x vs rival" >/dev/null 2>&1
perf_row "kernel a m3 vs rival" 200 100 >/dev/null 2>&1
perf_row "kernel b m4 vs rival" 100 200 >/dev/null 2>&1
out="$(perf_grid_end 2>/dev/null)"; rc=$?
[ "$rc" -eq 0 ] && ok "a grid of valid cells through perf_row still closes rc=0" || bad "a clean perf_row grid must close rc=0" "rc=0" "rc=$rc ($out)"
#-----------------------------------------------------------------------------------------------------
# F. THE HARNESSES THEMSELVES -- the law is worth nothing while no harness is wired to it.  Measured
# 2026-09-13: NOT ONE bench script called perf_grid_begin/perf_grid_end, so the whole-grid refusal
# guarded nothing in production, and four harnesses carried 10 sites of the row-deleting guard
#     [ -n "$ref" ] && [ -n "$ours" ] && perf_row ...
# which DELETES the row when an operand is missing -- shape (3), the invisible cell: the grid looks
# complete because nobody greps for a row that was never printed.
echo "F. the bench harnesses cannot delete a row, and they close the grid they open"
# ⭐ bench_prolog_perf.sh (angle 3) JOINED THIS LIST 2026-09-13 when it grew the two-number
# work/overhead basis: it formats its own aligned grids rather than perf_row rows, so it reaches the
# whole-grid verdict through perf_dark_cell -- arm H below is that path's own guard.
# ⭐ THE TWO REMAINING PROLOG ANGLES JOINED THIS LIST 2026-09-13 (hq_P) AND THEY WERE THE LAST GAP.
# Angle 1 (test_bench_prolog_timed.sh) closed with `perf_grid_end || true` over literal DARK/NA cells
# that never bumped the counter, so its grid verdict was structurally unable to fire; angle 2
# (bench_prolog_fixed_iter.sh) did not source lib_perf_fmt.sh AT ALL and hand-rolled its own LOAD line
# BELOW the grids.  Both now bump through perf_dark_cell and fold the verdict into their exit code.
# ⛔ Angle 1 is not named bench_*.sh, so arm G's census over "$HERE"/bench_*.sh never reached it either.
for h in bench_triangulate_pascal.sh bench_triangulate_prolog.sh bench_triangulate_raku.sh bench_triangulate_snobol4.sh bench_triangulate_demos_icon.sh bench_triangulate_demos_snobol4.sh bench_prolog_perf.sh test_bench_prolog_timed.sh bench_prolog_fixed_iter.sh; do
    f="$HERE/$h"
    [ -r "$f" ] || { bad "$h: unreadable" "a readable harness" "missing"; continue; }
    if grep -q '\[ -n "\$[a-zA-Z0-9_]*" \].*perf_row' "$f"; then
        bad "$h: row-deleting guard present" "no '[ -n ] && perf_row' idiom" "$(grep -c '\[ -n "\$[a-zA-Z0-9_]*" \].*perf_row' "$f") site(s)"
    # ⛔⭐ THE CENSUS READS CODE, NOT COMMENTS, AND THAT COST A FAIL-ONCE TO FIND (hq_P 2026-09-13).
    # This arm landed as a bare `grep -q 'perf_grid_begin' "$f"`, so A MENTION IN A COMMENT SATISFIED
    # IT.  Measured: commenting out bench_prolog_perf.sh's only perf_grid_begin CALL left the arm
    # green, because that harness's header explains what perf_grid_begin is for.  The arm was
    # therefore inert against the exact deletion it exists to catch -- on all six original entries
    # too, every one of which discusses the function it is being checked for.  A harness that
    # documents its own guard was the shape that disabled the guard.  Comment lines are stripped first.
    elif ! sed 's/^[[:space:]]*#.*$//' "$f" | grep -q 'perf_grid_begin'; then bad "$h: grid never opened" "a perf_grid_begin CALL (it carries the load stamp)" "no call outside comments"
    elif ! sed 's/^[[:space:]]*#.*$//' "$f" | grep -q 'perf_grid_end'; then bad "$h: grid never closed" "a perf_grid_end CALL (the whole-grid refusal)" "no call outside comments"
    else ok "$h: no row-deleting guard, grid opened and closed"; fi
done
#-----------------------------------------------------------------------------------------------------
# I. CEO-743: EVERY WALL-CLOCK NUMBER RECORDS THE LOAD AT MEASUREMENT, IN THE SAME LINE AS THE NUMBER.
# WHY THIS SECTION EXISTS RATHER THAN A NOTE IN A PROCEDURE: the ruling puts the stamp in lib_perf_fmt.sh
# "so it cannot be forgotten", and the census that earned it is that EIGHT bench scripts print multiples
# through perf_row and never call perf_grid_begin -- so the stamp the file already carried reached NONE of
# them. A law living only in the one entry point nobody calls is not a law.
# THE WARRANT IS A MEASUREMENT, NOT A PREFERENCE: one unchanged binary read 0.549x at load 6.96 and 0.384x
# at load 29.84, so the ratio moved by 30% of itself and the SIGN of the error is not knowable from inside
# the reading. Two such numbers are identical on paper and 30% apart in fact.
echo "I. every number carries the load it was measured under (CEO-743)"
# THE PRECONDITION IS SET EXPLICITLY, AND FINDING IT IS HALF THE VALUE OF THIS SECTION. Section C opens grids
# and the sections after it never close the last one, so PERF_GRID_OPEN was still 1 here and the first two
# arms failed on a library that was behaving correctly. That is worth stating rather than quietly working
# around: AN UNCLOSED GRID SILENTLY SUPPRESSES THE STAMP ON EVERY LATER STANDALONE NUMBER. A harness that
# forgets perf_grid_end is already broken -- it never reads its own dark-cell verdict -- but the second
# symptom is the quiet one, and a test that inherits ambient state from four sections above is not pinning
# what it claims to pin.
PERF_GRID_OPEN=0; PERF_ROWS_STAMPED=0
got="$(perf_mult 100 50 2>/dev/null)"
case "$got" in *load*core*) ok "a standalone perf_mult carries its load stamp" ;;
    *) bad "standalone perf_mult must carry a load stamp" "2.000x ... load N on C cores" "$got" ;; esac
got="$(perf_pct 200 100 2>/dev/null)"
case "$got" in *load*core*) ok "a standalone perf_pct carries its load stamp" ;;
    *) bad "standalone perf_pct must carry a load stamp" "100.0% faster ... load N on C cores" "$got" ;; esac
got="$(PERF_STAMP_OFF=1 perf_mult 100 50 2>/dev/null)"
case "$got" in *load*) bad "PERF_STAMP_OFF must suppress the stamp for a caller composing its own line" "2.000x" "$got" ;;
    *) ok "PERF_STAMP_OFF=1 suppresses the stamp (the composition path)" ;; esac
# INSIDE A GRID THE ROWS STAY BARE. The FACT RULE is that a grid names its axis ONCE in the header and its
# rows carry bare multiples, so a stamp on every row would break the very grid it is trying to make honest.
got="$( perf_grid_begin "x vs rival" >/dev/null 2>&1; perf_row "alpha" 100 50 2>/dev/null )"
case "$got" in *load*) bad "a row inside an opened grid must stay bare" "alpha ... 2.000x" "$got" ;;
    *) ok "a row inside an opened grid stays bare (its header carried the stamp)" ;; esac
# AND THE SEAM THAT MATTERS: rows printed with NO perf_grid_begin -- the shape of all eight bench scripts --
# must still emit the stamp, exactly ONCE, ahead of the first row.
got="$( PERF_GRID_OPEN=0; PERF_ROWS_STAMPED=0; perf_row "alpha" 100 50 2>/dev/null; perf_row "beta" 100 80 2>/dev/null )"
nload=$(printf '%s\n' "$got" | grep -c "load")
[ "$nload" -eq 1 ] && ok "rows with no perf_grid_begin self-stamp exactly once (got $nload)" \
                   || bad "gridless rows must stamp exactly once" "1 load line" "$nload load line(s)"
#-----------------------------------------------------------------------------------------------------
# G. NO HARNESS MAY CALL perf_row INSIDE $( ).  ⛔ THIS IS ARM E's SEAM ONE LEVEL OUT, AND IT SURVIVED
# ARM E's CURE.  perf_row was fixed to bump PERF_DARK_CELLS in its OWN shell, but a CALLER writing
#     echo "    $(perf_row ...)"
# puts perf_row in a subshell of its own making, so the bump dies there exactly as it used to die
# inside the printer -- and the grid closes rc=0 with a hole in it.  Measured 2026-09-13 on the two
# demos harnesses, the last three such sites in the tree: wrapped read PERF_DARK_CELLS=0 / grid rc=0,
# unwrapped read 1 / rc=2 on the identical refusing cell.
# ⭐ THE REASON THIS IS A GATE AND NOT A NOTE: arm F checks that a harness OPENS and CLOSES a grid,
# and a $( )-wrapped caller passes arm F while its verdict cannot fail.  A guard that is satisfied by
# the broken shape is the shape this lane keeps paying for -- so the census that found it lives here now.
echo "G. no bench harness calls perf_row inside a subshell"
gsites=0
for f in "$HERE"/bench_*.sh; do
    [ -r "$f" ] || continue
    n="$(grep -c '\$(perf_row' "$f" 2>/dev/null)" || n=0
    [ "$n" -eq 0 ] || { bad "$(basename "$f"): perf_row wrapped in \$( )" "a direct call (the dark-cell bump must land in the harness's own shell)" "$n site(s)"; gsites=$((gsites+n)); }
done
[ "$gsites" -eq 0 ] && ok "no bench harness wraps perf_row in \$( ) (census over $HERE/bench_*.sh)"
#-----------------------------------------------------------------------------------------------------
# H. perf_dark_cell -- THE HAND-PRINTED DARK CELL'S ONLY ROUTE TO THE GRID VERDICT.  A harness that
# formats its own grid (the three Prolog angle harnesses print aligned work/overhead tables, not
# perf_row rows) writes the cell text itself, so nothing it prints can bump the counter.  Before this
# function existed, angle 1 landed printing literal "DARK" cells and closing with `perf_grid_end ||
# true`: the counter was never touched by the cells it exists to count, and the `|| true` discarded
# even that.  ⛔ TWO PROPERTIES, AND THE SECOND IS ARM E's SEAM AGAIN -- it must print NOTHING on
# stdout, because a caller forced to capture it in $( ) would bump in a subshell of its own making.
echo "H. perf_dark_cell bumps the caller's own counter and prints nothing on stdout"
# ⭐ THE FIRST DRAFT OF THIS ARM FAILED ITSELF, AND THE FAILURE IS THE POINT: it captured the call as
# sout="$(perf_dark_cell ...)" to inspect stdout, and the bump then died in THAT subshell -- arm G's
# defect, committed by the test written to guard against it, caught on the first run.  The two
# properties cannot be read from ONE call: capturing stdout requires a subshell, and the bump only
# lands in the caller's shell.  So the captured calls prove the OUTPUT contract and a DIRECT call
# proves the COUNTER contract -- which is exactly the discipline a harness must follow.
perf_grid_begin "x vs rival" >/dev/null 2>&1
sout="$(perf_dark_cell "kernel q / gnu" "its bracket reported no work_us" 2>/dev/null)"   # subshell ON PURPOSE: stdout only
[ -z "$sout" ] && ok "perf_dark_cell prints nothing on stdout (so no caller is pushed into \$( ))" \
                || bad "perf_dark_cell wrote to stdout" "nothing" "'$sout'"
serr="$(perf_dark_cell "kernel q / swi" "no bracket" 2>&1 >/dev/null)"                    # subshell ON PURPOSE: stderr only
case "$serr" in *"kernel q / swi"*) ok "perf_dark_cell names its subject on stderr" ;;
  *) bad "perf_dark_cell must name its subject" "the subject in the stderr text" "'$serr'" ;; esac
PERF_DARK_CELLS=0
perf_dark_cell "kernel q / m3" "its bracket reported no work_us" 2>/dev/null              # ⛔ DIRECT: the bump must land HERE
[ "${PERF_DARK_CELLS:-0}" -eq 1 ] && ok "perf_dark_cell bumped the count in the caller's shell (1)" \
                || bad "perf_dark_cell did not bump the caller's counter" "PERF_DARK_CELLS=1" "PERF_DARK_CELLS=${PERF_DARK_CELLS:-unset}"
out="$(perf_grid_end 2>/dev/null)"; rc=$?
[ "$rc" -eq 2 ] && ok "a grid carrying hand-printed dark cells REFUSES (rc=2)" \
                || bad "perf_dark_cell must reach perf_grid_end" "rc=2" "rc=$rc ($out)"
#-----------------------------------------------------------------------------------------------------
printf '\nGATE %s -- pass=%s fail=%s\n' "$([ "$FAIL" -eq 0 ] && echo PASS || echo FAIL)" "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
