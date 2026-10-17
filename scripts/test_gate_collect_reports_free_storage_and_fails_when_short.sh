#!/usr/bin/env bash
# stale-binary preflight (same convention as every other gate here)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_collect_reports_free_storage_and_fails_when_short.sh
# (coo 2026-09-08, row snobol4-collect-returns-zero-and-collect-n-never-fails)
#
# WHAT THIS PINS, and why it is three arms and not a diff. COLLECT() had two defects that a
# byte-for-byte oracle diff CANNOT be used to pin, because the one number it returns is the
# reporting engine's own heap size: SPITBOL says 129483 here and we say 536870912, and both are
# right. So the invariant is the DECISION and the DATATYPE, which are semantics, not the count:
#
#   (1) COLLECT() returns a NONZERO integer.  It used to return 0 -- rt_gcheap_free() reports
#       g_hp_end - g_hp_top and the arena is allocated LAZILY, so a program whose first heap touch
#       IS the COLLECT call measured a heap that did not exist yet and got 0 - 0. The regression
#       this arm guards is subtle: it only appears when nothing has allocated yet, so a witness
#       that does any string work BEFORE the call cannot see it. This one deliberately calls
#       COLLECT() as its very first act.
#   (2) DATATYPE(COLLECT()) is INTEGER, on both engines. This was already right and is pinned so a
#       future cure of (1) cannot fix the number by returning a string.
#   (3) COLLECT(N) SUCCEEDS for a small N and FAILS for an unsatisfiable N. The argument used to be
#       discarded outright ((void)a), so every call succeeded whatever was asked. Programs branch on
#       COLLECT(N), so that was a control-flow divergence, and it is the arm that actually matters.
#
# EVERY ARM IS CHECKED AGAINST sbl -bf IN THE SAME RUN rather than against a recorded .ref, because a
# .ref is evidence about a past oracle run and arm (3) is exactly the kind of decision an oracle swap
# could legitimately change. The oracle comes from lib_oracle_flags.sh, never a hand-built path.
# ⛔ The RET NUMBERS are compared for nonzero-ness and never to each other -- see above.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP:-$HERE/../../SCRIP/scrip}"
RT_DIR="${RT_DIR:-$HERE/../../SCRIP/out}"
. "$HERE/lib_oracle_flags.sh"
SBL="$(sbl_correctness_bin)" || { echo "⛔ REFUSE(rc=2): no correctness oracle -- an ungraded run must never print a verdict"; exit 2; }
[ -x "$SBL" ] || { echo "⛔ REFUSE(rc=2): oracle not executable at $SBL"; exit 2; }
[ -x "$SCRIP" ] || { echo "⛔ REFUSE(rc=2): scrip not built at $SCRIP"; exit 2; }

W="$(mktemp -d)"; trap 'rm -rf "$W"' EXIT
# ⛔ BOTH ENGINES GET THE SAME SPELLING (f.sno, cwd in the scratch dir) -- the class the coo cured in
# test_snoflake_suite.sh the same day: &FILE is the pathname AS GIVEN, so a long path also risks
# SPITBOL's 119-column listing wrap eating a diagnostic.
printf '\tOUTPUT = "RET=" COLLECT()\n\tOUTPUT = "DT=" DATATYPE(COLLECT())\n\tCOLLECT(1000)\t\t\t:S(A)F(B)\nA\tOUTPUT = "SMALL=SUCCEEDED"\t:(C)\nB\tOUTPUT = "SMALL=FAILED"\nC\tCOLLECT(999999999999)\t\t:S(D)F(E)\nD\tOUTPUT = "BIG=SUCCEEDED"\t\t:(END)\nE\tOUTPUT = "BIG=FAILED"\nEND\n' > "$W/f.sno"

RED=0; ARMS=0
check() { # $1=label $2=engine-name $3=stream
    local ret dt small big
    ret="$(printf '%s' "$3" | sed -n 's/^RET=//p' | head -1)"
    dt="$(printf '%s'  "$3" | sed -n 's/^DT=//p'  | head -1)"
    small="$(printf '%s' "$3" | sed -n 's/^SMALL=//p' | head -1)"
    big="$(printf '%s'   "$3" | sed -n 's/^BIG=//p'   | head -1)"
    ARMS=$((ARMS+4))
    case "$ret" in ''|*[!0-9]*) echo "  ⛔ $1 ($2): RET is not a nonneg integer: '$ret'"; RED=$((RED+1));;
        0) echo "  ⛔ $1 ($2): COLLECT() returned 0 -- the lazily-allocated arena was measured before it existed"; RED=$((RED+1));;
        *) echo "  ✓ $1 ($2): COLLECT() = $ret (nonzero; engine-specific by construction, never compared across engines)";; esac
    [ "$dt" = INTEGER ] && echo "  ✓ $1 ($2): DATATYPE INTEGER" || { echo "  ⛔ $1 ($2): DATATYPE is '$dt', expected INTEGER"; RED=$((RED+1)); }
    [ "$small" = SUCCEEDED ] && echo "  ✓ $1 ($2): COLLECT(1000) succeeded" || { echo "  ⛔ $1 ($2): COLLECT(1000) = '$small', expected SUCCEEDED"; RED=$((RED+1)); }
    [ "$big" = FAILED ] && echo "  ✓ $1 ($2): COLLECT(999999999999) failed" || { echo "  ⛔ $1 ($2): COLLECT(999999999999) = '$big', expected FAILED -- the argument is being discarded"; RED=$((RED+1)); }
}

echo "== test_gate_collect_reports_free_storage_and_fails_when_short =="
echo "   oracle $SBL · scrip $SCRIP · one witness, three semantic arms per engine, RET numbers never compared across engines"

O_SBL="$(cd "$W" && timeout -k 5 20s "$SBL" $(sbl_lang_flags) f.sno < /dev/null 2>&1)"
check "oracle-agrees" "sbl -bf" "$O_SBL"

O_M3="$(cd "$W" && timeout -k 5 20s "$SCRIP" --run f.sno < /dev/null 2>&1)"
check "mode-3" "scrip --run" "$O_M3"

if (cd "$W" && timeout -k 5 60s "$SCRIP" --compile f.sno > p.s 2>/dev/null) \
   && (cd "$W" && gcc -c p.s -o p.o 2>/dev/null) \
   && (cd "$W" && gcc p.o -L"$RT_DIR" -lscrip_rt -lm -Wl,-rpath,"$RT_DIR" -o p.bin 2>/dev/null); then
    O_M4="$(cd "$W" && timeout -k 5 20s ./p.bin < /dev/null 2>&1)"
    check "mode-4" "standalone" "$O_M4"
else
    echo "  ⛔ REFUSE(rc=2): mode-4 toolchain failed on the witness -- could not measure, which is never green"
    exit 2
fi

echo "-- population: 1 witness × 3 engines (sbl -bf, mode 3, mode 4) × 4 checks = $ARMS arms, $RED red"
[ "$RED" -eq 0 ] || { echo "⛔ GATE RED: $RED of $ARMS arms"; exit 1; }
echo "✅ GATE OK: $ARMS/$ARMS arms -- COLLECT() reports real free storage and COLLECT(N) decides on its argument, oracle-agreeing in both modes"
