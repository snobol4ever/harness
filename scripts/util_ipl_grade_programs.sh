#!/usr/bin/env bash
# util_ipl_grade_programs.sh -- grade one or more corpus/packages/icon/ipl/progs/<name>.icn programs in BOTH
# modes against their own .ref, using test_icon_ipl_suite.sh's EXACT semantics, and exit 0 only if every
# named program passes both. hq_I 2026-09-06.
#
# WHY IT EXISTS. A baton's DONE-WHEN has to be a runnable command, and three rows of one entangled cure were
# about to carry three near-identical 900-character one-liners inlined into their batons. That is the
# copy-paste this repo forbids everywhere else (lib_oracle_flags.sh, lib_gate.sh, lib_ladder.sh, the one
# encoder): a criterion re-derived per caller drifts per caller, and a DONE-WHEN that drifts is worse than
# one that is missing, because it still prints a verdict.
#
# ⛔ IT MUST AGREE WITH THE SUITE OR IT IS MEASURING SOMETHING ELSE. Four conventions are the suite's, not
# this file's, and every one of them was a live defect for somebody before it was a convention:
#   · ipl_isolation_run for cwd/ICONPATH isolation -- IPL ships programs that RENAME EVERY FILE IN CWD.
#   · NAME.dat as stdin when present, /dev/null otherwise -- never guessed.
#   · NAME.argv through ipl_argv_read -- and ONLY rc=2 is "malformed"; a program with no sidecar at all
#     returns non-zero too, so `ipl_argv_read ... || refuse` REFUSES ON EVERY ARGV-LESS PROGRAM. Measured
#     here: igrep (no .argv) refused before this was matched to the suite's own `argv_rc -eq 2` test.
#     Passed after `--` in m3 and bare in m4 (the suite's own note explains
#     why the clever ${ARR[@]+-- "${ARR[@]}"} form GLUES the literal to the first element and is wrong).
#   · NAME.fixtures via IPL_ISO_FIXTURES.
# ⛔ AND ICONPATH IS EXPORTED FOR THE COMPILE STEP TOO. The suite exports it globally (its line 94) because
# m4's `--compile` runs UNISOLATED, so a program that `link`s a procs/ file cannot resolve it otherwise.
# Measured while writing this: igrep graded m3=PASS m4=FAIL from a harness that set ICONPATH only for the
# run -- a pure instrument bug that reads exactly like a mode divergence in the compiler.
#
# Usage: bash ../harness/scripts/util_ipl_grade_programs.sh igrep roffcmds
# Exits 0 all-pass, 1 any-fail, 2 cannot measure. Prints one line per program.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
SCRIP="${SCRIP:-$ROOT/scrip}"
[ $# -ge 1 ] || { echo "⛔ REFUSES(2): name at least one ipl package program" >&2; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSES(2): no scrip at $SCRIP -- run make" >&2; exit 2; }
"$HERE/util_require_fresh.sh" --gate util_ipl_grade_programs "$SCRIP" "$ROOT/out/libscrip_rt.so" || exit 2
. "$HERE/lib_icon_ipl_isolation.sh" 2>/dev/null || { echo "⛔ REFUSES(2): lib_icon_ipl_isolation.sh unloadable" >&2; exit 2; }
PKG="$ROOT/../corpus/packages/icon/ipl"
[ -d "$PKG/progs" ] || { echo "⛔ REFUSES(2): no ipl package at $PKG" >&2; exit 2; }
export ICONPATH="$PKG/procs:$PKG/gprocs:$PKG/progs:$PKG/gprogs:$PKG/incl:$PKG/gincl"   # libraries before programs: lib_icon_ipl_isolation.sh says why
ipl_isolation_init "$PKG" || { echo "⛔ REFUSES(2): ipl_isolation_init failed" >&2; exit 2; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"; ipl_isolation_cleanup' EXIT
GRADED=0; BAD=0
for name in "$@"; do
    # ⛔ THE PROGRAM'S DIRECTORY IS DISCOVERED, NEVER ASSUMED TO BE progs/. The suite grades every .ref
    # in the package and takes each entry's cwd from ITS OWN directory (its line 300); this file hardcoded
    # progs/ and so REFUSED(2) on ichartp -- a procs/ entry the suite has been grading and failing for
    # days -- with "no such program", which reads as "that program does not exist" rather than "I only
    # look in one of the package's six directories". A grader that cannot address an entry the suite
    # grades is measuring a different population than the board it is supposed to agree with.
    icn=""; std=""
    for d in progs gprogs procs gprocs incl gincl; do
        if [ -f "$PKG/$d/$name.icn" ]; then icn="$PKG/$d/$name.icn"; std="$PKG/$d/$name.ref"; break; fi
    done
    [ -n "$icn" ] || { echo "⛔ REFUSES(2): no such program $name.icn under $PKG/{progs,gprogs,procs,gprocs,incl,gincl}" >&2; exit 2; }
    [ -f "$std" ] || { echo "⛔ REFUSES(2): $name has no .ref -- ungradable, not failing" >&2; exit 2; }
    IPL_ISO_SUBDIR="$(basename "$(dirname "$std")")"; export IPL_ISO_SUBDIR
    GRADED=$((GRADED+1))
    exp="$(cat "$std")"
    stdin_src=/dev/null; [ -f "$(dirname "$icn")/$name.dat" ] && stdin_src="$(dirname "$icn")/$name.dat"
    declare -a AV=(); ipl_argv_read "$icn" AV; argv_rc=$?
    [ "$argv_rc" -eq 2 ] && { echo "⛔ REFUSES(2): $name argv sidecar malformed" >&2; exit 2; }
    IPL_ISO_FIXTURES="$icn"; export IPL_ISO_FIXTURES
    if [ "${#AV[@]}" -gt 0 ]; then ipl_isolation_run "$TMP/$name.m3" 180 "$stdin_src" "$SCRIP" --run "$icn" -- "${AV[@]}"
    else                          ipl_isolation_run "$TMP/$name.m3" 180 "$stdin_src" "$SCRIP" --run "$icn"; fi
    v3=FAIL; [ "$(cat "$TMP/$name.m3" 2>/dev/null)" = "$exp" ] && v3=PASS
    v4=FAIL
    if "$SCRIP" --compile "$icn" > "$TMP/$name.s" 2>/dev/null < /dev/null \
       && gcc -no-pie "$TMP/$name.s" -L"$ROOT/out" -lscrip_rt -Wl,-rpath,"$ROOT/out" -o "$TMP/$name.bin" 2>/dev/null; then
        if [ "${#AV[@]}" -gt 0 ]; then ipl_isolation_run "$TMP/$name.m4" 180 "$stdin_src" "$TMP/$name.bin" "${AV[@]}"
        else                          ipl_isolation_run "$TMP/$name.m4" 180 "$stdin_src" "$TMP/$name.bin"; fi
        [ "$(cat "$TMP/$name.m4" 2>/dev/null)" = "$exp" ] && v4=PASS
    fi
    printf '%-12s m3=%s m4=%s\n' "$name" "$v3" "$v4"
    { [ "$v3" = PASS ] && [ "$v4" = PASS ]; } || BAD=$((BAD+1))
done
[ "$GRADED" -gt 0 ] || { echo "⛔ REFUSES(2): graded zero programs" >&2; exit 2; }
echo "IPL_PROGRAM_GRADE graded=$GRADED bad=$BAD (both modes, against each program's own .ref)"
[ "$BAD" -eq 0 ]
