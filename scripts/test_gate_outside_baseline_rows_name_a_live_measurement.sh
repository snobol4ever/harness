#!/usr/bin/env bash
# ../harness/scripts/test_gate_outside_baseline_rows_name_a_live_measurement.sh -- EVERY OUTSIDE-BASELINE EXCLUSION NAMES
# THE MEASUREMENT THAT PUT IT THERE, AND THE ORACLE STILL AGREES TODAY.
# AUTHORS: Lon Jones Cherryholmes · Claude Opus 5   DATE: 2026-09-11
#
# ⛔⭐⭐ AN EXCLUSION IS A SUBTRACTION FROM THE DENOMINATOR, SO ITS REASON IS A NUMBER, NOT PROSE. Every row in
# a package's OUTSIDE_SPITBOL_BASELINE.tsv removes one program from the score anyone quotes. The record is
# hand-maintained -- nothing generates it, unlike a container's ALL.excluded.txt -- which is exactly why it
# needs an instrument: a reason written by a hand and re-read by a hand only ever re-confirms itself.
#
# ⛔⭐ THE CLASS THIS WAS BUILT AGAINST, measured 2026-09-11 by hq_R across all six SNOBOL4 packages (149 rows):
# FIVE csnobol4 rows read `sbl -bf rc=1: ` -- the diagnostic they promise to quote is the EMPTY STRING. The
# oracle is not silent on any of them; it prints ERROR 230, ERROR 214 and ERROR 014 x3. Whoever composed those
# reasons took the oracle's FIRST line, and sbl -bf opens with three blank lines and a banner. So five programs
# left the denominator on the strength of a quotation of nothing, and nothing has re-asked since 2026-09-07.
# ⭐ THE SAME SHAPE, THIRD SUITE DEEP: the IPL container's 65 ORACLE_FAIL reasons were hand-composed the same
# way (SCRIP bbcaff43a), and the cure there was the same -- re-ask the oracle, never re-spell the reason.
#
# ⛔ A REF DIAGNOSTIC IS A DEATH CERTIFICATE, NOT A CAUSE OF DEATH, and this gate is why that matters here.
# `No END statement found in source file(s).` is what SPITBOL prints after it has ALREADY aborted on a fatal
# error and therefore never reached the END -- so it is the last line for a whole family of unrelated causes.
# Measured on the 14 csnobol4 rows that quote it: THIRTEEN are honest (the oracle emits no ERROR NNN at all,
# so the certificate is the only diagnostic there is), and ONE -- crlf.sno -- is really ERROR 230 illegal
# character. ⭐ That is why ARM 3 keys on the quoted ERROR NNN rather than on the whole line: a row that names
# a number makes a falsifiable claim, and a row that names only the certificate makes none.
#
# ⛔⭐⭐ AN rc=124 IS NOT A REFUSAL AND IS NEVER STALE -- THE THIRD NARROWING OF ARM 2, found by hq_P 2026-09-12 by
# landing CEO-591 against this gate. ARM 2 decided a ruling was stale by asking whether the oracle's output holds
# an ERROR NNN or the no-END certificate. A program the oracle NEVER FINISHES prints NEITHER, so the arm rendered
# rc=0-with-no-diagnostic and rc=124-with-no-diagnostic IN THE SAME SENTENCE -- 'refuses this program with no
# diagnostic today; it belongs back in the denominator' -- when they are opposite facts. It told hq_P to readmit
# gimpel's PHRASE_driver and QUEST_driver, measured rc=124 with ZERO output at 25s AND at 90s, fed from their own
# .input fixture and unfed alike: following it would have put TWO PERMANENT TIMEOUTS into a graded denominator.
# ⭐ THE CURE IS A BRANCH BEFORE THE DIAGNOSTIC TEST, AND IT IS SHARPER THAN 'EXEMPT THE TIMEOUTS'. 'The oracle
# never finishes' IS ITSELF A FALSIFIABLE CLAIM, so this gate grades it the same way it grades a quoted ERROR NNN:
#   · rc=124 + the row claims non-termination  -> CONFIRMED LIVE, with the elapsed time and the budget. Not a defect.
#   · rc=124 + the row quotes a diagnostic     -> WRONG CAUSE: the oracle never reached any refusal it could print,
#                                                 so the row promises a quotation the oracle cannot make.
# ⛔ AND THE VERDICT NAMES THE BUDGET, NEVER 'DOES NOT TERMINATE': this instrument can only ever witness 'did not
# finish within Ns'. --timeout raises N for a package owner who wants a stronger witness without editing the gate.
# ⭐ WHY THIS ONE IS WORTH A PARAGRAPH RATHER THAN A LINE: the gate was not careless, it was CAREFUL AND STILL
# NARROW -- its own header already documents two earlier versions of this exact error (keying ARM 2 on rc, and $?
# after a pipeline reading tr's status, which called 78 sound rulings stale), and the warning it needed was already
# written one file away, unprompted, in test_gate_package_runners_print_the_inventory: 'an rc=124 is a TIMEOUT
# FIRING ... it cannot distinguish needs-8.1s from never-finishes. If a verdict turns on duration, record the
# duration.' A correct warning in a neighbouring file is not wired into anything. THAT is why the duration is
# printed here and why the classes must close over the population below.
#
# ⛔ THIS IS NOT A BOARD AND MUST NEVER BECOME ONE (ONE RUNNER, ONE BOARD -- only the coo runs a package board).
# It runs the ORACLE ALONE over the recorded rows only, never scrip, never the shipped set, and prints no
# pass/total for any suite. Its denominator is the RECORD's size, which is the only population it grades.
#
# Usage: bash ../harness/scripts/test_gate_outside_baseline_rows_name_a_live_measurement.sh [--package <name>] [--strict] [--timeout <s>]
# rc=0 every recorded row names a live measurement · rc=1 a row does not · rc=2 cannot measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
PKGROOT="$ROOT/../corpus/packages/snobol4"
ONLY=""; STRICT=0; TMO=25
while [ $# -gt 0 ]; do case "$1" in --package) ONLY="${2:-}"; shift 2;; --strict) STRICT=1; shift;; --timeout) TMO="${2:-}"; shift 2;; *) echo "⛔ REFUSES(2): unknown argument $1" >&2; exit 2;; esac; done
case "$TMO" in *[!0-9]*|"") echo "⛔ REFUSES(2): --timeout wants a whole number of seconds, not '$TMO' -- a budget this gate prints in its own verdict is never guessed" >&2; exit 2;; esac
[ "$TMO" -gt 0 ] || { echo "⛔ REFUSES(2): --timeout 0 would make every row read as non-terminating" >&2; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSES(2): lib_oracle_flags.sh unloadable -- the ONE oracle authority" >&2; exit 2; }
SBL="$(sbl_correctness_bin)" || { echo "⛔ REFUSES(2): sbl_correctness_bin refused -- no correctness oracle" >&2; exit 2; }
[ -x "$SBL" ] || { echo "⛔ REFUSES(2): oracle not executable at $SBL -- a missing oracle prints a full, plausible, entirely false table" >&2; exit 2; }
FLAGS="$(sbl_lang_flags)"
[ -d "$PKGROOT" ] || { echo "⛔ REFUSES(2): no snobol4 packages at $PKGROOT" >&2; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
ROWS=0; PKGS=0; GOOD=0; BAD_EMPTY=0; BAD_STALE=0; BAD_CAUSE=0; NT_OK=0; NT_BAD=0
# ⛔⭐ WHY ONLY ARM 1 BLOCKS BY DEFAULT, AND IT IS A SCOPE RULE RATHER THAN A CONFIDENCE ONE. A vacuous reason is
# a DOCUMENTATION defect: correcting it changes no score, so any seat may fix it and this gate may demand it.
# A stale ruling or a wrong cause PROPOSES A DENOMINATOR CHANGE -- the program goes back into, or moves within,
# a score somebody quotes -- and a denominator belongs to the board owner (ONE RUNNER, ONE BOARD), not to
# whoever happened to run this gate. So ARMs 2 and 3 are MEASURED and NAMED aloud on every run and blocked only
# under --strict, which each package owner turns on once their own record is clean. ⭐ Reporting is not
# softness here: the count is printed in the board line either way, so the debt cannot go quiet.
LBL2="⚠ REPORTED"; LBL3="⚠ REPORTED"; [ "$STRICT" = 1 ] && { LBL2="⛔ FAIL"; LBL3="⛔ FAIL"; }
# ⛔ THE ORACLE RUNS IN A THROWAWAY COPY OF THE PACKAGE DIRECTORY, NEVER IN THE CORPUS TREE. util_snobol4_oracle_
# census.sh records that its own first run left spitlib.idx, openo.tst, test.bin and ASMTEMP behind in the tracked
# tree; these programs open files by name, and several of the recorded ones are exactly the file-I/O refusals.
for tsv in "$PKGROOT"/*/OUTSIDE_SPITBOL_BASELINE.tsv; do
    [ -f "$tsv" ] || continue
    pkg="$(basename "$(dirname "$tsv")")"
    [ -n "$ONLY" ] && [ "$ONLY" != "$pkg" ] && continue
    src_dir="$(dirname "$tsv")"
    PKGS=$((PKGS+1)); n_pkg=0
    work="$TMP/$pkg"; mkdir -p "$work"; cp -r "$src_dir/." "$work/" 2>/dev/null
    # ⛔⭐ THE INCLUDES MUST BE FLAT IN CWD, WHICH IS THE PACKAGE RUNNER'S CONTRACT, NOT AN INVENTION.
    # test_snoflake_suite.sh:95 symlinks gimpel/*.INC and *.IN into its run dir; SPITBOL resolves -INCLUDE
    # relative to cwd and has no search path. A recursive copy alone leaves them one directory down, and the
    # oracle then answers ERROR 285 -- include file cannot be opened -- for THIRTY-ONE programs whose recorded
    # reason is perfectly correct. ⭐ That false table is what this gate printed on its first run, and it is the
    # same defect as the qei PATH bug: an instrument that does not declare the environment measures its own
    # cwd, states the result in the vocabulary of the thing under test, and accuses the record of being wrong.
    find "$work" -mindepth 2 \( -name '*.INC' -o -name '*.IN' \) -exec cp -n {} "$work"/ \; 2>/dev/null
    while IFS=$'\t' read -r name verdict reason _rest; do
        case "$name" in ''|'#'*) continue;; esac
        [ -n "${reason:-}" ] || { echo "⛔ FAIL [$pkg] $name -- the row has no reason column at all"; BAD_EMPTY=$((BAD_EMPTY+1)); ROWS=$((ROWS+1)); n_pkg=$((n_pkg+1)); continue; }
        ROWS=$((ROWS+1)); n_pkg=$((n_pkg+1))
        # ARM 1 -- THE REASON PROMISES A QUOTATION AND MUST DELIVER ONE. A reason whose last non-space character
        # is a colon quoted the empty string: it reads as a measurement and carries nothing falsifiable.
        case "$(printf '%s' "$reason" | sed 's/[[:space:]]*$//')" in
            *:) echo "⛔ FAIL [$pkg] $name -- ARM 1 VACUOUS REASON: the row quotes the empty string: '$reason'"; BAD_EMPTY=$((BAD_EMPTY+1)); continue;;
        esac
        [ -f "$work/$name" ] || { echo "$LBL2 [$pkg] $name -- recorded outside the baseline but the program is not in the package"; BAD_STALE=$((BAD_STALE+1)); continue; }
        stem="${name%.*}"; inp=/dev/null; [ -f "$work/$stem.in" ] && inp="$work/$stem.in"
        # ⛔ $? AFTER A PIPELINE IS THE LAST COMMAND'S STATUS, NOT THE ORACLE'S. Written the obvious way this read
        # `tr`'s rc -- always 0 -- so ARM 2 called SEVENTY-EIGHT rulings stale on a first run: a full, plausible,
        # entirely false table. util_snobol4_oracle_census.sh already carries the cure; this is the same one.
        t0="${EPOCHREALTIME/./}"
        out="$(cd "$work" && timeout -k 5 "$TMO" "$SBL" $FLAGS "$name" < "$inp" 2>&1 | tr -d '\000'; exit "${PIPESTATUS[0]}")"; rc=$?
        ds=$(( ( ${EPOCHREALTIME/./} - t0 ) / 100000 )); el="$((ds/10)).$((ds%10))"; nb="$(printf '%s' "$out" | wc -c)"
        # ARM 2a -- ⛔ THE ORACLE NEVER FINISHED, WHICH IS NOT A REFUSAL AND NOT A STALE RULING. Decided BEFORE the
        # diagnostic test below and regardless of any partial output, because a program that has not terminated has
        # not refused anything: whatever it printed so far is a prefix, never a verdict. `timeout` alone answers 124;
        # a 137/143 is a SIGKILL/SIGTERM from somewhere else, which is a crash and belongs to the arms below.
        if [ "$rc" -eq 124 ]; then
            if printf '%s' "$reason" | grep -qiE 'rc=124|does not (terminate|finish|halt|complete)|did not (terminate|finish|halt|complete)|never (terminates|finishes|halts|returns)|non-?terminat|hangs|infinite loop'; then
                echo "   NON-TERMINATING [$pkg] $name -- CONFIRMED LIVE: the oracle did not finish within ${TMO}s (elapsed ${el}s, ${nb} byte(s) of output), which is what the row claims"
                NT_OK=$((NT_OK+1)); continue
            fi
            echo "$LBL3 [$pkg] $name -- ARM 2a NON-TERMINATING BUT THE ROW QUOTES A DIAGNOSTIC: the oracle did not finish within ${TMO}s (elapsed ${el}s, ${nb} byte(s) of output), so it never reached any refusal it could print; the reason must name the non-termination and its budget instead of promising a quotation the oracle cannot make: '$reason'"
            NT_BAD=$((NT_BAD+1)); continue
        fi
        # ARM 2 -- THE RULING IS NOT STALE, AND ⛔ rc IS NOT THE SIGNAL. Measured: `sbl -bf test4.spt` prints
        # `ERROR 116 -- inappropriate file specification for input` and EXITS 0. Keying this arm on rc called
        # SEVENTY-EIGHT sound rulings stale on the first run -- a confident, stable, entirely false table, and the
        # same rc=0-with-a-refusal shape hq_V recorded for the `No END statement` family. A SPITBOL refusal is a
        # FATAL DIAGNOSTIC IN THE OUTPUT: an ERROR NNN line, or the no-END certificate it prints after aborting.
        if ! printf '%s\n' "$out" | grep -qE 'ERROR [0-9]{3}|No END statement found'; then
            echo "$LBL2 [$pkg] $name -- ARM 2 STALE RULING: the oracle RAN TO COMPLETION in ${el}s (rc=$rc, ${nb} byte(s) of output) and printed no fatal diagnostic today; it belongs back in the denominator"
            BAD_STALE=$((BAD_STALE+1)); continue
        fi
        # ARM 3 -- A QUOTED ERROR NNN IS A FALSIFIABLE CLAIM, SO FALSIFY IT. Rows that quote no error number
        # (the `No END statement` family, where the oracle genuinely emits none) make no claim for this arm to test.
        want="$(printf '%s' "$reason" | grep -o 'ERROR [0-9]\{3\}' | head -1)"
        if [ -n "$want" ] && ! printf '%s\n' "$out" | grep -q "$want"; then
            got="$(printf '%s\n' "$out" | grep -o 'ERROR [0-9]\{3\} -- .*' | head -1)"
            echo "$LBL3 [$pkg] $name -- ARM 3 WRONG CAUSE: the row names '$want' and the oracle now says '${got:-<no ERROR NNN at all>}'"
            BAD_CAUSE=$((BAD_CAUSE+1)); continue
        fi
        GOOD=$((GOOD+1))
    done < "$tsv"
    echo "   [$pkg] $n_pkg recorded row(s) re-asked"
done
[ "$ROWS" -gt 0 ] || { echo "⛔ REFUSES(2): zero recorded rows over $PKGS package(s) -- this gate cannot grade a vacuous population"; exit 2; }
BAD=$((BAD_EMPTY+BAD_STALE+BAD_CAUSE+NT_BAD)); RPT=$((BAD_STALE+BAD_CAUSE+NT_BAD))
echo "OUTSIDE_BASELINE_REASONS packages=$PKGS rows=$ROWS good=$GOOD vacuous=$BAD_EMPTY stale=$BAD_STALE wrong_cause=$BAD_CAUSE nonterm_confirmed=$NT_OK nonterm_wrong_reason=$NT_BAD strict=$STRICT budget=${TMO}s -- oracle $SBL $FLAGS"
# ⛔⭐ THE CLASSES MUST CLOSE OVER THE POPULATION, and this is the CEO-582 lesson arriving one level down: a loop of
# `continue` arms has one silent failure mode -- a path that classifies nothing -- and it reads GREEN, because every
# counter it did not touch is still zero. Six classes summing to rows is the only statement that catches it, and an
# instrument that cannot account for its own denominator REFUSES rather than reporting a total it did not build.
ACC=$((GOOD+BAD_EMPTY+BAD_STALE+BAD_CAUSE+NT_OK+NT_BAD))
[ "$ACC" -eq "$ROWS" ] || { echo "⛔ REFUSES(2): the classes do not close over the population -- good+vacuous+stale+wrong_cause+nonterm=$ACC but rows=$ROWS; a row left the loop unclassified and a partial pass must never read as a clean one"; exit 2; }
if [ "$STRICT" = 1 ]; then
    [ "$BAD" -eq 0 ] || { echo "⛔ FAIL: $BAD of $ROWS outside-baseline rows do not name a measurement the oracle still makes (--strict)"; exit 1; }
else
    [ "$BAD_EMPTY" -eq 0 ] || { echo "⛔ FAIL: $BAD_EMPTY of $ROWS outside-baseline rows quote the empty string -- a program left the denominator on a quotation of nothing"; exit 1; }
    [ "$RPT" -eq 0 ] && echo "✅ PASS: all $ROWS rows across $PKGS package(s) name a non-vacuous diagnostic the oracle still makes today -- $GOOD quote a refusal it still prints, $NT_OK claim a non-termination it still shows within ${TMO}s" \
        || echo "✅ PASS (ARM 1): no vacuous reason in $ROWS rows; ⚠ $RPT row(s) REPORTED above for their package owner ($NT_OK non-termination(s) CONFIRMED, not counted against them) -- re-run with --strict to block on them"
fi
exit 0
