#!/bin/bash
export S4E_MINT_NO_CRITERION="gate fixture: the row under test exercises the bus, not work (CEO-1386)"
# test_gate_library_driver_generator.sh -- THE HERMETIC GATE FOR util_gen_library_driver.py (ceo CEO-706 ->
# hq_B, rank 0, 2026-09-13).  It proves the generator's four brief-named arms plus the two its own proving
# ground added, and EVERY ARM WAS MADE TO FAIL ONCE before it was made to pass.
#
# ⛔⭐ WHY A GATE AND NOT A TRANSCRIPT.  The tool's job is to mint ~900 refs across four lanes.  A generator
# that cuts refs without its refusals intact manufactures permanently-red tests at scale -- hq_S's witness is
# the AIS row, which could never have closed because ATN prints TIME deltas on 19 lines, so two oracle runs of
# it differ on 38.  The refusals ARE the deliverable; the skeleton is a convenience.  So they are asserted
# here, executably, on fixtures this gate mints, rather than described in a commit message.
#
# ⛔ HERMETIC: every fixture is minted under a mktemp root and dies with the trap.  It grades no corpus
# population, writes no SCORE row and publishes no board.  It needs a BUILD OF NOTHING -- no scrip binary, no
# make -- and so belongs in `make preflight`.
# ⛔ IT NEEDS THE ORACLE, AND A MISSING ORACLE REFUSES rc=2 RATHER THAN PASSING.  Five of these arms are about
# what the oracle answers; with no oracle they would all "pass" by never contradicting anything, which is the
# absent-oracle false-green this tree has paid for more than once.
#
# THE THREE EXIT CODES (lib_gate.sh's rule): 0 clean · 1 a violation · 2 could-not-measure.  Never skip-as-success.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# ⛔ THE SUBJECT IS THE TREE THIS SCRIPT LIVES IN (lib_subject_tree.sh's rule; and the gate next door counts
# the alternative). The tool under test is the one beside this file, never $S4E/harness/scripts/<name>.
GEN="$HERE/util_gen_library_driver.py"
[ -f "$GEN" ] || { echo "⛔ REFUSES rc=2: no util_gen_library_driver.py beside this gate at $GEN"; exit 2; }
command -v python3 >/dev/null || { echo "⛔ REFUSES rc=2: no python3"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSES rc=2: cannot source lib_oracle_flags.sh -- the ONE authority for oracle paths"; exit 2; }
SBLB="$(sbl_correctness_bin 2>/dev/null)" || SBLB=""
[ -n "$SBLB" ] && [ -x "$SBLB" ] || {
    echo "⛔ REFUSES rc=2: no SNOBOL4 correctness oracle. Five arms below are about what the ORACLE answers;"
    echo "   without it they would pass by never contradicting anything, and a missing oracle prints a full,"
    echo "   plausible, entirely false table. UNMEASURED is not clean."
    exit 2; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
RC=0
pass() { printf '  ✅ %s\n' "$1"; }
fail() { printf '  ⛔ RED: %s\n' "$1"; RC=1; }
# capture-then-test, NEVER `cmd | tail; $?` -- a pipeline reports the LAST command's status (this tree's own
# measured trap: `./scrip --help </dev/null 2>&1 | head -3; echo $?` printed 0 for a command that exits 1).
run() { OUT="$("$@" 2>&1)"; ORC=$?; }

echo "== ARM 1: enumeration -- the DEFINE contract, a CONTINUATION line, and the OPSYNed DEFINE. spelling"
# ⛔ All three shapes are MEASURED from gimpel, not invented: FASTBAL.sno really does close its DEFINE on the
# next physical line, and FTRACE.sno/INSULATE.sno really do issue `DEFINE.(...)` after OPSYNing DEFINE over
# itself. A scanner blind to either reads a real module as defining nothing, which is indistinguishable from
# a module that genuinely defines nothing -- and this gate's arm 7 is what makes that distinction matter.
cat > "$W/M1.sno" <<'EOF'
	DEFINE('PLAIN(S)T')			:(PLAIN_END)
PLAIN	PLAIN  =  S  S			:(RETURN)
PLAIN_END
	DEFINE('WRAPPED(A,B,C)L1,L2,L3
+	,L4'
+	)					:(WRAPPED_END)
WRAPPED	WRAPPED  =  A			:(RETURN)
WRAPPED_END
	DEFINE.('OPSYNED(N,V)')			:(OPSYNED_END)
OPSYNED	OPSYNED  =  N			:(RETURN)
OPSYNED_END
	DEFINE('NOARG')				:(NOARG_END)
NOARG	NOARG  =  'x'			:(RETURN)
NOARG_END
EOF
run python3 "$GEN" procs "$W/M1.sno"
[ "$ORC" = 0 ] || fail "procs refused a module that defines four procedures (rc=$ORC): $OUT"
for want in "PLAIN	1" "WRAPPED	3" "OPSYNED	2" "NOARG	0"; do
    printf '%s\n' "$OUT" | grep -qP "^$(printf '%s' "$want" | sed 's/\t/\\t/')\b" \
        && pass "enumerated $(printf '%s' "$want" | cut -f1) with arity $(printf '%s' "$want" | cut -f2)" \
        || fail "did not enumerate $(printf '%s' "$want" | tr '\t' '/') -- got: $(printf '%s' "$OUT" | tr '\n' '|')"
done
printf '%s\n' "$OUT" | grep -q 'L1,L2,L3,L4' && pass "the continuation line's locals were folded, not truncated" \
    || fail "WRAPPED's locals were truncated at the physical line break -- got: $(printf '%s' "$OUT" | grep WRAPPED)"

echo "== ARM 2: a GOTO FIELD is not a call, and a STRING LITERAL is not a call"
# ⛔⭐ BOTH OF THESE COST A FALSE MEASUREMENT DURING THIS TOOL'S OWN PROVING GROUND, and the second was hidden
# by the first. Scanning gimpel's 144 hand drivers reported 54 modules whose driver "calls a procedure the
# enumerator missed"; cutting the goto field took that to 1, and the last 1 was a line of SNOBOL4 SOURCE
# PASSED AS DATA (SNOPUT_driver.sno line 6) with the goto inside a quoted literal. A measurement that
# improves from 54 to 1 is the easiest possible place to stop looking.
cat > "$W/M2.sno" <<'EOF'
	DEFINE('S(X)')				:(S_END)
S	S  =  X					:(RETURN)
S_END
	DEFINE('REAL(X)')			:(REAL_END)
REAL	REAL  =  X				:(RETURN)
REAL_END
EOF
cat > "$W/M2_driver.sno" <<'EOF'
-INCLUDE "M2.sno"
	OUTPUT  =  REAL('a')			:S(DONE)
DONE	OUTPUT  =  'literal :S(NOPE) S(NOPE)'
END
EOF
run python3 "$GEN" coverage "$W/M2.sno" "$W/M2_driver.sno"
[ "$ORC" = 0 ] || fail "coverage refused (rc=$ORC): $OUT"
printf '%s\n' "$OUT" | grep -q 'exercised=1 defined=2' \
    && pass "coverage is 1 of 2 -- the goto :S(DONE) and the quoted S(NOPE) were NOT read as calls to S" \
    || fail "goto field or string literal counted as a call -- expected exercised=1 defined=2, got: $OUT"
printf '%s\n' "$OUT" | grep -q 'NOT EXERCISED: S' \
    && pass "the un-called procedure is named, so a thin witness says which half it omits" \
    || fail "coverage did not name S as un-exercised: $OUT"

echo "== ARM 3: a deterministic driver -- the ref is CUT FROM THE ORACLE and equals the oracle's own bytes"
# ⛔⭐ WHY EVERY MODULE FIXTURE ABOVE CLOSES ON A LABEL AND NEVER ON `END` -- and this gate's first draft got
# it wrong, which is how the property was found. A SNOBOL4 `END` statement ENDS THE PROGRAM, so a library
# module carrying one terminates the driver at the point of inclusion: the oracle exits 0 having printed
# NOTHING. Every real gimpel module closes on a `<NAME>_END` LABEL for exactly this reason (checked: UPLO,
# AI, SEQ, PAD). ⭐ THE REASON THIS IS WORTH A COMMENT RATHER THAN A QUIET FIX: the failure arrives as
# rc=0 and an empty file -- a SUCCESSFUL run of a program that did nothing -- so without the EMPTY refusal
# this fixture would have minted a 0-byte ref and this arm would have passed while proving nothing at all.
# The tool caught its own gate's bug, which is the only reason the refusal is credible.
cat > "$W/M3.sno" <<'EOF'
	DEFINE('TWICE(S)')			:(TWICE_END)
TWICE	TWICE  =  S  S				:(RETURN)
TWICE_END
EOF
cat > "$W/M3_driver.sno" <<'EOF'
-INCLUDE "M3.sno"
	OUTPUT  =  TWICE('ab')
END
EOF
run python3 "$GEN" cut "$W/M3_driver.sno" --suite gimpel
[ "$ORC" = 0 ] || fail "cut refused a clean deterministic driver (rc=$ORC): $OUT"
if [ -f "$W/M3_driver.ref" ]; then
    got="$(cat "$W/M3_driver.ref")"
    [ "$got" = "abab" ] && pass "ref cut from the oracle reads 'abab'" \
        || fail "ref content is $got, expected abab (the ORACLE's answer, not ours)"
else
    fail "no .ref was written beside a clean deterministic driver"
fi

echo "== ARM 4 (REFUSAL): the oracle does not answer LIVE -- nothing is minted"
# The realistic cause, and the one the brief's arm 4 exists for: a GUESSED argument of the wrong type. A
# ref cut from an error report pins the error report as ground truth.
cat > "$W/M4_driver.sno" <<'EOF'
-INCLUDE "M3.sno"
	OUTPUT  =  TWICE(
END
EOF
run python3 "$GEN" cut "$W/M4_driver.sno" --suite gimpel
[ "$ORC" = 2 ] && pass "refused rc=2 on a non-LIVE oracle answer" || fail "expected rc=2 on a non-LIVE oracle, got rc=$ORC: $OUT"
[ -f "$W/M4_driver.ref" ] && fail "a .ref was written despite the refusal -- the refusal must mint NOTHING" \
    || pass "nothing was written"

echo "== ARM 5 (REFUSAL): NONDETERMINISM the SELF-DIFF can see -- two oracle runs disagree"
# ⛔ hq_S's prophylactic, and the brief calls it not optional. Measured witness for this fixture: run1
# 'elapsed 1860997', run2 'elapsed 1921230'.
cat > "$W/M5_driver.sno" <<'EOF'
	N  =  0
	T0 =  TIME()
LOOP	N  =  N + 1
	LT(N, 40000)				:S(LOOP)
	OUTPUT  =  'elapsed ' TIME() - T0
END
EOF
run python3 "$GEN" cut "$W/M5_driver.sno" --suite gimpel
[ "$ORC" = 2 ] && pass "refused rc=2 -- two oracle runs of one program disagreed" || fail "expected rc=2 on a self-diff disagreement, got rc=$ORC: $OUT"
# ⛔⭐ ASSERT THE SELF-DIFF'S OWN MESSAGE, NOT MERELY "something refused" -- AND THE REASON IS A DEFECT THIS
# GATE HAD (hq_B 2026-09-13, found by the fail-once proof and not by reading it). This witness prints a TIME
# delta, so it trips the SOURCE arm too. With the loose assertion, deleting the self-diff entirely left this
# arm GREEN: the source arm refused instead, the message was different, and nothing noticed. ⭐ THAT IS THE
# TOOL'S OWN DOCTRINE TURNED ON ITS GATE -- two arms that look independent and share one instrument are one
# instrument reported twice, and the unanimity reads as MORE confidence rather than less. Pinning the message
# is what makes the two arms falsifiable SEPARATELY. Measured: 6 of 6 run-pairs of this witness DIFFER.
printf '%s\n' "$OUT" | grep -q 'disagree on' && pass "the refusal is the SELF-DIFF's own, naming the differing lines" \
    || fail "arm 5 did not come from the self-diff -- its message must name the disagreeing lines, got: $OUT"
[ -f "$W/M5_driver.ref" ] && fail "a .ref was written for a nondeterministic program" || pass "nothing was written"

echo "== ARM 6 (REFUSAL): NONDETERMINISM the self-diff CANNOT see -- agreeing runs, a clock in the source"
# ⛔⭐ THE ARM THAT EXISTS BECAUSE THE MEASUREMENT CONTRADICTED THE DESIGN. Three lines of DATE() printed
# '09/13/26 17:15:14' in BOTH runs -- identical, because two runs milliseconds apart fall inside the same
# second. The self-diff is a sample of size two and a one-second clock is invisible to it. A third run, or a
# sleep, buys a wider sample of the SAME instrument; the cure is a SECOND INSTRUMENT WITH A DIFFERENT BLIND
# SPOT, so the source is read for known nondeterministic primitives. Agreement is only evidence when the
# arms CAN disagree.
# ⛔ THE WITNESS CALLS THE CLOCK AND DOES NOT PRINT IT, WHICH IS WHAT MAKES THIS ARM ISOLATE THE SOURCE SCAN.
# A witness that PRINTS a clock is caught by whichever arm runs first, and a DATE() printed twice is worse
# than useless here: measured, it straddles a second boundary often enough to be FLAKY in both directions --
# it agreed on '09/13/26 17:15:14' one minute and disagreed on 2 lines the next. This one prints a constant,
# so its two oracle runs AGREE every time (measured 4 of 4, on real non-empty output) and the ONLY thing that
# can object to it is the source scan. Delete that scan and this arm goes silent, which is what the fail-once
# proof requires.
# ⛔ IT IS ALSO A DELIBERATELY CONSERVATIVE REFUSAL, AND THAT IS THE RIGHT BIAS: the tool cannot prove the
# clock's value never reaches the output, so it refuses and says to author the driver by hand. For something
# minting ~900 refs, a false refusal costs a human a minute and a false mint costs a suite its meaning.
cat > "$W/M6_driver.sno" <<'EOF'
	T  =  DATE()
	OUTPUT  =  'constant'
END
EOF
run python3 "$GEN" cut "$W/M6_driver.sno" --suite gimpel
[ "$ORC" = 2 ] && pass "refused rc=2 although BOTH oracle runs agreed -- the source arm caught it" \
    || fail "expected rc=2 from the source arm on an agreeing clock program, got rc=$ORC: $OUT"
printf '%s\n' "$OUT" | grep -q 'runs AGREED' && pass "the refusal is the SOURCE arm's own -- it fired on runs that agreed" \
    || fail "arm 6 did not come from the source scan -- its message must say the runs AGREED, got: $OUT"
printf '%s\n' "$OUT" | grep -q 'DATE()' && pass "the refusal names the primitive it found, and in which file" \
    || fail "the refusal did not name DATE(): $OUT"
[ -f "$W/M6_driver.ref" ] && fail "a .ref was written for a clock-printing program" || pass "nothing was written"

echo "== ARM 7 (REFUSAL): a module that defines NOTHING is never reported as a clean zero"
# ⛔ 'this file defines 0 procedures' and 'my enumerator does not understand this file' are the same output
# unless one of them refuses. gimpel's BREAKX.sno is the real case: every line commented out, because BREAKX
# is a SPITBOL builtin.
printf '* all commented out, like gimpel BREAKX.sno\n*	DEFINE(%s)\n' "'BREAKX(S)'" > "$W/M7.sno"
run python3 "$GEN" procs "$W/M7.sno"
[ "$ORC" = 2 ] && pass "refused rc=2 rather than printing a triumphant zero" || fail "expected rc=2 for a module defining nothing, got rc=$ORC: $OUT"

echo "== ARM 8: the SHAPE CENSUS separates the FOUR kinds of 'library module'"
# ⛔⭐ CONTAINER_OR_LIBRARY is not one shape. Measured over gimpel's 149 modules: 131 PROCEDURES, 12
# PATTERN_FRAGMENT (ASM360.sno builds a pattern-valued variable; there is nothing to call), 6 with no
# executable content at all. A lane that discovers this one module at a time, at the moment its generated
# driver refuses, pays the discovery once per module.
cp "$W/M3.sno" "$W/census_procs.sno"
printf "\tLETTER  =  'ABC'\n\tPAT  =  ANY(LETTER)\n" > "$W/census_pattern.sno"
printf '* nothing but comments\n' > "$W/census_dead.sno"
# ⛔ THE ENTRY-POINT FIXTURE, AND THE SHAPE IT PROVES WAS MISSING UNTIL A SECOND PACKAGE CONTRADICTED THE
# FIRST. Read over gimpel alone the other three shapes looked complete; run the same census over
# snoflake_suite and 140 of 180 came back PATTERN_FRAGMENT, which is nonsense -- they are standalone test
# programs. The discriminator is a bare `END` statement, and it is exact: gimpel library modules 10 of 149
# carry one, snoflake_suite 178 of 180, csnobol4_suite 101 of 131. ⭐ A file with an entry point filed as
# CONTAINER_OR_LIBRARY is not awaiting a driver -- it is awaiting a RUN, and the row is wrong about the file.
# NOTE it carries a DEFINE as well, because precedence is the whole point: a program with its own procedures
# is still a program, and drafting a driver for it would put a second entry point in one file.
printf "\tDEFINE('HELPER(S)')\t\t\t:(HELPER_END)\nHELPER\tHELPER  =  S\t\t\t:(RETURN)\nHELPER_END\n\tOUTPUT  =  HELPER('x')\nEND\n" > "$W/census_standalone.sno"
run python3 "$GEN" classify "$W"
[ "$ORC" = 0 ] || fail "classify refused a directory with three shapes in it (rc=$ORC): $OUT"
printf '%s\n' "$OUT" | grep -q "^STANDALONE_PROGRAM.*census_standalone.sno$" && pass "STANDALONE_PROGRAM recognised, and it OUTRANKS the DEFINE in the same file" || fail "census_standalone.sno not classified STANDALONE_PROGRAM: $OUT"
printf '%s\n' "$OUT" | grep -q "^PROCEDURES.*census_procs.sno$"            && pass "PROCEDURES recognised"            || fail "census_procs.sno not classified PROCEDURES: $OUT"
printf '%s\n' "$OUT" | grep -q "^PATTERN_FRAGMENT.*census_pattern.sno$"    && pass "PATTERN_FRAGMENT recognised"      || fail "census_pattern.sno not classified PATTERN_FRAGMENT: $OUT"
printf '%s\n' "$OUT" | grep -q "^NO_EXECUTABLE_CONTENT.*census_dead.sno$"  && pass "NO_EXECUTABLE_CONTENT recognised" || fail "census_dead.sno not classified NO_EXECUTABLE_CONTENT: $OUT"

echo "== ARM 9 (REFUSAL): a committed .ref is never silently overwritten"
run python3 "$GEN" cut "$W/M3_driver.sno" --suite gimpel
[ "$ORC" = 2 ] && pass "refused rc=2 rather than re-cutting an existing ref without --force" \
    || fail "expected rc=2 re-cutting over an existing ref, got rc=$ORC: $OUT"

echo "== ARM 10: a THIN witness announces itself"
# ⭐ The brief's own clause: a driver exercising one procedure of a twenty-procedure module is honest only if
# its row says so. Measured over the 127 gimpel modules that already ship a hand driver: 135 of 196
# procedures are exercised, 69%, and ALL 127 drivers are thin. Not one is a full witness of its own module.
run python3 "$GEN" coverage "$W/M2.sno" "$W/M2_driver.sno"
printf '%s\n' "$OUT" | grep -q 'THIN WITNESS' && pass "the thin-witness warning fired on 1-of-2 coverage" \
    || fail "a 1-of-2 driver did not announce itself as thin: $OUT"
run python3 "$GEN" coverage "$W/M3.sno" "$W/M3_driver.sno"
printf '%s\n' "$OUT" | grep -q 'THIN WITNESS' && fail "a 1-of-1 driver was wrongly called thin: $OUT" \
    || pass "a complete witness is NOT warned about (the warning can say no as well as yes)"

echo "== ARM 11 (REFUSAL): 'the inventory is empty' and 'I cannot read the inventory' are DIFFERENT refusals"
# ⛔⭐ THIS ARM EXISTS BECAUSE THE TOOL FAILED IT (hq_B 2026-09-13, found by adding the per-package numbers up
# against the fleet cause census and refusing to let a 208-row shortfall be arithmetic). logtalk_iso carries
# 208 CONTAINER_OR_LIBRARY rows, every one a .lgt file this tool has no enumerator for, and `inventory`
# refused with "no CONTAINER_OR_LIBRARY rows in ..." -- rc=2, loud, honest-looking, and naming the WRONG
# CAUSE. ⭐ "The population is empty" and "the population is invisible to me" are the same output unless one
# of them says which -- and the first reads as a FINISHED package, so the error points away from the work.
mkdir -p "$W/pkg_unreadable" "$W/pkg_empty"
printf '# name\tCLASS\treason\nthing.lgt\tNEEDS_DRIVER\ta dialect this tool cannot read\n' > "$W/pkg_unreadable/UNGRADED.tsv"
printf 'irrelevant\n' > "$W/pkg_unreadable/thing.lgt"
printf '# name\tCLASS\treason\nthing.sno\tORACLE_REFUSES\tsome other cause entirely\n' > "$W/pkg_empty/UNGRADABLE.tsv"
printf 'END\n' > "$W/pkg_empty/thing.sno"
run python3 "$GEN" inventory "$W/pkg_unreadable"
[ "$ORC" = 2 ] && pass "refused rc=2 on rows it cannot read" || fail "expected rc=2 on unreadable rows, got rc=$ORC: $OUT"
printf '%s\n' "$OUT" | grep -q 'NO enumerator' \
    && pass "and the refusal says UNMEASURED, naming the extension -- not 'no rows'" \
    || fail "the refusal did not name the missing enumerator, so it is indistinguishable from an empty inventory: $OUT"
printf '%s\n' "$OUT" | grep -q 'not empty of rows' && pass "it explicitly denies the reading that would send a lane away" \
    || fail "the refusal does not rule out being read as zero: $OUT"
run python3 "$GEN" inventory "$W/pkg_empty"
[ "$ORC" = 2 ] && pass "a genuinely empty cause still refuses (never a clean zero)" || fail "expected rc=2 on an empty cause, got rc=$ORC: $OUT"
printf '%s\n' "$OUT" | grep -q 'no NEEDS_DRIVER rows' \
    && pass "and it is the OTHER message -- the two causes are told apart" \
    || fail "the empty-inventory refusal did not use its own message: $OUT"

echo "== ARM 12: a driver that WRITES A FILE must not dirty the tree it was read from"
# ⛔⭐⭐ THIS ARM EXISTS BECAUSE THE TOOL DID EXACTLY THIS, AND A `git status` AT HANDOFF CAUGHT IT RATHER THAN
# ANY CHECK OF MINE (hq_B 2026-09-13). Cutting refs for gimpel's 28 ref-less drivers left
# corpus/packages/snobol4/gimpel/asmtemp behind: ASM.sno opens a DISK work file by the relative name
# `asmtemp`, and the oracle door deliberately runs each program in the PROGRAM'S OWN DIRECTORY so a relative
# -INCLUDE resolves, so the work file lands in the vendored package.
# ⭐ AND IT WAS A KNOWN DEFECT I WALKED INTO, NOT A NEW ONE: test_snobol4_gimpel_suite.sh carries the
# identical overlay cure for the identical reason, and there the consequence was that util_score_row.py
# refused the leaderboard row -- a number measured on a dirty tree describes no tree anyone can check out.
# The lesson was written down in this tree, by someone else, before I repeated it. ⛔ SO THE ARM IS NOT "does
# the overlay exist"; it is the OBSERVABLE: run a writing driver, then assert the source directory is
# byte-identical. That is the gimpel runner's own rule -- two seats could not settle a witnessed leak by
# argument, so it measures.
mkdir -p "$W/writer"
printf "\tDEFINE('NOTE(S)')\t\t\t:(NOTE_END)\nNOTE\tOUTPUT(.DISK,10,'sidefx.tmp')\n\tDISK  =  S\n\tENDFILE(10)\n\tNOTE  =  S\t\t\t:(RETURN)\nNOTE_END\n" > "$W/writer/W.sno"
cat > "$W/writer/W_driver.sno" <<'EOF'
-INCLUDE "W.sno"
	OUTPUT  =  NOTE('wrote')
END
EOF
before="$(find "$W/writer" -type f -printf '%p %s
' | LC_ALL=C sort)"
run python3 "$GEN" cut "$W/writer/W_driver.sno" --suite gimpel --ref "$W/writer_out.ref"
after="$(find "$W/writer" -type f -printf '%p %s
' | LC_ALL=C sort)"
[ "$ORC" = 0 ] && pass "the writing driver cut its ref (rc=0)" || fail "cut failed on a file-writing driver (rc=$ORC): $OUT"
if [ "$before" = "$after" ]; then
    pass "and the source directory is byte-identical -- the side-effect file landed on the overlay"
else
    fail "the source directory CHANGED while cutting the ref -- the overlay leaked: $(printf '%s\n' "$after" | comm -13 <(printf '%s\n' "$before") - | tr '\n' ' ')"
fi

if [ "$RC" = 0 ]; then
    echo "✅ GATE OK: util_gen_library_driver.py -- enumeration (DEFINE, continuation, DEFINE.), goto/literal"
    echo "   regions excluded from call scans, ref cut from the oracle, FOUR refusals proven to mint nothing"
    echo "   (non-LIVE oracle · self-diff disagreement · agreeing-runs-with-a-clock · existing ref), the four-way"
    echo "   shape census, and an unreadable inventory told apart from an empty one."
else
    echo "⛔ GATE FAILED"
fi
exit $RC
