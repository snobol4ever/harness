#!/usr/bin/env bash
S4E_ONE_RUNNER_SINGLE_FILE=""; _sf_prev=""; for _sf_a in "$@"; do [ "$_sf_prev" = --driver ] && S4E_ONE_RUNNER_SINGLE_FILE="$_sf_a"; _sf_prev="$_sf_a"; done; source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${GNU_PROLOG_SUITE:=${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}/corpus/packages/prolog/gnu_prolog}" || exit 2
# test_prolog_gnu_suite.sh -- grades corpus/packages/prolog/gnu_prolog: GNU Prolog's OWN vendored
# compiler/library source (62 .pl files -- BipsPl/ = the built-in-predicates library, Pl2Wam/ = the
# Prolog-to-WAM compiler), NOT test programs. There is no external .ref oracle for these files; the
# earlier row `audit-corpus-what-is-ungated` found ZERO runner existed at all and ruled the fix:
# name every file, glob the runnable remainder, NEVER blanket-exclude the directory -- "a blanket
# exclusion and a named list give the same number today and different numbers forever after,
# permanently hiding the parse errors and the live files" (that file's own §2 CATEGORY 3 ruling).
# Per that same warning, this runner does NOT hardcode a file list either -- every run CLASSIFIES
# LIVE via the actual compile-probe signal, so it self-corrects if the vendored files or SCRIP's own
# frontend ever change, instead of silently drifting stale like a cached list would.
#
# THREE LIVE-DERIVED BUCKETS (never a fixed count -- see the classification loop for the exact rule):
#   LIB      -- ⚖️ RE-KEYED by hq_C ruling 2026-09-02 (row prolog-gnu-conformance-ok-fail-print-zero-
#               bytes-both-modes): classified by a PROPERTY OF THE FILE, checked BEFORE any SCRIP
#               invocation -- (1) it contains a GNU-Prolog-internal bootstrap-only directive
#               ($call_c/$call_c_test/$call_c_jump/ensure_linked/built_in), or (2) it is one of two
#               individually-named non-program drivers (Pl2Wam/all.pl, Pl2Wam/whole.pl -- see
#               is_bootstrap_only() below for why). The ORIGINAL key was `./scrip --compile` reaching
#               exactly "[IBB] FATAL: mode-4 driver: main BB graph not found" -- a SCRIP FAILURE
#               SIGNAL, not a file property, so it silently re-classified when commit 3ce7a526 gave
#               SCRIP a universal entry-point synthesis and made that signal structurally unreachable
#               (45 LIB files fell into OK overnight with no corpus or suite change at all). The old
#               rc==1 signal check below is left in place as a dormant fallback, not the key.
#   OK       -- `./scrip --compile` succeeds (rc=0, the file carries its own `:- initialization(...)`
#               directive). Run-graded, triangulated three ways: SCRIP m3 (--run), SCRIP m4
#               (--compile, link, execute), and real `gprolog`, all invoked with ZERO command-line
#               arguments (matching how every other suite runner in this repo invokes a file). These
#               files are GNU Prolog's own compiler-driver entry points and no-op on an empty
#               argument_list (e.g. Pl2Wam/ciaolib.pl's `go_other1([]) :- !.` clause), so they print
#               0 bytes in all three arms. ⛔ AN EMPTY AGREEMENT IS NOT A PASS (Lon 2026-10-05 via the
#               ceo, CEO-1523): it proves only that the file loads, so it is UNGRADED, named in
#               UNGRADED.tsv, owed its driver; a PASS needs m3 = m4 = gprolog AND a non-empty output.
#   REJECT   -- times out. A real, ALREADY-KNOWN class (`misc-single-witness-parser-crashes`' own
#               claim: these hang after a parse-error, a defect in error recovery, not a fresh bug).
#               Documented here, not graded PASS/FAIL, not counted against the exit code.
#   UNEXPECTED -- anything that is none of the above (a rc outside {0,1}, or an rc=1 whose output does
#               NOT contain the LIB signal). Loudly flagged and FAILS the gate -- a genuinely new
#               failure shape must never be silently folded into LIB or REJECT.
#
# AUTHORS: seat05, 2026-08-30 (Lon direct via ceo, row gnu-prolog-suite-runner-and-score)
#
# ⭐ --driver REL.pl GRADES ONE DRIVEN LIBRARY THE BOARD'S WAY (the cfo, 2026-10-14, ceo CEO-1727: "a row's criterion grades the way the
# board grades, ruled exclusions included ... through the runner, never a second copy of drop_excluded_lines"). REL.pl is the library as
# the board names it (BipsPl/flag.pl); the loop below runs for that file alone -- its driver, m3, m4, live gprolog, the stale-ref check
# and EXCLUDED_LINES.tsv -- writes no progress row and no score row (lib_one_runner.sh admits it for every seat, as the SWI runner's
# --file), and prints one labelled line, GNU_DRIVER rel=REL.pl verdict=PASS|FAIL|TIMEOUT|EXCLUDED m3_differ=N m4_differ=N: rc 0 PASS or
# EXCLUDED (a container, EXCLUDED.tsv or UNGRADABLE.tsv names it, as the board leaves it out), 1 FAIL, 2 could not measure.
set -uo pipefail   # deliberately NOT -e: a per-file compile/run failure is DATA the board must finish
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib_oracle_flags.sh"
                   # printing, never a reason to abort the whole sweep partway through

S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/lib_progress.sh" ] && . "$HERE/lib_progress.sh"   # CEO-331: a runner that grades with its OWN loop appends its own rows
. "$HERE/lib_flag_gate.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: lib_flag_gate.sh unloadable"; exit 2; }
. "$HERE/lib_inventory.sh" 2>/dev/null || { echo "⛔ REFUSED-TO-GRADE: lib_inventory.sh unloadable"; exit 2; }
ONLY_DRIVER=""
while [ $# -gt 0 ]; do
    case "$1" in
        --driver) [ $# -ge 2 ] || flaggate_reject "$1" "--driver REL.pl (one driven library, as the board names it)"; ONLY_DRIVER="$2"; shift 2 ;;
        *) flaggate_reject "$1" "--driver REL.pl, or none (set GNU_SUITE_VERBOSE / GNU_SUITE_CLASSIFY_TIMEOUT / GNU_SUITE_RUN_TIMEOUT via environment instead)" ;;
    esac
