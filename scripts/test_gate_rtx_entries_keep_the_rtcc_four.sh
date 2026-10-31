#!/usr/bin/env bash
# test_gate_rtx_entries_keep_the_rtcc_four.sh -- EVERY ENTRY INTO THE ASM RUNTIME RETURNS r8, r10 AND r11 AS IT RECEIVED THEM
# AND r9 AS THE GVA BASE, UNLESS ITS ROW IN THE GENERATED CLOBBER TABLE RECORDS THE WRITE, PROVEN FROM THE ASSEMBLED OBJECTS
# ALONG EVERY PATH. RE-ANCHORED ON THE TABLE (hq_runtime 2026-10-07, row rtx-leaves-carry-no-register-veneer-an-asm-runtime-
# call-is-not-a-c-function; ARCH-RT-CALL-PROTOCOL.md section 15 item 6): a recorded write is the contract, because the emitted
# site re-establishes exactly the recorded set (x86_rtcc_call); an UNRECORDED write is the violation. The table's freshness
# against the objects is test_gate_rtx_the_leaf_clobber_table_is_derived_and_gated_against_the_objects.sh. The truthful
# injection set carries one entry (inj_recorded) writing r8 and r10 under a planted row that records them, and the lies are
# walked under the same planted table, so lie_clobber's unrecorded r10 must still be caught. AND NO ROW MAY NAME r9: the GVA
# base is a constant of the run, so every exit of every entry, its C tails included, reloads it (RTX_GVA_R9 then ret) and the
# site re-establishes nothing for it -- a call_bare site could not (cto 2026-10-07). (cto 2026-09-23, CEO-1224, row
# spine-no-rtccb-veneer-on-any-call-into-the-asm-runtime-the-rtx-abi-preserves-r8-to-r11; Lon in-chat to the ceo, verbatim:
# "get rid of veneer for all RT ASM instances.").
#
# WHY THIS IS THE LOAD-BEARING CHECK OF THE ROW. Emitted code now calls every RTX entry BARE -- no g_rtccb write-back before
# the call, no reload after it -- so a single entry that leaves r10 (the statement number), r11 (the box id), r8 or r9 (the
# GVA base every global access indexes) changed on ONE path hands its caller a wrong register with no error anywhere. The
# emitter side is measured by test_gate_rtx_calls_carry_no_veneer.sh; THIS gate proves the callee side, and a green here is
# what licenses the emitter to drop the veneer at all.
#
# METHOD, HERMETIC (no build, no ./scrip): every src/runtime/rtx/*.s is assembled into a scratch directory with the
# Makefile's own RT_INCS and assembler flags; the entry REGISTRY is read out of the objects' rtx_entry_names sections (the
# names RTX_FUNC and RTX_ENTRY write, so the list is derived and never typed); ../harness/scripts/util_rtx_abi_walk.py then
# abstract-interprets every registered entry over `objdump -d -r` -- the instruction stream after cpp AND gas macros, with
# the relocation that names every external target -- tracking the four registers (entry value / GVA / other) and the stack
# slot by slot through pushes, pops, frames, dynamic alignment, calls and stubs. The contract it grades is written in
# src/runtime/rtx/rtx_abi.inc and ARCH-SNOBOL4-RTX.md section 2. A body the walker cannot read is a VIOLATION, never a pass.
#
# NEGATIVE-TESTED IN EVERY RUN, NOT AT AUTHORING TIME: a truthful synthetic body set (every sanctioned form: a leaf, a body
# that pushes and pops the four itself (the expansion of the deleted RTX_SAVE / RTX_RET, spelled literally), a wrapped C call, a C tail stub, a saved C tail stub, a nested and a tail RTX call through the GOT, an r9 argument
# handed back as GVA, a dynamically aligned C call, registers reloaded from their own stack slots) must be PROVEN, and a lying set -- a clobbered r10, a bare tail jump into C, an unwrapped C call, a
# nested RTX call through a PLT slot (lazy binding jumps through r11), an r9 argument returned as received, a stray stack
# slot, a gate arm straight into C, a C call made with rsp misaligned, a register reloaded from its NEIGHBOUR'S slot (the walker's slot arithmetic checked in
# the direction that matters), and a global function the registry does not name -- must be caught ENTRY BY ENTRY. If
# the walker ever proves a lie, or misses one by name, this gate is red: an instrument that cannot fail is not measuring.
#
# FLOOR: a registry of fewer than 200 entries is REFUSED (rc=2) -- the objects define 272 today, and an empty or truncated
# registry would walk nothing and read green.
#
# Usage: bash ../harness/scripts/test_gate_rtx_entries_keep_the_rtcc_four.sh    (exit 0 = green, 1 = measured broken, 2 = could not measure)
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../SCRIP" && pwd)"
WALK="$ROOT/../harness/scripts/util_rtx_abi_walk.py"
FLOOR=200
for t in gcc objdump objcopy nm python3; do
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

