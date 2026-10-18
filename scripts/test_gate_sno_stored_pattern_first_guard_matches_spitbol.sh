#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_sno_stored_pattern_first_guard_matches_spitbol.sh -- A STORED PATTERN'S FIRST-CHARACTER GUARD NEVER CHANGES WHAT THE
# MATCH DOES (ceo 2026-09-29, SCRIP bb51520b1, 5955a2e73 and the cure landed beside this gate; GOAL-SNOCONE-100 cursors 29n-29p).
#
# A PAT$n thunk whose FIRST set the compiler can name fails at its entry, or succeeds with the empty match, when the cursor's
# character cannot start it -- through *X by the pattern the program binds to X, the binding re-checked from X's cell at run time.
# The guard is only a shortcut: the three witnesses below, each cut from /home/resources/x64/bin/sbl -bf into its .ref, must print
# SPITBOL's output in mode 3 and in mode 4. abort_and_bare_fence: a node whose failure edge reaches ABORT (a bare FENCE is lowered
# as its successor's omega -> ABORT) turns a local failure into a whole-match failure, so the guard must stand down -- measured RED at
# 5955a2e73 (cases 1, 2, 3, 5 printed "matched" where SPITBOL fails), GREEN after the cure; twelve_shapes: a nullable immediate
# capture, POS alternatives, NOTANY, a deferred ref before and after the first consumer, a nullable alternation, FENCE, the subject
# end, &ANCHOR, a NUL subject character; bound_and_reassigned: white, White, Gray and $' ' reassigned mid-program (every guard
# stands down) and the empty-success path; alternations: the alternation-level guard (an alternation whose every arm has a known
# first character fails at its entry when none can start) inside ARBNO, under &ANCHOR, after a capture, beside a NUL subject byte.
# Exit 0 = all eight runs match; 1 = a divergence; 2 = cannot measure.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; G="$(basename "${BASH_SOURCE[0]}" .sh)"
SCRIP="${SCRIP_BIN:-$ROOT/scrip}"; [ -x "$SCRIP" ] || { echo "⛔ GATE REFUSE(2) [$G]: no scrip at $SCRIP"; exit 2; }
FX="$HERE/fixtures/sno_first_guard"; T=$(mktemp -d) || exit 2; trap 'rm -rf "$T"' EXIT
RC=0; N=0
for w in abort_and_bare_fence twelve_shapes bound_and_reassigned alternations; do
    [ -f "$FX/$w.sno" ] && [ -f "$FX/$w.ref" ] || { echo "⛔ GATE REFUSE(2) [$G]: missing fixture $FX/$w.{sno,ref}"; exit 2; }
    timeout -k 5 20 "$SCRIP" "$FX/$w.sno" < /dev/null > "$T/$w.m3" 2>&1
    if timeout -k 5 20 "$SCRIP" --compile -o "$T/$w.s" "$FX/$w.sno" < /dev/null > /dev/null 2>&1 && gcc -m64 -no-pie "$T/$w.s" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$T/$w.bin" 2>/dev/null
    then timeout -k 5 20 "$T/$w.bin" < /dev/null > "$T/$w.m4" 2>&1; else echo "<mode-4 build failed>" > "$T/$w.m4"; fi
    for m in m3 m4; do N=$((N + 1))
        if cmp -s "$FX/$w.ref" "$T/$w.$m"; then echo "  PASS $w $m"; else RC=1; echo "  FAIL $w $m: $(diff "$FX/$w.ref" "$T/$w.$m" | grep -m2 '^[<>]' | tr '\n' ' ' | cut -c1-160)"; fi; done
done
[ "$RC" = 0 ] && echo "GATE PASS(0) [$G]: $N of $N runs print SPITBOL's output" || echo "⛔ GATE FAIL(1) [$G]: a stored-pattern guard changed what a match does"
exit $RC
