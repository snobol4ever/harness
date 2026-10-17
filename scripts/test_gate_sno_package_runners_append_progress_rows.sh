#!/usr/bin/env bash
export S4E_ONE_RUNNER_FIXTURE="gate arm ${0##*/}: a runner invoked as an instrument fixture, not a board (CEO-523)"
# test_gate_sno_package_runners_append_progress_rows.sh -- THE SNOBOL4 PACKAGE RUNNERS RECORD ONE PROGRESS ROW PER
# PROGRAM PER MODE, ON THE STREAM-EQUAL BASIS, AND NEVER FROM A SCRATCH SUITE INTO THE LIVE TABLE.
# Row snobol4-snoflake-aisnobol-and-dotnet-runners-wired-onto-lib-inventory-with-their-sidecars (coo, 2026-09-07;
# CEO-383 rulings 2 and 3: "the measure counts only runner-appended rows, so the runner is defective, not the flip";
# a board published under an inventory REFUSE(2) is void). Before this landing test_snoflake_suite.sh and
# test_snobol4_dotnet_suite.sh appended NOTHING (util_progress_flips.py --coverage: snoflake MISSING, dotnet MISSING),
# so Flake's 131 -> 134 was unpaid and invisible; aisnobol records through corpus_suite_harness.py already.
# HERMETIC: S4E_PROGRESS_DB points every recording arm at a scratch table under mktemp; the suites are scratch copies
# (SNOFLAKE_SUITE / DOTNET_SUITE), so the live leaderboard and the live table are never touched. Needs this tree's
# built binary (util_require_fresh refuses rc=2 on a stale or absent one) and the sbl -bf oracle.
#   1  snoflake, scratch suite + scratch table: exactly 6 rows (3 fixtures x 2 modes)
#   2  a byte-equal fixture is PASS in both modes
#   3  an error-number-only fixture is UNGRADED (never PASS) in mode 3 -- the CEO-383 basis
#   4  the board prints the table's reading: SNOFLAKE_BOARD ... both_modes_stream_pass=1
#   5  the inventory does not refuse: PACKAGE_INVENTORY ... ungradable=2 (the two fixtures SPITBOL itself errors on are OUTSIDE THE SPITBOL BASELINE,
#      named in the scratch OUTSIDE_SPITBOL_BASELINE.tsv and mirrored into UNGRADABLE.tsv). ⛔ THIS ARM READ graded_narrow=2 UNTIL 2026-09-08 (ceo,
#      CEO-392): Lon ruled the score divides by the programs SPITBOL runs clean, so an error-number-only comparison is no longer a graded bucket at all --
#      the fixture leaves the denominator instead of being graded by a narrower instrument. The arm is not weakened: it still proves the inventory sums.
#   6  the same scratch suite WITHOUT S4E_PROGRESS_DB records nothing (says NOT recorded) and writes no SCORE.md cell
#   7  this seat's snoflake rows in the live table are exactly as many after arm 6 as before it (the table is shared and grows under other seats)
#   8  dotnet, scratch suite + scratch table: exactly 4 rows (2 programs x 2 modes), all PASS
#   9  dotnet prints the table's reading: DOTNET_AND both_modes_pass=2/2
#  10  testpgms, scratch copy of SPITBOL's own deck + scratch table: two rows per program, every outcome on the ladder, and the
#      programs PASS in both modes are the board's both_modes_pass
#  11  every program the board names UNSCORED reads OUTSIDE in both modes, its note carrying the oracle's own refusal
#  12  the same scratch deck WITHOUT S4E_PROGRESS_DB records nothing, writes no SCORE.md cell, and the live SUITES.tsv and SCORE.md
#      are byte-identical after it
#      (coo 2026-09-26, on hq_snobol4's report: test_snobol4_spitbol_testpgms_suite.sh appended NOTHING, so every write refused
#      "no progress rows for suite 'testpgms'" and the batch audit read the row UNPROVEN since 61315eaa9; and it wrote the
#      leaderboard for ANY suite, harmless only while nothing was appended. TESTPGMS_RUNNER=<a pre-cure copy beside this file>
#      reads 10, 11 and 12 red.)
# Fail-once (2026-09-07 09:0x CDT, coo, measured): with the pre-landing runners restored from scratch copies, 7 of 9 arms red
# (1-4, 6, 8, 9); arm 5 stays green because the scratch sidecars already name both outside fixtures, arm 7 by construction.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
. "$HERE/lib_gate.sh"
gate_parse_args "$@"
G=sno_package_runners_append_progress_rows
SNO="$S4E/corpus/packages/snobol4/snoflake_suite"; DOT="$S4E/corpus/packages/snobol4/dotnet"
[ -d "$SNO" ] && [ -d "$DOT" ] || { echo "GATE UNPROVEN(2) [$G]: package dirs missing under $S4E/corpus/packages/snobol4"; exit 2; }
"$HERE/util_require_fresh.sh" --gate test_gate_$G "$ROOT/scrip" "$ROOT/out/libscrip_rt.so" >/dev/null 2>&1 || { echo "GATE UNPROVEN(2) [$G]: this tree's binary is stale or unbuilt -- run make"; exit 2; }
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "GATE UNPROVEN(2) [$G]: lib_oracle_flags.sh unloadable"; exit 2; }
[ -x "$(sbl_correctness_bin)" ] || { echo "GATE UNPROVEN(2) [$G]: sbl -bf oracle absent"; exit 2; }
LIVE_DB="${S4E_PROGRESS_DB:-/home/resources/progress/results.tsv}"
W="$(mktemp -d "${TMPDIR:-/tmp}/gate_pkgprog.XXXXXX")" || { echo "GATE UNPROVEN(2) [$G]: mktemp failed"; exit 2; }
trap 'rm -rf "$W"' EXIT
PASS=0; FAIL=0; red() { FAIL=$((FAIL+1)); echo "  ⛔ arm $1 RED: $2"; }; ok() { PASS=$((PASS+1)); echo "  ✅ arm $1: $2"; }
rows() { awk -F'\t' 'NR>1 && NF>=10' "$1" 2>/dev/null | wc -l | tr -d ' '; }
# The LIVE table is shared by every seat and grows under them mid-gate (measured inside make test 2026-09-07: +15 rows
# from two other seats' boards in the ten seconds of arm 6), so arm 7 counts only THIS seat's snoflake rows.
ME="$(. "$HERE/lib_progress.sh" 2>/dev/null; progress_context 2>/dev/null | grep -oE 'measurer=[^[:space:]]+' | cut -d= -f2)"; [ -n "$ME" ] || ME=unknown
mine() { awk -F'\t' -v me="$ME" 'NR>1 && NF>=10 && $4==me && $6=="snoflake"' "$1" 2>/dev/null | wc -l | tr -d ' '; }
outcome() { awk -F'\t' -v p="$2" -v m="$3" 'NR>1 && $8==p && $9==m {print $10}' "$1" 2>/dev/null | tail -1; }
# --- snoflake scratch suite: one fixture SPITBOL runs clean and SCRIP matches, two fixtures SPITBOL itself errors on (outside the baseline), the gimpel includes
mkdir -p "$W/sno"; for f in indirect-real-illegal-type stlimit-nonnegative gimpel-general-purpose-macro; do
    [ -f "$SNO/$f.sno" ] || { echo "GATE UNPROVEN(2) [$G]: fixture $f.sno missing from $SNO"; exit 2; }; cp "$SNO/$f.sno" "$W/sno/"; done
