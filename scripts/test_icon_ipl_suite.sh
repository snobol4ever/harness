#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" || exit 2
# ⛔ THE INSTRUMENTATION SWITCH (--stlimit, which carries the call/return hooks Icon &trace rides) IS EACH PROGRAM'S OWN compile_args DECLARATION, read per program below (clause 8 (f), CEO-1281): this runner exported SCRIP_SNO_STMTKW=1 for every program until 2026-09-26
# test_icon_ipl_suite.sh -- grades corpus/packages/icon/ipl: the vendored Icon Program Library (every .icn
# under gprogs/procs/incl/gincl/progs/gprocs -- COUNT IT, never quote a remembered figure:
#   find corpus/packages/icon/ipl -name '*.icn' | wc -l
# ⛔⭐ THE POPULATION IS 851, AND THIS HEADER WAS "CURED" TO 852 ON 2026-09-05 BY hq_I -- WRONGLY, IN THE
# OTHER DIRECTION. The prose was right and the instrument was wrong. `find -name '*.icn'` returned 852
# because it counted `ALL.icn`, OUR OWN generated container (corpus `3b3b5b874`, landed the same day), not a
# vendored program. ⭐ A STRUCTURAL COUNT IS ONLY AS RIGHT AS THE POPULATION IT WALKS: that find answers
# "how many .icn files are under this directory", never "how many vendored programs are here", and it will
# absorb anything we drop into the package without saying so. I trusted "the runner computes it structurally"
# over a number a human had written down, and that heuristic is what carried the error outward into SCORE.md,
# this header, and my own goal cursor. The accounting that settles it is the package's own and it is exact:
# ALL.csv 78 entries + ALL.excluded.txt 773 named exclusions = 851. The runner REFUSES below if that identity
# ever breaks, so the two instruments in this package can no longer disagree in silence. That is RULES.md
# TRANSCRIPTION IS WHERE PROVENANCE DIES, committed
# inside the very script that measures the thing correctly) -- a REAL upstream code library, not a test
# suite: it ships ZERO .ref reference outputs (confirmed: `find $PKG -iname '*.ref'` -> 0 files, every
# run re-confirms this structurally rather than assuming it). Task icon-ipl-runner-and-denominator
# (hq_T mint, 2026-09-03): "a package suite with no runner is not a suite, it is a directory."
#
# TWO GRADING TIERS, NEVER CONFLATED (the task's own words: "Compile-graded-only entries must be
# COUNTED AS SUCH and never folded into a run-graded pass rate"):
#   compile-graded -- ./scrip --compile succeeds, OR (for a file with no `procedure main`) fails with
#                      EXACTLY the expected "no entry point" signal after real, non-trivial emission --
#                      i.e. the file's own content parsed/lowered/emitted cleanly; it is a library
#                      module, not a program, and that is not a defect.
#   run-graded     -- diffs execution output against a NAME.ref oracle ref, both modes, independently
#                      (RUN_PASS/RUN_FAIL/RUN_CRASH/RUN_HANG). The population is counted structurally
#                      (progs/*.ref files, cut by util_cut_icon_ipl_refs.sh from the real Icon oracle --
#                      see that script's own header for the classification discipline: only a
#                      deterministic, input-free, non-usage-banner clean run gets pinned), not hardcoded,
#                      so this self-corrects the day the population changes.
#
# ⛔⛔ EXECUTION (both m3 --run and m4's compiled binary) GOES THROUGH lib_icon_ipl_isolation.sh, NEVER
# a bare `cd $PKG/progs && ...`: IPL ships programs that mutate their own cwd as documented behavior
# (progs/upper.icn, progs/lower.icn rename every file in cwd) -- see that lib's header for the corpus-
# corruption incident this was built from. COMPILE (`--compile` emitting .s) does not execute the
# target program's own logic, so it stays unisolated same as before; only actually RUNNING one -- as the
# source program (m3) or as a linked binary (m4) -- carries the hazard.
#
# CLASSES THE REDS FALL INTO (grouped by directly-observed signal, same discipline as
# FINDING-2026-09-03-seat01-icon-arizona-...-nine-vendoring-gaps...: group by shared signature, never
# force one bucket; a genuinely new shape is reported by name, not absorbed):
#   nomain_ok -- no `procedure main`; sole failure is the expected mode-4-driver "main BB graph not
#                found" signal AFTER a non-trivial .s emission. Compile-graded PASS (library module).
#   linkgap   -- "icon: link: cannot open X (linked from Y)".
#                ⛔⭐ THE PARAGRAPH THAT STOOD HERE IS RETIRED AND IT WAS THE MOST MISLEADING KIND OF
#                STALE: it said SCRIP's resolver is SINGLE-DIRECTORY-ONLY with "no ICONPATH/LPATH support
#                anywhere in the tree (checked: zero hits)" -- a measurement that was true when written
#                and became false on 2026-09-05, when icn_link_open was taught to read IPATH and then
#                ICONPATH (SCRIP 55fae9091, hq_I, with hq_B's go-ahead). That cure moved linkgap from 354
#                of 415 compile failures to 2. ⭐ IT SURVIVED AS A JUSTIFICATION, WHICH IS WHERE A
#                RETRACTED CLAIM LIVES LONGEST (hq_T's rule): nobody re-reads the reason a bucket exists,
#                so the sentence explaining the gap outlived the gap by a day and was still being quoted.
#                hq_U lost twenty minutes to its neighbour this day -- running an ipl program from progs/
#                WITHOUT the path prints "cannot open random.icn" and reads exactly like a compiler
#                defect, so a census taken without ICONPATH counts the link failure and never sees the
#                real cause underneath it. Set the path the way lib_icon_ipl_isolation.sh does. IPL's own
#                progs/procs/gprocs/incl/gincl split is upstream's NORMAL organization -- a progs/
#                file linking a procs/ helper is the library working as designed, not a corpus defect.
#                ⭐ WHAT IS LEFT, MEASURED (hq_icon on SCRIP f7c43e4a2, re-read by the coo on a58f8e68c,
#                2026-09-27): 3 files -- procs/vhttp, progs/htget, and progs/weblinks through vhttp --
#                each on `link cfunc`, the IPL's dynamic-loading C-function library (ipl/cfuncs, loaded
#                with loadfunc), which the Icon distribution ships (/home/resources/icon-master/ipl/
#                cfuncs/cfunc.icn) and the corpus does not vendor: the NEEDS_VENDORED_SOURCE class of
#                Zona's cfuncs/extlvals rows, row icon-vendor-ipl-cfuncs-so-zona-and-jcon-reach-their-
#                full-denominators. The three are printed by name below with or without -v, as parseerr's
#                are; the "single-directory resolver, hundreds of cross-links" reason printed there until
#                this date was the retired paragraph above, still being quoted.
#   parseerr  -- "parse error" on stdout/stderr -- genuine frontend rejection.
#   timeout   -- exceeded $TIMEOUT.
#   other     -- any other non-zero, non-timeout signal. Reported individually (name + first stderr
#                line) so nothing new is ever silently folded into an existing bucket.
#
# SCORE.md: this suite is compile-graded-only (run_graded=0, honestly, because no oracle exists) --
# per the task's own warning, its numbers are written as bare key=value pairs, NEVER as a bald N-over-the-population
# fraction, so `util_score_row.py`'s cell_fractions() (which scores the ONE LEADERBOARD's overall
# per-language % from every bare \d+/\d+ it finds) cannot mistake "compiles" for "verified correct".
# Same convention GNU_SUITE already set: `lib=56` is a bare count, never `56/62`, for exactly this
# reason (test_prolog_gnu_suite.sh's own comment block explains it at the OK/LIB split).
#
# Usage: bash ../harness/scripts/test_icon_ipl_suite.sh [-v]   (-v prints every file's classification inline)
set -uo pipefail
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export TIMEOUT_RETRY="${TIMEOUT_RETRY:-$HERE/util_timeout_retry.sh}"   # a graded run's timeout (CEO-1335): a timeout under load is retried once, util_timeout_retry.sh
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
PKG="$S4E/corpus/packages/icon/ipl"
TIMEOUT="${IPL_SUITE_TIMEOUT:-30}"
# ⛔⭐ RAISED FROM 8 TO 30 (hq_icon, 2026-09-23), measured, not guessed: ibrow and vnq were reading RUN_HANG
# at 8s while both are CORRECT and byte-identical to their .ref -- ibrow completes in ~8.5s, vnq (92 real
# n-queens solutions, genuinely compute-heavy backtracking) in ~24s. An 8s ceiling was tighter than either
# program's real, deterministic runtime, so it was misclassifying two passing programs as hangs rather than
# catching an actual one. 30s covers both with headroom and still catches a true hang an order of magnitude
# faster than a real one would need to run. Genuine hangs/crashes in this suite (fileprnt, unitgenr) are
# unaffected by this -- they are real defects with their own findings, not timeout artifacts.
# ⛔⭐ THE COMPILE TIER MUST SEE THE LIBRARY'S OWN SHAPE, AND UNTIL 2026-09-05 IT DID NOT (hq_I).
# lib_icon_ipl_isolation.sh has always exported ICONPATH for the RUN tier, but the COMPILE tier below
# invoked scrip with no path at all, so a progs/ program linking a procs/ helper could only ever fail --
# and it did, 354 times, which was 85% of every IPL compile failure and 41% of the whole package. The
# resolver was single-directory-only (cured in icon_driver.c the same sitting); this is the other half,
# and neither half does anything alone. Exported once here so both tiers agree on the search path.
IPL_PATH="$PKG/procs:$PKG/gprocs:$PKG/progs:$PKG/incl:$PKG/gincl"   # libraries before programs: lib_icon_ipl_isolation.sh says why
export ICONPATH="${ICONPATH:-$IPL_PATH}"
VERBOSE=0; [ "${1:-}" = "-v" ] && VERBOSE=1
# ⭐ AREA SMOKE MODE (the coo 2026-10-02, row instruments-the-area-smoke-grades-ipl-entries-without-their-sidecars-and-reads-nine-false-
# reds): S4E_AREA_SMOKE_ENTRIES="progs/puzz gprogs/webimage ..." -- ALL.csv entry keys -- grades those programs exactly as the board does
# (this loop, its sidecars, its isolation) and nothing else: no population identity check, no progress row, no score row; one line per
# key, IPL_SMOKE_ENTRY <key> m3=<V> m4=<V>, then exit 0. The harness smoke delegates the ipl table here because ALL.icn/ALL.ref is
# consumed by no runner (see the progress note below) and grading it read nine false reds on 2026-10-02 (the cfo's area smoke).
SMOKE_KEYS="${S4E_AREA_SMOKE_ENTRIES:-}"
smoke_wants() { [ -z "$SMOKE_KEYS" ] || case " $SMOKE_KEYS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
declare -A SMOKE_V=()

[ -d "$PKG" ]   || { echo "⛔ GATE REFUSES: corpus subtree missing: $PKG" >&2; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ GATE REFUSES: scrip not built at $SCRIP" >&2; exit 2; }
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). The line above proves a binary EXISTS; this one proves it is the binary this
# tree describes. ceo's witness, twice on 2026-09-04: a 10:57 binary graded at 14:03 read RED, then GREEN after
# an incremental make -- a vendor board is exactly where that is least visible, because a plausible all-FAIL
# table is this class's normal output. NO LOGIC HERE: util_require_fresh.sh sources gate_require_fresh from
# lib_gate.sh, the ONE authority (hq_B 4c7253e99) -- never a second copy of the staleness rule.
"$HERE/util_require_fresh.sh" --gate test_icon_ipl_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
# ⛔⭐ THE BINARY MOVED UNDER THIS BOARD (ceo CEO-524 (1), wired by the coo 2026-09-10 as THE ONE RUNNER).
# The line above proves the binary is CURRENT AT THE START. It cannot see a swap that happens while the board is
# still grading, and the dirty guard downstream reads the tree at WRITE time -- so hq_R's board straddled a binary
# swap and published m3 635/759 into SCORE.md with a CLEAN stamp while the correct 756/759 was refused as dirty.
# ⛔ gate_bin_watch/gate_bin_unmoved ALREADY EXISTED for exactly this (lib_gate.sh, hoisted by hq_S 2026-09-06 out
# of test_corpus_snobol4.sh) AND NO BOARD CALLED THEM -- the instrument was built, hoisted, documented and never
# wired, which is the failure class it was written to catch, one level up. Both artifacts are watched because
# ./scrip is a ~40 KB driver and the emitter lives in the .so: a scrip-only fingerprint is vacuous exactly when an
# emitter change is the thing that moved.
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "⛔ REFUSED TO GRADE rc=2: lib_gate.sh unloadable -- this board cannot tell whether its binary moves under it" >&2; exit 2; }
GATE_NAME=test_icon_ipl_suite gate_bin_watch "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so"
# ⛔⭐ THE TREE MOVED UNDER THIS BOARD, and the stamp that names the tree this row actually graded
# (coo 2026-09-10, COO-54, on the coo's own witness: a pass recorded one corpus hash and a background job
# moved corpus eight seconds later; gate_bin_watch stayed silent and was right to, because the BINARY had
# not moved). One call: gate_tree_watch exports S4E_TREE_AT_START in util_score_row's own vocabulary AND
# takes the baseline, so this board stops stamping HEAD-at-WRITE-time and starts refusing a split reading.
GATE_NAME=test_icon_ipl_suite gate_tree_watch "$(cd "$HERE/../.." && pwd)"

