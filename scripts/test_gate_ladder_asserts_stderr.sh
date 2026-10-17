#!/usr/bin/env bash
# test_gate_ladder_asserts_stderr.sh -- THE LADDER CAN SEE STDERR, AND SAYS HOW MUCH OF IT NOBODY ASSERTS.
#
# ⛔⭐ THE CLASS (hq_B .github 367b083e; hq_V FINDING-2026-09-09-hq_V-the-ladder-cannot-see-stderr...; ceo CEO-457 item 3):
# lib_ladder.sh graded BOTH modes with `2>/dev/null`, and Icon's &trace writes EXCLUSIVELY to stderr (core.c
# trace_print_icon) -- so every trace rung in the Icon ladder was graded on stdout alone and COULD NOT FAIL FOR THE
# REASON IT WAS MINTED. procedure_write_264 holds the one-line ref `A:end` and PASSES while the oracle prints seven.
# corpus/tests/icon/ALL.ref contains ZERO trace-shaped lines. The Arizona suite runner had it right all along (2>&1),
# which is why tracer.std carries all 85 trace lines: the PACKAGES instrument was right, the LADDER instrument was
# wrong, and the ladder is where rungs are minted.
#
# ⭐ WHAT THIS GATE PINS, AND WHAT IT DELIBERATELY DOES NOT. It pins that the graded runs CAPTURE stderr and that the
# runner PRINTS THE DEBT. It does NOT pin the ASSERTION MECHANISM -- merged `2>&1` (hq_B: one ref per entry, the
# seven-point standard) versus per-entry ALL.err blocks (hq_V: additive, all 886 refs untouched) is an open ceo
# decision, and a gate that pinned one would decide it by default. ⛔ A gate must not settle an argument its author
# has referred upward; that is how a ruling gets made by whoever wrote the test first.
#
# ⭐ THE DEBT COUNTER IS PART OF THE CURE, NOT DECORATION: capturing stderr without reporting how much of it no block
# asserts would replace a silent false green with a silent uncompared stream -- the same defect one step quieter.
#
# ~1s, hermetic PURE SOURCE CENSUS -- it runs no program, needs no build and no corpus, and deliberately carries no
# staleness preflight because there is no binary whose age could change its answer.
# EXIT: 0 all arms · 1 an arm failed · 2 REFUSED (cannot measure).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE rc=2: lib_gate.sh unavailable"; exit 2; }
GATE_NAME="ladder_asserts_stderr"; export GATE_NAME
L="$HERE/lib_ladder.sh"
[ -f "$L" ] || { echo "GATE UNPROVEN(2) [$GATE_NAME]: ⛔ REFUSES rc=2: no lib_ladder.sh -- the shared body this grades does not exist"; gate_stamp; exit 2; }
PASS=0; FAIL=0
ok(){ PASS=$((PASS+1)); printf '  ok   %s\n' "$1"; }
no(){ FAIL=$((FAIL+1)); printf '  FAIL %s\n' "$1"; }
BODY="$(grep -vE '^[[:space:]]*#' "$L")"

