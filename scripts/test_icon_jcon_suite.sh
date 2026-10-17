#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/lib_one_runner.sh" && one_runner_guard "${0##*/}" "$(one_runner_population_of "$@")" || exit 2
# ⛔ THE INSTRUMENTATION SWITCH (--stlimit, which carries the call/return hooks Icon &trace rides) IS EACH PROGRAM'S OWN compile_args DECLARATION, read per program below (clause 8 (f), CEO-1281): this runner exported SCRIP_SNO_STMTKW=1 for every program until 2026-09-26
# ../harness/scripts/test_icon_jcon_suite.sh — grades SCRIP m3+m4 against the vendored JCON test suite
# (corpus/packages/icon/jcon_tests/: 91 .icn, 83 with a .ref oracle, 21 with a .dat companion, plus link1 graded by a .ref we cut from icont/iconx with its .args).
# Row jcon-tests-vendor-script-run. Self-contained. Run from anywhere with no env vars.
#
# FOUR-WAY VERDICT, not the usual PASS/FAIL/REFUSED: a jcon test is real, unmodified upstream Icon
# (see corpus/packages/icon/jcon_tests/README.md -- deliberately NOT semicolon-converted, unlike
# jcon-compiler/), so a program written in a construct SCRIP's semicolon-required dialect rejects at
# PARSE time is not a runtime defect -- it is a DIALECT GAP, and this suite's own GOAL requires it be
# counted and NAMED as its own class (REJECT), never silently folded into FAIL or dropped. Detected by
# scrip's own stable signature: "icon: parse error" on stderr, both modes (verified: m3 and m4 both
# print it verbatim and both exit rc=1 on the identical construct).
#
# .dat COMPANION CONVENTION: JCON's own `addtest` harness feeds a .dat file BOTH as argv[1] AND as
# stdin (`./prog file.dat <file.dat >file.ref`) -- reproduced here exactly, not stdin-only (a jcon test
# reading *args as well as reading stdin would silently see an empty argv otherwise).
#
# CWD FIX (seat02, 2026-09-05, icon-jcon-suite-39 11th pass): a jcon program may ALSO open its own .dat
# companion by a bare relative literal (e.g. fncs1.icn's `open("fncs1.dat")`), which this script's own
# invocation cwd never satisfied before -- FAIL was actually "file not found", not a compiler defect,
# a pure instrument bug (confirmed: fncs1 diffs 0 lines once its cwd is right). Each test now runs from
# its own private $WORK/<name>.rundir/ (never $CORPUS itself -- a program that WRITES a scratch file by
# relative name, e.g. loadfunc.icn's tmp.icn/foo.baz, must never touch the tracked corpus working tree)
# with the .dat companion copied in under its own basename; only the KNOWN .dat convention is covered,
# not arbitrary other literal filenames a program might reference (recent.icn's `open(".")` and its own
# `open("recent.dat")` remain unaddressed -- moot today since it dies earlier on an unrelated sortf bug,
# see FINDING-2026-09-05-seat02-icon-jcon-suite-census-11th-pass*.md).
#
# ⛔⭐ THE GRADED STREAM IS STDOUT **AND** STDERR, COMBINED, BECAUSE THAT IS THE CONTRACT THE .ref FILES
# WERE CUT UNDER (hq_P 2026-09-09, ceo CEO-445). Upstream's own harness is `prog < in > out 2>&1` and
# test_icon_arizona_suite.sh already reproduces it (`2>&1` at its :146/:163); this runner alone diffed
# STDOUT ONLY. Four programs write their ENTIRE output to stderr -- cxtrace, loadfunc, traceback, tracing
# (icont's runtime error and &trace reports go there) -- so this runner compared an EMPTY stdout against a
# full .ref and called it a wrong answer, forever, with nothing able to notice: the ref was right, the
# program was right, and the instrument was reading the wrong pipe. MEASURED before the change: all four
# FAIL/CRASH in both modes. ⛔ The stream and the rc rule are ONE defect with two halves -- see the rc note
# in verdict_of() -- and fixing either alone leaves all four still red, which is why they land together.
#
# NO-ORACLE SOURCES EXCLUDED, NOT GRADED AS MISSING: link2/load1/load2/tpp1-5 have no .ref by
# design (link targets and dynamic-load targets with no main; template-preprocessor inputs, not
# standalone programs -- see README.md). Globbing only *.icn with a matching *.ref (or a *.ref we cut
# from the oracle -- link1, cfo 2026-09-07) sidesteps them without a hardcoded exclude list that would
# silently go stale.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_flag_gate.sh" 2>/dev/null || { echo "⛔ REFUSED TO GRADE: lib_flag_gate.sh unloadable" >&2; exit 2; }
. "$HERE/lib_progress.sh" 2>/dev/null || { echo "⛔ REFUSED TO GRADE: lib_progress.sh unloadable -- a run that records nothing is a defect of that run (CEO-331)" >&2; exit 2; }
PROGRESS_CONFIG="$(progress_config_of_env)"   # every row declares what it ran under: the GC axis in this environment, else shipped (the board sets none per child)
# ⛔ COUNTED, NOT SWALLOWED, AND NOT FATAL EITHER. lib_progress.sh's header is explicit that it never hides
# the writer's rc and that the caller decides. Neither `|| true` nor `|| exit` is right here: swallowing
# turns "the table was never written" into silence, and aborting mid-loop would let one bookkeeping failure
# destroy a real measurement of 81 programs -- the reason gate_score_row is non-fatal by design. So the
# failures are counted and NAMED in the run's own output, which is what makes the receipt honest.
PROGRESS_FAILED=0
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
RT_SO="${RT_SO:-$ROOT/out/libscrip_rt.so}"
CORPUS="${CORPUS:-$S4E/corpus/packages/icon/jcon_tests}"
CORPUS_PUBLISHED="$S4E/corpus/packages/icon/jcon_tests"   # ⛔ the ONE population the JCON row in SCORE.md may ever name -- see the score-write guard at the foot of this file
# ⛔ icont_bin() comes from the ONE authority, never a hand-assembled path and never bare `icont` on PATH:
# CLAUDE.md's measured lesson is a seat that ran `command -v icont`, got nothing, and wrote "no Icon oracle
# exists" into a digest. The staleness arm below is the only consumer here, and it degrades to NAMING the
# rows it could not re-check rather than silently passing them.
. "$(dirname "${BASH_SOURCE[0]}")/lib_oracle_flags.sh"
# ⛔ CEO-1167 declared arena, same authority arizona's runner sources -- see lib_declared_arena.sh's own
# header for why every non-harness runner reads the SAME reader rather than growing its own SCRIP_HEAP_KB
# rule. geddump is the first entry here to carry one (heap_kb=8192): its live set fits the shipped 4096 KB
# cap, but rt_gcheap_grow commits only the triggering allocation per grow, never geometrically, so reaching
# a several-hundred-KB working set from the 128 KB default cost thousands of tiny mprotect+collect cycles
# and the program never finished inside this runner's timeout. A window that starts above the cap removes
# the growth ladder entirely -- measured 0.09-0.12s either way, byte-identical to geddump.ref.
. "$(dirname "${BASH_SOURCE[0]}")/lib_declared_arena.sh"
OUTSIDE="$CORPUS/OUTSIDE_ARIZONA_BASELINE.tsv"
# ⛔⭐ THE ONE-ORACLE RULE, APPLIED TO THIS PACKAGE (ceo CEO-470 on hq_P's measurement, 2026-09-09). A program
# ARIZONA icont cannot run has no ground truth, so it is OUT of the graded denominator and NAMED -- never
# hidden and never counted either way. The reader is the same shape test_snobol4_csnobol4_suite.sh uses for
# OUTSIDE_SPITBOL_BASELINE.tsv. ⛔ IT COSTS US TWO PASSES AND THAT IS THE POINT: htprep and prepro diffed
# ZERO against .ref files icont REFUSES to compile, so they were green cells resting on jcon's answers --
# the same defect as the sixteen jcon-cut refs re-cut this morning, except these three cannot be re-cut
# because the oracle will not run them. A false green is worth less than a smaller honest denominator.
is_outside_baseline() { [ -f "$OUTSIDE" ] && awk -F"\t" -v n="$1" '$1==n {f=1} END {exit f?0:1}' "$OUTSIDE"; }
outside_reason() { [ -f "$OUTSIDE" ] && awk -F"\t" -v n="$1" '$1==n {print $2; exit}' "$OUTSIDE"; }
OUTSIDE_LIST=""
ARENA_NAMES=""   # ⛔ initialized here, not merely appended-to in run_one -- an uninitialized ARENA_NAMES crashed test_icon_arizona_suite.sh under set -u the moment any entry declared heap_kb (same fix, one runner over)
MODE="all"
TIMEOUT=20

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)   MODE="$2";   shift 2 ;;
        --scrip)  SCRIP="$2";  shift 2 ;;
        --corpus) CORPUS="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        *) flaggate_reject "$1" "--mode --scrip --corpus --timeout" ;;
    esac
