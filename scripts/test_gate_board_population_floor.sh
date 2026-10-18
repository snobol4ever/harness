#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
# test_gate_board_population_floor.sh -- THE ACCEPTANCE GATE for row every-board-wrapper-refuses-on-a-
# zero-population-instead-of-passing-vacuously (hq_T -> seat16, 2026-09-04).
#
# THE DEFECT (WITNESSED TWICE IN ONE HOUR, INDEPENDENTLY, IN ONE FILE): test_snobol4_gimpel_suite.sh
# ended with `[ "$M3F" = 0 ] && [ "$M4F" = 0 ]`, vacuously TRUE over an empty results.tsv --
# scorecard_snobol4.sh TRUNCATES results.tsv before doing anything, so an UPSTREAM refusal (the
# concurrent-board registry declining, correctly) leaves it empty, and the wrapper turned that refusal
# into a green board. THE SHAPE: a guard that refuses upstream is undone by a verdict computed
# downstream over the empty result the refusal produced, silent because "no failures" and "nothing
# graded" are the same arithmetic.
#
# ⛔ CORRECTING THE BRIEF'S OWN CITATION: the dispatching message named
# test_snobol4_spitbol_testpgms_suite.sh as a worked "already does the floor" example. It does not
# exist anywhere in this tree (`grep -rl testpgms ../harness/scripts/` is empty) -- stale by the time it reached
# this seat, exactly the decay this repo's own docs keep warning about. The REAL, verified-on-disk
# precedents this gate's design and ARM 9/10 below are copied from: lib_ladder.sh (already carries
# `[ "$n" -gt 0 ] || refuse "graded ZERO witnesses..."` plus a second, stronger check for a rung
# DECLARED-but-unbuilt), board_beauty_m1.sh and board_icon_rungs.sh (already call gate_floor()/
# gate_verdict() directly), and util_require_fresh.sh (the shim shape this row's own
# util_require_population.sh is a mechanical copy of, down to the flag parsing).
#
# THE FIX: gate_floor() already existed in lib_gate.sh (used by gate-file-convention scripts). This row
# adds util_require_population.sh -- the CLI shim over it, so a `test_*_suite.sh`/board/scorecard
# wrapper or a Python harness can call the ONE authority without adopting the full GATE_NAME/gate_stamp
# sourcing convention, exactly as util_require_fresh.sh already does for staleness -- and wires it into
# every wrapper this row found with the defect shape.
#
# ⭐⭐ THE CENSUS IS HONEST, NOT UNIFORM (found while doing this row, not assumed): `board_*.sh` and
# `scorecard_*.sh` are NOT one shape. Every one of the 13 board_*.sh + 2 scorecard_*.sh files surveyed
# is EITHER already adequate (board_icon_rungs.sh / board_beauty_m1.sh call gate_floor directly;
# scorecard_icon.sh's header explains IN WORDS why it has "no pass/fail bar to violate" and uses
# lib_gate.sh's 0/2 convention on purpose) OR legitimately has no boolean verdict at all by design
# (perf-ratio boards, snap/diff comparison tools, board_packages.sh explicitly REPORTED-only "at this
# stage (D1)... D5 turns this into a floor" per its own GOAL). None were wired here because none NEED
# it. See ARM 6 below for the file-by-file account, not a blind grep.
#
# ⛔ A SEPARATE, MORE SEVERE, DIFFERENTLY-SHAPED DEFECT SURFACED DURING THIS CENSUS AND IS DELIBERATELY
# NOT FIXED HERE: six test_*_suite.sh files (test_csnobol4_budne_suite.sh, test_snobol4_pat_rung_suite.sh
# -- which banners itself "MODE-4 HARD GATE" --, test_icon_arizona_suite.sh, test_icon_jcon_suite.sh,
# test_pascal_pat_suite.sh, test_prolog_inria_suite.sh) compute real PASS/FAIL counts and then have NO
# exit-code verdict AT ALL (an unconditional `exit 0`, or simply no `exit` after the last printf, so the
# script's own rc is whatever that printf returns). THIS ROW'S CURE IS "ADD A FLOOR BEFORE AN EXISTING
# COMPARISON" -- these six have no comparison to put a floor before, and inventing pass/fail thresholds
# for six suites this seat does not own the semantics of is a judgment call for whoever owns each one,
# not a mechanical fix. ARM 6 lists them as a NAMED, TRACKED GAP (not a gate failure of THIS row, not a
# silent pass either) and this session sends an `ask` to hq_T so it is not lost.
#
# ARMS: 1-3 the shim itself (control, refusal, bad usage) · 4-5 REAL dynamic fail-once proofs (the
# Python harness on a genuinely empty suite pair; the gimpel wrapper under FORCED board contention --
# the exact witnessed scenario) · 6 the CENSUS, printed denominator, three-way classified · 7 lib_ladder.sh
# still carries its own (stronger) floor · 8 the one-copy invariant (util_require_population.sh has no
# floor logic of its own; gate_floor defined exactly once).
# EXIT: 0 all arms · 1 an arm failed · 2 REFUSED (could not measure -- unbuilt tree).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP_BIN="${SCRIP:-$ROOT/scrip}"
SHIM="$HERE/util_require_population.sh"

