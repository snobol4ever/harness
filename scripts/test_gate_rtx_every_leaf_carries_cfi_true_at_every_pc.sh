#!/usr/bin/env bash
# test_gate_rtx_every_leaf_carries_cfi_true_at_every_pc.sh -- EVERY ASM LEAF DECLARES ITS FRAME TO THE UNWINDER, TRUTHFULLY AT
# EVERY INSTRUCTION, AND THE C ROAD TO THE FIRST EMITTED FRAME IS THE SYSTEM UNWINDER'S, NOT A PROBE (hq_runtime 2026-10-08, row
# rtx-every-leaf-carries-cfi-so-the-icon-frame-walk-crosses-a-frameless-leaf-by-the-unwinder-and-the-fourteen-word-probe-goes-
# ceo-1548; ceo CEO-1546/1548; ARCH-ICON-RTX.md section 9.8 fact (a); ARCH-RT-CALL-PROTOCOL.md).
#
# WHY.  rt_icn_frames (gc_heap.c) -- the Icon traceback, display(), variable(), the error voice's guard, rt_heap_out_of_memory --
# finds the first emitted frame above a C function with _Unwind_Backtrace.  When the C function was called from an asm leaf
# (RTX_CCALL, RTX_CTAIL, a bare sub rsp,8 / call, the poll's slow path), the frame-pointer chain skips the leaf's own return
# address into emitted code, and only the leaf's FDE says where that word sits.  Before this row the walk tested the return
# address for an FDE and, finding none, looked for a call-site pc among the leaf's first fourteen stack words; that probe and
# gc_pc_is_frameless_leaf are deleted, so a leaf with no FDE or an FDE that lies at one pc sends the walk to a wrong word.
#
# METHOD, HERMETIC (no build): every src/runtime/rtx/*.s and src/runtime/rt/rt_asm_helpers.S is assembled with the Makefile's
# own RT_INCS, under RT_DIAG=1 (the build's default) and RT_DIAG=0; gc_heap.c is compiled for its two poll leaves
# (rt_gc_poll_asm, rt_gc_poll_slow, file-scope __asm__); ../harness/scripts/util_rtx_cfi_walk.py then walks every FDE from each global
# entry along every path, modelling the stack through push/pop, rsp arithmetic, frame pointers and RTX_CALL_ALIGN's dynamic
# alignment, and requires the FDE's CFA rule and callee-saved records to equal the model at every reached instruction, and
# every instruction of every body that makes a call to lie inside an FDE.  A body that makes no call is reported EXEMPT by
# name (no return address can point into it; today the set scanners and the tiny-glue trampoline).
#
# NEGATIVE-TESTED IN EVERY RUN: a truthful synthetic set (RTX_CCALL, RTX_CTAIL, a callee-saved push, a stub label after a ret
# re-declared with RTX_CFA, an aligned C call with pushes inside the region, a frame-pointer body, one torn down by mov rsp,rbp / pop rbp) must be PROVEN, and each lie
# (a push the CFI does not count, a stub label left at the text's depth, an RTX_CALL_ALIGN given the wrong depth, a callee-saved
# push with no record, a torn-down frame pointer whose rbp record is never restored, a body that calls with no FDE at all) must be caught BY NAME.  An instrument that cannot fail measures
# nothing.  FLOOR: fewer than 250 FDEs over the real leaves is REFUSED (rc 2): 265 today.
#
# Usage: bash ../harness/scripts/test_gate_rtx_every_leaf_carries_cfi_true_at_every_pc.sh   (exit 0 green, 1 measured broken, 2 could not measure)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
WALK="$ROOT/../harness/scripts/util_rtx_cfi_walk.py"
FLOOR=250
for t in gcc objdump readelf python3; do
    command -v "$t" >/dev/null 2>&1 || { echo "REFUSED(2): $t is not installed"; exit 2; }
done
[ -f "$WALK" ] || { echo "REFUSED(2): $WALK is missing"; exit 2; }
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
INCS="$(python3 - "$ROOT/Makefile" "$ROOT" <<'PY'
import re, sys
mk, root = sys.argv[1], sys.argv[2]
txt = open(mk, encoding='utf-8', errors='replace').read().replace('\\\n', ' ')
m = re.search(r'^RT_INCS\s*:=\s*(.*)$', txt, re.M)
if not m: sys.exit(1)
v = m.group(1).split('#')[0]
v = v.replace('$(SRC)', root + '/src').replace('$(RT)', root + '/src/runtime')
print(' '.join(t for t in v.split() if t.startswith('-I')))
PY
)"
[ -n "$INCS" ] || { echo "REFUSED(2): could not read RT_INCS out of the Makefile"; exit 2; }
F=0
pass() { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; F=$((F + 1)); }

