#!/usr/bin/env bash
# test_gate_snocone_apply_of_a_snocone_function_carries_its_arguments_into_the_tiny_record.sh
#
# THE DEFECT (the ceo's rank-1 row snocone-apply-of-a-snocone-defined-function-crashes-scrip, CEO-1446; it killed the SCRIPtix
# demo infinite_snobol4.md at its own sample's line 262): APPLY('f', 2), APPLY(x, 3), EVAL("APPLY('f', 4)") and APPLY of an
# NRETURN Snocone function died with a general-protection fault in the slab (mode 3) or printed nothing (mode 4), where the
# transpile runs under sbl -bf and under SCRIP alike.
# THE CAUSE (measured under gdb): APPLY opens through rt_call_open_by_name_p, and for a Snocone function p->fn IS its tiny
# alpha, whose prologue reads its call record through rcx (count, gamma, omega, one offset per argument).  The tiny road
# (how=2) was guarded on nargs<=0 since 94cc8f6e2, because bb_glue_enter_c2bb's how==2 record had a literal zero count, so a
# call WITH arguments took the named road (how=1), whose glue arm jumps with rcx = a continuation label -- straight into the
# prologue's read.
# THE CURE: the glue's how==2 arm hands its record to rt_tiny_glue_enter (src/runtime/rt/rt_asm_helpers.S, jump-entered, box
# to asm to box), which takes the count from the how word (rt_c2bb_word(p, afn, 2, nargs)), builds the callee's record below
# the glue's with every argument copied out of g_call_args, and returns through its own stubs to the glue's continuation; the
# nargs guard is lifted (test_gate_the_tiny_open_protocol_and_its_glue_record_agree.sh holds the three sites together).
# A SNOBOL4 DEFINE'd function under APPLY now takes the same road: its NRETURN in value context answers sbl's value (it
# answered '' on the road it took before).
#
# Two programs, every answer cut from sbl -bf at run time (the Snocone one through scrip --transpile) and pinned: a pinned line
# sbl no longer prints is a REFUSAL, never a green.  Both modes.  rc=0 clean · rc=1 a divergence · rc=2 REFUSAL.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
B="$HERE/../../SCRIP"
SBL="${SBL:-/home/resources/x64/bin/sbl}"
refuse() { echo "⛔ REFUSES rc=2: $*"; exit 2; }
[ -x "$B/scrip" ] || refuse "$B/scrip is not built -- cannot measure"
[ -f "$B/out/libscrip_rt.so" ] || refuse "out/libscrip_rt.so is not built -- mode 4 cannot link"
[ -x "$SBL" ] || refuse "the SNOBOL4 oracle $SBL is absent -- the pinned lines cannot be confirmed"
"$HERE/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
D="$(mktemp -d)" || refuse "no scratch dir"
trap 'rm -rf "$D"' EXIT
cat > "$D/c.sc" <<'SC'
function f(inf_arg) { f = inf_arg + 1; return; }
function two(a, b) { two = a '-' b; return; }
function fr(x) { if (GT(x, 5)) { fr = x; return; } freturn; }
function fact(n) { if (LE(n, 1)) { fact = 1; return; } fact = n * APPLY('fact', n - 1); return; }
function h(k) { h = .inf_tab[k]; nreturn; }
function outer(v) { outer = 'outer ' APPLY('f', v); return; }
inf_tab = TABLE();
inf_tab[1] = 'one';
OUTPUT = 'apply ' APPLY('f', 2);
x = 'f';
OUTPUT = 'apply x ' APPLY(x, 3);
OUTPUT = 'two ' APPLY('two', 'a', 'b');
OUTPUT = 'two short ' APPLY('two', 'a');
OUTPUT = 'two long ' APPLY('two', 'a', 'b', 'c');
OUTPUT = 'fr ' APPLY('fr', 9);
if (APPLY('fr', 1)) { OUTPUT = 'fr matched'; } else { OUTPUT = 'fr failed'; }
OUTPUT = 'fact ' APPLY('fact', 5);
OUTPUT = 'nr ' APPLY('h', 1);
OUTPUT = outer(7);
OUTPUT = 'eval ' EVAL("APPLY('f', 4)");
OUTPUT = 'end';
SC
printf '%s\n' 'apply 3' 'apply x 4' 'two a-b' 'two short a-' 'two long a-b' 'fr 9' 'fr failed' 'fact 120' 'nr one' 'outer 8' 'eval 5' 'end' > "$D/c.want"
cat > "$D/s.sno" <<'SNO'
        DEFINE('ZFN(X)')                                 :(ZFE)