assemble() {
    local src="$1" obj="$2"
    gcc -g -w -fPIC $INCS -I"$ROOT/src/runtime/rtx" -x assembler-with-cpp -c "$src" -o "$obj" 2>"$obj.err"
}
registry() {
    local out="$1"; shift
    : > "$out.bin"
    for o in "$@"; do
        objcopy -O binary --only-section=rtx_entry_names "$o" "$o.names" 2>/dev/null && cat "$o.names" >> "$out.bin"
    done
    python3 -c "import sys; d = open(sys.argv[1], 'rb').read(); open(sys.argv[2], 'w', encoding='utf-8').write(''.join(n.decode('utf-8') + '\n' for n in d.split(b'\0') if n))" "$out.bin" "$out"
}

mkdir -p "$WORK/real" "$WORK/inj"
cat > "$WORK/inj/inj_ok.s" <<'ASM'
#include "rtx_abi.inc"
RTX_FUNC(inj_leaf)
    mov     rax, rdi
    ret
RTX_ENDF(inj_leaf)
RTX_FUNC(inj_saved)
    push    r8
    push    r9
    push    r10
    push    r11
    mov     r10, 1
    mov     r11, 2
    sub     rsp, 8
    call    inj_c
    add     rsp, 8
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    ret
RTX_ENDF(inj_saved)
RTX_FUNC(inj_ccall)
    sub     rsp, 8
    RTX_PUSH(r8)
    RTX_PUSH(r9)
    RTX_PUSH(r10)
    RTX_PUSH(r11)
    call    inj_c
    RTX_POP(r11)
    RTX_POP(r10)
    RTX_POP(r9)
    RTX_POP(r8)
    add     rsp, 8
    ret
RTX_ENDF(inj_ccall)
RTX_FUNC(inj_ctail)
    test    rdi, rdi
    jz      .Linj_ct
    ret
.Linj_ct:
    RTX_PUSH(r8)
    RTX_PUSH(r9)
    RTX_PUSH(r10)
    RTX_PUSH(r11)
    RTX_SUB_RSP(8)
    call    inj_c
    RTX_ADD_RSP(8)
    RTX_POP(r11)
    RTX_POP(r10)
    RTX_POP(r9)
    RTX_POP(r8)
    ret
RTX_ENDF(inj_ctail)
RTX_FUNC(inj_saved_tail)
    push    r8
    push    r9
    push    r10
    push    r11
    mov     r8, 5
    test    rdi, rdi
    jz      .Linj_st
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    ret
.Linj_st:
    mov     r8, qword ptr [rsp + 24]
    mov     r9, qword ptr [rsp + 16]
    sub     rsp, 8
    call    inj_c
    add     rsp, 8
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    ret
RTX_ENDF(inj_saved_tail)
RTX_FUNC(inj_nested)
    sub     rsp, 8
    RTX_CALL(inj_leaf)
    add     rsp, 8
    RTX_JMP(inj_leaf)
RTX_ENDF(inj_nested)
RTX_FUNC(inj_r9_arg)
    push    r8
    push    r9
    push    r10
    push    r11
    mov     rax, r9
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    RTX_GVA_R9
    ret
RTX_ENDF(inj_r9_arg)
RTX_FUNC(inj_aligned)
    push    r8
    push    r9
    push    r10
    push    r11
    RTX_CALL_ALIGN(40)
    push    rdi
    push    rsi
    call    inj_c
    pop     rsi
    pop     rdi
    RTX_CALL_UNALIGN(40)
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    ret
RTX_ENDF(inj_aligned)
RTX_FUNC(inj_recorded)
    mov     r10, 1
    mov     r8, 2
    ret
RTX_ENDF(inj_recorded)
RTX_FUNC(inj_reload)
    push    r10
    push    r11
    mov     r10, 7
    mov     r11, 9
    mov     r11, qword ptr [rsp]
    mov     r10, qword ptr [rsp + 8]
    add     rsp, 16
    ret
