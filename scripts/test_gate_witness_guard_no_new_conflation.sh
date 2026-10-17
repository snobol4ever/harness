#!/bin/bash
# test_gate_witness_guard_no_new_conflation.sh -- RATCHET on a witness idiom that cannot report its own failure.
#
# THE DEFECT, PROVEN AGAINST THE ORACLE (sbl -bf), NOT INFERRED FROM READING:
#   NE(f(x), K)   :f(L)
# takes branch L in TWO different worlds -- (a) the predicate correctly failed because f(x) really is K, and
# (b) the CALL f(x) failed, so no comparison ever happened. A minimal witness (two arms, one FRETURN) prints
# "A took :f" and "B took :f" under SPITBOL itself: the branch is identical. So a witness written this way
# CANNOT DISTINGUISH A CORRECT ANSWER FROM A BROKEN CALL, and marches on to print its own PASS line.
#
# ⭐ MEASURED INSTANCE, and the reason this gate exists: corpus/tests/snobol4/crosscheck/rung10.sno case 1
# printed "PASS 1010_func_recursion (4/4)" in mode 4 while facto(4) -- its OPSYN alias check -- was silently
# failing as a call. The board was green over a wrong answer. Found via seat11's row conform-unload-noop, whose
# fix turned the silent failure loud and so LOOKED like it caused a regression it merely exposed.
#
# ⛔ THIS IS A RATCHET, NOT A CURE. Not every site is a bug -- where the callee provably cannot fail, the idiom is
# harmless, and mass-rewriting 70+ witnesses to satisfy a gate would be churn with its own regression risk. What
# must not happen is the count GROWING: every new one is a fresh place the board can lie. Lower the baseline when
# you genuinely fix sites; never raise it to make this pass.
# ⭐ THE FIX SHAPE, where a site is real: bind first, then compare --
#     v = f(x)      :f(callfailed)
#     NE(v, K)      :f(L)
# which separates "the call broke" from "the values matched".
set -u
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CORPUS="${WITNESS_CORPUS:-$S4E/corpus/tests/snobol4}"
BASELINE="${WITNESS_GUARD_BASELINE:-71}"

[ -d "$CORPUS" ] || { echo "⛔ REFUSES rc=2: witness corpus not found at $CORPUS"; exit 2; }
command -v grep >/dev/null || { echo "⛔ REFUSES rc=2: no grep"; exit 2; }

# The conflating shape: a predicate whose FIRST argument is a function call, guarded by :f(...).
PAT='^[[:space:]]+(NE|EQ|DIFFER|IDENT|LT|GT|LE|GE)\([a-zA-Z_][a-zA-Z0-9_]*\(.*\)[[:space:]]*:f\('
N=$(grep -rhE "$PAT" --include='*.sno' "$CORPUS" 2>/dev/null | wc -l)
FILES=$(grep -rlE "$PAT" --include='*.sno' "$CORPUS" 2>/dev/null | wc -l)

# A pattern that silently stops matching reads as a clean board -- the exact disease this gate is about.
if [ "$N" -eq 0 ] && [ "$BASELINE" -gt 0 ]; then
    echo "⛔ REFUSES rc=2: zero matches against a baseline of $BASELINE. Either every site was genuinely fixed"
    echo "   (then lower WITNESS_GUARD_BASELINE to 0 deliberately) or the pattern/corpus moved and this gate has"
    echo "   gone vacuous. A gate that matches nothing is not a green gate."
    exit 2
fi

echo "witness guard conflation ratchet -- recomputed live, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "corpus: $CORPUS"
echo "conflating guard sites: $N across $FILES file(s)   baseline: $BASELINE"
if [ "$N" -gt "$BASELINE" ]; then
    echo "⛔ GATE FAILED -- $((N - BASELINE)) NEW conflating guard(s) since the baseline. Offending files:"
    grep -rlE "$PAT" --include='*.sno' "$CORPUS" 2>/dev/null | sed 's|^|     |'
    echo "   -> bind the call to a variable first, then compare (see header). Do NOT raise the baseline."
    exit 1
fi
[ "$N" -lt "$BASELINE" ] && echo "⭐ IMPROVED: $((BASELINE - N)) site(s) below baseline -- lower WITNESS_GUARD_BASELINE to $N and commit that."
echo "✅ GATE OK -- no new witness able to hide a failed call behind a correct-looking branch."
exit 0
