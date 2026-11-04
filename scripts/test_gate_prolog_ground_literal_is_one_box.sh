#!/usr/bin/env bash
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
# test_gate_prolog_ground_literal_is_one_box.sh -- A GROUND LITERAL TERM IS ONE BOX AND A CELL TABLE, NOT A BOX PER CELL (the cto, 2026-11-04, R-2121; TRIO row 5,
# hakank_swi_stable_marriage). Before it a ground compound literal in a clause lowered to two LIT_INTEGER boxes and a $mkc leaf call per cell, about 180 lines of asm
# and 90 KB of compiler memory per list element (MEASURED on 0150f42f3: a 40x40 pair of literal matrices made 1,007,187 lines against the empty clause's 414,640, and
# the two 100x100 matrices of hakank_swi_stable_marriage never finished compiling in 429 s at 3.9 GB). Now lower_prolog.c serializes a ground compound that has a
# compound inside it into g_stage2.pl_ground_words ({tag word, value} pairs; a compound's value is nargs << 32 | the index of its argument run) and emits ONE
# IR_CALL "$mkground" naming the slice; the leaf-call template lays the table after the box and calls rt_pl_mkground(table, &result), which allocates each compound's
# argument block (HB_DVEC, as $mkc does) and fills it, iterating down the last argument; one poll after the call. A flat ground compound (foo(1,2), [a]) stays on $mkc.
# ARMS: (1) IR: the clause problem/2 of the probe (two 40x40 ground matrices) carries exactly two $mkground nodes and no $mkc; the clause flat/1 (foo(1,2)) carries one
#           $mkc and no $mkground (the flat road is kept, so the goal checks that read $mkc keep reading)
#       (2) SIZE: the mode-4 .s of the probe exceeds that of the same probe with both matrices replaced by [] by at most 8 lines per element (3,200 elements; MEASURED
#           4.2 after, 180 before)
#       (3) ANSWER: the probe's stdout equals swipl's (swipl -q -t halt, so no toplevel newline follows the initialization goal) in mode 3, in mode 4 and in mode 3 under SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_FLIP=1 (the [GC- banner filtered)
# RED ONCE WITHOUT A PLANT: on 0150f42f3 (the parent) arm 1 reads 0 $mkground and arm 2 reads 185 lines per element.
# rc 0 held · rc 1 a bar unmet · rc 2 cannot measure (no scrip, no swipl, a compile or link refused)
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${S4E_HOME:-$(cd "$HERE/../.." && pwd)}"
NAME=prolog_ground_literal_is_one_box
refuse() { echo "⛔ REFUSED(2) [$NAME]: $*"; exit 2; }
SCRIP="$ROOT/SCRIP/scrip"
[ -x "$SCRIP" ] || refuse "no $SCRIP"
. "$HERE/lib_oracle_flags.sh" || refuse "lib_oracle_flags.sh is missing"
SW="$(swipl_bin)" || refuse "the swipl oracle accessor refused"
[ -x "$SW" ] || refuse "swipl is not executable: $SW"
T="$(mktemp -d)" || refuse "mktemp failed"; trap 'rm -rf "$T"' EXIT
python3 -I - "$T" <<'PY' || refuse "the probe could not be written"
import sys
t = sys.argv[1]
def row(n, s): return '[' + ','.join(str((i * 7 + s) % 97 + 1) for i in range(n)) + ']'
def mat(n, s): return '[' + ',\n'.join(row(n, s + i) for i in range(n)) + ']'
head = ":- initialization(main).\nflat(F) :- F = foo(1,2).\np(1, [a,b,c]).\np(2, [1,2.5,'x y',[]]).\np(3, f(g(1,2),h([a|[b]]),[k])).\np(4, point(1,2)-[x,y|z]).\n"
main = ("main :- forall(p(I,X), (write(I), write(' '), writeq(X), nl)), flat(F), writeq(F), nl, problem(M, W), length(M, LM), length(W, LW), write(LM-LW), nl,\n"
        "        nth1(17, M, R17), nth1(23, R17, E), write(E), nl, last(W, LastRow), sum_list(LastRow, S), write(S), nl, p(3, T), T = f(A, B, C), writeq(A-B-C), nl,\n"
        "        ( p(1, [a,b,c]) -> write(yes) ; write(no) ), nl, ( p(1, [a,b]) -> write(yes) ; write(no) ), nl, copy_term([x,f(y)], CT), writeq(CT), nl.\n")
