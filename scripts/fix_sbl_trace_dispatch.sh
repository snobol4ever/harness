#!/usr/bin/env bash
# fix_sbl_trace_dispatch.sh -- repair the SPITBOL fork's TRACE/control-card dispatch and swap the oracle.
#
# ⛔⭐ WHY THIS EXISTS (hq_B 2026-09-05; FINDING-2026-09-05-hq_B-the-snoflake-correctness-oracle-refuses-
# every-trace-type-...; ceo CEO-280 STOP-AND-FIX, CEO-282 "neither oracle is correct, the fix is yours to land").
#
#   /home/resources/x64/bin/sbl -- the binary that IS the verdict for every SNOBOL4 suite -- refuses EVERY
#   documented TRACE second argument with `ERROR 199`.  Stock upstream accepts them and traces.  Manual v3.7
#   p.244 documents the full table 'A'/'V'/'K'/'L'/'F'/'C'/'R'.
#
# ⭐ THE ROOT CAUSE, AND WHY THE OBVIOUS FIX IS WRONG.  MINIMAL has ONE opcode `flc` (fold character),
# emitted by asm.sbl proc g_flc.  The ENTIRE translator diff between stock and this fork is three lines:
# stock folds upper->lower (`cmp 'A'/'Z'; add 32`), the fork folds lower->UPPER (`cmp 'a'/'z'; sub 32`),
# flipped by fork commit e68dfeb "SN-30g ... UPPERCASE canonical case".  But flc has FOUR CALL SITES THAT
# DEMAND OPPOSITE DIRECTIONS:
#     flstg  (the &CASE name folder) guards `blt =ch_la` / `bgt =ch_l_` -- admits only a-z, then folds.
#            REQUIRES lower->UPPER.
#     trace  and the cnc control-card scanner fold the first character and compare it against LOWERCASE
#            constants (ch_la equ 97).  REQUIRE upper->lower.
# One opcode cannot serve both, so EACH BUILD IS CORRECT WHERE THE OTHER IS BROKEN -- measured:
#     x64   : folds names correctly (abc==ABC -> 5)  |  refuses every trace type
#     stock : traces correctly                        |  &CASE folding is a SILENT NO-OP
# ⛔ SO DO NOT "FIX" THIS BY REVERTING THE THREE TRANSLATOR LINES TO MATCH STOCK.  That trades the trace
# defect for the folding defect: it looks green on the trace witness while silently disabling &CASE -- the
# same "symptom leaves the board, bug stays in the tree" shape the snoflake row keeps hitting.
# ⭐ Both sbl.min files carry the SAME lowercase constants, so the trace dispatch is a defect in the SHARED
# UPSTREAM SOURCE that stock merely MASKS.  hq_P predicted exactly this class ("agreement across both builds
# cannot catch a defect inherited from shared upstream") -- which is why the MANUAL is the third authority.
#
# ✅ THE CURE: keep the fork's flc (it matches the MINIMAL contract -- the comment says "fold to upper case"
# and flstg's guard admits only a-z) and repair the ELEVEN dispatch constants to the ch_u* equates, which
# already exist with correct values (ch_ua equ 65, ch_ui 73, ch_un 78, ch_uv 86, ...).
#
# ⛔ EVERY grep here is `command grep`: Claude Code's shell injects a grep FUNCTION that silently misreads
# `cmd | grep pattern` on a STDIN pipe (seat01, 2026-09-05).  A verification script must not use it.
#
# Usage:  bash fix_sbl_trace_dispatch.sh [--dry-run]
#         --dry-run  builds and runs every gate, then STOPS before backup/install.
# Exit:   0 installed (or dry-run all-green) · 1 a gate went RED, nothing installed · 2 REFUSE, cannot measure.
set -u
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
ORACLE_DIR=${ORACLE_DIR:-/home/resources/x64}
STOCK=${STOCK:-/home/resources/spitbol-bench-oracle/sbl}
SUITE=${SUITE:-}
refuse() { echo "⛔ REFUSE(rc=2): $*"; exit 2; }
red()    { echo "⛔ RED(rc=1): $*"; exit 1; }

