#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "${CSNOBOL4_SUITE:=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/corpus/packages/snobol4/csnobol4_suite}" || exit 2
# ⛔ THE STATEMENT INSTRUMENTATION (--stlimit) IS EACH PROGRAM'S OWN compile_args DECLARATION, read per program below (clause 8 (f), CEO-1281): this runner exported SCRIP_SNO_STMTKW=1 for every program until 2026-09-26 (Lon 2026-09-24 16:0x: off by default, never inferred from the source)
# test_snobol4_csnobol4_suite.sh — Phil Budne's CSNOBOL4 test suite, graded against its OWN oracle.
#
# Suite: corpus/packages/snobol4/csnobol4_suite (vendored, unmodified). A NAME.sno with a sibling NAME.ref
# is a graded pair; a NAME.sno with no .ref (e.g. bench.sno, a support/data file) is not a pair and is
# skipped by construction — never a hand-curated exclusion list.
#
# ⛔ THE ONE NAMED EXCEPTION — EXCLUDED_TESTS below (hq_P ruling, msg re-csnobol4-thirty-final-report,
# 2026-09-04, closing row snobol4-csnobol4-thirty-regen-candidate-refs-stale-pin-or-real-defect): ndbm,
# random, sleep, time each `-include` a modules/X/X.sno that dlopen()s ./X.so relative to CWD
# (lib/unix98/load.c:os_load_library) — physically unrunnable from this suite's flattened layout no matter
# what gets vendored. Upstream's OWN test/tests.in (verified directly, not taken on faith) carries these
# `reg` lines commented out: ndbm line 118 ("11/16/2005; off 10/22/2020 (moved to module)"), time line 122
# ("12/16/2010; off 10/25/2020 (moved to module)"), sleep line 130 and random line 132 (also `#`-commented
# in the same file; a specific disablement date is not legible for these two, unlike ndbm/time — do not
# overclaim one). Upstream itself does not run these four; neither do we — in THIS flattened layout.
#
# ⭐ MODULE-REPLACEMENT COVERAGE (landed here, row snobol4-csnobol4-module-replacement-coverage-ndbm-random-time,
# seat08 2026-09-05): Budne's own per-module self-tests — modules/{ndbm,random,time}/test.sno+test.ref and
# modules/time/test2.sno+test2.ref (test2 is literally "formerly test/time.sno", the time/date-family test;
# test.sno in the time module IS the sleep-family equivalent — there is no modules/sleep/ directory, SLEEP()
# ships as part of the "time" module, confirmed by reading modules/time/time.sno's own
# LOAD("SLEEP(REAL)", TIME_DL) line) — run from THEIR OWN directory below as MODULE_TESTS (never the flattened
# $SUITE copy, exactly because they dlopen ./X.so relative to cwd), folded into the SAME TOTAL/RED-M3/RED-M4
# counters as every other pair: no per-op exception list, a defect reached through an admitted family member
# counts like any other (RULES.md). ⛔ MEASURED, NOT ASSUMED GREEN: all four are RED against SCRIP in BOTH
# modes, for two already-out-of-scope, pre-existing reasons, never a fixture problem — the live csnobol4
# oracle passes all four byte-exact from these same directories, confirming the fixtures and this harness's
# plumbing, not the coverage itself, is what's new here. (1) ndbm and time/test2 hit the SAME gap: SCRIP's
# LOAD() (src/runtime/core/core.c, _b_LOAD_stub) recognizes only its own internal "MON_"-prefixed monitor
# hooks and FAILDESCRs everything else — there is no dlopen() anywhere in src/ (grepped clean). CSNOBOL4's
# dynamic external-C-module loading is simply unimplemented. ndbm's own FUNCTION("DBM_OPEN"):F(END) guard
# turns that into a graceful empty-output FAIL; time/test2 calls the LOAD'd GETTIMEOFDAY_ unconditionally and
# gets "Error 5: undefined function or operation" (REJECT). (2) random and time/test (the sleep equivalent)
# separately hit the PRE-EXISTING, ALREADY-DOCUMENTED lowercase-`end` dialect class named in the DIALECT
# paragraph below (case-sensitive SCRIP vs. CSNOBOL4's case-insensitive keywords) — "missing END statement"
# at a parse stage that never reaches LOAD at all. Fixing either gap is out of scope for a coverage-wiring
# row; see FINDING-2026-09-05-seat08-scrip-has-no-load-dlopen-support-confirmed-via-module-coverage.md.
#
# ⛔ PARKED_NO_REGEN below (same ruling) — breakline, k, rewind1, genc: live csnobol4 itself disagrees with
# its OWN historical .ref here (K-format fixed-record I/O looks broken; rewind1 SIGSEGVs on REWIND(5); genc
# now dies at statement 568 with "Error 24, Undefined or erroneous goto", a failure mode never seen before
# in this row), so the REGEN-CANDIDATE tiebreak (below) would misfile a live-oracle regression as "our .ref
# might be stale." ceo ruling (task ledger, snobol4-csnobol4-thirty-regen-candidate-refs-stale-pin-or-real-
# defect #28) covers breakline/k/rewind1; hq_P extended it to genc (msg re-csnobol4-genc-second-gap-and-a-
# third-mystery, 2026-09-04): do NOT re-cut any of the four .refs; grade plainly against csnobol4 and let
# them stay red until the oracle itself is fixed. They still count as ordinary RED (RED-M3/RED-M4,
# FAIL/REJECT/CRASH) — PARKED only removes them from the "maybe-stale-pin" bucket, it does not paper over
# the red. THERE IS NO XFAIL.
#
# ⛔ THE ORACLE IS SPITBOL (`sbl -bf`), THE ONE SNOBOL4 ORACLE (Lon 2026-09-07). The vendored .refs are re-cut from sbl;
# programs sbl refuses (rc=1) use CSNOBOL4-only extensions outside the SPITBOL baseline and are listed by name in
# OUTSIDE_SPITBOL_BASELINE.tsv (mirrored into UNGRADABLE.tsv as ORACLE_REFUSES) -- a list a census produced, never a count.
#
# ⭐ NORMALIZATION, sourced directly from Budne's own test/tests.in + test.dump.sh + test.trace.sh (the
# suite author's OWN definition of a matching DUMP/TRACE test, not a guess): 4 `dump`-type programs
# (a, dump, diag1, diag2 — &DUMP=1 output) mask `MAXLNGTH = NNN` -> `MAXLNGTH = xxx` and drop `&FILL = '..'`
# lines (both environment/build-dependent, not semantic); 4 `trace`-type programs (ftrace, spit, trace1,
# trace2 — TRACE() output) mask a trailing `time = N.NN` -> `time = xxx` (wall-clock, inherently
# nondeterministic). Applied identically to SCRIP's output, live csnobol4's output, AND the .ref before
# comparison — normalizing noise, not favoring a side. No other test type is touched.
#
# Ladder (per mode, m3 --run / m4 --compile+link+run), decided in this order:
#   HANG    killed by the timeout (rc=124)
#   CRASH   killed by a fatal signal (rc>=128) — or, m4 only, compile/link itself failed ("(CC)" suffix)
#   PASS    output byte-identical to .ref
#   REJECT  output differs, rc!=0 (parse/runtime refusal — didn't reach a normal exit)
#   FAIL    output differs, rc=0 (ran to completion, wrong answer)
#
# ⚠ DIALECT: this suite targets CSNOBOL4, not SPITBOL; SCRIP follows SPITBOL semantics (RULES.md). Known
# dialect-distance classes (lowercase `end`, missing -INCLUDE targets, CSNOBOL4-only builtins) are NOT
# filtered out here — see FINDING-2026-08-27-seat06-csnobol4_suite-triage-eight-classes-three-are-not-scrip-bugs.md
# for the read on which reds are confirmed SCRIP defects vs. corpus/dialect mismatches. This runner reports
# every red by name and leaves classification to that document and follow-on cure rows.
#
# Stdin convention (Budne's own, matching test_csnobol4_budne_suite.sh's STDIN_TESTS list): these programs
# carry their test data after their own END statement; split at the first bare "END" line, feed the tail
# as stdin, and run the head as the program.
#
# ⛔ SETUP_DEP (hq_P ruling above) — openo2 reads back openo.tst, a fixture openo.sno itself writes; upstream
# ran both sequentially in one shared dir (test/run.sh: `reg openo.sno` then `reg openo2.sno`, adjacent and
# ordered — upstream DESIGN, not an accident). This runner's own glob order (`for sno in "$SUITE"/*.sno`,
# locale-collated, NOT byte order) happens to visit openo2.sno BEFORE openo.sno, so without a declared setup
# step openo2 always read the fixture in its pristine vendored-empty state — measured directly, not guessed:
# a byte-for-byte repro outside this harness proves SCRIP's OUTPUT/INPUT association is correct as soon as
# openo runs first. Per-test isolation (comment above, ⛔ ALL arms run with cwd in a scratch dir) stays ruled;
# this is a one-time fixture-priming call, not a re-opening of that isolation.
#
# ⛔ ARGV_FOR (hq_P ruling above) — genc.sno needs `genc.sno v311.sil` (its own .ref header: "generated from
# v311.sil"); HOST(2,N)/HOST(3) (src/runtime/core/core.c) already index the REAL process argv correctly in
# m3, m4, and csnobol4 alike (verified directly against all three arms before wiring this in) — the runner
# just never passed a program argv through. One name, one extra token; extend the map if another test needs it.
#
# ⛔ ALL arms run with cwd in a scratch dir, never in the corpus tree — an OUTPUT unit-I/O association can
# create OR OVERWRITE files named by its argument in the cwd (SPITBOL/CSNOBOL4 dialect). The whole suite is
# COPIED (never symlinked) into the scratch run dir first: a same-directory `-INCLUDE "sibling.sno"` (e.g.
# line.sno -> line2.sno) still resolves cwd-relatively, but a write-target fixture (e.g. openo.tst, a
# pre-committed empty companion file openo.sno's file-I/O test writes into) lands on the scratch copy, never
# the tracked original. ⭐ MEASURED, THE HARD WAY (seat12, same session): the first cut of this script used
# symlinks here, and running it wrote real content into two tracked corpus fixtures (openo.tst, test.bin)
# through the symlink — reverted, cured to a copy before this landed. Never symlink a suite directory a
# program under test might open for writing.
#
# ⛔ A missing suite, compiler, RT, or the csnobol4 oracle REFUSES with rc=2 — never a silent skip-as-success.
# Exit: 0 iff FAIL+REJECT+CRASH+HANG == 0 in BOTH modes over the printed denominator (now includes the 4
# module/* coverage rows added below — measured RED today for reasons unrelated to this denominator, see
# the MODULE-REPLACEMENT COVERAGE paragraph further down).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"; SD="$HERE/../../SCRIP"; ROOT="$(cd "$HERE/../.." && pwd)"   # the root holds its repos as siblings, SCRIP or not
. "$HERE/lib_flag_gate.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_flag_gate.sh unloadable"; exit 2; }
[ $# -eq 0 ] || flaggate_reject "$1" "(none -- set CSNOBOL4_SUITE / TIMEOUT via environment instead)"
SUITE="${CSNOBOL4_SUITE:-$ROOT/corpus/packages/snobol4/csnobol4_suite}"
SCRIP="$SD/scrip"; RT_DIR="$SD/out"; TIMEOUT="${TIMEOUT:-8}"

[ -d "$SUITE" ] || { echo "⛔ REFUSE(rc=2): suite dir missing: $SUITE"; exit 2; }
# ⭐ UNDER A PORT ENGINE THIS RUNNER GRADES THE PORT WITH ITS OWN GRADING (S4E_ENGINE=dotnet|jvm; CEO-1822; Lon 2026-10-18, in-chat to hq_dotnet,
# verbatim: "Get all SNOBOL4 package runners working with snobol4dotnet."): SCRIP is the port's face (one_runner_port_face), the port runner's
# --binaries is the one check, each pair runs in m3 alone with its declared heap and stack as switches, its rows are keyed csnobol4@<engine>
# by the one writer, and no SCRIP score row is written -- the port's row is from-progress. A preload pair runs WITHOUT -L under a port (preload_for
# below): the switch is CSNOBOL4's, which SCRIP took, and the ref was cut by sbl -bf without it, so the port runs the program as the oracle did.
# Under scrip every line below reads as it did.
PORT=0; one_runner_is_port && PORT=1
ROWKEY=csnobol4; [ "$PORT" = 1 ] && ROWKEY="csnobol4@$(one_runner_engine)"
if [ "$PORT" = 1 ]; then SCRIP="$(one_runner_port_face)"; one_runner_port_ready snobol4 || exit 2; else
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2): no scrip binary at $SCRIP — build first (make)"; exit 2; }
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). The line above proves a binary EXISTS; this one proves it is the binary this
# tree describes. ceo's witness, twice on 2026-09-04: a 10:57 binary graded at 14:03 read RED, then GREEN after
# an incremental make -- a vendor board is exactly where that is least visible, because a plausible all-FAIL
# table is this class's normal output. NO LOGIC HERE: util_require_fresh.sh sources gate_require_fresh from
# lib_gate.sh, the ONE authority (hq_B 4c7253e99) -- never a second copy of the staleness rule.
"$HERE/util_require_fresh.sh" --gate test_snobol4_csnobol4_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
[ -f "$RT_DIR/libscrip_rt.so" ] || { echo "⛔ REFUSE(rc=2): no $RT_DIR/libscrip_rt.so"; exit 2; }
fi
# THE --compat SWITCH IS RETIRED (Lon 2026-09-07): there is one dialect, SPITBOL's, and no per-suite flag.
COMPAT=""
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_oracle_flags.sh unloadable"; exit 2; }
. "$HERE/lib_inventory.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_inventory.sh unloadable"; exit 2; }
. "$HERE/lib_progress.sh" 2>/dev/null || { echo "⛔ REFUSE(rc=2): lib_progress.sh unloadable -- a run that leaves the progress table untouched is the same defect as one that leaves its SCORE row untouched (ceo CEO-330/331)"; exit 2; }
SBL="$(sbl_correctness_bin)" || exit 2; SBL_FLAGS="$(sbl_lang_flags)"
RECUT="${RECUT_FROM_SPITBOL:-0}"
OUTSIDE="$SUITE/OUTSIDE_SPITBOL_BASELINE.tsv"
is_outside_baseline() { [ -f "$OUTSIDE" ] && awk -F"\t" -v n="$1.sno" '$1==n {f=1} END {exit f?0:1}' "$OUTSIDE"; }
# ⛔⭐ THE EXTENSION REF (Lon 2026-10-02, in-chat to the coo: "use CSNOBOL4 to gen the ORD tests. Mark the test as not generated by the
# SPITBOL oracle."): a program named in EXTENSIONS.tsv beside the suite is graded against a ref cut by the oracle its row names, stays in
# the denominator, is never re-cut from sbl, and is printed on the row. The harness checks the ledger (sha, overlap) and refuses rc=2.
EXT_NAMES="$(python3 "$HERE/corpus_suite_harness.py" extension-check --names "$SUITE")" || { echo "⛔ REFUSE(rc=2): $SUITE/EXTENSIONS.tsv did not check (its message is above)"; exit 2; }
EXT_N="$(printf '%s\n' $EXT_NAMES | grep -c .)"
is_extension() { printf '%s\n' $EXT_NAMES | grep -qxF "$1.sno"; }