done
SCRIP="${HERE}/../../SCRIP/scrip"
RT_SO="${HERE}/../../SCRIP/out/libscrip_rt.so"
PKG="${GNU_PROLOG_SUITE:-$S4E/corpus/packages/prolog/gnu_prolog}"   # line 2 sets it to this default, so the guard judges the suite graded here
CLASSIFY_TIMEOUT="${GNU_SUITE_CLASSIFY_TIMEOUT:-10}"
RUN_TIMEOUT="${GNU_SUITE_RUN_TIMEOUT:-15}"
GPROLOG_BIN="$(gprolog_bin 2>/dev/null || true)"
VERBOSE="${GNU_SUITE_VERBOSE:-0}"

# Named individually per the ruling (neither contains a bootstrap-only directive, so the content
# grep below can't catch them): Pl2Wam/all.pl is a bare sequence of `:- include(...)` directives
# concatenating the other Pl2Wam sources, with its one real `:- initialization(go).` line commented
# out in this vendored copy; Pl2Wam/whole.pl's `:- include(bip_list).` names a file absent from this
# vendored subset (a corpus completeness gap, tracked separately -- see handoff/ledger, not fixed here).
BOOTSTRAP_ONLY_NAMED=("Pl2Wam/all.pl" "Pl2Wam/whole.pl")

is_bootstrap_only() {  # $1 = rel path (for the named list), $2 = full path (for the content grep)
    local rel="$1" f="$2" n
    for n in "${BOOTSTRAP_ONLY_NAMED[@]}"; do [ "$rel" = "$n" ] && return 0; done
    grep -qE '\$call_c|ensure_linked|built_in' "$f"
}

[ -d "$PKG" ]        || { echo "⛔ REFUSED-TO-GRADE: $PKG missing"; exit 2; }
[ -x "$SCRIP" ]      || { echo "⛔ REFUSED-TO-GRADE: scrip not built"; exit 2; }
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). The line above proves a binary EXISTS; this one proves it is the binary this
# tree describes. ceo's witness, twice on 2026-09-04: a 10:57 binary graded at 14:03 read RED, then GREEN after
# an incremental make -- a vendor board is exactly where that is least visible, because a plausible all-FAIL
# table is this class's normal output. NO LOGIC HERE: util_require_fresh.sh sources gate_require_fresh from
# lib_gate.sh, the ONE authority (hq_B 4c7253e99) -- never a second copy of the staleness rule.
"$HERE/util_require_fresh.sh" --gate test_prolog_gnu_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
[ -f "$RT_SO" ]      || { echo "⛔ REFUSED-TO-GRADE: $RT_SO missing (m4 link needs it)"; exit 2; }
[ -n "$GPROLOG_BIN" ] || { echo "⛔ REFUSED-TO-GRADE: gprolog not on PATH"; exit 2; }

TMP="$(mktemp -d /tmp/gnu_suite_XXXXXX)"
trap 'rm -rf "$TMP"' EXIT
# ⭐ THE DECLARED HEAP AND STACK (Lon 2026-09-23 18:3x; CEO-1167, CEO-1225; wired by the coo on CEO-1229, the SWI runner's pattern):
# each file runs in BOTH modes at what its row in ALL.csv declares (entry = its path under the package without .pl) -- heap_kb,
# stack_kb, read once through lib_declared_arena.sh, the one reader -- and at the shipped default when it declares nothing; a refused
# cell refuses the board. The classifying compile and the gprolog oracle run as before.
. "$HERE/lib_declared_arena.sh" || { echo "⛔ REFUSED-TO-GRADE: lib_declared_arena.sh unloadable -- the one reader of a declared heap and stack"; exit 2; }
DECL="$TMP/declared_memory.tsv"
declared_memory_begin "$PKG/ALL.csv" "$DECL" || { echo "⛔ REFUSED-TO-GRADE: a declared-memory cell in $PKG/ALL.csv is refused (named above) -- fix the cell; this board does not grade around it"; exit 2; }

