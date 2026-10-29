#!/usr/bin/env bash
# board_beauty_m1.sh — ⭐ THE M1 PROGRESS BOARD (s183, HQ Fable).
#
#   bash ../harness/scripts/board_beauty_m1.sh [--modes m3|m4|both] [--rungs "1 2 5 ..."] [--bisect]
#
# ⛔ WHY THIS EXISTS.  MILESTONE 1 was a BINARY fact — beauty either self-hosts or it does not — and a binary
# fact cannot be delegated: there is exactly one rung and one seat can hold it.  This board makes M1 a LADDER
# by feeding beauty INCREASING PREFIXES OF ITS OWN SOURCE, so "how much of itself can beauty handle" becomes a
# number that moves.  Every red rung it names is an independently dispatchable row, which is what lets the
# fleet work M1 in parallel instead of queueing behind one seat.
#
# THE ORACLE IS THE JUDGE, NOT THE INPUT FILE — for PREFIX rungs only.  ⭐ s267 CORRECTION (was: graded every
# rung, including the full file, against `sbl` on beauty.sno itself): beauty.sno now opens the BEAUTY-CN
# `&`-constant namespace (`&USER_DECLARED_CONSTANTS`, line 9) — a SCRIP extension stock SPITBOL has no keyword
# for.  `sbl -bf` refuses at line 10 but exits rc=0 and prints its error TO STDOUT, so a harness that diffs
# stdout against expected output grades SCRIP's correct answer against an ORACLE ERROR MESSAGE — a false RED on
# every single rung, including the trivial one-line one (FINDING-2026-08-23-hq_P-the-m1-board-grades-beauty-
# against-an-oracle-that-refuses-it.md; independently cross-validated FINDING-2026-08-23-seat15-m1-board-judge-
# is-a-refusing-oracle.md).  Root cause is a known, tracked language-support gap (ARCH-LANGUAGES.md "Oracle
# amplification"; GOAL-SCRIP-HQ.md D-12/D-13, the `sbl-x`/`csnobol4-x` amplified-oracle pair, READY/queued) —
# this board works around it two ways, permanently, not just until D-12 lands:
#   THE FULL-FILE RUNG *is* MILESTONE 1 (Lon ruling s117): the checked-in beauty.sno is its OWN oracle.  Judge =
#   `cmp` against the INPUT FILE, byte-identical is the fixed point.  No SPITBOL involved, none needed.
#   PREFIX RUNGS grade against the live oracle on `beauty_classic.sno` — a FROZEN pre-BEAUTY-CN snapshot (last
#   commit before `53dd9ac0d`), portable SPITBOL, verified a fixed point of itself on BOTH engines the day this
#   was written.  A prefix of a `&`-constant program is not SPITBOL-gradable in principle (`&USER_DECLARED_
#   CONSTANTS` sits on line 9, inside every rung); a prefix of the frozen classic file still is.  Treat
#   `beauty_classic.sno` like `corpus/generated/` — pinned, never hand-edited, exists purely as a ladder target.
# ⛔ NO md5 IS EVER PINNED ANYWHERE IN THIS FILE (GOAL-SNOBOL4-100 DOD item 2) — both the oracle and the
# milestone's own input file are re-read fresh every run; a pinned hash goes stale the instant either file
# legitimately changes, silently, which is exactly the class of mistake that produced the bug this rewrite fixes.
# ⛔ REFUSE, NEVER DIFF (V2-5 `lib_gate.sh` discipline): rc=0 does not prove the oracle beautified anything on
# THIS box — verified `sbl -bf` exits 0 on its own refusal — so every oracle call is also sniffed for its own
# error-citation shape (`") : ERROR "`) and tagged `ORACLE-REFUSED`, excluded from both pass and fail tallies,
# never silently diffed as if it were real output.
#
# ⛔ `-bf` is REQUIRED and the reason is the LANGUAGE, not beauty: SPITBOL case-folds names by default (manual p.23/28) and SCRIP is CASE-SENSITIVE,
# so `-b` grades against a language SCRIP may not speak.  The `-b` SIGSEGV is DOWNSTREAM -- folding manufactures a phantom ERROR 217 duplicate label
# (`shift`/`Shift`, semantic.inc(16)) and SPITBOL cores in error RECOVERY; a GENUINE duplicate label SIGSEGVs under `-bf` too.  Under `-b` beauty has no
# stable oracle at all (3 runs: rc 139, three different md5s at 1079 bytes; `-bf`: rc 0, 40970 bytes, one md5).  s189 seat2.  m4 links out/libscrip_rt.so.
#
# ⭐ FIRST READING (s183, SCRIP 3da13598, m3): 3/10 rungs green, first red at 10 lines; --bisect named the exact
# first failing line as LINE 8 = the bare label START (lines 1-7 are comments and pass).  From there the wall
# reduced BY HAND to two INDEPENDENT classes, checked into corpus as beauty/m1_lad_*.in with live-oracle .refs:
#   CLASS A -- SEGV when beauty *COMPLETES* the parse; oracle returns the IDENTITY.  1-9 byte witnesses:
#             m1_lad_empty "\n" · m1_lad_barelabel "X\n" · m1_lad_end "END\n" · m1_lad_comment "* hi\nEND\n"
#             (the last PRINTS "* hi" CORRECTLY AND THEN DIES -- so the crash is in the completion/output path).
#   CLASS B -- `Parse Error` where the oracle beautifies; bails before ever reaching class A:
#             m1_lad_stmt · m1_lad_labelstmt · m1_lad_two · m1_lad_match.
# They are SEQUENTIAL IN A RUN but INDEPENDENT IN THE CODE, so they are two rows worked in PARALLEL.  (This note
# also restores the words a backtick ate out of this file's own commit message -- history is not force-rewritten
# with seats pulling; the record is corrected in place, which is where a reader looks anyway.)
#
# ⛔ AN INPUT WITHOUT AN `END` IS NOT A PROGRAM.  beauty parses a WHOLE program; feed it a fragment and the
# ORACLE ITSELF answers with EMPTY OUTPUT, so any verdict built on that input is meaningless.  HQ's first cut of
# the class-B inputs had exactly this defect and was caught before dispatch.  Every ladder input ends with END.
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME
TIMEOUT_RETRY="${TIMEOUT_RETRY:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_timeout_retry.sh}"   # every graded timeout is retried once, longer (Lon 2026-10-15, in-chat to the coo: "do a retry with longer timeouts")
S4A="${S4E_ASSETS:-$([ -d "$S4E/x64" ] && echo "$S4E" || echo /home/resources)}"   # D-17b: ASSET root -- oracles/vendor trees live at the HQ root on this machine (Lon: seats carry ONLY .github/SCRIP/corpus); a root owning its own x64 (HQ, or a full standalone clone-set) is self-contained.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_gate.sh"   # V2-5 three-exit-code discipline: 0 CLEAN / 1 VIOLATION / 2 UNPROVEN, never conflated
SCRIP="$S4E/SCRIP/scrip"
SBL="$S4A/x64/bin/sbl"
BDIR="$S4E/corpus/demos/snobol4/beauty"   # ⭐ REPOINTED 2026-09-01 (row dead-suite-path-consumer-sweep, seat05): was $S4E/corpus/crosscheck/beauty, deleted by corpus 69c43155e ("crosscheck: delete beauty/ fixtures", LON-20260828 total conversion) after corpus b131a913d dissolved beauty/.
SRC="$BDIR/beauty.sno"
CLASSIC="$S4E/corpus/demos/snobol4/beauty/beauty.sno"   # ⛔ SRC AND CLASSIC ARE NOW THE SAME FILE, AND THAT IS CORRECT, NOT A BUG -- Lon s271 (corpus b131a913d, "beauty resolution"): the DECLARED_CONSTANT/&-constant beauty.sno was DELETED ("the conversion did not help") and "beauty_classic.sno IS the correct beauty.sno", renamed to beauty.sno on the move to demos/. The two-file CN-vs-classic world this board was written for no longer exists; exactly ONE beauty.sno remains in corpus and it is the portable-SPITBOL classic. The prefix ladder is MORE valid than before, not less: its stated requirement (header, and the echo at the prefix-rung banner below) is that the graded file be the oracle-gradable classic, which is now the only file there is. The full-file rung stays oracle-free by design (Lon s117: beauty.sno is its OWN oracle).
MODES=both; RUNGS=""; BISECT=0
while [ $# -gt 0 ]; do case "$1" in
    --modes) MODES="$2"; shift 2;; --rungs) RUNGS="$2"; shift 2;; --bisect) BISECT=1; shift;;
    *) echo "usage: board_beauty_m1.sh [--modes m3|m4|both] [--rungs \"1 2 5\"] [--bisect]"; exit 2;; esac; done
