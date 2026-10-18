#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "$(one_runner_population_of "$@")" || exit 2
# ⛔ THE STATEMENT INSTRUMENTATION (--stlimit) IS EACH PROGRAM'S OWN compile_args DECLARATION: gimpel's ALL.csv declares it on all 120 rows, and scorecard_snobol4.sh, which this wrapper grades through, reads it per program (clause 8 (f), CEO-1281, landing 4). This wrapper exported SCRIP_SNO_STMTKW=1 for every program until 2026-09-26 (Lon 2026-09-24 16:0x: off by default, never inferred from the source)
# test_snobol4_gimpel_suite.sh -- dedicated gate for corpus/packages/snobol4/gimpel (144 *_driver.sno
# programs; 145 further NAME.sno library modules exist alongside them but are structurally unscoreable
# by design -- see gimpel/README.md), minted for row
# snobol4-gimpel-aisnobol-dotnet-measured-with-dedicated-gates (hq_T 2026-09-03).
#
# THIN WRAPPER, not a reimplementation: scorecard_snobol4.sh already carries a dedicated, working
# `gimpel` suite row (weight 5, `-name *_driver.sno`, SELFDIR:include lib, 20s timeout) with mature
# oracle-liveness handling (sbl_died: an oracle that exits 0 while printing a fatal-report banner is
# UNSCR, never a silent PASS or a manufactured FAIL) -- reusing it is lower-risk than a parallel
# implementation of the exact same dialect traps scorecard_snobol4.sh's own history already paid for.
# This script only runs it scoped to `gimpel`, reads its results.tsv, and reprints the board in this
# suite's own dedicated-gate line format so the DONE-WHEN of the minting row can find it by name.
#
# Exit: 0 iff m3_fail=0 and m4_fail=0 over the SCORED (non-ORACLE_FAIL) denominator.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; SD="$HERE/../../SCRIP"; ROOT="$(cd "$HERE/../.." && pwd)"   # the root holds its repos as siblings, SCRIP or not
. "$HERE/lib_fixture_root.sh" || { echo "⛔ REFUSE(rc=2): cannot load lib_fixture_root.sh -- the one way a scratch corpus is staged"; exit 2; }
SCRIP="$SD/scrip"
# ⭐ UNDER A PORT ENGINE THIS RUNNER GRADES THE PORT WITH ITS OWN GRADING (S4E_ENGINE=dotnet|jvm; CEO-1822; Lon 2026-10-18, in-chat to hq_dotnet,
# verbatim: "Get all SNOBOL4 package runners working with snobol4dotnet."): scorecard_snobol4.sh takes the port's face as its SCRIP under the
# same engine, the port runner's --binaries is the one check, each driver is graded in m3 alone (its m4 column reads "-"), the AND is that one
# mode, the rows are keyed gimpel@<engine> by the one writer, and no SCRIP score row is written -- the port's row is from-progress.
PORT=0; one_runner_is_port && PORT=1
ROWKEY=gimpel; [ "$PORT" = 1 ] && ROWKEY="gimpel@$(one_runner_engine)"
if [ "$PORT" = 1 ]; then one_runner_port_ready snobol4 || exit 2; else
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2): no scrip binary at $SCRIP -- build first (make)"; exit 2; }
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). The line above proves a binary EXISTS; this one proves it is the binary this
# tree describes. ceo's witness, twice on 2026-09-04: a 10:57 binary graded at 14:03 read RED, then GREEN after
# an incremental make -- a vendor board is exactly where that is least visible, because a plausible all-FAIL
# table is this class's normal output. NO LOGIC HERE: util_require_fresh.sh sources gate_require_fresh from
# lib_gate.sh, the ONE authority (hq_B 4c7253e99) -- never a second copy of the staleness rule.
"$HERE/util_require_fresh.sh" --gate test_snobol4_gimpel_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
fi
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# ⛔⭐ THE VENDORED FIXTURES ARE READ-ONLY, SO THE RUN HAPPENS ON A COPY (row snobol4-gimpel-runner-writes-
# asmtemp-into-the-vendored-dir-and-blocks-its-own-score-write, ceo -> hq_T on hq_C's opening gimpel
# measurement; the Icon Arizona precedent is c96cb087d, same class, same day).
# ⛔ THE SIDE EFFECT DISABLED THE VERY WRITE THIS RUN EXISTS TO PRODUCE: ASM_driver.sno opens its own work file
# ASMTEMP, the scorecard runs each program in the program's OWN directory (deliberately -- argv is the bare
# basename so a diagnostic echoing its own name stays comparable to a frozen .ref), so ASMTEMP landed in
# corpus/packages/snobol4/gimpel/ and left the tree DIRTY -- whereupon util_score_row.py correctly refused the
# leaderboard row, because a number measured on a dirty tree describes no tree anyone can check out. A grader
# that writes into what it grades is the same defect as a gate that edits the artifact it measures.
# ⭐ WHY AN OVERLAY RATHER THAN A cwd CHANGE: the scorecard's per-program cwd is load-bearing (above), and this
# runner does not own that instrument -- it is the shared SNOBOL4 board every suite goes through. Copying the
# 1.8M package and pointing CORPUS at an overlay leaves that contract untouched: reads resolve exactly as
# before (`include` is symlinked back to the real tree, and the suite's own lib spec is SELFDIR:include), and
# every write lands on the copy, which dies with the trap above.
CORPUS_REAL="${CORPUS:-$ROOT/corpus}"
# ⛔⭐ THE OVERLAY IS NOT TRUSTED, IT IS CHECKED -- BEFORE AND AFTER, EVERY RUN (seat16, 2026-09-04 19:16 CDT:
# witnessed ASMTEMP in the vendored dir AFTER the overlay cure landed in its clone, and could not reproduce it
# mechanically; hq_T could not reproduce it either -- a full 144-program run with a one-second watcher armed on
# the real directory left it clean). ⛔ TWO PEOPLE UNABLE TO REPRODUCE A WITNESSED LEAK IS NOT EVIDENCE THAT IT
# DID NOT HAPPEN; it is evidence that argument is the wrong instrument. So the runner now measures its own side
# effect: it fingerprints the vendored directory before grading and again after, and if a single byte differs it
# REFUSES rc=2 naming the files. ⭐ A guard that fires ONCE with the file named is worth more than an hour of
# reasoning about whether an overlay can leak, and it costs two `find` calls.
_vend_fingerprint() { find "$CORPUS_REAL/packages/snobol4/gimpel" -type f -printf '%p %s %T@\n' 2>/dev/null | LC_ALL=C sort; }
VEND_BEFORE="$(_vend_fingerprint)"
mkdir -p "$W/corpus/packages/snobol4"
cp -a "$CORPUS_REAL/packages/snobol4/gimpel" "$W/corpus/packages/snobol4/gimpel" || {
    echo "⛔ REFUSE(rc=2): could not copy the gimpel package to a scratch overlay -- refusing to grade in the vendored dir"; exit 2; }
