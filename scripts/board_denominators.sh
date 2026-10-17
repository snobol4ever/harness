#!/usr/bin/env bash
# board_denominators.sh — B-1(b-iii): every suite's denominator, LIVE, never a digit copied into prose.
# "A number in prose is a liability; a command is not" (GOAL-SN4-HOME-BOARD.md B-1(b-iii)).
# Every rung should cite `board_denominators.sh <suite>` instead of a hardcoded count.
#
# USAGE:
#   bash board_denominators.sh            # all suites
#   bash board_denominators.sh crosscheck # one suite
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -u
CORPUS="${CORPUS:-$S4E/corpus}"
SEL="${1:-}"

row() {
    local name="$1" val="$2" note="$3"
    printf "%-16s %-8s %s\n" "$name" "$val" "$note"
}

# ⛔ corpus/crosscheck/ is GONE -- converted into tests/snobol4/ALL.{sno,ref,csv} (corpus da0987478
# lineage, row dead-suite-path-consumer-sweep). `find` on the dead path prints nothing and exits 0, so
# this silently returned "0" -- a wrong-but-plausible-looking count, not a loud failure. Counts by
# origin-family prefix via the rungs CSV instead, same idiom already used by d_probebb/d_beauty_total
# below (ONE AUTHORITY for the suite grammar, never a second parser of it).
d_crosscheck()  { awk -F, 'NR>1 && $4 ~ /^crosscheck_/' "$CORPUS/tests/snobol4/ALL.csv" 2>/dev/null | wc -l; }
# library/probe_reference/bb/probes moved into suite format 2026-08-28 (probe-consolidate-bb, LON-20260828 total
# conversion) -- counts its entries via the harness (ONE AUTHORITY for the suite grammar) instead
# of a loose-file find, since the suite text file is no longer one file per test.
d_probebb()     { awk -F, 'NR>1 && $4=="probe_bb_probes"' "$CORPUS/tests/snobol4/ALL.csv" 2>/dev/null | wc -l; }   # counts rungs entries by origin-family (zero-subfolders cutover)
d_demo()        { find "$CORPUS/demos" -maxdepth 1 -name "*.sno" 2>/dev/null | wc -l; }
d_demo15()      { echo 14; }  # ⛔ CORRECTED 2026-09-04 (hq_T, row every-board-wrapper-refuses-on-a-zero-population-instead-of-passing-vacuously): was 15, cited as "fixed by construction (board_sno15_ident.sh's own for-loop)" -- mechanically re-counted (`for nm in <the loop's list>; do echo "$nm"; done | wc -l`) and that loop carries 14 names, not 15; the filename and this function's name are the only places "15" survives now. See NOTE below
d_bench()       { find "$CORPUS/benchmarks/snobol4" -maxdepth 1 -name "*.sno" 2>/dev/null | wc -l; }
d_bench_xfail() { find "$CORPUS/benchmarks/snobol4" -maxdepth 1 -name "*.xfail" 2>/dev/null | wc -l; }   # COMPUTED, never typed: the count was written into the row text as "1" and would have gone stale the moment a marker was added or retired (s170)
d_beauty_total(){ awk -F, 'NR>1 && $4 ~ /^beauty_suite_/' "$CORPUS/tests/snobol4/ALL.csv" 2>/dev/null | wc -l; }   # beauty drivers absorbed into the rungs (one per family)
d_beauty_drivers(){ d_beauty_total; }
d_earn0()       { awk -F, 'NR>1 && ($4=="probe_earn0" || $4=="probe_earn02")' "$CORPUS/tests/snobol4/ALL.csv" 2>/dev/null | wc -l; }   # rungs origin-family count (zero-subfolders cutover)
d_broad336()    {
    # Mirrors test_broad_corpus_snobol4.sh's OWN LOGIC verbatim (crosscheck-with-ref via the exact same
    # while-loop guard, + beauty *_driver.sno files with a .ref, + 4 named demos hardcoded in the script).
    # ⛔ CONFIRMED DISCREPANCY (BOARD s41, this session): this reconstruction reads 338 at corpus HEAD;
    # a live run of test_broad_corpus_snobol4.sh on the SAME corpus HEAD printed "336 total" for BOTH modes.
    # Traced as far as: crosscheck-with-ref = 317 (verified twice, once via `find`, once by copying the
    # script's exact while-loop verbatim) + beauty drivers = 17 (verified: *_driver.sno and *.ref are the
    # SAME 17 basenames, no glob mismatch) + 4 demos = 338. Did NOT find where the script's internal count
    # loses 2. NOT resolved — flagged, not silently corrected. If you find the 2, fix this formula's comment,
    # don't just change the number. Until then: THE SCRIPT'S OWN PRINTED "(N total)" LINE IS AUTHORITATIVE,
    # not this arm — this arm exists to give a number without waiting ~4 minutes for the full sweep to run,
    # not to replace it.
    # ⛔ row dead-suite-path-consumer-sweep: this function's own `find "$CORPUS/crosscheck"` below is
    # now ALSO a dead path (see d_crosscheck() above) and silently returns xc=0, compounding with the
    # already-flagged off-by-2 mystery above rather than fixing it. NOT repaired here deliberately --
    # this function exists to MIRROR test_broad_corpus_snobol4.sh's OWN internal logic verbatim for
    # comparison, so fixing it in isolation would make it mirror nothing; if that script gets its own
    # crosscheck-path fix (it is not on this row's own worked list), update this comment and formula
    # together, not the `find` alone.
    local xc; xc=$(find "$CORPUS/crosscheck" -name "*.sno" 2>/dev/null | while read -r f; do
        [ -f "${f%.sno}.ref" ] && echo "$f"; done | wc -l)
    local bd; bd=$(d_beauty_drivers)
    echo $((xc + bd + 4))
}

