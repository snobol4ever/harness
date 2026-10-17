#!/usr/bin/env bash
# util_package_inventory_cause.sh — WHY does this package's board cell carry no runner-written
# PACKAGE_INVENTORY clause? Prints exactly one CAUSE line for one package, and never guesses.
#
# Row package-shipped-per-lane-printed-by-the-runner-not-transcribed (hq_T).
#
# ⛔⭐ WHY THIS EXISTS. util_score_row.py's work line can observe only an ABSENCE -- it reads the cell and
# nothing else -- so on 2026-09-10 it named ONE cause ("the runner is not retrofitted"), was measured wrong
# for both packages it reported that day, and was cured to name TWO. On 2026-09-11 the same line was wrong
# again, in the same direction, for FOUR of the seven packages it reports: snobol4's gimpel, aisnobol,
# dotnet and testpgms are ALL wired AND their sidecars validate (ARM 20 pins all four), so NEITHER named
# cause holds -- their cells are prose only because no suite pass has rewritten them since the carriage
# landed, and under ONE RUNNER ONE BOARD (CEO-523) only the coo may run one.
# ⭐⭐ THE GENERAL FORM, and it is the reusable half: A DIAGNOSTIC THAT CAN ONLY OBSERVE AN ABSENCE MUST
# ENUMERATE EVERY CAUSE OF THE ABSENCE, AND ENUMERATING FROM MEMORY IS HOW YOU GET TWO OF FOUR. Each
# enumeration was written by someone who had just measured the cause in front of them and then generalised.
# The cure is not a longer list -- it is to stop enumerating and MEASURE the cause, which is cheap here
# (a directory, a grep, one call to the shared body) and was cheap on both earlier days too.
# ⛔ A wrong cause is not a cosmetic defect: it is a WORK LIST. This row's own baton told its next reader to
# do "the CARRIAGE half" on four runners whose carriage has been correct and pushed for days.
#
# Usage: bash ../harness/scripts/util_package_inventory_cause.sh <lang> <label> <clause-regex>
#   e.g. bash ../harness/scripts/util_package_inventory_cause.sh snobol4 testpgms 'spitbol_testpgms|testpgms'
# Prints one line: `CAUSE=<A|B|C|D> <label>: <text>`. rc=0 a cause was determined · rc=2 CANNOT MEASURE.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
[ "$#" -eq 3 ] || { echo "REFUSE(2): usage: $(basename "$0") <lang> <label> <clause-regex>"; exit 2; }
LANG_="$1"; LABEL="$2"; RX="$3"
. "$HERE/lib_inventory.sh" 2>/dev/null || { echo "REFUSE(2): lib_inventory.sh unloadable -- cannot call the shared body"; exit 2; }
PKGINV_CORPUS="${PKGINV_CORPUS:-$ROOT/../corpus}"
LANGDIR="$PKGINV_CORPUS/packages/$LANG_"
# ⭐ THE MATCH IS THE CELL'S OWN REGEX, UNANCHORED AND CASE-INSENSITIVE, exactly as util_score_row.py joins
# a clause key to a table label (`re.search(rx, k, re.I)`, util_score_row.py:2556) -- never a second
# spelling of the join. Three labels already differ from their package directory (testpgms/spitbol_testpgms,
# snoflake/snoflake_suite, gnu/gnu_prolog), and a reader that re-invented the join would report a package as
# MISSING, which looks exactly like honest work.
# ⛔ MEASURED, IN THIS SCRIPT, BEFORE IT SHIPPED: the first version matched case-SENSITIVELY and reported
# pascal/PAT as "NO VENDORED PACKAGE CORPUS" while packages/pascal/pat sat right there -- because `\bPAT\b`
# is written for a cell whose text says PAT and a directory that spells itself pat. ⭐ A JOIN COPIED FROM
# ONE PAIR OF THINGS TO ANOTHER KEEPS THE SPELLING AND LOSES THE RULE; the rule lived one line away in the
# reader this script exists to serve, and the copy was made by reading the regex rather than its consumer.
MATCHED=""
if [ -d "$LANGDIR" ]; then
    for _d in "$LANGDIR"/*/; do
        [ -d "$_d" ] || continue
        if printf '%s' "$(basename "$_d")" | grep -qiE "$RX"; then MATCHED="$MATCHED $(basename "$_d")"; fi
    done
fi
MATCHED="${MATCHED# }"
_n="$(printf '%s' "$MATCHED" | wc -w)"
# ⛔⭐ NARROWED ONCE, BY THE ONE FACT THAT IS ABOUT THE BODY'S OWN INPUT, AND THEN NEVER AGAIN. `jcon`
# matches three directories and `gnu` two; in both cases exactly one carries the UNGRADABLE/UNGRADED
# sidecars the shared body reads, so that is the directory whose data a clause would come from. This is a
# narrowing, not a guess, and it is bounded: if it does not leave exactly one, this reader REFUSES.
if [ "$_n" -gt 1 ]; then
    _narrow=""
    for _m in $MATCHED; do
        if [ -f "$LANGDIR/$_m/UNGRADABLE.tsv" ] || [ -f "$LANGDIR/$_m/UNGRADED.tsv" ]; then _narrow="$_narrow $_m"; fi
    done
    _narrow="${_narrow# }"
    if [ "$(printf '%s' "$_narrow" | wc -w)" -eq 1 ]; then
        echo "    note $LABEL: its regex matched $_n directories ($MATCHED); narrowed to $_narrow, the only one carrying the sidecars the shared body reads" >&2
        MATCHED="$_narrow"; _n=1
    fi
fi
# ⛔ AMBIGUITY IS REPORTED, NEVER RESOLVED BY PICKING. `gnu`'s regex matches gnu_prolog AND gnu_examples;
# a reader that silently took the first would publish a cause measured on the wrong directory.
if [ "$_n" -gt 1 ]; then
    echo "CAUSE=? $LABEL: its clause regex ($RX) matches $_n package directories under packages/$LANG_ ($MATCHED) -- this reader will not pick one for it; narrow the regex in PROGRESS_COUNTED or rename the directory"
    exit 2
fi
if [ "$_n" -eq 0 ]; then
    echo "CAUSE=A $LABEL: NO VENDORED PACKAGE CORPUS -- nothing under packages/$LANG_ matches its clause regex ($RX), so there is no runner to retrofit and no sidecar to validate. The table declares a population this tree does not ship; the work is to land the package (or retire the declaration), never to edit a runner."
    exit 0
fi
PKGDIR="$LANGDIR/$MATCHED"
# WIRED? -- a runner is wired when it assigns INV_PACKAGE to a token this cell's own regex matches.
# ⛔ Only `test_*.sh` count: lib_inventory.sh carries INV_PACKAGE in its own documentation and is the body,
# never a runner, so a grep over all of ../harness/scripts/ reports the body as the carrier of every package it names.
# ⛔ MATCHED ANYWHERE ON THE LINE, NOT ONLY AT ITS START. The four-token stanza is written `;`-joined on one
# line by at least one runner (`INV_PACKAGE=fpc; INV_DIR="$SUITE"; INV_EXT=".pas"`,
# test_pascal_fpc_suite.sh:127), and a `^`-anchored extractor answers "is this token at a line start", which
# is not the question. ⭐ Same family as the unanchored-glob trap in CLAUDE.md: an instrument that answers a
# narrower question than you think you asked will never say so -- here it said the runner declared no
# extension, of a runner whose extension is in plain sight.
# ⛔ ONE grep OVER ALL RUNNERS, NOT ONE PER RUNNER. The first version looped, spending a process per script
# across ~200 of them: every call cost 1.3s BEFORE it read a single sidecar row, so aisnobol (2 declared
# rows) and gimpel (174) timed within a second of each other -- the tell that the cost was not in the data.
# ⭐ The lane already has this exact residue named one level down (`_inv_names`, three subprocesses per row
# over ipl's 851); it is cheaper to not write it again than to name it again.
WIRED="$(grep -ohE '(^|[;[:space:]])INV_PACKAGE=[A-Za-z0-9_.-]+' "$HERE"/test_*.sh 2>/dev/null \
         | sed 's/.*INV_PACKAGE=//' | sort -u | grep -iE "$RX" \
         | while IFS= read -r _t; do grep -lE "(^|[;[:space:]])INV_PACKAGE=$_t([;[:space:]]|$)" "$HERE"/test_*.sh 2>/dev/null | while IFS= read -r _f; do basename "$_f"; done; done | sort -u | tr '\n' ' ')"
WIRED="$(printf '%s' "$WIRED" | sed 's/[[:space:]]*$//')"
if [ -z "$WIRED" ]; then
    echo "CAUSE=B $LABEL: NOT WIRED -- packages/$LANG_/$MATCHED ships, but no test_*.sh assigns INV_PACKAGE to a token its regex matches, so no runner can emit a clause. THIS ONE IS CARRIAGE WORK: add the four-token stanza (INV_PACKAGE/INV_DIR/INV_EXT then INV_LINE=\"\$(inventory_line <graded> 0)\") and splice \${INV_LINE:+ · \$INV_LINE} into the --text."
    exit 0
fi
# ⭐ EXTENSION FROM THE DATA, NEVER A LANG->EXT MAP -- ARM 20's rule, for ARM 20's reason: a map here is one
# more number typed into an instrument, which is this row's whole subject.
EXT="$(cat "$PKGDIR/UNGRADABLE.tsv" "$PKGDIR/UNGRADED.tsv" 2>/dev/null | grep -v '^#' | grep -v '^[[:space:]]*$' \
       | cut -f1 | sed -n 's/.*\(\.[A-Za-z0-9]*\)$/\1/p' | sort -u)"
EXT_FROM="its sidecars' own name column"
if [ "$(printf '%s\n' "$EXT" | grep -c .)" -ne 1 ]; then
    # ⛔ A PACKAGE WITH NO SIDECARS IS NOT A PACKAGE WITH AMBIGUOUS ONES, and the first draft of this script
    # reported pascal/fpc_tests -- which ships no UNGRADABLE/UNGRADED at all -- as "declares 0 shipped
    # extensions", a sentence that sends its reader to fix a name column that does not exist. ⭐ ZERO AND
    # MANY ARE DIFFERENT ANSWERS; a `-ne 1` test collapses them, and the collapsed message always describes
    # the MANY case, because that is the one its author had in front of them.
    EXT="$(grep -oE '(^|[;[:space:]])INV_EXT="?\.[A-Za-z0-9]+' "$HERE/$(printf '%s' "$WIRED" | cut -d" " -f1)" 2>/dev/null | head -1 | sed 's/.*INV_EXT="\?//')"
    EXT_FROM="its wired runner's own INV_EXT (no sidecar name column to read)"
    if [ -z "$EXT" ]; then
        echo "CAUSE=? $LABEL: WIRED by $WIRED, but this reader could derive no shipped extension for it -- neither its sidecars' name column nor the runner's own INV_EXT yields exactly one -- so it cannot call the shared body and will not pick one. Run test_gate_package_runners_print_the_inventory.sh ARM 20, which refuses on the same disagreement."
        exit 2
    fi
fi
# ⛔⭐⭐ THE ARITHMETIC REFUSAL IS NOT CLEAN HERE, AND IMPORTING ARM 20'S EXEMPTION IS THE ONE MEASURED BUG
# THIS SCRIPT SHIPPED WITH (coo, 2026-09-11: "I RAN THE PASS YOU SAID WAS OWED AND IT REFUSES"). ARM 20
# declares the bucket sum out of scope and is RIGHT to: it grades whether a package's data is HONEST, and
# the sum needs a graded count only a suite pass produces. THIS reader answers a different question -- WILL A
# PASS PRODUCE A CLAUSE -- and for that question the arithmetic is decisive. gimpel declares ungradable=174
# against shipped=292, so a pass emits a clause only if it grades exactly 118; the coo's pass graded 132, the
# buckets did not sum, and no clause could be computed. CAUSE=D told the only seat who may run a board that
# one pass would fix a cell that every future pass refuses identically.
# ⭐⭐ THE GENERAL FORM, and it is the sharper half: AN EXEMPTION COPIED BETWEEN INSTRUMENTS ARRIVES WITH ITS
# JUSTIFICATION ATTACHED AND ITS SCOPE SILENTLY CHANGED. ARM 20's sentence -- "the arithmetic stays the
# runner's to fail" -- is true there and false here, and it reads as true in both places because it is phrased
# about the arithmetic rather than about the question being asked. Same family as a digest copied between
# roots carrying the donor's JOB rather than only its paths, one instrument down.
# ⛔ SO THE ARITHMETIC IS READ, NOT IGNORED, AND THE BODY ITSELF PRINTS THE NUMBER: at graded=0 the delta IS
# the graded count that would make the buckets sum. This reader states it as a FALSIFIABLE PREDICTION the
# next pass either meets or refutes, instead of a promise it cannot keep.
_out="$(INV_PACKAGE="$MATCHED" INV_DIR="$PKGDIR" INV_EXT="$EXT" inventory_line 0 0 2>&1)"; _rc=$?
_need=""
case "$_out" in
  *"buckets do not sum"*)
    _need="$(printf '%s' "$_out" | sed -n 's/.*(delta \(-\{0,1\}[0-9][0-9]*\)).*/\1/p' | head -1)"
    # ⛔ A NEGATIVE OR ZERO REQUIREMENT IS NOT A PREDICTION, IT IS AN IMPOSSIBILITY: the declared exclusions
    # already account for everything the package ships, so no run can make the identity hold. That is a data
    # defect exactly like an honesty refusal, and it is reported as one rather than as a forecast.
    if [ -n "$_need" ] && [ "$_need" -le 0 ] 2>/dev/null; then
        echo "CAUSE=C $LABEL: WIRED by $WIRED, but its own sidecars can NEVER sum -- they declare exclusions that already account for every shipped program (required graded count $_need). No suite pass can emit a clause; the defect is in the data. $(printf '%s' "$_out" | tr '\n' ' ' | cut -c1-170)"
        exit 0
    fi
    _rc=0 ;;
