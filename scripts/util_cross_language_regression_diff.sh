#!/usr/bin/env bash
# util_cross_language_regression_diff.sh -- base-vs-patched verdict DIFFERENTIAL over the SNOBOL4,
# Icon and Prolog rung suites, for a commit or an uncommitted working-tree change (row
# cross-language-regression-differential-over-all-three-open-masters, hq_U, 2026-09-05).
#
# ⛔ MERGE NOTE (seat17, 2026-09-05): this row was independently built twice -- seat17 (this file,
# worktree-based) and seat18 (761eb9353, checkout-in-place) landed within minutes of each other under
# the same re-laning. Resolved as a real merge, not a coin flip: seat18's version is not carried
# forward as-is because its `--base <ref>` checks out that ref IN PLACE in the same checkout the
# script runs from -- undefined behaviour the moment the target ref's copy of this very file differs
# from (or is absent from) the one bash is mid-way through executing, and its stash push has no
# self-exclusion pathspec, so a dirty tree during that script's own development could have stashed
# itself away. Both are exactly the class of hazard this file's worktree + SELF_RELPATH design exists
# to rule out by construction (see below), so this file's mechanics are kept. What IS carried forward,
# because it is a genuine correctness improvement: seat18's diff_lang correctly special-cases a fresh
# XPASS as an improvement, never a regression; classify_deltas below adopts that. hq_U notified
# (override-cross-language-regression-differential-duplicate-build) so the collision and the
# checkout-in-place hazard are on record for whoever owns seat18's row next.
#
# WHY: both cross-language regressions found on hq_U's opening day (the HOST argv staging that burned
# Icon list serial 1; the CAP_NEST rsp-relative capture) were found by a human noticing a board move,
# not by an instrument. This prints the per-entry DELTA -- not absolute counts -- so a moved board is
# visible at landing time instead of a week later.
#
# ⛔ THE TRAP THIS SCRIPT IS BUILT AROUND (FINDING-2026-09-05-hq_T-arbno-null-body-guard...): `scrip`
# carries an ABSOLUTE DT_RUNPATH into this tree's own out/, so a binary COPIED to a "base/" snapshot
# folder silently keeps loading the CURRENT out/libscrip_rt.so -- "0 changed" then means "I diffed one
# arm against itself", never "clean". The cure here is to never copy a binary out of the tree that
# built it: base and patched are measured SEQUENTIALLY, immediately after each build, so whatever is
# on disk when the harness runs IS the arm under test. An md5 canary is printed either way (never
# trusted silently) so an unexpectedly-identical pair is visible, not assumed impossible.
#
# ⛔ RULE (the GOAL this row was minted for): a differential that cannot measure REFUSES (rc=2). It
# never prints a plausible all-zero delta for a build that failed, a run that was killed, or a harness
# that produced no board line -- an empty population reading as a healthy one is what hq_U exists to stop.
#
# Usage:
#   util_cross_language_regression_diff.sh                    # base=HEAD, patched=HEAD+working-tree (stash-and-rebuild, in place)
#   util_cross_language_regression_diff.sh --commit <sha>      # base=<sha>^, patched=<sha> (git worktree -- never touches this checkout)
#   util_cross_language_regression_diff.sh --only snobol4,icon # subset of: snobol4 icon prolog (default: all three)
#   util_cross_language_regression_diff.sh --shard 1/50        # passthrough to corpus_suite_harness.py, for a fast partial read
#   util_cross_language_regression_diff.sh --selftest          # unit-tests the diff engine + refusal paths, then a real build
#                                                               # + self-vs-self measurement of one small shard (~1 min)
#
# Exit codes: 0 = measured, no entry moved PASS->non-PASS (an IMPROVED/stale-XPASS entry does not count).
# 1 = measured, at least one REGRESSED entry.  2 = REFUSED -- could not measure (see stderr).

set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP_ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
S4E="${S4E_HOME:-$(cd "$SCRIP_ROOT/.." && pwd)}"           # D-17 PORTABLE-HOME
CORPUS="${CORPUS:-$S4E/corpus}"
HARNESS="$HERE/corpus_suite_harness.py"
SELF_RELPATH="../harness/scripts/util_cross_language_regression_diff.sh"

