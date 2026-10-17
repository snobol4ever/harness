#!/usr/bin/env bash
# test_gate_make_test_loops_and_reports.sh -- `make test` RUNS EVERY ARM AND REPORTS, ruled CEO-582.
#
# THE DEFECT, MEASURED BY THE cfo BEFORE THE CURE: `make test` was ONE target of ~150 recipe lines and make
# ABORTS ON THE FIRST FAILING LINE, so a red at arm 15 killed the set 24s in and 131 ARMS NEVER EXECUTED --
# for all 13 seats, for as long as that arm stayed red.  Not red, not green: UNMEASURED.  The first
# loop-and-continue census found EIGHT non-green where the target reported ONE (five reds, three refusals,
# one of which would have passed vacuously).  WE REPORTED 1 OF 8.
#
# ⛔ WHY THE ARMS BELOW ARE BEHAVIOURAL AND HERMETIC, NOT GREPS.  hq_V's measured lesson, 2026-09-11
# (FINDING-2026-09-11-hq_V-a-source-level-assertion-is-not-a-measurement-of-behaviour.md): a gate of theirs
# grepped for a correctly-spelled form, the form WAS correctly spelled, and the caller one frame up defeated
# it -- green all day over a broken path.  So this gate does not read the driver's source to decide whether
# it loops; it BUILDS A SCRATCH MAKEFILE WITH A RED IN THE MIDDLE AND RUNS `make test` THROUGH IT, then
# counts how many arms actually executed.  Arm (a) is the one unavoidably textual check -- that the declared
# population and the driver's reading of it are the same list -- and it is a DIFF of two derivations of the
# same file, not an assertion about a spelling.
#
# THE ARMS
#   (a) the driver's arm list == the `test-sequential:` recipe lines, re-derived here independently
#   (b) the live `test:` recipe reaches run_blocking_set.sh (a revert that re-inlines the arms is caught)
#   (c) END TO END: a scratch `make test` with a red at arm 2 of 4 RUNS ALL FOUR and exits non-zero
#   (d) the legacy twin `make test-sequential` on the same scratch tree STOPS at that red -- the difference
#       this row exists to create is measured, never assumed
#   (e) two deliberately red arms are BOTH printed
#   (f) reds and refusals are printed as SEPARATE classes and never summed
#   (g) the denominator closes: green+red+refused == arms, printed
#   (h) all green => rc=0 and the green shape
#   (i) a blocking refusal and no red => rc=2, never 0 and never 1 (a refusal is not a pass)
#   (j) a red anywhere => rc=1 even when refusals are also present
#   (k) a REPORTED (`-`) arm that fails is counted and printed but cannot change the exit code
#   (l) ZERO arms REFUSES rc=2 -- a set that graded nothing must never print the success shape
#   (m) an arm carrying an unexpandable make variable REFUSES rc=2 rather than handing `$(FOO)` to bash
#   (n) an unrecognised flag REFUSES rc=2 instead of absorbing it
#
# FAIL-ONCE PROVEN BEFORE LANDING (hq_T, 2026-09-12, MEASURED not predicted): with `[ "$rc" -eq 0 ] || break`
# added to the driver's loop -- the abort-on-first-red behaviour this row cures, reproduced inside the cure --
# FIVE arms go red together: (c) reports 2 of 4 arms reached, (e) the second red is never printed, (f) the
# class blocks are absent, (g) the summary reads arms=5 green=1 red=1 refused=0 and 1+1+0=2 does NOT close,
# and (j) the run exits 2 instead of 1 because the red after the refusal was never reached.  ⭐ (g) is the
# load-bearing one: the denominator is what makes a partial run impossible to mistake for a clean one, and it
# is the arm that fires no matter WHERE the loop stops.
#
# rc=0 all arms pass / rc=1 a violation / rc=2 cannot measure (no driver, no make, no Makefile).
set -u
GATE_NAME=test_gate_make_test_loops_and_reports
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
DRIVER="$HERE/run_blocking_set.sh"
MAKEFILE="$ROOT/Makefile"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
bad=0; checks=0
fail() { bad=$((bad + 1)); echo "  ⛔ ($1) $2"; }
ok()   { checks=$((checks + 1)); echo "  ok ($1) $2"; }
command -v make >/dev/null 2>&1 || refuse "make not on PATH"
[ -f "$DRIVER" ]   || refuse "$DRIVER not found -- the loop-and-report driver is the subject of this gate"
[ -f "$MAKEFILE" ] || refuse "$MAKEFILE not found"
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
run() { # run <arms-file> -> stdout+stderr in $out, rc in $rc
    out="$(bash "$DRIVER" --arms-from "$1" 2>&1)"; rc=$?
}
# (a) THE DECLARED POPULATION AND THE DRIVER'S READING OF IT ARE THE SAME LIST.  Both sides are derived from
# the Makefile here and now; neither is a remembered number.  The `-` prefix is data, so it is compared too.
awk '/^test-sequential:/{f=1; next} f && /^$/{exit} f' "$MAKEFILE" \
  | grep '^	' | grep -v '^	#' | sed 's/^	//; s/[ 	]#.*$//; s/[ 	]*$//' | grep -v '^$' > "$W/decl.txt"