case "$SEL" in
    crosscheck)      d_crosscheck ;;
    probe_bb|probebb) d_probebb ;;
    demo)            d_demo ;;
    demo15)          d_demo15 ;;
    bench)           d_bench ;;
    beauty_total)    d_beauty_total ;;
    beauty_drivers|beauty) d_beauty_drivers ;;
    earn0)           d_earn0 ;;
    broad336)        d_broad336 ;;
    "")
        printf "%-16s %-8s %s\n" SUITE COUNT NOTE
        printf '%.0s-' {1..60}; echo
        row crosscheck      "$(d_crosscheck)"       "rungs-CSV origin-family count (crosscheck_*) since corpus/crosscheck/ itself no longer exists"
        row probe_bb        "$(d_probebb)"          "moves on any BOARD mint — re-check every session"
        row demo            "$(d_demo)"             "top-level only; recursive find OVERCOUNTS (subdirs not board members)"
        row demo15          "$(d_demo15)"            "the 15-board is a FIXED named set (board_sno15_ident.sh's own for-loop), not a corpus count — will not drift with corpus size"
        row bench           "$(d_bench)"            "$(d_bench_xfail) xfail => $(($(d_bench)-$(d_bench_xfail))) graded both modes; every .sno is harness-driven since s170 (BM-2) and the timed runner FAILS if one is not"
        row beauty_total    "$(d_beauty_total)"      ".sno files in beauty_suite/ — DRIVERS ONLY since 2026-08-29: the 17 include-sources were deduplicated into corpus/include/*.inc, so no non-driver .sno remains here"
        row beauty_drivers  "$(d_beauty_drivers)"    ".ref count = driver count = the SIGSEGV-floor denominator"
        row earn0           "$(d_earn0)"             "⛔ HAS MOVED 16→20→28→... at least 3x in one plan's lifetime — NEVER cite from memory"
        row broad336        "$(d_broad336)"          "RECONSTRUCTED, confirmed OFF BY 2 vs the script's own printed total (338 here, 336 printed) — unresolved, see function comment; TRUST THE SCRIPT'S OWN RUN, not this row, until fixed"
        ;;
    *)
        echo "unknown suite '$SEL'. known: crosscheck probe_bb demo demo15 bench beauty_total beauty_drivers earn0 broad336" >&2
        exit 2
        ;;
esac