refuse() { echo "⛔ REFUSING (rc=2): $*" >&2; exit 2; }

# tree_is_dirty -- true (rc 0) iff the tree has a change outside this script's OWN path. Excluding
# SELF_RELPATH here (not just from the stash push below) matters even for --commit mode, which never
# touches the working tree at all: this script is developed/tested in the same checkout it ships from,
# and a real uncommitted edit to some OTHER file must not be masked, but this file's own in-flight
# state must never be what makes an unrelated --commit request refuse.
tree_is_dirty() {
    local status_out
    git diff --quiet -- . ":(exclude)$SELF_RELPATH" || return 0
    git diff --cached --quiet -- . ":(exclude)$SELF_RELPATH" || return 0
    status_out="$(git status --porcelain --untracked-files=normal -- . ":(exclude)$SELF_RELPATH")"
    [ -n "$status_out" ] && return 0
    return 1
}

# ============================================================ diff engine (pure, unit-tested by --selftest) ===
# classify_deltas base_stderr patched_stderr -- reads corpus_suite_harness.py's `  TAG mode name: detail`
# lines (SUITE_LIST_ALL=1 lifts its default 40-line cap) from each side and prints one TSV row per
# (entry,mode) whose verdict actually changed. Absence in a side means PASS (the harness only names
# non-PASS entries) -- the CALLER must already have proven the run was measured at all (check_measured);
# this function cannot tell "unmeasured" from "measured and all green", by design -- it only ever
# compares two explicit maps.
# ⛔ A FRESH XPASS IS NEVER A REGRESSION (seat18's diff_lang, adopted here): the harness only prints an
# XPASS-tagged line for an entry the SUITE marks xfail that unexpectedly PASSED -- a bug got fixed and
# nobody promoted the marker, exactly as actionable as a fresh FAIL and in the opposite direction. A
# naive PASS-vs-non-PASS classifier reads "absent from base, XPASS in patched" as PASS->non-PASS and
# mislabels a fixed bug as a regression; IMPROVED is its own bucket so the exit code stays trustworthy.
classify_deltas() {
    python3 - "$1" "$2" <<'PYEOF'
import sys, re
pat = re.compile(r'^\s*(.+) (m3|m4|ast) (\S+): (.*)$')
def load(path):
    m = {}
    try:
        fh = open(path, 'r', errors='replace')
    except FileNotFoundError:
        return m
    with fh:
        for line in fh:
            mo = pat.match(line.rstrip('\n'))
            if not mo:
                continue
            tag, mode, name, detail = mo.groups()
            m[(name, mode)] = (tag, detail)
    return m
base = load(sys.argv[1])
patched = load(sys.argv[2])
for name, mode in sorted(set(base) | set(patched)):
    b = base.get((name, mode), ("PASS", ""))
    p = patched.get((name, mode), ("PASS", ""))
    if b[0] == p[0]:
        continue
    if "XPASS" in p[0] and "XPASS" not in b[0]:
        status = "IMPROVED"
    elif b[0] == "PASS":
        status = "REGRESSED"
    elif p[0] == "PASS":
        status = "CURED"
    else:
        status = "CHANGED"
    print(f"{status}\t{name}\t{mode}\t{b[0]}\t{p[0]}\t{p[1]}")
PYEOF
}

# ============================================================ per-language rungs invocation ===
# ⛔ These three invocations are copied from the boards that already grade these rung suites in production
# (test_corpus_snobol4.sh, board_icon_rungs.sh, test_gate_pl_rungs_board_floor.sh), not re-derived --
# this codebase has three independent documented incidents (Pascal/Snocone/Raku, 2026-09-03/04) of a
# false-but-plausible board from getting one language's --lang/--modes pairing wrong.
lang_src()  { case "$1" in snobol4) echo "$CORPUS/tests/snobol4/ALL.sno";; icon) echo "$CORPUS/tests/icon/ALL.icn";; prolog) echo "$CORPUS/tests/prolog/ALL.pl";; esac; }
lang_ref()  { case "$1" in snobol4) echo "$CORPUS/tests/snobol4/ALL.ref";; icon) echo "$CORPUS/tests/icon/ALL.ref";; prolog) echo "$CORPUS/tests/prolog/ALL.ref";; esac; }
lang_args() { case "$1" in snobol4) echo "--modes m3,m4";; icon) echo "--lang icon --modes m3,m4";; prolog) echo "--lang prolog --modes m3,m4";; esac; }
# Every entry of every rung suite is graded in both modes: there is no modes column (Lon 2026-09-23, CEO-1218/1230).