# gprolog_out FILE: the oracle's stdout for a consulted file, its banner and its own compile diagnostics stripped -- ONE filter,
# used by the driver arm and the ref cut alike (the non-driven arm below keeps its historical copy until no file needs it).
# gprolog_out FILE [STDIN [ARG...]]: a driver's sidecars (below) ride on the oracle's run exactly as on SCRIP's -- its standard input, and
# its arguments after --, which gprolog hands to argument_list/1.
gprolog_out() { local _f="$1" _in="${2:-/dev/null}"; if [ $# -ge 2 ]; then shift 2; else shift $#; fi
    cd "$TMP" && "$TIMEOUT_RETRY" "$RUN_TIMEOUT" "$GPROLOG_BIN" --consult-file "$_f" --query-goal halt ${1+--} "$@" < "$_in" 2>/dev/null \
    | gprolog_output_filter --compile-diagnostics; }
# ⛔ ONE FIXED-PATH DRIVER AT A TIME ON THE BOX (the coo 2026-10-17, on the cfo's catch, CEO-1810): ten drivers make and remove a fixed /tmp/gnu_drv_*
# path (dec10io, char_io, consult, os_interf, pl_error, read, sockets, src_rdr, stream, utils), and two runs of one at once -- another seat's pass or gate
# beside the coo's -- disagree with the ref for a reason that is neither program's: the loop's pass at 371ce73cc refused on os_interf "differs from live
# gprolog" while live gprolog alone matched that ref three runs of three. drv_lock FILE holds one box-wide lock across a driver's runs (SCRIP m3, m4,
# gprolog, or a ref cut) when FILE names such a path; a wait past GNU_DRV_LOCK_WAIT seconds (600) runs it unlocked and says so; drv_unlock releases it.
DRV_LK=""
drv_lock() { DRV_LK=""; grep -q '/tmp/gnu_drv' "$1" 2>/dev/null || return 0
    exec {DRV_LK}> "${GNU_DRV_LOCK:-/tmp/gnu_drv.lock}" || { DRV_LK=""; return 0; }
    flock -w "${GNU_DRV_LOCK_WAIT:-600}" "$DRV_LK" || echo "  GNU_DRV_LOCK not taken in ${GNU_DRV_LOCK_WAIT:-600} s -- ${1#"$PKG"/} runs unlocked"; }
drv_unlock() { [ -n "$DRV_LK" ] && exec {DRV_LK}>&-; DRV_LK=""; }
# ⭐ GNU_SUITE_CUT_REFS=1 CUTS EVERY DRIVER'S REF FROM gprolog AND GRADES NOTHING (no row, no progress append): NAME_driver.ref is
# the oracle's answer as recorded evidence, cut by the same filter the board compares through; a driver gprolog answers with
# nothing refuses, because an empty ref grades nothing (THE PACKAGE LOCKDOWN).
if [ "${GNU_SUITE_CUT_REFS:-0}" = 1 ]; then
    n=0; while IFS= read -r d; do
        _ca=(); [ -f "${d%.pl}.argv" ] && read -r -a _ca < "${d%.pl}.argv"; _ci=/dev/null; [ -f "${d%.pl}.in" ] && _ci="${d%.pl}.in"
        drv_lock "$d"; o="$(gprolog_out "$d" "$_ci" "${_ca[@]}")"; drv_unlock; [ -n "$o" ] || { echo "⛔ REFUSED: ${d#"$PKG"/} prints nothing in gprolog -- no ref written"; exit 2; }
        printf '%s\n' "$o" > "${d%.pl}.ref"; n=$((n+1)); echo "  cut ${d#"$PKG"/} -> $(printf '%s\n' "$o" | wc -l) line(s)"
    done < <(find "$PKG" -name "*_driver.pl" | sort)
    echo "GNU driver refs cut from gprolog: $n"; exit 0
fi
mapfile -t FILES < <(find "$PKG" -name "*.pl" ! -name "*_driver.pl" | sort)
D_V=""; D_M3=""; D_M4=""
if [ -n "$ONLY_DRIVER" ]; then
    [ -f "$PKG/$ONLY_DRIVER" ] || { echo "⛔ REFUSED-TO-GRADE: --driver $ONLY_DRIVER is no file of $PKG"; exit 2; }
    [ -f "$PKG/${ONLY_DRIVER%.pl}_driver.pl" ] || { echo "⛔ REFUSED-TO-GRADE: --driver $ONLY_DRIVER has no ${ONLY_DRIVER%.pl}_driver.pl beside it"; exit 2; }
    FILES=("$PKG/$ONLY_DRIVER")
    progress_append() { :; }   # one driver is not a board: no progress row
fi
# ⭐ THE ROUND ROBIN'S SEAM (ceo CEO-1806/1812, as test_prolog_bench_suite.sh): under S4E_CHUNK=entry:<dir/stem>[,...] (PARTITION.tsv's keys) only those programs
# are graded and their rows appended, and no suite row is written (rr_end) -- one program at a time, re-graded after each fix (Lon 2026-10-23, CEO-1926)
. "$HERE/lib_rr.sh" && rr_load "$PKG" || exit 2
if rr_selected; then _fs=(); for f in "${FILES[@]}"; do _r="${f#"$PKG"/}"; rr_admits "${_r%.pl}" && _fs+=("$f"); done; FILES=(${_fs[@]+"${_fs[@]}"}); fi
TOTAL=${#FILES[@]}
[ "$TOTAL" -gt 0 ] || { echo "⛔ REFUSED-TO-GRADE: zero .pl files found under $PKG"; exit 2; }

LIB=0; OK_TOTAL=0; OK_PASS=0; OK_FAIL=0; OK_TIMEOUT=0; REJECT=0; UNEXPECTED=0; LADDER=0; EMPTY=0; CON_N=0; DRIVEN=0; UGB=0; EXN=0
UNEXPECTED_NAMES=(); REJECT_NAMES=(); OK_FAIL_NAMES=(); OK_TIMEOUT_NAMES=(); EMPTY_NAMES=(); SIDE_ERR=()
# ⛔⭐ THE ROW IS PUBLISHED OVER THE SHIPPED POPULATION, AND AN EMPTY OUTPUT GRADES NOTHING (Lon 2026-10-05, in-chat to the ceo, verbatim:
# "What's up with \"GNU source\" test suite entry? Is that real? Did you write drivers for all those?"; ceo CEO-1523). The row read 11/11:
# the 11 files that compile print 0 bytes in m3, m4 and gprolog with zero arguments, so their three-way agreement proved only that they
# load, and the 45 libraries owed their drivers since CEO-1312 were not in the denominator at all. Now: population = the shipped .pl files
# less the CONTAINERS.tsv rows (excluded, the Excl column, CEO-1288); a program PASSES only when m3 = m4 = gprolog AND that output is not
# empty; an empty three-way agreement and a library are UNGRADED and must each be NAMED in UNGRADED.tsv -- the board refuses an unnamed one
# and a stale row (a named program that now grades, or names no shipped file).
declare -A CON_SET=() UNG_SET=() UGB_SET=() EX_SET=()
if [ -f "$PKG/CONTAINERS.tsv" ]; then
    while IFS=$'\t' read -r _cn _rest; do case "$_cn" in ''|'#'*) continue;; esac
        [ -f "$PKG/$_cn" ] || { echo "⛔ REFUSED-TO-GRADE: CONTAINERS.tsv names $_cn, which this package does not ship"; exit 2; }
        CON_SET[$_cn]=1; CON_N=$((CON_N+1)); done < "$PKG/CONTAINERS.tsv"
fi
if [ -f "$PKG/UNGRADED.tsv" ]; then
    while IFS=$'\t' read -r _un _uc _rest; do case "$_un" in ''|'#'*) continue;; esac
        [ -f "$PKG/$_un" ] || { echo "⛔ REFUSED-TO-GRADE: UNGRADED.tsv names $_un, which this package does not ship"; exit 2; }
        UNG_SET[$_un]="${_uc:-NEEDS_DRIVER}"; done < "$PKG/UNGRADED.tsv"
fi
# ⛔⭐ A FILE THE ORACLE GIVES NO ANSWER FOR IS NAMED IN UNGRADABLE.tsv AND STAYS IN THE DENOMINATOR AS DEBT (the coo 2026-10-10, row
# prolog-gnu-every-prolog-source-file-...-ceo-1312; CEO-749, CEO-1286, CEO-1588 (a)). Measured: six of the 55 cannot be driven against
# gprolog -- ciaolib.pl and whole.pl and foreign.pl fail its compile, no_le_interf.pl and no_sockets.pl are stubs this build links other
# files in place of, top_level.pl reads its queries from a terminal. Each gets one UNGRADED progress row per mode whose note is its class
# (the container runner's shape, lib_container_package_runner.sh), is never compiled or run here, and a driver beside it is a stale row.
if [ -f "$PKG/UNGRADABLE.tsv" ]; then
    while IFS=$'\t' read -r _gn _gc _rest; do case "$_gn" in ''|'#'*) continue;; esac
        [ -f "$PKG/$_gn" ] || { echo "⛔ REFUSED-TO-GRADE: UNGRADABLE.tsv names $_gn, which this package does not ship"; exit 2; }
        UGB_SET[$_gn]="$_gc"; done < "$PKG/UNGRADABLE.tsv"
