#!/usr/bin/env bash
# test_gate_fb_adopt_one_predicate.sh — ZETA-FB-3 (s161): THE ADOPT CONDITION IS WRITTEN ONCE.
#
# WHY THIS EXISTS.  Two prologue shapes establish rbp as the frame base: xa_flat's jmp-entry
# hdr (save caller rbp + seed rbp=rsp), gated emit_jmp_pin_rbp(); and the HEAP-FRAME ADOPT
# (`push rbp; mov rbp,rdi`), which carves no rsp frame because the activation must survive
# beta-resume.  The second arm's condition was spelled as the RAW GLOBAL DISJUNCTION
# `g_gen_proc_active || g_resumable_callable_active` at SEVEN sites (6 in xa_flat.cpp across
# both media + prologue and epilogue, 1 at the emit.cpp beta dispatch) plus once more inside
# emit_rec_pin().  That duplication IS the s158 land-mine class: edit one copy and the store
# and the load name different base registers, which measured 107/164 FAIL + SIGSEGV.
#
# ZETA-FB-2 (s160) unified the CONSUMERS (x86_fb_pinned == emit_rec_pin).  ZETA-FB-3 names the
# PRODUCER -- emit_heap_fb_adopt() in emit.h -- so the union is the disjunction of two NAMED
# arms.  Prose cannot hold that; this gate can.  Per GOAL-PROLOG-BB.md's own closing note: an
# invariant that nothing checks and nobody updates is the defect, not the documentation.
#
# WHAT IT ASSERTS: the raw disjunction appears in CODE at exactly ONE place -- the body of
# emit_heap_fb_adopt().  Comment prose is exempt (provenance comments legitimately quote the
# old spelling); the check strips /* ... */ before matching.  The individual globals are NOT
# banned -- they are set by the driver and read for reporting; only the RE-DERIVED PREDICATE is.
#
# EXIT 0 = one definition site and no re-derivation.  EXIT 1 = a copy came back.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
cd "$ROOT" || exit 1
DEF_FILE="src/emitter/emit.h"
DEF_FN="emit_heap_fb_adopt"
echo "=== ζ adopt-condition single-predicate gate (ZETA-FB-3) ==="
if ! grep -q "int $DEF_FN(void)" "$DEF_FILE" 2>/dev/null; then
    echo "  FAIL  the named predicate $DEF_FN() is GONE from $DEF_FILE."
    echo "        Do not re-inline its condition -- restore the predicate."
    exit 1
fi
# Strip C comments, then find every surviving mention of the disjunction in either order.
hits="$(find src -name '*.c' -o -name '*.cpp' -o -name '*.h' | sort | while read -r f; do
    perl -0777 -pe 's{/\*(.*?)\*/}{my $c=$1; $c =~ s/[^\n]//g; $c}gse; s{//[^\n]*}{}g' "$f" 2>/dev/null \
      | grep -nE 'g_gen_proc_active[[:space:]]*\|\|[[:space:]]*g_resumable_callable_active|g_resumable_callable_active[[:space:]]*\|\|[[:space:]]*g_gen_proc_active' \
      | sed "s|^|$f:|"
done)"
n="$(printf '%s' "$hits" | grep -c . || true)"
echo "  re-derivation sites (code, comments stripped) : $n"
allowed=0
if [ "$n" -gt 0 ]; then
    while IFS= read -r h; do
        [ -z "$h" ] && continue
        case "$h" in
            "$DEF_FILE":*)
                if printf '%s' "$h" | grep -q "$DEF_FN"; then allowed=$((allowed+1)); continue; fi ;;
        esac
        echo "  OFFENDER  $h" | cut -c1-200
    done <<< "$hits"
fi
bad=$((n - allowed))
if [ "$bad" -eq 0 ] && [ "$allowed" -eq 1 ]; then
    echo "  PASS  the adopt condition is written ONCE, in $DEF_FN()."
    echo "        Every prologue/epilogue/dispatch site reads the predicate, so the base the"
    echo "        prologue ESTABLISHES and the base a reference NAMES cannot drift apart."
    exit 0
fi
echo "  FAIL  expected exactly 1 definition site and 0 re-derivations; got def=$allowed other=$bad."
echo "        Route the site above through $DEF_FN() instead of respelling the globals."
exit 1