TMP="$(mktemp -d /tmp/ipl_suite_XXXXXX)"
trap 'rm -rf "$TMP"' EXIT; trap 'rm -rf "$TMP"; exit 143' TERM; trap 'rm -rf "$TMP"; exit 130' INT; trap 'rm -rf "$TMP"; exit 129' HUP

# ⛔ EXCLUDE OUR OWN CONTAINER: ALL.icn is generated by util_build_* from the entries below it, so counting
# it makes the package's concatenation a 852nd "vendored program" -- it parse-errors at line 14125 and lands
# in parseerr, contaminating a VENDOR score with a file we wrote. The population is upstream files only.
# ⛔ AND A DRIVER IS NOT A PROGRAM (CEO-1269): NAME_driver.icn is its library's grading vehicle, never one of the shipped programs this
# tier compiles or the container accounts for -- lib_inventory.sh drops it from shipped by the same name.
mapfile -t FILES < <(find "$PKG" -name "*.icn" ! -name "ALL.icn" ! -name "*_driver.icn" ! -path "*.fixtures/*" | sort)
# ⭐ THE ROUND ROBIN'S SEAM (ceo CEO-1802/1805/1806): under S4E_CHUNK both tiers grade only the selected entries (keyed subdir/stem, as ALL.csv and
# PARTITION.tsv key them), each program's rows are appended as it is graded (ipl_progress), and no suite row is written (rr_end below).
. "$HERE/lib_rr.sh" && rr_load "$PKG" || exit 2
if rr_selected; then
    _rf=(); for f in "${FILES[@]}"; do rr_admits "$(basename "$(dirname "$f")")/$(basename "$f" .icn)" && _rf+=("$f"); done; FILES=(${_rf[@]+"${_rf[@]}"})
fi
if [ -n "$SMOKE_KEYS" ]; then
    _sf=(); for f in "${FILES[@]}"; do smoke_wants "$(basename "$(dirname "$f")")/$(basename "$f" .icn)" && _sf+=("$f"); done; FILES=(${_sf[@]+"${_sf[@]}"})