fi
# ⛔⭐ ... AND SINCE CEO-1696 IT LEAVES THE DENOMINATOR (Lon 2026-10-11 16:0x CDT, in-chat to the ceo, verbatim: "Exclude any program in which we
# have no way to get output from an oracle, or in which we do not know the answer."; RULES.md FACT RULE A PROGRAM WITH NO ORACLE ANSWER IS
# EXCLUDED, NEVER DEBT): each UNGRADABLE.tsv row keeps the oracle's measurement and an EXCLUDED.tsv row of class NO_ORACLE_ANSWER carries it
# verbatim; a file EXCLUDED.tsv names is out of the population as a container is, shown in Excl beside the containers, and writes no row.
# Read through lib_inventory.sh's one reader, which refuses a malformed row or an unknown class.
_exn="$(inventory_excluded_names "$PKG")" || { echo "⛔ REFUSED-TO-GRADE: $PKG/EXCLUDED.tsv is refused (the reader said why above)"; exit 2; }
while IFS= read -r _en; do [ -n "$_en" ] || continue
    [ -f "$PKG/$_en" ] || { echo "⛔ REFUSED-TO-GRADE: EXCLUDED.tsv names $_en, which this package does not ship"; exit 2; }
    EX_SET[$_en]=1; done <<< "$_exn"
declare -A LADDER_RUNG_COUNT LADDER_RUNG_NAMES
# ⛔⭐ AN EXCLUDED LINE IS NAMED, WITH ITS RULING (ceo CEO-1527 (a), 2026-10-06: SCRIP's integers are unbounded like SWI's, so
# current_prolog_flag(bounded, false) is the answer and gprolog's `true` differs by ruling, not defect: "Name it an excluded line with that
# ruling as its reason, never a row for the cfo"). EXCLUDED_LINES.tsv: name<TAB>line prefix<TAB>ruling. A driver output line that starts with
# the prefix leaves all three outputs before the comparison; the _driver.ref stays gprolog's whole answer. A row whose program is not
# shipped, or whose prefix matches no line of gprolog's live output, is a stale row and refuses the board.
declare -A XL_PFX=() XL_N=()
XL_TOTAL=0
if [ -f "$PKG/EXCLUDED_LINES.tsv" ]; then
    while IFS=$'\t' read -r _xn _xp _xr; do case "$_xn" in ''|'#'*) continue;; esac
        [ -f "$PKG/$_xn" ] || { echo "⛔ REFUSED-TO-GRADE: EXCLUDED_LINES.tsv names $_xn, which this package does not ship"; exit 2; }
        [ -n "$_xp" ] && [ -n "$_xr" ] || { echo "⛔ REFUSED-TO-GRADE: EXCLUDED_LINES.tsv row for $_xn lacks its prefix or its ruling"; exit 2; }
        XL_PFX[$_xn]+="$_xp"$'\n'; XL_TOTAL=$((XL_TOTAL+1)); done < "$PKG/EXCLUDED_LINES.tsv"
fi
drop_excluded_lines() {
    local rel="$1" text="$2"
    [ -n "${XL_PFX[$rel]:-}" ] || { printf '%s' "$text"; return; }
    printf '%s\n' "$text" | awk -v list="${XL_PFX[$rel]}" 'BEGIN{n=split(list,P,"\n")} {for(i=1;i<=n;i++) if(P[i]!="" && index($0,P[i])==1) next; print}'
}

echo "=== GNU Prolog vendored suite ($TOTAL files, $PKG) ==="