# ---------------------------------------------------------------------------- preconditions
[ -d "$ORACLE_DIR" ]         || refuse "no oracle tree at $ORACLE_DIR"
[ -x "$ORACLE_DIR/bin/sbl" ] || refuse "no $ORACLE_DIR/bin/sbl to repair or back up"
[ -f "$ORACLE_DIR/sbl.min" ] || refuse "no $ORACLE_DIR/sbl.min -- nothing to patch"
[ -x "$STOCK" ]              || refuse "no stock oracle at $STOCK -- the cross-LINEAGE control arm is not optional here: pairing a build against its own backup is blind to any defect they share, which is exactly what hid this for a day"
command -v nasm >/dev/null   || refuse "nasm not on PATH -- cannot rebuild"
command -v gcc  >/dev/null   || refuse "gcc not on PATH -- cannot rebuild"
if [ -z "$SUITE" ]; then
  for c in /home/claude_B/corpus /home/claude_C/corpus /home/claude_P/corpus /home/claude_T/corpus; do
    [ -d "$c/packages/snobol4/snoflake_suite" ] && { SUITE="$c/packages/snobol4/snoflake_suite"; break; }
  done
fi
[ -n "$SUITE" ] && [ -d "$SUITE" ] || refuse "no snoflake_suite found -- set SUITE=<path>; the 180-fixture regression census is a gate, not a nicety"

WORK=$(mktemp -d) || refuse "cannot make a work dir"
RUN="$WORK/run"; SINKD="$WORK/sink"; mkdir -p "$RUN" "$SINKD"
trap 'rm -rf "$WORK"' EXIT
echo "== staging a private copy (the shared tree is not touched until every gate is green)"
cp -a "$ORACLE_DIR" "$WORK/tree" || refuse "cp -a of the oracle tree failed"
SRC="$WORK/tree/sbl.min"; NEW="$WORK/tree/sbl"

# ---------------------------------------------------------------------------- the 11 constants
# Anchored on the BRANCH TARGET, not on a line number: each pattern below is unique in sbl.min, and none of
# them matches flstg's `blt wa,=ch_la,fst02` / `bgt wa,=ch_l_,fst02` guard, which MUST NOT change -- that is
# the a-z admission test feeding flc and it is correct as written.
PAIRS="
beq  wa,=ch_li,cnc07|beq  wa,=ch_ui,cnc07
bne  wa,=ch_ln,cnc0a|bne  wa,=ch_un,cnc0a
beq  wa,=ch_la,trc10|beq  wa,=ch_ua,trc10
beq  wa,=ch_lv,trc10|beq  wa,=ch_uv,trc10
beq  wa,=ch_lf,trc01|beq  wa,=ch_uf,trc01
beq  wa,=ch_lr,trc01|beq  wa,=ch_ur,trc01
beq  wa,=ch_ll,trc03|beq  wa,=ch_ul,trc03
beq  wa,=ch_lk,trc06|beq  wa,=ch_uk,trc06
bne  wa,=ch_lc,trc15|bne  wa,=ch_uc,trc15
beq  wa,=ch_lr,trc02|beq  wa,=ch_ur,trc02
beq  wa,=ch_lc,exnul|beq  wa,=ch_uc,exnul
"
cp "$SRC" "$WORK/sbl.min.pre"
n=0
while IFS='|' read -r from to; do
    [ -n "${from:-}" ] || continue
    hits=$(command grep -cF -- "$from" "$SRC")
    [ "$hits" = "1" ] || refuse "expected exactly ONE occurrence of [$from] in sbl.min, found $hits -- the source has moved under this script and a blind substitution would be a guess"
    FROM="$from" TO="$to" python3 - "$SRC" <<'PY' || refuse "substitution failed for $from"
import os,sys
p=sys.argv[1]; f=os.environ["FROM"]; t=os.environ["TO"]
s=open(p,encoding="utf-8",errors="surrogateescape").read()
assert s.count(f)==1, "occurrence count changed under us"
open(p,"w",encoding="utf-8",errors="surrogateescape").write(s.replace(f,t))
PY
    n=$((n+1))
done <<< "$PAIRS"
[ "$n" = "11" ] || refuse "applied $n substitutions, expected 11"
changed=$(diff "$WORK/sbl.min.pre" "$SRC" | command grep -c '^<')
[ "$changed" = "11" ] || red "expected exactly 11 changed lines, diff reports $changed"
# MINIMAL is column-sensitive: ch_l? -> ch_u? is width-preserving, so the file may not change size.
[ "$(wc -c < "$WORK/sbl.min.pre")" = "$(wc -c < "$SRC")" ] || red "sbl.min changed SIZE -- a column shifted, and MINIMAL is column-sensitive"
command grep -q 'blt  wa,=ch_la,fst02' "$SRC" || red "flstg's a-z guard was altered -- that guard must survive verbatim"
echo "== 11 constants applied, widths preserved, flstg guard intact"

