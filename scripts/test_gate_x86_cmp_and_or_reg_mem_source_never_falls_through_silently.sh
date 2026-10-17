#!/usr/bin/env bash
# test_gate_x86_cmp_and_or_reg_mem_source_never_falls_through_silently.sh
# row encoder-cmp-and-or-reg-mem-source-falls-through-to-empty-string
#
# WHY THIS EXISTS: x86_asm.h's cmp/and/or dispatch matched a register-dest + memory-source form
# (cmp rdi, [r13+32], same shape for and/or) against none of its explicit arms. cmp's FATAL guard
# tested only the DESTINATION operand kind, so it never fired; and/or had no guard at all. Every
# such call fell through to `return std::string()` -- NO instruction emitted, and a following jcc
# then reads STALE FLAGS. Silent. hq_prolog's R4.1 work hit exactly this shape. Census over the
# live tree at claim time found zero current call sites landing in the gap (the one committed
# trail-unwind site, x86_pl_tr_unwind_at, avoids it with a mov-then-cmp-reg-reg workaround) -- this
# gate is therefore the only thing standing between a future caller and the same silent drop.
#
# PROOF SHAPE (five arms, each a DIFFERENT failure mode -- a probe that cannot show its own
# negative is worthless, same philosophy as test_gate_rtx_ctor_armed.sh):
#   GOOD    -- the new REG+[REG+disp] forms for cmp/and/or encode to the exact bytes an
#              independent `objdump -D -b binary` disassembly confirms, in BOTH media.
#   BAD_CMP/BAD_AND/BAD_OR -- a DIFFERENT still-unhandled frame/cell source (FR64) for each
#              mnemonic must now abort loudly (SIGABRT, FATAL message naming the mnemonic) rather
#              than silently returning empty. This is the actual bug class closing, not just the
#              one named case working.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../SCRIP" && pwd)"
SRC="$ROOT/../harness/scripts/probe_x86_cmp_and_or_reg_mem_source.cpp"
SO="$ROOT/out/libscrip_rt.so"
[ -f "$SRC" ] || { echo "FATAL: $SRC missing"; exit 1; }
[ -f "$SO" ]  || { echo "FATAL: $SO missing -- run 'make' first"; exit 1; }
WORKDIR="$(mktemp -d)"; trap 'rm -rf "$WORKDIR"' EXIT
gcc -O0 -g -fno-strict-aliasing -fwrapv -fno-omit-frame-pointer -w -std=c++17 -finput-charset=UTF-8 \
    -I "$ROOT/src" -I "$ROOT/src/ir" -I "$ROOT/src/lower" -I "$ROOT/src/emitter" -I "$ROOT/src/runtime/core" \
    -I "$ROOT/src/runtime/builtins" -I "$ROOT/src/runtime" -I "$ROOT/src/runtime/rt" -I "$ROOT/src/parsers/snobol4" \
    -I "$ROOT/src/parsers/raku" -I "$ROOT/src/optimizer" -I "$ROOT/src/templates/bb" -I "$ROOT/src/templates/xa" \
    -I "$ROOT/src/templates/x86" -c "$SRC" -o "$WORKDIR/probe.o" || { echo "FATAL: probe failed to compile"; exit 1; }
g++ -m64 -no-pie "$WORKDIR/probe.o" -Wl,-rpath,"$ROOT/out" -L"$ROOT/out" -lscrip_rt -lm -lpthread -o "$WORKDIR/probe" \
    || { echo "FATAL: probe failed to link"; exit 1; }
FAIL=0
echo "=== GOOD -- cmp/and/or rdi, qword ptr [r13 + 32], both media ==="
out="$("$WORKDIR/probe" good)"; rc=$?
printf '%s\n' "$out"
if [ "$rc" -ne 0 ]; then echo "FAIL: good arm exited $rc, expected 0"; FAIL=1; fi
exp_cmp_bin="493bbd20000000"; exp_and_bin="4923bd20000000"; exp_or_bin="490bbd20000000"
for pair in "cmp_bin:$exp_cmp_bin" "and_bin:$exp_and_bin" "or_bin :$exp_or_bin"; do
    label="${pair%%:*}"; want="${pair##*:}"
    got="$(printf '%s\n' "$out" | grep "^$label" | awk '{print $2}')"
    if [ "$got" != "$want" ]; then echo "FAIL: $label got '$got' want '$want'"; FAIL=1
    else echo "  $label bytes verified: $got"
    fi
done
for pair in "cmp_txt:cmp" "and_txt:and" "or_txt :or"; do
    label="${pair%%:*}"; mnem="${pair##*:}"
    line="$(printf '%s\n' "$out" | grep "^$label")"
    case "$line" in
        *"$mnem"*"rdi, qword ptr [r13 + 32]"*) ;;
        *) echo "FAIL: $label unexpected text: $line"; FAIL=1 ;;
    esac
done
echo
echo "=== BAD arms -- a DIFFERENT still-unhandled frame/cell source (FR64) must abort, not vanish ==="
for m in bad_cmp bad_and bad_or; do
    mnem="${m#bad_}"
    errfile="$WORKDIR/$m.err"
    "$WORKDIR/probe" "$m" >"$WORKDIR/$m.out" 2>"$errfile"; rc=$?
    if [ "$rc" -eq 134 ] && grep -q "FATAL x86(\"$mnem\")" "$errfile"; then
        echo "  $m: ABORTED as required (rc=134, FATAL names \"$mnem\")"
    else
        echo "FAIL: $m rc=$rc (want 134) stderr follows:"; sed 's/^/    /' "$errfile"; FAIL=1
    fi
done
echo
if [ "$FAIL" -ne 0 ]; then echo "GATE: FAIL"; exit 1; fi
echo "GATE: PASS -- the named silent-drop case now encodes correctly in both media (objdump-verified at authorship time), and the surrounding frame/cell gap now refuses loudly instead of vanishing."
exit 0