for f in "${FILES[@]}"; do
    base="$(basename "$f" .pl)"
    rel="${f#"$PKG"/}"
    # ⭐ THE UNIT'S DECLARED COMPILE SWITCHES (clause 8 (f), CEO-1281): ALL.csv's compile_args, right after --run and --compile in both modes -- the
    # GNU tables declare --dialect=gnu (cfo 2026-10-17, row prolog-gnu-semantics-leak-...-ceo-1810), and this runner types none of its own.
    read -r -a CA <<< "$(declared_compile_args_from_table "$DECL" "${rel%.pl}")"
    export S4E_TIMEOUT_KEY="$rel"   # the unit a retried timeout's stamp names (CEO-1335)
    out="$TMP/${base}.s"
    probe_log="$TMP/${base}.probe"

    if [ -n "${CON_SET[$rel]:-}" ]; then
        [ "$VERBOSE" -eq 1 ] && echo "  CONTAINER (CONTAINERS.tsv, excluded) $rel"
        continue
    fi
    if [ -n "${EX_SET[$rel]:-}" ]; then
        EXN=$((EXN+1))
        [ "$VERBOSE" -eq 1 ] && echo "  EXCLUDED (EXCLUDED.tsv, NO_ORACLE_ANSWER -- ${UGB_SET[$rel]:-no UNGRADABLE.tsv row}) $rel"
        continue
    fi
    # ⛔⭐ A LIBRARY IS GRADED THROUGH ITS DRIVER (Lon 2026-09-27 via the ceo, CEO-1312: "So then create drivers for all the Prolog
    # source"; CEO-700, CEO-1269; the coo's drivers, CEO-1523/1525). NAME_driver.pl beside NAME.pl calls the predicates NAME.pl
    # defines and prints the answers; SCRIP m3, SCRIP m4 and gprolog all run the DRIVER, and the verdict is recorded under the
    # LIBRARY's name, as the arizona, jcon, IPL and gimpel runners record theirs. A BipsPl file is GNU's own built-in source, which
    # neither system can load as user code, so its driver calls the built-ins it defines and gprolog's answer is that file's code.
    # NAME_driver.ref is the oracle's answer as cut (GNU_SUITE_CUT_REFS=1, below): live gprolog that disagrees with it refuses the
    # board as a stale ref, so the stored evidence and the live oracle can never silently part.
    drv="${f%.pl}_driver.pl"
    if [ -n "${UGB_SET[$rel]:-}" ]; then
        UGB=$((UGB+1))
        [ ! -f "$drv" ] || SIDE_ERR+=("$rel has a driver and UNGRADABLE.tsv still names it -- delete the stale row")
        if command -v progress_append >/dev/null 2>&1; then
            progress_append package gnu prolog "$rel" m3 UNGRADED 0 "${UGB_SET[$rel]}" || true
            progress_append package gnu prolog "$rel" m4 UNGRADED 0 "${UGB_SET[$rel]}" || true
        fi
        [ "$VERBOSE" -eq 1 ] && echo "  UNGRADABLE ${UGB_SET[$rel]} (UNGRADABLE.tsv, the oracle's reason) $rel"
        continue
    fi
    if [ -f "$drv" ]; then
        DRIVEN=$((DRIVEN+1)); OK_TOTAL=$((OK_TOTAL+1))
        [ -z "${UNG_SET[$rel]:-}" ] || SIDE_ERR+=("$rel has a driver and UNGRADED.tsv still names it -- delete the stale row")
        dout="$TMP/${base}.drv.s"; dbin="$TMP/${base}.drv.bin"
        # ⭐ A DRIVER'S COMMAND LINE TRAVELS WITH IT (hard-cap clause 8 (f), CEO-1281; the coo 2026-10-10, row -ceo-1312): NAME_driver.argv is
        # one line of the program's own arguments and NAME_driver.in its standard input, beside the driver, fed alike to m3 (after --), to the
        # m4 binary and to gprolog (after --, its argument_list/1). Measured need: Pl2Wam/all.pl is pl2wam, whose own initialization reads
        # argument_list/1 and aborts with none; run as pl2wam user -o user over a fixed input it compiles that input to WAM. A driver with
        # neither sidecar runs exactly as before, on /dev/null with no arguments.
        dargv=(); [ -f "${drv%.pl}.argv" ] && read -r -a dargv < "${drv%.pl}.argv"
        din=/dev/null; [ -f "${drv%.pl}.in" ] && din="${drv%.pl}.in"
        # ⛔ A DRIVER RUNS IN THE SCRATCH DIRECTORY, never in the tree under test: dec10io's tell(user) made a FILE named user in the cwd
        # (a SCRIP defect the driver exposed) and a dirty SCRIP skips every row this pass writes.
        # each mode's own wall for its row (CEO-1676 (c)): m3 its run, m4 the compile, link and run
        drv_lock "$drv"; _t0="$(progress_clock)"
        "$TIMEOUT_RETRY" "$RUN_TIMEOUT" "$SCRIP" --compile "${CA[@]}" "$drv" --out="$dout" < /dev/null > "$probe_log" 2>&1; drc=$?
        _cs="$(progress_secs_since "$_t0")"; _t0="$(progress_clock)"
        m3_out=$(cd "$TMP" && run_at_declared_table "$DECL" "${rel%.pl}" -- "$TIMEOUT_RETRY" "$RUN_TIMEOUT" "$SCRIP" --run "${CA[@]}" "$drv" ${dargv[0]+--} "${dargv[@]}" < "$din" 2>/dev/null); m3rc=$?
        S3="$(progress_secs_since "$_t0")"; _t0="$(progress_clock)"
        m4_out=""; m4rc=0
        if [ "$drc" -eq 0 ] && gcc -no-pie "$dout" -L "${HERE}/../../SCRIP/out" -lscrip_rt -Wl,-rpath,"${HERE}/../../SCRIP/out" -o "$dbin" 2>/dev/null; then
            m4_out=$(cd "$TMP" && run_at_declared_table "$DECL" "${rel%.pl}" -- "$TIMEOUT_RETRY" "$RUN_TIMEOUT" "$dbin" "${dargv[@]}" < "$din" 2>/dev/null); m4rc=$?
        fi
        S4="$(progress_secs_sum "$(progress_secs_since "$_t0")" "$_cs")"
        gp_out=$(gprolog_out "$drv" "$din" "${dargv[@]}"); drv_unlock
        dref="${f%.pl}_driver.ref"
        if [ ! -s "$dref" ]; then SIDE_ERR+=("${dref#"$PKG"/} is missing or empty -- cut it from gprolog (GNU_SUITE_CUT_REFS=1 bash $0) before grading")
        elif [ "$(cat "$dref")" != "$gp_out" ]; then SIDE_ERR+=("${dref#"$PKG"/} differs from live gprolog -- a stale ref; re-cut it (GNU_SUITE_CUT_REFS=1 bash $0)"); fi
        [ -n "$gp_out" ] || SIDE_ERR+=("${drv#"$PKG"/} prints nothing in gprolog -- a driver that prints nothing grades nothing")
        if [ -n "${XL_PFX[$rel]:-}" ]; then
            while IFS= read -r _xp; do [ -n "$_xp" ] || continue
                printf '%s\n' "$gp_out" | awk -v p="$_xp" 'index($0,p)==1{f=1} END{exit !f}' || SIDE_ERR+=("EXCLUDED_LINES.tsv prefix '$_xp' for $rel matches no line of live gprolog -- a stale row")
                XL_N[$rel]=$((${XL_N[$rel]:-0}+1)); done <<< "${XL_PFX[$rel]}"
            gp_out=$(drop_excluded_lines "$rel" "$gp_out"); m3_out=$(drop_excluded_lines "$rel" "$m3_out"); m4_out=$(drop_excluded_lines "$rel" "$m4_out")
        fi
        if [ "$m3_out" = "$gp_out" ] && [ "$m4_out" = "$gp_out" ]; then _gv=PASS; else _gv=FAIL; fi
        D_V=$_gv; D_M3=$(diff <(printf '%s\n' "$gp_out") <(printf '%s\n' "$m3_out") | grep -c '^>'); D_M4=$(diff <(printf '%s\n' "$gp_out") <(printf '%s\n' "$m4_out") | grep -c '^>')
        # ⛔ A TIMEOUT UNDER LOAD IS A TIMEOUT, NEVER A FAIL (ceo CEO-1686, CEO-1574's load-guard rule for every runner; the coo 2026-10-11): at
        # load 20-30 five driver compiles read rc 124 on 966109bb9 (Pl2Wam/all.pl among them with 0 of 201 lines differing) and the row fell
        # 18 -> 17 on a reading of the box, not the program. A driver whose compile or run answered 124 -- after util_timeout_retry.sh's own
        # retry -- while the 1-minute load is at or above the cores is COULD NOT MEASURE: named with the load, recorded UNGRADED, outside pass
        # and fail, and the suite row is not written from such a pass. At a load under the cores a 124 stays the program's FAIL.
        if [ "$_gv" = FAIL ] && { [ "$drc" -eq 124 ] || [ "$m3rc" -eq 124 ] || [ "$m4rc" -eq 124 ]; }; then
            _l1="${GNU_SUITE_LOAD1:-$(cut -d' ' -f1 /proc/loadavg 2>/dev/null || echo 0)}"; _nc="$(nproc 2>/dev/null || echo 1)"   # GNU_SUITE_LOAD1: a fixture's load
            if awk -v l="$_l1" -v n="$_nc" 'BEGIN { exit !(l + 0 >= n + 0) }'; then
                D_V=TIMEOUT; OK_TIMEOUT=$((OK_TIMEOUT+1)); OK_TIMEOUT_NAMES+=("$rel (compile rc $drc, m3 rc $m3rc, m4 rc $m4rc at load1 $_l1 on $_nc cores)")
                echo "  DRIVEN TIMEOUT $rel -- compile rc $drc, m3 rc $m3rc, m4 rc $m4rc at load1 $_l1 on $_nc cores: could not measure (CEO-1686), not a FAIL"
                if command -v progress_append >/dev/null 2>&1; then
                    progress_append package gnu prolog "$rel" m3 UNGRADED "$S3" "timeout-under-load load1=$_l1 cores=$_nc" || true
                    progress_append package gnu prolog "$rel" m4 UNGRADED "$S4" "timeout-under-load load1=$_l1 cores=$_nc" || true
                fi
                continue
            fi
        fi
        if command -v progress_append >/dev/null 2>&1; then
            progress_append package gnu prolog "$rel" m3 "$([ "$m3_out" = "$gp_out" ] && echo PASS || echo FAIL)" "$S3" "driver ${base}_driver.pl vs gprolog" || true
            progress_append package gnu prolog "$rel" m4 "$([ "$m4_out" = "$gp_out" ] && echo PASS || echo FAIL)" "$S4" "driver ${base}_driver.pl vs gprolog" || true
        fi
        if [ "$_gv" = PASS ]; then
            OK_PASS=$((OK_PASS+1))
            [ "$VERBOSE" -eq 1 ] && echo "  DRIVEN PASS $rel (m3 = m4 = gprolog, $(printf '%s' "$gp_out" | wc -l) lines)"
        else
            OK_FAIL=$((OK_FAIL+1)); OK_FAIL_NAMES+=("$rel(driver)")
            echo "  DRIVEN FAIL $rel -- driver compile rc=$drc; lines differing from gprolog: m3 $(diff <(printf '%s\n' "$gp_out") <(printf '%s\n' "$m3_out") | grep -c '^>') m4 $(diff <(printf '%s\n' "$gp_out") <(printf '%s\n' "$m4_out") | grep -c '^>') of $(printf '%s\n' "$gp_out" | wc -l)"
        fi
        continue
    fi
    if is_bootstrap_only "$rel" "$f"; then
        LIB=$((LIB+1))
        [ -n "${UNG_SET[$rel]:-}" ] || SIDE_ERR+=("$rel is a library (no entry point) and UNGRADED.tsv does not name it NEEDS_DRIVER")
        # the note is the work owed: a library still owed its driver keeps the note it has carried since CEO-1523; a file owed something
        # else (all.pl, NEEDS_ARGV_FIXTURE) carries its UNGRADED.tsv class, as the container runner's rows do
        _ln="library-needs-driver"; [ "${UNG_SET[$rel]:-NEEDS_DRIVER}" = NEEDS_DRIVER ] || _ln="${UNG_SET[$rel]}"
        if command -v progress_append >/dev/null 2>&1; then
            progress_append package gnu prolog "$rel" m3 UNGRADED 0 "$_ln" || true
            progress_append package gnu prolog "$rel" m4 UNGRADED 0 "$_ln" || true
        fi
        [ "$VERBOSE" -eq 1 ] && echo "  LIB (bootstrap-only file, no SCRIP invocation) $rel"
        continue
    fi

    _t0="$(progress_clock)"
    "$TIMEOUT_RETRY" "$CLASSIFY_TIMEOUT" "$SCRIP" --compile "${CA[@]}" "$f" --out="$out" < /dev/null > "$probe_log" 2>&1
    rc=$?; _cs="$(progress_secs_since "$_t0")"   # the classify compile is mode 4's compile: its row carries it (CEO-1676 (c))

    if [ "$rc" -eq 124 ]; then
        REJECT=$((REJECT+1)); REJECT_NAMES+=("$rel")
        [ "$VERBOSE" -eq 1 ] && echo "  REJECT (hang after parse error, known class) $rel"
        continue
    fi

    if [ "$rc" -eq 0 ]; then
        OK_TOTAL=$((OK_TOTAL+1))
        # -- triangulate: SCRIP m3, SCRIP m4 (link+run the .s this classify pass already produced), gprolog --
        _t0="$(progress_clock)"
        m3_out=$(run_at_declared_table "$DECL" "${rel%.pl}" -- "$TIMEOUT_RETRY" "$RUN_TIMEOUT" "$SCRIP" --run "${CA[@]}" "$f" < /dev/null 2>/dev/null)
        S3="$(progress_secs_since "$_t0")"; _t0="$(progress_clock)"
        bin="$TMP/${base}.bin"
        m4_out=""
        if gcc -no-pie "$out" -L "${HERE}/../../SCRIP/out" -lscrip_rt -Wl,-rpath,"${HERE}/../../SCRIP/out" -o "$bin" 2>/dev/null; then
            m4_out=$(run_at_declared_table "$DECL" "${rel%.pl}" -- "$TIMEOUT_RETRY" "$RUN_TIMEOUT" "$bin" < /dev/null 2>/dev/null)
        fi
        S4="$(progress_secs_sum "$(progress_secs_since "$_t0")" "$_cs")"
        # ⛔⭐ --init-goal RUNS *BEFORE* --consult-file, SO THE FILE'S OWN `:- initialization(...)`
        # DIRECTIVE NEVER FIRES (verified by hand: --init-goal halt produces silent empty output on a
        # file proven, by a separate plain-consult run, to print real text on init -- the exact
        # "oracle answers when it should refuse" shape this project keeps re-discovering, this time in
        # a fresh binary rather than a fresh flag). The correct, ALREADY-PROVEN invocation lives in
        # test_bench_prolog_modes.sh: --query-goal (runs AFTER consult, so the file's own
        # initialization has already executed) + an explicit banner-strip, reused verbatim rather than
        # re-derived, since it is already battle-tested.
        gp_raw=$("$TIMEOUT_RETRY" "$RUN_TIMEOUT" "$GPROLOG_BIN" --consult-file "$f" --query-goal halt < /dev/null 2>/dev/null)
        # ⛔⭐ THE OLD `^error:`/`^warning:` ANCHORS NEVER MATCHED A REAL GPROLOG LINE (row
        # prolog-gnu-suite-ciaolib-use-module-warning): gprolog's own compile-time diagnostics are
        # prefixed `<path>:<line>[-<line>]: warning: ...` / `<path>:<line>[-<line>]: fatal error: ...`
        # -- never bare `warning:`/`error:` at column 0 -- so EVERY file where gprolog warns (an
        # unrecognized directive, e.g. `use_module/1`) or hard-fails to compile (e.g. `use_module/2`
        # with a non-atom module term, or a bootstrap-only `$call_c`/`$call_c_test` builtin) leaked
        # gprolog's own tooling chatter into gp_out as if it were program output. Measured: 41 of 62
        # files in this suite were OK_FAIL for exactly this reason (m3=m4=0B, gprolog non-zero), all
        # of it gprolog's own diagnostic text, not a real SCRIP divergence -- see the FINDING for the
        # full board before/after. Matched by line-number prefix instead of line start; the trailing
        # summary line gets its own literal match since it carries no line number.
        gp_out=$(printf '%s\n' "$gp_raw" | gprolog_output_filter --compile-diagnostics)

        # ⛔⭐ CEO-331: one progress row per program per mode, from a runner that grades with its OWN loop (the coverage
        # report read gnu as MISSING, 0 of 62). ⛔ THIS SUITE'S VERDICT IS A THREE-WAY AGREEMENT m3=m4=gprolog, so a
        # per-MODE outcome cannot be derived from it without lying about what was compared -- a mode is not graded
        # independently here. Both rows carry the SAME agreement verdict and the note names the comparison, rather than
        # inventing a per-mode result the runner never computed.
        if [ "$m3_out" = "$m4_out" ] && [ "$m4_out" = "$gp_out" ] && [ -z "$m3_out" ]; then
            EMPTY=$((EMPTY+1)); EMPTY_NAMES+=("$rel")
            [ -n "${UNG_SET[$rel]:-}" ] || SIDE_ERR+=("$rel prints 0 bytes in m3, m4 and gprolog and UNGRADED.tsv does not name it -- an empty output grades nothing")
            if command -v progress_append >/dev/null 2>&1; then
                progress_append package gnu prolog "$rel" m3 UNGRADED 0 "empty-output-grades-nothing" || true
                progress_append package gnu prolog "$rel" m4 UNGRADED 0 "empty-output-grades-nothing" || true
            fi
            continue
        fi
        [ -z "${UNG_SET[$rel]:-}" ] || SIDE_ERR+=("$rel is named in UNGRADED.tsv and now grades with output -- delete the stale row")
        if command -v progress_append >/dev/null 2>&1; then
            if [ "$m3_out" = "$m4_out" ] && [ "$m4_out" = "$gp_out" ]; then _gv=PASS; else _gv=FAIL; fi
            progress_append package gnu prolog "$rel" m3 "$_gv" "$S3" "three-way m3=m4=gprolog" || true
            progress_append package gnu prolog "$rel" m4 "$_gv" "$S4" "three-way m3=m4=gprolog" || true
        fi
        if [ "$m3_out" = "$m4_out" ] && [ "$m4_out" = "$gp_out" ]; then
            OK_PASS=$((OK_PASS+1))
            [ "$VERBOSE" -eq 1 ] && echo "  OK PASS $rel (m3=m4=gprolog, $(printf '%s' "$m3_out" | wc -c) bytes)"
        else
            OK_FAIL=$((OK_FAIL+1)); OK_FAIL_NAMES+=("$rel")
            echo "  OK FAIL $rel -- m3/$( printf '%s' "$m3_out" | wc -c)B m4/$( printf '%s' "$m4_out" | wc -c)B gprolog/$( printf '%s' "$gp_out" | wc -c)B disagree"
            if [ "$VERBOSE" -eq 1 ]; then
                echo "    m3:      $(printf '%s' "$m3_out" | head -c 200)"
                echo "    m4:      $(printf '%s' "$m4_out" | head -c 200)"
                echo "    gprolog: $(printf '%s' "$gp_out" | head -c 200)"
            fi
        fi
        continue
    fi

    # rc == 2 with the ladder-refusal shape (lower_prolog.c pl_refuse()): a construct not yet built on
    # the construct ladder. Named and counted by rung for diagnostic visibility, and the RUNG ITSELF is
    # never cured here -- a fleet seat never touches a rung (RULES.md sec THE PROLOG REBUILD GATE;
    # ARCH-PROLOG-BYRD-BOX-TRANSLATION.md sec E). ⛔ BUT per lib_inventory.sh's ARM 8 ("a program the
    # ORACLE grades and WE do not is GRADED and RED, never removed from the denominator"): gprolog can
    # run every one of these files, so a ladder gap is OUR compiler's gap, not an oracle ruling or an
    # owed-ref-cutting task -- excluding it from OK_TOTAL was a red moved out of the denominator one
    # level up from the case ARM 8 was written for. It counts as an ordinary OK/FAIL entry; SCRIP's own
    # refusal to lower the construct is itself the divergence from gprolog's real output, so there is
    # nothing left to triangulate.
    rung="$(grep -oP 'is not on the ladder yet -- rung \K[0-9]+' "$probe_log" | head -1)"
    if [ "$rc" -eq 2 ] && [ -n "$rung" ]; then
        LADDER=$((LADDER+1))
        LADDER_RUNG_COUNT[$rung]=$(( ${LADDER_RUNG_COUNT[$rung]:-0} + 1 ))
        LADDER_RUNG_NAMES[$rung]="${LADDER_RUNG_NAMES[$rung]:-}${LADDER_RUNG_NAMES[$rung]:+ }$rel"
        OK_TOTAL=$((OK_TOTAL+1)); OK_FAIL=$((OK_FAIL+1)); OK_FAIL_NAMES+=("$rel(ladder rung $rung)")
        [ "$VERBOSE" -eq 1 ] && echo "  OK FAIL (ladder rung $rung not built yet, SCRIP cannot lower this construct) $rel"
        continue
    fi

    # rc == 1 (or any other non-timeout, non-zero code): must be exactly the LIB signal to count as LIB
    if grep -q "\[IBB\] FATAL: mode-4 driver: main BB graph not found" "$probe_log"; then
        LIB=$((LIB+1))
        [ "$VERBOSE" -eq 1 ] && echo "  LIB (no entry point, compile-graded) $rel"
    else
        UNEXPECTED=$((UNEXPECTED+1)); UNEXPECTED_NAMES+=("$rel (rc=$rc)")
        echo "  ⛔ UNEXPECTED $rel -- rc=$rc, not the known LIB/OK/REJECT shape:"
        sed 's/^/      /' "$probe_log" | head -5
    fi