RTX_ENDF(inj_reload)
RTX_FUNC(inj_spill)
    sub     rsp, 40
    mov     qword ptr [rsp], r8
    mov     qword ptr [rsp + 8], r9
    mov     qword ptr [rsp + 16], r10
    mov     qword ptr [rsp + 24], r11
    call    inj_c
    mov     r8, qword ptr [rsp]
    mov     r9, qword ptr [rsp + 8]
    mov     r10, qword ptr [rsp + 16]
    mov     r11, qword ptr [rsp + 24]
    mov     rax, qword ptr [r10]
    add     rsp, 40
    RTX_GVA_R9
    ret
RTX_ENDF(inj_spill)
.macro XPINS rec
    mov     rbp, qword ptr [\rec + 24]
    mov     rbx, qword ptr [\rec + 32]
    mov     r12, qword ptr [\rec + 40]
    mov     r13, qword ptr [\rec + 48]
    mov     r14, qword ptr [\rec + 56]
    mov     r15, qword ptr [\rec + 64]
.endm
.macro XREGS rec
    mov     r8, qword ptr [\rec + 72]
    mov     r10, qword ptr [\rec + 80]
    mov     r11, qword ptr [\rec + 88]
.endm
RTX_FUNC(ok_xfer_seg)
    mov     rsp, qword ptr [rax + 8]
    sub     rsp, 256
    mov     rdi, qword ptr [rax + 8]
    mov     rcx, qword ptr [rax + 16]
    lea     rsi, [rax + 96]
    cld
    rep movsb
    XPINS   rax
    XREGS   rax
    mov     rsp, qword ptr [rax + 8]
    RTX_GVA_R9
    mov     eax, DT_I
    mov     edx, 1
    ret
RTX_ENDF(ok_xfer_seg)
RTX_FUNC(ok_xfer_choice)
    XPINS   rdx
    XREGS   rdx
    mov     rcx, qword ptr [rdx + 16]
    mov     rsp, qword ptr [rdx + 8]
    add     rsp, 8
    RTX_GVA_R9
    mov     eax, DT_I
    mov     edx, 1
    jmp     rcx
RTX_ENDF(ok_xfer_choice)
RTX_FUNC(ok_xfer_park)
    push    rbp
    mov     rbp, rsp
    sub     rsp, 48
    mov     qword ptr [rsp], r8
    mov     qword ptr [rsp + 8], r10
    mov     qword ptr [rsp + 16], r11
    call    inj_c
    mov     r8, qword ptr [rsp]
    mov     r10, qword ptr [rsp + 8]
    mov     r11, qword ptr [rsp + 16]
    RTX_GVA_R9
    test    rax, rax
    jnz     .Lxp_go
    mov     rsp, rbp
    pop     rbp
    ret
.Lxp_go:
    jmp     ok_xfer_seg
RTX_ENDF(ok_xfer_park)
RTX_FUNC(ok_xfer_resume)
    push    rbp
    mov     rbp, rsp
    sub     rsp, 48
    call    inj_c
    RTX_JMP(ok_xfer_seg)
RTX_ENDF(ok_xfer_resume)
RTX_FUNC(ok_xfer_recorded)
    mov     rsp, qword ptr [rax + 8]
    XPINS   rax
    RTX_GVA_R9
    mov     eax, DT_I
    ret
RTX_ENDF(ok_xfer_recorded)
.section .note.GNU-stack,"",@progbits
ASM
cat > "$WORK/inj/inj_lie.s" <<'ASM'
#include "rtx_abi.inc"
RTX_GATE_DEF(inj)
RTX_FUNC(inj_leaf2)
    mov     rax, rdi
    ret
RTX_ENDF(inj_leaf2)
RTX_FUNC(lie_clobber)
    mov     r10, 1
    ret
RTX_ENDF(lie_clobber)
RTX_FUNC(lie_ctail)
    jmp     inj_c
RTX_ENDF(lie_ctail)
RTX_FUNC(lie_cbare)
    sub     rsp, 8
    call    inj_c
    add     rsp, 8
    ret
RTX_ENDF(lie_cbare)
RTX_FUNC(lie_plt)
    sub     rsp, 8
    call    inj_leaf2
    add     rsp, 8
    ret
RTX_ENDF(lie_plt)
RTX_FUNC(lie_r9)
    mov     rax, r9
    ret
RTX_ENDF(lie_r9)
RTX_FUNC(lie_stack)
    push    rax
    ret