[ -x "$SHIM" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: shim under test missing/not executable: $SHIM"; exit 2; }
[ -x "$SCRIP_BIN" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: scrip not built at $SCRIP_BIN -- ARMs 4/5 need a current tree"; exit 2; }
"$HERE/util_require_fresh.sh" --gate gate-precondition >/dev/null 2>&1 || { echo "⛔ REFUSED-TO-GRADE rc=2: this tree's own scrip/libscrip_rt.so is stale -- run 'make', then re-run."; exit 2; }

fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }

echo "=== gate: every board wrapper refuses rc=2 on a zero population instead of passing vacuously ==="

echo "--- ARM 1 (control): the shim PASSES when count >= floor ---"
out="$("$SHIM" --gate arm1 5 1 "widgets" 2>&1)"; rc=$?
[ "$rc" = 0 ] && ck ok "5 >= floor 1 -> rc=0" || ck no "must PASS; got rc=$rc -- $out"

echo "--- ARM 2: the shim REFUSES rc=2 on count < floor, naming count/floor/label ---"
out="$("$SHIM" --gate arm2 0 1 "widgets (upstream: fake refusal)" 2>&1)"; rc=$?
[ "$rc" = 2 ] && ck ok "0 < floor 1 -> rc=2" || ck no "must REFUSE rc=2; got rc=$rc -- $out"
grep -q "examined 0 widgets" <<<"$out" && ck ok "refusal names the count and label" || ck no "refusal must name count+label -- $out"
grep -q "floor is 1" <<<"$out" && ck ok "refusal names the floor" || ck no "refusal must name the floor -- $out"

echo "--- ARM 3: the shim REFUSES rc=2 on malformed usage (missing args, non-numeric count) ---"
out="$("$SHIM" --gate arm3 2>&1)"; rc=$?
[ "$rc" = 2 ] && ck ok "missing args -> rc=2" || ck no "must REFUSE rc=2; got rc=$rc -- $out"
out="$("$SHIM" --gate arm3b notanumber 1 label 2>&1)"; rc=$?
[ "$rc" = 2 ] && ck ok "non-numeric count -> rc=2" || ck no "must REFUSE rc=2; got rc=$rc -- $out"

echo "--- ARM 4 (REAL dynamic proof): the Python harness refuses rc=2 on a genuinely empty suite pair ---"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_pop_floor.XXXXXX")" || { echo "⛔ REFUSED-TO-GRADE rc=2: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
: > "$W/empty.sno"; : > "$W/empty.ref"
out="$(python3 "$HERE/corpus_suite_harness.py" run "$W/empty.sno" "$W/empty.ref" --modes m3 2>&1)"; rc=$?
[ "$rc" = 2 ] && ck ok "zero-entry suite pair -> rc=2 (was rc=0 before this row: sys.exit(0 if not fails else 1) over fails=[])" \
              || ck no "must REFUSE rc=2; got rc=$rc -- $out"
grep -q "examined 0 entries" <<<"$out" && ck ok "harness refusal names zero entries" || ck no "harness refusal must name the empty population -- $out"

echo "--- ARM 5 (REAL dynamic proof, the WITNESSED scenario): gimpel wrapper refuses under FORCED board contention ---"
# ⭐ This is not a synthetic shape -- it is the exact incident the row's own GOAL describes, replayed:
# register a fake peer under a live PID so scorecard_snobol4.sh's registry sees contention, refuses
# (rc=3), and truncates results.tsv to empty -- which is precisely what a real second board running at
# the same time does. Isolated via S4E_BOARDS so this never touches the real registry.
sleep 60 & FAKE_PID=$!
FAKE_BOARDS="$W/fake_boards"; mkdir -p "$FAKE_BOARDS"
printf '%s|%s|%s|%s|%s\n' "$FAKE_PID" "/fake/root" "/fake/out" "1" "2026-01-01T00:00:00" > "$FAKE_BOARDS/$FAKE_PID.board"
# ⛔ ON A SCRATCH CORPUS (ceo CEO-1302 (c), coo 2026-09-27): the fixture exemption no longer admits the shared corpus, so the wrapper
# grades a copy of the gimpel package with include copied beside it, the population it would copy into its own overlay anyway.
PFC="$W/pfcorpus"; mkdir -p "$PFC/packages/snobol4"; cp -a "$(cd "$HERE/../.." && pwd)/corpus/packages/snobol4/gimpel" "$PFC/packages/snobol4/gimpel"
cp -a "$(cd "$HERE/../.." && pwd)/corpus/include" "$PFC/include"
out="$(CORPUS="$PFC" S4E_PROGRESS_DB="$W/pf_progress.tsv" S4E_BOARDS="$FAKE_BOARDS" bash "$HERE/test_snobol4_gimpel_suite.sh" 2>&1)"; rc=$?
kill "$FAKE_PID" 2>/dev/null; wait "$FAKE_PID" 2>/dev/null
[ "$rc" = 2 ] && ck ok "forced board contention -> gimpel wrapper rc=2 (was rc=0 before this row: M3F=M4F=0 over the truncated-empty results.tsv)" \
              || ck no "must REFUSE rc=2; got rc=$rc -- $out"
# ⭐ NOT PINNED TO THIS ROW'S OWN MESSAGE TEXT: a second seat independently cured the SAME incident in
# this SAME file concurrently with this row (commit cfde5756f, checking TOTAL==0 -- an earlier, coarser
# check than this row's SCORED==0, which also catches the distinct all-ORACLE_FAIL case where TOTAL>0
# but nothing was scored). Whichever check fires first is correct; asserting one exact wording would
# make this gate red the next time a third seat improves the message again. Assert the OUTCOME: rc=2,
# and that SOME refusal names the empty/zero population and scorecard's own non-zero exit.
grep -qE "graded ZERO|scored rows|UNMEASURED" <<<"$out" && grep -q "rc=3" <<<"$out" && ck ok "refusal names the zero/empty population and scorecard's own contention rc" \
              || ck no "refusal must name the upstream cause -- $out"

echo "--- ARM 6 (CENSUS, PRINTED DENOMINATOR, three-way): every test_*_suite.sh is WIRED, ALREADY-ADEQUATE, or a NAMED GAP ---"
# WIRED: calls this row's shim directly, OR calls gate_floor directly (the pre-existing authority this
# row's shim wraps), OR delegates its grading to corpus_suite_harness.py's `run` (which this row wired).
ALREADY_ADEQUATE="test_prolog_swi_suite.sh test_snocone_hand_suite.sh test_snobol4_spitbol_testpgms_suite.sh test_icon_bench_suite.sh test_pascal_bench_suite.sh test_prolog_bench_suite.sh test_rebus_bench_suite.sh"
# the four BENCHMARK runners (landed 2026-09-23 by four seats; classified by the coo the same day, when their arrival turned this
# arm red): each refuses rc=2 on an empty kernel population with its own line -- icon :67 `[ "${#POP[@]}" -gt 0 ] || refuse`,
# pascal :48, prolog :41 and rebus :52 `[ "${#KERNELS[@]}" -gt 0 ] || refuse` -- and each refuse() exits 2. MEASURED for the
# two that take a directory override (BENCH_REBUS_DIR, BENCH_PROLOG_DIR pointed at an empty dir): rc=2, "a population of zero
# is not a green board". A kernel found is a kernel graded (compile failures grade FAIL), so the discovery floor is the floor.
# test_prolog_swi_suite.sh: run_one_mode() already has `[ "$TOTAL" -gt 0 ] || { REFUSED-TO-GRADE; exit 2; }`
#   (verified by hand, predates this row) -- does not match the grep below because it never calls the
#   shim, gate_floor, or the harness; it is a fourth, bespoke-but-correct mechanism.
# test_snocone_hand_suite.sh: TESTS=(fibonacci palindrome wordcount quicksort pattern_suite) is a
#   hardcoded literal array, not a glob/discovery result -- it cannot become silently empty at runtime
#   the way every other wrapper in this census can; only an in-diff source edit could empty it, which
#   code review catches, not this gate.
# test_snobol4_spitbol_testpgms_suite.sh: landed independently, concurrently with this row (a different
#   seat's row on the same defect class -- the dispatching message's citation of this exact filename,
#   which did not exist when this row started, turned out to be a race rather than pure staleness). It
#   already carries its own correct, hand-written `if [ "$SCORED" -eq 0 ]; then REFUSE rc=2; fi` --
#   verified by hand, not wired to this row's shim, and does not need to be.
KNOWN_GAP="test_csnobol4_budne_suite.sh test_snobol4_pat_rung_suite.sh test_icon_arizona_suite.sh test_icon_jcon_suite.sh test_pascal_pat_suite.sh test_prolog_inria_suite.sh"
# ^ verified by hand 2026-09-04: each computes real PASS/FAIL counts and then has NO exit-code verdict
#   at all (unconditional `exit 0`, or no `exit` after the final printf) -- a DIFFERENT defect shape
#   (no comparison exists to put a floor before) than this row cures. Tracked, not silently passed: see
#   the header comment and this session's `ask` to hq_T. A future row that gives these real verdicts
#   must ALSO give them a population floor, or it reintroduces this row's exact class on day one.
graders=0; wired=0; adequate=0; gap=0; unaccounted=""
for f in "$HERE"/test_*_suite.sh; do
    graders=$((graders+1))
    base="$(basename "$f")"
    case " $ALREADY_ADEQUATE " in *" $base "*) adequate=$((adequate+1)); continue;; esac
    case " $KNOWN_GAP " in *" $base "*) gap=$((gap+1)); continue;; esac
    if grep -qE 'util_require_population\.sh|gate_floor|corpus_suite_harness\.py' "$f"; then
        wired=$((wired+1))
    else
        unaccounted="$unaccounted $base"
    fi