bash "$DRIVER" --list > "$W/list.raw" 2>&1 || refuse "the driver could not list its own arms"
sed -n 's/^ *[0-9]\+  BLOCKING  //p;s/^ *[0-9]\+  REPORTED  /-/p' "$W/list.raw" > "$W/seen.txt"
# the driver expands $(MAKE); normalise the declaration the same way so the diff is about the POPULATION.
sed -i "s/\\\$(MAKE)/${MAKE:-make}/g" "$W/decl.txt"
nd=$(wc -l < "$W/decl.txt"); ns=$(wc -l < "$W/seen.txt")
[ "$nd" -gt 0 ] || refuse "the test-sequential declaration in $MAKEFILE has no arms -- nothing to pin"
if diff -q "$W/decl.txt" "$W/seen.txt" >/dev/null 2>&1; then
    ok a "driver reads all $nd declared arm(s) of test-sequential, in order, with their REPORTED flags"
else
    fail a "the driver's arm list ($ns) differs from the test-sequential declaration ($nd):"
    diff "$W/decl.txt" "$W/seen.txt" | head -8 | sed 's/^/      /'
fi
# (b) THE LIVE TARGET REACHES THE DRIVER.  Cheap, and it catches the one revert this row is about.
if awk '/^test: scrip/{f=1; next} f && /^$/{exit} f' "$MAKEFILE" | grep -q 'run_blocking_set.sh'; then
    ok b "the live \`test:\` recipe invokes run_blocking_set.sh"
else
    fail b "the live \`test:\` recipe does not invoke run_blocking_set.sh -- \`make test\` no longer loops"
fi
# (c)+(d) END TO END THROUGH make ITSELF, on a scratch tree.  A red sits at arm 2 of 4 and each arm leaves a
# receipt file, so "how many arms ran" is COUNTED from the filesystem rather than parsed out of a summary
# the driver wrote about itself.
mkdir -p "$W/tree/scripts"
cp "$DRIVER" "$W/tree/scripts/run_blocking_set.sh"
cat > "$W/tree/Makefile" <<'MK'
test:
	@bash ../harness/scripts/run_blocking_set.sh

test-sequential:
	bash -c 'touch ran.1'
	bash -c 'touch ran.2; exit 1'
	bash -c 'touch ran.3'
	bash -c 'touch ran.4'
MK
( cd "$W/tree" && make test >"$W/mk.out" 2>&1 ); mkrc=$?
ran=$(ls "$W/tree" | grep -c '^ran\.')
if [ "$ran" -eq 4 ] && [ "$mkrc" -ne 0 ]; then
    ok c "\`make test\` with a red at arm 2 of 4 ran all 4 arms and exited $mkrc"
else
    fail c "\`make test\` reached $ran of 4 arms and exited $mkrc (want 4 arms, non-zero)"
    sed 's/^/      /' "$W/mk.out" | head -8
fi
rm -f "$W"/tree/ran.*
( cd "$W/tree" && make test-sequential >"$W/mkseq.out" 2>&1 ); seqrc=$?
seqran=$(ls "$W/tree" | grep -c '^ran\.')
if [ "$seqran" -eq 2 ] && [ "$seqrc" -ne 0 ]; then
    ok d "the legacy twin \`make test-sequential\` stops at the red having reached 2 of 4 -- the abort this row cures, measured"
else
    fail d "\`make test-sequential\` reached $seqran of 4 and exited $seqrc (want 2, non-zero) -- the declaration twin no longer behaves as documented"
fi
# (e)(f)(g)(j) TWO REDS AND A REFUSAL IN ONE RUN.
cat > "$W/mixed.txt" <<'EOF'
bash -c 'exit 0'
bash -c 'echo first-red >&2; exit 1'
bash -c 'echo a-refusal >&2; exit 2'
bash -c 'echo second-red >&2; exit 3'
bash -c 'exit 0'
EOF
run "$W/mixed.txt"
printf '%s\n' "$out" | grep -q 'first-red'  && printf '%s\n' "$out" | grep -q 'second-red' \
  && ok e "both red arms are printed, not just the first" \
  || { fail e "a red after the first red was not reported"; printf '%s\n' "$out" | sed 's/^/      /' | head -20; }