fi
TOTAL=${#FILES[@]}
[ "$TOTAL" -gt 0 ] || { echo "⛔ GATE REFUSES: zero .icn files found under $PKG" >&2; exit 2; }
# ⛔⭐ CROSS-INSTRUMENT IDENTITY -- the check whose absence let 851 be "corrected" to 852 for a whole session.
# The container machinery accounts for every upstream file exactly once: graded entries + named exclusions.
# If that disagrees with what this runner walks, the two instruments in ONE package disagree and NEITHER
# number can be published, so we REFUSE rather than print a plausible one (rc=2 = could not measure).
if [ -z "$SMOKE_KEYS" ] && ! rr_selected && [ -f "$PKG/ALL.csv" ] && [ -f "$PKG/ALL.excluded.txt" ]; then
    # ⛔ A ROW IS A CONTAINER ENTRY ONLY WHEN ALL.excluded.txt DOES NOT NAME IT (ceo CEO-1261): since Lon's word of 2026-09-25 every
    # graded program carries its settings in ALL.csv, so an excluded program the runner still RUNS has a settings row too, and
    # counting it as a container entry would count it twice.
    _entries=$(awk -F': ' 'NR==FNR{ex[$1]=1; next} FNR>1{split($0,a,","); if(!(a[2] in ex)) n++} END{print n+0}' "$PKG/ALL.excluded.txt" "$PKG/ALL.csv")
    _excluded=$(wc -l < "$PKG/ALL.excluded.txt")
    _accounted=$(( _entries + _excluded ))
    if [ "$_accounted" -ne "$TOTAL" ]; then
        echo "⛔ GATE REFUSES: population disagreement inside one package -- this runner walks $TOTAL upstream .icn," >&2
        echo "   but the container accounts for $_accounted (ALL.csv $_entries entries + ALL.excluded.txt $_excluded exclusions)." >&2
        echo "   Neither number may be published. Regenerate the container, or find what entered the tree unaccounted." >&2
        exit 2
    fi
fi

mapfile -t STDFILES < <(find "$PKG" -name "*.ref" ! -name ALL.ref)
if rr_selected; then
    _rs=(); for f in "${STDFILES[@]}"; do _b="$(basename "$f" .ref)"; rr_admits "$(basename "$(dirname "$f")")/${_b%_driver}" && _rs+=("$f"); done; STDFILES=(${_rs[@]+"${_rs[@]}"})
fi
if [ -n "$SMOKE_KEYS" ]; then
    _ss=(); for f in "${STDFILES[@]}"; do _b="$(basename "$f" .ref)"; smoke_wants "$(basename "$(dirname "$f")")/${_b%_driver}" && _ss+=("$f"); done; STDFILES=(${_ss[@]+"${_ss[@]}"})
fi
RUN_GRADED=${#STDFILES[@]}

COMPILE_PASS=0; COMPILE_FAIL=0
NOMAIN_OK=0; LINKGAP=0; PARSEERR=0; TIMEOUT_N=0; OTHER=0
NOMAIN_TOTAL=0; HASMAIN_TOTAL=0
LINKGAP_NAMES=(); PARSEERR_NAMES=(); OTHER_NAMES=(); TIMEOUT_NAMES=()
declare -A OTHER_SIG_COUNT

echo "=== Icon Program Library ($TOTAL .icn files, $PKG; run-graded population=$RUN_GRADED) ==="

# ⭐ THE DECLARED COMPILE SWITCHES, READ ONCE, BEFORE THE COMPILE TIER (clause 8 (f), CEO-1281): declared_memory_table validates every
# cell of the attribute file through the harness's own validators, and each file then looks its compile_args up with one awk, keyed
# "parentdir/stem" as util_build_package_suite.py writes the entry column. A file with no row compiles with no switch.
. "$HERE/lib_declared_arena.sh"
CA_TBL="$TMP/compile_args.tsv"
declared_memory_table "$PKG/ALL.csv" > "$CA_TBL" || { echo "⛔ REFUSED TO GRADE rc=2: a cell in $PKG/ALL.csv is refused (named above) -- this board does not grade around it" >&2; exit 2; }
# ⛔⭐ A UNIT WITH NO DECLARING ROW IS NAMED, NEVER GRADED SILENTLY AT THE DEFAULTS (RULES.md 8 (f); coo 2026-09-27): every key the two
# tiers look up is asked once, and the names print below, empty or not. 631 of these 851 files had no row from the drivers of
# CEO-1269/1272 until corpus 2026-09-27, and the 356 run-graded among them ran without the --stlimit this runner typed for every
# program until 286483382 -- IPL iftrace's trace lines could never appear (hq_icon's ask). util_icon_package_units.py lists the keys.
DECL_CSV_OF_TABLE="$PKG/ALL.csv"; declare -A UNDECLARED=() DECL_ASKED=()
decl_ask() { [ -n "${DECL_ASKED[$1]:-}" ] && return 0; DECL_ASKED[$1]=1; declared_row_in_table "$CA_TBL" "$1"; case $? in 0) ;; 1) UNDECLARED[$1]=1 ;; *) exit 2 ;; esac; }

for f in "${FILES[@]}"; do
    rel="${f#"$PKG"/}"
    base="$(basename "$f" .icn)"
    out="$TMP/${base}.s"
    log="$TMP/${base}.log"
    has_main=0
    grep -qE '^procedure[[:space:]]+main[[:space:]]*\(' "$f" && has_main=1
    if [ "$has_main" -eq 1 ]; then HASMAIN_TOTAL=$((HASMAIN_TOTAL+1)); else NOMAIN_TOTAL=$((NOMAIN_TOTAL+1)); fi

    decl_ask "$(basename "$(dirname "$f")")/$base"
    _ca="$(declared_compile_args_from_table "$CA_TBL" "$(basename "$(dirname "$f")")/$base")" || exit 2
    "$TIMEOUT_RETRY" "$TIMEOUT" "$SCRIP" --compile $_ca "$f" -o "$out" < /dev/null > "$log" 2>&1
    rc=$?

    if [ "$rc" -eq 124 ]; then
        TIMEOUT_N=$((TIMEOUT_N+1)); TIMEOUT_NAMES+=("$rel")
        COMPILE_FAIL=$((COMPILE_FAIL+1))
        [ "$VERBOSE" -eq 1 ] && echo "  TIMEOUT $rel"
        continue
    fi

    if [ "$rc" -eq 0 ]; then
        COMPILE_PASS=$((COMPILE_PASS+1))
        [ "$VERBOSE" -eq 1 ] && echo "  PASS $rel"
        continue
    fi

    # rc != 0, not a timeout -- classify by signal. nomain_ok is checked FIRST and narrowly (has_main
    # must be 0 AND the exact FATAL string) so a has-main file that hits this same string for a
    # genuinely surprising reason falls through to OTHER instead of being silently absorbed. ⚠️ Does
    # NOT additionally require a non-empty $out: measured directly (fresh /tmp path, no stale debris)
    # that this failure path writes NOTHING to -o, ever -- confirming the fatal exit happens before
    # mode-4 ever opens the output file, so a size check here would just always read empty and never
    # fire. Matches the exact bar test_prolog_gnu_suite.sh's sibling LIB check already uses (grep the
    # one known-shape string on the probe log, nothing else) -- and by the compiler's own control flow
    # a link-resolution or parse-error exit() fires strictly earlier and never reaches this string, so
    # the two classes cannot collide in one run.
    if [ "$has_main" -eq 0 ] && grep -q "\[IBB\] FATAL: mode-4 driver: main BB graph not found" "$log"; then
        NOMAIN_OK=$((NOMAIN_OK+1)); COMPILE_PASS=$((COMPILE_PASS+1))
        [ "$VERBOSE" -eq 1 ] && echo "  PASS (nomain, library module) $rel"
        continue
    fi

    COMPILE_FAIL=$((COMPILE_FAIL+1))
    if grep -q "^icon: link: cannot open" "$log"; then
        LINKGAP=$((LINKGAP+1)); LINKGAP_NAMES+=("$rel")
        [ "$VERBOSE" -eq 1 ] && echo "  FAIL (linkgap) $rel"
    elif grep -qi "parse error" "$log"; then
        PARSEERR=$((PARSEERR+1)); PARSEERR_NAMES+=("$rel")
        [ "$VERBOSE" -eq 1 ] && echo "  FAIL (parse error) $rel"
    else
        OTHER=$((OTHER+1)); OTHER_NAMES+=("$rel (rc=$rc)")
        sig="$(head -1 "$log" | tr -s ' ')"
        OTHER_SIG_COUNT["$sig"]=$(( ${OTHER_SIG_COUNT["$sig"]:-0} + 1 ))
        echo "  ⛔ OTHER $rel -- rc=$rc: $(head -1 "$log")"
    fi