done
echo "    graders=$graders wired=$wired already-adequate=$adequate known-gap=$gap unaccounted=$(printf '%s' "$unaccounted" | wc -w)"
[ "$graders" -ge 20 ] && ck ok "census floor: $graders test_*_suite.sh examined (zero-examined would be indistinguishable from all-clean)" \
                      || ck no "census examined only $graders -- the glob moved; a floor this low cannot prove anything"
[ -z "$unaccounted" ] && ck ok "every $graders test_*_suite.sh is wired, already-adequate, or a named tracked gap -- none fell through uncategorized" \
                      || ck no "UNACCOUNTED (new file, or a regression in one already fixed):$unaccounted"

echo "--- ARM 7: lib_ladder.sh still carries its own (stronger) population floor ---"
grep -q 'graded ZERO witnesses' "$HERE/lib_ladder.sh" && ck ok "lib_ladder.sh refuses on zero graded witnesses (pre-existing, verified, not touched by this row)" \
                                                        || ck no "lib_ladder.sh's population floor is gone -- every test_<lang>_ladder.sh just regressed"
grep -q 'LADDER.tsv declares rung' "$HERE/lib_ladder.sh" && ck ok "lib_ladder.sh also refuses on a DECLARED-but-unbuilt rung (the stronger, second half of the same class)" \
                                                          || ck no "lib_ladder.sh's declared-rung cross-check is gone"