run_rungs() {  # $1=lang $2=stdout-file $3=stderr-file ; returns the harness's own exit code
    local lang="$1" out="$2" err="$3" src ref
    src="$(lang_src "$lang")"; ref="$(lang_ref "$lang")"
    [ -n "$src" ] || refuse "unknown language '$lang' -- only snobol4, icon, prolog are wired"
    [ -f "$src" ] && [ -f "$ref" ] || refuse "$lang rungs suite missing ($src / $ref) -- pull corpus"
    local args=(); read -ra args <<<"$(lang_args "$lang")"
    [ -n "${SHARD:-}" ] && args+=(--shard "$SHARD")
    local rc=0
    SUITE_LIST_ALL=1 timeout -k 5 1800 python3 "$HARNESS" run "$src" "$ref" "${args[@]}" >"$out" 2>"$err" || rc=$?
    return "$rc"
}

# check_measured $lang $stdout $stderr $rc -- REFUSES (never returns) unless this run is trustworthy.
# ⛔ THE THREE SHAPES THAT MUST NEVER READ AS "ZERO ENTRIES, ZERO FAILS": killed (rc>128), the harness's
# own refusal (rc=2), and rc==0/1 with no SUITE_BOARD line at all (a harness defect, or the two streams
# swapped upstream) -- mirrors test_corpus_snobol4.sh's own three-way split of this identical trap.
check_measured() {
    local lang="$1" out="$2" err="$3" rc="$4"
    if [ "$rc" -gt 128 ]; then
        local sig signame; sig=$((rc - 128)); signame="$(kill -l "$sig" 2>/dev/null || echo "$sig")"
        refuse "$lang measurement was KILLED by SIG$signame (rc=$rc) -- not a red board, re-run. stderr tail: $(tail -3 "$err" 2>/dev/null | tr '\n' ' ')"
    fi
    if [ "$rc" -eq 2 ]; then
        refuse "$lang harness refused to measure (rc=2): $(tail -6 "$err" 2>/dev/null | tr '\n' ' ')"
    fi
    grep -q '^SUITE_BOARD ' "$out" 2>/dev/null || refuse "$lang harness printed no SUITE_BOARD line (rc=$rc) -- cannot tell a clean run from an unmeasured one. stderr tail: $(tail -6 "$err" 2>/dev/null | tr '\n' ' ')"
}

# ============================================================ build ===
# Incremental `make` -- NO pristine build anywhere (Lon, FLEET-20 telegram, 2026-09-05); the
# stale-binary refusal inside corpus_suite_harness.py's check_scrip()/require_fresh() is what makes
# trusting the incremental build safe -- a build that silently under-rebuilt is caught downstream, not
# reimplemented here.
build_tree() { ( cd "$SCRIP_ROOT" && timeout -k 5 900 make ) >"$1" 2>&1; }

