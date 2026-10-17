#!/usr/bin/env bash
# ../harness/scripts/test_gate_term_wordref_ratchet.sh — MASTER-PLAN.md ladder I, rung I5 (minted hq_C 2026-09-01, landed hq_B 2026-09-02).
# Since 2026-09-02 it also carries rung 13 clause 2 of ARCH-PROLOG-BYRD-BOX-TRANSLATION.md (no resolve_choice in resolution.{c,h}) -- see RC_HITS below.
#
# WHAT IT GATES.  The T slices are migrating Prolog off the `Term *` tree representation onto cells
# (pl_cell / pl_cell_conv).  Each T slice's DONE-WHEN prints the umbrella total, but between two landings
# NOTHING stopped the count from rising again — a migration with no ratchet is a migration that can be
# silently undone one merge at a time.  This gate closes that seam: PER FILE, the count only goes down.
#
# ⭐ WHY A RATCHET IS LEGITIMATE HERE, WHEN test_gate_rbp_census_ratchet.sh RETIRED ITS OWN.
# That gate retired because it counted a property that could never reach zero (a pinned frame's [rbp+N]
# refs are the design working as intended), so it "fired on progress".  Read its FLATDISP-9 header before
# copying this shape anywhere else — the question it forces is: CAN THIS COUNT REACH ZERO BY DESIGN?
# Here it can and is meant to: `Term` is a representation the ladder exists to DELETE, so every remaining
# reference is debt, and 0 is the intended terminal value.  That is the whole difference, and it is the
# only thing that makes a ratchet honest rather than a tripwire on legitimate work.
#
# THE COUNTING METHOD IS NOT A CHOICE — IT IS REPRODUCED FROM THE CENSUS THE ROW WAS MINTED AGAINST.
# The row pinned "the 490 census at SCRIP bcb0ec1e".  Occurrence-counting (`grep -ow`) gives 653 there and
# reproduces NONE of the row's per-file numbers.  MATCHING-LINE counting reproduces all 16 of them exactly
# (unification.c 208 · prolog_parse.c 85 · rt_runtime.c 38 · prolog_lower.c 26 · prolog_builtin.c 24 ·
# prolog_atom.c 17 · resolution.h 12 · term.h 11 · prolog_unify_test.c 10 · pl_cell_conv_test.c 10 ·
# pl_cell_conv.h 10 · prolog_builtin.h 9 · by_name_dispatch.c 8 · prolog_unify.c 6 · resolution.c 4 ·
# prolog_runtime.h 3) and totals 490 over src/ once `*.bak` is excluded.  So: METHOD = `grep -cw Term`,
# SCOPE = src/**, EXCLUDING *.bak.  Verify with the ONE_LINER at the foot of this file; never retype a pin.
# ⛔ A line with two `Term`s counts ONCE.  That is the census's definition, not an approximation of it —
# changing to occurrences would silently re-scale every pin by ~1.33x and invalidate the whole ladder.
#
# ⛔ THE PINS BELOW ARE **NOT** THE ROW'S 490 NUMBERS, DELIBERATELY.  Between the mint (bcb0ec1e) and this
# landing (c6190d9e) the T slices drove the census 490 -> 136: prolog_parse.c 85->0, prolog_lower.c 26->0,
# unification.c 208->56, and prolog_builtin.{c,h} / prolog_unify_test.c / pl_cell_conv_test.c were DELETED
# outright.  Pinning at the row's stale figures would have shipped a gate with 354 refs of slack — green
# while the migration regressed by a factor of three.  The row's own doctrine is "pin-the-property: the
# count only goes down", and "pins are LOWERED in the landing commit of every T slice"; this landing IS
# such a commit, so the pins are the MEASURED census at HEAD.  Routed to hq_C as a FINDING.
#
# ⭐⭐ RE-PIN HISTORY — AND THE FIRST ONE HAPPENED BEFORE THIS GATE HAD EVEN LANDED, WHICH IS THE POINT.
#   490 (bcb0ec1e, the row's mint)  ->  136 (c6190d9e, first pin)  ->  94 (d85035e5, landed pin).
# T9 milestone 7 (8412a1ca) and its follow-up regression fix (be11af20) landed DURING the session that
# wrote this gate.  Neither seat erred; a pin keyed on a tree that other seats are actively lowering is
# stale on arrival BY CONSTRUCTION -- see A CRITERION NEVER PINS A POPULATION COUNT in .github/GOAL-TEST-SUITE-CONSISTENCY.md.
# ⛔ So do not read a stale pin here as a discipline failure, and NEVER 'fix' a TIGHTEN by pinning higher
# than measured — re-measure with the ONE_LINER and lower it.  Slack is the only failure mode that matters
# in a ratchet: a pin above the tree is a gate that is green while the migration walks backwards.
#
# ⭐ THE METHOD IS CROSS-CHECKED AGAINST THE LADDER, NOT JUST AGAINST ITSELF.  8412a1ca's own message
# reports '136 -> 111'; this gate's method measures exactly 111 at that commit, and 94 after be11af20.
# So the slice author and this gate count the SAME THING — worth re-checking whenever a T slice's stated
# delta and this gate's umbrella total disagree, because that disagreement would mean the ladder and its
# ratchet had quietly forked on the definition, and the gate would be measuring a property nobody targets.
#
# ⛔ UNPINNED FILE WITH ANY `Term` REF == FAIL.  Without this the ratchet is trivially dodged by moving a
# refactor into a new file, which is exactly the motion a migration produces.  A new file is not a fresh
# budget; add it below with its measured count ONLY if it is genuinely a step down elsewhere.
#
# HOW TO RE-PIN (manual, never automatic — several seats share this file; RULES.md CONCURRENCY note).
# Run the ONE_LINER, paste the measured table into PINS, and land it IN THE SAME COMMIT as the slice that
# lowered it.  A TIGHTEN hint below is the gate telling you the tree is already better than its pin.
GATE_NAME="test_gate_term_wordref_ratchet"
. "$(dirname "$0")/lib_gate.sh"
gate_parse_args "$@"
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: siblings resolve under THIS root.
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)/src"
# ⛔ THE ROW'S OWN REFUSAL CLAUSE: no parsers dir == nothing to measure == UNPROVEN(2), never a pass.
if [ ! -d "$SRC/parsers/prolog" ]; then
    echo "GATE UNPROVEN(2) [$GATE_NAME]: src/parsers/prolog is absent at $SRC/parsers/prolog"
    echo "    This is NOT a pass.  The Prolog frontend is what the Term census measures; without it the gate examined nothing."
    gate_stamp
    exit 2