RTX_ENDF(lie_stack)
RTX_FUNC(lie_gate)
    RTX_GATE(inj, inj_c)
    ret
RTX_ENDF(lie_gate)
RTX_FUNC(lie_misaligned)
    push    r8
    push    r9
    push    r10
    push    r11
    call    inj_c
    pop     r11
    pop     r10
    pop     r9
    pop     r8
    ret
RTX_ENDF(lie_misaligned)
RTX_FUNC(lie_reload)
    push    r10
    push    r11
    mov     r10, 7
    mov     r10, qword ptr [rsp]
    add     rsp, 16
    ret
RTX_ENDF(lie_reload)
RTX_FUNC(lie_read_after_call)
    sub     rsp, 8
    mov     r10, rdi
    call    inj_c
    mov     rax, qword ptr [r10]
    add     rsp, 8
    ret
RTX_ENDF(lie_read_after_call)
RTX_FUNC(lie_r9_own)
    sub     rsp, 8
    mov     r9, rdi
    call    inj_c
    RTX_GVA_R9
    mov     rax, qword ptr [r9]
    add     rsp, 8
    ret
RTX_ENDF(lie_r9_own)
.macro XPINS rec
    mov     rbp, qword ptr [\rec + 24]
    mov     rbx, qword ptr [\rec + 32]
    mov     r12, qword ptr [\rec + 40]
    mov     r13, qword ptr [\rec + 48]
    mov     r14, qword ptr [\rec + 56]
    mov     r15, qword ptr [\rec + 64]
.endm
.macro XREGS rec
    mov     r8, qword ptr [\rec + 72]
    mov     r10, qword ptr [\rec + 80]
    mov     r11, qword ptr [\rec + 88]
.endm
RTX_FUNC(lie_xfer_nonrec)
    mov     rsp, qword ptr [rdi + 8]
    ret
RTX_ENDF(lie_xfer_nonrec)
RTX_FUNC(lie_xfer_r11rec)
    sub     rsp, 8
    call    inj_c
    mov     r11, rax
    mov     rsp, qword ptr [r11 + 8]
    ret
RTX_ENDF(lie_xfer_r11rec)
RTX_FUNC(lie_xfer_disp)
    mov     rsp, qword ptr [rax + 8]
    add     rsp, 16
    XPINS   rax
    XREGS   rax
    RTX_GVA_R9
    mov     eax, DT_I
    ret
RTX_ENDF(lie_xfer_disp)
RTX_FUNC(lie_xfer_pin)
    mov     rsp, qword ptr [rax + 8]
    XPINS   rax
    mov     rbx, 1
    XREGS   rax
    RTX_GVA_R9
    mov     eax, DT_I
    ret
RTX_ENDF(lie_xfer_pin)
RTX_FUNC(lie_xfer_r9)
    mov     rsp, qword ptr [rax + 8]
    XPINS   rax
    XREGS   rax
    mov     eax, DT_I
    ret
RTX_ENDF(lie_xfer_r9)
RTX_FUNC(lie_xfer_push)
    mov     rsp, qword ptr [rax + 8]
    push    rbx
    XPINS   rax
    XREGS   rax
    RTX_GVA_R9
    mov     eax, DT_I
    ret
RTX_ENDF(lie_xfer_push)
RTX_FUNC(lie_xfer_noswitch)
    mov     rax, rdi
    ret
RTX_ENDF(lie_xfer_noswitch)
RTX_FUNC(lie_xfer_r10)
    mov     rsp, qword ptr [rax + 8]
    XPINS   rax
    mov     r8, qword ptr [rax + 72]
    mov     r11, qword ptr [rax + 88]
    RTX_GVA_R9
    mov     eax, DT_I
    ret
RTX_ENDF(lie_xfer_r10)
RTX_FUNC(lie_xfer_tail)
    RTX_JMP(ok_xfer_seg)
RTX_ENDF(lie_xfer_tail)
RTX_FUNC(lie_xfer_partial)
    mov     rsp, qword ptr [rax + 8]
    XPINS   rax
    mov     r11, qword ptr [rax + 88]
    RTX_GVA_R9
    mov     eax, DT_I
    ret
RTX_ENDF(lie_xfer_partial)
    .text
    .globl  lie_unregistered
    .type   lie_unregistered,@function
lie_unregistered:
    ret
    .size   lie_unregistered, .-lie_unregistered