# ---------------------------------------------------------------------------- build
echo "== rebuilding (uses the tree's own ./bin/sbl as BASEBOL)"
( cd "$WORK/tree" && make sbl ) > "$WORK/build.log" 2>&1 || { tail -20 "$WORK/build.log"; refuse "the rebuild failed -- log above; nothing was installed"; }
[ -x "$NEW" ] || refuse "make returned 0 but produced no $NEW"
echo "== built"

# ---------------------------------------------------------------------------- gates
run_sno() { # $1=binary $2=flags ; program on stdin
    cat > "$RUN/f.sno"; ( cd "$RUN" && timeout 25 "$1" $2 f.sno < /dev/null 2>&1 )
}
TRACEPROG="         &TRACE = 100\n         X = 1\n         TRACE('X', 'VALUE')\n         X = 2\n         OUTPUT = 'OK'\nEND\n"
TRACELOW="         &TRACE = 100\n         X = 1\n         TRACE('X', 'value')\n         X = 2\n         OUTPUT = 'OK'\nEND\n"
FOLDPROG="         abc = 5\n         OUTPUT = ABC\n         OUTPUT = 'end'\nEND\n"
fail=0
check() { # $1=label $2=expect-substring $3=actual
    if printf '%s' "$3" | command grep -qF -- "$2"; then echo "  ✅ $1"
    else echo "  ⛔ $1 -- expected [$2], got [$(printf '%s' "$3" | tr '\n' ' ')]"; fail=$((fail+1)); fi
}
echo "== ACCEPTANCE (all four must pass in ONE binary -- no build on this box did before)"
T1=$(printf "$TRACEPROG" | run_sno "$NEW" "-bf");  check "TRACE('X','VALUE') traces"          "X = 2" "$T1"
T2=$(printf "$TRACELOW"  | run_sno "$NEW" "-bf");  check "TRACE('X','value') traces (folded)" "X = 2" "$T2"
T3=$(printf "$FOLDPROG"  | run_sno "$NEW" "-b");   check "-b  folds names: abc==ABC -> 5"     "5"     "$T3"
T4=$(printf "$FOLDPROG"  | run_sno "$NEW" "-bf")
if printf '%s' "$T4" | command grep -qx '5'; then echo "  ⛔ -bf must stay case-SENSITIVE (-f turns folding off) but it printed 5"; fail=$((fail+1))
else echo "  ✅ -bf stays case-sensitive"; fi
printf '%s' "$T1$T2" | command grep -q 'ERROR 199' && { echo "  ⛔ ERROR 199 is still raised"; fail=$((fail+1)); }
[ "$fail" = "0" ] || red "$fail acceptance test(s) failed -- nothing installed"

