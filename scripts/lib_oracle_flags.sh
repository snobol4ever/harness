#!/usr/bin/env bash
# lib_oracle_flags.sh -- ⭐ THE ONE AUTHORITY for the SPITBOL oracle's LANGUAGE ARM.
#
# WHY THIS FILE EXISTS (s200, row `bench-timed-oracle-flag`).  The s189 ruling established that `-bf` is the
# ONLY correct arm for grading or timing SCRIP against SPITBOL: SPITBOL CASE-FOLDS names by default (manual
# v3.7 p.23 names, p.28 labels) and `-f` turns folding OFF (p.162), which is the arm SCRIP -- declared
# CASE-SENSITIVE by RULES.md -- is MEASURED to agree with in three independent constructs (names/labels, the
# special name `output` vs `OUTPUT` p.192, and indirect reference `$('ABC')` p.182).  `scorecard_snobol4.sh`
# adopted it; the TIMING harnesses did not, and kept `-b`.  So the correctness board and the performance board
# were grading two DIFFERENT LANGUAGES, and `NOISE-FLOOR.tsv` was baked under the wrong one.
# ⛔⭐ READ THE `SECOND DIVERGENCE AXIS` BLOCK NEAR sbl_clean_bin BEFORE REASONING FROM THE SENTENCE ABOUT SPITBOL'S DEFAULT FOLDING: it is MEASURED true of the x64 correctness face and MEASURED FALSE of the bench face, where folding is off whatever you pass.  `-bf` remains the mandate; the RATIONALE is per-binary (hq_P 2026-09-05).
#
# ⛔ THE SPLIT THIS FILE ENCODES, AND WHY IT IS NOT ONE FUNCTION.  The LANGUAGE arm (`-bf`) is universal and is
# never a per-suite choice -- that was the whole s189 finding.  The SIZING knobs are NOT universal and are not a
# language question: a correctness run wants `-d512m -i64m` (heap/stack for the big corpus programs), a timed run
# wants `-s16m` (the json deserializer's recursive descent overflows the default stack).  Sizing a stack is not a
# throughput knob and not a semantics knob.  Callers therefore take `sbl_lang_flags` VERBATIM and append their own
# sizing -- they may never substitute for it.
#
# ⛔ CALLERS MUST REFUSE, NOT FALL BACK.  A harness that cannot load this file must exit non-zero and say so.  A
# silent private default is exactly the defect this file retires: it looks like a measurement and is a different
# language.  (Same shape as row `suite-table-one-authority`, where the refusal is the load-bearing half.)
sbl_lang_flags() { echo "-bf"; }

# ⭐⭐ THE ONE AUTHORITY for DIVERTING SPITBOL'S LISTING OUT OF THE COMPARED STREAM (hq_B 2026-09-04, ceo
# CEO-251 on the snoflake grading ruling).  MEASURED on snoflake: `sbl -bf` printed `macro spitbol version
# 4.0f`, an `x86-64 <date>` line, page headers and a full statement listing on 56 of 180 fixtures.  NOT from
# our flags -- `-b` already suppresses the signon -- but from `-LIST` control lines INSIDE the fixtures, which
# no command-line flag can pre-empt.  Any harness that compares SCRIP's output against the oracle's byte-for-
# byte fails those on SPITBOL's own furniture rather than on semantics; with this flag the count went 56 -> 0.
# Errors STILL arrive on stdout with it set, so an "errors included" comparison is unaffected -- verified.
# ⛔⛔ IT FAILS OPEN, AND THAT IS THE WHOLE REASON THIS IS A FUNCTION AND NOT A STRING.  SPITBOL APPENDS `.lst`
# to the name, so `-o=/dev/null` becomes `/dev/null.lst`, which it cannot open -- whereupon it prints
# `-o file open error.` and DUMPS THE LISTING TO STDOUT ANYWAY.  The caller then compares against a stream that
# silently regained the furniture this flag exists to remove, and nothing in the exit code says so.  A caller
# that grades on the oracle's stdout MUST treat `-o file open error.` in the output as a REFUSAL (rc=2), never
# as a fixture result.  Pass a directory you have already created and can write.
# ⛔ DELIBERATELY NOT FOLDED INTO sbl_lang_flags: that returns the SEMANTICS flags every caller takes verbatim,
# and this one needs a PATH.  Baking a relative name in would drop a `.lst` file into whatever cwd each caller
# happens to run in -- including corpus directories, where it could collide with a fixture's own companions.
# ⛔⭐ THE SINK TRADES ONE LEAK FOR ANOTHER, AND THE SECOND ONE IS INVISIBLE — PASS THE ORACLE A SHORT
# FILENAME, NEVER A LONG ABSOLUTE PATH (hq_B 2026-09-04, measured on `trace-procedure`).  SPITBOL formats
# a diagnostic as `<path>(<line>) : ERROR <n> -- <text>`, wraps it at COLUMN 119 into the LISTING, and
# spills only the OVERFLOW onto stdout.  Without this flag the listing IS stdout, so `ERROR <n>` is
# visible and everything looks fine.  WITH this flag the first 119 characters are diverted into the sink,
# so a caller passing a 73-char absolute path receives the bare tail `t trace type` on the compared
# stream -- the error NUMBER, which is the only durable half of a SPITBOL diagnostic, is gone.  A grader
# that falls back to comparing error numbers then finds none and returns FAIL.
#   MEASURED, and note the direction: exactly 119 characters are lost regardless of message length, so a
#   LONGER path leaves MORE of the tail on stdout (path 66 -> 5 chars survive; 106 -> 45).  The symptom
#   therefore gets less alarming as the defect gets worse, which is why it read as 8 ordinary fixture
#   failures for a whole sitting.  Every other sbl caller in ../harness/scripts/ is safe TODAY only because it does
#   not use this sink -- not because its paths are short.  Adopt this flag and you inherit the trap.
#   ✅ THE CURE IS ONE LINE AT THE CALL SITE: stage the program under a short name in the run directory
#   (`ln -sf "$src" "$RUN/f.sno"`) and hand the oracle `f.sno`, cwd in $RUN.  See run_one() in
#   test_snoflake_suite.sh.  Grading by error NUMBER also needs a NUMERIC compare: SPITBOL zero-pads to
#   three digits (`ERROR 042`) where SCRIP does not (`Error 42`), so `[ "$a" = "$b" ]` silently misses
#   every error below 100.
sbl_listing_sink_flag() {
    local d="${1:-}"
    if [ -z "$d" ] || [ ! -d "$d" ] || [ ! -w "$d" ]; then
        printf "⛔ sbl_listing_sink_flag: need an existing writable directory (got '%s') -- SPITBOL fails OPEN on -o= and dumps its listing to stdout\n" "$d" >&2
        return 3
    fi
    printf -- '-o=%s/spitbol_listing' "$d"
}