artifact_md5() { md5sum "$SCRIP_ROOT/scrip" "$SCRIP_ROOT"/out/*.so 2>/dev/null | md5sum | cut -d' ' -f1; }

# ============================================================ selftest ===
run_selftest() {
    local fail=0 t rc d sig
    t="$(mktemp -d)"

    rc=0; ( refuse "selftest probe" ) >"$t/out" 2>"$t/err" || rc=$?
    [ "$rc" -eq 2 ] || { echo "SELFTEST FAIL: refuse() exited $rc, want 2"; fail=1; }
    [ -s "$t/err" ] && [ ! -s "$t/out" ] || { echo "SELFTEST FAIL: refuse() did not write stderr-only"; fail=1; }

    : >"$t/base.same.err"; : >"$t/patched.same.err"
    d="$(classify_deltas "$t/base.same.err" "$t/patched.same.err")"
    [ -z "$d" ] || { echo "SELFTEST FAIL: identical empty sides produced spurious deltas ($d)"; fail=1; }

    : >"$t/base.reg.err"; printf '  FAIL m3 widget_1: expected 3 got 4\n' >"$t/patched.reg.err"
    d="$(classify_deltas "$t/base.reg.err" "$t/patched.reg.err")"
    case "$d" in
        REGRESSED$'\t'widget_1$'\t'm3$'\t'PASS$'\t'FAIL*) ;;
        *) echo "SELFTEST FAIL: a new patched-only FAIL did not classify REGRESSED (got: $d)"; fail=1 ;;
    esac

    printf '  FAIL m4 widget_2: boom\n' >"$t/base.cure.err"; : >"$t/patched.cure.err"
    d="$(classify_deltas "$t/base.cure.err" "$t/patched.cure.err")"
    case "$d" in
        CURED$'\t'widget_2$'\t'm4$'\t'FAIL$'\t'PASS*) ;;
        *) echo "SELFTEST FAIL: a base-only FAIL did not classify CURED (got: $d)"; fail=1 ;;
    esac

    printf '  CRASH m3 widget_3: sig11\n' >"$t/base.same2.err"; printf '  CRASH m3 widget_3: sig11\n' >"$t/patched.same2.err"
    d="$(classify_deltas "$t/base.same2.err" "$t/patched.same2.err")"
    [ -z "$d" ] || { echo "SELFTEST FAIL: an identical CRASH on both sides was reported as a delta ($d)"; fail=1; }

    printf '  FAIL m3 widget_4: was off by one\n' >"$t/base.chg.err"; printf '  CRASH m3 widget_4: sig11\n' >"$t/patched.chg.err"
    d="$(classify_deltas "$t/base.chg.err" "$t/patched.chg.err")"
    case "$d" in
        CHANGED$'\t'widget_4$'\t'm3$'\t'FAIL$'\t'CRASH*) ;;
        *) echo "SELFTEST FAIL: FAIL->CRASH on the same entry did not classify CHANGED (got: $d)"; fail=1 ;;
    esac

    # A fresh XPASS (a documented-xfail entry that started unexpectedly passing) must classify IMPROVED,
    # never REGRESSED -- a naive PASS-vs-non-PASS reading of "absent in base, XPASS in patched" would
    # otherwise flag a fixed bug as a regression (the exact bug seat18's concurrent build caught).
    : >"$t/base.imp.err"; printf '  XPASS(marker stale, promote it) m3 widget_5: some detail\n' >"$t/patched.imp.err"
    d="$(classify_deltas "$t/base.imp.err" "$t/patched.imp.err")"
    case "$d" in
        IMPROVED$'\t'widget_5$'\t'm3$'\t'PASS$'\t'*XPASS*) ;;
        *) echo "SELFTEST FAIL: a fresh XPASS did not classify IMPROVED (got: $d)"; fail=1 ;;
    esac

    # THE load-bearing refusal: rc=0 with NO SUITE_BOARD line (streams swapped, harness printed nothing
    # useful, etc.) must REFUSE, never be read as "zero entries, zero fails".
    printf 'not a board line\n' >"$t/noboard.out"; : >"$t/noboard.err"
    rc=0; ( check_measured "fakelang" "$t/noboard.out" "$t/noboard.err" 0 ) >/dev/null 2>&1 || rc=$?
    [ "$rc" -eq 2 ] || { echo "SELFTEST FAIL: check_measured accepted a run with no SUITE_BOARD line (rc=$rc)"; fail=1; }

    rc=0; ( check_measured "fakelang" "$t/noboard.out" "$t/noboard.err" 137 ) >/dev/null 2>&1 || rc=$?
    [ "$rc" -eq 2 ] || { echo "SELFTEST FAIL: check_measured accepted a killed run (rc=137) without refusing (got rc=$rc)"; fail=1; }

    # A genuine SUITE_BOARD line with rc=1 (measured, some entries red) must NOT refuse -- a red board
    # is a measurement, and treating it as unmeasurable would be the opposite failure.
    printf 'SUITE_BOARD family=x total=5 m3_pass=4 m3_fail=1\n' >"$t/board.out"; printf '  FAIL m3 e: x\n' >"$t/board.err"
    rc=0; ( check_measured "fakelang" "$t/board.out" "$t/board.err" 1 ) >/dev/null 2>&1 || rc=$?
    [ "$rc" -eq 0 ] || { echo "SELFTEST FAIL: check_measured refused a legitimately-red (rc=1, SUITE_BOARD present) run"; fail=1; }

    # Environment sanity: a selftest that passes where the real path cannot even start is worse than none.
    [ -f "$HARNESS" ] || { echo "SELFTEST FAIL: corpus_suite_harness.py missing at $HARNESS"; fail=1; }
    local lang src ref
    for lang in snobol4 icon prolog; do
        src="$(lang_src "$lang")"; ref="$(lang_ref "$lang")"
        [ -f "$src" ] && [ -f "$ref" ] || { echo "SELFTEST FAIL: $lang rungs suite missing ($src / $ref)"; fail=1; }
    done
    command -v git >/dev/null || { echo "SELFTEST FAIL: git not found"; fail=1; }
    command -v python3 >/dev/null || { echo "SELFTEST FAIL: python3 not found"; fail=1; }
    git -C "$SCRIP_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "SELFTEST FAIL: $SCRIP_ROOT is not a git repo"; fail=1; }

    # ⭐ REAL-PIPELINE CHECK (seat18's concurrent build had this and this file's earlier revision did
    # not -- adopted here): the checks above are pure unit tests of classify_deltas/check_measured and
    # never touch `make` or the harness, so a real flag/argv regression in run_rungs (e.g. one
    # language's --lang/--modes pairing breaking) would still pass every check above. Build
    # once for real, then measure the SAME freshly-built binary against itself on a small shard: if
    # comparing a binary to itself ever reports a delta, the measure+parse+diff pipeline is broken, not
    # the compiler -- mirrors board_icon_rungs.sh's own "0 changed can mean I diffed one arm against
    # itself" lesson, applied as a standing regression test instead of a one-time finding.
    if [ "$fail" -eq 0 ]; then
        local buildlog="$t/selftest.make.log"
        if build_tree "$buildlog"; then
            local o1="$t/self_a.out" e1="$t/self_a.err" o2="$t/self_b.out" e2="$t/self_b.err" rc1=0 rc2=0
            local saved_shard="${SHARD:-}"; SHARD="1/300"
            run_rungs snobol4 "$o1" "$e1" || rc1=$?
            run_rungs snobol4 "$o2" "$e2" || rc2=$?
            SHARD="$saved_shard"
            if [ "$rc1" -le 1 ] && [ "$rc2" -le 1 ] && grep -q '^SUITE_BOARD ' "$o1" 2>/dev/null && grep -q '^SUITE_BOARD ' "$o2" 2>/dev/null; then
                d="$(classify_deltas "$e1" "$e2")"
                [ -z "$d" ] || { echo "SELFTEST FAIL: measuring the SAME freshly-built binary against itself (snobol4, shard 1/300) reported a delta -- the pipeline itself is broken: $d"; fail=1; }
            else
                echo "SELFTEST FAIL: could not measure snobol4 for the real-pipeline check (rc1=$rc1 rc2=$rc2) -- see $e1 / $e2"; fail=1
            fi
        else
            echo "SELFTEST FAIL: 'make' failed during the real-pipeline check -- see $buildlog: $(tail -5 "$buildlog" | tr '\n' ' ')"; fail=1
        fi
    fi

    rm -rf "$t"
    if [ "$fail" -eq 0 ]; then
        echo "SELFTEST OK: diff engine (REGRESSED/CURED/CHANGED/IMPROVED/stable) + check_measured refusal paths + a real build-and-self-measure pass all verified."
        return 0
    fi
    return 1
}

# ============================================================ main ===
COMMIT="" ONLY="" SHARD="" DO_SELFTEST=0
while [ $# -gt 0 ]; do
    case "$1" in
        --commit) COMMIT="${2:?--commit needs a <sha>}"; shift 2;;
        --only) ONLY="${2:?--only needs a comma-separated language list}"; shift 2;;
        --shard) SHARD="${2:?--shard needs k/N}"; shift 2;;
        --selftest) DO_SELFTEST=1; shift;;
        -h|--help) sed -n '2,33p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0;;
        *) echo "unknown argument: $1 (see --help)" >&2; exit 2;;
    esac
done

if [ "$DO_SELFTEST" -eq 1 ]; then
    run_selftest; exit $?
fi

LANGS=(snobol4 icon prolog)
[ -n "$ONLY" ] && IFS=',' read -ra LANGS <<<"$ONLY"

command -v git >/dev/null || refuse "git not found"
command -v python3 >/dev/null || refuse "python3 not found"
command -v make >/dev/null || refuse "make not found"
[ -f "$HARNESS" ] || refuse "corpus_suite_harness.py missing at $HARNESS"
cd "$SCRIP_ROOT" || refuse "cannot cd to $SCRIP_ROOT"
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || refuse "$SCRIP_ROOT is not a git repo"

WORK="$(mktemp -d)"
STASHED=0
WORKTREES=()
cleanup() {
    local ec=$?
    set +e
    cd "$SCRIP_ROOT" 2>/dev/null
    if [ "$STASHED" = 1 ]; then
        git stash pop --quiet || echo "⚠️  git stash pop failed -- your changes are still stashed: run 'git stash list' / 'git stash pop' by hand" >&2
    fi
    local wt
    for wt in ${WORKTREES[@]+"${WORKTREES[@]}"}; do
        git worktree remove --force "$wt" >/dev/null 2>&1
    done
    exit "$ec"
}
trap cleanup EXIT INT TERM

measure_state() {  # $1=state label (base|patched); must be called with $SCRIP_ROOT/$HARNESS already pointed at that state's tree
    local state="$1" lang rc=0
    build_tree "$WORK/$state.make.log" || rc=$?
    [ "$rc" -eq 0 ] || refuse "make failed while building the '$state' tree -- see $WORK/$state.make.log. Last lines: $(tail -5 "$WORK/$state.make.log" | tr '\n' ' ')"
    for lang in "${LANGS[@]}"; do
        rc=0
        run_rungs "$lang" "$WORK/$state.$lang.out" "$WORK/$state.$lang.err" || rc=$?
        check_measured "$lang" "$WORK/$state.$lang.out" "$WORK/$state.$lang.err" "$rc"
    done
    echo "artifact_md5=$(artifact_md5)" >"$WORK/$state.md5"
}

if [ -n "$COMMIT" ]; then
    if tree_is_dirty; then
        refuse "working tree is dirty -- --commit needs an unambiguous 'patched' state; commit or stash your changes first (or drop --commit to diff the working-tree change itself)"
    fi
    BASE_REF="${COMMIT}^"; PATCHED_REF="$COMMIT"
    git rev-parse --verify "$BASE_REF" >/dev/null 2>&1 || refuse "cannot resolve $BASE_REF -- does $COMMIT have a parent commit?"
    git rev-parse --verify "$PATCHED_REF" >/dev/null 2>&1 || refuse "cannot resolve $PATCHED_REF"
    LABEL_BASE="$BASE_REF"; LABEL_PATCHED="$COMMIT"
    # ⛔ git worktree, never checkout-in-place: this script's OWN file may not exist at an old $BASE_REF,
    # and a checkout that rewrites ../harness/scripts/ out from under the bash process currently reading this file
    # is undefined behaviour, not merely bad style. A worktree is a separate directory -- this process's
    # own file is never touched by anything that happens inside one.
    WT_BASE="$WORK/wt-base"; WT_PATCHED="$WORK/wt-patched"
    git worktree add --quiet --detach "$WT_BASE" "$BASE_REF" || refuse "git worktree add failed for $BASE_REF"
    WORKTREES+=("$WT_BASE")
    git worktree add --quiet --detach "$WT_PATCHED" "$PATCHED_REF" || refuse "git worktree add failed for $PATCHED_REF"
    WORKTREES+=("$WT_PATCHED")
    ORIG_SCRIP_ROOT="$SCRIP_ROOT"; ORIG_HARNESS="$HARNESS"
    SCRIP_ROOT="$WT_BASE"; HARNESS="$WT_BASE/scripts/corpus_suite_harness.py"
    [ -f "$HARNESS" ] || refuse "corpus_suite_harness.py does not exist at $BASE_REF -- too old to grade with this tool"
    measure_state base
    SCRIP_ROOT="$WT_PATCHED"; HARNESS="$WT_PATCHED/scripts/corpus_suite_harness.py"
    [ -f "$HARNESS" ] || refuse "corpus_suite_harness.py does not exist at $PATCHED_REF"
    measure_state patched
    SCRIP_ROOT="$ORIG_SCRIP_ROOT"; HARNESS="$ORIG_HARNESS"
else
    if ! tree_is_dirty; then
        refuse "working tree is clean and no --commit given -- nothing to diff (pass --commit <sha> to grade an already-landed commit instead)"
    fi
    LABEL_BASE="HEAD"; LABEL_PATCHED="HEAD+working-tree"
    # ⛔ SELF-EXCLUDED, ALWAYS: keeps this script's own path out of what gets stashed regardless of
    # whether it happens to be tracked, modified, or freshly-untracked at call time. A tool that can
    # delete the file it is running from, out of its own working directory, the moment someone tests it
    # on a dirty tree is a defect in the tool, not in whoever ran it that way.
    STASH_OUT="$(git stash push -u -m "xlang-diff-$$" -- . ":(exclude)$SELF_RELPATH" 2>&1)"; STASH_RC=$?
    [ "$STASH_RC" -eq 0 ] || refuse "git stash push failed: $(echo "$STASH_OUT" | tr '\n' ' ')"
    if echo "$STASH_OUT" | grep -qi "No local changes to save"; then
        refuse "nothing to stash -- the working tree became clean between the dirty check and now (concurrent edit?)"
    fi
    STASHED=1
    measure_state base
    git stash pop --quiet || refuse "git stash pop failed after measuring base -- YOUR CHANGES ARE STILL STASHED (git stash list / git stash pop by hand). Refusing rather than measuring 'patched' against a state that never happened."
    STASHED=0
    measure_state patched
fi

echo "=== cross-language regression differential: base($LABEL_BASE) vs patched($LABEL_PATCHED) ==="
BASE_MD5="$(cut -d= -f2 "$WORK/base.md5")"; PATCHED_MD5="$(cut -d= -f2 "$WORK/patched.md5")"
if [ "$BASE_MD5" = "$PATCHED_MD5" ]; then
    echo "NOTE: base and patched scrip+out/*.so are byte-identical (md5 $BASE_MD5) -- if you expected a codegen change, verify your diff actually touches emitted code, not just comments/docs."
fi

ANY_REGRESSED=0
for lang in "${LANGS[@]}"; do
    BOARD_B="$(grep '^SUITE_BOARD ' "$WORK/base.$lang.out" | head -1)"
    BOARD_P="$(grep '^SUITE_BOARD ' "$WORK/patched.$lang.out" | head -1)"
    echo ""
    echo "--- $lang ---"
    echo "base:    $BOARD_B"
    echo "patched: $BOARD_P"
    DELTAS="$(classify_deltas "$WORK/base.$lang.err" "$WORK/patched.$lang.err")"
    if [ -z "$DELTAS" ]; then
        echo "no per-entry verdict moved."
        continue
    fi
    N_REG=0; N_CUR=0; N_CHG=0; N_IMP=0
    N_REG="$(grep -c '^REGRESSED' <<<"$DELTAS" || true)"
    N_CUR="$(grep -c '^CURED' <<<"$DELTAS" || true)"
    N_CHG="$(grep -c '^CHANGED' <<<"$DELTAS" || true)"
    N_IMP="$(grep -c '^IMPROVED' <<<"$DELTAS" || true)"
    echo "DELTAS: $N_REG REGRESSED, $N_CUR CURED, $N_CHG CHANGED, $N_IMP IMPROVED(stale XFAIL marker)"
    while IFS=$'\t' read -r status name mode btag ptag detail; do
        printf '  %-10s %-3s %-40s %s -> %s   %s\n' "$status" "$mode" "$name" "$btag" "$ptag" "$detail"
    done <<<"$DELTAS"
    [ "$N_REG" -gt 0 ] && ANY_REGRESSED=1
done

echo ""
echo "work dir (make logs + raw harness output, for post-mortem): $WORK"
if [ "$ANY_REGRESSED" -eq 1 ]; then
    echo "⛔ REGRESSION: at least one entry moved PASS -> non-PASS between base and patched."
    exit 1
fi
echo "✅ no PASS->non-PASS regressions across ${LANGS[*]}."
exit 0
