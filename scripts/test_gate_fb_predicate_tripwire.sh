#!/usr/bin/env bash
# stale-binary preflight (row test-gate-scripts-that-grade-scrip-refuse-on-a-stale-binary-census-widened, hq_T 2026-09-05)
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# ../harness/scripts/test_gate_fb_predicate_tripwire.sh — the ζ FRAME-BASE predicate tripwire (ZETA-FB, s160).
#
# WHAT IT GUARDS.  Exactly ONE register is the ζ frame base for a given graph, and THREE places must
# name the same one or the emitted code stores through one base and loads through another (the s158
# 44-test backtrack SIGSEGV, whose land mine was `pop rsp` reading a heap frame base):
#   (1) the PROLOGUE that ESTABLISHES it — xa_flat's jmp-entry hdr `mov rbp,rsp` (gated
#       emit_jmp_pin_rbp) OR xa_flat.cpp:281's gen-proc/resumable heap-frame adopt `mov rbp,rdi`
#       (gated g_gen_proc_active || g_resumable_callable_active);
#   (2) every DATA reference — FR/FRQ via x86_fb_pinned();
#   (3) the 16-byte suspend RECORD protocol — resume-slot store, res-landing pop, beta dispatch,
#       via emit_rec_pin().
# ZETA-FB-2 unified (2) onto emit_rec_pin(), which is the exact disjunction of the two arms in (1),
# so all three now read ONE predicate and cannot drift.
#
# WHAT THIS SCRIPT REPORTS.  The instrument (emit.cpp emit_fb_divergence_check, SCRIP_FB_DIVERGE=1)
# fires whenever the WIDE predicate exceeds the NARROW one for a graph — i.e. whenever a graph enters
# the class `g_gen_proc_active || g_resumable_callable_active` WITHOUT `flat_deep_arrival || flat_pat
# || flat_gen`. That class is REACHABLE BY CONSTRUCTION (flat_gen = is_generator && has_suspend, while
# g_gen_proc_active = is_generator, so a SUSPEND-FREE generator graph is exactly it) but was measured
# EMPTY over 592 corpus programs across four frontends at s160.
#
# A HIT IS NOT A FAILURE — IT IS NEWS, and that is the whole point (the s193 falsifiable-tripwire
# discipline). It means the previously-empty class is now live, so ZETA-FB-2's byte-neutrality claim
# has EXPIRED for that graph and the widening must be re-measured rather than assumed. Default mode
# reports and exits 0; --strict exits 1 on any hit, for a session that wants the class held empty.
#
# Self-contained. Run from anywhere. Authors: LCherryholmes · Jeffrey Cooper M.D. · Claude Sonnet
S4E="${S4E_HOME:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"   # D-17 PORTABLE-HOME: the sibling root (all repos + oracles are siblings under ONE root; /home/claude2-style seat roots work with zero env; S4E_HOME overrides)
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT"
SCRIP="${SCRIP:-$ROOT/scrip}"
CORPUS="${CORPUS:-$S4E/corpus/programs}"
STRICT=0
[ "${1:-}" = "--strict" ] && STRICT=1
[ -x "$SCRIP" ] || { echo "FB-TRIPWIRE: no scrip binary at $SCRIP — build first." >&2; exit 2; }
echo "=== ζ frame-base predicate tripwire (ZETA-FB) ==="
TOTAL=0
PROGS=0
HITFILES=""
for f in $(ls "$CORPUS"/tests/prolog/*.pl 2>/dev/null) \
         $(find "$CORPUS/icon"    -name "*.icn" 2>/dev/null) \
         $(find "$CORPUS/snobol4" -name "*.sno" 2>/dev/null) \
         $(find "$CORPUS/snocone" -name "*.sc"  2>/dev/null); do
    PROGS=$((PROGS + 1))
    n=$(SCRIP_FB_DIVERGE=1 timeout -k 5 15 "$SCRIP" --run "$f" < /dev/null 2>&1 | grep -c "^FB-DIVERGE #")
    if [ "$n" -gt 0 ]; then
        TOTAL=$((TOTAL + n))
        HITFILES="$HITFILES $f"
        echo "  HIT ($n): $f"
        SCRIP_FB_DIVERGE=1 timeout -k 5 15 "$SCRIP" --run "$f" < /dev/null 2>&1 | grep "^FB-DIVERGE #" | head -3 | sed 's/^/      /'
    fi
done
echo "  programs swept : $PROGS"
echo "  wide-exceeds-narrow graphs : $TOTAL"
if [ "$TOTAL" -eq 0 ]; then
    echo "  PASS  the wide/narrow gap is EMPTY — ZETA-FB-2 is byte-neutral on this corpus."
    exit 0
fi
echo "  NEWS  the gap is NO LONGER EMPTY. The suspend-free-generator class is live in:$HITFILES"
echo "        ZETA-FB-2's byte-neutrality claim has expired for those graphs — RE-MEASURE the"
echo "        widening (capture .s before/after with x86_fb_pinned pinned back to emit_jmp_pin_rbp)"
echo "        rather than assuming it. This is a report, not a verdict."
[ "$STRICT" -eq 1 ] && { echo "  GATE FAIL (--strict)."; exit 1; }
exit 0