STDIN_TESTS="atn crlf longrec rewind1 sudoku trim0 trim1 uneval2 factor len repl tab words words1"
is_stdin_test() { local n="$1" s; for s in $STDIN_TESTS; do [ "$n" = "$s" ] && return 0; done; return 1; }
DUMP_TESTS="a dump diag1 diag2"; TRACE_TESTS="ftrace keytrace spit trace1 trace2 trfunc t"
EXCLUDED_TESTS="ndbm random sleep time"
is_excluded_test() { local n="$1" s; for s in $EXCLUDED_TESTS; do [ "$n" = "$s" ] && return 0; done; return 1; }
# MODULE-REPLACEMENT COVERAGE for the four EXCLUDED_TESTS above — see header. name:module-subdir:sno:ref.
MODULE_TESTS="ndbm:ndbm:test.sno:test.ref random:random:test.sno:test.ref sleep:time:test.sno:test.ref time:time:test2.sno:test2.ref"
# Like compile_m4 below, but cwd-relative with no SNO_LIB override: these -INCLUDEs are bare same-directory
# names (e.g. 'ndbm.sno'), resolved by running with cwd already in the test's own directory — measured
# directly (seat08 2026-09-05) against a real invocation before wiring this in, not assumed.
compile_m4_mod() { local dir="$1" sno="$2" out="$3" t; t="$(mktemp -d)"
    ( cd "$dir" && "$SCRIP" $COMPAT --compile "$sno" > "$t/p.s" 2>/dev/null ) || { rm -rf "$t"; return 1; }
    gcc -c "$t/p.s" -o "$t/p.o" 2>/dev/null || { rm -rf "$t"; return 1; }
    gcc "$t/p.o" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$out" 2>/dev/null || { rm -rf "$t"; return 1; }
    rm -rf "$t"; return 0; }