done

echo ""
echo "-- linkgap (KNOWN, NAMED -- see file header: link cfunc, the IPL's loadfunc C-function library in ipl/cfuncs, not vendored in the corpus; NEEDS_VENDORED_SOURCE, row icon-vendor-ipl-cfuncs-so-zona-and-jcon-reach-their-full-denominators): $LINKGAP --"
for n in "${LINKGAP_NAMES[@]:-}"; do [ -n "$n" ] && echo "   $n"; done

echo ""
echo "-- parseerr (genuine frontend rejection): $PARSEERR --"
for n in "${PARSEERR_NAMES[@]:-}"; do [ -n "$n" ] && echo "   $n"; done

echo ""
echo "-- timeout (>${TIMEOUT}s): $TIMEOUT_N --"
for n in "${TIMEOUT_NAMES[@]:-}"; do [ -n "$n" ] && echo "   $n"; done

if [ "$OTHER" -gt 0 ]; then
    echo ""
    echo "-- OTHER (unclassified signal, needs investigation): $OTHER --"
    for sig in "${!OTHER_SIG_COUNT[@]}"; do echo "   [${OTHER_SIG_COUNT[$sig]}x] $sig"; done
    for n in "${OTHER_NAMES[@]}"; do echo "   $n"; done
fi

COMPILE_GRADED=$((COMPILE_PASS + COMPILE_FAIL))
echo ""
# ⛔ BEFORE THE BOARD LINE AND BEFORE ANY SCORE.md WRITE, NEVER AFTER (ceo CEO-524 (1)): a refusal that fires
# after the row is published is an annotation, not a refusal -- the same lesson test_gate_progress_rows_carry_
# the_start_fingerprint.sh was written for. gate_bin_unmoved exits 2 itself when the fingerprint moved.
GATE_NAME=test_icon_ipl_suite gate_bin_unmoved
# ⛔ BEFORE THE FIRST PUBLISHED NUMBER, beside the binary check and for the same reason: an annotation that
# the tree moved is not a refusal -- util_score_row would happily write "graded; HEAD moved during the run"
# onto a number that describes no single tree.
GATE_NAME=test_icon_ipl_suite gate_tree_unmoved
BOARD_LINE="IPL_SUITE_BOARD total=$TOTAL compile_graded=$COMPILE_GRADED compile_pass=$COMPILE_PASS compile_fail=$COMPILE_FAIL run_graded=$RUN_GRADED nomain_total=$NOMAIN_TOTAL hasmain_total=$HASMAIN_TOTAL nomain_ok=$NOMAIN_OK linkgap=$LINKGAP parseerr=$PARSEERR timeout=$TIMEOUT_N other=$OTHER"; echo "$BOARD_LINE"

# ═══ RUN TIER -- every progs/*.icn with a NAME.ref (cut by util_cut_icon_ipl_refs.sh) gets EXECUTED,
# both modes independently, and diffed against it. See file header: execution goes through
# lib_icon_ipl_isolation.sh, never a bare cd into $PKG/progs. ═══
. "$HERE/lib_inventory.sh" 2>/dev/null || { echo "⛔ GATE REFUSES: lib_inventory.sh unloadable" >&2; exit 2; }
. "$HERE/lib_icon_ipl_isolation.sh"
# ⛔ CEO-1167 declared arena, the same reader arizona's and jcon's runners source. Four IPL entries carry
# one: miu/kwic/ichartp/concord all die rc=139 with a [ZGC-STALE] report (a root the collector never
# visited kept a pre-collection address) on the shipped 4096 KB default, and clear byte-identical at
# 8192 KB -- a window that never triggers a collection for their small working sets sidesteps the gap
# rather than curing it, so the underlying root-visitation defect is reported separately, not fixed here.
. "$HERE/lib_declared_arena.sh"
PKG_CSV="$PKG/ALL.csv"
. "$HERE/lib_progress.sh" 2>/dev/null || { echo "⛔ GATE REFUSES: lib_progress.sh unloadable -- a run that records nothing is a defect of that run (CEO-331)" >&2; exit 2; }
PROGRESS_CONFIG="$(progress_config_of_env)"   # every row declares what it ran under: the GC axis in this environment, else shipped (the board sets none per child)
# ⛔ ipl DOES NOT RECORD AUTOMATICALLY, whatever the ALL.icn pair suggests. CEO-331 lists ipl among the
# packages that "now record automatically" because they have an ALL.<ext> pair -- but this package's
# ALL.icn/ALL.ref are consumed by NO runner (measured 2026-09-06: this script opens ALL.csv only for its
# container identity check and grades by per-program .ref; board_packages.sh's runner_for() has no
# icon/ipl case; ALL.ref has ONE commit in its whole history, and a ref nothing regenerates is a ref
# nothing grades). So the automatic path would record a suite nobody runs. This runner has its own loop
# and appends from it. ⭐ A package can satisfy the STRUCTURAL condition for a mechanism and be outside it.
PROGRESS_FAILED=0
# ⛔ A PROGRESS ROW NAMES ITS PROGRAM BY PATH, parentdir/stem -- the key of its ALL.csv row (util_build_package_suite.py), not the
# bare stem: the IPL ships gener and morse both as a procs/ library graded through its driver and as a progs/ program, so stem keys
# collapsed 550 graded programs into 548 DB names, two passes vanished from the DB's count, and util_score_row's cross-check refused
# the row (hq_icon 2026-09-26 18:2x: AND 513 of 550 against 511 PASS over 841). gimpel, gnu, roast and swi key by path already.
ipl_progress() { if [ -n "$SMOKE_KEYS" ]; then SMOKE_V["$IPL_ISO_SUBDIR/$1 $2"]="$3"; return 0; fi; progress_append package ipl icon "$IPL_ISO_SUBDIR/$1" "$2" "$3" "${IPL_SECS:-0}" || PROGRESS_FAILED=$((PROGRESS_FAILED+1)); }   # IPL_SECS: that mode's own wall (CEO-1676 (c)); 0 for a row that ran nothing
ipl_isolation_init "$PKG" || { echo "⛔ GATE REFUSES: could not build IPL isolation template" >&2; exit 2; }
# ⛔ Snapshot the subtree BEFORE any graded program runs -- ipl_isolation_verify_clean at the end reports
# what moved SINCE HERE, not what differs from HEAD; the fixtures a sitting is authoring are untracked by
# definition, and the old form called that a breach (hq_I 2026-09-06).
ipl_isolation_baseline "$S4E/corpus" || echo "⚠ could not snapshot the ipl subtree; the end-of-run isolation check falls back to a HEAD comparison" >&2
trap 'rm -rf "$TMP"; ipl_isolation_cleanup' EXIT; trap 'rm -rf "$TMP"; ipl_isolation_cleanup; exit 143' TERM; trap 'rm -rf "$TMP"; ipl_isolation_cleanup; exit 130' INT; trap 'rm -rf "$TMP"; ipl_isolation_cleanup; exit 129' HUP

M3_RUN_PASS=0; M3_RUN_FAIL=0; M3_RUN_CRASH=0; M3_RUN_HANG=0
M4_RUN_PASS=0; M4_RUN_FAIL=0; M4_RUN_CRASH=0; M4_RUN_HANG=0
M3_RUN_FAIL_NAMES=(); M4_RUN_FAIL_NAMES=()
M3_RUN_CRASH_NAMES=(); M4_RUN_CRASH_NAMES=(); M3_RUN_HANG_NAMES=(); M4_RUN_HANG_NAMES=()
ARENA_NAMES=""   # ⛔ initialized here, not merely appended-to in the loop -- an uninitialized ARENA_NAMES crashed test_icon_arizona_suite.sh under set -u the moment any entry declared heap_kb (same fix, two runners over)