fixture_corpus_light "$CORPUS_REAL" "$W/corpus" tests || { echo "⛔ REFUSE(rc=2): could not stage the light corpus (include library reference editor_configs tests, copied) beside the gimpel overlay"; exit 2; }
# ⭐ AREA SMOKE MODE (the coo 2026-10-03, on hq_snobol4's report: gimpel's area smoke selected 79 of 145 and ran 0, exiting 0, because the
# harness graded the package's ALL.sno container, which still holds the 120 entries cut before CEO-1269 while ALL.csv names the 145
# drivers this board grades): S4E_AREA_SMOKE_ENTRIES="agt_driver ai_driver ..." -- ALL.csv entry keys -- grades those drivers exactly as
# the board does (scorecard_snobol4.sh, the overlay, the pins, ALL.mask) and nothing else: no census, no progress row, no score row; one
# line per key, GIMPEL_SMOKE_ENTRY <key> m3=<V> m4=<V>, then exit 0. --force because a smoke is a correctness read, never a timing one.
SMOKE_KEYS="${S4E_AREA_SMOKE_ENTRIES:-}"
SMOKE_FORCE=""; [ -n "$SMOKE_KEYS" ] && SMOKE_FORCE="--force"
# ⭐ THE ROUND ROBIN'S SEAM (ceo CEO-1802/1805/1806): under S4E_CHUNK the scorecard grades only the part's drivers (its SC_ONLY_PROGRAMS filter, the smoke's
# own road), appends their rows under their libraries' names as it always does, and this runner writes no suite row (rr_end below)
. "$HERE/lib_rr.sh" && rr_load "$CORPUS_REAL/packages/snobol4/gimpel" || exit 2
rr_selected && [ -z "$SMOKE_KEYS" ] && SMOKE_KEYS="" && export SC_RR_ONLY="$(printf '%s ' ${RR_SEL:-})"
SC_ONLY_PROGRAMS="${SMOKE_KEYS:-${SC_RR_ONLY:-}}" CORPUS="$W/corpus" bash "$HERE/scorecard_snobol4.sh" run --suites gimpel --out "$W" $SMOKE_FORCE > "$W/run.log" 2>&1
rc=$?
TSV="$W/results.tsv"
[ -f "$TSV" ] || { echo "⛔ REFUSE(rc=2): scorecard_snobol4.sh produced no results.tsv (rc=$rc) -- run.log:"; cat "$W/run.log"; exit 2; }
TOTAL=$(awk -F'\t' 'END{print NR}' "$TSV")
# ⛔⭐ A RUN THAT GRADED NOTHING IS UNMEASURED, NEVER A BOARD OF ZEROS (found 2026-09-04 while curing the
# vendored-dir write, hq_T). scorecard_snobol4.sh TRUNCATES results.tsv before it does anything else, so any
# refusal AFTER that point -- and the common one is its own board-contention guard, "another SNOBOL4 board is
# already running on this box", which is a REFUSAL and not a failure -- leaves an EMPTY results.tsv behind.
# This runner then printed `GIMPEL_BOARD total=0 scored=0 ... m3_fail=0 m4_fail=0` and, because the final
# verdict is `[ "$M3F" = 0 ] && [ "$M4F" = 0 ]`, EXITED 0. A perfect green board over an empty population, on a
# run that never started. ⛔ That is the absent-oracle false-green in its purest form: zero failures because
# zero programs, indistinguishable in the exit code from 144 passes.
if [ "$TOTAL" -eq 0 ]; then
    echo "⛔ REFUSE(rc=2): the gimpel run graded ZERO programs -- results.tsv is empty, so this is UNMEASURED, not clean."
    echo "   scorecard_snobol4.sh exited rc=$rc; its own log follows (the usual cause is the board-contention"
    echo "   guard: another SNOBOL4 board is running on this box, which is a refusal to measure under contention,"
    echo "   not a failure -- wait for it and re-run):"
    sed 's/^/     /' "$W/run.log"
    exit 2