esac
if [ "$_rc" -ne 0 ]; then
    echo "CAUSE=C $LABEL: WIRED by $WIRED, but the shared body REFUSES(rc=$_rc) on its own sidecars, so the runner emits nothing while staying green. THE DEFECT IS IN THE DATA, NOT THE RUNNER: $(printf '%s' "$_out" | tr '\n' ' ' | cut -c1-220)"
    exit 0
fi
# ⛔ D IS A CONDITIONAL ANSWER AND MUST READ AS ONE. Every non-arithmetic arm being clean is all this reader
# can establish without a graded count, so it NAMES the count a pass must produce and the next pass settles
# it. A reader that promised the pass would work is exactly what sent the coo to run one.
if [ -n "$_need" ]; then
    echo "CAUSE=D $LABEL: WIRED by $WIRED, every honesty/duplicate/vocabulary arm clean (ext $EXT from $EXT_FROM). ⛔ CONDITIONAL, AND THIS IS THE FALSIFIABLE PART: its sidecars declare exclusions such that a pass emits a clause ONLY IF IT GRADES EXACTLY $_need PROGRAM(S). Grade any other number and the buckets do not sum, the body refuses, and the cell stays prose however many passes are run. If a pass grades something else, the defect is the SIDECAR DATA -- typically a name counted in BOTH graded and ungradable -- not the runner and not the pass."
else
    echo "CAUSE=D $LABEL: WIRED by $WIRED AND its data validates outright (ext $EXT from $EXT_FROM) -- the carriage is correct and the buckets sum. The cell is prose only because no suite pass has rewritten it since; it needs ONE RUNNER PASS, which under ONE RUNNER ONE BOARD (CEO-523) is the coo's. ⛔ NOT CARRIAGE WORK -- editing this runner would change a correct one."
fi
exit 0