done
# ⛔⭐ THE SIDECAR PATHS ARE RE-BOUND HERE, AFTER --corpus IS PARSED (hq_V 2026-09-11): bound from the DEFAULT
# $CORPUS at load time, `--corpus <scratch>` graded the scratch tree while reading the PACKAGE's declarations --
# a run that silently mixes two trees' rules and reports one number, invisible at the default path.
OUTSIDE="$CORPUS/OUTSIDE_ARIZONA_BASELINE.tsv"
PKG_CSV="$CORPUS/ALL.csv"   # the attribute file the heap_kb declaration lives in (CEO-1167) -- rebound here, not at load time, for the identical reason OUTSIDE is (see the comment just above)

if [ ! -x "$SCRIP" ]; then
    echo "⛔ REFUSED TO GRADE: no scrip binary at $SCRIP — run make" >&2
    exit 2
fi
# ⛔⭐ STALE-BINARY PREFLIGHT (row harness-and-ladder-runner-refuse-on-a-stale-binary-like-the-artifact-regen-
# does, ceo -> hq_T 2026-09-04). The line above proves a binary EXISTS; this one proves it is the binary this
# tree describes. ceo's witness, twice on 2026-09-04: a 10:57 binary graded at 14:03 read RED, then GREEN after
# an incremental make -- a vendor board is exactly where that is least visible, because a plausible all-FAIL
# table is this class's normal output. NO LOGIC HERE: util_require_fresh.sh sources gate_require_fresh from
# lib_gate.sh, the ONE authority (hq_B 4c7253e99) -- never a second copy of the staleness rule.
"$HERE/util_require_fresh.sh" --gate test_icon_jcon_suite "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so" || exit 2
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
GATE_NAME=test_icon_jcon_suite gate_bin_watch "$SCRIP" "${RT_DIR:-$HERE/../../SCRIP/out}/libscrip_rt.so"
# ⛔⭐ THE TREE MOVED UNDER THIS BOARD, and the stamp that names the tree this row actually graded
# (coo 2026-09-10, COO-54, on the coo's own witness: a pass recorded one corpus hash and a background job
# moved corpus eight seconds later; gate_bin_watch stayed silent and was right to, because the BINARY had
# not moved). One call: gate_tree_watch exports S4E_TREE_AT_START in util_score_row's own vocabulary AND
# takes the baseline, so this board stops stamping HEAD-at-WRITE-time and starts refusing a split reading.
GATE_NAME=test_icon_jcon_suite gate_tree_watch "$(cd "$HERE/../.." && pwd)"
if [ ! -d "$CORPUS" ]; then
    echo "⛔ REFUSED TO GRADE: no jcon_tests corpus at $CORPUS" >&2
    exit 2
fi

OUTDIR="$(dirname "$RT_SO")"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# ⭐ THE DECLARED COMPILE SWITCHES, READ ONCE, HERE IN THE MAIN SHELL (clause 8 (f), CEO-1281): declared_memory_table validates every cell
# of the attribute file through the harness's own validators, so a refused cell refuses this board before one program is graded;
# run_one, which runs inside a command substitution, only looks its program's compile_args up with one awk.
CA_TBL="$WORK/compile_args.tsv"
declared_memory_table "$PKG_CSV" > "$CA_TBL" || { echo "⛔ REFUSED TO GRADE rc=2: a cell in $PKG_CSV is refused (named above) -- this board does not grade around it" >&2; exit 2; }
# ⛔⭐ A UNIT WITH NO DECLARING ROW IS NAMED, NEVER GRADED SILENTLY AT THE DEFAULTS (RULES.md 8 (f); coo 2026-09-27): run_mode asks once per
# graded unit, here in the main shell, and the names print beside the declared-arena receipt, empty or not. The three driver-graded
# libraries (link2, load1, load2) had no row until corpus 2026-09-27, and run_one looked their attributes up under the DRIVER's name.
DECL_CSV_OF_TABLE="$PKG_CSV"; declare -A UNDECLARED=() DECL_ASKED=()
decl_ask() { [ -n "${DECL_ASKED[$1]:-}" ] && return 0; DECL_ASKED[$1]=1; declared_row_in_table "$CA_TBL" "$1"; case $? in 0) ;; 1) UNDECLARED[$1]=1 ;; *) exit 2 ;; esac; }

