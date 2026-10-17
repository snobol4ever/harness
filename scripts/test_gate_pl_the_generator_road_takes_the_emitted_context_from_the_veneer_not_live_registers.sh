#!/usr/bin/env bash
# test_gate_pl_the_generator_road_takes_the_emitted_context_from_the_veneer_not_live_registers.sh -- THE C META-CALL GENERATOR NEVER READS LIVE CALLEE-SAVED REGISTERS.
# hq_prolog 2026-10-04, row prolog-bb-the-generator-road-takes-the-emitted-context-from-the-veneer-not-live-callee-saved-registers (the cfo's
# finding, 2026-10-04: rt_proc_call_gen_h captures rbx, r12-r15 with inline asm from inside C and restores them in the generator's thread for the
# emitted Prolog body -- whatever C frame sits between emitted code and that capture and keeps a value in a callee-saved register breaks the
# generator; the fixed-tables batch did exactly that (a VLA key in rt_pl_goal_gen_h_c kept its bookkeeping in a callee-saved register under
# gcc -O0, and a user portray/1 under format ~p died in rt_pl_tr_gc_sync with cx->tr pointing into the caller's stack; cured at 476b4fc91 by
# keeping that frame fixed-size, which is a workaround). The shape: the rtx entry veneer saves the five callee-saved registers into the context
# frame it already builds (tr, b, ball, then rbx, r14, r15), rt_proc_call_gen_h takes them as an argument, and the two C callers (the gen road
# and the writer's portray hook) pass the context's copy -- nothing C-side reads a live register.
# ARM 1: rt.c holds no inline-asm capture of callee-saved registers (the movq rbx/r12-r15 asm string count is 0; 1 on origin c5e4896b9).
# ARM 2: the cfo's witness (a user portray/1 under format ~p) answers 3 in m3 and m4 -- the behaviour the cure must keep.
# RED BEFORE on origin c5e4896b9: arm 1 counts 1.
set -u
GATE_NAME=test_gate_pl_the_generator_road_takes_the_emitted_context_from_the_veneer_not_live_registers
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIP="${SCRIP_BIN:-$HERE/../../SCRIP/scrip}"
RT="${RT_DIR:-$(dirname "$SCRIP")/out}"
SRC="$HERE/../../SCRIP/src/runtime/rt/rt.c"
refuse() { echo "⛔ REFUSED(2) [$GATE_NAME]: $*" >&2; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- run make first"
[ -f "$SRC" ] || refuse "no $SRC"
[ -n "${SCRIP_BIN:-}" ] || "$HERE/util_require_fresh.sh" --gate "$GATE_NAME" "$SCRIP" "$RT/libscrip_rt.so" || exit 2
TMPD="$(mktemp -d)"; trap 'rm -rf "$TMPD"' EXIT
red=0
BND="$HERE/../../SCRIP/src/runtime/by_name_dispatch.c"; [ -f "$BND" ] || refuse "no $BND"
c=$(awk '/^DESCR_t rt_pl_goal_gen_h_c\(/{p=1} p && /rt_proc_call_gen_h\(key, ar \+ n, hslot, [a-z_]+\)/{n++} p && /^}/{exit} END{print n+0}' "$BND")
h=$(grep -cE 'rt_proc_call_gen_h\(const char \*, int, void \*\*, const uint64_t \*\)' "$HERE/../../SCRIP/src/runtime/rt/rt.h")
if [ "$c" = 1 ] && [ "$h" = 1 ]; then echo "  ok  arm 1: the Prolog gen road (rt_pl_goal_gen_h_c) hands the generator the five context words from the veneer's frame"
else echo "  RED arm 1: the Prolog gen road still calls rt_proc_call_gen_h without the context words (call with regs: $c, prototype with regs: $h)"; red=$((red+1)); fi
cat > "$TMPD/w.pl" <<'EOP'
:- dynamic(portray/1).
portray(F) :- float(F), I is truncate(F), write(I).
main :- format("~p", [3.14]), nl, format("~p~n", [f(2.5, x)]), X = 7.9, format("~p-~w~n", [X, X]).
:- initialization(main).
EOP
want='3
f(2,x)
7-7.9'
for mode in m3 m4; do
    if [ "$mode" = m3 ]; then got="$(cd "$TMPD" && timeout -k 5 60 "$SCRIP" w.pl </dev/null 2>"$TMPD/err")"; rc=$?
    else
        timeout -k 5 120 "$SCRIP" --compile -o "$TMPD/w.s" "$TMPD/w.pl" </dev/null 2>"$TMPD/err" || { echo "  RED w $mode: the compile refused: $(head -c 160 "$TMPD/err")"; red=$((red+1)); continue; }
        gcc -m64 -no-pie "$TMPD/w.s" -o "$TMPD/w.bin" -L"$RT" -lscrip_rt -Wl,-rpath,"$RT" -lm 2>"$TMPD/err" || { echo "  RED w $mode: the assembler or linker refused: $(grep -m1 -E 'Error|error' "$TMPD/err" | head -c 200)"; red=$((red+1)); continue; }
        got="$(cd "$TMPD" && timeout -k 5 60 ./w.bin </dev/null 2>"$TMPD/err")"; rc=$?
    fi
    if [ "$rc" = 0 ] && [ "$got" = "$want" ]; then echo "  ok  arm 2 $mode: a user portray/1 under format ~p answers through the generator road"
    else echo "  RED arm 2 $mode: rc=$rc out=[$(printf '%s' "$got" | tr '\n' '|' | cut -c1-120)] err=[$(head -c 160 "$TMPD/err" | tr '\n' '|')]"; red=$((red+1)); fi
done
[ "$red" = 0 ] || { echo "GATE FAIL [$GATE_NAME]: $red arm(s) red"; exit 1; }
echo "GATE PASS [$GATE_NAME]: the generator road takes the emitted context from the veneer's frame, and a user portray/1 under format ~p answers in both modes"
exit 0
