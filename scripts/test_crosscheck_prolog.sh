#!/usr/bin/env bash
# test_crosscheck_prolog.sh — 2-mode oracle crosscheck for PROLOG (GOAL-LANG-PROLOG)
#
# Runs the prolog test corpus through m3 (--run) and m4 (--compile via run_prolog_via_x86_backend.sh),
# grading EACH MODE INDEPENDENTLY against its .ref oracle.
# Run on every major push. Mode-consistency check, not regression.
# If .ref present alongside test file: diffs vs oracle too.
# Exits 0 only if BOTH modes have FAIL=0 against the oracle.
#
# AUTHORS: Lon Jones Cherryholmes · Claude Sonnet 4.6  DATE: 2026-04-14
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_declared_arena.sh" || { echo "REFUSE(2): cannot load lib_declared_arena.sh"; exit 2; }   # m3 runs at the declared size (CEO-1353)
SCRIP="${HERE}/../../SCRIP/scrip"
TIMEOUT=30
PASS=0; FAIL=0; SKIP=0; ORACLE_MISS=0; M3_PASS=0; M3_FAIL=0; M4_PASS=0; M4_FAIL=0; DIVERGE=0; NOORACLE=0

xcheck() {
    local label="$1" file="$2" ref="${3:-}"
    if [ ! -f "$file" ]; then echo "  SKIP $label (no file)"; SKIP=$((SKIP+1)); return; fi
    # ⛔⛔ REWRITTEN seat15 2026-09-01 -- THIS FUNCTION COULD NOT FAIL. Three independent green-manufacturing
    # defects, each verified on a pristine -O0 tree (SCRIP f85e1fdc) before the cure:
    #   (1) it captured `--run` into $ir and `--run` into $run_out -- THE SAME INVOCATION -- then branched on
    #       `[ "$run_out" != "$ir" ]`. That is X != X: unreachable for any deterministic program, so the FAIL
    #       arm was dead code and mode 4 was NEVER INVOKED AT ALL, despite the header's "3-mode crosscheck"
    #       and "Exits 0 only if all three modes agree". The variable name `ir` is the fossil: this script
    #       predates the deletion of modes 1-2, and when mode 2's flag went away the invocation was repointed
    #       to --run instead of to --compile, leaving a self-comparison behind.
    #   (2) the oracle branch read "${f%.pl}.ref" but corpus/tests/prolog stores .expected -- 0 rung*.ref vs
    #       26 *.expected on disk -- so `[ -f "$ref" ]` was never true and ORACLE_MISS=0 meant NO ORACLE WAS
    #       EVER CONSULTED, not "output is correct".
    #   (3) the rung loop pre-skipped any program whose --run exited non-zero, so a crash became SKIP, never
    #       FAIL -- it hid exactly the PZ-4 class this corpus exists to catch (25 SKIP vs 13 PASS).
    # Measured before the cure: PASS=13 FAIL=0 SKIP=25 ORACLE_MISS=0, exit 0, on a language whose own goal
    # file says its flagship row crashes with SIGILL. Authority: RULES.md INSTRUMENT LAWS fifth batch -- an
    # instrument that CANNOT FAIL is worse than no instrument, because it manufactures green.
    # ⭐ PER-MODE INDEPENDENT GRADING (RULES.md MODES MAY DIVERGE, Lon 2026-08-28): m3 and m4 are each graded
    # against the oracle on their own; a divergence between them is reported but is NOT itself a failure.
    local m3_out m3_rc m4_out m4_rc exp=""
    [ -n "$ref" ] && [ -f "$ref" ] && exp="$ref"
    [ -z "$exp" ] && [ -f "${file%.pl}.ref" ]      && exp="${file%.pl}.ref"
    local sw; sw="$(declared_switches_beside "$file")" || { echo "  REFUSE(2) $label: a .heap or .stack sidecar the reader refuses"; exit 2; }
    m3_out=$(timeout -k 5 $TIMEOUT "$SCRIP" --run $sw "$file" </dev/null 2>/dev/null); m3_rc=$?
    m4_out=$(timeout -k 5 $TIMEOUT bash "$HERE/run_prolog_via_x86_backend.sh" "$file" </dev/null 2>/dev/null); m4_rc=$?
    if [ -z "$exp" ]; then
        echo "  NO-ORACLE $label (m3_rc=$m3_rc m4_rc=$m4_rc — ungraded, not a pass)"; NOORACLE=$((NOORACLE+1))
    else
        local want; want=$(cat "$exp")
        if [ "$m3_rc" -eq 0 ] && [ "$m3_out" = "$want" ]; then M3_PASS=$((M3_PASS+1)); else
            echo "  m3 FAIL $label (rc=$m3_rc)"; M3_FAIL=$((M3_FAIL+1)); fi
        if [ "$m4_rc" -eq 0 ] && [ "$m4_out" = "$want" ]; then M4_PASS=$((M4_PASS+1)); else
            echo "  m4 FAIL $label (rc=$m4_rc)"; M4_FAIL=$((M4_FAIL+1)); fi
    fi
    if [ "$m3_out" != "$m4_out" ] || [ "$m3_rc" -ne "$m4_rc" ]; then
        echo "    (DIVERGE $label — m3_rc=$m3_rc m4_rc=$m4_rc; legal under MODES MAY DIVERGE, reported not failed)"
        DIVERGE=$((DIVERGE+1))
    fi
}

echo "=== Prolog 2-mode oracle crosscheck (m3 + m4, graded independently) ==="

T=$(mktemp /tmp/pl_XXXXXX.pl)
cat > "$T" << 'EOF'
:- initialization(main).
main :- write(hello), nl.
EOF
xcheck "hello" "$T"

cat > "$T" << 'EOF'
:- initialization(main).
fact(a). fact(b). fact(c).
main :- fact(X), write(X), nl, fail ; true.
EOF
xcheck "backtrack" "$T"

cat > "$T" << 'EOF'
:- initialization(main).
main :- X is 2 + 3, write(X), nl.
EOF
xcheck "arith" "$T"

cat > "$T" << 'EOF'
:- initialization(main).
count(0) :- !.
count(N) :- N > 0, write(N), nl, N1 is N - 1, count(N1).
main :- count(3).
EOF
xcheck "recursion" "$T"

rm -f "$T"

# Rung corpus files (PJ-9b: extended to walk flat-file corpus, not just subdirs)
RUNGS=$S4E/corpus/tests/prolog
if [ -d "$RUNGS" ]; then
    for f in "$RUNGS"/rung*.pl; do
        [ -f "$f" ] || continue
        # ⛔ THE PRE-SKIP IS DELETED (seat15 2026-09-01): it ran --run first and `continue`d on any non-zero
        # rc, converting every crashing program into a SKIP instead of a failure -- 25 of 38 rungs vanished
        # that way, and a crash is precisely what this corpus exists to catch. Grade it; do not skip it.
        ref="${f%.pl}.ref"
        xcheck "$(basename $f .pl)" "$f" "$ref"
    done
fi

echo ""
echo "PL-CROSSCHECK m3: PASS=$M3_PASS FAIL=$M3_FAIL   m4: PASS=$M4_PASS FAIL=$M4_FAIL   DIVERGE=$DIVERGE NO-ORACLE=$NOORACLE SKIP=$SKIP"
echo "(per-mode INDEPENDENT grading vs .ref oracle — RULES.md MODES MAY DIVERGE; DIVERGE is reported, never failed)"
echo "(NO-ORACLE counts programs with no .ref on disk: ungraded, deliberately NOT counted as passes)"
[ "$M3_FAIL" -eq 0 ] && [ "$M4_FAIL" -eq 0 ]