# classify one (mode, file) pair. Echoes "KIND" on stdout; KIND in PASS|FAIL|REJECT|CRASH|HANG.
# stdout of the PROGRAM itself is captured to $2 (a path), never mixed with our own echo.
run_one() {
    local mode="$1" icn="$2" want="$3" outfile="$4"
    local base="${icn%.icn}" name errf rc
    name=$(basename "$icn" .icn)
    errf="$WORK/err.txt"; : > "$errf"
    local dat="${base}.dat" IN=/dev/null; local -a prog_args=()
    local rundir="$WORK/$name.rundir"; mkdir -p "$rundir"
    if [ -f "$dat" ]; then IN="$dat"; prog_args=("$dat"); cp "$dat" "$rundir/$(basename "$dat")"; fi
    # ⛔⭐ THE PROGRAM'S OWN SOURCE TRAVELS WITH IT (hq_P 2026-09-09, ceo CEO-445). Upstream runs each test IN
    # the package directory, where <name>.icn sits beside the program by construction; we run in a private
    # rundir so a test that writes scratch files cannot touch the tracked tree, and that isolation silently
    # removed a file some tests READ. io.icn pipes `sed ... io.icn` and `ls io.[ids][tca][dnt]` -- it reads
    # its own source and lists its own companions -- so in a rundir holding only io.dat it produced 14 wrong
    # lines that looked exactly like an I/O defect. MEASURED both ways on this tree: 14 diff lines without
    # the source beside it, ZERO with it, same binary and same ref. ⛔ Only the entry's OWN source is copied,
    # never the whole package: the ref for that `ls` expects to see io.dat and io.icn and NOTHING ELSE, so
    # copying more would break the very test this fixes. The .ref is deliberately NOT copied for the same
    # reason. This is the same class the .dat line above already cures, one filename over.
    cp "$icn" "$rundir/$(basename "$icn")" 2>/dev/null || true
    # ⭐ TWO MORE SIDECARS, BOTH OURS AND BOTH DECLARED, NEVER INFERRED (cfo 2026-09-07, row every-package-runner-
    # prints-...: link1.icn was the package's one UNGRADED row, NEEDS_RUNNER_WIRING). `<name>.args` is the argv the
    # ref was cut with (test_demo_icon_jcon.sh's own convention, words split by the shell); the modules a program
    # `link`s are read from the program itself -- the entry IS the manifest, as that gate puts it -- and handed to
    # scrip beside it in BOTH modes, the same two-file build icont needs (`icont link1.icn link2.icn`).
    local args="${base}.args" m; local -a mods=()
    if [ -f "$args" ]; then prog_args=($(cat "$args")); fi
    # ⛔ THE `--` IS THE DRIVER'S, NOT THE PROGRAM'S (cfo 2026-09-07, measured on link1): `scrip --run f -- a b c`
    # strips the `--` and hands the program `a b c`, but a mode-4 binary is a plain executable and saw `--` as
    # argv[1] -- link1 printed `{{ -- }}` first, and every .dat program that reads *args (geddump, htprep,
    # mffsol, profsum, tgrlink) was handed `--` before its data file in m4 and could only FAIL there. So the
    # separator is added for m3 alone and the binary gets the program's own argv.
    local -a extra_args=(); [ "${#prog_args[@]}" -eq 0 ] || extra_args=(-- "${prog_args[@]}")
    # ⛔ EVERY NAME ON A link LINE, AND THE LINKS OF WHAT IT LINKS (coo 2026-09-25, hq_icon's measurement landing the Jcon drivers):
    # this sed captured only the FIRST name, so `link load2, load1` -- ordinary Icon -- copied load2.icn and not load1.icn, and
    # m3 refused the link ("cannot open load1.icn ... tried <rundir>/load1.icn") while m4 passed. Nor did it follow a library
    # that links a neighbour. Every comma-separated name is read, and each local module's own link lines are followed in turn.
    local -a _lq=("$icn"); local _ls _ln _lseen=" $(basename "$icn" .icn) "
    while [ "${#_lq[@]}" -gt 0 ]; do
        _ls="${_lq[0]}"; _lq=("${_lq[@]:1}")
        for _ln in $(sed -nE 's/#.*$//; s/^[[:space:]]*link[[:space:]]+(.*)$/\1/p' "$_ls" | tr ',"' '  '); do
            _ln="${_ln%.icn}"; case "$_lseen" in *" $_ln "*) continue ;; esac; _lseen="$_lseen$_ln "
            [ -f "$(dirname "$icn")/$_ln.icn" ] || continue
            mods+=("$(dirname "$icn")/$_ln.icn"); _lq+=("$(dirname "$icn")/$_ln.icn")
        done
    done
    # ⛔⭐ A LINKED MODULE TRAVELS WITH THE PROGRAM, exactly as the program's own source does one screen up
    # (hq_V 2026-09-11, measured on link1). `link link2` is resolved RELATIVE TO THE MAIN PROGRAM'S PATH, so
    # naming the program by its bare name in the rundir -- which is what makes &progname gradable at all --
    # moved that search to ./ and link1 died with `cannot open link2.icn (linked from link1.icn); tried:
    # .../ipl/procs/link2.icn, ./link2.icn` even though link2.icn was ALSO on the command line. The two
    # changes are one cure and must land together: argv carries the bare name, so the rundir must hold what
    # the bare name implies. ⛔ Still the program's OWN closure and never the package: only sources this
    # entry `link`s are copied, so io's rundir -- whose ref lists its directory and expects io.dat and io.icn
    # and nothing else -- is untouched, because io links nothing.
    local _mm; for _mm in ${mods[@]+"${mods[@]}"}; do cp "$_mm" "$rundir/$(basename "$_mm")" 2>/dev/null || true; done
    # ⛔⭐ AN $include'd FRAGMENT TRAVELS WITH ITS INCLUDER TOO (coo 2026-09-25, row instruments-container-or-library-splits-...,
    # ceo CEO-1272): a fragment is a CONTAINER graded through the program that splices it, and `$include "frag.icn"` is resolved
    # from the directory the bare name runs in -- so a program in a rundir holding only its own source died at the include in m3
    # while its m4 compile, made in place, passed (measured on the gate's fixture: m3_pass=0, m4_pass=1). The program is the
    # manifest here as for `link`: its $include lines, followed through the fragments it pulls in, name exactly what is copied.
    local -a _incq=("$icn"); local _src _inc _seen=" "
    while [ "${#_incq[@]}" -gt 0 ]; do
        _src="${_incq[0]}"; _incq=("${_incq[@]:1}")
        for _inc in $(sed -nE 's/^[[:space:]]*\$[[:space:]]*include[[:space:]]*"([A-Za-z0-9_.-]+)".*$/\1/p' "$_src"); do
            case "$_seen" in *" $_inc "*) continue ;; esac; _seen="$_seen$_inc "
            [ -f "$(dirname "$icn")/$_inc" ] || continue
            cp "$(dirname "$icn")/$_inc" "$rundir/$_inc" 2>/dev/null && _incq+=("$(dirname "$icn")/$_inc")
        done
    done
    # ⛔⭐ THE ENTRY KEY IS THE BARE NAME: jcon_tests is a flat package (no nested subdirs), unlike arizona's
    # general/mega -- util_build_package_suite.py writes the bare stem into ALL.csv's entry column here, and
    # using anything else would silently match nothing (see arizona's identical note at its own arena read).
    # ⛔ AND A DRIVER'S KEY IS ITS LIBRARY'S (CEO-1269; coo 2026-09-27): $name is the file that RUNS, so for NAME_driver it looked up
    # "NAME_driver", a row no table carries, while the unit is counted, named and recorded as NAME -- the key IPL and Arizona read.
    local _akey="${name%_driver}"
    # ⭐ THE DECLARATION RIDES THE COMMAND LINE AS SPITBOL'S SWITCHES (ceo CEO-1353, the coo's census): -d<kb>k -s<kb>k after --run and
    # the compile args in m3, leading the binary's own arguments in m4 (a -- before the program's argv, as the harness's run_m4), never
    # the compile step. ⛔ NEVER SCRIP_HEAP_KB: gc_heap.c reads it as the collector's initial WINDOW, so every declared program ran at
    # window = cap = 128 MB where the shipped window is 1 MB. An undeclared program's command line is byte-identical to before.
    local _sw
    if ! _sw=$(declared_arena_switches "$PKG_CSV" "$_akey"); then
        echo "⛔ REFUSED TO GRADE rc=2: $name carries a heap_kb or stack_kb cell this runner will not honour (reason above) -- grading it at the shipped default would publish a row whose sizes its own attribute file contradicts" >&2
        exit 2
    fi
    [ -n "$_sw" ] && ARENA_NAMES="${ARENA_NAMES:-} $name=[$_sw]"
    local -a _sw4=(); [ -n "$_sw" ] && { read -r -a _sw4 <<<"$_sw"; [ ${#prog_args[@]} -gt 0 ] && _sw4+=(--); }
    local _ca; _ca="$(declared_compile_args_from_table "$CA_TBL" "$_akey")" || exit 2
    # ⛔ A DRIVER RUN ONLY PUTS ITS OWN DIRECTORY FIRST ON IPATH (coo 2026-09-25, hq_icon's measurements): a driver's ref was cut over
    # the library shipped beside it, while every other program's ref was cut by icont against its INSTALLED IPL ucode, which the
    # directory first on IPATH would shadow with an older shipped namesake (Arizona ilib read red at 6850da706 exactly that way).
    local -a _ipath3=() _ipath4=()
    case "$name" in *_driver) _ipath3=(env "IPATH=$rundir${IPATH:+:$IPATH}"); _ipath4=(env "IPATH=$(dirname "$icn")${IPATH:+:$IPATH}") ;; esac
    case "$mode" in
        m3)
            # ⛔⭐ THE PROGRAM'S OWN NAME IN argv IS THE BARE NAME, NEVER THE ABSOLUTE PATH (hq_V 2026-09-11,
            # measured on kwds). This handed "$icn" -- an absolute path -- to the driver while already cd'd into
            # the rundir where the source was copied one screen up, so &progname echoed the whole path and the
            # program could not match ANY ref: /tmp/.../kwds.icn against the shipped `&progname: kwds.icn`. That
            # is a defect of the INVOCATION, not of scrip, and it read as a red cell in the published fraction.
            # corpus_suite_harness.py's run_m3 already carries exactly this cure (row suite-harness-argv-echoes-
            # a-mktemp-path-so-diagnostic-programs-cannot-be-graded: "Bare name in argv, explicit cwd so it still
            # resolves"); this runner never got it. ⛔ SCOPE, MEASURED BEFORE THE CHANGE rather than asserted: the
            # only programs whose output can turn on the spelling are the ones that print their own invocation or
            # their own filename -- sources naming &progname/&file (kwds, profsum, tgrlink) and .ref files quoting
            # a .icn name (io, kwds, recent, traceback, cxtrace, loadfunc, tracing, tpp). All nine gradable ones
            # were run both ways on a scratch corpus: kwds FAIL -> PASS, every other verdict byte-identical.
            # The mods stay absolute on purpose -- they are not argv[0] and nothing echoes them.
            ( cd "$rundir" && ${_ipath3[@]+"${_ipath3[@]}"} "$TIMEOUT_RETRY" "$TIMEOUT" "$SCRIP" --run $_ca $_sw "$(basename "$icn")" ${mods[@]+"${mods[@]}"} ${extra_args[@]+"${extra_args[@]}"} < "$IN" > "$outfile" 2>&1 )
            rc=$?
            ;;
        m4)
            # ⛔⭐ THE M4 BINARY IS BUILT UNDER A STABLE STATED NAME IN THE RUNDIR, NEVER A MKTEMP PATH
            # (CEO-569, hq_V 2026-09-11; the same cure the coo landed one level up for the rungs harness at
            # 413a0e0a6 and hq_B landed for arizona under CEO-557). It was "$WORK/${name}_bin" -- an ABSOLUTE
            # path under a mktemp root -- invoked by that absolute path, so a mode-4 binary, which IS the program
            # and correctly answers its own argv[0], reported a name that CHANGES EVERY RUN and that no .ref
            # could ever be cut from. &progname is argv[0] VERBATIM: measured on the oracle (Arizona icont/iconx
            # 9.5.25a) with one program under three invocations -- ./pn printed "./pn", the absolute path printed
            # the absolute path, and `iconx pn` printed "pn". A name nothing states is therefore not a defect in
            # the compiler and not a bad ref; it is an ungradable quantity, and pinning it is what makes the
            # question askable at all.
            # ⛔ INTO THE RUNDIR AND NOT BESIDE THE SOURCE, and the bare stem is load-bearing: io.icn lists its
            # own directory through `ls io.[ids][tca][dnt]` and `ls io.i?n io.d?t io.s?d`, patterns that require a
            # dot plus three characters -- a binary named `io` cannot match either, which is why this may land at
            # all. Measured across every .ref in the package: io is the ONLY program that lists its directory.
            local s="$WORK/$name.s" o="$WORK/$name.o" bin="$rundir/$name"
            # the shipped library first on the link search for a driver run only, as in the arizona runner (coo 2026-09-25)
            if ! ${_ipath4[@]+"${_ipath4[@]}"} "$TIMEOUT_RETRY" "$TIMEOUT" "$SCRIP" --compile --target=x86 $_ca "$icn" ${mods[@]+"${mods[@]}"} < /dev/null > "$s" 2>"$errf"; then
                : > "$outfile"; rc=1
            elif grep -q 'icon: parse error' "$errf"; then
                : > "$outfile"; rc=1
            elif ! as "$s" -o "$o" 2>>"$errf"; then
                : > "$outfile"; rc=1
            elif ! gcc -no-pie "$o" -L"$OUTDIR" -lscrip_rt -Wl,-rpath,"$OUTDIR" -lm -o "$bin" 2>>"$errf"; then
                : > "$outfile"; rc=1
            else
                # ⭐ BARE RELATIVE NAME, matching run_m4 in corpus_suite_harness.py exactly: a mode-4
                # binary's argv IS the program's argv, so what we type here is what &progname answers.
                ( cd "$rundir" && PATH="$rundir:$PATH" "$TIMEOUT_RETRY" "$TIMEOUT" "$name" ${_sw4[@]+"${_sw4[@]}"} ${prog_args[@]+"${prog_args[@]}"} < "$IN" > "$outfile" 2>&1 )
                rc=$?
            fi
            ;;
    esac
    if [ "$rc" -eq 124 ]; then echo "HANG"; return; fi
    if grep -q 'icon: parse error' "$outfile" "$errf" 2>/dev/null; then echo "REJECT"; return; fi
    if [ "$rc" -ge 128 ]; then echo "CRASH"; return; fi
    # ⛔⭐ A NONZERO rc IS NOT A FAILURE IN THIS SUITE, AND MAKING IT ONE HID FOUR PROGRAMS (hq_P 2026-09-09,
    # CEO-445). Upstream's own contract -- tests/general/Test-icon, which is also what
    # test_icon_arizona_suite.sh reproduces -- runs `prog < in > out 2>&1` and diffs out against .ref. It
    # never reads the exit status, because a jcon/Icon test that ENDS IN A RUNTIME ERROR is a legitimate
    # test whose expected output IS the error report: traceback.icn exits 1 under icont by design, and so
    # do errors.icn and loadfunc.icn. Blanket-failing a nonzero rc marked all three FAIL before their text
    # was ever compared, so their refs could not be falsified in either direction -- the same shape as an
    # xfail marker, arrived at accidentally. The two verdicts that DO turn on rc are kept above: 124 is the
    # timeout firing (HANG) and >=128 is a signal (CRASH), neither of which upstream can express because it
    # has no timeout and no crash bucket. Everything else is decided by the text, as upstream decides it.
    # ⛔⭐ ONE ERROR VOICE (Lon 2026-09-12, RULES.md § ONE ERROR VOICE, CEO-625): the runtime prints SCRIP's own error shape;
    # the .ref pins icont's. The captured stream is rendered through the Icon EQUIVALENCE LIST (util_render_error_voice.py)
    # and THAT is diffed -- every field SCRIP printed is carried, a block the list cannot render stays as it is and reads red.
    python3 "$HERE/util_render_error_voice.py" icon < "$outfile" > "$outfile.icon" 2>/dev/null || cp "$outfile" "$outfile.icon"
    if diff -q "$outfile.icon" "$want" >/dev/null 2>&1; then echo "PASS"; else echo "FAIL"; fi
}