# ⛔⛔ MAX_BYTES gates every full-content read here too, checked via `wc -c` on the FILE before any
# slurp into a bash variable -- same discipline, same incident, as util_cut_icon_ipl_refs.sh's own
# MAX_BYTES (see that script's header): a timing-out process is not necessarily quiet while it waits, so
# `out3="$(cat ...)"` run UNCONDITIONALLY before checking rc==124 can slurp gigabytes for a result about
# to be discarded as HANG anyway. Here the risk is SCRIP's own output on a genuine bug (an infinite-
# output loop from a miscompiled pattern), not the oracle's -- same shape, same fix. Every .ref this
# tier reads is itself already capped at ref-cutting time, so oversized ACTUAL output can never equal
# `$exp` regardless; it is graded RUN_FAIL without ever being read into memory.
MAX_BYTES=1048576

for std in "${STDFILES[@]}"; do
    base="$(basename "$std" .ref)"
    rr_yield "$(basename "$(dirname "$std")")/${base%_driver}" && break   # a test request waits: stop between two tests (CEO-1806)
    icn="$(dirname "$std")/$base.icn"
    [ -f "$icn" ] || continue
    # ⛔ Each entry runs with ITS OWN package subdirectory as cwd -- refs are no longer progs-only
    # (gprogs/ carries .ref files as of 2026-09-06, CEO-316). A gprogs entry run from progs/ links
    # against the wrong directory and grades a program that never ran properly. Set here, before the first ipl_progress, which
    # names the program by it.
    IPL_ISO_SUBDIR="$(basename "$(dirname "$std")")"; export IPL_ISO_SUBDIR
    # ⛔⭐ A LIBRARY IS GRADED BY ITS DRIVER, UNDER ITS OWN NAME (ceo CEO-1269; coo 2026-09-25, hq_icon's ask for the 382 IPL libraries
    # CEO-1272 made NEEDS_DRIVER): NAME_driver.icn and its .ref beside NAME.icn -- the driver is what RUNS, NAME is what is counted,
    # named and recorded, as in the Arizona and Jcon runners. The driver run puts its own directory first on IPATH (IPL_ISO_DRIVER).
    # A driver whose library is not shipped, or a library carrying its own .ref as well, refuses: two answers, or none, to one question.
    id="$base"; unset IPL_ISO_DRIVER; _drvpath=(); IPL_SECS=0
    case "$base" in *_driver)
        id="${base%_driver}"
        [ -f "$(dirname "$std")/$id.icn" ] || { echo "⛔ REFUSED TO GRADE rc=2: ${std#"$PKG"/} is a driver's ref but its library $id.icn is not shipped beside it -- a vehicle with nothing to carry (CEO-1269)" >&2; exit 2; }
        [ -f "$(dirname "$std")/$id.ref" ] && { echo "⛔ REFUSED TO GRADE rc=2: $id has its own .ref AND a driver $base -- two grading vehicles for one library (CEO-1269)" >&2; exit 2; }
        export IPL_ISO_DRIVER=1; _drvpath=(env "IPATH=$(dirname "$icn")${IPATH:+:$IPATH}") ;;
    esac
    # ⛔ NO $exp VARIABLE (hq_icon 2026-10-01): both PASS checks below cmp the rendered run output FILE
    # directly against $std -- the ref file itself, never a `"$(cat "$std")"` capture. Measured on
    # progs/huffstuf.icn (a real Huffman encoder, genuinely binary output): command substitution silently
    # drops embedded NUL bytes ("ignored null byte in input"), which is the ONE comparison every run-graded
    # IPL program's PASS/FAIL goes through -- a wrong verdict here is silent in both directions, for any
    # program whose correct output is not plain text.
    # ⭐ NAME.rc, THE PROGRAM'S DECLARED EXIT STATUS (seat07's sidecar, which the cutter mints under): a program whose every exit is
    # stop() is graded on its status as well as its output, so a run that prints the right text and exits 0 is not a pass
    # (hq_icon 2026-09-27, ceo CEO-1315). Absent, the status is not graded, exactly as before.
    if ! want_rc="$(ipl_rc_declared "$(dirname "$std")/$base.icn")"; then
        M3_RUN_FAIL=$((M3_RUN_FAIL+1)); M3_RUN_FAIL_NAMES+=("$id(rc-sidecar-malformed)"); ipl_progress "$id" m3 REFUSE
        M4_RUN_FAIL=$((M4_RUN_FAIL+1)); M4_RUN_FAIL_NAMES+=("$id(rc-sidecar-malformed)"); ipl_progress "$id" m4 REFUSE
        continue
    fi
    # ⭐ NAME.dat STDIN SIDECAR (hq_I 2026-09-05): same convention as arizona/jcon_tests' own .dat
    # fixtures, and the one util_cut_icon_ipl_refs.sh mints these four new refs under -- both tiers
    # must agree per this file's own FACT RULE (a script and its DONE-WHEN, or its sibling ref-cutter,
    # must not disagree).
    dat="$(dirname "$std")/$base.dat"; stdin_src=/dev/null; [ -f "$dat" ] && stdin_src="$dat"
    # ⭐ NAME.argv ARGV SIDECAR (hq_I 2026-09-06, CEO-328). Read through the SHARED reader in
    # lib_icon_ipl_isolation.sh, never re-implemented here -- the ref-cutter mints under exactly this
    # lookup, so a program's ref and its grading cannot disagree about the argv it was given. ⛔ A
    # MALFORMED SIDECAR IS A GRADED FAILURE, NOT A SKIP: grading it with an empty argv would silently
    # compare the program's no-arguments behaviour against a ref cut WITH arguments, and score the
    # difference against SCRIP. That is the false-FAIL shape this package already carries in arizona.
    declare -a IPLARGV=(); ipl_argv_read "$icn" IPLARGV; argv_rc=$?
    if [ "$argv_rc" -eq 2 ]; then
        M3_RUN_FAIL=$((M3_RUN_FAIL+1)); M3_RUN_FAIL_NAMES+=("$id(argv-sidecar-malformed)"); ipl_progress "$id" m3 REFUSE
        M4_RUN_FAIL=$((M4_RUN_FAIL+1)); M4_RUN_FAIL_NAMES+=("$id(argv-sidecar-malformed)"); ipl_progress "$id" m4 REFUSE
        continue
    fi
    # ⭐ NAME.fixtures/ FIXTURE-FILE SIDECAR (seat07 2026-09-06): staged by ipl_isolation_run itself when
    # this is set, same convention as the cutter's own run_isolated() -- both sites call the one shared
    # ipl_fixtures_stage reader in lib_icon_ipl_isolation.sh, so a program's minted ref and its grading
    # here can never disagree about which files were present when it ran.
    IPL_ISO_FIXTURES="$icn"; export IPL_ISO_FIXTURES

    # ⛔⭐ THE ENTRY KEY IS "$IPL_ISO_SUBDIR/$id", matching what util_build_package_suite.py writes into
    # ALL.csv's entry column for a nested source (arizona's identical note at its own arena read applies
    # here verbatim). _sw expands to nothing for an undeclared entry -- an undeclared program's
    # invocation is byte-identical to what it was before this existed.
    # ⭐ THE DECLARATION RIDES THE COMMAND LINE AS SPITBOL'S SWITCHES (ceo CEO-1353, the coo's census): -d<kb>k -s<kb>k after --run and
    # the compile args in m3, leading the binary's own arguments in m4, never the compile step. ⛔ NEVER SCRIP_HEAP_KB: gc_heap.c reads it
    # as the collector's initial WINDOW, so every declared program ran at window = cap = 128 MB where the shipped window is 1 MB.
    if ! _sw=$(declared_arena_switches "$PKG_CSV" "$IPL_ISO_SUBDIR/$id"); then
        echo "⛔ REFUSED TO GRADE rc=2: $IPL_ISO_SUBDIR/$id carries a heap_kb or stack_kb cell this runner will not honour (reason above) -- grading it at the shipped default would publish a row whose sizes its own attribute file contradicts" >&2
        exit 2
    fi
    [ -n "$_sw" ] && ARENA_NAMES="${ARENA_NAMES:-} $IPL_ISO_SUBDIR/$id=[$_sw]"

    # -- m3 (--run): executes the Icon program's own logic directly -- isolated.
    # ⛔ `--` separates SCRIP's own flags from the target program's argv; the oracle needs no separator
    # (`icon prog.icn a b`), and the m4 binary takes them bare. Three shapes, one declaration.
    # ⛔ WRITTEN LONG ON PURPOSE. The clever one-liner `${IPLARGV[@]+-- "${IPLARGV[@]}"}` GLUES the
    # literal to the first element -- measured: with (x, "y z") it yields the two words `-- x` and `y z`,
    # so SCRIP receives "-- x" as a single argument and the program sees one argv entry, not two. It
    # looks right, it runs, and every count downstream would have been quietly off.
    decl_ask "$IPL_ISO_SUBDIR/$id"
    _ca="$(declared_compile_args_from_table "$CA_TBL" "$IPL_ISO_SUBDIR/$id")" || exit 2
    _t0="$(progress_clock)"
    if [ "${#IPLARGV[@]}" -gt 0 ]; then
        ipl_isolation_run "$TMP/${base}.m3.out" "$TIMEOUT" "$stdin_src" "$SCRIP" --run $_ca $_sw "$icn" -- "${IPLARGV[@]}"
    else
        ipl_isolation_run "$TMP/${base}.m3.out" "$TIMEOUT" "$stdin_src" "$SCRIP" --run $_ca $_sw "$icn"
    fi
    rc3=$?; IPL_SECS="$(progress_secs_since "$_t0")"
    by3=$(wc -c < "$TMP/${base}.m3.out" 2>/dev/null || echo 0)
    if [ "$rc3" -eq 124 ]; then M3_RUN_HANG=$((M3_RUN_HANG+1)); M3_RUN_HANG_NAMES+=("$id"); ipl_progress "$id" m3 HANG
    elif [ "$rc3" -eq 125 ]; then M3_RUN_FAIL=$((M3_RUN_FAIL+1)); M3_RUN_FAIL_NAMES+=("$id(fixture-sidecar-malformed)"); ipl_progress "$id" m3 REFUSE
    elif [ "$rc3" -ge 128 ]; then M3_RUN_CRASH=$((M3_RUN_CRASH+1)); M3_RUN_CRASH_NAMES+=("$id(sig$((rc3-128)))"); ipl_progress "$id" m3 CRASH
    elif [ "$by3" -gt "$MAX_BYTES" ]; then M3_RUN_FAIL=$((M3_RUN_FAIL+1)); M3_RUN_FAIL_NAMES+=("$id(oversized:$by3)"); ipl_progress "$id" m3 FAIL
    elif [ -n "$want_rc" ] && [ "$rc3" -ne "$want_rc" ]; then M3_RUN_FAIL=$((M3_RUN_FAIL+1)); M3_RUN_FAIL_NAMES+=("$id(rc$rc3-not-$want_rc)"); ipl_progress "$id" m3 FAIL
    elif { python3 "$HERE/util_render_error_voice.py" icon < "$TMP/${base}.m3.out" > "$TMP/${base}.m3.voice" 2>/dev/null; ipl_graded_cmp "$IPL_ISO_FIXTURES" "$TMP/${base}.m3.voice" "$std"; }; then M3_RUN_PASS=$((M3_RUN_PASS+1)); ipl_progress "$id" m3 PASS
    else M3_RUN_FAIL=$((M3_RUN_FAIL+1)); M3_RUN_FAIL_NAMES+=("$id"); ipl_progress "$id" m3 FAIL; fi

    # -- m4 (--compile): emitting .s does not execute the target program, so THAT step is unisolated,
    # same as the compile tier above; only running the linked binary carries the self-mutation hazard.
    s4="$TMP/${base}.m4.s"; bin4="$TMP/${base}.m4.bin"; _t0="$(progress_clock)"
    ${_drvpath[@]+"${_drvpath[@]}"} "$SCRIP" --compile $_ca "$icn" >"$s4" 2>"$TMP/${base}.m4.diag" </dev/null
    if [ -s "$s4" ] && gcc -no-pie "$s4" -L"$HERE/../../SCRIP/out" -lscrip_rt -Wl,-rpath,"$HERE/../../SCRIP/out" -o "$bin4" 2>/dev/null; then
        if [ "${#IPLARGV[@]}" -gt 0 ]; then
            ipl_isolation_run "$TMP/${base}.m4.out" "$TIMEOUT" "$stdin_src" "$bin4" $_sw -- "${IPLARGV[@]}"
        else
            ipl_isolation_run "$TMP/${base}.m4.out" "$TIMEOUT" "$stdin_src" "$bin4" $_sw
        fi
        rc4=$?; IPL_SECS="$(progress_secs_since "$_t0")"
        by4=$(wc -c < "$TMP/${base}.m4.out" 2>/dev/null || echo 0)
        if [ "$rc4" -eq 124 ]; then M4_RUN_HANG=$((M4_RUN_HANG+1)); M4_RUN_HANG_NAMES+=("$id"); ipl_progress "$id" m4 HANG
        elif [ "$rc4" -eq 125 ]; then M4_RUN_FAIL=$((M4_RUN_FAIL+1)); M4_RUN_FAIL_NAMES+=("$id(fixture-sidecar-malformed)"); ipl_progress "$id" m4 REFUSE
        elif [ "$rc4" -ge 128 ]; then M4_RUN_CRASH=$((M4_RUN_CRASH+1)); M4_RUN_CRASH_NAMES+=("$id(sig$((rc4-128)))"); ipl_progress "$id" m4 CRASH
        elif [ "$by4" -gt "$MAX_BYTES" ]; then M4_RUN_FAIL=$((M4_RUN_FAIL+1)); M4_RUN_FAIL_NAMES+=("$id(oversized:$by4)"); ipl_progress "$id" m4 FAIL
        elif [ -n "$want_rc" ] && [ "$rc4" -ne "$want_rc" ]; then M4_RUN_FAIL=$((M4_RUN_FAIL+1)); M4_RUN_FAIL_NAMES+=("$id(rc$rc4-not-$want_rc)"); ipl_progress "$id" m4 FAIL
        elif { python3 "$HERE/util_render_error_voice.py" icon < "$TMP/${base}.m4.out" > "$TMP/${base}.m4.voice" 2>/dev/null; ipl_graded_cmp "$IPL_ISO_FIXTURES" "$TMP/${base}.m4.voice" "$std"; }; then M4_RUN_PASS=$((M4_RUN_PASS+1)); ipl_progress "$id" m4 PASS
        else M4_RUN_FAIL=$((M4_RUN_FAIL+1)); M4_RUN_FAIL_NAMES+=("$id"); ipl_progress "$id" m4 FAIL; fi
    else
        IPL_SECS="$(progress_secs_since "$_t0")"
        M4_RUN_FAIL=$((M4_RUN_FAIL+1)); M4_RUN_FAIL_NAMES+=("$id(compile/link)"); ipl_progress "$id" m4 FAIL
    fi
    rm -f "$s4" "$bin4" "$TMP/${base}.m3.out" "$TMP/${base}.m4.out"