.section .note.GNU-stack,"",@progbits
ASM
objs=()
for s in "$ROOT"/src/runtime/rtx/*.s; do
    o="$WORK/real/$(basename "$s" .s).o"
    ( assemble "$s" "$o" || touch "$o.failed" ) &
    objs+=("$o")
done
for b in inj_ok inj_lie; do
    ( assemble "$WORK/inj/$b.s" "$WORK/inj/$b.o" || touch "$WORK/inj/$b.failed" ) &
done
wait
[ "${#objs[@]}" -gt 0 ] || { echo "REFUSED(2): no src/runtime/rtx/*.s found"; exit 2; }
for o in "${objs[@]}"; do
    if [ -e "$o.failed" ] || [ ! -s "$o" ]; then echo "REFUSED(2): $(basename "$o" .o).s does not assemble:"; head -5 "$o.err"; exit 2; fi
done
for b in inj_ok inj_lie; do
    if [ -e "$WORK/inj/$b.failed" ]; then echo "REFUSED(2): the injection file $b does not assemble:"; head -5 "$WORK/inj/$b.o.err"; exit 2; fi
    registry "$WORK/inj/$b.entries" "$WORK/inj/$b.o"
done
registry "$WORK/real/entries.txt" "${objs[@]}"
n_entries=$(grep -c . "$WORK/real/entries.txt")
echo "=== THE REAL RUNTIME: ${#objs[@]} objects, $n_entries registered entries ==="
if [ "$n_entries" -lt "$FLOOR" ]; then echo "REFUSED(2): the registry names $n_entries entries, under the floor of $FLOOR -- nothing would be walked"; exit 2; fi
TABLE="$WORK/real/walker_table.inc"
python3 "$ROOT/../harness/scripts/util_gen_rt_entry_table.py" --walker-table "$TABLE" || { echo "REFUSED(2): the runtime entry table (harness/scripts/rt_entries.tsv) could not be written in the walker's row format"; exit 2; }
[ -s "$TABLE" ] || { echo "REFUSED(2): the runtime entry table states no clobbers, so there is no contract to hold the objects to ($TABLE is empty)"; exit 2; }
cat > "$WORK/inj/table.inc" <<'TBL'
    { "inj_recorded", RTCC_C_R8|RTCC_C_R10 },
    { "ok_xfer_seg", RTCC_XFER|RTCC_XREC_RAX },
    { "ok_xfer_choice", RTCC_XFER|RTCC_XREC_RDX },
    { "ok_xfer_park", RTCC_XFER },
    { "ok_xfer_resume", RTCC_XFER },
    { "ok_xfer_recorded", RTCC_C_R8|RTCC_C_R10|RTCC_C_R11|RTCC_XFER|RTCC_XREC_RAX },
    { "lie_xfer_partial", RTCC_C_R8|RTCC_XFER|RTCC_XREC_RAX },
    { "lie_xfer_nonrec", RTCC_XFER|RTCC_XREC_RAX },
    { "lie_xfer_r11rec", RTCC_XFER },
    { "lie_xfer_disp", RTCC_XFER|RTCC_XREC_RAX },
    { "lie_xfer_pin", RTCC_XFER|RTCC_XREC_RAX },
    { "lie_xfer_r9", RTCC_XFER|RTCC_XREC_RAX },
    { "lie_xfer_push", RTCC_XFER|RTCC_XREC_RAX },
    { "lie_xfer_noswitch", RTCC_XFER },
    { "lie_xfer_r10", RTCC_XFER|RTCC_XREC_RAX },
TBL
( python3 "$WALK" "${objs[@]}" --entries "$WORK/real/entries.txt" --table "$TABLE" > "$WORK/real.out" 2>&1; echo $? > "$WORK/real.rc" ) &
( python3 "$WALK" "$WORK/inj/inj_ok.o" --entries "$WORK/inj/inj_ok.entries" --table "$WORK/inj/table.inc" > "$WORK/inj_ok.out" 2>&1; echo $? > "$WORK/ok.rc" ) &
( python3 "$WALK" "$WORK/inj/inj_lie.o" --entries "$WORK/inj/inj_lie.entries" --table "$WORK/inj/table.inc" > "$WORK/inj_lie.out" 2>&1; echo $? > "$WORK/lie.rc" ) &
wait
real_rc=$(cat "$WORK/real.rc"); ok_rc=$(cat "$WORK/ok.rc"); lie_rc=$(cat "$WORK/lie.rc")
cat "$WORK/real.out"
echo "=== THE INJECTION SELF-TEST ==="
python3 - "$WORK/inj_ok.out" "$ok_rc" "$WORK/inj/inj_ok.entries" "$WORK/inj_lie.out" "$lie_rc" > "$WORK/inj.verdict" <<'PY'
import sys
ok_out, ok_rc, ok_ent, lie_out, lie_rc = open(sys.argv[1]).read(), int(sys.argv[2]), open(sys.argv[3]).read().split(), open(sys.argv[4]).read(), int(sys.argv[5])
bad = []
if ok_rc != 0: bad.append('the truthful set was NOT proven (rc=%d):\n%s' % (ok_rc, ok_out))
if len(ok_ent) != 16: bad.append('the truthful set registered %d entries, wanted 16' % len(ok_ent))
if 'PROVEN: 16 ' not in ok_out: bad.append('the truthful set did not report 16 proven')
want = {'lie_clobber': 'r10 not returned', 'lie_ctail': 'tail exit into C', 'lie_cbare': 'r8 not returned',
        'lie_plt': 'r10 not returned', 'lie_r9': 'came in as an argument', 'lie_stack': 'left above the return address',
        'lie_gate': 'tail exit into C', 'lie_unregistered': 'does not name', 'lie_reload': 'r10 not returned', 'lie_misaligned': 'misaligned',
        'lie_read_after_call': 'reads r10 after a call', 'lie_r9_own': 'reads r9 after a call',
        'lie_xfer_nonrec': 'cannot follow', 'lie_xfer_r11rec': 'may not be one of the four', 'lie_xfer_disp': 'displacement D=16',
        'lie_xfer_pin': 'rbx (a pin) not restored', 'lie_xfer_r9': 'r9 not reloaded', 'lie_xfer_push': 'push after the switch',
        'lie_xfer_noswitch': 'no path of its body switches', 'lie_xfer_r10': 'r10 not record-restored', 'lie_xfer_tail': 'does not declare a transfer entry', 'lie_xfer_partial': 'r10 not record-restored'}
lines = [l for l in lie_out.split('\n') if 'VIOLATION' in l]
for name, frag in want.items():
    hit = [l for l in lines if (' ' + name + '+') in l or (' ' + name + ':') in l]
    if not hit: bad.append('the lie %s was NOT caught' % name)
    elif not any(frag in l for l in hit): bad.append('the lie %s was caught for the wrong reason: %s' % (name, hit[0].strip()))
if lie_rc != 1: bad.append('the lying set exited %d, wanted 1' % lie_rc)
if any(' inj_leaf2+' in l or ' inj_leaf2:' in l for l in lines): bad.append('the honest leaf inside the lying set was convicted')
for b in bad: print('  SELF-TEST FAIL  ' + b)
if not bad: print('  SELF-TEST PASS  16 truthful forms proven (5 of them transfers); 22 lies caught by name and for the right reason (10 of them transfers); the honest leaf beside them proven')
sys.exit(1 if bad else 0)
PY
inj_rc=$?
cat "$WORK/inj.verdict"

if [ "$real_rc" -eq 2 ] || [ "$ok_rc" -eq 2 ] || [ "$lie_rc" -eq 2 ]; then echo "REFUSED(2): the walker could not measure"; exit 2; fi
r9rows="$(grep -E '^\s*\{ "[^"]+", [A-Z0-9_|]*RTCC_C_R9' "$TABLE" | sed -E 's/^\s*\{ "([^"]+)".*/\1/' | tr '\n' ' ')"
echo "=== THE GVA BASE IS NEVER A RECORDED WRITE ==="
if [ -n "$r9rows" ]; then
    echo "  VIOLATION  the table records r9 for: $r9rows-- every exit of an entry, a C tail included, leaves by RTX_GVA_R9 then ret, because a call_bare site re-establishes nothing after the call (cto 2026-10-07, on the veneer row's r9 rule)"
    real_rc=1
else
    echo "  ok  no row of $TABLE names RTCC_C_R9"
fi
if [ "$real_rc" -eq 0 ] && [ "$inj_rc" -eq 0 ]; then
    echo "PASS: all $n_entries RTX entries keep the RTCC four on every path, and the walker catches every planted lie."
    exit 0
fi
[ "$real_rc" -ne 0 ] && echo "FAIL: the real runtime has entries that break the contract (listed above)."
[ "$inj_rc" -ne 0 ] && echo "FAIL: the walker's self-test failed -- its green on the real runtime cannot be trusted."
exit 1