cp -r "$SNO/gimpel" "$W/sno/gimpel"
printf 'gimpel-general-purpose-macro.sno\tORACLE_REFUSES\tdoes not run in SPITBOL: ERROR 285 -- include file cannot be opened; source checked 2026-09-08 (ceo)\nstlimit-nonnegative.sno\tORACLE_REFUSES\tdoes not run in SPITBOL: ERROR 244 -- statement count exceeds value of stlimit keyword; source checked 2026-09-08 (ceo)\n' > "$W/sno/OUTSIDE_SPITBOL_BASELINE.tsv"
cp "$W/sno/OUTSIDE_SPITBOL_BASELINE.tsv" "$W/sno/UNGRADABLE.tsv"
OUT1="$(cd "$ROOT" && S4E_PROGRESS_DB="$W/db1.tsv" SNOFLAKE_SUITE="$W/sno" ARM_CSN=0 timeout -k 5 300 bash "$HERE/test_snoflake_suite.sh" 2>&1)"
n="$(rows "$W/db1.tsv")"; [ "$n" = 6 ] && ok 1 "6 rows recorded in the scratch table" || red 1 "expected 6 rows in $W/db1.tsv, got $n"
o3="$(outcome "$W/db1.tsv" indirect-real-illegal-type m3)"; o4="$(outcome "$W/db1.tsv" indirect-real-illegal-type m4)"
[ "$o3" = PASS ] && [ "$o4" = PASS ] && ok 2 "byte-equal fixture PASS in both modes" || red 2 "indirect-real-illegal-type m3=$o3 m4=$o4 (want PASS/PASS)"
e3="$(outcome "$W/db1.tsv" stlimit-nonnegative m3)"; g3="$(outcome "$W/db1.tsv" gimpel-general-purpose-macro m3)"
[ "$e3" = UNGRADED ] && [ "$g3" = UNGRADED ] && ok 3 "error-number-only fixtures UNGRADED in mode 3" || red 3 "stlimit-nonnegative m3=$e3 gimpel-general-purpose-macro m3=$g3 (want UNGRADED)"
printf '%s\n' "$OUT1" | grep -qE '^SNOFLAKE_BOARD total=3 .*both_modes_stream_pass=1( |$)' && ok 4 "SNOFLAKE_BOARD states both_modes_stream_pass=1" || red 4 "no SNOFLAKE_BOARD line with both_modes_stream_pass=1"
if printf '%s\n' "$OUT1" | grep -q 'INVENTORY REFUSES'; then red 5 "the inventory refused on the scratch suite"; else
    printf '%s\n' "$OUT1" | grep -qE '^PACKAGE_INVENTORY package=snoflake_suite .*ungradable=2( |$)' && ok 5 "PACKAGE_INVENTORY ungradable=2, no refusal" || red 5 "no PACKAGE_INVENTORY line with graded_narrow=2"; fi
