#!/bin/bash
# test_gate_no_weak_abort_stub.sh -- pins the two halves of the sm_eval_subexpr landmine so a refactor cannot re-arm it.
#
# ⭐ WHAT THE LANDMINE ACTUALLY WAS (measured 2026-08-27, row sm-eval-subexpr-weak-abort-landmine):
# `sm_eval_subexpr` was declared __attribute__((weak)) with NO strong definition anywhere in the tree, and its body
# called abort(). A weak symbol that aborts is the worst available failure mode: the call TYPE-CHECKS, it LINKS, and
# it kills the process at run time. Two live call arms reached it, and both were unreachable only BY ACCIDENT:
#   (1) runtime_eval.c's `slen == 1` arm -- reachable only from proc_as_value(), which sets pv.slen to the PROC-TABLE
#       INDEX while the consumer reads slen as a TYPE TAG. It never fired because proc_as_value() has zero callers.
#       Had anything called it for the proc at index 1, EXPVAL on that value would have aborted the process.
#   (2) invocation.c's proc_table_call -> sm_call_proc, guarded by `entry_pc >= 0`. It never fired because all live
#       stage2_proc_grow() sites assign entry_pc = -1 BY HAND -- over a memset-to-0 default in which 0 is >= 0.
# ⛔ NEITHER GUARD WAS STRUCTURAL. Both were one edit away from arming: a caller for proc_as_value, or one new
# allocation site that forgot the -1. The path is deleted now; this gate keeps the shape from coming back.
#
# REFUSES rc=2 when it cannot measure -- never skip-as-success.
#
# ⛔⭐ AND IT GRADES THE TREE IT IS RUN FROM (hq_B 2026-09-13, row
# snobol4-a-gate-that-reads-the-main-tree-src-passes-in-a-worktree-while-origin-is-red).  It did not used to.
# It hopped UP to the sibling root and back DOWN into the literal string `SCRIP`, so run from a second
# worktree it graded the MAIN checkout -- and the coo's pre-landing preflight read 33 arms 0 red while origin
# was red for about thirty-five minutes after f0d0adf5b landed a weak pas_gc_roots.  ⭐ Note the gate was not
# confused and did not guess: it PRINTED the tree it graded, on the `src:` line, correctly.  A wrong-subject
# verdict has no symptom, because a verdict about the wrong tree looks exactly like a verdict.
# The subject now comes from ../harness/scripts/lib_subject_tree.sh, which is where the reasoning lives.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib_subject_tree.sh"
REPO="$(s4e_subject_repo "${BASH_SOURCE[0]}")"
SRC="${WEAKGATE_SRC:-$REPO/src}"
[ -d "$SRC" ] || { echo "⛔ REFUSES rc=2: src tree not found at \$REPO/src ($REPO/src)"; exit 2; }
command -v grep >/dev/null || { echo "⛔ REFUSES rc=2: no grep"; exit 2; }

FAIL=0
echo "weak-abort-stub gate -- recomputed live, $(date -u +%Y-%m-%dT%H:%M:%SZ)"
s4e_subject_announce "$REPO" || true
echo "src: $SRC"

# ── HALF 1: no weak definition may reappear, except a named, reviewed allowlist. ─────────────────────────────────
# ⭐ NAMED DELIBERATELY (per this gate's own instruction above), TASK error-voice-statement-number-from-a-code-map-
# no-per-statement-store, cto ruling 2026-10-01: each entry below is checked to NOT share the landmine's shape (a
# weak symbol whose only body is an unconditional abort) -- scrip_emit_stno_table is a weak DECLARATION whose one
# definition (src/emitter/emit.cpp) is a plain strong function, never a stub; __start_/__stop_scrip_stno_map are
# linker section-boundary DATA symbols (no body to call at all) and every reader null-checks both before any
# dereference, falling back to "no statement number" -- today's own pre-existing behaviour -- never aborting.
WEAK_ALLOWLIST='scrip_emit_stno_table|__start_scrip_stno_map|__stop_scrip_stno_map'
WEAK_RAW=$(grep -rn '__attribute__((weak))' "$SRC" --include=*.c --include=*.h 2>/dev/null || true)
ALLOWED=$(printf '%s\n' "$WEAK_RAW" | grep -E "$WEAK_ALLOWLIST" || true)
UNALLOWED=$(printf '%s\n' "$WEAK_RAW" | grep -vE "$WEAK_ALLOWLIST" || true)
WN=$(printf '%s' "$UNALLOWED" | grep -c . || true)
if [ -n "$ALLOWED" ]; then
    echo "  ⭐ half 1: $(printf '%s\n' "$ALLOWED" | grep -c .) allowlisted weak symbol(s) (reviewed, never an abort stub):"
    printf '%s\n' "$ALLOWED" | sed 's|^|     |'