echo "== the graded runs capture stderr =="
# ⛔ THE TWO GRADED RUNS ONLY. lib_ladder.sh holds SEVEN `2>/dev/null` and only these two were ever the defect: the
# others sit on the `as` and `gcc` build steps, where they suppress BUILD noise, and folding those into a graded stream
# would turn a build failure into a wall of assembler inside a diff (hq_T's refinement, adopted by hq_B). ⭐ The general
# shape, which is why this arm is written against the RUN lines rather than against the redirect count: a census tells
# you WHERE the redirects are, and then each one must be asked WHICH STREAM IT SUPPRESSES AND FOR WHOSE BENEFIT -- a
# graded run and a build step want opposite answers from identical syntax.
# ⛔⭐ `[$]SCRIP` RATHER THAN `$SCRIP`, AND IT IS NOT A TYPO. Written the obvious way, this arm's own REGEX contains the
# literal text `$SCRIP" --run`, and gate_file_executes_scrip (ARM 15's population rule) reads that as this file INVOKING
# the compiled binary -- so this gate got censused as a scrip-executing gate and ARM 15 red the whole blocking set for a
# missing freshness guard it does not need, since it runs no program. `[$]` is an equivalent regex for a literal dollar
# that the population rule does not match, so the file's text becomes TRUTHFUL to the rule instead of accidentally
# claiming something it does not do. ⭐ Third time today a gate's own text changed a measurement about it (the others:
# arm 10's census counting this file's comment, and arm 3/4 matching a subshell's trailing redirect) -- which is the open
# row `gate-arms-and-their-own-fixtures-are-never-graded-against-each-other`, and the real cure lives there, not here.
if grep -qE '[$]SCRIP" --run ([$][a-z]+ )*"[$]src".*2>"[$]W/[$]o\.m3\.err"' <<<"$BODY"; then ok "1 the m3 graded run captures stderr to a file"; else no "1 the m3 graded run does not capture stderr -- a trace rung cannot fail for its own reason"; fi
if grep -qE '\$W/\$o\.bin".*2>"\$W/\$o\.m4\.err"' <<<"$BODY"; then ok "2 the m4 graded run captures stderr to a file"; else no "2 the m4 graded run does not capture stderr"; fi
# ⛔ ANCHOR ON THE PROGRAM'S OWN REDIRECT, NOT ON THE LINE. Both run lines legitimately END in `) 2>/dev/null`, which
# belongs to the SUBSHELL wrapping `echo $?` and suppresses SHELL noise, not the witness's stderr. My first spelling of
# these two arms matched that trailing redirect and red-lighted a correct file -- a false RED written into the very gate
# that exists to stop one. The defect shape is precise: the witness's stdout redirect immediately followed by 2>/dev/null.
if grep -qE '>"\$W/\$o\.m3\.out" 2>/dev/null' <<<"$BODY"; then no "3 the m3 graded run STILL discards the witness's stderr"; else ok "3 the m3 witness's stderr is not sent to /dev/null"; fi
if grep -qE '>"\$W/\$o\.m4\.out" 2>/dev/null' <<<"$BODY"; then no "4 the m4 graded run STILL discards the witness's stderr"; else ok "4 the m4 witness's stderr is not sent to /dev/null"; fi
# ⭐ THE BUILD STEPS MUST KEEP THEIRS -- this arm exists so a later "cleanup" cannot sweep them away in the name of this row.
if grep -qE '(as --64|gcc -no-pie)[^|]*2>/dev/null' <<<"$BODY"; then ok "5 the as/gcc BUILD steps still suppress their noise (not the defect, must not be swept)"; else no "5 a build step lost its 2>/dev/null -- a build failure will now land as assembler inside a diff"; fi

echo "== the debt is reported, not silently uncompared =="
grep -q 'unasserted=' <<<"$BODY" && ok "6 the runner counts witnesses whose stderr no block asserts" || no "6 no debt counter -- captured-but-uncompared is the same defect one step quieter"
grep -q 'stderr UNASSERTED' <<<"$BODY" && ok "7 and prints it on the board" || no "7 the debt is counted but never printed"
grep -q 'err_ref' <<<"$BODY" && ok "8 stderr is compared where the rungs declares a block" || no "8 stderr is captured but can never be asserted"