# ⛔⭐ THE PREPROCESS-ONLY CONTRACT (hq_icon, SCRIP 999a62f58: scrip -E prints what icont -E prints; coo 2026-09-25, the naming hq_icon
# accepted 21:0x). tpp.icn is graded by preprocessing, as upstream grades it: `scrip -E tpp.icn`, stderr then stdout, byte for byte
# against tpp.E.ref (cut from icont -E under the one-oracle rule; Jcon's own tpp.ref was Jcon's preprocessor text) and the declared
# exit (1, deliberate errors). PREPROCESS.tsv names each contract: program<TAB>argv<TAB>rc. Every argv file is a program graded by
# the one run under its own name; the fragments it $includes are CONTAINERS (CONTAINERS.tsv, CEO-1272). Each mode's pass runs the
# contract itself -- the preprocessor is the frontend both modes share, and -E emits no code.
PRE_TSV="$CORPUS/PREPROCESS.tsv"; PRE_NAMES=" "
if [ -f "$PRE_TSV" ]; then
    while IFS=$'\t' read -r _pp _pargv _prc _prest; do
        case "$_pp" in ''|'#'*) continue ;; esac
        [ -n "$_pargv" ] && [ -n "$_prc" ] || { echo "⛔ GATE REFUSES(2): $PRE_TSV row '$_pp' wants program<TAB>argv<TAB>rc" >&2; exit 2; }
        [ -f "$CORPUS/$(dirname "$_pp")/$(basename "$_pp" .icn).E.ref" ] || { echo "⛔ GATE REFUSES(2): $_pp names a preprocess contract but its .E.ref is not beside it" >&2; exit 2; }
        for _pa in $_pargv; do
            [ -f "$CORPUS/$(dirname "$_pp")/$_pa" ] || { echo "⛔ GATE REFUSES(2): $_pp's contract argv names $_pa, which is not shipped" >&2; exit 2; }
            [ -f "$CORPUS/$(dirname "$_pp")/${_pa%.icn}.ref" ] && { echo "⛔ GATE REFUSES(2): $_pa has its own .ref AND a preprocess contract -- two grading vehicles for one program" >&2; exit 2; }
            PRE_NAMES="$PRE_NAMES$(basename "$_pa") "
        done
    done < "$PRE_TSV"
fi