# --- the scratch suite without a scratch table must record nothing, anywhere
before="$(mine "$LIVE_DB")"
OUT6="$(cd "$ROOT" && env -u S4E_PROGRESS_DB SNOFLAKE_SUITE="$W/sno" ARM_CSN=0 timeout -k 5 300 bash "$HERE/test_snoflake_suite.sh" 2>&1)"
after="$(mine "$LIVE_DB")"
if printf '%s\n' "$OUT6" | grep -q 'NOT recorded' && printf '%s\n' "$OUT6" | grep -q 'SCORE.md: scratch suite'; then ok 6 "scratch suite says NOT recorded and writes no SCORE.md cell"; else red 6 "scratch suite without S4E_PROGRESS_DB did not say NOT recorded / SCORE.md not written"; fi
[ "$before" = "$after" ] && ok 7 "live table unchanged for this seat's snoflake rows ($before rows, measurer $ME)" || red 7 "this seat's snoflake rows in the live table grew $before -> $after during a scratch run"
# --- dotnet scratch suite: two programs that answer byte-equal to the oracle in both modes
mkdir -p "$W/dot"; for f in chap8_funcs pattern_demo; do
    [ -f "$DOT/$f.sno" ] || { echo "GATE UNPROVEN(2) [$G]: program $f.sno missing from $DOT"; exit 2; }; cp "$DOT/$f.sno" "$W/dot/"; for e in IN in input; do [ -f "$DOT/$f.$e" ] && cp "$DOT/$f.$e" "$W/dot/"; done; done
