#!/usr/bin/env bash
# test_gate_ladder_walk_v4_exempts_package_class_rows.sh -- THE ACCEPTANCE GATE for row ladder-walk-v4-exempts-package-
# class-rows (ceo CEO-230 -> hq_T 2026-09-04; law RULES.md § FACT RULES THE PACKAGE-CLASS RULE, on Lon 13:20: the
# percentage IS the V column).
#
# THE DEFECT: util_ladder_walk.py's V4 RANK INVERSION flagged EVERY FREE off-ladder row at rank 0/1 -- including the class
# rows minted from a vendored-package census (icon-arizona-class-…, pascal-fpc-class-…, prolog-inria-class-…), which are
# LADDER-RANK WORK by law and belong at rank 1. The ceo's 16:14 walk printed 18 such lines; on the 2026-09-04 evening
# queue the count was 27 of 62 V4 lines, so the report the ceo reads every tick was nearly half noise, and a report that
# is half noise is a report nobody reads (the same finding that turned V6 into a census).
#
# ⛔ THE CURE IS BY SHAPE, NOT BY A LIST OF PACKAGE NAMES, and this gate pins that: a list is a census that drifts
# silently the day a new suite is vendored -- its class rows would be flagged again and read as genuine inversions by
# whoever had stopped seeing the old ones. The shape the law defines is <lang>-<package>-class-<slug>: a recognised
# language prefix, exactly ONE package token, then -class-. Two tokens (prolog-master-red-class-…) is a RUNGS-BOARD red
# class, not a package class, and stays a V4 candidate.
#
# ARMS, hermetic (a scratch plan + a scratch postoffice under mktemp; the LIVE postoffice is never read):
#   ARM 1  a <lang>-<package>-class-* row FREE at rank 1 is NOT flagged            (pre-cure: flagged -- the fail-once arm)
#   ARM 2  a genuine off-ladder rank-1 row IS still flagged                        (control: the cure did not delete V4's job)
#   ARM 3  the exemption is COUNTED on one visible line, never silent              (pre-cure: no such line)
#   ARM 4  by SHAPE: a two-token -rungs-red-class- row at rank 1 is still flagged
#   ARM 5  rank 2+ was never V4's business, either way
#   ARM 6  a PRE-SHAPE package row (no -class- token) is exempt too -- 15 were minted before the rule
#   ARM 7  the package token may sit at segment two (pascal-iso7185-pat-*, prolog-swi-tests-*)
#   ARM 8  a row whose second segment is an ordinary word (snobol4-every-non-package-...) is NOT exempt
#   ARM 9  the vocabulary is CENSUSED FROM DISK: a freshly vendored package directory exempts its rows with no
#          edit to this script -- the arm a hand-typed list cannot pass
#   ARM 10 an unreadable census turns the exemption OFF with a visible warning, and flags package rows again
# FAIL-ONCE PROVEN 2026-09-04: SUT=<pre-cure util_ladder_walk.py> fails exactly ARM 1 and ARM 3, passes 2/4/5.
# EXIT: 0 all arms · 1 an arm failed · 2 REFUSED (no python3, SUT missing, mktemp failed, or the walk itself refused).
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUT="${SUT:-$HERE/util_ladder_walk.py}"
[ -f "$SUT" ] || { echo "⛔ REFUSED-TO-GRADE rc=2: script under test not found: $SUT"; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "⛔ REFUSED-TO-GRADE rc=2: python3 not on PATH"; exit 2; }
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_walk_v4.XXXXXX")" || { echo "⛔ REFUSED-TO-GRADE rc=2: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/po/claims" "$W/po/tasks"
printf '# scratch index\n' > "$W/po/QUEUE.done.tsv"
printf '# scratch index\n0\tsno-scratch-rung-row\thq_C\tFREE\n1\ticon-arizona-class-scratch-package-class\thq_B\tFREE\n1\ticon-scratch-genuine-off-ladder-row\thq_B\tFREE\n1\tprolog-master-red-class-scratch-two-tokens\thq_C\tFREE\n2\tpascal-fpc-class-scratch-rank-two\thq_P\tFREE\n1\ticon-jcon-scratch-pre-shape-no-class-token\thq_B\tFREE\n1\tpascal-iso7185-pat-scratch-package-at-segment-two\thq_P\tFREE\n1\tsnobol4-every-non-package-source-scratch\thq_B\tFREE\n' > "$W/po/QUEUE.tsv"
# ⛔ THE PACKAGE VOCABULARY IS CENSUSED FROM DISK, so this gate builds a SCRATCH tree for it rather than reading
# the real corpus: an arm that depended on the live corpus would grade whatever anyone vendored today, and could
# not prove the census MECHANISM at all. arizona_tests/jcon_tests/fpc_tests/pat are named here as DIRECTORIES,
# exactly as the real tree names them, so the normalisation (jcon_tests -> jcon) is under test too.
mkdir -p "$W/home/corpus/packages/icon/arizona_tests" "$W/home/corpus/packages/icon/jcon_tests" \
         "$W/home/corpus/packages/pascal/fpc_tests" "$W/home/corpus/packages/pascal/pat" "$W/home/harness/scripts"
export S4E_HOME="$W/home"
printf '### LADDER SNO — scratch\n\n| rung | row | lane | gate |\n|---|---|---|---|\n| SNO1 | sno-scratch-rung-row | hq_C | x |\n' > "$W/plan.md"
out="$(python3 "$SUT" --plan "$W/plan.md" --po "$W/po" --quiet 2>&1)"; rc=$?
# rc=1 is the only honest reading of this fixture: ARM 2's genuine inversion is always present, so a 0 means the walk
# printed nothing at all, and a 2 means it refused -- neither is a state this gate can grade.
[ "$rc" = 1 ] || { echo "⛔ REFUSED-TO-GRADE rc=2: the walk must exit 1 (violations printed) on the scratch fixture; it exited $rc:"; echo "$out"; exit 2; }
fails=0; checks=0
ck() { checks=$((checks+1)); if [ "$1" = ok ]; then printf '  ok    %s\n' "$2"; else printf '  FAIL  %s\n' "$2"; fails=$((fails+1)); fi; }
v4() { grep -E '^ *V4 RANK INVERSION ' <<<"$out" | grep -c -- "$1"; }
echo "=== gate: the ladder walk's V4 exempts package-class rows -- by shape, visibly, and only those ==="
echo "--- ARM 1: a <lang>-<package>-class-* row FREE at rank 1 is NOT a V4 inversion ---"
n=$(v4 'icon-arizona-class-scratch-package-class'); [ "$n" = 0 ] && ck ok "package class row at rank 1 -> no V4 line" || ck no "package class row still flagged ($n line(s)) -- it is ladder-rank by law"
echo "--- ARM 2 (control): a genuine off-ladder rank-1 row IS still flagged ---"
n=$(v4 'icon-scratch-genuine-off-ladder-row'); [ "$n" = 1 ] && ck ok "genuine off-ladder rank-1 row -> exactly one V4 line" || ck no "genuine inversion not flagged ($n line(s)) -- the cure deleted V4's job"
echo "--- ARM 3: the exemption is COUNTED, never silent ---"
grep -qE '^V4 EXEMPT \(package rule\): 3 FREE package row' <<<"$out" && ck ok "one visible census line names all 3 exempted rows" || ck no "no census line -- an invisible filter is indistinguishable from lost lines"
echo "--- ARM 4: by SHAPE -- two tokens before -class- is a rung suite-board red class, not a package class ---"
n=$(v4 'prolog-master-red-class-scratch-two-tokens'); [ "$n" = 1 ] && ck ok "prolog-master-red-class-* at rank 1 -> still flagged" || ck no "two-token row wrongly exempted ($n line(s))"
echo "--- ARM 5: rank 2+ was never V4's business, either way ---"
n=$(v4 'pascal-fpc-class-scratch-rank-two'); [ "$n" = 0 ] && ck ok "package class row at rank 2 -> no V4 line" || ck no "rank-2 row flagged ($n) -- V4 looks only at rank 0/1"
echo "--- ARM 6: a PRE-SHAPE package row (no -class- token at all) is exempt -- the vocabulary is the package, not the token ---"
n=$(v4 'icon-jcon-scratch-pre-shape-no-class-token'); [ "$n" = 0 ] && ck ok "icon-jcon-* with no -class- token -> no V4 line" \
    || ck no "still flagged ($n) -- 15 rows minted before the rule carry no -class- token and are package work all the same"
echo "--- ARM 7: the package token may sit at segment TWO (a row that dates the standard before naming the suite) ---"
n=$(v4 'pascal-iso7185-pat-scratch-package-at-segment-two'); [ "$n" = 0 ] && ck ok "pascal-iso7185-pat-* -> no V4 line" || ck no "still flagged ($n)"
echo "--- ARM 8 (control): a row whose second segment is an ordinary word is NOT exempt ---"
n=$(v4 'snobol4-every-non-package-source-scratch'); [ "$n" = 1 ] && ck ok "snobol4-every-* still flagged (every is not a vendored package)" \
    || ck no "wrongly exempted ($n) -- the vocabulary is leaking past the package census"
echo "--- ARM 9: the vocabulary is CENSUSED FROM DISK -- vendor a suite, and its rows exempt themselves ---"
# ⛔ THE ARM THAT KILLS THE HAND-TYPED LIST. A brand-new package directory that no source file has ever heard of
# must exempt its rows immediately; a typed list would fail this arm on the day a suite is vendored, which is the
# day nobody is looking at the walk.
printf '# scratch index\n1\tprolog-brandnewpkg-scratch-freshly-vendored\thq_C\tFREE\n1\ticon-scratch-genuine-off-ladder-row\thq_B\tFREE\n' > "$W/po/QUEUE.tsv"
out2="$(python3 "$SUT" --plan "$W/plan.md" --po "$W/po" --quiet 2>&1)"
grep -qE 'V4 RANK INVERSION .*prolog-brandnewpkg' <<<"$out2" && ck ok "before vendoring: the row IS flagged (the census is real, not a rubber stamp)" \
    || ck no "an unknown token must be flagged, or the exemption is meaningless"
mkdir -p "$W/home/corpus/packages/prolog/brandnewpkg_tests"
out2="$(python3 "$SUT" --plan "$W/plan.md" --po "$W/po" --quiet 2>&1)"
grep -qE 'V4 RANK INVERSION .*prolog-brandnewpkg' <<<"$out2" && ck no "after vendoring: still flagged -- the vocabulary is not coming from disk" \
    || ck ok "after vendoring the directory: the row exempts itself, with no edit to the walk"
echo "--- ARM 10: an UNREADABLE census turns the exemption OFF and says so -- never silently absent ---"
out3="$(S4E_HOME="$W/nonexistent" python3 "$SUT" --plan "$W/plan.md" --po "$W/po" --quiet 2>&1)"
grep -q 'V4 EXEMPTION OFF' <<<"$out3" && ck ok "no census -> a visible warning line" || ck no "the exemption vanished silently -- that reads as a queue that grew inversions"
grep -qE 'V4 RANK INVERSION .*prolog-brandnewpkg' <<<"$out3" && ck ok "and with the exemption off, package rows ARE flagged again (the warning is true)" \
    || ck no "warning printed but rows still exempt -- the line is decorative"

echo "------------------------------------------------------------"
if [ "$fails" -ne 0 ]; then echo "⛔ GATE FAIL: $fails of $checks check(s) failed"; exit 1; fi
echo "✅ GATE PASS: $checks/$checks checks"; exit 0