# ⭐ THE ONE AUTHORITY for the SPITBOL oracle's BINARY (s row `clean-oracle-build`).  Lon's FACT RULE
# (2026-08-22, in-chat): "For benchmarking we should use only the official SPITBOL from the x64 repo at
# the SPITBOL GitHub."  The repo's checked-in `x64/bin/sbl` is INSTRUMENTED -- it carries a monitor IPC
# bridge (sysmc/sysml/sysmv/sysmr/sysmw/pmcll/pmext/pmred/pmfal fire-points, ~130 lines over upstream)
# that is NOT part of official SPITBOL.  MEASURED (callgrind Ir, matched `-bf` flags, cross-validated via
# an independent same-toolchain rebuild of the full fork tree landing within 7 instructions of the
# checked-in binary): the monitor fire-points cost ~2.2-2.3x the instruction count on statement/store-
# dense code even with MONITOR_READY_PIPE/MONITOR_GO_PIPE unset -- documented as "negligible overhead"
# but empirically NOT, most likely an uncached per-fire env-var check.  This binary is a from-source
# build of official upstream (github.com/spitbol/spitbol, HEAD 4fe74db) plus exactly two ALLOW-LISTED
# compatibility patches (Lon's amendment, same session): the uppercase-keyword/datatype-name table
# conversion + matching flc/flstg fold-direction reversal (so `-bf` accepts SCRIP-convention uppercase
# keywords), and the NS-TIME clock fix to osint/systm.c (s249, Lon in-chat, CLOCK_MONOTONIC not
# CLOCK_PROCESS_CPUTIME_ID).  NO monitor instrumentation, NO LOAD/UNLOAD ABI rework (that subsystem was
# classified UNKNOWN/deferred, not needed for the 15 top-level benchmark kernels, and is NOT minor).
# Proven: nm/strings show zero monitor symbols; patched-vs-pure-upstream Ir delta is 0.0067%, fully
# one-time (does not scale with iteration count); all 15 corpus/benchmarks/snobol4 kernels' deterministic
# `check:` output matches x64/bin/sbl exactly.  Full measurement in
# FINDING-2026-08-22-seat2-clean-oracle-monitor-overhead.md.
#
# ⛔ CALLERS MUST REFUSE, NOT FALL BACK -- same law as sbl_lang_flags above.  This path is OUTSIDE every
# tracked repo (built alongside its upstream source clone, both living outside the seat-root workspace so
# neither is ever discovered as a repo by tooling that walks S4E_HOME); a caller that cannot find it must
# say so loudly, never silently substitute x64/bin/sbl.
# ⛔⛔ THE -f CAPABILITY ASSERTION (hq_P s259, row `oracle-bin-sbl-trap`).  MEASURED: three SPITBOL binaries on
# this box -- `spitbol-clean/bin/sbl` (before it was repointed), `spitbol-fork-rebuilt/bin/sbl` and
# `spitbol-upstream/bin/sbl`, all byte-identical -- DO NOT SUPPORT `-f`.  Handed the MANDATORY `-bf` they answer
# "No END statement found in source file(s)." to EVERY program, including a two-line one that plainly has an END.
# A harness pointed at one of them prints a full, plausible, ENTIRELY FALSE all-FAIL table -- the exact class
# CLAUDE.md records this project hitting in three separate sessions.
# ⭐ WHY IT IS STRUCTURAL AND WILL COME BACK: a SPITBOL source tree SHIPS a prebuilt `bin/sbl` as BASEBOL, the
# BOOTSTRAP compiler; `make spitbol` consumes it and writes the real product to the TOP LEVEL as `./sbl`.  In our
# `x64/` fork `bin/sbl` IS the product.  The two layouts disagree, so the natural generalisation "the oracle is
# <root>/bin/sbl" lands EXACTLY on the trap.  Documentation cannot fix that; a capability check can.
# ⛔ THE RULE THIS ENCODES: an oracle is not a PATH, it is a BINARY THAT ACCEPTS `-bf`.  Never assemble a path.
sbl_bf_capable() {   # $1 = binary.  0 = accepts -bf, 1 = does not, 2 = could not be tested.  Memoised per shell.
    [ -n "${1:-}" ] && [ -x "$1" ] || return 1
    local key; key="_sbl_bf_memo_$(printf '%s' "$1" | tr -c 'A-Za-z0-9' '_')"
    local memo="${!key:-}"; [ -n "$memo" ] && return "$memo"
    local t; t="$(mktemp 2>/dev/null)" || { printf '%s' "$1" >/dev/null; return 2; }
    printf "        OUTPUT = 'sblbfok'\nEND\n" > "$t"
    local out; out="$(timeout -k 5 30 "$1" -bf "$t" < /dev/null 2>&1)"; rm -f "$t"
    case "$out" in *sblbfok*) eval "$key=0"; return 0 ;; esac
    eval "$key=1"; return 1
}
# ⛔ REFUSE, NEVER FALL BACK -- the same law as the two functions above, now applied to CAPABILITY rather than
# to mere existence.  A missing binary was already loud; a PRESENT binary that silently grades nothing was not.
sbl_assert_bf() {    # $1 = binary, $2 = human label.  Prints the path on success; refuses loudly and returns 3.
    if sbl_bf_capable "$1"; then printf '%s\n' "$1"; return 0; fi
    printf '⛔ REFUSING: %s at %s does not accept the MANDATORY -bf (s189).\n' "${2:-oracle}" "$1" >&2
    printf '   It answers "No END statement found" to EVERY program, so a run against it is a FALSE all-FAIL table,\n' >&2
    printf '   not a measurement. A SPITBOL tree ships bin/sbl as the BASEBOL BOOTSTRAP; the built product is ./sbl\n' >&2
    printf '   at the TOP LEVEL. Do not assemble oracle paths -- use sbl_clean_bin / sbl_correctness_bin.\n' >&2
    return 3
}
# ⛔⛔ NAMING, CORRECTED BY LON s259 ("What is spitbol-upstream, is the pristine version? ... What is upstream mean?").
# "UPSTREAM" IS A GIT WORD, NOT A QUALITY WORD: it names the project you forked FROM (github.com/spitbol/spitbol),
# as opposed to `origin`, your own fork (snobol4ever/x64).  It says PROVENANCE and says NOTHING about whether the
# binary in that tree can serve as an oracle -- and the one shipped there CANNOT (no `-f`).
# ⭐ MEASURED, and it inverts the old names: `spitbol-upstream` had **0 modified files** -- it was the genuinely
# pristine one -- while `spitbol-clean` has **4** (the two allow-listed patches).  THE NAME "clean" WAS THE LIE.
# Renamed by ROLE s259, compatibility symlinks left at both old names so nothing in flight breaks:
#   spitbol-pristine/      <- was spitbol-upstream       untouched reference SOURCE. ⛔ NOT an oracle: its shipped
#                                                        bin/sbl is the BASEBOL bootstrap and rejects `-bf`.
#   spitbol-bench-oracle/  <- was spitbol-clean          the minimal-patch BUILD we TIME against. ⭐ the oracle.
#   x64/                   (shared, symlinked into all 19 roots since Lon s259) the CORRECTNESS oracle + IPC monitor.
sbl_clean_bin() { sbl_assert_bf "/home/resources/spitbol-bench-oracle/sbl" "the CLEAN benchmark oracle"; }