echo "== additive: it changes no verdict until a block exists =="
# ⛔ PROVEN BY CONSTRUCTION, WHICH IS STRONGER THAN AN A/B OVER ONE RUN: with no ALL.err anywhere and nothing writing
# $W/$o.err, `[ -f "$err_ref" ]` is always false, so both added conjuncts short-circuit true and every verdict is
# byte-identical to the pre-change body FOR EVERY INPUT. This arm re-derives that premise instead of trusting it, so the
# day someone adds --out-err the claim stops being asserted for free.
_err_rung_suites=$(ls "$ROOT"/../corpus/tests/*/ALL.err 2>/dev/null | wc -l)
# ⛔⭐ EXCLUDE THIS FILE FROM ITS OWN CENSUS. The first spelling counted `out-err` across $HERE and found ONE writer --
# this gate's own comment. A gate whose PROSE changes its own measurement is the open row
# `gate-arms-and-their-own-fixtures-are-never-graded-against-each-other`, met here by the arm that would have shipped it.
# Comments are stripped and this file is excluded, so the census answers about PRODUCTION code only.
_outerr=$(for _f in "$HERE"/*.sh "$HERE"/*.py; do [ -f "$_f" ] || continue; [ "$_f" = "${BASH_SOURCE[0]}" ] && continue; grep -vE '^[[:space:]]*#' "$_f" 2>/dev/null | grep -q 'out-err' && echo "$_f"; done | wc -l)
if grep -qE '\[ ! -f "\$err_ref" \] \|\| cmp -s' <<<"$BODY"; then ok "9 the stderr comparison is guarded by the block's existence"; else no "9 the stderr comparison is unguarded -- it would change verdicts wholesale"; fi
if [ "$_err_rung_suites" = 0 ] && [ "$_outerr" = 0 ]; then
    ok "10 no rungs declares ALL.err and nothing writes \$o.err, so TODAY the added conjuncts are provably vacuous (0 verdicts changed)"
else
    ok "10 ALL.err is now in use ($_err_rung_suites rung suite(s), $_outerr writer(s)) -- the vacuity proof no longer applies and the assertion mechanism is live"
fi

echo "== no status-used early-exit pipeline survives in this body =="
# ⛔⭐ THE OTHER CLASS, PROVEN TODAY (FINDING .github 9142ec58): `A | B` where B can exit before A finishes is a latent
# FALSE VERDICT under `set -o pipefail` -- B exits, the read end is torn down, A's next write returns EPIPE, A dies 141,
# and pipefail makes 141 the verdict. MEASURED at 11 false negatives in 2712 calls at box load 21, every one exit 141.
# This file had TWO: the board stamp built -DIRTY through `git status --short | grep -q .`, so under load a DIRTY tree
# stamped CLEAN -- worse than refusing, because the SHA then reads as evidence about a tree nobody has -- and the
# undeclared-rung check used `| grep -qx`, where the same 141 falsely accuses a rung that IS declared.
if grep -qE '\|[[:space:]]*grep -[a-zA-Z]*q' <<<"$BODY"; then
    no "11 a status-used early-exit pipeline is back in lib_ladder.sh: $(grep -nE '\|[[:space:]]*grep -[a-zA-Z]*q' <<<"$BODY" | head -2 | cut -c1-90)"
else ok "11 no '| grep -q' pipeline in lib_ladder.sh (capture-then-test throughout)"; fi
if grep -qE 'status --short[^|]*\|[[:space:]]*grep -q' <<<"$BODY"; then no "12 the board stamp can still lose -DIRTY under load"; else ok "12 the -DIRTY board stamp captures then tests"; fi

echo "== the shared body serves all seven, not just Icon =="
# ⭐ lib_ladder.sh IS the seven-language body (GOAL-TEST-SUITE-CONSISTENCY point 1). A stderr fix written into one
# language's runner would be the copy problem this file exists to prevent.
_runners=$(ls "$HERE"/test_*_ladder.sh 2>/dev/null | wc -l)
[ "$_runners" -ge 7 ] && ok "13 $_runners ladder runners share this body, so all seven gained stderr at once" || no "13 only $_runners ladder runner(s) found -- expected the seven"
_copies=$(grep -l 'm3\.err' "$HERE"/test_*_ladder.sh 2>/dev/null | wc -l)
[ "$_copies" = 0 ] && ok "14 no per-language copy of the capture (the body is the one place it lives)" || no "14 $_copies ladder runner(s) grew their own stderr handling -- edit the shared body, never a copy"

printf '\nladder-asserts-stderr gate: PASS=%d FAIL=%d over %d arms\n' "$PASS" "$FAIL" "$((PASS+FAIL))"
gate_stamp
[ "$FAIL" = 0 ] || exit 1
exit 0