done

echo ""
echo "-- REJECT (known hang-after-parse-error class, misc-single-witness-parser-crashes -- documented, not graded): $REJECT --"
for n in "${REJECT_NAMES[@]:-}"; do [ -n "$n" ] && echo "   $n"; done

echo ""
echo "-- LADDER (construct not yet on the ladder -- a SUBSET of OK_FAIL above, named by rung for diagnostic visibility; the rung itself is never cured by a fleet seat, RULES.md sec THE PROLOG REBUILD GATE): $LADDER --"
for rung in $(printf '%s\n' "${!LADDER_RUNG_COUNT[@]}" | sort -n); do
    echo "   rung $rung: ${LADDER_RUNG_COUNT[$rung]} --${LADDER_RUNG_NAMES[$rung]}"
done

if [ "$UNEXPECTED" -gt 0 ]; then
    echo ""
    echo "-- UNEXPECTED (genuinely new failure shape, not LIB/OK/REJECT -- needs investigation): $UNEXPECTED --"
    for n in "${UNEXPECTED_NAMES[@]}"; do echo "   $n"; done
fi

POP=$((TOTAL - CON_N - EXN))
echo ""
echo "-- EMPTY (m3 = m4 = gprolog = 0 bytes: the file loads and prints nothing, so it grades nothing -- UNGRADED, owed its driver): $EMPTY --"
for n in "${EMPTY_NAMES[@]:-}"; do [ -n "$n" ] && echo "   $n"; done
if [ "${#SIDE_ERR[@]}" -gt 0 ]; then
    echo "⛔ REFUSED-TO-GRADE: UNGRADED.tsv disagrees with this run:"; for n in "${SIDE_ERR[@]}"; do echo "   $n"; done; exit 2