if printf '%s\n' "$out" | grep -q '^⛔ RED -- examined and FAILED (2):' \
   && printf '%s\n' "$out" | grep -q '^⛔ REFUSED -- COULD NOT MEASURE, rc=2 (1)'; then
    ok f "reds (2) and refusals (1) print as separate classes and are never summed"
else
    fail f "the two classes are not printed separately -- rc=1 FAILED and rc=2 COULD-NOT-MEASURE are different facts"
fi
sum="$(printf '%s\n' "$out" | grep '^blocking set: ')"
if [ "$sum" = "blocking set: arms=5  green=2  red=2  refused=1   (2+2+1=5)" ]; then
    ok g "the denominator closes and is printed: $sum"
else
    fail g "the summary line is wrong or absent: '$sum' (want arms=5 green=2 red=2 refused=1)"
fi
[ "$rc" -eq 1 ] && ok j "a red with refusals also present exits 1" || fail j "want rc=1 with reds present, got rc=$rc"
# (h) ALL GREEN.
printf "bash -c 'exit 0'\nbash -c 'exit 0'\n" > "$W/green.txt"
run "$W/green.txt"
[ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q '✅ BLOCKING SET GREEN' \
  && ok h "an all-green set exits 0 and says so" || fail h "all-green run exited $rc without the green shape"
# (i) A REFUSAL ALONE IS NOT A PASS.
printf "bash -c 'exit 0'\nbash -c 'exit 2'\n" > "$W/ref.txt"
run "$W/ref.txt"
[ "$rc" -eq 2 ] && ok i "a blocking refusal with no red exits 2 -- not 0 (not a pass) and not 1 (it did not fail)" \
  || fail i "a refusal-only run exited $rc, want 2"
# (k) A REPORTED ARM CANNOT CHANGE THE VERDICT, BUT IS STILL COUNTED AND PRINTED.
printf "bash -c 'exit 0'\n-bash -c 'echo reported-red >&2; exit 1'\n" > "$W/rep.txt"
run "$W/rep.txt"
if [ "$rc" -eq 0 ] && printf '%s\n' "$out" | grep -q 'reported-red' \
   && printf '%s\n' "$out" | grep -q '^blocking set: arms=2  green=1  red=1  refused=0'; then
    ok k "a failing REPORTED arm is counted and printed but does not fail the run (rc=0)"
else
    fail k "REPORTED handling wrong: rc=$rc (want 0, with the arm counted red and printed)"
fi
# (l) ZERO ARMS IS A REFUSAL.  This is the false-green `make test` itself once carried: named in .PHONY with
# no recipe, exit 0 having run nothing.
: > "$W/empty.txt"
run "$W/empty.txt"
[ "$rc" -eq 2 ] && ok l "a population of zero arms REFUSES rc=2 instead of printing the success shape" \
  || fail l "an empty population exited $rc, want 2"
# (m) AN UNEXPANDABLE MAKE VARIABLE IS A REFUSAL, NOT A GUESS -- `$(FOO)` handed to bash is command substitution.
printf 'bash -c \x27echo $(SOME_MAKE_VAR)\x27\n' > "$W/var.txt"
run "$W/var.txt"
[ "$rc" -eq 2 ] && ok m "an arm carrying an unexpandable make variable REFUSES rc=2" \
  || fail m "a make-variable arm exited $rc, want 2"
# (n) AN UNKNOWN FLAG REFUSES.  The driver must not repeat scrip's own fall-through, where an unrecognised
# argument becomes a filename and a typo becomes a plausible answer.
out="$(bash "$DRIVER" --no-such-flag 2>&1)"; rc=$?
[ "$rc" -eq 2 ] && ok n "an unrecognised flag REFUSES rc=2" || fail n "an unknown flag exited $rc, want 2"
echo
if [ "$bad" -ne 0 ]; then
    echo "⛔ GATE RED [$GATE_NAME]: $bad violation(s) over $((checks + bad)) check(s)"
    exit 1
fi
echo "GATE PASS(0) [$GATE_NAME]: $checks check(s) -- make test loops every arm, reports reds and refusals as separate classes, and its denominator closes"
[ -f "$HERE/lib_gate.sh" ] && . "$HERE/lib_gate.sh" 2>/dev/null && gate_stamp 2>/dev/null
exit 0