run_mode() {
    local mode="$1"
    local pass=0 fail=0 reject=0 crash=0 hang=0
    local -a reject_names=() fail_names=() crash_names=() hang_names=()
    local _want _nsub _t0 _secs
    local icn std kind outfile
    for icn in "$CORPUS"/*.icn; do
        [ -f "$icn" ] || continue
        case "$(basename "$icn")" in ALL.*) continue ;; esac   # our own generated container is not a shipped program -- see the census loop below
        case "$(basename "$icn")" in *_driver.icn) continue ;; esac   # a driver is its library's grading vehicle, graded below under the library's name (CEO-1269)
        case "$PRE_NAMES" in *" $(basename "$icn") "*) continue ;; esac   # graded by its preprocess contract below, never run as a program
        std="${icn%.icn}.ref"
        [ -f "$std" ] || std="${icn%.icn}.ref"   # `.ref` is a ref WE cut from icont/iconx with `<name>.args` (README.md), for a shipped program upstream ships no .ref for
        # ⛔⭐ A LIBRARY IS GRADED BY ITS DRIVER, UNDER ITS OWN NAME (ceo CEO-1269; coo 2026-09-25): when NAME_driver.icn and its .ref
        # ship beside NAME.icn, the driver is what RUNS (run_one copies the linked NAME.icn into its rundir) and NAME is what is
        # counted and recorded. A library with its own .ref AND a driver is two vehicles for one program and refuses.
        exe="$icn"; _drv="${icn%.icn}_driver"
        if [ -f "$_drv.icn" ] && [ -f "$_drv.ref" ]; then
            [ -f "${icn%.icn}.ref" ] && { echo "⛔ GATE REFUSES(2): $(basename "$icn" .icn) has its own .ref AND a driver $(basename "$_drv") -- two grading vehicles for one library (CEO-1269)" >&2; exit 2; }
            exe="$_drv.icn"; std="$_drv.ref"
        fi
        [ -f "$std" ] || continue   # no-oracle source (link2/load*/tpp*) — excluded, not MISSING
        is_outside_baseline "$(basename "$icn" .icn)" && continue
        case "$(basename "$icn")" in tpp.icn) continue;; esac   # tpp.ref is jcon PREPROCESSOR TEXT output, not program output (its body is deliberately-invalid Icon like `abc 11`); ungradable by execution — named exclusion, same class as the no-.ref sources above
        outfile="$WORK/out.txt"
        name=$(basename "$icn" .icn)
        rr_admits "$name" || continue
        decl_ask "$name"
        _want="$std"
        _t0="$(progress_clock)"; kind=$(run_one "$mode" "$exe" "$_want" "$outfile"); _secs="$(progress_secs_since "$_t0")"   # the mode's own wall for its row (CEO-1676 (c))
        # ⭐ THE PROGRESS DATABASE, ONE ROW PER PROGRAM PER MODE (CEO-331). Placed at the SINGLE point where
        # this runner already decides a per-program verdict, so the recorded outcome and the counted one are
        # the same value -- a second classification here would be a second opinion that drifts. $kind is
        # already exactly the writer's vocabulary (PASS|FAIL|REJECT|CRASH|HANG), so nothing is translated.
        progress_append package jcon icon "$name" "$mode" "$kind" "$_secs" || PROGRESS_FAILED=$((PROGRESS_FAILED+1))
        case "$kind" in
            PASS)   pass=$((pass+1)) ;;
            FAIL)   fail=$((fail+1)); fail_names+=("$name") ;;
            REJECT) reject=$((reject+1)); reject_names+=("$name") ;;
            CRASH)  crash=$((crash+1)); crash_names+=("$name") ;;
            HANG)   hang=$((hang+1)); hang_names+=("$name") ;;
        esac
    done
    if [ -f "$PRE_TSV" ]; then
        local _pp _pargv _prc _prest _pgot _pa
        while IFS=$'\t' read -r _pp _pargv _prc _prest; do
            case "$_pp" in ''|'#'*) continue ;; esac
            if rr_selected; then _adm=0; for _pa in $_pargv; do rr_admits "$(basename "$_pa" .icn)" && _adm=1; done; [ "$_adm" = 1 ] || continue; fi
            _t0="$(progress_clock)"
            ( cd "$CORPUS/$(dirname "$_pp")" && "$TIMEOUT_RETRY" "$TIMEOUT" "$SCRIP" -E $_pargv < /dev/null > "$WORK/pp.out" 2> "$WORK/pp.err" ); _pgot=$?
            _secs="$(awk -v d="$(progress_secs_since "$_t0")" -v n="$(echo $_pargv | wc -w)" 'BEGIN { printf "%.3f", d / (n > 0 ? n : 1) }')"   # one run, split over its rows
            if cat "$WORK/pp.err" "$WORK/pp.out" | cmp -s - "$CORPUS/$(dirname "$_pp")/$(basename "$_pp" .icn).E.ref" && [ "$_pgot" = "$_prc" ]; then kind=PASS
            elif [ "$_pgot" = 124 ]; then kind=HANG; elif [ "$_pgot" -ge 128 ]; then kind=CRASH; else kind=FAIL; fi
            for _pa in $_pargv; do
                name="$(basename "$_pa" .icn)"
                progress_append package jcon icon "$name" "$mode" "$kind" "$_secs" "preprocess-only contract: scrip -E $_pargv against icont -E (stderr then stdout, rc $_prc) -- the frontend both modes share" </dev/null || PROGRESS_FAILED=$((PROGRESS_FAILED+1))
                case "$kind" in
                    PASS)  pass=$((pass+1)) ;;
                    FAIL)  fail=$((fail+1)); fail_names+=("$name") ;;
                    CRASH) crash=$((crash+1)); crash_names+=("$name") ;;
                    HANG)  hang=$((hang+1)); hang_names+=("$name") ;;
                esac
            done
            echo "PREPROCESS_CONTRACT ($mode) $_pp argv=\"$_pargv\" want_rc=$_prc got_rc=$_pgot verdict=$kind"
        done < "$PRE_TSV"
    fi
[ "${PROGRESS_FAILED:-0}" -eq 0 ] || echo "⛔ PROGRESS DB: $PROGRESS_FAILED per-program appends have FAILED so far in this run -- this run is not fully recorded (CEO-331); the board lines below still stand, the table does not" >&2
    local mode_total=$((pass+fail+reject+crash+hang))
    echo "--- jcon ($mode): PASS=$pass FAIL=$fail REJECT=$reject CRASH=$crash HANG=$hang TOTAL=$mode_total ---"
    [ "$reject" -gt 0 ] && echo "    REJECT (dialect gap, semicolon-required): ${reject_names[*]}"
    [ "$fail" -gt 0 ]   && echo "    FAIL (wrong output): ${fail_names[*]}"
    [ "$crash" -gt 0 ]  && echo "    CRASH: ${crash_names[*]}"
    [ "$hang" -gt 0 ]   && echo "    HANG (>${TIMEOUT}s): ${hang_names[*]}"
    eval "${mode}_PASS=$pass"
    # ⛔⭐ THE RED NAMES LEAVE run_mode BECAUSE THE ROW NEEDS THEM (ceo CEO-545): when the modes disagree the
    # row is the AND PER PROGRAM, and the AND is computed from the UNION OF RED NAMES -- never from
    # total minus two pass counts, which double-subtracts a program red in both modes. These four arrays
    # were already built for the printed fail lists one screen up; only their scope was missing.
    eval "${mode}_RED_NAMES=\"${fail_names[*]:-} ${reject_names[*]:-} ${crash_names[*]:-} ${hang_names[*]:-}\""
    # ⛔ TOTAL IS THE LOOP'S OWN DENOMINATOR, NEVER A SEPARATE `ls *.ref` RECOUNT: jcon_tests carries one
    # orphaned .ref (linking.ref) with no matching .icn -- a stray in the vendored upstream, harmless to
    # leave in place (provenance), but counting it as part of TOTAL would assert a witness this suite
    # never actually graded. RULES.md § A PROBE ASSERTS ITS NAMED WITNESS, NEVER A POSITIONAL DENOMINATOR.
    eval "${mode}_TOTAL=$mode_total"
}