echo "=== THE PROBE IS GONE AND THE WALK IS THE UNWINDER'S ==="
H="$ROOT/src/runtime/rt/gc_heap.c"
if grep -q 'gc_pc_is_frameless_leaf' "$H"; then fail "gc_heap.c still carries gc_pc_is_frameless_leaf"; else pass "gc_pc_is_frameless_leaf is deleted"; fi
if grep -q '_Unwind_Backtrace(gc_uw_step' "$H"; then pass "gc_chain_entry_from_c starts with _Unwind_Backtrace"; else fail "gc_chain_entry_from_c does not unwind with _Unwind_Backtrace"; fi

echo "=== THE REAL LEAVES ==="
for diag in 1 0; do
    mkdir -p "$WORK/real$diag"
    objs=()
    for src in "$ROOT"/src/runtime/rtx/*.s "$ROOT/src/runtime/rt/rt_asm_helpers.S"; do
        b="$(basename "$src")"; o="$WORK/real$diag/${b%.*}.o"
        gcc -g -w -fPIC -DRT_DIAG=$diag $INCS -x assembler-with-cpp -c "$src" -o "$o" 2>"$o.err" || { echo "REFUSED(2): could not assemble $b (RT_DIAG=$diag): $(head -3 "$o.err")"; exit 2; }
        objs+=("$o")
    done
    if [ "$diag" = 1 ]; then
        gcc -O0 -g -w -fPIC $INCS -c "$H" -o "$WORK/real1/gc_heap.o" 2>"$WORK/gc.err" || { echo "REFUSED(2): could not compile gc_heap.c: $(head -3 "$WORK/gc.err")"; exit 2; }
        objs+=("$WORK/real1/gc_heap.o:rt_gc_poll_asm,rt_gc_poll_slow")
    fi
    out="$(python3 "$WALK" "${objs[@]}" 2>&1)"; rc=$?
    line="$(printf '%s\n' "$out" | grep '^RTX-CFI ' | tail -1)"
    [ -n "$line" ] || { echo "REFUSED(2): the walker printed no summary (rc $rc): $(printf '%s\n' "$out" | tail -3)"; exit 2; }
    [ "$rc" = 2 ] && { echo "REFUSED(2): the walker could not measure: $(printf '%s\n' "$out" | tail -3)"; exit 2; }
    nf="$(printf '%s\n' "$line" | grep -oE 'fdes=[0-9]+' | cut -d= -f2)"
    [ "${nf:-0}" -ge "$FLOOR" ] || { echo "REFUSED(2): only ${nf:-0} FDEs over the real leaves at RT_DIAG=$diag (floor $FLOOR)"; exit 2; }
    printf '%s\n' "$out" | grep -E 'VIOLATION|EXEMPT' | head -40 | sed 's/^/      /'
    if [ "$rc" = 0 ]; then pass "RT_DIAG=$diag: $line"; else fail "RT_DIAG=$diag: $line"; fi
done

echo "=== THE WALKER PROVES THE TRUTH AND CATCHES EVERY LIE ==="
mkdir -p "$WORK/inj"
cat > "$WORK/inj/ok.s" <<'ASM'
#include "rtx_abi.inc"
RTX_FUNC(ok_ccall)
    RTX_SUB_RSP(8)
    RTX_PUSH(r8)
    RTX_PUSH(r9)
    RTX_PUSH(r10)
    RTX_PUSH(r11)
    call    ok_c@PLT
    RTX_POP(r11)
    RTX_POP(r10)
    RTX_POP(r9)
    RTX_POP(r8)
    RTX_ADD_RSP(8)
    ret
RTX_ENDF(ok_ccall)
RTX_FUNC(ok_ctail)
    test    rdi, rdi
    jz      .Lok_ct
    ret
.Lok_ct:
    RTX_PUSH(r8)
    RTX_PUSH(r9)
    RTX_PUSH(r10)
    RTX_PUSH(r11)
    RTX_SUB_RSP(8)
    call    ok_c@PLT
    RTX_ADD_RSP(8)
    RTX_POP(r11)
    RTX_POP(r10)
    RTX_POP(r9)
    RTX_POP(r8)
    ret
RTX_ENDF(ok_ctail)
RTX_FUNC(ok_saved)
    RTX_PUSHS(rbx)
    mov     rbx, rdi
    test    rdi, rdi
    jz      .Lok_sv
    call    ok_c@PLT
    RTX_POPS(rbx)
    ret
.Lok_sv:
    RTX_CFA(16)
    .cfi_rel_offset rbx, 0
    RTX_SUB_RSP(16)
    call    ok_c@PLT
    RTX_ADD_RSP(16)
    RTX_POPS(rbx)
    ret
RTX_ENDF(ok_saved)
RTX_FUNC(ok_aligned)
    RTX_PUSH(r8)
    RTX_CALL_ALIGN(16)
    RTX_PUSH_DYN(rdi, 16, 16)
    RTX_PUSH_DYN(rsi, 24, 16)
    call    ok_c@PLT
    RTX_POP_DYN(rsi, 16, 16)
    RTX_POP_DYN(rdi, 8, 16)
    RTX_CALL_UNALIGN(16)
    RTX_POP(r8)
    ret
RTX_ENDF(ok_aligned)
RTX_FUNC(ok_framed)
    RTX_PUSHS(rbp)
    mov     rbp, rsp
    .cfi_def_cfa_register rbp
    sub     rsp, 32
    and     rsp, -16
    call    ok_c@PLT
    leave
    .cfi_def_cfa rsp, 8
    .cfi_restore rbp
    ret
RTX_ENDF(ok_framed)
RTX_FUNC(ok_framed_pop)
    RTX_PUSHS(rbp)
    mov     rbp, rsp
    .cfi_def_cfa_register rbp
    sub     rsp, 48
    call    ok_c@PLT
    mov     rsp, rbp
    pop     rbp
    .cfi_def_cfa rsp, 8
    .cfi_restore rbp
    test    rax, rax
    jz      99f
    mov     eax, 1
99: ret
RTX_ENDF(ok_framed_pop)
.section .note.GNU-stack,"",@progbits
ASM
lie() {
    local name="$1" want="$2" body="$3"
    printf '#include "rtx_abi.inc"\n%s\n.section .note.GNU-stack,"",@progbits\n' "$body" > "$WORK/inj/$name.s"
    gcc -g -w -fPIC $INCS -I"$ROOT/src/runtime/rtx" -x assembler-with-cpp -c "$WORK/inj/$name.s" -o "$WORK/inj/$name.o" 2>"$WORK/inj/$name.err" || { echo "REFUSED(2): the lie $name does not assemble: $(head -2 "$WORK/inj/$name.err")"; exit 2; }
    local o; o="$(python3 "$WALK" "$WORK/inj/$name.o" 2>&1)"; local r=$?
    if [ "$r" = 1 ] && printf '%s\n' "$o" | grep -q "$want"; then pass "lie $name caught ($want)"; else fail "lie $name NOT caught as '$want' (rc $r): $(printf '%s\n' "$o" | head -3)"; fi
}
gcc -g -w -fPIC $INCS -I"$ROOT/src/runtime/rtx" -x assembler-with-cpp -c "$WORK/inj/ok.s" -o "$WORK/inj/ok.o" 2>"$WORK/inj/ok.err" || { echo "REFUSED(2): the truthful set does not assemble: $(head -3 "$WORK/inj/ok.err")"; exit 2; }
o="$(python3 "$WALK" "$WORK/inj/ok.o" 2>&1)"; r=$?
if [ "$r" = 0 ]; then pass "the truthful set is proven: $(printf '%s\n' "$o" | tail -1)"; else fail "the truthful set is NOT proven (rc $r): $(printf '%s\n' "$o" | head -5)"; fi
lie uncounted_push 'model rsp+24  CFI rsp+16' 'RTX_FUNC(lie_push)
    RTX_PUSH(r8)
    push    r9
    call    lie_c@PLT
    RTX_POP(r9)
    RTX_POP(r8)
    ret
RTX_ENDF(lie_push)'
lie stub_at_text_depth 'model rsp+16  CFI rsp+8' 'RTX_FUNC(lie_stub)
    RTX_PUSH(r8)
    test    rdi, rdi
    jz      .Llie_st
    RTX_POP(r8)
    ret
.Llie_st:
    call    lie_c@PLT
    RTX_POP(r8)
    ret
RTX_ENDF(lie_stub)'
lie align_wrong_depth 'model \[rsp+8\]+16  CFI \[rsp+8\]+8' 'RTX_FUNC(lie_align)
    RTX_PUSH(r8)
    RTX_CALL_ALIGN(8)
    call    lie_c@PLT
    RTX_CALL_UNALIGN(16)
    RTX_POP(r8)
    ret
RTX_ENDF(lie_align)'
lie unrecorded_save 'saved{rbx@cfa-16}  CFI rsp+16$' 'RTX_FUNC(lie_save)
    RTX_PUSH(rbx)
    mov     rbx, rdi
    call    lie_c@PLT
    RTX_POP(rbx)
    ret
RTX_ENDF(lie_save)'
lie framed_pop_unrestored 'model rsp+8  CFI rsp+8 saved{rbp@cfa-16}' 'RTX_FUNC(lie_fp)
    RTX_PUSHS(rbp)
    mov     rbp, rsp
    .cfi_def_cfa_register rbp
    sub     rsp, 48
    call    lie_c@PLT
    mov     rsp, rbp
    pop     rbp
    .cfi_def_cfa rsp, 8
    test    rax, rax
    jz      99f
    mov     eax, 1
99: ret
RTX_ENDF(lie_fp)'
lie no_fde 'NO FDE covers this instruction of lie_bare' '.text
.globl lie_bare
.type lie_bare,@function
lie_bare:
    sub     rsp, 8
    call    lie_c@PLT
    add     rsp, 8
    ret
.size lie_bare, .-lie_bare'

if [ "$F" = 0 ]; then
    echo "PASS: every asm leaf carries CFI that is true at every reached pc, the poll included, and the walker catches every planted lie."
    exit 0
fi
echo "FAIL: $F arm(s) red"
exit 1
