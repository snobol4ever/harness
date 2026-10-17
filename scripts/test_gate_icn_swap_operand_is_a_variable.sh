#!/bin/bash
# Icon's `:=:` yields a VARIABLE, not a value, so a swap operand may itself be an assignment or another
# swap. SCRIP's Icon lowerer only recognises a plain name (or a subscript/section/field lvalue) there;
# anything else falls through to the by-name IR_SWAP path. Row
# icon-chained-swap-and-non-plain-swap-operands-abort-or-swap-the-wrong-values.
#
# ⛔ THE CLASS HAS TWO HALVES AND ONLY ONE OF THEM IS LOUD -- measured against iconx 2026-09-05 (hq_B):
#   x :=: y :=: z          SCRIP rc=134 FATAL "IR op=122 has no template" -- the guard sink inside the
#                          IR_SWAP case (emit.cpp), not a missing template; iconx prints 312
#   x :=: (y := 5)         SCRIP rc=0 prints 21 -- WRONG WHILE EXITING CLEANLY; iconx prints 51
#   (x := 7) :=: y         SCRIP rc=0 prints 21 -- WRONG WHILE EXITING CLEANLY; iconx prints 27
# The silent half is the reason this gate grades by VALUE: a compiles-or-not check, or a crash census,
# sees the chain and calls the class cured while the inner assignment's effect is still being dropped.
#
# Control arms, both already correct today, so a cure that breaks them is caught here and not on a board:
#   x :=: y                the plain two-name swap                     -> 21
#   L[1] :=: L[2]          the subscript lvalue path (IR_SWAP_VAR)     -> 21
#
# ⛔ REFUSES rc=2 unless all 12 runs (6 witnesses x 2 modes) are graded -- never skip-as-success.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)"; cd "$ROOT" || exit 2
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
printf 'procedure main()\n  x := 1; y := 2; z := 3;\n  x :=: y :=: z;\n  write(x,y,z);\nend\n'                > "$d/chain2.icn"
printf 'procedure main()\n  x := 1; y := 2; z := 3; w := 4;\n  x :=: y :=: z :=: w;\n  write(x,y,z,w);\nend\n' > "$d/chain3.icn"
printf 'procedure main()\n  x := 1; y := 2;\n  x :=: (y := 5);\n  write(x,y);\nend\n'                         > "$d/assign_rhs.icn"
printf 'procedure main()\n  x := 1; y := 2;\n  (x := 7) :=: y;\n  write(x,y);\nend\n'                         > "$d/assign_lhs.icn"
printf 'procedure main()\n  x := 1; y := 2;\n  x :=: y;\n  write(x,y);\nend\n'                                > "$d/plain.icn"
printf 'procedure main()\n  L := [1,2];\n  L[1] :=: L[2];\n  write(L[1],L[2]);\nend\n'                         > "$d/subscript.icn"
want_chain2=312; want_chain3=4123; want_assign_rhs=51; want_assign_lhs=27; want_plain=21; want_subscript=21
graded=0; bad=0
for w in chain2 chain3 assign_rhs assign_lhs plain subscript; do
    eval "want=\$want_$w"
    o=$(timeout -k 5 10 ./scrip "$d/$w.icn" </dev/null 2>&1); r=$?; graded=$((graded+1))
    if [ "$r" != 0 ] || [ "$o" != "$want" ]; then
        echo "  ⛔ RED m3 $w: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-90)] -- want rc=0 out=[$want] (iconx)"; bad=1
    fi
    if timeout -k 5 60 ./scrip --compile -o "$d/$w.s" "$d/$w.icn" </dev/null >/dev/null 2>&1 \
       && gcc -m64 -no-pie "$d/$w.s" -o "$d/$w.m4" -L./out -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then
        o=$(timeout -k 5 10 "$d/$w.m4" </dev/null 2>&1); r=$?; graded=$((graded+1))
        if [ "$r" != 0 ] || [ "$o" != "$want" ]; then
            echo "  ⛔ RED m4 $w: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-90)] -- want rc=0 out=[$want] (iconx)"; bad=1
        fi
    else
        graded=$((graded+1)); echo "  ⛔ RED m4 $w: does not compile/link"; bad=1
    fi
done
[ "$graded" = 12 ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the 12 required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [icn_swap_operand_is_a_variable]: a non-plain swap operand still aborts or swaps the wrong values"; exit 1; }
echo "✅ GATE OK [icn_swap_operand_is_a_variable]: chained and assignment-operand swaps match iconx by VALUE, BOTH modes"