# ⛔⭐⭐ AN ORACLE IS A BINARY, SO A PERF BASELINE MUST NAME *WHICH* BINARY (hq_P 2026-09-05, prompted by the pending
# g_flc repair).  `NOISE-FLOOR.tsv` records the bake timestamp, reps and MACHINE LOAD -- it warns at length that the
# floor is a property of load and not only of the engine -- but it records NOTHING about the oracle binary itself.
# ⛔ SO A REBUILT OR REPAIRED ORACLE SILENTLY INVALIDATES EVERY BAKED `sbl` ROW AND NOTHING DETECTS IT.  That is not
# hypothetical: hq_B has a verified 11-constant `asm.sbl` repair built and waiting on Lon's permission to install.
# The moment it lands, every sbl row baked before it is a number from a DIFFERENT BINARY sitting in the same column
# as numbers from the new one -- the exact "a number's tree is part of its label" law from RULES.md § FACT RULES,
# applied to the oracle instead of to our own tree.  ⭐ The load warning above is the PRECEDENT, not a counterexample:
# it exists because an unrecorded hidden variable already cost a bake once.  This is the second such variable.
# Prints: <path> md5=<hash> size=<bytes> mtime=<iso>.  Never fails a bake -- an unfingerprintable oracle records
# UNKNOWN loudly in the provenance rather than aborting a measurement that is otherwise valid.
sbl_oracle_fingerprint() {   # $1 = binary path (already resolved by an accessor above)
    local b="${1:-}"
    if [ -z "$b" ] || [ ! -x "$b" ]; then printf '%s md5=UNKNOWN size=UNKNOWN mtime=UNKNOWN\n' "${b:-<unset>}"; return 0; fi
    local m s t
    m="$(md5sum "$b" 2>/dev/null | cut -d' ' -f1)"; [ -n "$m" ] || m=UNKNOWN
    s="$(stat -c %s "$b" 2>/dev/null)"; [ -n "$s" ] || s=UNKNOWN
    t="$(stat -c %y "$b" 2>/dev/null | cut -d'.' -f1)"; [ -n "$t" ] || t=UNKNOWN
    printf '%s md5=%s size=%s mtime=%s\n' "$b" "$m" "$s" "$t"
}
# ⭐ THE CORRECTNESS FACE, through the authority for the first time (hq_P s259).  Callers previously assembled
# "$X64/bin/sbl" by hand, which is how a path becomes a trap.  Since Lon's s259 ruling ("everyone should be
# using the shared /home/resources") every seat root's x64/ is a SYMLINK to /home/resources/x64, so the shared
# path is canonical and the per-root one still resolves.
# ⛔⭐⭐ SHARED ONLY -- NO PER-ROOT x64, NO SYMLINK (Lon, 2026-08-23 s261: "Ensure that no root have x64. Everyone must share." / "Do not use symlinks.")
# This used to fall back to "${S4E_HOME}/x64/bin/sbl" when the shared oracle was missing.  That fallback is DELETED, and deleting it is the point: a fallback does not just TOLERATE a per-root clone, it
# SILENTLY REWARDS one -- a seat that cloned x64 into its root would grade green against its own private copy and never learn it had diverged from everyone else.  A missing shared oracle must be LOUD.
# A per-root clone is also a permanent handoff_status.sh blocker the moment it takes a local commit, since that script adopts every directory in the root that is a git repo with an origin remote.
# VERIFIED s261 across all 19 roots: no x64 entry of any kind, symlink or directory.  The shared tree is /home/resources/x64 (clean, 0 dirty, 0 unpushed).
sbl_correctness_bin() {
    local c="/home/resources/x64/bin/sbl"
    if [ ! -x "$c" ]; then
        printf "⛔ THE SHARED CORRECTNESS ORACLE IS MISSING: %s\n" "$c" >&2
        printf "   ⛔ DO NOT clone x64 into your seat root and DO NOT symlink it -- Lon s261, everyone shares /home/resources/x64.\n" >&2
        printf "   Restore the SHARED tree, then re-run.  Grading with it absent prints a full, plausible, entirely false all-FAIL table.\n" >&2
        return 1
    fi
    sbl_assert_bf "$c" "the CORRECTNESS oracle (x64, instrumented)"
}

