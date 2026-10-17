#!/usr/bin/env bash
# test_gate_runtime_trampolines_enter_generated_code_16_byte_aligned.sh -- every hand-written trampoline that jumps
# into generated code must leave RSP where the x86-64 ABI says a called function's stack sits, because everything
# below that jump is C: the generated code calls the runtime, the runtime calls glibc, and glibc is entitled to use
# aligned SSE against its own frame.
#
# ⛔ THE DEFECT THIS WAS WRITTEN FOR (ceo 2026-09-14, row snobol4-generated-code-enters-the-c-runtime-with-the-stack-
# misaligned-by-eight). `rt_proc_enter_named` pushes SIX registers (rsi plus the five callee-saved) where its sibling
# `rt_proc_enter` pushes five, and nothing compensated for the parity flip -- so every procedure entered through it
# ran 8 bytes off, and so did every C frame it went on to call. `rt_proc_enter_frag` does the SAME six pushes and
# then `subq $8, %rsp`, with a matching `addq $8` in both exit paths: the compensation existed, was written by
# someone who understood exactly this, and was missing from the one trampoline beside it.
#
# ⭐ WHY IT SURVIVED SO LONG, WHICH IS THE PART WORTH GATING RATHER THAN FIXING: a misaligned stack is not an error.
# It runs. Hundreds of calls return correct answers on it. It faults only when a callee happens to use a 16-byte
# aligned SSE store -- here glibc's vsnprintf, reached through an unrelated DATA() buildplan hook -- so the symptom
# lands arbitrarily far from the cause, in a different language's library, and reads as a SNOBOL4 semantic defect.
# Measured on AI SNOBOL's SIR: 2298 of 2438 runtime calls correctly aligned, 140 not, the flip at one APPLY.
#
# ⛔ THIS IS A SOURCE GATE AND SAYS SO. It does not run a program and cannot see a misalignment introduced by
# emitted code; it holds the five hand-written trampolines, which is where this class lives because they are the
# only places we hand-count pushes. A dynamic arm belongs with the witness, not here.
#
# THE ARITHMETIC, stated so the next reader can check it by hand rather than trusting the parser: a trampoline is
# entered by a CALL, so RSP ≡ 8 (mod 16) at its first instruction. It then pushes N quadwords and subtracts S bytes
# before `jmp *%rax`. Generated code is entered as if CALLED (its own return addresses are the last two pushes), the
# convention rt_outer_call sets, so the requirement is:  8 - 8N - S ≡ 0  (mod 16).
#
# NO BUILD NEEDED (pure source census, <1s). rc=0 clean · rc=1 a trampoline lands on the wrong parity · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$HERE/../../SCRIP/src/runtime/rt/rt.c"
EVAL="$HERE/../../SCRIP/src/runtime/runtime_eval.c"
[ -f "$SRC" ] || { echo "⛔ REFUSES rc=2: cannot read $SRC"; exit 2; }
[ -f "$EVAL" ] || { echo "⛔ REFUSES rc=2: cannot read $EVAL"; exit 2; }

python3 - "$SRC" "$EVAL" <<'PY'
import re, sys

want = 0          # required RSP mod 16 at the jmp into generated code
entry = 8         # RSP mod 16 at a trampoline's first instruction, because a CALL got us here
found, bad, refused, dyn, loaded = [], [], [], [], []

