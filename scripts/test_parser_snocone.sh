#!/usr/bin/env bash
# test_parser_snocone.sh — smoke test for parser_snocone.sc (PST-SC-SC-5)
# Runs each .sc fixture through the SCRIP parser and diffs against .ref
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet 4.6  DATE: 2026-05-19
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"   # ⭐ was "$HERE/scrip" (../harness/scripts/scrip, a dead symlink to a nonexistent /home/claude/one4all/scrip) -- every other caller in this tree uses ../scrip; the binary lives at the SCRIP root, not inside ../harness/scripts/
SD="${SD:-$S4E/SCRIP/bootstrap}"

if [ ! -f "$SCRIP" ]; then echo "SKIP scrip not found: $SCRIP"; exit 0; fi

# ⭐ REPOINTED (dead-suite-path-consumer-sweep, seat06 2026-09-04): corpus/tests/snocone/parser-fixtures/
# no longer exists -- Lon's one-flat-suite ruling absorbed it into the Snocone rungs (ALL.sc/ALL.ref/
# ALL.csv) as the "parser" family, 67 entries (family=parser, kind=block, modes=ast), origin names
# parser__<old-name> preserving the old per-file names. Verified by direct extraction before wiring this
# in: parser__arith_add materializes to "x = 1 + 2;" / "(STMT :subj (TT_ASSIGN ...))" -- exactly the
# .sc-source-in / AST-dump-out shape this script already expects, not a different population wearing the
# same name. Materialize into an ephemeral scratch dir (mktemp + EXIT trap, same discipline as this row's
# other extraction fixes) rather than a persistent one -- this script runs standalone/rarely, not
# repeatedly in one board session, so there is nothing to gain from reuse and a stale extraction across a
# corpus update is a worse failure mode than a few seconds of re-extraction.
if [ -n "${FIX:-}" ]; then
    [ -d "$FIX" ] || { echo "⛔ REFUSE(2): FIX override '$FIX' does not exist" >&2; exit 2; }
else
    # RUNGS_DIR/RUNGS_EXT must be set BEFORE sourcing -- lib_rungs_extract.sh reads them once at
    # source time into RUNGS_SNO/RUNGS_REF/RUNGS_CSV, not live on each call (learned the hard way:
    # setting them as a prefix on the rungs_extract_family call below silently extracted against the
    # SNOBOL4 rungs instead and produced an empty dir).
    RUNGS_DIR="$S4E/corpus/tests/snocone"
    RUNGS_EXT=.sc
    . "$HERE/lib_rungs_extract.sh"
    FIX=$(mktemp -d /tmp/parser_snocone_fix_XXXXXX) || { echo "⛔ REFUSE(2): mktemp failed" >&2; exit 2; }
    trap 'rm -rf "$FIX"' EXIT
    rungs_extract_family parser "$FIX" \
        || { echo "⛔ REFUSE(2): extracting the 'parser' family from the Snocone rungs failed" >&2; exit 2; }
    [ -n "$(ls -A "$FIX" 2>/dev/null)" ] || { echo "⛔ REFUSE(2): extraction produced an empty directory -- the 'parser' family may have been renamed again" >&2; exit 2; }
fi

PASS=0; FAIL=0; EMPTY=0
for sc in "$FIX"/*.sc; do
    base="${sc%.sc}"
    ref="${base}.ref"
    [ -f "$ref" ] || continue
    name="$(basename "$base")"
    got=$(timeout -k 5 8 "$SCRIP" --run \
        "$SD/global.sc" "$SD/case.sc" "$SD/assign.sc" "$SD/match.sc" \
        "$SD/counter.sc" "$SD/stack.sc" "$SD/tree.sc" "$SD/ShiftReduce.sc" \
        "$SD/tdump.sc" "$SD/gen.sc" "$SD/qize.sc" "$SD/semantic.sc" \
        "$SD/omega.sc" "$SD/trace.sc" \
        "$SD/parser_snocone.sc" < "$sc" 2>/dev/null)
    exp=$(cat "$ref")
    if [ "$got" = "$exp" ]; then
        PASS=$((PASS+1))
    else
        FAIL=$((FAIL+1))
        [ -z "$got" ] && EMPTY=$((EMPTY+1))
        echo "  FAIL $name"
        echo "    exp: $(echo "$exp" | head -1)"
        echo "    got: $(echo "$got" | head -1)"
    fi
done
echo ""
# ⛔⭐ ASSERT NON-TRIVIAL BEFORE TRUSTING THE VERDICT (same Law-4 principle as the sr1-lower-gate row this
# sitting also handled): checked live, not assumed from memory. If literally every failure got EMPTY
# output, this is not $FAIL independent parser defects, it is one shared mechanism failing identically --
# characterized this session (seat06 2026-09-04): `scrip --run` with N positional source files only
# honors the FIRST one (confirmed by swapping file order: global.sc-first dumps exactly global.sc's own
# 56 statements and parser_snocone.sc's content, including its driver, never appears; reversed, the
# opposite happens), so parser_snocone.sc (last in this script's 15-file list) and its driver never run.
# grepping ../harness/scripts/*.sh found ZERO other callers relying on this multi-file-positional pattern -- not a
# tree-wide regression, just this one script's assumption, apparently never actually exercised end-to-end.
# Whether the real fix is an INCLUDE-based single-file composition or a scrip driver change is its own
# investigation, out of this row's scope (same treatment as test_emit_diff_invariant_check.sh elsewhere
# in this row) -- REFUSE with the diagnosis rather than print a false per-fixture board.
if [ "$FAIL" -gt 0 ] && [ "$EMPTY" -eq "$FAIL" ]; then
    echo "⛔ GATE REFUSES: all $FAIL failures got EMPTY output -- one shared invocation failure, not $FAIL" >&2
    echo "   independent parser defects. scrip --run only honors the FIRST of N positional source files;" >&2
    echo "   parser_snocone.sc (last in this script's own 15-file list) and its driver never run. FIX path" >&2
    echo "   is repaired and verified (67 'parser' family fixtures extract correctly); the invocation" >&2
    echo "   itself needs its own investigation, not attempted here. See this script's own comment just" >&2
    echo "   above this check for the swap-order proof." >&2
    exit 2
fi
echo "PASS=$PASS FAIL=$FAIL"