fi
if rr_selected && [ -z "$SMOKE_KEYS" ]; then
    [ "$VEND_BEFORE" = "$(_vend_fingerprint)" ] || { echo "⛔ REFUSE(rc=2): the part's run changed the vendored gimpel directory"; exit 2; }
    rr_end "$ROWKEY"; exit 0   # the scorecard appended the part's rows under their libraries' names (progress_append_results_tsv); no suite row (CEO-1802)
fi
if [ -n "$SMOKE_KEYS" ]; then
    [ "$VEND_BEFORE" = "$(_vend_fingerprint)" ] || { echo "⛔ REFUSE(rc=2): the smoke run changed the vendored gimpel directory"; exit 2; }
    _kind() { case "$1" in PASS) echo PASS ;; TIMEOUT) echo HANG ;; SIG*) echo CRASH ;; ASM_FAIL) echo NONE ;; *_REFUSED) echo REFUSE ;; *) echo FAIL ;; esac; }
    for k in $SMOKE_KEYS; do
        row="$(awk -F'\t' -v k="$k.sno" '{ n = $2; sub(/.*\//, "", n) } n == k { print $3 "\t" $4; exit }' "$TSV")"
        if [ -z "$row" ]; then echo "GIMPEL_SMOKE_ENTRY $k NOT_RUN-GRADED (no such driver in the board's list)"
        elif [ "${row%%$'\t'*}" = ORACLE_FAIL ]; then echo "GIMPEL_SMOKE_ENTRY $k NOT_RUN-GRADED (the oracle answered nothing: OUTSIDE)"
        else echo "GIMPEL_SMOKE_ENTRY $k m3=$(_kind "${row%%$'\t'*}") m4=$(_kind "${row#*$'\t'}")"; fi
    done
    exit 0
fi
UNSCR=$(awk -F'\t' '$3=="ORACLE_FAIL"' "$TSV" | wc -l)
M3P=$(awk -F'\t' '$3!="ORACLE_FAIL" && $3=="PASS"' "$TSV" | wc -l)
M3F=$(awk -F'\t' '$3!="ORACLE_FAIL" && $3!="PASS"' "$TSV" | wc -l)
M4P=$(awk -F'\t' '$3!="ORACLE_FAIL" && $4=="PASS"' "$TSV" | wc -l)
M4F=$(awk -F'\t' '$3!="ORACLE_FAIL" && $4!="PASS"' "$TSV" | wc -l)
[ "$PORT" = 1 ] && M4F=0   # a port has no mode 4
SCRIP_HASH="$(git -C "$SD" rev-parse --short HEAD 2>/dev/null || echo '?')"
TREE_LABEL="SCRIP $SCRIP_HASH"; [ "$PORT" = 1 ] && TREE_LABEL="engine $(one_runner_port_tree)"
CORP_HASH="$(git -C "$ROOT/corpus" rev-parse --short HEAD 2>/dev/null || echo '?')"
SCORED=$((TOTAL-UNSCR))
# ⛔⭐ A ZERO DENOMINATOR IS A REFUSAL, NEVER A STEADY STATE (RULES.md, the denominator law) -- AND THIS SCRIPT
# USED TO PRINT IT AS A GREEN BOARD. The verdict below is `[ "$M3F" = 0 ] && [ "$M4F" = 0 ]`, which is
# VACUOUSLY TRUE over an empty results.tsv: `GIMPEL_BOARD total=0 ... m3_fail=0 m4_fail=0` and rc=0. MEASURED
# 2026-09-04 by hq_C: running this suite CONCURRENTLY with test_corpus_snobol4.sh produced exactly that --
# scorecard_snobol4.sh's own concurrent-board registry (sc_peers, the thing that exists to refuse a contended
# measurement) declined to grade, left an empty results.tsv, and this wrapper turned that refusal into a
# PASS. The same suite run solo, same binary, same minute, read total=144 scored=126. A board that reports
# "no failures" because it graded nothing is the false green the registry was built to prevent, arriving
# through the one path the registry cannot see: its own caller's arithmetic.
# ⛔⭐ TWO HQs CURED THE total=0 DEFECT INDEPENDENTLY, WITHIN ONE HOUR, IN THIS FILE -- hq_T (7b18a3c52, hit via
# the vendored-dir overlay row) and hq_C (cfde5756f, hit by running gimpel concurrently with the rungs board).
# Both cures were right and the merge left the tree carrying BOTH, one above and one here. Consolidated into
# the single early refusal above, which fires before the counters and prints the scorecard's own log.
# ⭐ THE COINCIDENCE IS THE LESSON, not the duplication: this is the one-cure-many-copies class running FORWARD
# for once -- the same defect, found twice the same hour by two people who never spoke, because a concurrent
# board makes it reproducible on demand. A defect that two independent lanes hit in an hour was never rare; it
# was only invisible, and it will be there again in the next wrapper nobody has run two of yet.
# ⛔ THIS ARM IS hq_C's AND IT IS NOT A DUPLICATE: total=0 is "nothing was graded"; scored=0 is "every entry was
# graded and the ORACLE failed on all of them" -- a different fact, about a different component, with a
# different cure. Keeping only the first would have re-opened half the hole.
[ "$SCORED" -gt 0 ] || { echo "⛔ REFUSE(rc=2): every one of the $TOTAL entries is ORACLE_FAIL (scored=0) -- the oracle, not SCRIP, is what this run measured. Preflight the oracle before trusting any verdict."; exit 2; }
VEND_AFTER="$(_vend_fingerprint)"
if [ "$VEND_BEFORE" != "$VEND_AFTER" ]; then
    echo "⛔ REFUSE(rc=2): THIS RUN CHANGED THE VENDORED DIRECTORY IT WAS GRADING -- the scratch overlay did not"
    echo "   contain a write. The board below is NOT trustworthy (a grader that writes into its own fixtures may"
    echo "   have graded a file it had already altered), and the tree is now dirty, which correctly blocks the"
    echo "   leaderboard write. What changed:"
    diff <(printf '%s\n' "$VEND_BEFORE") <(printf '%s\n' "$VEND_AFTER") | sed 's/^/     /' | head -20
    echo "   Cure: remove the stray file, then report this WITH the diff above -- it is the first mechanical"
    echo "   evidence of an escape that two people have witnessed and neither could reproduce."
    exit 2
fi
# ⭐ THE SPITBOL BASELINE (Lon 2026-09-08, row snobol4-every-package-runner-states-its-row-over-the-spitbol-
# baseline-measured-live; test_snoflake_suite.sh is the shape). A program the ONE ORACLE cannot answer is
# OUTSIDE the baseline and out of the denominator. This runner ALREADY measures that set live -- it is exactly
# the ORACLE_FAIL rows the scorecard writes, which is why SCORED is TOTAL minus UNSCR above -- so nothing new
# is computed here. What is added is the record beside the package and a live cross-check that says STALE or
# UNRECORDED aloud, so a written ruling cannot drift from what sbl does today.
# ⛔ THE MIRROR CHECK IS DELIBERATELY ABSENT HERE, unlike the other three runners. Gimpel's UNGRADABLE.tsv is a
# SUPERSET, not a mirror: it holds 163 rows -- the 146 vendored library sources that are not programs plus these
# 17 drivers -- and shipped 290 = graded 127 + ungradable 163 already balances. Demanding a row-for-row mirror
# here would demand double-counting. The record and the bucket are not the same set in every package.
# ⛔⭐ THE PROGRAM IS THE LIBRARY; THE DRIVER IS HOW IT IS GRADED (ceo CEO-1269, CEO-700 applied; coo 2026-09-25, row
# instruments-the-arizona-jcon-and-gimpel-runners-grade-a-library-through-its-driver-...; hq_snobol4's re-derivation of this
# package's shipped population moved into it). The scorecard grades the 144 *_driver.sno and each verdict is its library's:
# SHIPPED_LIBS counts every NAME.sno the package ships except ALL.* and the drivers (lib_inventory.sh's census, the same
# exclusions), a library with no driver stays in the denominator as owed (UNGRADED.tsv NEEDS_DRIVER) and is named below, and
# a driver row whose library is not shipped refuses -- a vehicle with nothing to carry. The progress rows land under the
# library's name (util_progress_append.py results-tsv). Measured at the ruling: 148 libraries, 144 drivers, four without one.
GPKG="$CORPUS_REAL/packages/snobol4/gimpel"
# ⛔ A LIBRARY SHIPS AS name.inc, A PROGRAM AS name.spt (Lon 2026-09-27, "Use the *.inc names exclusively" -- Catspaw's SPITBOL form under
# lower-case names, CEO-1319; the .sno/.INC spellings of the day before, CEO-1315, still read), and its driver is name_driver.sno. The two
# stems the form ships twice, as a program and the library it includes (infinip, rseason), keep the _lib convention: x_driver drives x.spt
# and x_lib_driver drives x.inc. _lib_of names the file a driver carries; a library no driver carries is NO DRIVER.
_lib_of() { local s="$CORPUS_REAL/${1%_driver.sno}" e
    for e in spt inc sno INC; do [ -f "$s.$e" ] && { printf '%s' "${s##*/}.$e"; return 0; }; done
    case "$s" in *_lib) s="${s%_lib}"; [ -f "$s.inc" ] && { printf '%s' "${s##*/}.inc"; return 0; } ;; esac
    return 1; }