ZFN     ZFN = X + 1                                      :(RETURN)
ZFE     DEFINE('TWO(A,B)')                               :(TWE)
TWO     TWO = A '-' B                                    :(RETURN)
TWE     DEFINE('FR(X)')                                  :(FRE)
FR      GT(X, 5)                                         :S(RETURN)F(FRETURN)
FRE     DEFINE('FACT(N)')                                :(FAE)
FACT    FACT = LE(N, 1) 1                                :S(RETURN)
        FACT = N * APPLY('FACT', N - 1)                  :(RETURN)
FAE     DEFINE('NR(K)')                                  :(NRE)
NR      NR = .T[K]                                       :(NRETURN)
NRE     T = TABLE()
        T[1] = 'one'
        OUTPUT = 'zfn ' APPLY('ZFN', 41)
        F = 'ZFN'
        OUTPUT = 'zfn var ' APPLY(F, 1)
        OUTPUT = 'two ' APPLY('TWO', 'a', 'b')
        OUTPUT = 'two short ' APPLY('TWO', 'a')
        OUTPUT = 'two long ' APPLY('TWO', 'a', 'b', 'c')
        OUTPUT = 'fr ' (APPLY('FR', 9) 'ok')
        OUTPUT = 'fr fail ' (APPLY('FR', 1) 'ok')            :S(X1)
        OUTPUT = 'fr failed'
X1      OUTPUT = 'fact ' APPLY('FACT', 5)
        OUTPUT = 'nr ' APPLY('NR', 1)
        APPLY('NR', 1) = 'uno'
        OUTPUT = 'nr set ' T[1]
        OUTPUT = 'eval ' EVAL("APPLY('ZFN', 9)")
        OUTPUT = 'end'
END
SNO
printf '%s\n' 'zfn 42' 'zfn var 2' 'two a-b' 'two short a-' 'two long a-b' 'fr ok' 'fr failed' 'fact 120' 'nr one' 'nr set uno' 'eval 10' 'end' > "$D/s.want"
( cd "$D" && timeout -k 5 30 "$B/scrip" --transpile c.sc > c.sno 2>/dev/null && timeout -k 5 10 "$SBL" -bf c.sno < /dev/null > c.sbl 2>/dev/null )
cmp -s "$D/c.want" "$D/c.sbl" || refuse "sbl -bf does not answer the transpiled c as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/c.sbl")]"
( cd "$D" && timeout -k 5 10 "$SBL" -bf s.sno < /dev/null > s.sbl 2>/dev/null )
cmp -s "$D/s.want" "$D/s.sbl" || refuse "sbl -bf does not answer s as pinned: [$(tr '\n' '|' 2>/dev/null < "$D/s.sbl")]"
red=0; n=0
for p in c:sc s:sno; do
    w=${p%%:*}; x=${p#*:}
    ( cd "$D" && timeout -k 5 30 "$B/scrip" $w.$x < /dev/null > $w.m3 2>/dev/null )
    ( cd "$D" && timeout -k 5 60 "$B/scrip" --compile $w.$x < /dev/null > $w.s 2>/dev/null && gcc -no-pie $w.s -L"$B/out" -lscrip_rt -lm -lpthread -Wl,-rpath,"$B/out" -o $w.bin 2>/dev/null \
        && timeout -k 5 30 ./$w.bin < /dev/null > $w.m4 2>/dev/null )
    for m in m3 m4; do
        n=$((n + 1))
        if [ -f "$D/$w.$m" ] && cmp -s "$D/$w.want" "$D/$w.$m"; then echo "  ok   $w $m"
        else echo "  FAIL $w $m: got [$(tr '\n' '|' 2>/dev/null < "$D/$w.$m")] want [$(tr '\n' '|' < "$D/$w.want")]"; red=$((red + 1)); fi
    done
done
if [ $red -eq 0 ]; then
    echo "GATE PASS(0): APPLY of a Snocone function carries its arguments into the tiny record -- and SNOBOL4's APPLY rides the same road -- both modes; $n arm(s)"
    exit 0
fi
echo "GATE FAIL(1): $red of $n arm(s) diverge"; exit 1