PARKED_NO_REGEN="breakline k rewind1 genc"
is_parked_no_regen() { local n="$1" s; for s in $PARKED_NO_REGEN; do [ "$n" = "$s" ] && return 0; done; return 1; }
setup_dep_for() { case "$1" in openo2) echo openo;; esac; }
argv_for() { case "$1" in genc) echo v311.sil;; esac; }
# ⛔⭐ PRELOAD FLAGS, from upstream tests.in's OWN registration lines ("reg -Laa/aa.sno preload1.sno").
# csnobol4 -h calls -L "load source file before user program"; scrip had no -L at all until SCRIP (this
# landing) -- the argument fell through to the filename path and died as "cannot open '-Laa/aa.sno'", which
# is indistinguishable from a typo. These two entries were the package's whole UNGRADED bucket, and the
# sidecar reason said the pickup was a runner map; measured, it was a driver flag AND this map.
preload_for() { case "$1" in preload1) echo "-Laa/aa.sno";; preload2) echo "-Laa/aa.sno -Lbb/bb.sno";; esac; }
# ⛔⭐⭐ CEO-409 LINE MASKS ARE READ HERE, THROUGH THE HARNESS'S OWN BODY (hq_T 2026-09-08, ceo CEO-432 item 1).
# hq_R's mask mechanism landed in corpus_suite_harness.py (0ffb087b2) and was INERT for this suite, because this
# runner grades with its own loop and never calls the harness: a `<name>.mask` sidecar dropped beside a csnobol4
# fixture did exactly nothing, silently, which is the worst way for a safety mechanism to be absent -- the author
# would have seen a well-formed green board and concluded the mask was honoured.
# ⭐ IT IS A SHIM, NOT A SECOND IMPLEMENTATION, and the reason is the REGEX DIALECT rather than tidiness. The
# harness compiles PYTHON regexes; this file's other normalisations are sed EREs. A re-implementation in awk or sed
# would agree on every mask anyone happened to test and diverge on the first one using \d, (?i) or a lazy
# quantifier -- one sidecar meaning two different things depending on which runner read it. util_apply_ceo409_mask.py
# imports read_mask_sidecar() and apply_line_mask() from the harness, so the path rule, the dialect, the marker and
# the malformed-row refusal are all the ONE authority's.
# ⛔ DEFAULT-OFF AND MEASURABLY SO: no `<name>.mask` beside the fixture and this is byte-identical to the path that
# ran before it, which is every csnobol4 program today (zero sidecars in the suite).
MASK_TOKEN='<<CEO-409 MASKED IMPLEMENTATION-DEFINED LINE>>'
MASKED_LINES=0; MASKED_FIX=0; MASKED_LIST=""
MASK_N=0
# ⛔ GUARDRAIL 2, ENFORCED BEFORE ANY GRADING: a sidecar naming a program the suite does not contain REFUSES.
# A mask that matches nothing is one nobody notices has stopped applying -- it is the stale-marker shape wearing
# the mask mechanism's clothes, and it survives a rename in silence.
mask_preflight() {
    local f n; local any=0
    for f in "$SUITE"/*.mask; do
        [ -e "$f" ] || break
        any=1; n="$(basename "$f" .mask)"
        # ⛔ `ALL` is the SUITE-WIDE sidecar and names no single program by design; every other stem must name one.
        [ "$n" = ALL ] || [ -f "$SUITE/$n.sno" ] || { echo "⛔ REFUSE(rc=2): $f names no program in this suite -- $n.sno is not in $SUITE."; echo "   CEO-409 guardrail 2: a mask that matches nothing is one nobody notices has stopped applying."; exit 2; }
        [ -f "$SUITE/$n.ref" ] || { echo "⛔ REFUSE(rc=2): $f has no $n.ref beside it, and the sidecar path is derived from the REF -- the shim would look for a file that is not there and report no masks, which is a silent nothing rather than a refusal."; exit 2; }
        # the sidecar's own row validation is the harness's, reached through the shim, so it cannot drift from it.
        printf '' | python3 "$HERE/util_apply_ceo409_mask.py" "$SUITE/$n.ref" "$n" "$W/mask_n" >/dev/null || exit 2
    done
    [ "$any" = 1 ] && echo "CEO-409 masks: $(ls "$SUITE"/*.mask 2>/dev/null | wc -l) sidecar(s) armed and validated"
    return 0
}
# ⛔⭐ THE COUNT TRAVELS IN A FILE, NOT A VARIABLE, AND THAT IS FORCED RATHER THAN CHOSEN. normalize() is called
# as `exp="$(normalize ...)"`, so its whole body runs in a SUBSHELL: a variable it sets is gone the instant the
# substitution closes, and so is an `exit`. Anything this layer needs to tell the grading loop -- the masked-line
# count, and the fact that the masker itself refused -- has to cross that boundary in the filesystem.
# ⛔⭐ WHICH SIDECAR APPLIES, AND WHY A SUITE-WIDE ONE IS THE NORMAL CASE HERE. The shim derives <stem>.mask from
# the ref path it is handed -- the harness's own rule, not a second one -- so this function chooses WHICH family
# file the sidecar hangs off and lets the shim do the deriving. This suite is one .sno/.ref pair PER PROGRAM, so a
# per-program `<name>.mask` is possible; but its live sidecar is `ALL.mask`, masking SPITBOL's own allocator
# bookkeeping, which no program in the suite can compute and every program could print. Naming 93 programs one per
# row would be a census that goes stale the next time a program is added -- and a mask that has silently stopped
# covering a new entry is the unauditable shape CEO-409 exists against. The `*` entry column resolves it, in the
# harness's masks_for(), so both readers agree by construction rather than by both being written carefully.
mask_ref_for() { # $1=name -> echoes the ref path whose stem carries the applicable sidecar, or nothing
    [ -f "$SUITE/$1.mask" ] && { printf '%s' "$SUITE/$1.ref"; return 0; }
    [ -f "$SUITE/ALL.mask" ] && { printf '%s' "$SUITE/ALL.ref"; return 0; }
    return 1
}
mask_apply() { # $1=name $2=text -> echoes the masked text; leaves the replaced-line count (or ERR) in $W/mask_n
    printf '0' > "$W/mask_n"
    local mref; mref="$(mask_ref_for "$1")" || { printf '%s' "$2"; return 0; }
    local out
    if ! out="$(printf '%s' "$2" | python3 "$HERE/util_apply_ceo409_mask.py" "$mref" "$1" "$W/mask_n" 2>"$W/mask_err")"; then
        printf 'ERR' > "$W/mask_n"; printf '%s' "$2"; return 0
    fi
    printf '%s' "$out"
}
normalize() { # $1=name $2=text -> echoes text, masked per tests.in's dump/trace convention for that name
    local n="$1" t="$2"
    # ⛔⭐ A SPITBOL FATAL IS GRADABLE (CEO-1344, the coo's row instruments-a-spitbol-fatal-is-gradable-...): this runner captures
    # 2>&1 and cuts its refs the same way, so the SCRIP error block inside the captured text is replaced by the oracle's fatal
    # block as a merged capture reads it (measured: the error line twice, the run summary twice), through the ONE renderer; the
    # run-summary lines are masked by ALL.mask beside the data. The oracle's own text carries no SCRIP block and passes untouched.
    t="$(printf '%s' "$t" | python3 "$HERE/util_render_error_voice.py" spitbol --fatal-merged)"
    t="$(printf '%s' "$t" | sed -E 's/^x86-64  [A-Z][a-z]{2} [A-Z][a-z]{2} +[0-9]+ [0-9:]+ [0-9]{4}$/x86-64  xxx/')"
    # ⛔⭐ THE &FILL RULE REPLACES, IT NO LONGER DELETES (hq_T 2026-09-08, CEO-432 item 1: "replace-never-delete,
    # guardrail 4 as the harness has it"). This line used to be `/^&FILL = '/d`, and a DELETED line lets a MISSING
    # line pass as a masked one: the fixture that prints nothing where the oracle prints an &FILL matched, because
    # both sides had the line removed. Rewriting to a marker preserves line count AND position, so an absent line
    # is still an absent line. Same reasoning hq_R wrote into the harness; this runner predates it.
    case " $DUMP_TESTS " in *" $n "*) t="$(printf '%s' "$t" | sed -E -e 's/MAXLNGTH = [0-9]+/MAXLNGTH = xxx/' -e "s/^&FILL = '.*/$MASK_TOKEN/")";; esac
    case " $TRACE_TESTS " in *" $n "*) t="$(printf '%s' "$t" | sed -E 's/time = [0-9.eE+-]+$/time = xxx/')";; esac
    t="$(mask_apply "$n" "$t")"
    printf '%s' "$t"
}