fi
if [ "$WN" -ne 0 ]; then
    echo "⛔ WEAK DEFINITION(S) PRESENT -- each is a call that type-checks, links, and may kill the process:"
    printf '%s\n' "$UNALLOWED" | sed 's|^|     |'
    echo "     -> give it a strong definition, or delete the path. If one must stay, name it here deliberately."
    FAIL=1
else
    echo "  ✅ half 1: zero UNREVIEWED __attribute__((weak)) definitions in src/"
fi

# ── HALF 2: the entry_pc invariant. Every proc allocation must set entry_pc = -1. ─────────────────────────────────
# The default from stage2_proc_grow() is memset-0, and 0 satisfies every `entry_pc >= 0` test in the tree. So a site
# that allocates without assigning -1 does not merely leave a field unset -- it opts that proc INTO the >= 0 branches.
SITES=0; BAD=0; BADLIST=""
while IFS=: read -r f l _; do
    [ -n "${f:-}" ] || continue
    case "$f" in *"gz5-parked"*) continue;; esac      # not in the Makefile's explicit source list; not built
    SITES=$((SITES+1))
    # the assignment sits within a few lines of the allocation at every live site
    if ! sed -n "${l},$((l+6))p" "$f" 2>/dev/null | grep -q 'entry_pc *= *-1'; then
        BAD=$((BAD+1)); BADLIST="$BADLIST\n     $f:$l"
    fi
done <<EOF
$(grep -rnE '=[[:space:]]*stage2_proc_grow\(' "$SRC" --include=*.c 2>/dev/null)
EOF

# ⭐ ANTI-VACUITY BY CROSS-CHECK, NOT BY A >0 FLOOR. A floor of zero is not a real check: this gate's first draft
# matched exactly ONE site out of seventeen (a stray \? in a BRE) and reported a confident green, because 1 > 0.
# An instrument that half-matches reports success on the fraction it can see. So count independently and disagree loudly.
XPECT=$(grep -rlE '=[[:space:]]*stage2_proc_grow\(' "$SRC" --include=*.c 2>/dev/null | grep -v 'gz5-parked' \
        | xargs grep -cHE '=[[:space:]]*stage2_proc_grow\(' 2>/dev/null | awk -F: '{n+=$NF}END{print n+0}')
REFUSE=0
if [ "$SITES" -eq 0 ] || [ "$SITES" -ne "$XPECT" ]; then
    echo "⛔ CANNOT MEASURE half 2: enumerated $SITES call site(s) but an independent count says $XPECT."
    echo "   The pattern and the tree disagree, so a half-match would report green on the fraction it can see."
    echo "   Fix the pattern; do not lower the expectation."
    REFUSE=1
fi
if [ "$REFUSE" -eq 0 ]; then
if [ "$BAD" -ne 0 ]; then
    echo "⛔ $BAD of $SITES stage2_proc_grow site(s) do NOT set entry_pc = -1 within 6 lines:"
    printf "$BADLIST\n"
    echo "     -> the memset-0 default is 0, and 0 is >= 0. An unset entry_pc opts that proc into every >= 0 branch."
    FAIL=1
else
    echo "  ✅ half 2: all $SITES live stage2_proc_grow site(s) set entry_pc = -1"
fi
fi

# A definite defect outranks an unmeasurable half -- but never silently: the refusal is printed either way.
[ "$FAIL" -ne 0 ] && { echo "⛔ GATE FAILED"; exit 1; }
[ "$REFUSE" -ne 0 ] && { echo "⛔ REFUSES rc=2 -- half 2 could not measure; half 1 alone is not a green gate."; exit 2; }
echo "✅ GATE OK"; exit 0
