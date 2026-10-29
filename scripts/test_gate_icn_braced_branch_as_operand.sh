#!/bin/bash
# A control structure's CLOSING BRACE must not end the expression: icont continues parsing a binary
# operator after it, SCRIP raises "expected ; (got <op>)". Row
# icon-braced-control-branch-cannot-be-followed-by-a-binary-operator.
#
# ⛔ THE TWO FORMS NEED DIFFERENT ANSWERS, which is the trap in the obvious "just let the expression
# continue after }" cure -- measured against iconx 2026-09-05 (hq_B), x=1 in both:
#   case x of { default: 1 } + 2        icont = 3  -- the CASE VALUE is the LEFT OPERAND (1+2)
#   if x then {1} else {9} + 2          icont = 1  -- the operator is ABSORBED INTO THE ELSE BRANCH,
#                                                     i.e. if x then {1} else ({9}+2), NOT (if...)+2
# A cure that makes both bind as a left operand yields 3 and 3, and the second is then wrong while
# compiling cleanly -- a false green that only a VALUE check catches, never a compiles-or-not check.
#
# Scope, measured, so the cure is not narrowed to `case`:
#   any binary operator, not just ||| -- '+', '||', '<' all raise "expected ;"
#   LEFT operand only -- `1 + case x of {...}` already compiles
#   NOT every closing brace -- a bare block `{1} + 2` already compiles and gives 3
# Real-world origin: corpus/packages/icon/ipl/procs/io.icn:365 ends a procedure with
# `} ||| ([&null ~=== x[2]] | []);` and io.icn is linked by much of IPL (hq_I, IPL suite).
#
# ⛔ REFUSES rc=2 unless all 4 runs (2 witnesses x 2 modes) are graded -- never skip-as-success.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }; cd "$ROOT" || exit 2
[ -x ./scrip ] && [ -f out/libscrip_rt.so ] || { echo "⛔ GATE REFUSES (rc=2): scrip/runtime not built at $ROOT"; exit 2; }
d=$(mktemp -d) || exit 2; trap 'rm -rf "$d"' EXIT
printf 'procedure f(x)\n  return case x of { default: 1 } + 2;\nend\nprocedure main()\n  write(f(1));\nend\n' > "$d/case_lhs.icn"
printf 'procedure f(x)\n  return if x then {1} else {9} + 2;\nend\nprocedure main()\n  write(f(1));\nend\n'    > "$d/if_else_brace.icn"
want_case_lhs=3; want_if_else_brace=1
graded=0; bad=0
for w in case_lhs if_else_brace; do
    eval "want=\$want_$w"
    o=$(timeout -k 5 10 ./scrip "$d/$w.icn" </dev/null 2>&1); r=$?; graded=$((graded+1))
    if [ "$r" != 0 ] || [ "$o" != "$want" ]; then
        echo "  ⛔ RED m3 $w: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-90)] -- want rc=0 out=[$want] (iconx)"; bad=1
    fi
    if timeout -k 5 60 ./scrip --compile --out="$d/$w.s" "$d/$w.icn" </dev/null >/dev/null 2>&1 \
       && gcc -m64 -no-pie "$d/$w.s" -o "$d/$w.m4" -L./out -lscrip_rt -Wl,-rpath,"$ROOT/out" -lm -lpthread 2>/dev/null; then
        o=$(timeout -k 5 10 "$d/$w.m4" </dev/null 2>&1); r=$?; graded=$((graded+1))
        if [ "$r" != 0 ] || [ "$o" != "$want" ]; then
            echo "  ⛔ RED m4 $w: rc=$r out=[$(printf '%s' "$o" | tr '\n' '|' | cut -c1-90)] -- want rc=0 out=[$want] (iconx)"; bad=1
        fi
    else
        graded=$((graded+1)); echo "  ⛔ RED m4 $w: does not compile/link (the parse gap itself, today)"; bad=1
    fi
done
[ "$graded" = 4 ] || { echo "⛔ GATE REFUSES (rc=2): graded $graded of the 4 required runs"; exit 2; }
[ "$bad" = 0 ] || { echo "⛔ GATE RED [icn_braced_branch_as_operand]: a closing brace still ends the expression"; exit 1; }
echo "✅ GATE OK [icn_braced_branch_as_operand]: case-as-left-operand = 3 and if-else-brace-absorbs = 1, BOTH modes"
