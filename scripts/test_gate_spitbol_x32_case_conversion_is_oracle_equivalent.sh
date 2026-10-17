#!/usr/bin/env bash
# test_gate_spitbol_x32_case_conversion_is_oracle_equivalent.sh
# ⭐ THE PROOF BEHIND THE CEO-571 UPPERCASE CONVERSION OF corpus/packages/snobol4/spitbol_x32_tests (ceo CEO-1287,
# Lon 2026-09-26).  test_gate_spitbol_x64_case_conversion_is_oracle_equivalent.sh's method, whose header carries the why:
#
#   for every *.spt in the package:   sbl ORIGINAL (folding, upstream's own invocation, the commit that ADDED the package)
#                             vs      sbl -bf CURRENT (our converted tree)
#   must agree BYTE-FOR-BYTE on stdout AND stderr AND on the exit code, each program in a fresh copy of its own tree.
#
# ⭐ TWO STDIN ARMS, NOT ONE.  Most of these 21 are SPITBOL's build-time filters (lower, cc, tbl, c, rev, def, arcput...) and
# print NOTHING on /dev/null, so an empty-stdin comparison cannot see a conversion that broke their logic.  MEASURED at vendoring:
# c.spt calls `leq`, the converter's list lacked LEQ, `-bf` then raised undefined function inside the block-comment branch --
# and the /dev/null arm read it as equivalent while a four-line text stdin read 4 lines against the original's 18.  So every
# program runs on /dev/null AND on the fixed text below, and both must agree.
#
# ⛔ REFUSES (rc=2) on a missing oracle, a missing package, a corpus that is not a git repo, or a vendored tree that extracts empty.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)"
WS="$(cd "$ROOT/.." && pwd)"
. "$HERE/lib_oracle_flags.sh" || { echo "REFUSE: cannot load lib_oracle_flags.sh"; exit 2; }
SBL="$(sbl_correctness_bin 2>/dev/null)"
[ -n "$SBL" ] && [ -x "$SBL" ] || { echo "REFUSE: SPITBOL CORRECTNESS oracle (x64) not executable: '${SBL:-<empty>}'"; exit 2; }
LANG_FLAGS="$(sbl_lang_flags)"
PKG_REL="packages/snobol4/spitbol_x32_tests"
CORPUS="${SPITBOL_X32_CORPUS:-$WS/corpus}"
PKG="$CORPUS/$PKG_REL"
[ -d "$PKG" ] || { echo "REFUSE: package not found: $PKG"; exit 2; }
git -C "$CORPUS" rev-parse --git-dir >/dev/null 2>&1 || { echo "REFUSE: $CORPUS is not a git repo; the ORIGINAL arm has no source"; exit 2; }
VENDOR="$(git -C "$CORPUS" log --diff-filter=A --format=%H --reverse -- "$PKG_REL" | head -1)"
[ -n "$VENDOR" ] || { echo "REFUSE: cannot find the commit that vendored $PKG_REL"; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/spitbol_x32_case.XXXXXX")" || exit 2
trap 'rm -rf "$TMP"' EXIT
mkdir -p "$TMP/orig.tree"
git -C "$CORPUS" archive "$VENDOR" "$PKG_REL" | tar -x -C "$TMP/orig.tree" --strip-components=3 || { echo "REFUSE: cannot extract the vendored tree at $VENDOR"; exit 2; }
[ -n "$(ls -A "$TMP/orig.tree" 2>/dev/null)" ] || { echo "REFUSE: vendored tree extracted empty at $VENDOR"; exit 2; }
printf 'Hello World\nfoo /* a comment */ bar\n  mov  r1,r2   move it\nABC def\n' > "$TMP/text.in"
TO="${SPITBOL_X32_TIMEOUT:-600}"
PASS=0; FAIL=0; FAILED=""
echo "gate: spitbol_x32 case conversion is oracle-equivalent"
echo "  oracle   : $SBL"
echo "  original : $VENDOR (folding, no flags)   current: worktree ($LANG_FLAGS)   stdin arms: /dev/null and a 4-line text"
for src in "$PKG"/*.spt; do
    f="$(basename "$src")"
    if [ ! -f "$TMP/orig.tree/$f" ]; then
        FAIL=$((FAIL+1)); FAILED="$FAILED $f(no-vendored-original)"; printf '  %-12s FAIL  not present in the vendored tree\n' "$f"; continue
    fi
    why=""; bytes=""
    for arm in null text; do
        inp=/dev/null; [ "$arm" = text ] && inp="$TMP/text.in"
        rm -rf "$TMP/a" "$TMP/b"
        cp -r "$TMP/orig.tree" "$TMP/a" && cp -r "$PKG" "$TMP/b" || { echo "REFUSE: cannot stage run directories"; exit 2; }
        ( cd "$TMP/a" && timeout -k 5 "$TO" "$SBL"             "$f" ) <"$inp" >"$TMP/a.out" 2>"$TMP/a.err"; rca=$?
        ( cd "$TMP/b" && timeout -k 5 "$TO" "$SBL" $LANG_FLAGS "$f" ) <"$inp" >"$TMP/b.out" 2>"$TMP/b.err"; rcb=$?
        [ "$rca" = "$rcb" ] || why="${why:+$why; }$arm: rc $rca vs $rcb"
        cmp -s "$TMP/a.out" "$TMP/b.out" || why="${why:+$why; }$arm: stdout differs ($(diff "$TMP/a.out" "$TMP/b.out" | grep -c '^[<>]') lines)"
        cmp -s "$TMP/a.err" "$TMP/b.err" || why="${why:+$why; }$arm: stderr differs"
        bytes="$bytes $arm=$(wc -c <"$TMP/a.out")"
    done
    if [ -z "$why" ]; then PASS=$((PASS+1)); printf '  %-12s pass  bytes%s\n' "$f" "$bytes"
    else FAIL=$((FAIL+1)); FAILED="$FAILED $f"; printf '  %-12s FAIL  %s\n' "$f" "$why"; fi
done
TOTAL=$((PASS+FAIL))
echo "spitbol_x32 case conversion: PASS=$PASS FAIL=$FAIL of $TOTAL"
[ "$FAIL" = 0 ] || { echo "  failing:$FAILED"; exit 1; }
[ "$TOTAL" -gt 0 ] || { echo "REFUSE: population is empty"; exit 2; }
exit 0