open(t + '/probe.pl', 'w').write(head + 'problem(M, W) :-\nM = ' + mat(40, 0) + ',\nW = ' + mat(40, 3) + '.\n' + main)
open(t + '/empty.pl', 'w').write(head + 'problem(M, W) :-\nM = [],\nW = [].\n' + main)
PY
cd "$T" || refuse "cannot enter $T"
rc=0
"$SCRIP" --dump-ir probe.pl < /dev/null > probe.ir 2>/dev/null || refuse "--dump-ir refused"
graph() { awk -v want="; proc $1" '$0 == want {p=1; next} p && /^; proc / {exit} p' probe.ir; }
gm="$(graph problem/2 | grep -c '"\$mkground"')"; gc="$(graph problem/2 | grep -c '"\$mkc"')"; fm="$(graph flat/1 | grep -c '"\$mkground"')"; fc="$(graph flat/1 | grep -c '"\$mkc"')"
[ -n "$(graph problem/2)" ] && [ -n "$(graph flat/1)" ] || refuse "the probe's graphs problem/2 and flat/1 are not in the IR dump"
if [ "$gm" = 2 ] && [ "$gc" = 0 ] && [ "$fm" = 0 ] && [ "$fc" = 1 ]; then echo "  ok   arm 1 (IR): problem/2 carries 2 \$mkground and 0 \$mkc; flat/1 carries 0 \$mkground and 1 \$mkc"
else echo "  ⛔ FAIL arm 1 (IR): problem/2 carries $gm \$mkground and $gc \$mkc (want 2 and 0); flat/1 carries $fm \$mkground and $fc \$mkc (want 0 and 1)"; rc=1; fi
"$SCRIP" --compile --out=probe.s probe.pl < /dev/null 2>/dev/null || refuse "the mode-4 compile of the probe refused"
"$SCRIP" --compile --out=empty.s empty.pl < /dev/null 2>/dev/null || refuse "the mode-4 compile of the empty probe refused"
pl="$(wc -l < probe.s)"; el="$(wc -l < empty.s)"; per=$(( (pl - el) / 3200 ))
if [ "$per" -le 8 ]; then echo "  ok   arm 2 (SIZE): $pl - $el = $((pl - el)) lines for 3,200 elements, $per per element (bar 8)"
else echo "  ⛔ FAIL arm 2 (SIZE): $pl - $el = $((pl - el)) lines for 3,200 elements, $per per element (bar 8)"; rc=1; fi
timeout -k 5 120 "$SW" -q -t halt probe.pl < /dev/null > ref.out 2> ref.err || refuse "swipl refused the probe: $(head -c 200 ref.err)"
[ -s ref.out ] || refuse "swipl printed nothing"
timeout -k 5 300 "$SCRIP" probe.pl < /dev/null > m3.out 2>/dev/null; m3rc=$?
gcc probe.s -L"$ROOT/SCRIP/out" -lscrip_rt -lm -Wl,-rpath,"$ROOT/SCRIP/out" -o probe.bin 2> ld.err || refuse "the link refused: $(head -c 200 ld.err)"
timeout -k 5 300 ./probe.bin < /dev/null > m4.out 2>/dev/null; m4rc=$?
SCRIP_GC_STRESS=1 SCRIP_GC_PLANT_FLIP=1 timeout -k 5 600 "$SCRIP" probe.pl < /dev/null 2>/dev/null | grep -v '^\[GC-' > st.out; strc=$?
for a in "m3 $m3rc m3.out" "m4 $m4rc m4.out" "m3-stress-flip $strc st.out"; do set -- $a
    if [ "$2" = 0 ] && cmp -s ref.out "$3"; then echo "  ok   arm 3 ($1): stdout equals swipl's ($(wc -l < ref.out) lines)"
    else echo "  ⛔ FAIL arm 3 ($1): rc $2, stdout differs from swipl's: $(diff ref.out "$3" | head -3 | tr '\n' ' ' | cut -c1-200)"; rc=1; fi
done
[ "$rc" = 0 ] && { echo "GATE OK [$NAME]: a nested ground literal is one \$mkground box with a cell table ($per lines per element), the flat road is kept, both modes and the flip plant agree with swipl"; exit 0; }
echo "GATE FAIL [$NAME]"; exit 1