gate_require_exec "$SCRIP" "scrip binary (run make)"
gate_require_exec "$SBL" "SPITBOL bench oracle (D-17b: seats do not clone x64 -- point S4E_ASSETS at a root that has it)"
gate_require "$CLASSIC" "frozen pre-BEAUTY-CN beauty_classic.sno (the prefix ladder's oracle-gradable target)"
TOT=$(wc -l < "$SRC")
[ -n "$RUNGS" ] || RUNGS="1 2 5 10 20 40 80 160 320 $TOT"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
# ---------------------------------------------------------------- one rung: N leading lines of {SRC,CLASSIC} as the input
rung() {
    local n="$1" mode="$2" tag rc prog
    # THE MILESTONE ITSELF (Lon s117): the full, current, checked-in beauty.sno is its OWN oracle. No SPITBOL --
    # BEAUTY-CN's &-constant namespace makes $SRC oracle-ungradable in principle (see header). This branch is
    # oracle-free BY DESIGN, not because the oracle was skipped by omission.
    if [ "$n" = "$TOT" ]; then
        prog="$SRC"
        if [ "$mode" = m3 ]; then
            "$TIMEOUT_RETRY" 60 "$SCRIP" "$prog" < "$prog" > "$WORK/got.$n" 2>/dev/null; rc=$?
        else
            ( cd "$BDIR" && "$TIMEOUT_RETRY" 120 "$SCRIP" --compile --out="$WORK/b.s" "$prog" ) >/dev/null 2>&1 || { echo "COMPILE-FAIL"; return; }
            gcc -no-pie "$WORK/b.s" -L"$S4E/SCRIP/out" -lscrip_rt -Wl,-rpath,"$S4E/SCRIP/out" -lm -o "$WORK/b.bin" >/dev/null 2>&1 \
                || { echo "LINK-FAIL"; return; }
            "$TIMEOUT_RETRY" 60 "$WORK/b.bin" < "$prog" > "$WORK/got.$n" 2>/dev/null; rc=$?
        fi
        if   [ "$rc" -eq 139 ]; then tag="SEGV"
        elif [ "$rc" -eq 124 ]; then tag="HANG"
        elif [ "$rc" -ne 0 ];   then tag="rc$rc"
        elif cmp -s "$WORK/got.$n" "$prog"; then tag="⭐M1-FIXED-POINT"
        else tag="PASS-but-NOT-fixed-point"; fi
        echo "$tag"; return
    fi
    # PREFIX LADDER RUNGS: graded against the LIVE oracle on the frozen, portable $CLASSIC (see header) -- $SRC
    # cannot serve this role any more.
    prog="$CLASSIC"
    head -n "$n" "$prog" > "$WORK/in.$n"
    "$TIMEOUT_RETRY" 60 "$SBL" -bf "$prog" < "$WORK/in.$n" > "$WORK/oracle.$n" 2>/dev/null; local orc=$?
    if [ "$mode" = m3 ]; then
        "$TIMEOUT_RETRY" 60 "$SCRIP" "$prog" < "$WORK/in.$n" > "$WORK/got.$n" 2>/dev/null; rc=$?
    else
        ( cd "$BDIR" && "$TIMEOUT_RETRY" 120 "$SCRIP" --compile --out="$WORK/b.s" "$prog" ) >/dev/null 2>&1 || { echo "COMPILE-FAIL"; return; }
        gcc -no-pie "$WORK/b.s" -L"$S4E/SCRIP/out" -lscrip_rt -Wl,-rpath,"$S4E/SCRIP/out" -lm -o "$WORK/b.bin" >/dev/null 2>&1 \
            || { echo "LINK-FAIL"; return; }
        "$TIMEOUT_RETRY" 60 "$WORK/b.bin" < "$WORK/in.$n" > "$WORK/got.$n" 2>/dev/null; rc=$?
    fi
    # ⛔ REFUSE, NEVER DIFF. rc=0 does not prove the oracle beautified anything -- measured fact on this box,
    # `sbl -bf` exits 0 on its own refusal -- so also sniff its stdout for its own error-citation shape. TWO
    # markers required TOGETHER, never either alone (same discipline as scorecard_snobol4.sh's sbl_died(), s191
    # row ref-the-ungraded-suites -- a different incident, Gimpel's ERROR 042/116/..., same underlying SPITBOL
    # behaviour: it exits 0 after printing a fatal report to stdout). A refusal is excluded from both tallies
    # below (ORACLE-* case arms), never diffed as if it were real output.
    local why=""
    [ "$orc" -ne 0 ] && why="rc$orc"
    if grep -qE ' : ERROR [0-9][0-9][0-9] -- ' "$WORK/oracle.$n" 2>/dev/null && grep -qE '^in statement +[0-9]+$' "$WORK/oracle.$n" 2>/dev/null; then
        why="${why:+$why,}content"
    fi
    if   [ -n "$why" ];      then tag="ORACLE-REFUSED($why)"
    elif [ "$rc" -eq 139 ]; then tag="SEGV"
    elif [ "$rc" -eq 124 ]; then tag="HANG"
    elif [ "$rc" -ne 0 ];   then tag="rc$rc"
    elif cmp -s "$WORK/got.$n" "$WORK/oracle.$n"; then tag="PASS"
    else tag="DIFF"; fi
    echo "$tag"
}
echo "=== M1 PROGRESS BOARD — beauty.sno fed INCREASING PREFIXES OF ITSELF ($TOT lines total) ==="
echo "    prefix rungs: judge = live oracle (sbl -bf) on beauty_classic.sno (frozen, pre-BEAUTY-CN, portable SPITBOL)"
echo "    rung $TOT (full CURRENT beauty.sno): judge = the INPUT FILE itself (Lon s117) -- no oracle, that IS milestone 1"
printf "%8s  %-24s %-24s\n" "lines" "m3 (--run)" "m4 (--compile)"
first_red_m3=""; first_red_m4=""; pass3=0; pass4=0; tried=0; violations=0; gradable_prefix=0
milestone_m3=""; milestone_m4=""
for n in $RUNGS; do
    [ "$n" -gt "$TOT" ] && continue
    tried=$((tried+1)); r3="-"; r4="-"
    case "$MODES" in both|m3) r3="$(rung "$n" m3)";; esac
    case "$MODES" in both|m4) r4="$(rung "$n" m4)";; esac
    case "$r3" in PASS|⭐*) pass3=$((pass3+1)); [ "$n" != "$TOT" ] && gradable_prefix=$((gradable_prefix+1));;
                  -) ;; ORACLE-*) ;;
                  *) violations=$((violations+1)); [ "$n" != "$TOT" ] && gradable_prefix=$((gradable_prefix+1)); [ -z "$first_red_m3" ] && first_red_m3="$n";; esac
    case "$r4" in PASS|⭐*) pass4=$((pass4+1)); [ "$n" != "$TOT" ] && gradable_prefix=$((gradable_prefix+1));;
                  -) ;; ORACLE-*) ;;
                  *) violations=$((violations+1)); [ "$n" != "$TOT" ] && gradable_prefix=$((gradable_prefix+1)); [ -z "$first_red_m4" ] && first_red_m4="$n";; esac
    [ "$n" = "$TOT" ] && { milestone_m3="$r3"; milestone_m4="$r4"; }
    printf "%8s  %-24s %-24s\n" "$n" "$r3" "$r4"