DRIVEN=" $(cd "$GPKG" 2>/dev/null && for _d in *_driver.sno; do [ -f "$_d" ] && _lib_of "packages/snobol4/gimpel/$_d" && printf ' '; done) "
SHIPPED_LIBS=0; NODRV_NAMES=""
while IFS= read -r _f; do
    _b="${_f##*/}"; case "$_b" in ALL.*|*_driver.sno) continue ;; esac
    SHIPPED_LIBS=$((SHIPPED_LIBS+1)); case "$DRIVEN" in *" $_b "*) ;; *) NODRV_NAMES="$NODRV_NAMES ${_b%.*}" ;; esac
done < <(find "$GPKG" -type f \( -name '*.inc' -o -name '*.spt' -o -name '*.sno' -o -name '*.INC' \) ! -path '*.fixtures/*' 2>/dev/null | LC_ALL=C sort)
ORPHAN_DRV="$(awk -F'\t' '{print $2}' "$TSV" | while IFS= read -r _p; do _lib_of "$_p" > /dev/null || printf ' %s' "${_p##*/}"; done)"
LIBMAP="$(awk -F'\t' '{print $2}' "$TSV" | while IFS= read -r _p; do _l="$(_lib_of "$_p")" && printf '%s\t%s\n' "$_p" "$_l"; done)"
[ -z "$ORPHAN_DRV" ] || { echo "⛔ REFUSE(rc=2): graded driver(s) whose library the package does not ship:$ORPHAN_DRV -- a vehicle with nothing to carry (CEO-1269)"; exit 2; }
[ "$SHIPPED_LIBS" -ge "$TOTAL" ] || { echo "⛔ REFUSE(rc=2): $TOTAL graded drivers against $SHIPPED_LIBS shipped libraries -- more vehicles than programs, so the census and the board disagree (CEO-1269)"; exit 2; }
OUTSIDE_TSV="$CORPUS_REAL/packages/snobol4/gimpel/OUTSIDE_SPITBOL_BASELINE.tsv"
BOTH=$(awk -F'\t' -v port="$PORT" '$3!="ORACLE_FAIL" && $3=="PASS" && ($4=="PASS" || port==1)' "$TSV" | wc -l)   # a port's AND is its one mode
if [ "$UNSCR" -gt 0 ]; then
    echo "OUTSIDE-SPITBOL-BASELINE ($UNSCR; the oracle answered none of these this run):"
    awk -F'\t' '$3=="ORACLE_FAIL"{sub(/.*\//,"",$2); printf "OUTSIDE\t%s\n", $2}' "$TSV"
fi
if [ -f "$OUTSIDE_TSV" ]; then
    rec="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{sub(/\.sno$/,"",$1); print $1}' "$OUTSIDE_TSV" | sort)"
    live="$(awk -F'\t' '$3=="ORACLE_FAIL"{sub(/.*\//,"",$2); sub(/\.sno$/,"",$2); print $2}' "$TSV" | sort)"
    stale="$(comm -23 <(printf '%s\n' "$rec") <(printf '%s\n' "$live") | tr '\n' ' ')"
    unrec="$(comm -13 <(printf '%s\n' "$rec") <(printf '%s\n' "$live") | tr '\n' ' ')"
    [ -n "$stale" ] && echo "⚠ OUTSIDE_SPITBOL_BASELINE.tsv STALE -- recorded as unanswerable by the oracle, but it answered this run: $stale"
    [ -n "$unrec" ] && echo "⚠ OUTSIDE_SPITBOL_BASELINE.tsv UNRECORDED -- the oracle answers none of these and the record does not name them; record each with its error and a source check: $unrec"
    [ -z "$stale$unrec" ] && echo "OUTSIDE_SPITBOL_BASELINE.tsv agrees with the measured outside set ($UNSCR)"
else echo "⚠ no OUTSIDE_SPITBOL_BASELINE.tsv beside the suite -- the outside-baseline set above is measured, not yet recorded"; fi
echo "GIMPEL_LIBRARIES shipped=$SHIPPED_LIBS graded_through_a_driver=$TOTAL no_driver=$(printf '%s' "$NODRV_NAMES" | wc -w) (CEO-1269: the program is the library, its verdict is its driver's)"
[ -n "$NODRV_NAMES" ] && echo "NO DRIVER (owed, UNGRADED.tsv NEEDS_DRIVER -- in the denominator, a non-pass):$NODRV_NAMES"
echo "GIMPEL_BOARD total=$TOTAL scored=$SCORED unscr=$UNSCR m3_pass=$M3P m3_fail=$M3F m4_pass=$M4P m4_fail=$M4F -- $TREE_LABEL corpus $CORP_HASH RT_OPT=-O0 oracle=sbl-bf (via scorecard_snobol4.sh --suites gimpel)"
awk -F'\t' 'NR==FNR{lib[$1]=$2; next} $3=="ORACLE_FAIL"{printf "  UNSCR  %s (driver %s)  %s\n", lib[$2], $2, $7}' <(printf '%s\n' "$LIBMAP") "$TSV"
awk -F'\t' -v port="$PORT" 'NR==FNR{lib[$1]=$2; next} $3!="ORACLE_FAIL" && ($3!="PASS" || ($4!="PASS" && port!=1)){printf "  RED    %s (driver %s)  m3=%s m4=%s%s\n", lib[$2], $2, $3, $4, ($7!="" ? "  "$7 : "")}' <(printf '%s\n' "$LIBMAP") "$TSV"
# ⭐ THE PACKAGE LOCKDOWN (Lon 2026-09-06), through the SHARED body -- never a second copy of the arithmetic.
#
# ⛔⭐⭐ WHAT USED TO BE HERE COMPUTED `ungraded` AS A TAUTOLOGY, AND THE LOCKDOWN'S OWN CRITERION IS
# `ungraded=0` (hq_P 2026-09-06, proven by substitution, FINDING-2026-09-06-hq_P-the-gimpel-inventorys-
# ungraded-bucket-is-identically-zero-by-construction.md). The four lines were:
#     libmods=$((real_shipped - TOTAL)) ; ungradable=$((libmods + UNSCR))
#     ungraded=$((real_shipped - SCORED - ungradable))     # with SCORED = TOTAL - UNSCR
# Substitute and every term cancels: real_shipped - (TOTAL-UNSCR) - (real_shipped-TOTAL) - UNSCR == 0.
# ⛔ NOT "usually zero" and not "zero today" -- ZERO FOR EVERY POSSIBLE INPUT. Measured over eight arms
# including a board that graded 1 driver of 144 (ungradable 163 -> 288, ungraded still 0), an oracle that
# failed on all 144, and a shipped count that tripled overnight. The line printed `ungraded=0` for all of
# them, which is the same string it prints when the lockdown is genuinely finished.
# ⭐ AND THE REACHABLE HARM IS THE SECOND LINE, NOT THE FOURTH: `libmods = real_shipped - TOTAL` DEFINES
# whatever the board did not grade as a library module. scorecard_snobol4.sh has a documented
# concurrent-board guard that reduces TOTAL, and the only floor below is `SCORED >= 1` -- so a partial
# board silently RECLASSIFIES real ungraded drivers as ungradable-by-design library modules, and the
# inventory reports the lockdown met while it happened. An instrument whose sensitivity is below the
# effect it was built to detect is not a weak test; it is a test that cannot fail.
#
# ⭐ THE CURE IS NOT A BETTER FORMULA HERE -- it is to stop having a formula here. lib_inventory.sh already
# carries the sum check that refuses when the buckets do not cover `shipped`, the closed reason-code
# vocabulary, and the arm that refuses an UNGRADABLE naming OUR OWN compiler. Wiring to it turns a silent
# `ungraded=0` into a loud, per-entry, actionable debt naming the 163 programs in no bucket.
# ⛔ IT WILL REFUSE UNTIL THE SIDECARS ARE AUTHORED, AND THAT IS THE POINT, NOT A REGRESSION: the refusal
# is rc=2 on the INVENTORY only -- the board line and this gate's own verdict are untouched below.
# The sidecars are row snobol4-gimpel-inventory-sidecars-name-the-oracles-own-reason-for-all-163 (seat02).
. "$HERE/lib_inventory.sh"
INV_PACKAGE=gimpel; INV_DIR="$CORPUS_REAL/packages/snobol4/gimpel"; INV_EXT=".inc .spt .sno .INC"
# graded_narrow=0, and CONFIRMED rather than assumed (ceo CEO-307 (3) asked for exactly this): this runner
# grades through scorecard_snobol4.sh's grade(), which is `cmp -s` against the .ref pin and then against the
# live oracle -- full stream equality, no error-number arm anywhere in the path. ⛔ THE ERROR-NUMBER ARM IS
# THE SNOFLAKE RUNNER'S, NOT THIS ONE'S (test_snoflake_suite.sh:133 oracle_equal, deliberate and documented);
# that is where gimpel's topological-sort scored PASS on one integer, because snoflake_suite/topological-sort.sno
# is graded by THAT runner over gimpel/TSORT.INC. Two runners, two comparisons, one package name.
# ⛔⭐ CAPTURED, NOT PRINTED-AND-DISCARDED (coo 2026-09-08, measured on three seats' runs at once -- hq_C's 105,
# the cto's 107 and the coo's own audit). This line called inventory_line for its STDOUT and threw it away, while
# the write below splices ${INV_LINE:+...} -- a variable this file never assigns. So the vendor text carried no
# PACKAGE_INVENTORY clause, util_score_row.py REFUSED rc=2 on every run, and gimpel's row could only ever be set
# BY HAND. ⭐ THE TELL WORTH KEEPING: `${VAR:+...}` is SILENT on an unset variable by design, so the one construct
# that would have named the missing piece is the construct that guarantees nothing is named. The refusal that did
# fire named the missing CLAUSE, one level away from the missing ASSIGNMENT, and three seats read past it.
# Both sibling runners already had these two lines (test_snobol4_csnobol4_suite.sh:304, test_snoflake_suite.sh:384).
INV_LINE="$(inventory_line "$SCORED" 0)"
if [ -n "$INV_LINE" ]; then echo "$INV_LINE"; else echo "⚠ inventory refused (above) -- the board line still stands; the inventory does not" >&2; fi
# ⛔⭐ POPULATION FLOOR (row every-board-wrapper-refuses-on-a-zero-population-instead-of-passing-
# vacuously, hq_T 2026-09-04): WITNESSED TWICE IN ONE HOUR on this exact file -- the concurrent-board
# registry in scorecard_snobol4.sh declined (rc=$rc, an UPSTREAM refusal), which truncates results.tsv
# to empty and leaves it there; `-f "$TSV"` above only proves the FILE exists, not that it holds any
# rows, so TOTAL/SCORED/M3F/M4F all read 0 and the line below used to read that as clean. NO LOGIC
# HERE: util_require_population.sh sources gate_floor from lib_gate.sh, the ONE authority.
"$HERE/util_require_population.sh" --gate test_snobol4_gimpel_suite "$SCORED" 1 "scored rows (total=$TOTAL unscr=$UNSCR, scorecard rc=$rc)" || exit 2
# ⭐ THE ROW, NAMING ITS OWN FRACTION (the shape test_snoflake_suite.sh uses). ⛔ BEFORE THIS THIS RUNNER WROTE
# NO ROW AT ALL -- not a suite row and not a SCORE.md cell -- so gimpel's reading on the board had only ever been
# set BY HAND, by the coo, from this runner's printed line. A number nobody's runner writes is a number nothing
# re-measures. The table's reading is the ceo-372 AND per program over the SPITBOL baseline.
# ⛔ CEO-749 SHAPE (row snobol4-four-package-rows-leave-their-outside-baseline-programs-out-of-the-denominator-ceo-749): the
# row reads PASS over SHIPPED ($TOTAL = the graded drivers plus the $UNSCR the oracle refuses), OUTSIDE=$UNSCR named and
# stamped through lib_outside_shape.sh -- the outside drivers stay in the denominator as debt to cure. Before this the
# row published $BOTH/$SCORED, the graded set only, and nothing in the verdict instrument could see the difference.
if [ "$PORT" = 1 ]; then echo "SCORE.md: the $(one_runner_engine) engine writes no SCRIP row -- its row is util_score_row.py from-progress --suite $ROWKEY (CEO-1822), graded in m3 alone"
    if [ -z "${GIMPEL_SUITE:-}" ]; then one_runner_port_publish "$ROWKEY"; else echo "SUITES.tsv: scratch suite $GIMPEL_SUITE -- not published (only the canonical suite publishes its row)"; fi
elif [ "$SCORED" -gt 0 ] && [ -z "${GIMPEL_SUITE:-}" ]; then
. "$HERE/lib_outside_shape.sh" || exit 2
# ⛔⭐ CEO-1286 (Lon 2026-09-26): the libraries NOT IN THE SPITBOL DIALECT (EXCLUDED.tsv, named by library; the live outside set names
# their drivers) leave the denominator of shipped libraries; the drivers the oracle refuses for any other cause stay as debt.
SUITE="$CORPUS_REAL/packages/snobol4/gimpel"
EXCL_D_N="$(excluded_in_outside "$SUITE" "$(awk -F'\t' '$3=="ORACLE_FAIL"{sub(/.*\//,"",$2); print $2}' "$TSV")")" || exit 2; DENOM=$((SHIPPED_LIBS - EXCL_D_N))
echo "EXCLUDED_NOT_SPITBOL_DIALECT=$EXCL_D_N of this run's outside set leave the denominator ($(excluded_names_count "$SUITE") named in $SUITE/EXCLUDED.tsv; Lon 2026-09-26, CEO-1286): pass over $DENOM"
_cc="${S4E_CRITERION_CHANGED:-}"
if [ -z "$_cc" ]; then
    # the denominator moved from the 144 drivers to the libraries they grade: stamped as CEO-1269's criterion change, not CEO-749's
    _prevt="$(awk -F'\t' '$1=="gimpel" {print $10; exit}' "$(. "$HERE/lib_suites_tsv.sh"; suites_tsv "${S4E_HOME:-$ROOT}")" 2>/dev/null)"
    if [ -n "$_prevt" ] && [ "$_prevt" != "$SHIPPED_LIBS" ] && [ "$_prevt" = "$TOTAL" ]; then
        _cc="$(date +%F):CEO-1269-the-program-is-the-library-graded-through-its-driver-shipped-counts-the-${SHIPPED_LIBS}-libraries-not-the-${TOTAL}-drivers-OUTSIDE=${UNSCR}-named-no-driver=$(printf '%s' "$NODRV_NAMES" | wc -w)-owed"
    else _cc="$(excluded_shape_stamp gimpel "$DENOM" "$UNSCR" "$EXCL_D_N")" || exit 2; fi
fi
python3 "$HERE/util_score_row.py" write --lang snobol4 --column vendor --suite gimpel --modes m3,m4 \
    ${_cc:+--criterion-changed "$_cc"} \
    --measurer "${S4E_SEAT:-}" --suite-pass "$BOTH" --suite-total "$DENOM" --excluded "$EXCL_D_N" \
    --text "gimpel both_modes_pass=$BOTH/$DENOM ($SHIPPED_LIBS shipped libraries minus EXCLUDED=$EXCL_D_N not in the SPITBOL dialect, EXCLUDED.tsv, CEO-1286), each graded through its driver (CEO-1269) · OUTSIDE=$UNSCR whose driver SPITBOL does not answer, named with the oracle's own error in OUTSIDE_SPITBOL_BASELINE.tsv, in the denominator (CEO-749) · no driver $(printf '%s' "$NODRV_NAMES" | wc -w), owed (NEEDS_DRIVER) · graded $BOTH/$SCORED · m3 $M3P/$SCORED · m4 $M4P/$SCORED (sbl -bf the one oracle)${INV_LINE:+ · $INV_LINE} (\`test_snobol4_gimpel_suite.sh\`)" \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
fi
[ "$M3F" = 0 ] && [ "$M4F" = 0 ]