split_at_end() { # $1=src -> writes $2=prog (thru END) $3=stdin-tail
    python3 - "$1" "$2" "$3" << 'PY'
import re, sys
lines = open(sys.argv[1], 'r', errors='replace').read().split('\n')
idx = next((i for i, l in enumerate(lines) if re.match(r'^END\s*$', l, re.IGNORECASE)), None)
if idx is None:
    open(sys.argv[2], 'w').write('\n'.join(lines)); open(sys.argv[3], 'w').write('')
else:
    open(sys.argv[2], 'w').write('\n'.join(lines[:idx+1]) + '\n'); open(sys.argv[3], 'w').write('\n'.join(lines[idx+1:]))
PY
}

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
RUN="$W/run"; mkdir -p "$RUN"
cp -rp "$SUITE"/. "$RUN"/ 2>/dev/null || true
# ⭐ THE DECLARED HEAP AND STACK (Lon 2026-09-23 18:3x; CEO-1167, CEO-1225; wired by the coo on CEO-1229, the SWI runner's pattern):
# each program runs in BOTH modes at what its row in ALL.csv declares -- heap_kb, stack_kb, read once through lib_declared_arena.sh,
# the one reader -- and at the shipped default when it declares nothing; a refused cell refuses the board. The oracle runs as before.
# Line 2 hands the guard the same suite this runner grades (CSNOBOL4_SUITE), so a scratch fixture is judged as one.
. "$HERE/lib_declared_arena.sh" || { echo "⛔ REFUSE(rc=2): lib_declared_arena.sh unloadable -- the one reader of a declared heap and stack"; exit 2; }
DECL="$W/declared_memory.tsv"
declared_memory_begin "$SUITE/ALL.csv" "$DECL" || { echo "⛔ REFUSE(rc=2): a declared-memory cell in $SUITE/ALL.csv is refused (named above) -- fix the cell; this board does not grade around it"; exit 2; }
# ⛔⭐ RECORD THE TREE THIS RUN GRADES, AT ITS START (hq_T 2026-09-08). A board takes ten to forty minutes and its
# SCORE.md write happens at the END; a seat who commits and pushes mid-run -- which the CEO-174 dirty-tree guard
# actively pushes you toward, since a dirty tree skips the write entirely -- moves HEAD under a measurement that
# already happened, and the row then names a tree carrying commits it never ran. Measured three times in one
# sitting, twice while doing the disciplined thing. util_score_row.py stamps this instead of HEAD, and says so
# when the two differ; unset, it behaves exactly as it always did.
# ⛔⭐ THE HAND-SPELLED export S4E_TREE_AT_START THAT STOOD HERE IS RETIRED ONTO gate_tree_watch (coo
# 2026-09-10, COO-54), which SETS THE STAMP AND TAKES THE BASELINE IN ONE CALL. It was the THIRD copy of
# this string: written out here, in board_icon_rungs.sh and in test_corpus_snobol4.sh, and ABSENT from
# every other board -- so the runners that had it stamped honestly and the rest stamped HEAD AT WRITE
# TIME, silently. This one was found by ARM 12 of test_gate_boards_refuse_when_the_binary_moves.sh on the
# very run that landed the arm; I had retired the other two by hand and missed this one, which is the
# argument for the census rather than for my memory.
. "$HERE/lib_gate.sh" 2>/dev/null || { echo "⛔ REFUSED TO GRADE rc=2: lib_gate.sh unloadable -- this board cannot tell whether its corpus moves under it" >&2; exit 2; }
GATE_NAME=test_snobol4_csnobol4_suite gate_tree_watch "$(cd "$HERE/../.." && pwd)"
SCRIP_HASH="$(git -C "$SD" rev-parse --short HEAD 2>/dev/null || echo '?')"
TREE_LABEL="SCRIP $SCRIP_HASH"; [ "$PORT" = 1 ] && TREE_LABEL="engine $(one_runner_port_tree)"
CORP_HASH="$(git -C "$ROOT/corpus" rev-parse --short HEAD 2>/dev/null || echo '?')"