# ⛔⭐⭐ SECOND DIVERGENCE AXIS, MEASURED 2026-09-05 (hq_B discovered on the correctness face; hq_P re-measured the BENCH face here by execution).  THE TWO ORACLES DO **NOT** DIFFER ONLY IN LOAD SUPPORT -- read the block below as ONE known edge, never as THE known edge.
# ⛔ THE BENCHMARK ORACLE CANNOT CASE-FOLD NAMES AT ALL.  The entire translator diff is three lines in asm.sbl `g_flc`: stock folds UPPER->lower, our x64 fork flipped it to lower->UPPER (fork commit e68dfeb, "SN-30g UPPERCASE canonical case").  `flc` has FOUR call sites wanting OPPOSITE directions, so each build is correct at some and broken at the others -- x64 folds NAMES correctly and refuses every TRACE type; the bench build traces correctly and its name folding is a SILENT NO-OP.
# ⭐ MEASURED, witness `ABC = 5 ; OUTPUT = abc` (hq_P 2026-09-05, both binaries, this root):
#     x64/bin/sbl            -b -> `5`      -bf -> ``      <- folds by default, `-f` turns it off.  s189 holds HERE.
#     spitbol-bench-oracle   -b -> ``       -bf -> ``      <- folding is OFF WHATEVER YOU PASS.  `-f` is a NO-OP.
# ⭐ SO THE s189 SENTENCE AT THE TOP OF THIS FILE -- "SPITBOL case-folds names by default and `-f` turns folding OFF" -- IS A PROPERTY OF x64, NOT OF "SPITBOL".  It is still the right MANDATE (see why it is dormant, next line), but it is the wrong EXPLANATION for the bench face, and a seat reasoning from it about the bench binary will reason wrongly.
# ✅ WHY THIS IS DORMANT AND NOT A LIVE PERF DEFECT (swept by hq_P 2026-09-05, all 17 sbl_clean_bin callers): every bench caller takes the language arm from `sbl_lang_flags` VERBATIM, i.e. `-bf`, and under `-bf` BOTH binaries have folding off -- so they agree, and the NOISE-FLOOR provenance is intact ON THIS AXIS.  The two non-users are `bench_triangulate_snobol4.sh` (calls sbl_clean_bin as a PRECONDITION GUARD only, then delegates timing to two callers that do use it) and `test_gate_oracle_bf_capable.sh` (the capability gate itself).
# ⛔ WHAT WOULD WAKE IT: any bench invocation that drops `-f`.  That is not a style slip -- it silently changes WHICH LANGUAGE the oracle is running, on one binary and not the other, so the two faces stop being comparable and nothing in the exit code says so.  `sbl_bf_capable()` above CANNOT catch this: it proves `-bf` is ACCEPTED, never that `-f` DOES ANYTHING.
# ⛔ NOT CURED HERE, AND DELIBERATELY SO: the repair is 11 dispatch constants in the oracle's own asm.sbl (hq_B has it designed -- point the broken sites at the already-correct `ch_u*`), which is an ORACLE-SOURCE change in /home/resources, not a SCRIP change.  Full witness: .github FINDING-2026-09-05-hq_B-the-snoflake-correctness-oracle-refuses-every-trace-type-...
# ⭐ A LIVE EDGE, PRESERVED NOT FIXED (row oracle-two-face-adoption): the clean binary above is a from-
# source build of official upstream with exactly the two ALLOW-LISTED patches described in the block
# above -- it carries NO LOAD/UNLOAD ABI rework, so its external-fn loader is stock upstream and its
# parity with x64/bin/sbl on a LOAD()-calling program is UNVERIFIED (classified UNKNOWN/deferred, not
# needed for the 15 top-level benchmark kernels -- none of which call LOAD).  Fixing that subsystem is
# out of scope here.  What IS in scope: a benchmark timing a LOAD()-calling program against this binary
# must REFUSE LOUDLY, never silently print a number of unknown validity -- same "CALLERS MUST REFUSE,
# NOT FALL BACK" law as the two functions above, applied to program CONTENT instead of binary ABSENCE.
# Usage: sbl_clean_refuse_if_load "$path/to/prog.sno" || exit 3   (grep, not a parse -- LOAD as a bare
# word covers the real corpus shape; a string literal merely containing the four letters is not a
# realistic false-positive in named SNOBOL4 source and a parser is not worth building for this edge).
sbl_clean_refuse_if_load() {
  grep -qE '(^|[^A-Za-z0-9_])LOAD\s*\(' "$1" 2>/dev/null || return 0
  echo "⛔ REFUSING: $1 calls LOAD() -- the clean benchmark oracle's LOAD/external-fn support is stock upstream and UNVERIFIED against x64/bin/sbl (see sbl_clean_bin() above). Benchmarking this program against it would silently report a number of unknown validity, not a loud refusal. This is a preserved gap, not a bug for this row to fix. Time it against x64/bin/sbl directly (correctness oracle, sbl_lang_flags) if you must measure a LOAD()-calling program." >&2
  return 1
}
# ⛔⭐ THE ONE FILTER OVER gprolog's STANDARD OUTPUT (the coo 2026-10-10, ceo CEO-1599 on the swap CEO-1598): what a consult run prints
# that is gprolog's and not the program's. gprolog_output_filter [--compile-diagnostics] < raw > program output. MEASURED, the two
# banners: 1.4.5 printed "GNU Prolog 1.4.5 (64 bits)", "Compiled ...", "By Daniel Diaz", "Copyright ...", then "compiling ... for byte
# code..." and "... compiled, N lines read"; 1.6.0 prints "GNU Prolog 1.6.0 (64 bits)", "Compiled ...", "Copyright ..." and then ONE EMPTY
# LINE, with no By Daniel Diaz and no compiling line, and opens a compile diagnostic with "In file included from X:N". Five sites each held
# a copy of the 1.4.5 pattern (the GNU runner twice, lib_prolog_bench.sh's gnu_filter, test_bench_prolog_4way.sh and _modes.sh), so under
# 1.6.0 every one kept the banner's empty line and all 48 GNU driver outputs differed from their refs by that line alone. Both banners
# are dropped here; the empty line only when it follows the Copyright line, so an empty line the program prints is kept. The query echo
# ("| ?- halt.") and the diagnostics every copy dropped (^error:, ^warning:, cannot be redefined) go too. --compile-diagnostics also drops
# a file:line: (fatal error|error|warning): line and "compilation failed" -- the GNU runner's stricter copy, kept to its own sites.
# test_gate_gprolog_output_filter_is_the_one_filter.sh holds a fixed witness of each banner and the census of copies.
gprolog_output_filter() {
    local diag=0; [ "${1:-}" = --compile-diagnostics ] && diag=1
    awk -v diag="$diag" '
        after_copyright && $0 == "" { after_copyright = 0; next }
        { after_copyright = 0 }
        /^Copyright/ { after_copyright = 1; next }
        /^GNU Prolog|^Compiled |^By Daniel|^compiling |compiled, |^\| \?-|^error:|^warning:|cannot be redefined|^In file included from / { next }
        diag && (/:[0-9]+(-[0-9]+)?: *(fatal error|error|warning):/ || /^compilation failed$/) { next }
        { print }'
}