fi
if [ -n "$ONLY_DRIVER" ]; then
    if [ -z "$D_V" ] && { [ -n "${CON_SET[$ONLY_DRIVER]:-}" ] || [ -n "${EX_SET[$ONLY_DRIVER]:-}" ] || [ -n "${UGB_SET[$ONLY_DRIVER]:-}" ]; }; then D_V=EXCLUDED; fi
    echo "GNU_DRIVER rel=$ONLY_DRIVER verdict=${D_V:-NONE} m3_differ=${D_M3:-?} m4_differ=${D_M4:-?}"
    echo "SUITES.tsv NOT UPDATED (by design): --driver grades one driver and cannot produce a suite-wide number."
    case "${D_V:-}" in PASS|EXCLUDED) exit 0 ;; FAIL) exit 1 ;; *) exit 2 ;; esac
fi
echo ""
if [ "$OK_TIMEOUT" -gt 0 ]; then
    echo ""
    echo "-- TIMEOUT UNDER LOAD (could not measure, CEO-1686 -- outside pass and fail; the suite row is not written from this pass): $OK_TIMEOUT --"
    for n in "${OK_TIMEOUT_NAMES[@]}"; do echo "   $n"; done
fi
echo "GNU_SUITE_BOARD population=$POP pass=$OK_PASS driven=$DRIVEN excluded=$((CON_N + EXN)) containers=$CON_N no_oracle_answer=$EXN empty=$EMPTY ungradable=$UGB total=$TOTAL lib=$LIB ok=$OK_TOTAL ok_pass=$OK_PASS/$OK_TOTAL ok_fail=$OK_FAIL reject=$REJECT ladder=$LADDER(subset of ok_fail) unexpected=$UNEXPECTED timeout_under_load=$OK_TIMEOUT"
if rr_selected; then rr_end gnu; [ "$OK_FAIL" -eq 0 ] && [ "$UNEXPECTED" -eq 0 ] && [ "$OK_TIMEOUT" -eq 0 ] && exit 0; exit 1; fi
# ⭐ THE PACKAGE LOCKDOWN inventory line, via the shared body (lib_inventory.sh) -- never a second copy
# of the arithmetic. LIB (bootstrap/library files, no independent behavior) is a ruling about what the
# file IS, so it is UNGRADABLE/CONTAINER_OR_LIBRARY; REJECT (hang after parse error, a known, filed,
# fixable defect in error recovery) is owed work, so it is UNGRADED/TIMEOUT; OK_TOTAL already includes
# the former LADDER entries per ARM 8 above, so graded_stream is OK_TOTAL with nothing left over.
INV_PACKAGE=gnu_prolog; INV_DIR="$PKG"; INV_EXT=".pl"
INV_LINE="$(inventory_line "$((OK_TOTAL - EMPTY))" 0)"
if [ -n "$INV_LINE" ]; then echo "$INV_LINE"; else echo "⚠ inventory refused (above) -- the board line still stands; the inventory does not" >&2; fi
# ⛔ ONE LEADERBOARD (RULES.md FACT RULE, Lon 2026-09-03 ~16:05: "any run of a test suite by any
# session will update the ONE LEADERBOARD"). This records the board line printed just above into
# .github/SCORE.md -- it RUNS NOTHING, it only writes down what this script already measured.
# ⛔ NON-FATAL BY DESIGN: a bookkeeping failure must never turn a real measurement into a red board,
# because a gate that goes red for a reason unrelated to the code is a gate people route around. It
# warns and names the unrecorded row instead; it has no silent path.
if [ "$OK_TIMEOUT" -gt 0 ]; then
    echo "SUITES.tsv NOT UPDATED: $OK_TIMEOUT driver(s) timed out under load (CEO-1686: a timeout under load is could-not-measure, so this pass is not a reading of the suite) -- re-read on a quieter box"