echo "--- ARM 8 (the one-copy invariant): the floor rule is DEFINED exactly once ---"
defs=$(grep -rl '^gate_floor()' "$HERE" 2>/dev/null | wc -l)
[ "$defs" = 1 ] && ck ok "gate_floor() defined in exactly 1 file (lib_gate.sh)" \
                || ck no "gate_floor() defined in $defs files -- a second copy is how this class survives its own cure"
if grep -qE '^\s*if \[ "\$[0-9A-Za-z_]+" -lt ' "$SHIM"; then
    ck no "util_require_population.sh appears to reimplement the floor comparison instead of sourcing gate_floor -- it must SHELL OUT to the one authority"
else
    ck ok "util_require_population.sh carries no floor logic of its own"
fi
# extract def require_population(...) up to (not including) the NEXT top-level `def`, so a long
# docstring in between (this one has one, explaining why it shells out rather than reimplementing)
# doesn't starve a fixed -A window the way it did the first time this arm was written.
_reqpop="$(awk '/^def require_population/{p=1} p{print} p && /^def / && !/^def require_population/{exit}' "$HERE/corpus_suite_harness.py")"
if [ -z "$_reqpop" ]; then
    ck no "corpus_suite_harness.py's require_population() is missing"
elif grep -q 'subprocess.run' <<<"$_reqpop"; then
    ck ok "corpus_suite_harness.py's require_population() shells out to the shim (no Python reimplementation of the floor)"
else
    ck no "corpus_suite_harness.py's require_population() does not shell out -- check for a Python-side reimplementation"
fi

echo "------------------------------------------------------------"
if [ "$fails" -ne 0 ]; then echo "⛔ GATE FAIL: $fails of $checks check(s) failed"; exit 1; fi
echo "✅ GATE PASS: $checks/$checks checks (test_*_suite.sh censused: $graders, wired=$wired already-adequate=$adequate known-gap=$gap)"; exit 0