echo "== REGRESSION CENSUS over all 180 fixtures: old bin/sbl vs the fixed build."
echo "   Only the trace class may differ.  Anything else is collateral and stops the swap."
OLD="$ORACLE_DIR/bin/sbl"
diffs=0; unexpected=""; total=0
for sno in "$SUITE"/*.sno; do
    name=$(basename "$sno" .sno); total=$((total+1))
    : > "$WORK/inp"; inblock=""
    while IFS= read -r line || [ -n "$line" ]; do
        case "$line" in '*'*) ;; *) break;; esac
        if [ -n "$inblock" ]; then
            [ "$line" = '* <<<' ] && { inblock=""; continue; }
            if [ "$line" = '*' ]; then p=""; elif [ "${line:0:2}" = '* ' ]; then p="${line:2}"; else continue; fi
            printf '%s\n' "$p" >> "$WORK/inp"; continue
        fi
        case "$line" in '* @input >>>'*) inblock=input;; esac
    done < "$sno"
    rm -f "$RUN/f.sno"; cp "$sno" "$RUN/f.sno"
    a=$( cd "$RUN" && timeout 25 "$OLD" -bf "-o=$SINKD/l" f.sno < "$WORK/inp" 2>&1 )
    b=$( cd "$RUN" && timeout 25 "$NEW" -bf "-o=$SINKD/l" f.sno < "$WORK/inp" 2>&1 )
    [ "$a" = "$b" ] && continue
    # SPITBOL's statistics block carries a nondeterministic `execution time msec`; that alone is not a change.
    [ "$(printf '%s' "$a" | command grep -v 'execution time msec')" = "$(printf '%s' "$b" | command grep -v 'execution time msec')" ] && continue
    diffs=$((diffs+1))
    case "$name" in trace-*|stop-tracing|value-trace-during-match|twelve-days) ;; *) unexpected="$unexpected $name";; esac
done
[ "$total" -ge 100 ] || refuse "census saw only $total fixtures -- a census that cannot see its population must never print a verdict"
echo "   fixtures=$total  changed-by-this-fix=$diffs"
[ -z "$unexpected" ] || red "COLLATERAL CHANGE outside the trace class:$unexpected -- nothing installed"
[ "$diffs" -gt 0 ]   || red "the fix changed NOTHING across $total fixtures -- it cannot be doing what it claims"
echo "   ✅ every change is inside the trace class"

echo "== CROSS-LINEAGE control: the fixed build vs STOCK on the free-pass witnesses"
agree=0; disagree=""
for name in trace-procedure value-trace-during-match stop-tracing; do
    [ -f "$SUITE/$name.sno" ] || continue
    rm -f "$RUN/f.sno"; cp "$SUITE/$name.sno" "$RUN/f.sno"
    x=$( cd "$RUN" && timeout 25 "$NEW"   -bf "-o=$SINKD/l" f.sno < /dev/null 2>&1 )
    y=$( cd "$RUN" && timeout 25 "$STOCK" -bf "-o=$SINKD/l" f.sno < /dev/null 2>&1 )
    if [ "$(printf '%s' "$x" | command grep -v 'execution time msec')" = "$(printf '%s' "$y" | command grep -v 'execution time msec')" ]; then agree=$((agree+1)); else disagree="$disagree $name"; fi
done
[ -z "$disagree" ] || red "the fixed build still disagrees with STOCK on:$disagree"
echo "   ✅ $agree/3 byte-agree with stock (these are the fixtures SCRIP already passes -- free passes the broken oracle was withholding)"

if [ "$DRY" = "1" ]; then
    echo; echo "✅ DRY RUN ALL GREEN -- every gate passed, nothing installed. Re-run without --dry-run to swap."; exit 0
fi

# ---------------------------------------------------------------------------- backup + swap
STAMP=$(date -u +%Y%m%dT%H%M%SZ)
BAK="$ORACLE_DIR/bin/sbl.bak-$STAMP"
cp -p "$ORACLE_DIR/bin/sbl" "$BAK" || refuse "could not write the dated backup -- refusing to swap without one"
[ -s "$BAK" ]                      || refuse "backup $BAK is empty -- refusing to swap"
cp "$NEW" "$ORACLE_DIR/bin/sbl"    || refuse "install failed AFTER the backup was made; restore with: cp -p $BAK $ORACLE_DIR/bin/sbl"
cp "$SRC" "$ORACLE_DIR/sbl.min"    || refuse "sbl.min install failed and the BINARY IS ALREADY SWAPPED -- restore with: cp -p $BAK $ORACLE_DIR/bin/sbl"
POST=$(printf "$TRACEPROG" | run_sno "$ORACLE_DIR/bin/sbl" "-bf")
printf '%s' "$POST" | command grep -qF "X = 2" || { cp -p "$BAK" "$ORACLE_DIR/bin/sbl"; refuse "post-install smoke FAILED -- rolled the binary back to $BAK"; }
echo
echo "✅ SWAPPED at $STAMP"
echo "   backup : $BAK"
echo "   binary : $ORACLE_DIR/bin/sbl   (md5 $(md5sum "$ORACLE_DIR/bin/sbl" | cut -c1-12))"
echo "   source : $ORACLE_DIR/sbl.min   (11 dispatch constants -> ch_u*)"
echo
echo "⛔ STILL OWED IN THIS SITTING -- the swap is not the deliverable:"
echo "   1. commit + push the fork (git -C $ORACLE_DIR add -A; commit; push)"
echo "   2. ORACLES.md top line names the new commit"
echo "   3. BROADCAST the swap minute to every seat inbox -- every board measured BEFORE $STAMP must be re-measured"
echo "   4. re-baseline snoflake and rewrite the SCORE.md vendor cell through the runner itself"