else
python3 "$HERE/util_score_row.py" write --lang prolog --column vendor --suite GNU --modes m3,m4 \
    --suite-pass "$OK_PASS" --suite-total "$POP" --excluded "$((CON_N + EXN))" ${S4E_CRITERION_CHANGED:+--criterion-changed "$S4E_CRITERION_CHANGED"} \
    --measurer "${S4E_SEAT:-}" --text "PASS $OK_PASS over $POP shipped programs (Excl $((CON_N + EXN)): $CON_N containers, $EXN NO_ORACLE_ANSWER) -- a program passes when m3 = m4 = gprolog and the output is not empty · ungraded $((LIB + EMPTY)) named in UNGRADED.tsv ($LIB libraries, $EMPTY that print nothing) · ungradable $UGB named in UNGRADABLE.tsv with the oracle's reason · ok_fail=$OK_FAIL reject=$REJECT ladder=$LADDER(of ok_fail) unexpected=$UNEXPECTED of total=$TOTAL${INV_LINE:+ · $INV_LINE (\`test_prolog_gnu_suite.sh\`)}" \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
fi


# ⛔⭐ POPULATION FLOOR (row every-board-wrapper-refuses-on-a-zero-population-instead-of-passing-
# vacuously, hq_T 2026-09-04): the bucket-sum check just below PASSES vacuously at TOTAL=0 (0==0),
# and OK_FAIL/UNEXPECTED read 0 too when nothing was discovered -- refuse first.
"$HERE/util_require_population.sh" --gate test_prolog_gnu_suite "$TOTAL" 1 "prolog GNU source files discovered" || exit 2
[ "$((CON_N + EXN + UGB + LIB + OK_TOTAL + REJECT + UNEXPECTED))" -eq "$TOTAL" ] || { echo "⛔ BUCKET COUNTS DON'T SUM TO TOTAL -- instrument bug, refusing to trust the board"; exit 2; }
[ "$OK_FAIL" -eq 0 ] && [ "$UNEXPECTED" -eq 0 ] || exit 1
[ "$OK_TIMEOUT" -eq 0 ] || exit 2   # a pass with a timeout under load and no red is could-not-measure (CEO-1686)
