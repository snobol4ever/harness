#!/usr/bin/env bash
# test_gate_spitbol_x64_case_conversion_is_oracle_equivalent.sh
# ⭐ THE PROOF BEHIND CEO-571's UPPERCASE CONVERSION OF corpus/packages/snobol4/spitbol_x64_tests.
#
# WHY.  SPITBOL folds case by default; our one mandated arm is `sbl -bf` and `-f` turns folding OFF, because
# that is the arm SCRIP's case-sensitive SNOBOL4 matches (lib_oracle_flags.sh, s189).  29 of these 36 vendored
# programs are written in SPITBOL's lower-case idiom and `-bf` refused them with "No END statement found".
# CEO-571 ruled the cure is to convert the SOURCE in the repo, once -- never at grade time.  A conversion is
# only legitimate if it did not change what the program MEANS, and that is what this gate measures:
#
#   for every *.sbl in the package:   sbl ORIGINAL (folding, upstream's own invocation, vendored tree)
#                             vs      sbl -bf CURRENT (our converted tree)
#   must agree BYTE-FOR-BYTE on stdout AND stderr AND on the exit code.
#
# ⛔ rc ALONE IS NOT THE VERDICT.  Measured during CEO-571: the math tests changed one line each yet diverged,
# because their `-INCLUDE` was still lower case and the `-bf` run then printed NOTHING AT ALL while still
# exiting 0.  A silent empty run reads green to any check that only reads `$?`.  Hence stdout+stderr+rc.
#
# ⛔ EACH PROGRAM RUNS IN ITS OWN FRESH COPY OF ITS OWN TREE.  These programs write files into cwd (save.spx,
# module.out, arcput's archive, &dump output).  Sharing one run directory across programs makes a program's
# verdict depend on which programs ran before it, and the two arms do not hold the same files to begin with.
#
# ⛔ REFUSES (rc=2) rather than reporting a result it could not take: missing oracle, missing package, missing
# vendored baseline.  A test that cannot measure never reports green.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
WS="$(cd "$ROOT/.." && pwd)"
. "$HERE/lib_oracle_flags.sh" || { echo "REFUSE: cannot load lib_oracle_flags.sh"; exit 2; }
SBL="$(sbl_correctness_bin 2>/dev/null)"
[ -n "$SBL" ] && [ -x "$SBL" ] || { echo "REFUSE: SPITBOL CORRECTNESS oracle (x64) not executable: '${SBL:-<empty>}'"; exit 2; }
LANG_FLAGS="$(sbl_lang_flags)"
PKG_REL="packages/snobol4/spitbol_x64_tests"
CORPUS="$WS/corpus"
PKG="$CORPUS/$PKG_REL"
[ -d "$PKG" ] || { echo "REFUSE: package not found: $PKG"; exit 2; }
git -C "$CORPUS" rev-parse --git-dir >/dev/null 2>&1 || { echo "REFUSE: $CORPUS is not a git repo; the ORIGINAL arm has no source"; exit 2; }
# The ORIGINAL is the pristine vendored tree -- the commit that ADDED this package, found, never typed.
VENDOR="$(git -C "$CORPUS" log --diff-filter=A --format=%H --reverse -- "$PKG_REL" | head -1)"
[ -n "$VENDOR" ] || { echo "REFUSE: cannot find the commit that vendored $PKG_REL"; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/spitbol_x64_case.XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/orig.tree"
git -C "$CORPUS" archive "$VENDOR" "$PKG_REL" | tar -x -C "$TMP/orig.tree" --strip-components=3 || { echo "REFUSE: cannot extract the vendored tree at $VENDOR"; exit 2; }
[ -n "$(ls -A "$TMP/orig.tree" 2>/dev/null)" ] || { echo "REFUSE: vendored tree extracted empty at $VENDOR"; exit 2; }
# ⛔⭐ ONE NAMED NORMALIZATION, AND IT EXISTS BECAUSE ONE PROGRAM PRINTS THINGS NO CASE CONVERSION CAN REACH.
# `gcbuster.sbl` sets `&DUMP = 1`, so SPITBOL dumps the symbol table and every keyword on exit.  Two cells in
# that dump are outside any source edit's reach, both MEASURED, not argued:
#   (1) `&CASE` IS THE FOLDING FLAG THE TWO ARMS DIFFER IN BY CONSTRUCTION -- the folding arm prints `&CASE = 1`
#       and the `-bf` arm prints `&CASE = 0`.  A program that reports the invocation cannot be made invariant
#       under the invocation; converting its source harder never closes this line.
#   (2) `BASEMEM` / `TOPMEM` are `HOST(-1,2)` / `HOST(-1,3)`, RAW HEAP ADDRESSES UNDER ASLR.  Measured: three
#       consecutive runs of the UNMODIFIED vendored source under the SAME binary print three different values,
#       so the ORIGINAL arm is not byte-identical TO ITSELF here.  No `.ref` could pin this either.
# ⛔ THE NORMALIZATION IS APPLIED TO BOTH ARMS, IS ANCHORED TO WHOLE LINES, AND IS PRINTED IN THE VERDICT -- a
# silent filter is how a gate stops measuring.  Everything else in that dump (all ten natural variable names,
# their values, the other 23 keywords) is compared byte-for-byte, which is what caught the user identifiers:
# under folding the dump reads `BASEMEM`, under `-bf` it read `basemem`, so gcbuster's user names ARE
# observable output and had to be converted too -- the one file in this package where that is true.
spitbol_x64_normalize() {   # $1 = program name; filters stdin
    case "$1" in
    gcbuster.sbl) sed -E -e 's/^(BASEMEM|TOPMEM) = [0-9]+$/\1 = <ASLR-heap-address>/' -e 's/^&CASE = [01]$/\&CASE = <the-arm-being-compared>/' ;;
    *) cat ;;
    esac
}
spitbol_x64_normalized_note() { case "$1" in gcbuster.sbl) echo "  (normalized: &CASE, ASLR BASEMEM/TOPMEM)" ;; *) echo "" ;; esac; }
TO="${SPITBOL_X64_TIMEOUT:-600}"
PASS=0; FAIL=0; FAILED=""
echo "gate: spitbol_x64 case conversion is oracle-equivalent"
echo "  oracle   : $SBL"
echo "  original : $VENDOR (folding, no flags)   current: worktree ($LANG_FLAGS)"
for src in "$PKG"/*.sbl; do
    f="$(basename "$src")"
    if [ ! -f "$TMP/orig.tree/$f" ]; then
        FAIL=$((FAIL+1)); FAILED="$FAILED $f(no-vendored-original)"; printf '  %-20s FAIL  not present in the vendored tree\n' "$f"; continue
    fi
    rm -rf "$TMP/a" "$TMP/b"
    cp -r "$TMP/orig.tree" "$TMP/a" && cp -r "$PKG" "$TMP/b" || { echo "REFUSE: cannot stage run directories"; exit 2; }
    ( cd "$TMP/a" && timeout -k 5 "$TO" "$SBL"              "$f" ) </dev/null >"$TMP/a.raw" 2>"$TMP/a.err"; rca=$?
    ( cd "$TMP/b" && timeout -k 5 "$TO" "$SBL" $LANG_FLAGS  "$f" ) </dev/null >"$TMP/b.raw" 2>"$TMP/b.err"; rcb=$?
    spitbol_x64_normalize "$f" <"$TMP/a.raw" >"$TMP/a.out"
    spitbol_x64_normalize "$f" <"$TMP/b.raw" >"$TMP/b.out"
    why=""
    [ "$rca" = "$rcb" ] || why="rc $rca vs $rcb"
    cmp -s "$TMP/a.out" "$TMP/b.out" || why="${why:+$why; }stdout differs ($(diff "$TMP/a.out" "$TMP/b.out" | grep -c '^[<>]') lines)"
    cmp -s "$TMP/a.err" "$TMP/b.err" || why="${why:+$why; }stderr differs"
    if [ -z "$why" ]; then
        PASS=$((PASS+1)); printf '  %-20s pass  rc=%s %s bytes%s\n' "$f" "$rca" "$(wc -c <"$TMP/a.out")" "$(spitbol_x64_normalized_note "$f")"
    else
        FAIL=$((FAIL+1)); FAILED="$FAILED $f"; printf '  %-20s FAIL  %s\n' "$f" "$why"
    fi
done
TOTAL=$((PASS+FAIL))
echo "spitbol_x64 case conversion: PASS=$PASS FAIL=$FAIL of $TOTAL"
[ "$FAIL" = 0 ] || { echo "  failing:$FAILED"; exit 1; }
[ "$TOTAL" -gt 0 ] || { echo "REFUSE: population is empty"; exit 2; }
exit 0
