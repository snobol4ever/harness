#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${DOTNET_SUITE:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/corpus/packages/snobol4/dotnet}" || exit 2
# ⛔ THE STATEMENT INSTRUMENTATION (--stlimit) IS EACH PROGRAM'S OWN compile_args DECLARATION, read per program below (clause 8 (f), CEO-1281): this runner exported SCRIP_SNO_STMTKW=1 for every program until 2026-09-26 (Lon 2026-09-24 16:0x: off by default, never inferred from the source)
# test_snobol4_dotnet_suite.sh -- dedicated gate for corpus/packages/snobol4/dotnet (14 programs),
# minted for row snobol4-gimpel-aisnobol-dotnet-measured-with-dedicated-gates (hq_T 2026-09-03): this
# suite was previously counted only in prose and folded into scorecard_snobol4.sh's MISC bucket
# alongside unrelated test dirs -- a regression here was invisible behind that shared denominator.
# Not folded into scorecard_snobol4.sh's own SUITES table (that file is the SINGLE AUTHORITY other
# scripts extract via SCORECARD_PRINT_SUITES=1; this suite is small enough that a standalone script
# carries far less risk than surgery on a 587-line shared mechanism).
#
# Grading: live oracle diff only (no .ref files exist for this suite) -- SCRIP m3 and m4 output compared
# byte-for-byte against a live SPITBOL (`sbl -bf`) run, same stdin, same scratch cwd, same timeout.
# ⛔ STDOUT ONLY, NEVER 2>&1: two engines that agree on an error still print different diagnostic TEXT
# for it, which would manufacture a FAIL out of an agreement -- see test_snobol4_aisnobol_suite.sh's
# header for the measured example and the prior-art false-disagreement class this avoids.
#
# stdin: none of these 14 ship a same-stem .IN/.in/.input file (checked); every program runs with
# /dev/null on both engines -- still a valid oracle-diff comparison. Several (e.g. palin.sno) use the
# TERMINAL pseudo-variable for interactive I/O rather than INPUT/OUTPUT; this script does not need to
# know that dialect's exact redirection semantics, because both engines receive the identical stream --
# the live-oracle diff is robust to a dialect detail neither of us hand-modeled.
#
# UNSCR (not FAIL): two independent oracle-liveness checks, neither alone is sufficient. (1) sbl_died()
# detects a GRACEFUL fatal-report (banner to STDOUT, exits 0 -- rc alone is not a liveness signal;
# copied from scorecard_snobol4.sh's own check, same convention gimpel already uses). (2) the oracle's
# own exit code >= 128 (killed by a signal) catches the UNGRACEFUL case sbl_died cannot: measured live
# on Test.sno/Test2.sno/SourceLines00{1,2,3}.sno, all five carrying a UTF-8 BOM at byte 0 -- the oracle
# misreads the BOM as part of the first label ("ERROR 214 -- bad label or misplaced continuation line")
# and then SEGFAULTS (rc=139) instead of finishing its normal error report, so it never prints the
# "in statement N" footer sbl_died's text check needs. Comparing SCRIP's real output against a crashed
# oracle's truncated one would misattribute an oracle bug (BOM handling) as a SCRIP defect.
#
# REFUSE (not FAIL) for any program whose -INCLUDE target is missing from this directory (none found at
# authoring time -- checked every *.sno for an actual -INCLUDE directive, not just a comment mentioning
# the word -- but the check stays in case a future addition needs it, same convention as the aisnobol gate).
#
# REFUSE (not FAIL) for a file carrying more than one END statement: chap7.sno is a textbook chapter's
# worth of separate example programs concatenated into one file (measured: 2 top-level END lines, the
# second example starting mid-file under its own "Simple word usage program" header) -- not a single
# valid SNOBOL4 program. SCRIP correctly REFUSES it ("duplicate label 'END'"); the oracle instead runs
# only its first chunk silently, which is the more surprising behavior of the two, not the more correct
# one. Grading SCRIP against a partial run of a malformed multi-program file would blame SCRIP for
# being the stricter, arguably more correct, of the two engines.
#
# Exit: 0 iff FAIL3=0 and FAIL4=0 over the printed (scoreable) denominator. REFUSE entries never gate.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; SD="$HERE/../../SCRIP"; ROOT="$(cd "$HERE/../.." && pwd)"   # the root holds its repos as siblings, SCRIP or not
SUITE="${DOTNET_SUITE:-$ROOT/corpus/packages/snobol4/dotnet}"
SCRIP="$SD/scrip"; RT_DIR="$SD/out"; TIMEOUT="${TIMEOUT:-20s}"
[ -d "$SUITE" ] || { echo "⛔ REFUSE(rc=2): suite dir missing: $SUITE"; exit 2; }
# ⭐ UNDER A PORT ENGINE THIS RUNNER GRADES THE PORT WITH ITS OWN GRADING (S4E_ENGINE=dotnet|jvm; CEO-1822; Lon 2026-10-18, in-chat to hq_dotnet,
# verbatim: "Get all SNOBOL4 package runners working with snobol4dotnet."): SCRIP is the port's face (one_runner_port_face), the port runner's
# --binaries is the one check, each program runs in m3 alone with its declared heap and stack as switches, its rows are keyed dotnet@<engine>
# by the one writer, and no SCRIP score row is written -- the port's row is from-progress. Under scrip every line below reads as it did.
PORT=0; one_runner_is_port && PORT=1
ROWKEY=dotnet; [ "$PORT" = 1 ] && ROWKEY="dotnet@$(one_runner_engine)"
if [ "$PORT" = 1 ]; then SCRIP="$(one_runner_port_face)"; one_runner_port_ready snobol4 || exit 2; else
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2): no scrip binary at $SCRIP -- build first (make)"; exit 2; }
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). The line above proves a binary EXISTS; this one proves it is the binary this
# tree describes. ceo's witness, twice on 2026-09-04: a 10:57 binary graded at 14:03 read RED, then GREEN after
# an incremental make -- a vendor board is exactly where that is least visible, because a plausible all-FAIL
# table is this class's normal output. NO LOGIC HERE: util_require_fresh.sh sources gate_require_fresh from
# lib_gate.sh, the ONE authority (hq_B 4c7253e99) -- never a second copy of the staleness rule.
"$HERE/util_require_fresh.sh" --gate test_snobol4_dotnet_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
[ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ REFUSE(rc=2): no $RT_DIR/libscrip_rt.so"; exit 2; }
fi
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_oracle_flags.sh unloadable"; exit 2; }
. "$HERE/lib_inventory.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_inventory.sh unloadable"; exit 2; }
. "$HERE/lib_progress.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_progress.sh unloadable"; exit 2; }
SBL="$(sbl_correctness_bin)"; SBL_FLAGS="$(sbl_lang_flags)"
[ -x "$SBL" ] || { echo "⛔ REFUSE(rc=2): oracle absent: $SBL"; exit 2; }
sbl_assert_bf "$SBL" 2>/dev/null || { echo "⛔ REFUSE(rc=2): oracle at $SBL failed the -bf capability check"; exit 2; }
W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
SCRIP_HASH="$(git -C "$SD" rev-parse --short HEAD 2>/dev/null || echo '?')"
TREE_LABEL="SCRIP $SCRIP_HASH"; [ "$PORT" = 1 ] && TREE_LABEL="engine $(one_runner_port_tree)"
CORP_HASH="$(git -C "$ROOT/corpus" rev-parse --short HEAD 2>/dev/null || echo '?')"
TOTAL=0; UNSCR=0; UNGR=0; FLG=""; P3=0; F3=0; P4=0; F4=0; S4=0
FL3=""; FL4=""; FLU=""
sbl_died() { printf '%s' "$1" | grep -qE ' : ERROR [0-9][0-9][0-9] -- ' && printf '%s' "$1" | grep -qE '^in statement +[0-9]+$'; }
has_bom() { [ "$(head -c3 "$1" | xxd -p 2>/dev/null)" = "efbbbf" ]; }
# ⚠️ A BOM-prefixed source hits the oracle in TWO different shapes, neither of which sbl_died() alone
# catches: (a) segfault mid-report (Test.sno et al, rc>=128, handled above) or (b) a PARSE-time fatal
# that prints only the ERROR line and stops -- rc=1, no crash, but also no "in statement N" footer
# (SourceLines001.sno/Test2.sno measured: prints "ERROR 214 -- bad label or misplaced continuation
# line" then exits, nothing more). Checking the SOURCE BYTES directly is more precise than loosening
# the text match (which would risk matching a real program's own legitimate output by coincidence).
stdin_of() { local sno="$1" b; b="${sno%.sno}"
    for ext in IN in input; do [ -f "$b.$ext" ] && { echo "$b.$ext"; return; }; done
    echo /dev/null; }