# ⭐ ICON ORACLE ACCESSORS (row icon-oracle-accessors-shared, added 2026-08-23) -- the same one-
# authority pattern as the SPITBOL accessors above, extended to the Arizona Icon oracle.  Before
# this pair existed, this file had ZERO Icon awareness: `grep -rn "icont\|iconx\|icon-master"
# ../harness/scripts/*.sh` turns up at least four DIFFERENT hand-assembled roots across Icon board/bench
# scripts (icon-build, icon-master, work/icon-master/icon-master, refs/icon-master) plus bare
# `icont`/`iconx` trusted on PATH -- each script guessing independently, most with no existence
# check at all before use.  A wrong or absent guess is SILENT: the harness prints a full,
# plausible, entirely FALSE all-FAIL table (the same class sbl_correctness_bin() above exists to
# prevent), never a loud refusal.
# ⛔ CALLERS MUST REFUSE, NOT FALL BACK -- same law as every accessor above.  A missing icont/iconx
# must be LOUD on stderr with a non-zero return, never a silent empty string a caller can string-
# concat into a broken command line.
# Canonical shared build (verified executable this session): /home/resources/icon-master/bin/{icont,iconx}.
# ⭐ ONE PATH, NO ALIAS (ceo CEO-1853, 2026-10-21; Lon in-chat to the ceo, verbatim: "We use proper absolute and relative paths."
# · "I am concerned only with ones we create."): /home/resources/icon-build was a symlink to icon-master that hq_C made in s266
# so callers defaulting to it would land on the one tree. Every caller now names /home/resources/icon-master and the link is
# removed; test_gate_no_symlinks.sh ARM 5 keeps the top level of /home/resources free of links we make.
icont_bin() {
    local c="/home/resources/icon-master/bin/icont"
    if [ ! -x "$c" ]; then
        printf "⛔ THE SHARED ICON ORACLE (icont) IS MISSING: %s\n" "$c" >&2
        printf "   Grading or timing an Icon harness with it absent prints a full, plausible, entirely false all-FAIL table.\n" >&2
        printf "   Do not hand-assemble a path or fall back to bare 'icont' on PATH -- fix the shared tree, then re-run.\n" >&2
        return 1
    fi
    printf '%s\n' "$c"
}
# ⭐ THE ONE-STEP DRIVER (hq_P 2026-08-30, FLEET-16 all-hands consolidation). `icon <file>` COMPILES AND RUNS
# in a single invocation, which is what an oracle caller with a one-shot `[bin] + flags + [name]` contract needs
# -- corpus_suite_harness.py's run_oracle() is exactly that shape, so capture-oracle-refs could not drive the
# two-step icont/iconx pair at all. Same shared tree, same loud-refusal contract as its two siblings above.
# ⛔ This does NOT deprecate icont_bin/iconx_bin: a BENCHMARK must keep the compile and the run separate so it
# times only the run, and this driver folds the two together by design. Grading wants one step; timing wants two.
icon_bin() {
    local c="/home/resources/icon-master/bin/icon"
    if [ ! -x "$c" ]; then
        printf "⛔ THE SHARED ICON ORACLE (icon, one-step driver) IS MISSING: %s\n" "$c" >&2
        printf "   Grading an Icon harness with it absent prints a full, plausible, entirely false all-FAIL table.\n" >&2
        printf "   Do not hand-assemble a path or fall back to bare 'icon' on PATH -- fix the shared tree, then re-run.\n" >&2
        return 1
    fi
    printf '%s\n' "$c"
}
iconx_bin() {
    local c="/home/resources/icon-master/bin/iconx"
    if [ ! -x "$c" ]; then
        printf "⛔ THE SHARED ICON ORACLE (iconx) IS MISSING: %s\n" "$c" >&2
        printf "   Grading or timing an Icon harness with it absent prints a full, plausible, entirely false all-FAIL table.\n" >&2
        printf "   Do not hand-assemble a path or fall back to bare 'iconx' on PATH -- fix the shared tree, then re-run.\n" >&2
        return 1
    fi
    printf '%s\n' "$c"
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ⭐ THE PROLOG AND JVM-ICON RIVALS (hq_P s272, at CEO's instruction; Lon installed swipl+gprolog, CEO built jcon).
# Same loud-refusal contract as icont_bin/iconx_bin above and for the same reason: another root or container may not
# have these, and a benchmark harness that silently falls back to a missing rival prints a plausible, entirely FALSE
# column rather than refusing. ⛔ Never hand-assemble these paths and never fall back to a bare name on PATH.
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
swipl_bin() {
    local c="/usr/bin/swipl"
    if [ ! -x "$c" ]; then
        printf "⛔ THE SWI-PROLOG RIVAL IS MISSING: %s\n" "$c" >&2
        printf "   A Prolog rival column measured with it absent is not slow, it is ABSENT -- and a harness that fills it anyway publishes a false number.\n" >&2
        printf "   Do not hand-assemble a path or fall back to bare 'swipl' on PATH -- install it, then re-run.\n" >&2
        return 1
    fi
    printf '%s\n' "$c"
}
# ⛔⭐ THE GNU PROLOG ORACLE IS THE PRISTINE 1.6.0 UNDER /home/resources, NOT /usr/bin (Lon 2026-10-10 10:2x CDT, in-chat to the ceo, verbatim: "Get the new oracle 1.6.0 and
# begin using it instead of the older one."; ceo CEO-1598, the ORACLE-SWAP PROCEDURE of RULES.md). The vendored GNU Prolog source (corpus/packages/prolog/gnu_prolog) IS 1.6.0 and
# /usr/bin/gprolog is 1.4.5, which dies on a 1.6.0 format directive in pl2wam's all.pl; the monitor fork gprolog-mon/gprolog-1.6.0 is 1.6.0 too, so the graded oracle and the
# monitor now agree. The pristine build (configure --prefix under gprolog-mon/pristine, 2026-09-23, zero Pl_Mon references -- the fork carries 2) is the ONE grading binary; gplc
# beside it is the ONE compiler. Nothing under ../harness/scripts/ names gprolog or gplc any other way (test_gate_no_bare_gprolog_or_gplc_outside_the_accessors.sh).
# ⛔ THE ACCESSORS NAME WRAPPERS, NOT THE BINARIES (the coo, measured 2026-10-10 10:3x): 1.6.0's gprolog runs pl2wam FROM PATH, so with /usr/bin first a consult
# compiles with 1.4.5's pl2wam and fails ("unknown option --include"); ../harness/scripts/oracle_gprolog.sh and ../harness/scripts/oracle_gplc.sh put the oracle's bin first and exec the
# real binary, and nothing else. The wrapper is what a caller runs; GPROLOG_ORACLE_DIR is where the binaries are, for a caller that must name the directory.
GPROLOG_ORACLE_DIR="/home/resources/gprolog-mon/pristine/gprolog-1.6.0/bin"
gprolog_bin() {
    local c="$GPROLOG_ORACLE_DIR/gprolog" w="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/oracle_gprolog.sh"
    if [ ! -x "$c" ] || [ ! -x "$w" ]; then
        printf "⛔ THE GNU-PROLOG ORACLE IS MISSING: %s (wrapper %s)\n" "$c" "$w" >&2
        printf "   A Prolog column measured with it absent is not slow, it is ABSENT -- and a harness that fills it anyway publishes a false number.\n" >&2
        printf "   Do not hand-assemble a path or fall back to bare 'gprolog' on PATH (that is 1.4.5, retired as the oracle 2026-10-10, CEO-1598) -- rebuild the pristine drop, then re-run.\n" >&2
        return 1
    fi
    printf '%s\n' "$w"
}
gplc_bin() {
    local c="$GPROLOG_ORACLE_DIR/gplc" w="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/oracle_gplc.sh"
    if [ ! -x "$c" ] || [ ! -x "$w" ]; then
        printf "⛔ THE GNU-PROLOG COMPILER gplc IS MISSING: %s (wrapper %s)\n" "$c" "$w" >&2
        printf "   Do not hand-assemble a path or fall back to bare 'gplc' on PATH (that is 1.4.5, retired as the oracle 2026-10-10, CEO-1598) -- rebuild the pristine drop, then re-run.\n" >&2
        return 1
    fi
    printf '%s\n' "$w"
}
# ⛔⭐⭐⭐ XSB IS THE THIRD PROLOG ORACLE, FOR THE XSB PACKAGE (Lon 2026-10-23 11:3x CDT, in-chat to the cfo, verbatim: "Since SWIPL does not have all XSB, we should begin
# to use XSB system as the third oracle."; ceo CEO-1927, RULES.md § Oracles FACT RULE of the same name). XSB 5.0.0 (Green Tea, built 2026-09-13) under /home/resources/prologs/xsb
# grades packages/prolog/xsb_tests alone, each program run as XSB's own gentest.sh runs it ([NAME]. tell(temp). GOAL. told. on stdin of "xsb -e segfault_handler(warn).",
# testall.sh's options); swi_tests/xsb and every other Prolog package keep their oracle. XSB_ORACLE_BIN is the launcher XSB ships (bin/xsb, a script that finds its own
# install); nothing under ../harness/scripts/ names it any other way (test_gate_no_bare_xsb_outside_the_accessor.sh).
XSB_ORACLE_BIN="/home/resources/prologs/xsb/XSB/bin/xsb"
xsb_bin() {
    local c="$XSB_ORACLE_BIN"
    if [ ! -x "$c" ]; then
        printf "⛔ THE XSB ORACLE IS MISSING: %s\n" "$c" >&2
        printf "   An XsbTests ref cut or a column measured with it absent is not slow, it is ABSENT -- and a harness that fills it anyway publishes a false number.\n" >&2
        printf "   Do not hand-assemble a path or fall back to a bare 'xsb' on PATH (ORACLES.md, XSB, CEO-1927) -- rebuild the shared drop, then re-run.\n" >&2
        return 1
    fi
    printf '%s\n' "$c"
}
# ⛔⭐⭐⭐ UNICON IS THE ORACLE FOR UNICON-ONLY PROGRAMS (Lon 2026-10-31, in-chat to the ceo, verbatim: "Let's extend Icon to Unicon with a command-line switch, or if it is a super set then a switch is not needed."; ceo CEO-2072,
# which supersedes the 2026-09-11 "Do not use Unicon for anything" ruling (CEO-570) for the superset's own surface and for nothing else). The Unicon translator `unicon` (the Unicon git drop d784f58, built in place under
# /home/resources/unicon by build_unicon_oracle.sh) cuts the refs of the programs that carry the Unicon markers (class, package, import, method); Arizona icont/iconx (icont_bin/iconx_bin above) stay the oracle of plain Icon.
# ⛔ The 2026-09-11 ruling's SECOND reason stands: Unicon is NEVER a normalizer. `unicon -E` rewrites a source (it inserts the semicolons the Icon reader leaves implicit), and a rewrite applied at grade time means the artifact graded
# is not the artifact in the repo -- the source in the corpus IS the source (CEO-567). test_gate_no_bare_unicon_outside_the_accessor.sh holds both: the oracle is named one way, and no script runs it with -E. ORACLES.md, UNICON.
UNICON_ORACLE_BIN="/home/resources/unicon/bin/unicon"
unicon_bin() {
    local c="$UNICON_ORACLE_BIN"
    if [ ! -x "$c" ]; then
        printf "⛔ THE UNICON ORACLE IS MISSING: %s\n" "$c" >&2
        printf "   A Unicon ref cut or a column measured with it absent is not slow, it is ABSENT -- and a harness that fills it anyway publishes a false number.\n" >&2
        printf "   Do not hand-assemble a path or fall back to a bare 'unicon' on PATH (ORACLES.md, UNICON, CEO-2072) -- run build_unicon_oracle.sh, then re-run.\n" >&2
        return 1
    fi
    printf '%s\n' "$c"
}
# ⛔⭐ JCON RE-EXECS BY NAME, SO THE ACCESSOR EXPORTS PATH -- CALLING IT BY ABSOLUTE PATH ALONE IS NOT ENOUGH (CEO s272,
# measured: the launcher scripts resolve their siblings off PATH). Use as: eval "$(jcon_path_export)"; then run jcont/jcon.
jcont_bin() {
    local c="/home/resources/jcon-master/bin/jcont"
    if [ ! -x "$c" ]; then
        printf "⛔ THE JCON (JVM Icon) RIVAL IS MISSING: %s\n" "$c" >&2
        printf "   Do not hand-assemble a path or fall back to bare 'jcont' on PATH -- rebuild the shared drop, then re-run.\n" >&2
        return 1
    fi
    printf '%s\n' "$c"
}
jcon_bin() {
    local c="/home/resources/jcon-master/bin/jcon"
    if [ ! -x "$c" ]; then
        printf "⛔ THE JCON (JVM Icon) RUNNER IS MISSING: %s\n" "$c" >&2
        printf "   Do not hand-assemble a path or fall back to bare 'jcon' on PATH -- rebuild the shared drop, then re-run.\n" >&2
        return 1
    fi
    printf '%s\n' "$c"
}
jcon_path_export() {
    local d="/home/resources/jcon-master/bin"
    if [ ! -x "$d/jcont" ] || [ ! -x "$d/jcon" ]; then
        printf "⛔ THE JCON RIVAL IS MISSING under %s -- refusing to export a PATH that would let a bare 'jcont' resolve elsewhere.\n" "$d" >&2
        return 1
    fi
    printf 'export PATH="%s:$PATH"\n' "$d"
}
rakudo_bin() {
    local local_r="/home/resources/rakudo-local/bin/raku" apt_r="/usr/bin/raku"
    if [ -x "$local_r" ]; then printf '%s\n' "$local_r"; return 0; fi
    if [ -x "$apt_r" ]; then printf '%s\n' "$apt_r"; return 0; fi
    printf "⛔ THE RAKUDO RIVAL IS MISSING: neither %s nor %s exists.\n" "$local_r" "$apt_r" >&2
    printf "   Do not fall back to a bare 'raku' on PATH -- build rakudo-local (task rakudo-build-current) or apt install rakudo, then re-run.\n" >&2
    printf "   LABEL DUTY (FACT RULE): every grid quoting a rakudo arm names its version (rakudo-local 2026.x vs apt 2022.12).\n" >&2
    return 1
}
fpc_bin() {
    local c="/usr/bin/fpc"
    if [ ! -x "$c" ]; then
        printf "⛔ THE FPC (Free Pascal) RIVAL IS MISSING: %s (apt install fpc -- Lon-granted 2026-08-27, fpc 3.2.2 = current stable).\n" "$c" >&2
        return 1
    fi
    printf '%s\n' "$c"
}
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ⭐ CSNOBOL4 ORACLE ACCESSOR (row snobol4-csnobol4-suite-graded).  Phil Budne's CSNOBOL4 is the vendored
# csnobol4_suite's OWN home-dialect oracle -- `sbl -bf` is NOT a substitute for grading it: 30 of the suite's
# 120 programs go false-red under sbl -bf (RULES.md FACT RULE s261), because the suite exercises CSNOBOL4-only
# extensions (ORD, &DUMP, popen, ...) that SPITBOL/SCRIP never claim to implement. Built via
# build_csnobol4_oracle.sh from snobol4ever/csnobol4 (`make -f Makefile2 xsnobol4`, copied to `snobol4`).
# ⛔ SHARED ONLY, same law as x64/icon-master/jcon-master above (Lon s261: no per-root clone, no symlink,
# refuse loudly rather than silently reward a stray local copy). ⚠️ build_csnobol4_oracle.sh's own path math
# (`$ROOT/csnobol4`, two levels above ../harness/scripts/) still targets a PER-ROOT location, not this shared one -- that
# script predates the shared-oracle convention and is stale in the same way old sbl/icon docs were; running it
# as-is would create exactly the per-root divergence hazard this file's other accessors were built to prevent.
# Flagged, not fixed here (out of scope for this row) -- the shared binary already exists and this accessor
# only ever reads it.
# ⛔ NOT ON PATH -- never hand-assemble this path in a caller.
# ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
csnobol4_bin() {
    local c="/home/resources/csnobol4/snobol4"
    if [ ! -x "$c" ]; then
        printf "⛔ THE CSNOBOL4 ORACLE IS MISSING: %s\n" "$c" >&2
        printf "   Restore/build the SHARED tree at /home/resources/csnobol4 (see build_csnobol4_oracle.sh for\n" >&2
        printf "   the build recipe -- but build INTO the shared root, never a per-root clone; Lon s261).\n" >&2
        printf "   Do not hand-assemble a path or fall back to a bare 'snobol4'/'csnobol4' on PATH.\n" >&2
        return 1
    fi
    printf '%s\n' "$c"
}