for path in sys.argv[1:]:
    text = open(path, encoding="utf-8").read()
    # Each trampoline is one __asm__("...") block naming a global and ending in a jmp through a register.
    for blk in re.findall(r'__asm__\s*\((.*?)\);', text, re.S):
        # ⛔ THE NAME IS MATCHED ANYWHERE IN THE BLOCK, NOT ONLY AS A LINE OF ITS OWN. rt_outer_call writes
        # ".globl rt_outer_call\n.type rt_outer_call, @function\n" as ONE string literal, so a per-string pattern
        # skipped it in silence -- the first draft of this gate held seven trampolines and reported that as all of
        # them. A census that cannot say how many it did not see is the shape this file exists to refuse.
        names = re.findall(r'\.globl\s+(\w+)', blk)
        if not names:
            continue
        name = names[0]
        lines = re.findall(r'"([^"]*)\\n"', blk)
        n_push, sub, seen_jmp, dynamic, ld = 0, 0, False, False, None
        for ln in lines:
            s = ln.strip()
            # ⛔ A JUMP INTO rt_chain_enter's SEED TAIL IS AN ENTRY TOO -- kept for the shape, its one member deleted by CEO-1468 (row snobol4-the-setexit-landing-2b89a5ef2-added-a-third-asm-
            # transfer-...): rt_unwind_to_activation loads RSP from its recorded base and then shares rt_chain_enter's one
            # `jmp *%rax` through .Lrt_chain_seed instead of carrying a third. Without this arm its block would read as
            # 'not an entry trampoline' and the RSP-LOADED class below would stop holding its displacement, in silence.
            if re.match(r'^jmp\s+(\*%\w+|\.Lrt_chain_seed\b)', s):
                seen_jmp = True
                break
            if re.match(r'^pushq?\s+%\w+', s):
                n_push += 1
            m = re.match(r'^subq?\s+\$(\d+),\s*%rsp', s)
            if m:
                sub += int(m.group(1))
            m = re.match(r'^addq?\s+\$(\d+),\s*%rsp', s)
            if m:
                sub -= int(m.group(1))
            # ⛔ A REGISTER-SIZED ADJUSTMENT IS NOT STATICALLY DECIDABLE AND IS NOT A FAILURE. rt_tiny_record_enter
            # sizes its frame from the argument count (leaq 56(%rdx),%rcx; subq %rcx,%rsp), so its parity is a
            # runtime value and this gate CANNOT compute it. Reading that as red is exactly the false red this
            # gate exists to prevent -- measured 2026-09-14, it was this gate's own first output.
            if re.match(r'^(sub|add)q?\s+%\w+,\s*%rsp', s):
                dynamic = True
            # ⛔ AN RSP LOADED FROM A RECORDED BASE IS A THIRD CASE, NEITHER OK NOR OFF: rt_unwind_to_activation (row
            # snobol4-a-setexit-handler-runs-at-top-level-so-freturn-from-it-is-error-242) does not arrive by CALL-and-push
            # arithmetic at all -- it puts RSP back on an activation's wire pair that was recorded where that activation
            # was entered, so its parity is the recorded base's. What this gate CAN hold statically is the displacement:
            # it must be a multiple of 16, or the jump lands off the base's parity whatever the base was. The base's own
            # alignment is checked at run time by the caller before the jump (core_setexit_handler_return refuses an
            # unaligned base and keeps ERROR 242), and it is printed here as its own class, never counted green.
            m = re.match(r'^(?:leaq?\s+(-?\d*)\(%\w+\)|movq?\s+%\w+),\s*%rsp$', s)
            if m and 'rbp' not in s:
                ld = int(m.group(1) or 0) if m.group(1) is not None else 0
        if not seen_jmp:
            continue                      # not an entry trampoline: nothing to hold
        if ld is not None:
            loaded.append((name, ld))
            if ld % 16 != 0:
                bad.append((name, 0, ld, ld % 16, path))
            continue
        if dynamic:
            # It is held to a DIFFERENT property it can actually be held to: a frame-pointer trampoline must put
            # RSP back from RBP in EVERY exit path, or the pops below read the callee's leftovers.
            tail = lines[lines.index(ln) + 1:] if ln in lines else []
            exits = [t for t in tail if re.match(r'^\s*popq?\s+%r15', t)]
            restores = [t for t in tail if re.search(r'lea[q]?\s+-?\d*\(%rbp\),\s*%rsp|movq?\s+%rbp,\s*%rsp|leave', t)]
            dyn.append((name, len(exits), len(restores)))
            if exits and len(restores) < len(exits):
                refused.append((name, "%d exit path(s) pop callee-saved registers but only %d restore RSP from RBP" % (len(exits), len(restores))))
            continue
        got = (entry - 8 * n_push - sub) % 16
        found.append((name, n_push, sub, got))
        if got != want:
            bad.append((name, n_push, sub, got, path))