compile_m4() { local sno="$1" out="$2" ca="${3:-}" t; t="$(mktemp -d)"
    SNO_LIB="$SUITE" "$SCRIP" --compile $ca "$sno" > "$t/p.s" 2>/dev/null || { rm -rf "$t"; return 1; }
    gcc -c "$t/p.s" -o "$t/p.o" 2>/dev/null || { rm -rf "$t"; return 1; }
    gcc "$t/p.o" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$out" 2>/dev/null || { rm -rf "$t"; return 1; }
    rm -rf "$t"; }
RUN="$W/run"; mkdir -p "$RUN"
# ⭐ THE DECLARED HEAP AND STACK (Lon 2026-09-23 18:3x; CEO-1167, CEO-1225; wired by the coo on CEO-1229, the SWI runner's pattern):
# each program runs in BOTH modes at what its row in ALL.csv declares -- heap_kb, stack_kb, read once through lib_declared_arena.sh,
# the one reader -- and at the shipped default when it declares nothing; a refused cell refuses the board. Line 2 hands the guard the
# same suite this loop grades (DOTNET_SUITE), so a scratch fixture is judged as one and the canonical suite as a board.
. "$HERE/lib_declared_arena.sh" || { echo "⛔ REFUSE(rc=2): lib_declared_arena.sh unloadable -- the one reader of a declared heap and stack"; exit 2; }
DECL="$W/declared_memory.tsv"
declared_memory_begin "$SUITE/ALL.csv" "$DECL" || { echo "⛔ REFUSE(rc=2): a declared-memory cell in $SUITE/ALL.csv is refused (named above) -- fix the cell; this board does not grade around it"; exit 2; }
# ⭐ THE PROGRESS DATABASE (CEO-319/331; CEO-383 ruling 2; row snobol4-snoflake-aisnobol-and-dotnet-runners-wired-onto-
# lib-inventory-with-their-sidecars, coo 2026-09-07): one row per program per mode -- PASS on a byte-equal stream against
# the live sbl -bf run, HANG/CRASH/FAIL by rc otherwise, SKIP when mode 4 could not compile or link, UNGRADED with the
# reason for every UNSCR program (the oracle could not grade it). Recorded only for the canonical suite path or when
# S4E_PROGRESS_DB names a scratch table; written once at the end through lib_progress.sh; said aloud, never a red board.
PROG_ROWS="$W/progress.tsv"; : > "$PROG_ROWS"
CANON_SUITE="$ROOT/corpus/packages/snobol4/dotnet"
PROG_RECORD=0; { [ "$SUITE" = "$CANON_SUITE" ] || [ -n "${S4E_PROGRESS_DB:-}" ]; } && PROG_RECORD=1
BOTH=0
prog_row() { [ "$PORT" = 1 ] && [ "$2" = m4 ] && return 0; printf 'package\tdotnet\tsnobol4\t%s\t%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$(progress_row_secs "$2")" "$4" >> "$PROG_ROWS"; }   # secs: ROW_S3/ROW_S4, each mode's own wall (CEO-1676 (c))
# ⭐ THE SPITBOL BASELINE (Lon 2026-09-08, row snobol4-every-package-runner-states-its-row-over-the-spitbol-
# baseline-measured-live; test_snoflake_suite.sh is the shape). A program the ONE ORACLE cannot run is OUTSIDE
# the baseline and out of the denominator. This runner already MEASURES that set live -- it is exactly the
# UNSCR arms, which key on the oracle's own rc and stream -- so nothing new is computed; what is added is the
# RECORD (OUTSIDE_SPITBOL_BASELINE.tsv beside the package, mirrored by UNGRADABLE.tsv) and a live cross-check
# that says STALE or UNRECORDED aloud rather than letting a written ruling drift from what sbl does today.
# ⛔ HOOKED IN prog_unscr RATHER THAN AT THE FOUR CALL SITES: every UNSCR path already funnels through here,
# so one hook cannot fall out of step with a fifth arm somebody adds later.
OUTSIDE_TSV="$SUITE/OUTSIDE_SPITBOL_BASELINE.tsv"; MIRROR_TSV="$SUITE/UNGRADABLE.tsv"; OUTSIDE_LIST=""
prog_unscr() { prog_row "$1" m3 UNGRADED "$2"; prog_row "$1" m4 UNGRADED "$2"; OUTSIDE_LIST="${OUTSIDE_LIST}$1\t$2\n"; }
# ⭐ UNGRADABLE.tsv IS AN UNSCORED SET (ceo CEO-1460, 2026-10-03): a row whose class is not ORACLE_REFUSES (those rows mirror the
# measured outside set below) names a program the oracle runs but whose answer cannot be graded here -- NEEDS_INPUT,
# NEEDS_INTERACTIVE_TTY and the rest of lib_inventory.sh's closed vocabulary. It is not run, it leaves SCORED and the denominator,
# and its progress rows say UNGRADED with the class -- the csnobol4 runner's reading, where an UNGRADABLE program has no ref.
ungradable_class_of() { [ -f "$MIRROR_TSV" ] || return 0; awk -F'\t' -v n="$1.sno" 'NF>2 && $1 !~ /^#/ && $1==n && $2!="ORACLE_REFUSES"{print $2; exit}' "$MIRROR_TSV"; }
verdict_of() { if [ "$1" -eq 124 ]; then echo HANG; elif [ "$1" -ge 128 ]; then echo CRASH; else echo FAIL; fi; }
# ⛔⭐ A SPITBOL FATAL IS GRADABLE (ceo CEO-1344 on hq_snobol4's measurement; the coo's row instruments-a-spitbol-fatal-is-gradable-...):
# the oracle prints its fatal block on stdout and exits 0, so a program that ends in a run-time fatal (1brc.sno, asgn1.sno) has an
# answer to grade, not a death to unscore. SCRIP's one error voice is on stderr: it is captured, rendered through the ONE renderer
# (util_render_error_voice.py --fatal-stdout) into the oracle's block shape and appended to SCRIP's stdout; the five run-summary
# lines the oracle prints (stmts executed, execution time msec, REGENERATIONS, memory used, memory left) are oracle-internal and
# masked on BOTH sides through the ONE mask shim from ALL.mask beside the package (a dash on SCRIP's side, the placeholder on both).
# An oracle that CRASHES (rc >= 128) is still unscored: a signal is not an answer.
FATAL_GRADED=""
fatal_render() { # $1=stdout text $2=stderr file -> the text with SCRIP's error block rendered and appended, unchanged when there is none
    # only the SCRIP error block itself is rendered: stderr also carries the declared-table notes of run_at_declared_table, which are
    # not the program's and must not reach the compare
    local blk r; blk="$(awk '/^scrip: error /{p=1; print; next} p && /^  /{print; next} {p=0}' "$2")"
    [ -n "$blk" ] || { printf '%s' "$1"; return 0; }
    r="$(printf '%s\n' "$blk" | python3 "$HERE/util_render_error_voice.py" spitbol --fatal-stdout)"
    if [ -n "$r" ] && [ "$r" != "$blk" ]; then if [ -n "$1" ]; then printf '%s\n%s' "$1" "$r"; else printf '%s' "$r"; fi; else printf '%s' "$1"; fi
}
mask_dot() { # $1=text $2=name $3=side -> the text masked per ALL.mask (the harness's own reader through the shim), unchanged without one
    [ -f "$SUITE/ALL.mask" ] || { printf '%s' "$1"; return 0; }
    local out; out="$(printf '%s' "$1" | python3 "$HERE/util_apply_ceo409_mask.py" "$SUITE/ALL.mask" "$2" "$W/mask_n" "--side=$3" 2>"$W/mask_err")" || { echo "⛔ REFUSE(rc=2): the CEO-409 masker refused on $2 (side $3): $(head -1 "$W/mask_err")"; exit 2; }
    printf '%s' "$out"
}
. "$HERE/lib_rr.sh" && rr_load "$SUITE" || exit 2   # the round robin's seam (CEO-1802/1805/1806): one chunk or a request's entries, rows as each test ends
for sno in "$SUITE"/*.sno; do
    _rrn="$(basename "$sno")"; _rrn="${_rrn%.*}"; rr_admits "$_rrn" || continue; rr_yield "$_rrn" && break; [ "$PROG_RECORD" = 1 ] && rr_flush "$PROG_ROWS"
    [ -e "$sno" ] || { echo "⛔ REFUSE(rc=2): zero fixtures in $SUITE"; exit 2; }
    name="$(basename "$sno" .sno)"; ROW_S3=0; ROW_S4=0
    export S4E_TIMEOUT_KEY="$name"   # the unit a retried timeout's stamp names (CEO-1335)
    # ⛔ A CONTAINER IS NOT A PROGRAM (ceo CEO-1272): chap7.sno carries two top-level ENDs, a chapter of example programs in one
    # file, and CONTAINERS.tsv names it MULTI_PROGRAM with that measurement -- it is neither graded nor outside the baseline.
    inventory_is_container "$SUITE" "$name.sno" && continue
    TOTAL=$((TOTAL+1))
    ugc="$(ungradable_class_of "$name")"
    if [ -n "$ugc" ]; then
        UNGR=$((UNGR+1)); FLG="$FLG $name($ugc)"; prog_row "$name" m3 UNGRADED "unscored: UNGRADABLE.tsv $ugc"; prog_row "$name" m4 UNGRADED "unscored: UNGRADABLE.tsv $ugc"; continue
    fi
    inc="$(grep -ohE "^[[:space:]]*-INCLUDE ['\"][^'\"]+['\"]" "$sno" | sed -E "s/.*-INCLUDE ['\"]([^'\"]+)['\"]/\1/" | head -1)"
    if [ -n "$inc" ] && [ ! -f "$SUITE/$inc" ]; then
        UNSCR=$((UNSCR+1)); FLU="$FLU $name(missing-include:$inc)"; prog_unscr "$name" "unscored: missing include $inc"; continue
    fi
    if has_bom "$sno"; then
        UNSCR=$((UNSCR+1)); FLU="$FLU $name(oracle-cannot-parse-utf8-bom)"; prog_unscr "$name" "unscored: oracle cannot parse the UTF-8 BOM"; continue
    fi
    ends="$(grep -cE '^END([[:space:]]|$)' "$sno")"
    if [ "$ends" -gt 1 ]; then
        UNSCR=$((UNSCR+1)); FLU="$FLU $name(multi-program-file:$ends-END-statements)"; prog_unscr "$name" "unscored: multi-program file, $ends END statements"; continue
    fi
    inp="$(stdin_of "$sno")"
    gotS="$(cd "$RUN" && "$TIMEOUT_RETRY" "$TIMEOUT" "$SBL" $SBL_FLAGS "$sno" < "$inp" 2>/dev/null)"; rcS=$?
    if [ "$rcS" -ge 128 ]; then
        UNSCR=$((UNSCR+1)); FLU="$FLU $name(oracle-crashed:sig$((rcS-128)))"; prog_unscr "$name" "unscored: oracle crashed sig$((rcS-128))"; continue
    fi
    # ⛔ AN EXCLUDED PROGRAM'S FATAL IS THE DIALECT REFUSAL, NOT AN ANSWER (the coo 2026-09-28, after d6c775c13 counted expr_parser_stub
    # into the denominator): a program EXCLUDED.tsv names NOT_SPITBOL_DIALECT (CEO-1286) is excluded exactly because sbl -bf stops on the
    # CSNOBOL4 feature it uses (ERROR 248, a user DEFINE of the system function ITEM) -- that fatal is half one of the exclusion, so the
    # program stays in the outside set and leaves the denominator, never graded through the rendered block.
    if sbl_died "$gotS" && inventory_is_excluded "$SUITE" "$name.sno"; then
        UNSCR=$((UNSCR+1)); FLU="$FLU $name(oracle-refuses-a-csnobol4-feature:EXCLUDED.tsv)"; prog_unscr "$name" "unscored: EXCLUDED not SPITBOL dialect, the oracle stops on the CSNOBOL4 feature"; continue
    fi
    DIED=0; if sbl_died "$gotS"; then DIED=1; FATAL_GRADED="$FATAL_GRADED $name"; fi
    # every oracle stream passes the ONE mask shim (CEO-1352, hq_snobol4: the -LIST listing's version and clock lines of SourceLines001-003
    # are per-entry rows); a row that matches nothing changes nothing, so a program without one is compared byte for byte as before
    gotS="$(mask_dot "$gotS" "$name" oracle)"
    ca="$(declared_compile_args_from_table "$DECL" "$name")" || exit 2
    SZ=""; [ "$PORT" = 1 ] && { SZ="$(declared_switches_from_table "$DECL" "$name")" || exit 2; }   # a port reads its declared heap and stack as -dNk -sNk, never SCRIP's env
    _t0="$(progress_clock)"
    got3="$(cd "$RUN" && run_at_declared_table "$DECL" "$name" -- env SNO_LIB="$SUITE" "$TIMEOUT_RETRY" "$TIMEOUT" "$SCRIP" --run $ca $SZ "$sno" < "$inp" 2>"$W/err3")"; rc3=$?
    ROW_S3="$(progress_secs_since "$_t0")"
    if [ "$DIED" = 1 ]; then got3="$(mask_dot "$(fatal_render "$got3" "$W/err3")" "$name" scrip)"; else got3="$(mask_dot "$got3" "$name" scrip)"; fi
    [ -n "${DOTNET_DEBUG_DIR:-}" ] && { printf '%s' "$gotS" > "$DOTNET_DEBUG_DIR/$name.oracle"; printf '%s' "$got3" > "$DOTNET_DEBUG_DIR/$name.m3"; cp "$W/err3" "$DOTNET_DEBUG_DIR/$name.err3" 2>/dev/null; }   # what this runner compared, on request (a red a reader cannot see is a red nobody can cure)
    if [ "$got3" = "$gotS" ]; then P3=$((P3+1)); OUT3=PASS; else F3=$((F3+1)); FL3="$FL3 $name"; OUT3="$(verdict_of "$rc3")"; fi
    # ⛔ A HANG NEVER COLLAPSES INTO PASS (the verdict ladder): measured 2026-09-07 (coo) on code/palin/temp -- the
    # oracle reads TERMINAL from /dev/null, sees EOF and exits rc=0 with 0 bytes in 0 s; SCRIP spins to the timeout
    # with 0 bytes, and "0 bytes equals 0 bytes" graded it PASS. The board's P3 takes that pass back (the coo 2026-10-18, on hq_jvm's
    # and hq_dotnet's reading: the DOTNET_BOARD line read m3_pass=5 where its rows read 3 PASS + 2 HANG), so the board, the progress
    # row and the AND line all say HANG, which is what happened (ceo-372: a timed-out run is HANG, never PASS, whatever its stream).
    if [ "$rc3" -eq 124 ]; then [ "$OUT3" = PASS ] && { P3=$((P3-1)); F3=$((F3+1)); FL3="$FL3 $name(HANG)"; }; OUT3=HANG; fi
    rc4=""; _t0="$(progress_clock)"; if [ "$PORT" = 1 ]; then OUT4=""   # a port has no mode 4: no compile, no row
    elif compile_m4 "$sno" "$W/prog.bin" "$ca"; then
        got4="$(cd "$RUN" && run_at_declared_table "$DECL" "$name" -- "$TIMEOUT_RETRY" "$TIMEOUT" "$W/prog.bin" < "$inp" 2>"$W/err4")"; rc4=$?
        if [ "$DIED" = 1 ]; then got4="$(mask_dot "$(fatal_render "$got4" "$W/err4")" "$name" scrip)"; else got4="$(mask_dot "$got4" "$name" scrip)"; fi
        if [ "$got4" = "$gotS" ]; then P4=$((P4+1)); OUT4=PASS; else F4=$((F4+1)); FL4="$FL4 $name"; OUT4="$(verdict_of "$rc4")"; fi
        if [ "$rc4" -eq 124 ]; then [ "$OUT4" = PASS ] && { P4=$((P4-1)); F4=$((F4+1)); FL4="$FL4 $name(HANG)"; }; OUT4=HANG; fi
    else S4=$((S4+1)); FL4="$FL4 $name(CC)"; OUT4=SKIP
    fi
    ROW_S4="$(progress_secs_since "$_t0")"
    [ "$OUT3" = PASS ] && { [ "$PORT" = 1 ] || [ "$OUT4" = PASS ]; } && BOTH=$((BOTH+1))   # a port's AND is its one mode
    N3="vs live sbl -bf, rc=$rc3"; [ "$OUT3" = HANG ] && N3="SCRIP hit the ${TIMEOUT} timeout (rc=124) while the oracle exited rc=$rcS; streams equal at the cut"
    N4="vs live sbl -bf${rc4:+, rc=$rc4}"; [ "$OUT4" = HANG ] && N4="SCRIP hit the ${TIMEOUT} timeout (rc=124) while the oracle exited rc=$rcS; streams equal at the cut"
    prog_row "$name" m3 "$OUT3" "$N3"; prog_row "$name" m4 "$OUT4" "$N4"
done
SCORED=$((TOTAL-UNSCR-UNGR))
echo "DOTNET_BOARD total=$TOTAL scored=$SCORED unscr=$UNSCR ungradable=$UNGR m3_pass=$P3 m3_fail=$F3 m4_pass=$P4 m4_fail=$F4 m4_skip=$S4 -- $TREE_LABEL corpus $CORP_HASH RT_OPT=-O0 oracle=sbl-bf timeout=$TIMEOUT"
[ -n "$FLU" ] && echo "UNSCR (missing corpus dependency, not a SCRIP defect):$FLU"
[ -n "$FLG" ] && echo "UNGRADABLE ($UNGR, named in UNGRADABLE.tsv with the oracle's own measurement, out of the denominator, CEO-1460):$FLG"
[ -n "${FATAL_GRADED:-}" ] && echo "FATAL_GRADED (the oracle ended these in a run-time fatal block; graded through the rendered block and ALL.mask, CEO-1344):$FATAL_GRADED"
echo "DOTNET_AND both_modes_pass=$BOTH/$SCORED -- the suite table states this reading (ceo-372: the AND per program; a timed-out run is HANG, never PASS, whatever its stream)"
echo "DOTNET_BASELINE baseline=$SCORED both_modes_pass=$BOTH outside_spitbol_baseline=$UNSCR of $TOTAL -- THE SUITE TABLE STATES both_modes_pass/baseline (a program SPITBOL itself cannot run is outside the baseline and out of the denominator; Lon 2026-09-08)"
if [ "$UNSCR" -gt 0 ]; then echo "OUTSIDE-SPITBOL-BASELINE ($UNSCR; name<TAB>why the oracle gave no answer):"; printf '%b' "$OUTSIDE_LIST" | sed 's/^/OUTSIDE\t/'; fi
if [ -f "$OUTSIDE_TSV" ]; then
    rec="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{sub(/\.sno$/,"",$1); print $1}' "$OUTSIDE_TSV" | sort)"
    live="$(printf '%b' "$OUTSIDE_LIST" | cut -f1 | grep . | sort)"
    stale="$(comm -23 <(printf '%s\n' "$rec") <(printf '%s\n' "$live") | grep . | tr '\n' ' ')"
    unrec="$(comm -13 <(printf '%s\n' "$rec") <(printf '%s\n' "$live") | grep . | tr '\n' ' ')"
    [ -n "$stale" ] && echo "⚠ OUTSIDE_SPITBOL_BASELINE.tsv STALE -- recorded as unrunnable by the oracle, but it answered cleanly this run; move it back into the baseline record: $stale"
    [ -n "$unrec" ] && echo "⚠ OUTSIDE_SPITBOL_BASELINE.tsv UNRECORDED -- the oracle gave no answer for these and the record does not name them; record each with its error and a source check: $unrec"
    [ -z "$stale$unrec" ] && echo "OUTSIDE_SPITBOL_BASELINE.tsv agrees with the measured outside set ($UNSCR)"
    if [ -f "$MIRROR_TSV" ]; then
        mir="$(awk -F'\t' 'NF>2 && $1 !~ /^#/ && $2=="ORACLE_REFUSES"{print $1}' "$MIRROR_TSV" | sort)"; recn="$(awk -F'\t' 'NF>2 && $1 !~ /^#/{print $1}' "$OUTSIDE_TSV" | sort)"
        [ "$mir" = "$recn" ] || echo "⚠ UNGRADABLE.tsv does not mirror OUTSIDE_SPITBOL_BASELINE.tsv row for row -- the lockdown bucket and the record have drifted; edit them together"
    fi
else echo "⚠ no OUTSIDE_SPITBOL_BASELINE.tsv beside the suite -- the outside-baseline set above is measured, not yet recorded"; fi
[ -n "$FL3" ] && echo "FAIL-M3 (vs live sbl -bf):$FL3"
[ -n "$FL4" ] && echo "FAIL-M4 (vs live sbl -bf):$FL4"
# ⭐ THE PACKAGE LOCKDOWN (Lon 2026-09-06): TOTAL is a fresh per-run filesystem census (the for loop
# above), never a cached count, so shipped can never silently lag the vendored dir. Every one of the 14
# lands in SCORED or UNSCR (named above) -- nothing here is ever left unclassified. lib_inventory.sh
# recomputes ungradable itself from UNGRADABLE.tsv beside $SUITE (a static declaration of exactly the
# UNSCR names above, with the oracle's own per-program reason) rather than trusting $UNSCR as a number.
INV_PACKAGE=dotnet; INV_DIR="$SUITE"; INV_EXT=".sno"
if ! rr_selected; then   # a chunk grades a part of the package, and the inventory sums the whole shipped package (CEO-1802)
INV_LINE="$(inventory_line "$SCORED" 0)"
if [ -n "$INV_LINE" ]; then echo "$INV_LINE"; else echo "⚠ inventory refused (above) -- the board line still stands; the inventory does not" >&2; fi
fi
# ⭐ THE PROGRESS ROWS, written once (see PROG_ROWS above). Said aloud either way; never a red board.
if [ "$PROG_RECORD" = 1 ]; then
    progress_append_rows_tsv "$PROG_ROWS" || echo "⚠ PROGRESS ROWS NOT RECORDED (writer rc=$? above) -- a run that leaves the table untouched is a defect of that run (progress/README.md), not a red board" >&2
else echo "progress: scratch suite $SUITE -- $(grep -c . "$PROG_ROWS") row(s) NOT recorded (only the canonical suite, or S4E_PROGRESS_DB, records)"; fi
rr_selected && { rr_end "$ROWKEY"; exit 0; }   # a chunk or a request writes its rows and no suite row (CEO-1802)
# ⛔⭐ POPULATION FLOOR (row every-board-wrapper-refuses-on-a-zero-population-instead-of-passing-
# vacuously, hq_T 2026-09-04): F3/F4/S4 all read 0 over zero SCORED entries too (empty corpus dir,
# every witness oracle-crashed/died) -- refuse before the vacuous-clean verdict below can be reached.
"$HERE/util_require_population.sh" --gate test_snobol4_dotnet_suite "$SCORED" 1 "scored rows (total=$TOTAL unscr=$UNSCR)" || exit 2
# ⭐ THE ROW, NAMING ITS OWN FRACTION (the shape test_snoflake_suite.sh uses). Before this the dotnet row was
# only ever set BY HAND -- this runner wrote no SCORE.md cell and no suite row at all, so its 5/5 had no
# runner behind it. The table's reading is the ceo-372 AND per program over the SPITBOL baseline.
if [ "$PORT" = 1 ]; then echo "SCORE.md: the $(one_runner_engine) engine writes no SCRIP row -- its row is util_score_row.py from-progress --suite $ROWKEY (CEO-1822), graded in m3 alone"
    if [ "$SUITE" = "$CANON_SUITE" ]; then one_runner_port_publish "$ROWKEY"; else echo "SUITES.tsv: scratch suite $SUITE -- not published (only the canonical suite publishes its row)"; fi
elif [ "$SUITE" = "$CANON_SUITE" ]; then
# ⛔ CEO-749 SHAPE (row snobol4-four-package-rows-leave-their-outside-baseline-programs-out-of-the-denominator-ceo-749):
# PASS over SHIPPED ($TOTAL = graded plus the $UNSCR outside the SPITBOL baseline), OUTSIDE=$UNSCR named and stamped
# through lib_outside_shape.sh; the outside programs stay in the denominator as debt to cure.
. "$HERE/lib_outside_shape.sh" || exit 2
EXCL_D_N="$(excluded_in_outside "$SUITE" "$(printf '%b' "$OUTSIDE_LIST" | cut -f1)")" || exit 2; DENOM=$((TOTAL - EXCL_D_N - UNGR))
echo "EXCLUDED_NOT_SPITBOL_DIALECT=$EXCL_D_N of this run's outside set leave the denominator ($(excluded_names_count "$SUITE") named in $SUITE/EXCLUDED.tsv; Lon 2026-09-26, CEO-1286): pass over $DENOM (UNGRADABLE=$UNGR also out, named above)"
# ⭐ THE ROW'S Excl IS EVERY SHIPPED UNIT THE DENOMINATOR LEAVES OUT (Lon 2026-09-26, "use the Excl column to properly classify
# the exclusions for good reasons only"; CEO-1288): its include fragments of CONTAINERS.tsv (CEO-1272), read off the inventory
# line, plus the EXCLUDED.tsv programs of this run's outside set -- the denominator does not move, only its classification.
CONT_N="$(inventory_containers_of "${INV_LINE:-}")"; EXCL_ROW=$((EXCL_D_N + CONT_N))
_cc="${S4E_CRITERION_CHANGED:-}"; [ -n "$_cc" ] || _cc="$(excluded_shape_stamp dotnet "$DENOM" "$UNSCR" "$EXCL_ROW" "$CONT_N")" || exit 2
python3 "$HERE/util_score_row.py" write --lang snobol4 --column vendor --suite dotnet --suite-key dotnet --modes m3,m4 \
    ${_cc:+--criterion-changed "$_cc"} \
    --measurer "${S4E_SEAT:-}" --suite-pass "$BOTH" --suite-total "$DENOM" --excluded "$EXCL_ROW" \
    --text "dotnet both_modes_pass=$BOTH/$DENOM ($TOTAL shipped minus EXCLUDED=$EXCL_D_N not in the SPITBOL dialect, EXCLUDED.tsv, CEO-1286) OUTSIDE=$UNSCR, graded $BOTH/$SCORED ( programs SPITBOL runs clean · $UNSCR outside the SPITBOL baseline, named with the oracle's own refusal and a source check in OUTSIDE_SPITBOL_BASELINE.tsv, Lon 2026-09-08) · m3 $P3/$SCORED · m4 $P4/$SCORED (of $TOTAL shipped · sbl -bf the one oracle · live oracle diff, no refs)${INV_LINE:+ · $INV_LINE} (\`test_snobol4_dotnet_suite.sh\`)" \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
else echo "SCORE.md: scratch suite $SUITE -- not written (only the canonical suite records the leaderboard)"; fi
[ "$F3" = 0 ] && [ "$F4" = 0 ] && [ "$S4" = 0 ]