compile_m4() { local sno="$1" out="$2" ca="${3:-}" t pre; t="$(mktemp -d)"; pre="$(preload_for "$(basename "$sno" .sno)")"
    SNO_LIB="$SUITE" "$SCRIP" $COMPAT $pre --compile $ca "$sno" > "$t/p.s" 2>/dev/null || { rm -rf "$t"; return 1; }
    gcc -c "$t/p.s" -o "$t/p.o" 2>/dev/null || { rm -rf "$t"; return 1; }
    gcc "$t/p.o" -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o "$out" 2>/dev/null || { rm -rf "$t"; return 1; }
    rm -rf "$t"; return 0; }
status_of() { # $1=got $2=rc $3=exp -> echoes PASS|FAIL|REJECT|CRASH|HANG
    local got="$1" rc="$2" exp="$3"
    if [ "$rc" = 124 ]; then echo HANG
    elif [ "$rc" -ge 128 ]; then echo CRASH
    elif [ "$got" = "$exp" ]; then echo PASS
    elif [ "$rc" != 0 ]; then echo REJECT
    else echo FAIL; fi
}

mask_preflight
TOTAL=0
M3_PASS=0; M3_FAIL=0; M3_REJECT=0; M3_CRASH=0; M3_HANG=0; RED3=""
M4_PASS=0; M4_FAIL=0; M4_REJECT=0; M4_CRASH=0; M4_HANG=0; RED4=""
BOTH_PASS=0   # programs PASS in m3 AND m4 -- the suite table's reading (ceo-372), what util_score_row's --suite-pass names
CSN_PASS=0; CSN_FAIL=0; CSN_EXT=0
REGEN=0; REGEN_LIST=""
EXCLUDED_LIST=""
OUTSIDE_LIST=""; RECUT_OK=0; RECUT_OUT=0
NOA_LIST=""   # CEO-1696: a shipped program with no ref that EXCLUDED.tsv names (NO_ORACLE_ANSWER: sbl -bf prints nothing), shipped and excluded, never graded
[ "$RECUT" != 0 ] && { : > "$OUTSIDE.tmp"; [ -f "$OUTSIDE" ] || : > "$OUTSIDE"; }
MOD_SUMMARY=""

