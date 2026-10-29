#!/usr/bin/env bash
# test_gate_sno_a_capture_into_an_element_binds_its_name_before_the_match_as_spitbol_does.sh -- a pattern capture whose target is an
# array or table element (. A[2], $ A[3], . T['k']), or a cursor capture into an element or an indirection (@A[1], @$N), answers as
# sbl -bf does in both modes (row snobol4-a-cursor-capture-whose-target-is-not-a-plain-variable-fatals-the-whole-program-at-compile).
# SPITBOL evaluates the target's NAME when the pattern is built; SCRIP refused every such statement at compile (FATAL lower_snobol4,
# GZ#5 subset). The cure (lower_snobol4.c sno_capt_elem_rewrite): before the match the statement assigns each element target's NAME to a
# hidden SN4$CAPN<k> and the capture reads it back as the deferred indirect *$SN4$CAPN<k>, a road both modes already take. A STORED
# pattern with an element target (P = 'y' . A[2]) keeps its name in the pattern's own snap vector, not a statement temporary: that half is
# test_gate_sno_a_stored_pattern_capture_into_an_element_binds_its_name_at_construction_as_spitbol_does.sh.
# THE WITNESSES are two master entries, extracted from corpus/tests/snobol4: arbno_break_len_replace_branch_1 (origin
# capture_into_an_element_target: cond, imm, table, both cursor forms, a subscript read before @I moves I, an unmatched pattern, an
# out-of-range subscript, ARBNO and an alternation) and len_array_capture_replace_1 (origin gimpel's gim_cassign_array_elt_loud,
# S LEN(1) . A[I] =). Each is graded in mode 3 and mode 4 against the ref sbl -bf prints, CUT FROM THE ORACLE at run time, with the
# grader's conventions (SNO_LIB, SCRIP_SNO_STMTKW=1, --stlimit).
# FAIL_ONCE (2026-10-17, SCRIP eb755e98c, the tree before the cure): RED 4 of 4 -- both witnesses FATAL at compile in both modes.
# rc 0 every arm equals the oracle / 1 an arm diverged / 2 could not measure (no scrip, runtime, oracle, corpus entry, or the oracle
# printed nothing).
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
for e in arbno_break_len_replace_branch_1 len_array_capture_replace_1; do
    python3 "$HERE/corpus_suite_harness.py" extract "$M/ALL.sno" "$M/ALL.ref" "$e" "$T/$e.sno" --out-ref "$T/$e.mref" --out-in "$T/$e.in" > /dev/null 2>&1 \
        || { echo "⛔ GATE REFUSE(2) [$G]: cannot extract $e from the SNOBOL4 master"; exit 2; }
    [ -f "$T/$e.in" ] || : > "$T/$e.in"
    ( cd "$T" && timeout -k 5 20s "$SBL" -bf "$e.sno" < "$e.in" > "$e.ref" 2> /dev/null )
    [ -s "$T/$e.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: the oracle printed nothing for $e"; exit 2; }
    ( cd "$T" && timeout -k 5 20s "$SCRIP" --stlimit "$e.sno" < "$e.in" > "$e.m3" 2> "$e.e3" )
    if ( cd "$T" && "$SCRIP" --stlimit --compile --out="$e.s" "$e.sno" < /dev/null > "$e.c" 2>&1 && gcc "$e.s" -L"$LIBDIR" -lscrip_rt -lm -Wl,-rpath,"$LIBDIR" -o "$e.x" 2>> "$e.c" ); then
        ( cd "$T" && timeout -k 5 20s "./$e.x" < "$e.in" > "$e.m4" 2> "$e.e4" )
    else
        : > "$T/$e.m4"; echo "  $e: mode-4 compile or link failed: $(grep -m1 . "$T/$e.c" | cut -c1-160)"
    fi
    for m in m3 m4; do
        n=$((n+1))
        if cmp -s "$T/$e.$m" "$T/$e.ref"; then echo "  $e $m PASS ($(wc -l < "$T/$e.ref") lines)"
        else echo "  $e $m FAIL (first difference: $(diff "$T/$e.$m" "$T/$e.ref" | grep -m2 '^[<>]' | tr '\n' ' ' | cut -c1-160)$(grep -m1 -o 'FATAL[^.]*' "$T/$e.e3" 2>/dev/null | head -1 | sed 's/^/; /'))"; RC=1; red="$red $e.$m"; fi
    done
done
if [ "$RC" = 0 ]; then echo "✅ GATE PASS(0) [$G]: a capture into an element binds its name before the match as sbl -bf does -- $n of $n arms (2 witnesses x 2 modes)"
else echo "⛔ GATE FAIL(1) [$G]: diverged from sbl -bf:$red"; fi
echo "    tree: SCRIP=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)$(git -C "$ROOT" diff --quiet 2>/dev/null || echo -DIRTY) corpus=$(git -C "$S4E/corpus" rev-parse --short HEAD 2>/dev/null)  measured $(date -u +%Y-%m-%dT%H:%MZ)"
exit $RC
