#!/usr/bin/env bash
# test_gate_sno_a_stored_pattern_capture_into_an_element_binds_its_name_at_construction_as_spitbol_does.sh -- a pattern STORED in a variable whose
# capture target is an array or table element (P = 'y' . A[2], Q = BREAK('z') $ T['k'], C = @A[1] 'y', PAT[I] = LEN(1) . A[I]) answers as sbl -bf
# does in both modes, also when the collector moves the array between the capture and the end-of-match commit (row
# snobol4-a-stored-pattern-whose-capture-target-is-an-element-fatals-lower-snobol4-at-compile; the inline half is
# test_gate_sno_a_capture_into_an_element_binds_its_name_before_the_match_as_spitbol_does.sh).
# SPITBOL evaluates a capture target's NAME when the pattern is built, so a statement temporary cannot serve a stored pattern (the next
# construction would overwrite it). THE CURE (lower_snobol4.c sno_elem_pre, pattern_match.c rt_cap_assign_patv / rt_at_cursor_patv / the pump's
# element pair): the lowerer registers TT_NAME(target) as a pre argument, so SNO$MKPAT evaluates the NAME at construction into the pattern's own
# snap vector (an out-of-range subscript fails the statement); the $ and @ boxes read the slot through the pattern header and assign at once; the
# . box pushes TWO island entries -- the element sentinel with the span, then the address of the pattern's head cell and the slot -- and the
# commit pump reads the NAME through the LIVE head, so nothing that moves is held by the r12 CAS island (the cfo's review, hq_snobol4 2026-10-22).
# THE WITNESSES are three master entries of corpus/tests/snobol4: break_len_table_replace_branch_1 (origin capture_into_an_element_of_a_stored_pattern:
# . $ @ into an element, a table, the loop-built PAT[I], a name bound at construction and not at match, an out-of-range subscript) and
# user_function_arbno_any_replace_branch_1 (origin ..._across_collections: a conditional capture through a composed pattern, an alternation that
# fails, an ARBNO, and a deferred function that allocates 100 arrays between the capture and the commit) and user_function_arbno_fence_replace_branch_2
# (origin ..._inside_fence: the capture inside FENCE(p), a FENCE'd ARBNO, a nested FENCE and an ARBNO of FENCE, the commit after the fence's gamma, which
# the gamma law may pop -- the cfo's case, 2026-10-22). Each is graded in mode 3 and mode 4
# against the ref sbl -bf prints, CUT FROM THE ORACLE at run time, with the grader's conventions (SNO_LIB, SCRIP_SNO_STMTKW=1, --stlimit); the second
# is graded again under SCRIP_GC_STRESS=1 with SCRIP_GC_PLANT_FLIP=1 (every collection moves the live blocks and traps the stale copies).
# FAIL_ONCE=1 corrupts the oracle's cut ref (a line is appended) and requires every arm to read red -- the comparison is live, not a constant.
# FAIL_ONCE (2026-10-22): RED 12 of 12 on the corrupted refs. RED on the tree before the cure (SCRIP f0d1c392a, built in a scratch root with its
# harness sibling): both entries FATAL at compile in both modes, 4 of 4 -- "capture target in a runtime-built pattern is not a simple variable".
# rc 0 every arm equals the oracle / 1 an arm diverged / 2 could not measure (no scrip, runtime, oracle, corpus entry, or the oracle printed nothing).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -uo pipefail
G="$(basename "${BASH_SOURCE[0]}" .sh)"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S4E="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
ROOT="$S4E/SCRIP"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
LIBDIR="$ROOT/out"; [ -f "$LIBDIR/libscrip_rt.so" ] || { echo "⛔ GATE REFUSE(2) [$G]: no libscrip_rt.so in $LIBDIR"; exit 2; }
SBL="${SBL_BIN:-/home/resources/x64/bin/sbl}"; [ -x "$SBL" ] || { echo "⛔ GATE REFUSE(2) [$G]: no sbl at $SBL -- the ref is cut from the oracle at run time"; exit 2; }
M="$S4E/corpus/tests/snobol4"; [ -f "$M/ALL.sno" ] || { echo "⛔ GATE REFUSE(2) [$G]: no SNOBOL4 master at $M"; exit 2; }
export SNO_LIB="$S4E/corpus/include" SCRIP_SNO_STMTKW=1
T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; n=0; red=""
arm() {
    n=$((n+1)); local label="$1" got="$2" want="$3"
    if cmp -s "$got" "$want"; then
        if [ "${FAIL_ONCE:-0}" = 1 ]; then echo "  $label PASS (FAIL_ONCE: this arm should have read red)"; RC=1; red="$red $label"; else echo "  $label PASS ($(wc -l < "$want") lines)"; fi
    else
        if [ "${FAIL_ONCE:-0}" = 1 ]; then echo "  $label RED as the corrupted ref requires"
        else echo "  $label FAIL (first difference: $(diff "$got" "$want" | grep -m2 '^[<>]' | tr '\n' ' ' | cut -c1-160))"; RC=1; red="$red $label"; fi
    fi
}
for e in break_len_table_replace_branch_1 user_function_arbno_any_replace_branch_1 user_function_arbno_fence_replace_branch_2; do
    python3 "$HERE/corpus_suite_harness.py" extract "$M/ALL.sno" "$M/ALL.ref" "$e" "$T/$e.sno" --out-ref "$T/$e.mref" --out-in "$T/$e.in" > /dev/null 2>&1 \
        || { echo "⛔ GATE REFUSE(2) [$G]: cannot extract $e from the SNOBOL4 master"; exit 2; }
    [ -f "$T/$e.in" ] || : > "$T/$e.in"
    ( cd "$T" && timeout -k 5 20s "$SBL" -bf "$e.sno" < "$e.in" > "$e.ref" 2> /dev/null )
    [ -s "$T/$e.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for $e"; exit 2; }
    [ "${FAIL_ONCE:-0}" = 1 ] && echo "corrupted" >> "$T/$e.ref"
    ( cd "$T" && timeout -k 5 20s "$SCRIP" --stlimit "$e.sno" < "$e.in" > "$e.m3" 2> "$e.e3" )
    if ( cd "$T" && "$SCRIP" --stlimit --compile --out="$e.s" "$e.sno" < /dev/null > "$e.c" 2>&1 && gcc "$e.s" -L"$LIBDIR" -lscrip_rt -lm -Wl,-rpath,"$LIBDIR" -o "$e.x" 2>> "$e.c" ); then
        ( cd "$T" && timeout -k 5 20s "./$e.x" < "$e.in" > "$e.m4" 2> "$e.e4" )
        ( cd "$T" && SCRIP_GC_EXERCISE=1 SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_FLIP=1 timeout -k 5 60s "./$e.x" < "$e.in" > "$e.m4s" 2> "$e.e4s" )
    else
        : > "$T/$e.m4"; : > "$T/$e.m4s"; echo "  $e: mode-4 compile or link failed: $(grep -m1 . "$T/$e.c" | cut -c1-160)"
    fi
    ( cd "$T" && SCRIP_GC_EXERCISE=1 SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_FLIP=1 timeout -k 5 60s "$SCRIP" --stlimit "$e.sno" < "$e.in" > "$e.m3s" 2> "$e.e3s" )
    for m in e3s e4s; do
        c=$(grep -o 'collections=[0-9]*' "$T/$e.$m" | head -1 | cut -d= -f2)
        [ "${c:-0}" -gt 0 ] || { echo "⛔ GATE REFUSE(2) [$G]: the stress arm of $e ($m) collected nothing (collections=${c:-absent}) -- a stress arm that never collects proves nothing"; exit 2; }
    done
    arm "$e m3" "$T/$e.m3" "$T/$e.ref"
    arm "$e m4" "$T/$e.m4" "$T/$e.ref"
    arm "$e m3 stress+flip" "$T/$e.m3s" "$T/$e.ref"
    arm "$e m4 stress+flip" "$T/$e.m4s" "$T/$e.ref"
done
if [ "${FAIL_ONCE:-0}" = 1 ]; then
    if [ "$RC" = 0 ]; then echo "⛔ GATE FAIL_ONCE(1) [$G]: every arm read RED on the corrupted ref, as required -- the comparison is live ($n of $n arms)"; RC=1
    else echo "⛔ GATE FAIL_ONCE(2) [$G]: an arm did not read red on the corrupted ref:$red"; RC=2; fi
elif [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: a stored pattern's capture into an element binds its name at construction as sbl -bf does, across collections that move the array -- $n of $n arms (3 witnesses x 2 modes x plain and stress+flip)"
else echo "⛔ GATE FAIL(1) [$G]: diverged from sbl -bf:$red"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY) corpus=$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