. "$HERE/lib_rr.sh" && rr_load "$SUITE" || exit 2   # the round robin's seam (CEO-1802/1805/1806); this runner appends each program's rows as it grades it
for sno in "$SUITE"/*.sno; do
    [ -e "$sno" ] || { echo "⛔ REFUSE(rc=2): zero .sno files in $SUITE"; exit 2; }
    name="$(basename "$sno" .sno)"
    rr_admits "$name" || continue; rr_yield "$name" && break
    export S4E_TIMEOUT_KEY="$name"   # the unit a retried timeout's stamp names (CEO-1335)
    ref="$SUITE/$name.ref"
    if [ ! -f "$ref" ]; then           # not a graded pair (support file) — never hand-curated
        inventory_is_excluded "$SUITE" "$name.sno" && NOA_LIST="$NOA_LIST $name"   # unless EXCLUDED.tsv names it: a shipped program the oracle gives no answer for (CEO-1696)
        [ "$PORT" = 1 ] && is_outside_baseline "$name" && { progress_append package csnobol4 snobol4 "$name" m3 UNGRADED 0 "unscored: OUTSIDE_SPITBOL_BASELINE.tsv names it, the oracle gives no answer and it has no ref" >/dev/null 2>&1 || true; }   # a port's row reads every shipped program (from-progress)
        continue
    fi
    # ⛔ ALL.sno IS OUR OWN GENERATED CONCATENATION (2006 lines, every entry run together), NOT A SHIPPED
    # VENDOR PROGRAM -- lib_inventory.sh's census already excludes ALL.<ext> fleet-wide (hq_T 2026-09-06,
    # measured across ipl/aisnobol/csnobol4_suite/gimpel), and this loop must agree or `graded` counts one
    # more pair than `shipped` ever offered, and the inventory can never sum. It happens to carry its own
    # .ref (concatenated from every entry's own historical run) and was being silently graded before this.
    [ "$name" = "ALL" ] && continue
    if is_excluded_test "$name"; then EXCLUDED_LIST="$EXCLUDED_LIST $name"; if [ "$RECUT" != 0 ]; then awk -F"\t" -v n="$name.sno" '$1!=n' "$OUTSIDE" > "$OUTSIDE.tmp" 2>/dev/null; mv -f "$OUTSIDE.tmp" "$OUTSIDE" 2>/dev/null; printf '%s.sno\tORACLE_REFUSES\toutside the SPITBOL baseline (Lon 2026-09-07): CSNOBOL4 LOAD() module test\n' "$name" >> "$OUTSIDE"; fi; continue; fi
    # under a port its row is assembled by from-progress, which reads every shipped program, so an outside program carries its reading there
    if [ "$RECUT" = 0 ] && is_outside_baseline "$name"; then OUTSIDE_LIST="$OUTSIDE_LIST $name"; [ "$PORT" = 1 ] && { progress_append package csnobol4 snobol4 "$name" m3 UNGRADED 0 "unscored: OUTSIDE_SPITBOL_BASELINE.tsv names it, the oracle gives no answer" >/dev/null 2>&1 || true; }; continue; fi
    TOTAL=$((TOTAL+1))
    exp="$(normalize "$name" "$(cat "$ref")")"
    _mn="$(cat "$W/mask_n" 2>/dev/null || echo 0)"
    [ "$_mn" = ERR ] && { echo "⛔ REFUSE(rc=2): the CEO-409 masker refused on $name (its own message follows) -- a runner that cannot apply a declared mask must not grade as though there were none:"; sed 's/^/   /' "$W/mask_err" 2>/dev/null; exit 2; }
    if [ "${_mn:-0}" -gt 0 ]; then
        # ⛔ GUARDRAIL 4, THE HARNESS'S OWN FORM: a mask covering half a fixture's ref lines or more makes that
        # fixture UNGRADABLE -- it belongs outside the baseline, named, not carried in the denominator behind a
        # mask. Enforced as a hard refusal here rather than a quiet pass, because the failure mode of getting this
        # wrong is a program that can never be red again.
        _rl="$(printf '%s' "$exp" | grep -c '' )"
        if [ "$_rl" -gt 0 ] && [ "$((_mn * 2))" -ge "$_rl" ]; then
            echo "⛔ REFUSE(rc=2): $name would have $_mn of its $_rl ref lines masked."
            echo "   CEO-409 guardrail 4 -- a majority-masked fixture is UNGRADABLE and belongs OUTSIDE the baseline,"
            echo "   named in OUTSIDE_SPITBOL_BASELINE.tsv, not carried in the denominator behind a mask."; exit 2
        fi
        # ⛔ GUARDRAIL 3: counted and printed. An invisible mask is the machine for hiding reds; a printed one is
        # a measurement, and the count rides into the leaderboard cell beside the fraction for the same reason the
        # xpass count does -- a number nobody publishes is a number nobody can notice moving.
        MASKED_LINES=$((MASKED_LINES + _mn)); MASKED_FIX=$((MASKED_FIX + 1)); MASKED_LIST="$MASKED_LIST $name($_mn)"
    fi

    prog="$RUN/$name.sno"; relprog="$name.sno"; inp=/dev/null
    if is_stdin_test "$name"; then
        rm -f "$prog"; split_at_end "$sno" "$prog" "$W/stdin"; inp="$W/stdin"
    fi
    ca="$(declared_compile_args_from_table "$DECL" "$name")" || exit 2
    sz=""; [ "$PORT" = 1 ] && { sz="$(declared_switches_from_table "$DECL" "$name")" || exit 2; }   # a port reads its declared heap and stack as -dNk -sNk, never SCRIP's env
    dep="$(setup_dep_for "$name")"
    [ -n "$dep" ] && { dca="$(declared_compile_args_from_table "$DECL" "$dep")" || exit 2; [ "$PORT" = 1 ] && { dca="$dca $(declared_switches_from_table "$DECL" "$dep")" || exit 2; }; (cd "$RUN" && run_at_declared_table "$DECL" "$dep" -- env SNO_LIB="$SUITE" "$TIMEOUT_RETRY" "$TIMEOUT" "$SCRIP" $COMPAT --run $dca "$dep.sno" > /dev/null 2>&1); }
    xargs_extra="$(argv_for "$name")"
    pre_extra="$(preload_for "$name")"
    # ⭐ A PORT RUNS A PRELOAD PAIR AS THE ORACLE DID, WITHOUT -L: snobol4dotnet mimics SPITBOL exactly (Lon 2026-10-18, in-chat to hq_dotnet,
    # verbatim: "The snobol4dotnet is meant to mimic SPITBOL exactly."), SPITBOL has no -L, and the ref (one empty line) is sbl -bf's answer to
    # the bare program -- handed the switch, the face refused rc 2 and the pair read REJECT for a switch no SPITBOL takes
    [ "$PORT" = 1 ] && pre_extra=""
    if [ "$RECUT" != 0 ] && is_extension "$name"; then echo "RECUT SKIPS $name.sno: an EXTENSION REF (EXTENSIONS.tsv), not sbl's to cut"; continue; fi
    if [ "$RECUT" != 0 ]; then
        gotr="$(cd "$RUN" && "$TIMEOUT_RETRY" "$TIMEOUT" "$SBL" $SBL_FLAGS "$relprog" $xargs_extra < "$inp" 2>&1)"; rcr=$?
        if [ "$rcr" != 1 ]; then printf '%s\n' "$gotr" > "$ref"; RECUT_OK=$((RECUT_OK+1)); awk -F"\t" -v n="$name.sno" '$1!=n' "$OUTSIDE" > "$OUTSIDE.tmp" 2>/dev/null; mv -f "$OUTSIDE.tmp" "$OUTSIDE" 2>/dev/null
        else first="$(printf '%s' "$gotr" | head -1 | cut -c1-120)"; awk -F"\t" -v n="$name.sno" '$1!=n' "$OUTSIDE" > "$OUTSIDE.tmp" 2>/dev/null; mv -f "$OUTSIDE.tmp" "$OUTSIDE" 2>/dev/null; printf '%s.sno\tORACLE_REFUSES\toutside the SPITBOL baseline (Lon 2026-09-07): sbl -bf rc=%s: %s\n' "$name" "$rcr" "$first" >> "$OUTSIDE"; RECUT_OUT=$((RECUT_OUT+1)); fi
        continue
    fi

    # ⛔ RELATIVE, NOT $prog: cwd is already $RUN below, and the vendored .ref files were cut against a
    # bare-relative invocation (name.sno). Passing the absolute scratch path here makes every self-path-
    # referencing program (TRACE(), error messages, &FILE) embed a throwaway tmpdir string instead of the
    # bare name the .ref expects — a harness artifact, not a SCRIP or oracle divergence (found triaging
    # row snobol4-csnobol4-thirty-regen-candidate-refs-stale-pin-or-real-defect, seat07 2026-09-04).
    _t0="$(progress_clock)"   # each mode's own wall for its row (CEO-1676 (c)); m4's takes its compile and link
    got3="$(cd "$RUN" && run_at_declared_table "$DECL" "$name" -- env SNO_LIB="$SUITE" "$TIMEOUT_RETRY" "$TIMEOUT" "$SCRIP" $COMPAT $pre_extra --run $ca $sz "$relprog" ${xargs_extra:+-- $xargs_extra} < "$inp" 2>&1)"; rc3=$?
    s3="$(progress_secs_since "$_t0")"
    got3="$(normalize "$name" "$got3")"
    st3="$(status_of "$got3" "$rc3" "$exp")"
    progress_append package csnobol4 snobol4 "$name" m3 "$st3" "$s3" >/dev/null 2>&1 || true
    case "$st3" in
        PASS) M3_PASS=$((M3_PASS+1));;
        FAIL) M3_FAIL=$((M3_FAIL+1)); RED3="$RED3 $name";;
        REJECT) M3_REJECT=$((M3_REJECT+1)); RED3="$RED3 $name";;
        CRASH) M3_CRASH=$((M3_CRASH+1)); RED3="$RED3 $name";;
        HANG) M3_HANG=$((M3_HANG+1)); RED3="$RED3 $name";;
    esac

    _t0="$(progress_clock)"
    if [ "$PORT" = 1 ]; then [ "$st3" = PASS ] && BOTH_PASS=$((BOTH_PASS+1))   # a port has no mode 4: no compile, no row; its AND is its one mode
    elif (cd "$RUN" && compile_m4 "$relprog" "$W/prog.bin" "$ca"); then
        got4="$(cd "$RUN" && run_at_declared_table "$DECL" "$name" -- env SNO_LIB="$SUITE" "$TIMEOUT_RETRY" "$TIMEOUT" "$W/prog.bin" $xargs_extra < "$inp" 2>&1)"; rc4=$?
        s4="$(progress_secs_since "$_t0")"
        got4="$(normalize "$name" "$got4")"
        st4="$(status_of "$got4" "$rc4" "$exp")"
        progress_append package csnobol4 snobol4 "$name" m4 "$st4" "$s4" >/dev/null 2>&1 || true
        case "$st4" in
            PASS) M4_PASS=$((M4_PASS+1));;
            FAIL) M4_FAIL=$((M4_FAIL+1)); RED4="$RED4 $name";;
            REJECT) M4_REJECT=$((M4_REJECT+1)); RED4="$RED4 $name";;
            CRASH) M4_CRASH=$((M4_CRASH+1)); RED4="$RED4 $name";;
            HANG) M4_HANG=$((M4_HANG+1)); RED4="$RED4 $name";;
        esac
        [ "$st3" = PASS ] && [ "$st4" = PASS ] && BOTH_PASS=$((BOTH_PASS+1))
    else
        M4_REJECT=$((M4_REJECT+1)); RED4="$RED4 $name(CC)"
    fi

    # an EXTENSION program's ref was cut by the oracle its EXTENSIONS.tsv row names, so sbl is not asked to reproduce it (CEO-1416)
    if is_extension "$name"; then CSN_EXT=$((CSN_EXT+1)); continue; fi
    gotc="$(cd "$RUN" && "$TIMEOUT_RETRY" "$TIMEOUT" "$SBL" $SBL_FLAGS "$relprog" $xargs_extra < "$inp" 2>&1)"
    gotc="$(normalize "$name" "$gotc")"
    if [ "$gotc" = "$exp" ]; then CSN_PASS=$((CSN_PASS+1))
    else
        CSN_FAIL=$((CSN_FAIL+1))
        [ "$st3" != PASS ] && ! is_parked_no_regen "$name" && { REGEN=$((REGEN+1)); REGEN_LIST="$REGEN_LIST $name"; }
    fi
done


echo "── csnobol4_suite: $TOTAL pairs · $TREE_LABEL · corpus $CORP_HASH · RT_OPT -O0 · timeout ${TIMEOUT}s · oracle sbl -bf (SPITBOL; Lon 2026-09-07: the one SNOBOL4 oracle; formerly csnobol4, Phil Budne, home dialect) · .ref primary, live csnobol4 = triangulation + tiebreak/regen"
# ⛔ AND THE BASELINE IS COMPARED, not merely taken: a gate_tree_watch with no gate_tree_unmoved is a
# half-instrument -- it records what nobody checks. Placed BEFORE the board line for the same reason the
# binary guard is: a refusal that fires after the row is published is an annotation, not a refusal.
GATE_NAME=test_snobol4_csnobol4_suite gate_tree_unmoved
echo "CSNOBOL4_SUITE_BOARD total=$TOTAL m3_PASS=$M3_PASS m3_FAIL=$M3_FAIL m3_REJECT=$M3_REJECT m3_CRASH=$M3_CRASH m3_HANG=$M3_HANG m4_PASS=$M4_PASS m4_FAIL=$M4_FAIL m4_REJECT=$M4_REJECT m4_CRASH=$M4_CRASH m4_HANG=$M4_HANG"
echo "sbl -bf re-read against the refs (staleness check, informational): PASS=$CSN_PASS FAIL=$CSN_FAIL EXTENSION=$CSN_EXT (an extension ref is not sbl's to reproduce, CEO-1416)"
# ⛔ GUARDRAIL 3 -- PRINTED WHETHER OR NOT ANY MASK EXISTS. A line that appears only when masks are in play tells
# the reader nothing on the day one is added and everything on the day one is removed; masked_lines=0 is the
# reading that says "this board declined to grade nothing", and it is the one worth having by default.
echo "CEO-409 masks: masked_lines=$MASKED_LINES in $MASKED_FIX fixture(s)${MASKED_LIST:+ ·$MASKED_LIST} (excluded at the LINE; every fixture stays in the denominator)"
[ -n "$OUTSIDE_LIST" ] && echo "OUTSIDE_SPITBOL_BASELINE ($(printf '%s' "$OUTSIDE_LIST" | wc -w), programs sbl -bf refuses, named in $OUTSIDE, out of the denominator):$OUTSIDE_LIST"
[ "$RECUT" != 0 ] && echo "RECUT_FROM_SPITBOL: refs re-cut=$RECUT_OK outside-baseline=$RECUT_OUT"
if [ "$RECUT" != 0 ]; then U="$SUITE/UNGRADABLE.tsv"; { [ -f "$U" ] && awk -F"\t" '$3!~/outside the SPITBOL baseline/' "$U"; cat "$OUTSIDE"; } > "$U.tmp" && mv -f "$U.tmp" "$U"; echo "UNGRADABLE.tsv: outside-the-SPITBOL-baseline rows mirrored ($(grep -c 'outside the SPITBOL baseline' "$U"))"; fi
[ -n "$RED3" ] && echo "RED-M3:$RED3"
[ -n "$RED4" ] && echo "RED-M4:$RED4"
[ "$REGEN" -gt 0 ] && echo "REGEN-CANDIDATE ($REGEN, SCRIP m3 disagrees with .ref and so does a fresh sbl -bf run — .ref pin may be stale):$REGEN_LIST"
[ -n "$EXCLUDED_LIST" ] && echo "EXCLUDED (upstream's own tests.in retired these, see script header):$EXCLUDED_LIST"

# ⭐ THE PACKAGE LOCKDOWN inventory line, via the shared body (lib_inventory.sh) -- never a second copy
# of the arithmetic. $TOTAL already equals "pairs in $SUITE measured against the oracle": the excluded-4/
# module-4 swap above is a same-count replacement (four $SUITE pairs physically unrunnable in this
# flattened layout, traded 1:1 for their MODULE_TESTS equivalents from the shared csnobol4 tree), so it
# is the right "graded" figure for a census of $SUITE itself. graded_narrow=0: grading is byte-exact
# against .ref, never by error-number-only.
INV_PACKAGE=csnobol4; INV_DIR="$SUITE"; INV_EXT=".sno"
if ! rr_selected; then   # a chunk grades a part of the package, and the inventory sums the whole shipped package (CEO-1802)
INV_LINE="$(inventory_line "$TOTAL" 0)"
if [ -n "$INV_LINE" ]; then echo "$INV_LINE"; else echo "⚠ inventory refused (above) -- the board line still stands; the inventory does not" >&2; fi
fi

# ⛔ ONE LEADERBOARD (RULES.md FACT RULE, Lon 2026-09-03 ~16:05). Records what this script just
# measured into .github/SCORE.md; runs nothing itself. Non-fatal: a bookkeeping failure must never
# turn a real measurement into a red board. Matches the other package suites (Arizona/JCON/fpc/GNU/SWI);
# this one and snoflake_suite's own runner were the two missing it (board-packages-into-make-test-
# reported-then-blocking, seat13 2026-09-03).
# ⭐ THE INVENTORY CLAUSE RIDES IN THE CELL TOO (util_score_row.py's inventory_clauses(), CEO-316):
# appended verbatim when non-empty, runner name immediately after so `by=`/backtick attribution
# finds it within the reader's 200-char window; absent when inventory_line refused.
# ⛔⭐ NAME THE SUITE FRACTION EXPLICITLY (cto 2026-09-08, the cure b2660262e gave the snoflake and ipl runners and
# b7f48462a gave Arizona): without --suite-pass/--suite-total the writer REFUSED this row every time ("carries no N/M
# fraction") and the Budne cell was hand-set (62/97 at 19162985f); the runner now writes its own AND-per-program count.
# ⛔ CEO-749 SHAPE (row snobol4-four-package-rows-leave-their-outside-baseline-programs-out-of-the-denominator-ceo-749): TOTAL
# above counts the GRADED fixtures only (an outside one takes its `continue` first), so the row publishes PASS over SHIPPED =
# graded plus the OUTSIDE_LIST, OUTSIDE=k named and stamped through lib_outside_shape.sh. Before this it read 71/71 with 49
# programs listed in OUTSIDE_SPITBOL_BASELINE.tsv -- a 100% the law does not allow.
rr_selected && { rr_end "$ROWKEY"; exit 0; }   # a chunk or a request wrote its rows as it went, and writes no suite row (CEO-1802)
OUT_N="$(printf '%s\n' $OUTSIDE_LIST | grep -c .)"; NOA_N="$(printf '%s\n' $NOA_LIST | grep -c .)"; SHIPPED=$((TOTAL + OUT_N + NOA_N))
. "$HERE/lib_outside_shape.sh" || exit 2
# ⛔⭐ CEO-1286 (Lon 2026-09-26): the programs NOT IN THE SPITBOL DIALECT (EXCLUDED.tsv beside the suite) leave the denominator; the
# oracle-refused programs that ARE SPITBOL dialect (diag1/diag2 by origin, the lowercase ones owed their case conversion, tab, rewind1) stay.
# ⛔⭐ CEO-1696 (Lon 2026-10-11: "Exclude any program in which we have no way to get output from an oracle, or in which we do not know the answer."): a refless
# program EXCLUDED.tsv names NO_ORACLE_ANSWER (include2, include3, include4, noexec: sbl -bf runs them and prints nothing) is shipped and leaves the denominator too.
EXCL_D_N="$(excluded_in_outside "$SUITE" "$OUTSIDE_LIST $NOA_LIST")" || exit 2; DENOM=$((SHIPPED - EXCL_D_N))
[ -z "$NOA_LIST" ] || echo "EXCLUDED_NO_ORACLE_ANSWER=$NOA_N shipped with no ref and named NO_ORACLE_ANSWER in EXCLUDED.tsv (CEO-1696):$NOA_LIST"
echo "EXCLUDED_NOT_SPITBOL_DIALECT=$EXCL_D_N of this run's outside set leave the denominator ($(excluded_names_count "$SUITE") named in $SUITE/EXCLUDED.tsv; Lon 2026-09-26, CEO-1286): pass over $DENOM"
python3 "$HERE/corpus_suite_harness.py" extension-check "$SUITE" || exit 2
if [ "$PORT" = 1 ]; then echo "SCORE.md: the $(one_runner_engine) engine writes no SCRIP row -- its row is util_score_row.py from-progress --suite $ROWKEY (CEO-1822), graded in m3 alone"; else
_cc="${S4E_CRITERION_CHANGED:-}"; [ -n "$_cc" ] || _cc="$(excluded_shape_stamp csnobol4 "$DENOM" "$OUT_N" "$EXCL_D_N")" || exit 2
python3 "$HERE/util_score_row.py" write --lang snobol4 --column vendor --suite CSNOBOL4 --modes m3,m4 \
    ${_cc:+--criterion-changed "$_cc"} \
    --suite-pass "$BOTH_PASS" --suite-total "$DENOM" --excluded "$EXCL_D_N" \
    --measurer "${S4E_SEAT:-}" \
    --text "both_modes_pass=$BOTH_PASS/$DENOM ($SHIPPED shipped minus EXCLUDED=$EXCL_D_N not in the SPITBOL dialect or with no oracle answer, EXCLUDED.tsv, CEO-1286 and CEO-1696; NO_ORACLE_ANSWER=$NOA_N) OUTSIDE=$OUT_N EXTENSION=$EXT_N (refs not cut by sbl, named in EXTENSIONS.tsv), graded $BOTH_PASS/$TOTAL · total=$TOTAL m3 PASS=$M3_PASS FAIL=$M3_FAIL REJECT=$M3_REJECT CRASH=$M3_CRASH HANG=$M3_HANG · m4 PASS=$M4_PASS FAIL=$M4_FAIL REJECT=$M4_REJECT CRASH=$M4_CRASH HANG=$M4_HANG · masked_lines=$MASKED_LINES in $MASKED_FIX fixture(s) (CEO-409, excluded at the line, fixture stays in the denominator)${INV_LINE:+ · $INV_LINE (\`test_snobol4_csnobol4_suite.sh\`)} · the $(inventory_containers_of "${INV_LINE:-}") include fragments of CONTAINERS.tsv (CEO-1272) are outside this graded-pair population, so they are named here and are not Excl (CEO-1288)" \
    || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why)"
fi

# ⛔⭐ POPULATION FLOOR (row every-board-wrapper-refuses-on-a-zero-population-instead-of-passing-
# vacuously, hq_T 2026-09-04): every _FAIL/_REJECT/_CRASH/_HANG bucket reads 0 over TOTAL=0 too
# (empty pair discovery) -- refuse before the vacuous-clean verdict below can be reached.
"$HERE/util_require_population.sh" --gate test_snobol4_csnobol4_suite "$TOTAL" 1 "pairs" || exit 2
[ "$M3_FAIL" = 0 ] && [ "$M3_REJECT" = 0 ] && [ "$M3_CRASH" = 0 ] && [ "$M3_HANG" = 0 ] && \
[ "$M4_FAIL" = 0 ] && [ "$M4_REJECT" = 0 ] && [ "$M4_CRASH" = 0 ] && [ "$M4_HANG" = 0 ]