fi
# ── PINS ── measured at SCRIP d85035e5 (`grep -cw Term`, src/**, excluding *.bak).  Umbrella total 94.
# ⛔ EDIT ONLY DOWNWARD, and only in the same commit as the slice that earned it.
PINS="
17 src/parsers/prolog/prolog_atom.c
14 src/runtime/unification.c
13 src/runtime/rt_runtime.c
11 src/runtime/builtins/resolution.h
11 src/parsers/prolog/term.h
10 src/parsers/prolog/pl_cell_conv.h
 4 src/parsers/prolog/prolog_unify.c
 3 src/runtime/by_name_dispatch.c
 3 src/runtime/builtins/resolution.c
 3 src/parsers/prolog/prolog_parse.h
 2 src/parsers/prolog/prolog_runtime.h
 2 src/driver/sync_monitor.c
 1 src/runtime/rt/rt.h
"
PIN_TOTAL=$(echo "$PINS" | awk 'NF{t+=$1} END{print t+0}')
# ⭐ PROLOG SOURCE IS NOT THE C REPRESENTATION (cfo 2026-10-10, CEO-1473's vendored libraries): src/parsers/prolog/prelude/*.pl
# are swipl's own library files, where Term is a Prolog VARIABLE NAME (library(aggregate) 43 lines, (error) 16), and
# src/parsers/prolog/prolog_prelude_libs.inc is that same Prolog text embedded as C strings by util_gen_prolog_prelude_libs.py.
# Neither is the C `Term *` this ladder deletes, so *.pl and that generated table are outside the scope; at the mint every
# counted file was C (the 16 above), so the census the pins reproduce is unchanged.
# ⚠️ *.bak is excluded because that is what reproduces the row's 490 (prolog_emit_jvm.c.bak carried 17 there).
# It matches nothing at this tree, but a .bak must never become a place to PARK Term code, so it is reported loudly.
BAK_HITS=$(find "$SRC" -name '*.bak' -exec grep -cw 'Term' {} + 2>/dev/null | awk -F: '{t+=$NF} END{print t+0}')
# ⭐ WORKTREE SWEEP, NOT `git grep`: a plain `git grep` misses an UNTRACKED new file, which is precisely the
# dodge the unpinned-file rule above exists to catch.  Verified equal (136) to the tracked sweep on a clean tree.
FILES=$(grep -rIlw 'Term' "$SRC" 2>/dev/null | grep -v '\.bak$' | grep -v '\.pl$' | grep -v '/prolog_prelude_libs\.inc$' | sed "s#^$SRC/#src/#" | sort)
NFILES=$(echo "$FILES" | grep -c . )
# ⭐⭐ THE FINISH LINE (Lon 2026-09-02 10:35, in-chat to ceo: "First order of business is to simply remove the definition of the struct named Term. Delete it now."):
# a ratchet that could only REFUSE at zero could never say YES to its own goal (the criterion-that-cannot-say-YES defect, INSTRUMENT LAWS).
# Zero files bearing the word is the census COMPLETE, not "nothing examined": the parsers dir exists (checked above), the sweep ran, it found none.
# ⭐ RUNG 13, CLAUSE 2 (ARCH-PROLOG-BYRD-BOX-TRANSLATION.md § E: "resolution.{c,h} hold no resolve_choice"; hq_B 2026-09-02). The second
# choice-point/trail/env machine left resolution.{c,h} with ceo's Term deletion; a `resolve_choice` word-ref returning is that machine
# returning under the old name. Checked BEFORE the zero-Term finish line so the ratchet cannot say YES to rung 13 on the Term half alone.
# Absent files read 0 -- rung 2 deletes them, and a deleted file cannot carry the machine.
RC_HITS=0
for f in "$SRC/runtime/builtins/resolution.c" "$SRC/runtime/builtins/resolution.h"; do
    [ -f "$f" ] && RC_HITS=$((RC_HITS + $(grep -cw 'resolve_choice' "$f")))