done
echo "------------------------------------------------------------"
echo "M3 rungs green: $pass3/$tried   first red at: ${first_red_m3:-none}"
echo "M4 rungs green: $pass4/$tried   first red at: ${first_red_m4:-none}"
# ---------------------------------------------------------------- optional: bisect to the EXACT first failing line
if [ "$BISECT" = 1 ] && [ -n "$first_red_m3" ]; then
    lo=1; hi="$first_red_m3"
    for r in $RUNGS; do [ "$r" -lt "$hi" ] && lo="$r"; done
    echo "--- bisecting m3 between $lo (green) and $hi (red) for the EXACT first failing line ---"
    while [ $((hi-lo)) -gt 1 ]; do
        mid=$(( (lo+hi)/2 )); v="$(rung "$mid" m3)"
        echo "    $mid -> $v"
        case "$v" in PASS|⭐*) lo=$mid;; *) hi=$mid;; esac
    done
    echo "⭐ M3 FIRST FAILING LINE = $hi"
    echo "    the line itself:"; sed -n "${hi}p" "$SRC" | head -c 200; echo
fi
echo "⛔ A red rung is never denied (law 0d).  Each distinct red CLASS above is an independently dispatchable row."
# ---------------------------------------------------------------- V2-5 aggregate verdict: 0 CLEAN / 1 VIOLATION / 2 UNPROVEN, never conflated
# If EVERY prefix rung came back ORACLE-REFUSED, the ladder proved nothing (zero-examined looks identical to
# all-clean unless refused outright) -- this is the exact defect class lib_gate.sh's gate_floor exists to catch,
# now applied to an oracle-refusal count instead of a missing-file count.
gate_floor "$gradable_prefix" 1 "gradable prefix rungs (oracle answered rather than refused, beauty_classic.sno vs $SBL)"
if [ "$MODES" = both ] || [ "$MODES" = m3 ]; then [ "$milestone_m3" = "⭐M1-FIXED-POINT" ] || violations=$((violations+1)); fi
if [ "$MODES" = both ] || [ "$MODES" = m4 ]; then [ "$milestone_m4" = "⭐M1-FIXED-POINT" ] || violations=$((violations+1)); fi
gate_verdict "$violations" "rungs failed (MILESTONE-1-not-fixed-point counts here too; ORACLE-REFUSED rungs do not, they are UNPROVEN not VIOLATION)"