OUT8="$(cd "$ROOT" && S4E_PROGRESS_DB="$W/db2.tsv" DOTNET_SUITE="$W/dot" timeout -k 5 300 bash "$HERE/test_snobol4_dotnet_suite.sh" 2>&1)"
n="$(rows "$W/db2.tsv")"; np="$(awk -F'\t' 'NR>1 && $10=="PASS"' "$W/db2.tsv" 2>/dev/null | wc -l | tr -d ' ')"
[ "$n" = 4 ] && [ "$np" = 4 ] && ok 8 "4 dotnet rows, all PASS" || red 8 "dotnet rows=$n pass=$np (want 4/4)"
printf '%s\n' "$OUT8" | grep -qE '^DOTNET_AND both_modes_pass=2/2( |$)' && ok 9 "DOTNET_AND both_modes_pass=2/2" || red 9 "no DOTNET_AND both_modes_pass=2/2 line"
# --- testpgms: a scratch copy of the whole deck (its programs share testpgms.in and read their sidecars)
TP="$S4E/corpus/packages/snobol4/spitbol_testpgms"; TP_RUNNER="${TESTPGMS_RUNNER:-$HERE/test_snobol4_spitbol_testpgms_suite.sh}"
[ -d "$TP" ] && [ -s "$TP_RUNNER" ] || { echo "GATE UNPROVEN(2) [$G]: $TP or $TP_RUNNER missing"; exit 2; }
cp -a "$TP" "$W/tp" || { echo "GATE UNPROVEN(2) [$G]: could not copy $TP to a scratch deck"; exit 2; }
NTP="$(ls "$W/tp"/test*.spt 2>/dev/null | wc -l | tr -d ' ')"
OUT10="$(cd "$ROOT" && S4E_PROGRESS_DB="$W/db3.tsv" SPITBOL_TESTPGMS_SUITE="$W/tp" timeout -k 5 600 bash "$TP_RUNNER" 2>&1)"
n="$(rows "$W/db3.tsv")"; bad="$(awk -F'\t' 'NR>1 && $10 !~ /^(PASS|FAIL|CRASH|HANG|OUTSIDE)$/' "$W/db3.tsv" 2>/dev/null | wc -l | tr -d ' ')"
both_db="$(awk -F'\t' 'NR>1 {k[$8]=k[$8] " " $9 ":" $10} END {n=0; for (p in k) if (k[p] ~ /m3:PASS/ && k[p] ~ /m4:PASS/) n++; print n}' "$W/db3.tsv" 2>/dev/null)"
both_bd="$(printf '%s\n' "$OUT10" | sed -n 's/^SPITBOL_TESTPGMS_BASELINE .*both_modes_pass=\([0-9]*\).*/\1/p')"
if [ "$NTP" -gt 0 ] && [ "$n" = "$((2*NTP))" ] && [ "$bad" = 0 ] && [ -n "$both_bd" ] && [ "$both_db" = "$both_bd" ]; then
    ok 10 "testpgms: $n rows for $NTP programs, every outcome on the ladder, $both_db PASS in both modes = the board's both_modes_pass"
else red 10 "testpgms rows=$n (want $((2*NTP))), off-ladder=$bad, both-modes PASS in the table=$both_db vs the board's both_modes_pass=${both_bd:-none}"; fi
uns="$(printf '%s\n' "$OUT10" | sed -n 's/^  UNSCORED  \([^ ]*\) .*/\1/p' | sort | tr '\n' ' ')"
out_db="$(awk -F'\t' 'NR>1 && $10=="OUTSIDE" && $12 ~ /sbl -bf/ {print $8}' "$W/db3.tsv" 2>/dev/null | sort | uniq -c | awk '$1==2 {print $2}' | tr '\n' ' ')"
[ "$uns" = "$out_db" ] && ok 11 "testpgms: the programs the oracle does not run [${uns:-none}] read OUTSIDE in both modes with its refusal" \
    || red 11 "UNSCORED on the board [${uns:-none}] vs OUTSIDE in both modes in the table [${out_db:-none}]"
. "$(dirname "${BASH_SOURCE[0]}")/lib_suites_tsv.sh" || exit 2; s_mark="$(suites_real_mark)"; s_before="$(md5sum < "$S4E/.github/SCORE.md" 2>/dev/null)"
OUT12="$(cd "$ROOT" && env -u S4E_PROGRESS_DB SPITBOL_TESTPGMS_SUITE="$W/tp" timeout -k 5 600 bash "$TP_RUNNER" 2>&1)"
s_after="$(md5sum < "$S4E/.github/SCORE.md" 2>/dev/null)"; suites_real_untouched "$s_mark" || s_after="the shared SUITES.tsv moved"
if printf '%s\n' "$OUT12" | grep -q 'progress: scratch suite .* NOT recorded' && printf '%s\n' "$OUT12" | grep -q '^SCORE.md: scratch suite' && [ "$s_before" = "$s_after" ]; then
    ok 12 "testpgms: a scratch deck without a scratch table records nothing and leaves the live SUITES.tsv and SCORE.md byte-identical"
else red 12 "testpgms scratch deck without S4E_PROGRESS_DB: NOT-recorded line $(printf '%s\n' "$OUT12" | grep -c 'NOT recorded'), scratch SCORE line $(printf '%s\n' "$OUT12" | grep -c '^SCORE.md: scratch suite'), live files $([ "$s_before" = "$s_after" ] && echo unchanged || echo CHANGED)"; fi
echo "------------------------------------------------------------"
if [ "$FAIL" = 0 ]; then echo "GATE PASS(0) [$G]: $PASS of 12 arms green (denominator: 12 arms over 3 snoflake fixtures + 2 dotnet programs + the $NTP-program testpgms deck, scratch tables + scratch suites)"; exit 0
else echo "GATE FAIL(1) [$G]: $FAIL of 12 arms red"; exit 1; fi