done
if [ "$RC_HITS" -ne 0 ]; then
    echo "  ⛔ $RC_HITS resolve_choice word-ref(s) in src/runtime/builtins/resolution.{c,h} -- the second choice-point machine is back (rung 13 clause 2)"
    GATE_EXAMINED="resolution.{c,h}"
    gate_verdict 1 "resolve_choice word-ref(s) in resolution.{c,h} (rung 13 clause 2; Term census not reached)"
fi
if [ "$NFILES" -eq 0 ]; then
    echo "✅ GATE OK [$GATE_NAME]: 0 Term word-refs in 0 source files under src/ -- the ratchet reached ZERO (pin total was $PIN_TOTAL; term.h and pl_cell_conv.h are gone). A future file that reintroduces the word fails the unpinned-file rule below."
    exit 0
fi
gate_floor "$NFILES" 1 "source files bearing a Term word-reference"
VIOL=0; TOTAL=0; TIGHTEN=""
echo "── per-file Term word-refs (method: grep -cw Term · scope src/** · excluding *.bak) ──"
for f in $FILES; do
    n=$(grep -cw 'Term' "$SRC/${f#src/}")
    TOTAL=$((TOTAL + n))
    pin=$(echo "$PINS" | awk -v p="$f" 'NF && $2==p {print $1; found=1} END{if(!found) print "UNPINNED"}')
    if [ "$pin" = "UNPINNED" ]; then
        printf '  ⛔ %6d  (unpinned)  %s\n' "$n" "$f"
        echo "        A file carrying Term refs with no pin is a RISE from an implicit 0 — see the unpinned-file rule in this file's header."
        VIOL=$((VIOL + 1))
    elif [ "$n" -gt "$pin" ]; then
        printf '  ⛔ %6d  > pin %-6d %s   ROSE by %d\n' "$n" "$pin" "$f" "$((n - pin))"
        VIOL=$((VIOL + 1))
    elif [ "$n" -lt "$pin" ]; then
        printf '  ⭐ %6d  < pin %-6d %s   TIGHTEN by %d\n' "$n" "$pin" "$f" "$((pin - n))"
        TIGHTEN="$TIGHTEN $f:$pin->$n"
    else
        printf '     %6d  = pin %-6d %s\n' "$n" "$pin" "$f"
    fi
done
# ⭐ A PINNED FILE THAT VANISHED IS PROGRESS, AND IT MUST STILL BE REPORTED — otherwise the pin lingers
# forever as dead slack that a later file of the same name would silently inherit.
while read -r pin f; do
    [ -z "$f" ] && continue
    [ -e "$SRC/${f#src/}" ] && continue
    printf '  ⭐ %6d  < pin %-6d %s   FILE GONE — drop this pin\n' 0 "$pin" "$f"
    TIGHTEN="$TIGHTEN $f:$pin->GONE"
done <<< "$(echo "$PINS" | awk 'NF')"
echo "── umbrella total: $TOTAL Term word-refs across $NFILES files (pin total $PIN_TOTAL · row's mint census was 490 at bcb0ec1e) ──"
[ "$BAK_HITS" -gt 0 ] && echo "  ⚠️  $BAK_HITS Term ref(s) sit in *.bak files, EXCLUDED from this count by the census definition — do not park Term code there."
if [ -n "$TIGHTEN" ]; then
    echo "  ⭐ TIGHTEN AVAILABLE (the tree is better than its pins — lower them in the commit that earned it):"
    for t in $TIGHTEN; do echo "        $t"; done
fi
# ONE_LINER — regenerate the PINS block; never retype a number you did not produce (RULES.md § TRANSCRIPTION).
#   cd "$S4E/SCRIP" && for f in $(grep -rIlw Term src/ | grep -v '\.bak$' | sort); do echo "$(grep -cw Term $f) $f"; done | sort -rn
gate_verdict "$VIOL" "file(s) ROSE above their Term word-ref pin (or carry refs with no pin)"