print("runtime trampolines that jump into generated code -- RSP at the jump, mod 16")
print("  %-26s %6s %10s %8s  %s" % ("TRAMPOLINE", "PUSHES", "SUB BYTES", "RSP%16", "VERDICT"))
for name, n, s, got in found:
    print("  %-26s %6d %10d %8d  %s" % (name, n, s, got, "OK" if got == want else "⛔ OFF BY %d" % ((got - want) % 16)))

for name, nex, nres in dyn:
    print("  %-26s %6s %10s %8s  ---- NOT STATICALLY DECIDABLE (register-sized frame; %d exit(s), %d RSP-from-RBP restore(s))"
          % (name, "-", "dynamic", "-", nex, nres))

for name, d in loaded:
    print("  %-26s %6s %10s %8s  %s" % (name, "-", "load", "-", ("---- RSP LOADED FROM A RECORDED BASE + %d (parity inherited; displacement held to 0 mod 16, base checked at run time)" % d) if d % 16 == 0 else ("⛔ DISPLACEMENT %d IS NOT 0 (mod 16)" % d)))

if refused:
    print()
    print("⛔ REFUSES rc=2: %d dynamic trampoline(s) do not restore RSP from RBP on every exit." % len(refused))
    for name, why in refused:
        print("   %s: %s" % (name, why))
    sys.exit(2)
if not found and not dyn:
    print("✅ no runtime trampoline jumps into generated code from C any more (ceo 2026-10-09, CEO-1576, the C-to-BB removal): the family rt_proc_enter, rt_proc_enter_named, rt_tiny_record_enter, rt_chain_enter, rt_chain_enter_v is deleted and nothing statically-decidable or dynamic remains to measure; the %d RSP-loading trampoline(s) above (the SETEXIT continue, entered from the box) stay held to their 16-byte displacement; a trampoline put back re-arms this gate by itself" % len(loaded))
    sys.exit(0)
if not found:
    print("⛔ REFUSES rc=2: no trampoline matched -- the asm blocks moved and this gate is blind, which is not a pass.")
    sys.exit(2)
if len(found) < 3:
    print("⛔ REFUSES rc=2: only %d trampoline(s) found; this gate expects the family (rt_chain_enter, rt_chain_enter_v," % len(found))
    print("   rt_proc_enter_named; rt_proc_enter_frag DELETED under CEO-1576 2026-10-09, the C-to-BB removal). A shrinking population is a")
    print("   blind gate, not a clean one: this floor follows the tree DOWN one deletion at a time, re-cut in the landing that deletes, never ahead of it.")
    sys.exit(2)
if bad:
    print()
    print("⛔ GATE FAILED: %d trampoline(s) enter generated code on the wrong 16-byte parity." % len(bad))
    for name, n, s, got, path in bad:
        print("   %s (%s): %d pushes + %d sub bytes leaves RSP ≡ %d (mod 16), want %d." % (name, path.split('/')[-1], n, s, got, want))
    print("   ⭐ THE CURE IS THE ONE ITS OWN SIBLING ALREADY USES: rt_proc_enter_frag compensates six pushes with")
    print("      `subq $8, %rsp` and undoes it with `addq $8, %rsp` in EVERY exit path. Add both halves or neither --")
    print("      a sub with no matching add corrupts the return instead of the callee.")
    print("   ⛔ DO NOT 'fix' this by aligning at the call sites in emitted code: that masks an already-odd spine and")
    print("      the next callee to use an aligned SSE store faults somewhere else entirely.")
    sys.exit(1)
print()
print("✅ GATE OK: all %d statically-decidable trampoline(s) enter generated code with RSP ≡ 0 (mod 16), as a CALL would" % len(found))
print("   leave it; %d dynamic trampoline(s) named above are held to the RBP-restore property instead, never counted green," % len(dyn))
print("   and %d RSP-loading trampoline(s) are held to a 16-byte displacement, never counted green." % len(loaded))
PY
exit $?