# ⛔⭐ POPULATION LAW (Lon, ruled 2026-09-04 via hq_B for the Arizona suite; brought to jcon by hq_I
# 2026-09-05 on ceo ruling CEO-294 "jcon onto the arizona population shape"). THE COUNTED POPULATION IS
# EVERY .icn THIS PACKAGE SHIPS, not merely the subset carrying a .ref oracle today. A shipped program with
# no oracle is UNGRADED -- zero of the population, never PASS -- and it may NEVER be silently dropped from
# the denominator. SHIPPED/GRADED/GAP are computed fresh on every run, never hand-maintained, and the GAP is
# NAMED rather than merely counted, so a reader can see exactly which programs are carrying a zero.
# ⚠️ THIS MOVES THE PUBLISHED FRACTION AND THAT IS THE POINT, NOT A REGRESSION: jcon reported m3 45/81
# before this landed and reports m3 45/91 after it. Identical passes, honest denominator. Anyone diffing the
# leaderboard across this commit must read it as a denominator change, not as ten programs breaking.
SHIPPED=0; GRADED=0; GAP_NAMES=""
# ⛔⭐ A CONTAINER IS NOT A SHIPPED PROGRAM (ceo CEO-1272; coo 2026-09-25): CONTAINERS.tsv names the files that are not a
# compilation unit on their own (tpp1..tpp5, $include'd by tpp.icn), each with its measurement, and lib_inventory.sh takes them
# out of shipped -- this census reads the same list so the board's shipped and the inventory's are one number.
. "$(dirname "${BASH_SOURCE[0]}")/lib_inventory.sh"
_cn="$(inventory_container_names "$CORPUS")" || { echo "⛔ GATE REFUSES(2): CONTAINERS.tsv is malformed (named above) -- the shipped census cannot be read"; exit 2; }
CONTAINER_NAMES=" $(printf '%s' "$_cn" | tr '\n' ' ') "
for _icn in "$CORPUS"/*.icn; do
    [ -f "$_icn" ] || continue
# ⛔⭐ OUR OWN GENERATED CONTAINER IS NOT A SHIPPED PROGRAM (hq_I 2026-09-06, pre-empted rather than
# walked into). lib_inventory.sh already skips `ALL.*` when it counts shipped, and the ipl package paid
# for the disagreement: a `find -name '*.icn'` counted our generated ALL.icn as a vendored program, the
# runner said 852 where the container's own accounting said 851, and a VENDOR score carried a file we
# wrote. CEO-331 asks for an ALL.csv on this package next, which creates exactly that container here --
# so the census excludes it BEFORE the file exists, not after the number moves.
case "$(basename "$_icn")" in ALL.*) continue ;; esac
    # ⛔⭐ A DRIVER IS NOT A SHIPPED PROGRAM (CEO-1269): it is counted as its library, and a driver with no library refuses.
    case "$(basename "$_icn")" in *_driver.icn)
        [ -f "${_icn%_driver.icn}.icn" ] || { echo "⛔ GATE REFUSES(2): $(basename "$_icn") is a driver whose library $(basename "${_icn%_driver.icn}").icn is not shipped -- a vehicle with nothing to carry (CEO-1269)" >&2; exit 2; }
        continue ;; esac
    case "$CONTAINER_NAMES" in *" $(basename "$_icn") "*) continue ;; esac
    SHIPPED=$((SHIPPED+1))
    _b="$(basename "$_icn" .icn)"
    case "$PRE_NAMES" in *" $(basename "$_icn") "*) GRADED=$((GRADED+1)); continue ;; esac   # graded by its preprocess contract (PREPROCESS.tsv)
    if [ ! -f "${_icn%.icn}.ref" ] && ! { [ -f "${_icn%.icn}_driver.icn" ] && [ -f "${_icn%.icn}_driver.ref" ]; }; then GAP_NAMES="$GAP_NAMES $_b(no .ref shipped upstream, no .ref cut by us, no driver)"; continue; fi
    case "$_b" in tpp) GAP_NAMES="$GAP_NAMES tpp(.ref is jcon PREPROCESSOR text, not program output)"; continue;; esac
    if is_outside_baseline "$_b"; then GAP_NAMES="$GAP_NAMES $_b(outside the Arizona baseline: $(outside_reason "$_b"))"; OUTSIDE_LIST="$OUTSIDE_LIST $_b"; continue; fi
    GRADED=$((GRADED+1))
done
GAP=$((SHIPPED-GRADED))
# ⛔ REFUSE rather than grade a population the census could not read: a zero SHIPPED would make every rate
# below vacuously perfect and print the success shape over nothing (RULES.md -- a test that cannot measure
# REFUSES rc=2, it never skips as success).
if [ "$SHIPPED" -eq 0 ] || [ "$GRADED" -eq 0 ]; then
    echo "⛔ GATE REFUSES(2): censused shipped=$SHIPPED graded=$GRADED under $CORPUS -- nothing to grade" >&2
    exit 2
fi
echo "=== JCON vendored suite (upstream jcon, unmodified standard Icon) — shipped=$SHIPPED graded=$GRADED gap=$GAP ==="
# ⭐ THE ROUND ROBIN'S SEAM (ceo CEO-1802/1806/1812): under S4E_CHUNK (a request's entry: names, or a part) only the selected programs are graded, a
# preprocess contract when one of its argv programs is selected; each program's rows are appended as it is graded, and no suite row is written (rr_end).
. "$HERE/lib_rr.sh" && rr_load "$CORPUS" || exit 2

case "$MODE" in
    all) run_mode m3; run_mode m4 ;;
    m3)  run_mode m3 ;;
    m4)  run_mode m4 ;;
    *) echo "Usage: $0 [--mode all|m3|m4] [--scrip PATH] [--corpus PATH] [--timeout N]" >&2; exit 1 ;;
esac

total="${m3_TOTAL:-${m4_TOTAL:-0}}"
m3p="${m3_PASS:-}"; m4p="${m4_PASS:-}"
rr_selected && { echo "JCON selection graded: m3 ${m3p:-n/a}/${m3_TOTAL:-0} m4 ${m4p:-n/a}/${m4_TOTAL:-0} pass"; rr_end jcon; exit 0; }
# ⛔ THE CENSUS AND THE GRADING LOOP MUST AGREE ON WHAT WAS GRADED, and this is the one place that can be
# checked rather than assumed. They apply the SAME two exclusions by two independent walks; if they ever
# diverge, one of them is wrong about the population and every rate printed here is unsound. Refuse loudly
# rather than publish a number whose denominator two parts of this script disagree about.
if [ "$total" -ne "$GRADED" ]; then
    echo "⛔ GATE REFUSES(2): census says graded=$GRADED, the grading loop graded total=$total -- the two"  >&2
    echo "    walks disagree about the population, so neither rate is trustworthy. Reconcile before quoting." >&2
    exit 2
fi
[ -n "$GAP_NAMES" ] && echo "UNGRADED ($GAP of $SHIPPED shipped, zero of the population until graded):$GAP_NAMES"
# ⛔⭐⭐ THE EXCLUSION LIST IS RECONCILED AGAINST THE ORACLE AND AGAINST THE INVENTORY, EVERY RUN (hq_T,
# reviewing CEO-470). The reader landed correct and UNPROTECTED: it TRUSTS the .tsv as a static list, while
# all four SNOBOL4 siblings re-measure theirs and print STALE / UNRECORDED / "does not mirror" -- see
# test_snoflake_suite.sh:396-400, test_snobol4_gimpel_suite.sh:142-145, test_snobol4_dotnet_suite.sh:158-163,
# test_snobol4_spitbol_testpgms_suite.sh:168-173. Without an arm the denominator can only ever SHRINK: the
# day Arizona icont accepts htprep, the row stands forever, six programs stay out, and NOTHING reds.
# ⭐ That is hq_P's own commit-message principle -- "a correction that only ever raises the number is not a
# correction" -- running in the direction it did not look: a list that can only ever lower one is not one either.
# ⛔ THE ORACLE_REFUSES CLASS IS RE-MEASURED, THE OTHER TWO ARE NOT, AND THE ASYMMETRY IS THE POINT rather
# than a shortcut. `icont -s -c` is COMPILE-ONLY and costs 4 ms per program (measured), so re-proving a
# refusal is free and always on. A TIMEOUT row costs the 30 s cap it is named for, and an
# ENVIRONMENT_IDENTITY_IN_OUTPUT row cannot be re-measured at all -- its whole claim is that the answer
# depends on who is running it. So this arm re-proves what is cheap to re-prove and says plainly which
# rows it did not touch, rather than pricing a 60 s tax into every jcon run or pretending it checked six.
outside_rows() { [ -f "$OUTSIDE" ] && grep -v '^#' "$OUTSIDE" | grep -v '^[[:space:]]*$'; }
OUT_STALE=""; OUT_UNSHIPPED=""; OUT_UNMIRRORED=""; OUT_RECHECKED=0; OUT_UNCHECKED=""
# ⛔ THE TRAP NAMES BOTH DIRECTORIES. A bare `trap ... EXIT` here REPLACES the one set at :108 and leaks
# $WORK on every run -- caught in review of this very arm, which is the trap-handler class exactly: a
# second registration for the same signal is not additive, and nothing warns that the first one is gone.
_ORWORK="$(mktemp -d)"; trap 'rm -rf "$WORK" "$_ORWORK"' EXIT
OUT_ROWLEVEL=""
while IFS="$(printf '\t')" read -r _on _oc _or; do
    [ -n "$_on" ] || continue
    # ⛔⭐⭐ A ROW-LEVEL ENTRY IS NOT A PROGRAM AND MUST NOT BE CHECKED AS ONE (ceo CEO-516, hq_P 2026-09-10).
    # CEO-516 ruled that lgint's unbounded arm is THREE ROWS INSIDE the program and ordered them named here
    # "as rows, not the program", so lgint itself stays in the graded denominator.  This file's reader was
    # program-keyed, so those entries -- `lgint:bigexp(3 ^ 41)` and its two siblings -- tripped the
    # NAMES-NOTHING-SHIPPED arm on every run.  ⭐ THE WARNING WAS NOT WRONG ABOUT WHAT IT SAW; it was asking
    # the wrong question of a kind of row that did not exist when it was written, and its text ("a rename or
    # a leftover; the row withdraws an exclusion silently") actively misdescribes a deliberate ruling.
    # ⛔ A PERMANENT FALSE WARNING IS WORSE THAN NO WARNING: it teaches the reader to skip this whole block,
    # and the block's other two arms are real.  So a name carrying ':' is recognised as row-level, exempted
    # from the shipped and mirror checks -- and PRINTED on its own line, never silently dropped, because an
    # exclusion nobody can see is the thing this file exists to prevent.
    case "$_on" in
        *:*) OUT_ROWLEVEL="$OUT_ROWLEVEL $_on"; continue;;
    esac
    # A row naming no shipped program is a rename or a leftover, and it withdraws an exclusion silently --
    # the same refusal lib_inventory.sh makes for UNGRADED/UNGRADABLE, which this file is NOT covered by
    # except through the hand-written mirror checked just below.
    [ -f "$CORPUS/$_on.icn" ] || { OUT_UNSHIPPED="$OUT_UNSHIPPED $_on"; continue; }
    # ⛔ THE MIRROR IS NOT DECORATION: `gap` is split by UNGRADED.tsv/UNGRADABLE.tsv and NOT by this file,
    # so an OUTSIDE row absent from both leaves the program out of the graded denominator AND out of the
    # lockdown split -- excluded by one instrument and invisible to the other, which is how a population
    # stops summing while every individual file still reads honest.
    if ! grep -q "^$_on\.icn"$'\t' "$CORPUS/UNGRADED.tsv" 2>/dev/null && ! grep -q "^$_on\.icn"$'\t' "$CORPUS/UNGRADABLE.tsv" 2>/dev/null; then
        OUT_UNMIRRORED="$OUT_UNMIRRORED $_on"
    fi
    case "$_oc" in
        ORACLE_REFUSES)
            if _ic="$(icont_bin 2>/dev/null)" && [ -x "$_ic" ]; then
                cp "$CORPUS/$_on.icn" "$_ORWORK/" 2>/dev/null || true
                _oout="$(cd "$_ORWORK" && "$TIMEOUT_RETRY" 120 "$_ic" -s -c "$_on.icn" 2>&1)"; _orc=$?
                OUT_RECHECKED=$((OUT_RECHECKED+1))
                [ "$_orc" = 0 ] && OUT_STALE="$OUT_STALE $_on(icont -s -c now rc=0)"
            else OUT_UNCHECKED="$OUT_UNCHECKED $_on(no icont)"; fi ;;
        *) OUT_UNCHECKED="$OUT_UNCHECKED $_on($_oc)" ;;
    esac
done <<EOF
$(outside_rows)
EOF
# ⛔ PRINTED WHETHER OR NOT THE LIST IS EMPTY, for the reason CEO-409 guardrail 3 gives about masks: a line
# that appears only when something is excluded tells the reader nothing on the day one is added and
# everything on the day one is removed. Names AND the oracle's own class ride on it so the six stay visible.
echo "OUTSIDE_ARIZONA_BASELINE ($(printf '%s' "$OUTSIDE_LIST" | wc -w), out of the graded denominator, named in $OUTSIDE):${OUTSIDE_LIST:- none}"
declared_arena_receipt "$PKG_CSV"
echo "-- undeclared (RULES.md 8 (f): no declaring row in ALL.csv, so graded at the runtime's defaults -- named, never taken silently): ${#UNDECLARED[@]} --"
for n in $(printf '%s\n' "${!UNDECLARED[@]}" | sort); do echo "   $n"; done
# ⛔ THE RECONCILIATION PRINTS UNCONDITIONALLY TOO, and for a sharper reason than the list above it: a
# silent agreement line is the only way a reader can tell "the arm ran and the record holds" apart from
# "the arm did not run", and those two have opposite meanings for every number on the board line below.
[ -n "$OUT_ROWLEVEL" ]   && echo "ROW-LEVEL exclusions (ceo CEO-516) -- rows INSIDE a graded program, named so the program stays in the denominator:$OUT_ROWLEVEL"
[ -n "$OUT_UNSHIPPED" ]  && echo "⚠ OUTSIDE_ARIZONA_BASELINE.tsv NAMES NOTHING SHIPPED:$OUT_UNSHIPPED -- a rename or a leftover; the row withdraws an exclusion silently, and this file is not covered by lib_inventory's declared-but-not-shipped refusal except through the mirror"
[ -n "$OUT_UNMIRRORED" ] && echo "⚠ OUTSIDE_ARIZONA_BASELINE.tsv DOES NOT MIRROR the lockdown buckets:$OUT_UNMIRRORED -- named outside the denominator here and in neither UNGRADED.tsv nor UNGRADABLE.tsv, so the gap split above cannot see them; a TIMEOUT is work owed (UNGRADED), an oracle refusal is a ruling (UNGRADABLE)"
[ -n "$OUT_STALE" ]      && echo "⚠ OUTSIDE_ARIZONA_BASELINE.tsv STALE:$OUT_STALE -- recorded as refused by Arizona icont, but icont compiled it THIS RUN. Move it back into the graded denominator; an exclusion list that can only ever lower the number is not a correction either"
# ⛔⭐ THE AGREEMENT LINE MAY NOT CLAIM THE ORACLE AGREED WHEN THE ORACLE WAS NEVER ASKED. Caught by this
# arm's OWN failure test (hq_T, driving it with icont_bin() forced to fail): with the oracle unreachable it
# re-measured zero rows and still printed "agrees with the oracle", which is the exact defect the arm was
# written to catch, one level up -- CLAUDE.md's "a missing oracle does not blank a board, it prints a full,
# plausible, entirely false table", inverted into a plausible GREEN. The wording now follows what was
# actually measured: agreement is claimed over the oracle only when a row was put to it.
if [ -z "$OUT_UNSHIPPED$OUT_UNMIRRORED$OUT_STALE" ]; then
    if [ "$OUT_RECHECKED" -gt 0 ]; then
        echo "OUTSIDE_ARIZONA_BASELINE.tsv agrees with the oracle and the lockdown buckets (re-measured $OUT_RECHECKED ORACLE_REFUSES row(s) with icont -s -c; NOT re-measured:${OUT_UNCHECKED:- none})"
    else
        echo "OUTSIDE_ARIZONA_BASELINE.tsv agrees with the lockdown buckets; THE ORACLE WAS NOT ASKED (zero rows re-measured -- no ORACLE_REFUSES row was reachable). Every row stands on its recorded reason alone:${OUT_UNCHECKED:- none}"
    fi
fi
# ⛔ BEFORE THE BOARD LINE AND BEFORE ANY SCORE.md WRITE, NEVER AFTER (ceo CEO-524 (1)): a refusal that fires
# after the row is published is an annotation, not a refusal -- the same lesson test_gate_progress_rows_carry_
# the_start_fingerprint.sh was written for. gate_bin_unmoved exits 2 itself when the fingerprint moved.
GATE_NAME=test_icon_jcon_suite gate_bin_unmoved
# ⛔ BEFORE THE FIRST PUBLISHED NUMBER, beside the binary check and for the same reason: an annotation that
# the tree moved is not a refusal -- util_score_row would happily write "graded; HEAD moved during the run"
# onto a number that describes no single tree.
GATE_NAME=test_icon_jcon_suite gate_tree_unmoved
BOARD_LINE="JCON_SUITE_BOARD shipped=$SHIPPED graded=$GRADED gap=$GAP total=$total m3_pass=${m3p:-n/a} m4_pass=${m4p:-n/a}"; echo "$BOARD_LINE"
# ⛔⭐ THE PACKAGE LOCKDOWN INVENTORY (Lon 2026-09-06: "Fix the never graded business"; instrument row
# every-package-runner-prints-shipped-graded-ungraded-and-ungradable..., hq_T). ONE line, ONE shape, from
# the SHARED body -- never a second copy of the arithmetic. ⭐ IT SPLITS THE `gap=` PRINTED ABOVE, and the
# split is the whole point: under a single `gap=` a program upstream ships no oracle answer for is
# indistinguishable from one this lane owes work on, and since every lockdown row's DONE-WHEN reads
# `ungraded=0`, a conflated number makes the criterion unreadable in BOTH directions.
# ⛔⭐ THIS COMMENT USED TO ASSERT THE SPLIT INSTEAD OF DERIVING IT -- "all 9 gap entries are UNGRADABLE, so
# jcon's ungraded is ZERO and it already meets the lockdown criterion" -- and CEO-470 falsified it in the
# same commit that made it stale: reading OUTSIDE_ARIZONA_BASELINE.tsv moved six programs into the gap, of
# which lgint and toby are UNGRADED (a TIMEOUT is work owed, not a ruling), so the gap is 15 and ungraded
# is 2 and this package does NOT meet the criterion today. ⭐ The reusable half is not the number: a
# comment that states what the line below it PRINTS is a second, unversioned copy of a measurement, and it
# decays exactly when the measurement moves -- which is the one moment a reader is most likely to trust it.
# Read PACKAGE_INVENTORY on the run in front of you; this comment says what the split MEANS, never what it is.
. "$(dirname "${BASH_SOURCE[0]}")/lib_inventory.sh"
INV_PACKAGE=jcon; INV_DIR="$CORPUS"; INV_EXT=".icn"
# ⛔ NAMED, NOT DOWNGRADED TO A ⚠ (test_gate_package_runners_print_the_inventory.sh flagged this runner by
# name: "SWALLOWS THE REFUSAL -- rc=2 becomes a warning nobody reads"). A refusal is not a warning: rc=2
# means the inventory COULD NOT BE MEASURED, which is a different thing from a bad number, and this project
# keeps those three outcomes apart everywhere else (lib_gate.sh's exit codes, the harness's rc=2). It stays
# non-fatal -- the board above IS a real measurement -- but it is printed as ⛔ and it says what is missing.
# ⛔⭐⭐ CAPTURED, NOT MERELY PRINTED (hq_T 2026-09-10, row package-shipped-per-lane-printed-by-the-runner-
# not-transcribed; gate arm 17 of test_gate_package_runners_print_the_inventory.sh, proven red on THIS
# runner and green on the other eleven before the cure). This runner printed a correct PACKAGE_INVENTORY
# line on every run for four days and handed the leaderboard a hand-written restatement of it, so
# util_score_row.py's inventory_clauses() found no jcon clause and took jcon's shipped population from the
# PACKAGE_SHIPPED dict -- three integers typed into that file by a reader of somebody else's board. ⭐ The
# reusable half: PRINTING A NUMBER AND REPORTING IT ARE TWO JOBS, and a board line satisfies only the
# first. The measurement stood one line above the transcription, in this same script's own output.
INV_LINE="$(inventory_line "$GRADED" 0)"
if [ -n "$INV_LINE" ]; then echo "$INV_LINE"; else
    echo "⛔ PACKAGE INVENTORY REFUSED (rc=2, reason above) -- the jcon board line stands, the inventory does NOT, and this run publishes no bucket counts" >&2
fi
# ⭐ THE ROW'S Excl (Lon 2026-09-26, "use the Excl column to properly classify the exclusions for good reasons only"; CEO-1288): every
# shipped unit the denominator leaves out, classified -- here the tpp1..tpp5 include fragments of CONTAINERS.tsv (CEO-1272), read off
# the inventory line above, so shipped = denominator + Excl reads off the row. Unknown when the inventory refused: no Excl is written.
. "$HERE/lib_outside_shape.sh" 2>/dev/null || { echo "⛔ REFUSED TO GRADE: lib_outside_shape.sh unloadable" >&2; exit 2; }
EXCL_N=""; [ -n "$INV_LINE" ] && EXCL_N="$(inventory_containers_of "$INV_LINE")"
# ⭐ THE CLASS SPLIT, from the shared body (hq_T ruling 2026-09-06): its own line, its own refusal, and the
# per-class counts are asserted against the buckets inventory_line just published.
if SPLIT_LINE="$(inventory_split_line)"; then [ -n "$SPLIT_LINE" ] && echo "$SPLIT_LINE"
else echo "⛔ PACKAGE INVENTORY SPLIT REFUSED (rc=2, reason above) -- the classes do not sum to their own buckets, so neither reading is published" >&2; fi
# ⛔ ONE LEADERBOARD (RULES.md FACT RULE, Lon 2026-09-03 ~16:05: "any run of a test suite by any
# session will update the ONE LEADERBOARD"). This records the board line printed just above into
# .github/SCORE.md -- it RUNS NOTHING, it only writes down what this script already measured.
# ⛔ NON-FATAL BY DESIGN: a bookkeeping failure must never turn a real measurement into a red board,
# because a gate that goes red for a reason unrelated to the code is a gate people route around. It
# warns and names the unrecorded row instead; it has no silent path.
# ⛔⭐ TWO THINGS THIS --text ASSERTED WRONGLY ON EVERY RUN UNTIL 2026-09-10 (hq_T), both of them the
# defects test_icon_arizona_suite.sh had already had cured out of its own --text on 2026-09-06 -- the same
# pair, in the sibling runner, four days later, which is what an uncopied cure looks like:
#   1. THE DENOMINATOR WAS $SHIPPED, NOT THE GRADED POPULATION. Lon ruled 2026-09-05 "Show measured numbers
#      from running test suites not FLOORS": `${m3p}/$SHIPPED` publishes a numerator measured over $total
#      graded programs against a population that includes every program this suite never executed. $total
#      is the grading loop's OWN count and is asserted equal to $GRADED above (rc=2 if they disagree), so
#      it is the one denominator this run can prove.
#   2. $GAP IS NOT "ungraded". Under the ruled vocabulary UNGRADED means WORK OWED and UNGRADABLE means a
#      RULING; $GAP is just shipped-minus-graded, and CEO-470 measured jcon's as 13 ungradable + 2
#      ungraded. Calling all 15 "ungraded" put a flat contradiction beside the inventory clause now riding
#      in the same cell. The neutral phrase is the honest one -- the clause does the splitting.
# ⛔⭐⭐ POINT 1 IS SUPERSEDED (ceo CEO-1245 2026-09-24, re-ruled CEO-1268 2026-09-25 on the coo's audit COO-183; CEO-749, CEO-786,
# CEO-799b, CEO-700): THE SHIPPED POPULATION IS THE DENOMINATOR. The row publishes $AND_PASS/$SHIPPED; the $GAP not graded (the
# containers and library modules among them) stay IN it as debt, named by class in the inventory clause -- a container is graded
# by writing it a driver, never by leaving the total. The graded fraction still rides in the cell, labelled as such.
# ⛔⭐ THIS WRITE WAS REFUSED OUTRIGHT BEFORE THIS CHANGE, AND THE INSTRUMENT WAS RIGHT (measured on the
# 2026-09-10 19:00 pass): with m3 79 and m4 78 the --text carried TWO different N/M fractions, and
# util_score_row said so -- "which one the suite row means is a judgement, not a reading -- pass
# --suite-pass/--suite-total" -- and wrote NOTHING rather than guess. The row went unwritten and the coo set it
# by hand. ⭐ THE SIBLING RUNNER FAILED THE OTHER WAY ON THE SAME PASS: arizona passed m3's number into both
# halves of its cell, silently. One honestly unwritten, one silently wrong, ONE ROOT -- neither could COMPUTE
# the number CEO-545 asks for. gate_and_per_program is that computation, spelled once in lib_gate.sh.
# ⛔⭐ A RUN OVER A CORPUS THAT IS NOT THE PACKAGE'S OWN PUBLISHES NO ROW (hq_V 2026-09-11, found while wiring
# CEO-581 and closed before using the flag). `--corpus <scratch>` exists so a seat can exercise this runner on a
# FIXTURE without touching the tracked tree -- and every such run reached this write and published a JCON cell
# measured over the fixture's population: one program in, "JCON 1/1" out, with a clean stamp and a plausible
# denominator. THE BOARD ABOVE IS STILL A REAL MEASUREMENT OF WHAT WAS ASKED FOR and is still printed; what is
# refused is calling it the package's published row. ⛔ IT IS THE SAME SHAPE AS THE BUILDER TRAP MEASURED ONE DAY
# EARLIER (HQV-34): an instrument pointed at the wrong tree does not fail, it succeeds about something else, and
# the output is complete and plausible. A guard belongs where the number is PUBLISHED, not where it is computed.
_CORPUS_REAL="$(cd "$CORPUS" 2>/dev/null && pwd -P || echo "$CORPUS")"
_CORPUS_PUB_REAL="$(cd "$CORPUS_PUBLISHED" 2>/dev/null && pwd -P || echo "$CORPUS_PUBLISHED")"
if [ "$_CORPUS_REAL" != "$_CORPUS_PUB_REAL" ]; then
    echo "⛔ SCORE ROW NOT WRITTEN: this run graded --corpus $_CORPUS_REAL, which is not the published jcon package ($_CORPUS_PUB_REAL). The board line above is a real measurement OF THAT CORPUS; the SCORE.md JCON row names the package's own population and no other, so this run publishes none."
else
read -r AND_PASS AND_RED AND_NAMES <<<"$(gate_and_per_program "$total" "${m3_RED_NAMES:-}" "${m4_RED_NAMES:-}")"
if [ -z "${AND_PASS:-}" ]; then
    echo "⛔ SCORE ROW REFUSES (rc=2): gate_and_per_program could not compute the AND per program over total='$total' -- the row IS that number, so this run writes none rather than guess one" >&2
else
    echo "JCON_AND_PER_PROGRAM and_pass=$AND_PASS of $total (m3 ${m3p:-n/a} · m4 ${m4p:-n/a} · union of reds $AND_RED:$AND_NAMES)"
    _cc="${S4E_CRITERION_CHANGED:-}"
    if [ -z "$_cc" ] && [ -n "$EXCL_N" ]; then _cc="$(excluded_shape_stamp jcon "$SHIPPED" - "$EXCL_N" "$EXCL_N")" || exit 2; fi
    python3 "$HERE/util_score_row.py" write --lang icon --column vendor --suite JCON --modes m3,m4 --suite-pass "$AND_PASS" --suite-total "$SHIPPED" \
        ${_cc:+--criterion-changed "$_cc"} ${EXCL_N:+--excluded "$EXCL_N"} \
        --measurer "${S4E_SEAT:-}" --text "AND per program $AND_PASS/$SHIPPED shipped (ceo CEO-1245: the shipped population is the denominator; CEO-545: a program is green only if BOTH modes are; union of reds $AND_RED:$AND_NAMES) · graded $AND_PASS/$total · m3 ${m3p:-n/a}/$total · m4 ${m4p:-n/a}/$total graded (of $SHIPPED shipped, $GRADED graded, $GAP not graded and owed -- the inventory clause splits ungraded=owed from ungradable=ruled)${INV_LINE:+ · $INV_LINE (\`test_icon_jcon_suite.sh\`)} · $BOARD_LINE" \
        || echo "⚠ SCORE.md NOT UPDATED -- record this row by hand (the REFUSED line above says why; a denominator move wants S4E_CRITERION_CHANGED='YYYY-MM-DD:reason' on this runner's call)"
fi
fi