done
unset IPL_ISO_DRIVER
if [ -n "$SMOKE_KEYS" ]; then
    ipl_isolation_verify_clean "$S4E/corpus" || true
    for k in $SMOKE_KEYS; do
        if [ -n "${SMOKE_V["$k m3"]:-}${SMOKE_V["$k m4"]:-}" ]; then echo "IPL_SMOKE_ENTRY $k m3=${SMOKE_V["$k m3"]:-NONE} m4=${SMOKE_V["$k m4"]:-NONE}"
        else echo "IPL_SMOKE_ENTRY $k NOT_RUN-GRADED (no NAME.ref or driver ref beside it: the board grades it on the compile tier only)"; fi
    done
    exit 0
fi

echo ""
echo "-- RUN tier: $RUN_GRADED progs/ programs graded against a .ref cut from the real Icon oracle (util_cut_icon_ipl_refs.sh --apply) --"
echo "mode-3 (--run):     RUN_PASS=$M3_RUN_PASS RUN_FAIL=$M3_RUN_FAIL RUN_CRASH=$M3_RUN_CRASH RUN_HANG=$M3_RUN_HANG / $RUN_GRADED"
echo "mode-4 (--compile): RUN_PASS=$M4_RUN_PASS RUN_FAIL=$M4_RUN_FAIL RUN_CRASH=$M4_RUN_CRASH RUN_HANG=$M4_RUN_HANG / $RUN_GRADED"
[ "$VERBOSE" -eq 1 ] && [ ${#M3_RUN_FAIL_NAMES[@]} -gt 0 ] && printf 'm3 RUN_FAIL:%s\n' "$(printf ' %s' "${M3_RUN_FAIL_NAMES[@]}")"
[ "$VERBOSE" -eq 1 ] && [ ${#M4_RUN_FAIL_NAMES[@]} -gt 0 ] && printf 'm4 RUN_FAIL:%s\n' "$(printf ' %s' "${M4_RUN_FAIL_NAMES[@]}")"
[ ${#M3_RUN_CRASH_NAMES[@]} -gt 0 ] && printf 'm3 RUN_CRASH:%s\n' "$(printf ' %s' "${M3_RUN_CRASH_NAMES[@]}")"
[ ${#M4_RUN_CRASH_NAMES[@]} -gt 0 ] && printf 'm4 RUN_CRASH:%s\n' "$(printf ' %s' "${M4_RUN_CRASH_NAMES[@]}")"
[ ${#M3_RUN_HANG_NAMES[@]} -gt 0 ] && printf 'm3 RUN_HANG:%s\n' "$(printf ' %s' "${M3_RUN_HANG_NAMES[@]}")"
[ ${#M4_RUN_HANG_NAMES[@]} -gt 0 ] && printf 'm4 RUN_HANG:%s\n' "$(printf ' %s' "${M4_RUN_HANG_NAMES[@]}")"
echo "IPL_RUN_BOARD run_graded=$RUN_GRADED m3_RUN_PASS=$M3_RUN_PASS m3_RUN_FAIL=$M3_RUN_FAIL m3_RUN_CRASH=$M3_RUN_CRASH m3_RUN_HANG=$M3_RUN_HANG m4_RUN_PASS=$M4_RUN_PASS m4_RUN_FAIL=$M4_RUN_FAIL m4_RUN_CRASH=$M4_RUN_CRASH m4_RUN_HANG=$M4_RUN_HANG"
# ⛔⭐ THE ROW IS THE AND OF BOTH MODES PER PROGRAM (ceo CEO-627, 2026-09-12; the rule arizona and jcon already publish under
# CEO-545). Until today this runner published --suite-pass "$M3_RUN_PASS" alone: a run that read m3 162/162 · m4 161/162 and
# exited rc=1 on that mode-4 red still wrote "162/162 ✅ done" to SCORE.md. A program is green only if BOTH modes are; the
# FAIL, CRASH and HANG names of each mode (their "(reason)" suffixes stripped, so one program never counts twice) are unioned by
# gate_and_per_program and the row is RUN_GRADED minus that union. Gate: test_gate_icn_ipl_row_is_the_and_of_both_modes.sh.
m3_RED_NAMES="$(printf '%s\n' ${M3_RUN_FAIL_NAMES[@]+"${M3_RUN_FAIL_NAMES[@]}"} ${M3_RUN_CRASH_NAMES[@]+"${M3_RUN_CRASH_NAMES[@]}"} ${M3_RUN_HANG_NAMES[@]+"${M3_RUN_HANG_NAMES[@]}"} | sed 's/(.*$//')"
m4_RED_NAMES="$(printf '%s\n' ${M4_RUN_FAIL_NAMES[@]+"${M4_RUN_FAIL_NAMES[@]}"} ${M4_RUN_CRASH_NAMES[@]+"${M4_RUN_CRASH_NAMES[@]}"} ${M4_RUN_HANG_NAMES[@]+"${M4_RUN_HANG_NAMES[@]}"} | sed 's/(.*$//')"
read -r AND_PASS AND_RED AND_NAMES <<<"$(gate_and_per_program "$RUN_GRADED" "$m3_RED_NAMES" "$m4_RED_NAMES")"
echo "IPL_AND_PER_PROGRAM and_pass=${AND_PASS:-n/a} of $RUN_GRADED (m3 $M3_RUN_PASS · m4 $M4_RUN_PASS · union of reds ${AND_RED:-n/a}:${AND_NAMES:-})"
declared_arena_receipt "$PKG_CSV"
echo "-- undeclared (RULES.md 8 (f): no declaring row in ALL.csv, so graded at the runtime's defaults -- named, never taken silently): ${#UNDECLARED[@]} --"
for n in $(printf '%s\n' "${!UNDECLARED[@]}" | sort); do echo "   $n"; done
ipl_isolation_verify_clean "$S4E/corpus" || true

# ⭐ THE PACKAGE LOCKDOWN inventory line, via the shared body (lib_inventory.sh) -- never a second copy
# of the arithmetic (CEO-321: this row is hq_I's). ipl was the LAST Icon runner without it; arizona and
# jcon already print one.
# ⛔ THE GRADED POPULATION IS THE PACKAGE-WIDE .ref COUNT ($RUN_GRADED, from `find "$PKG" -name '*.ref'`),
# NOT progs/ alone. gprogs/ briefly carried refs on 2026-09-06; they were wrong and were reverted, but the
# discovery is package-wide by construction and lib_icon_ipl_isolation.sh is now subdirectory-aware
# (IPL_ISO_SUBDIR), so a future non-progs ref grades from its own directory instead of silently from progs/.
# ⛔ graded_narrow=0: this suite diffs FULL output against the oracle ref, never by error-number only.
rr_selected && { rr_end ipl; exit 0; }   # a chunk or a request wrote each program's rows as it went, and writes no suite row (CEO-1802)
INV_PACKAGE=ipl; INV_DIR="$PKG"; INV_EXT=".icn"
INV_LINE="$(inventory_line "$RUN_GRADED" 0)"
if [ -n "$INV_LINE" ]; then echo "$INV_LINE"; else echo "⚠ inventory refused (above) -- the board lines still stand; the inventory does not" >&2; fi
[ "${PROGRESS_FAILED:-0}" -eq 0 ] || echo "⛔ PROGRESS DB: $PROGRESS_FAILED per-program appends FAILED -- this run is not fully recorded (CEO-331); the board lines stand, the table does not" >&2

# ⭐ THE CLASS SPLIT, IN THE INVENTORY LINE RATHER THAN IN PROSE (CEO-328). It was built here first and
# hq_T RULED it into the shared body the same day (lib_inventory.sh: inventory_split_line), so this runner
# now CALLS it rather than carrying a second copy -- their reason is the keeper: a per-runner reading means
# seven readings of one count and no way to say which is authoritative. The sum invariant travelled with it.
if SPLIT_LINE="$(inventory_split_line)"; then [ -n "$SPLIT_LINE" ] && echo "$SPLIT_LINE"
else SPLIT_LINE=""; echo "⛔ PACKAGE INVENTORY SPLIT REFUSED (rc=2, reason above) -- the classes do not sum to their own buckets, so neither reading is published" >&2; fi
UNG_SPLIT="$(printf '%s' "$SPLIT_LINE" | sed -n 's/.*ungraded_by_class=\([^ ]*\).*/\1/p')"

# ⛔ ONE LEADERBOARD (RULES.md FACT RULE, Lon 2026-09-03 ~16:05: "any run of a test suite by any
# session will update the ONE LEADERBOARD"). This records the boards printed just above into
# .github/SCORE.md -- it RUNS NOTHING, it only writes down what this script already measured.
# ⛔ NON-FATAL BY DESIGN: a bookkeeping failure must never turn a real measurement into a red board.
# ⛔ NO BARE N/TOTAL FRACTION for the COMPILE tier -- see file header: compile-graded is not
# run-graded-correct, and a fraction here would silently enter the ONE LEADERBOARD's automatic
# per-language pass-rate sum (util_score_row.py cell_fractions()) as if it were verified-correct
# output. The RUN tier IS a verified-correctness population (diffed against a real oracle), so ITS
# m3/m4 fractions are reported as fractions -- same convention test_icon_arizona_suite.sh already uses.
# ⛔⭐ NAME THE SUITE FRACTION EXPLICITLY (cfo 2026-09-08, row score-row-write-rewrites-the-board-then-refuses,
# same cure test_icon_arizona_suite.sh took in b7f48462a). --text below deliberately mixes bare counts with
# fractions across THREE tiers (compile, nomain, run), so fraction_from_text() sees several distinct
# candidates and refuses rather than guess -- which is why the IPL row was hand-set. THE RUN TIER IS THE
# SUITE ROW, for the reason the comment block just above already gives: it is the only tier diffed against a
# real oracle, so it is the verified-correctness population. SUITES.tsv's hand-set 75/89 of 2026-09-07 is
# exactly M3_RUN_PASS/RUN_GRADED.
# ⛔⭐⭐ THE SHIPPED POPULATION IS THE DENOMINATOR, NOT THE GRADED SUBSET (ceo CEO-1272, 2026-09-25, applying CEO-1245/CEO-1268 to
# ipl): this line published the graded count RUN_GRADED as its suite total, the graded-subset shape CEO-1245 overturned for Zona and Jcon, so the row
# read 194/194 -- a 100% over the 194 programs with a cut ref -- while UNGRADABLE.tsv carried 557 files, 382 of them LIBRARIES
# (procs/, gprocs/) owed their drivers (CEO-1269). The total is now the inventory's own shipped count (containers out, CEO-1272),
# the graded fraction rides in the text labelled as such, and a refused inventory writes NO row rather than fall back to the subset.
IPL_SHIPPED="$(printf '%s' "${INV_LINE:-}" | sed -n 's/.* shipped=\([0-9][0-9]*\) .*/\1/p')"
# ⭐ THE GRAPHICS PROGRAMS LEAVE THE DENOMINATOR, NAMED (Lon 2026-09-27, in-chat to hq_icon, verbatim: "Place the graphics programs on
# the exclude list."): ipl/EXCLUDED.tsv names them, class NEEDS_GRAPHICS_FACILITY, and the inventory line then carries excluded=N
# denominator=shipped-N. The row divides by the denominator, and its Excl is the containers plus the excluded -- shipped = denominator
# + Excl reads off the row. A package with no EXCLUDED.tsv prints no denominator= and the row divides by shipped exactly as before.
IPL_EXCLUDED="$(printf '%s' "${INV_LINE:-}" | sed -n 's/.* excluded=\([0-9][0-9]*\) denominator=.*/\1/p')"
IPL_DENOM="$(printf '%s' "${INV_LINE:-}" | sed -n 's/.* denominator=\([0-9][0-9]*\).*/\1/p')"
[ -n "$IPL_DENOM" ] && [ -n "$IPL_SHIPPED" ] && IPL_SHIPPED="$IPL_DENOM"
# ⭐ THE ROW'S Excl (Lon 2026-09-26, "use the Excl column to properly classify the exclusions for good reasons only"; CEO-1288): every
# shipped unit the denominator leaves out, classified -- here the gincl/ include fragments of CONTAINERS.tsv (CEO-1272), read off the
# inventory line, so shipped = denominator + Excl reads off the row. Unknown when the inventory refused, and then no row is written.
. "$HERE/lib_outside_shape.sh" 2>/dev/null || { echo "⛔ REFUSED TO GRADE: lib_outside_shape.sh unloadable" >&2; exit 2; }
EXCL_N=""; _cc=""
if [ -n "$IPL_SHIPPED" ]; then
    _CON_N="$(inventory_containers_of "$INV_LINE")"; EXCL_N=$((_CON_N + ${IPL_EXCLUDED:-0}))
    _cc="${S4E_CRITERION_CHANGED:-}"; [ -n "$_cc" ] || _cc="$(excluded_shape_stamp ipl "$IPL_SHIPPED" - "$EXCL_N" "$_CON_N")" || exit 2
fi
[ -n "${AND_PASS:-}" ] || echo "⚠ SCORE.md NOT UPDATED -- AND per program unavailable (run_graded=$RUN_GRADED): record this row by hand"
[ -n "$IPL_SHIPPED" ] || echo "⚠ SCORE.md NOT UPDATED -- the inventory refused (above), so the shipped population the row divides by is unknown; the graded subset is never substituted for it (CEO-1245, CEO-1272)"
[ -n "${AND_PASS:-}" ] && [ -n "$IPL_SHIPPED" ] && python3 "$HERE/util_score_row.py" write --lang icon --column vendor --suite IPL --modes m3,m4 \
    --suite-pass "${AND_PASS}" --suite-total "$IPL_SHIPPED" ${_cc:+--criterion-changed "$_cc"} ${EXCL_N:+--excluded "$EXCL_N"} \
    --measurer "${S4E_SEAT:-}" \
    --text "AND per program ${AND_PASS}/$IPL_SHIPPED shipped${IPL_EXCLUDED:+ less $IPL_EXCLUDED graphics units excluded (EXCLUDED.tsv, Lon 2026-09-27)} (ceo CEO-1272/CEO-1245: the shipped population is the denominator, the libraries owed their drivers in it) · graded ${AND_PASS}/$RUN_GRADED (a program is green only if BOTH modes are; union of reds ${AND_RED:-n/a}:${AND_NAMES:-}) · compile_pass=$COMPILE_PASS compile_fail=$COMPILE_FAIL (linkgap=$LINKGAP parseerr=$PARSEERR timeout=$TIMEOUT_N other=$OTHER) of total=$TOTAL · nomain_ok=$NOMAIN_OK of nomain_total=$NOMAIN_TOTAL, hasmain_total=$HASMAIN_TOTAL · run m3 $M3_RUN_PASS/$RUN_GRADED m4 $M4_RUN_PASS/$RUN_GRADED (of $RUN_GRADED oracle-cut · fail m3=$M3_RUN_FAIL m4=$M4_RUN_FAIL, crash m3=$M3_RUN_CRASH m4=$M4_RUN_CRASH, hang m3=$M3_RUN_HANG m4=$M4_RUN_HANG)${INV_LINE:+ · $INV_LINE}${UNG_SPLIT:+ · ungraded_by_class=$UNG_SPLIT} (\`test_icon_ipl_suite.sh\`) · $BOARD_LINE" \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"

# ⛔⭐ POPULATION FLOOR (row every-board-wrapper-refuses-on-a-zero-population-instead-of-passing-
# vacuously, hq_T 2026-09-04): the bucket-sum check just below PASSES vacuously at TOTAL=0 (0+0==0),
# and OTHER=0 too when nothing was discovered -- neither line can tell "examined and clean" from
# "examined nothing", which is exactly what this refuses before either check runs.
"$HERE/util_require_population.sh" --gate test_icon_ipl_suite "$TOTAL" 1 "IPL source files discovered" || exit 2
[ "$((COMPILE_PASS + COMPILE_FAIL))" -eq "$TOTAL" ] || { echo "⛔ BUCKET COUNTS DON'T SUM TO TOTAL -- instrument bug, refusing to trust the board"; exit 2; }
# ⛔ THE SCRIPT'S OWN EXIT CODE MUST AGREE WITH WHAT THE TASK'S DONE-WHEN INDEPENDENTLY RE-DERIVES FROM
# THIS OUTPUT (RUN_PASS>0, every RUN_FAIL/RUN_CRASH/RUN_HANG==0 in both modes) -- a script that reads
# green by rc while the DONE-WHEN reads red from the same text (or vice versa) is exactly the kind of
# disagreement RULES.md's FACT RULE exists to prevent.
[ "$OTHER" -eq 0 ] && [ "$RUN_GRADED" -gt 0 ] \
    && [ "$M3_RUN_FAIL" -eq 0 ] && [ "$M3_RUN_CRASH" -eq 0 ] && [ "$M3_RUN_HANG" -eq 0 ] \
    && [ "$M4_RUN_FAIL" -eq 0 ] && [ "$M4_RUN_CRASH" -eq 0 ] && [ "$M4_RUN_HANG" -eq 0 ]
