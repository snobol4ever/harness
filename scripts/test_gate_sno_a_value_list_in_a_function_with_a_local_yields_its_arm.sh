#!/usr/bin/env bash
# test_gate_sno_a_value_list_in_a_function_with_a_local_yields_its_arm.sh -- a value list (e1, e2, ...) yields its first succeeding
# arm, fails when every arm fails, keeps the operands evaluated before it, and survives recursion through an arm -- inside a
# program-defined function with locals, nested in another list's arm, and at the top level -- in both modes, as SPITBOL answers it.
#
# ⛔ THE DEFECT (long-standing -- it reproduces on 380cc4162, 2026-09-03; Gimpel ARC's graded red, both modes, "stack smashing
# detected" through ASIN -> ACOS). Minimal: DEFINE('F(X)K') / F F = (EQ(X,0) 5, EQ(X,1) 'one', 7) :(RETURN) -> sbl '5 one 7', SCRIP
# '27' or SIGSEGV; a list nested in an arm of a list inside such a function SIGSEGVs; a nested list at the top level loses the
# operands before it ('r.' for 'nest r.'). The SNOBOL4 lowerer built every list as an IR_DISJUNCTION whose arm chains the zd plan
# never claims, so inside a function body with a frame the arm nodes stored at [rsp+96..184] off the body's rsp while the
# disjunction reserved 32 -- the caller's save area.
#
# THE CURE (SNOBOL4's own lowerer; no shared node -- the cfo's pick (c), 2026-09-25): a list whose every arm but the last fails
# only through an inlined predicate test (EQ..LGE, IDENT, DIFFER) over literals, variables and operators lowers as CONTROL FLOW --
# each arm assigns a per-list temporary SNO$VL$n and control joins at one read of it; an arm's failure falls to the next arm, the
# last arm's failure is the list's. A list of three or more arms nests to the right, each inner list joining at its own read of the
# temporary, because the zd planner seeds a failing arm's spine depth from its test only when the arm rejoins that test's own run:
# flat, a third arm started at depth 0 and overwrote the operand evaluated before the list ('77' for 'three-last-succeeds  7' --
# the rungs' user_function_array_replace_branch_1, which withdrew the flat form before it was pushed). Any other list -- an arm
# that can fail through a call, a pattern match, INPUT -- keeps the IR_DISJUNCTION: a call's failure edge pops to the statement
# base, so as control flow it lost the operands before the list (and SIGSEGV'd in a function), while the disjunction answers those.
# NO MONITOR BRACKET: the program dies, or answers wrong, before its first diverging event.
#
# THE ARMS (expectations cut from sbl -bf AT RUN TIME; SCRIP as shipped, the --stlimit statement instrumentation hides the minimal
# crash; ARC as the graders run it):
#   1-2  m3 / m4: lists in functions with locals (three arms, a local-using arm, all arms failing, recursion, a nested list, an arm
#        with an unreachable successor, operands before and after the list) and nested lists at the top level     -- RED on base
#   3    m3: Gimpel's ARC through its driver (corpus packages/snobol4/gimpel)                                            -- RED on base
#   4-6  THE MATRIX (the cfo's, 2026-09-25): a live operand before the list and after it, 2 to 5 arms with the succeeding arm at
#        every position and none, at the top level and in a function with a local, and lists nested in the middle arms -- m3, m4,
#        and m3 under SCRIP_GC_STRESS=5 (the temporary is a named variable across a call)          -- RED on base
#   7-8  CONTROL m3 / m4: the shapes the disjunction already answered and the flat form broke -- three and four arms after a
#        live operand, arms failing through a user function (top level and in a function with a local), INPUT at end of file,
#        a pattern match, lexical predicates
# EXIT: 0 all arms pass · 1 an arm failed · 2 REFUSED (no binary, no oracle, no Gimpel package, the oracle's answer moved).
"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/util_require_fresh.sh" --gate "$(basename "${BASH_SOURCE[0]}" .sh)" || exit $?
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../SCRIP" && pwd)" || { echo "REFUSE(2): no SCRIP beside harness at $HERE/../../SCRIP (a port root) -- this gate measures SCRIP and cannot from here"; exit 2; }
SCRIP="$ROOT/scrip"
RT_DIR="$ROOT/out"
S4E="${S4E_HOME:-$(cd "$ROOT/.." && pwd)}"
PKG="$S4E/corpus/packages/snobol4/gimpel"
NAME=sno_a_value_list_in_a_function_with_a_local_yields_its_arm
refuse() { echo "GATE REFUSE(2) [$NAME]: $*"; exit 2; }
[ -x "$SCRIP" ] || refuse "no scrip binary at $SCRIP -- cannot measure"
[ -f "$RT_DIR/libscrip_rt.so" ] || refuse "no $RT_DIR/libscrip_rt.so -- cannot measure mode 4"
{ [ -f "$PKG/arc_driver.sno" ] && [ -f "$PKG/arc.inc" ]; } || { [ -f "$PKG/ARC_driver.sno" ] && [ -f "$PKG/ARC.sno" ]; } || refuse "no Gimpel ARC under $PKG -- pull corpus"
ARC_D=arc_driver; [ -f "$PKG/$ARC_D.sno" ] || ARC_D=ARC_driver   # lower-case since Catspaw's SPITBOL form (CEO-1319)
. "$HERE/lib_oracle_flags.sh" 2>/dev/null || true
SBL="$(sbl_correctness_bin 2>/dev/null || true)"; [ -n "${SBL:-}" ] && [ -x "$SBL" ] || SBL=/home/resources/x64/bin/sbl
[ -x "$SBL" ] || refuse "no sbl oracle -- cannot measure (a missing oracle prints a full false table)"
T="$(mktemp -d)" || refuse "no tmpdir"
trap 'rm -rf "$T"' EXIT
cp "$PKG"/*.sno "$T/" 2>/dev/null; cp "$PKG"/*.INC "$PKG"/*.inc "$PKG"/*.spt "$T/" 2>/dev/null
cat > "$T/vl.sno" <<'EOF'
        DEFINE('F(X)K')                         :(F_END)
F       F = (EQ(X,0) 5, EQ(X,1) 'one', 7)       :(RETURN)
F_END   OUTPUT = F(0) ' ' F(1) ' ' F(2)
        DEFINE('G(X)K')                         :(G_END)
G       K = 'k'
        G = 'pre-' (EQ(X,0) K, IDENT(X,1) 'a' K, X + 1) '-post' :(RETURN)
G_END   OUTPUT = G(0) ' ' G(1) ' ' G(5)
        DEFINE('A(X)K')                         :(A_END)
A       A = (LT(X,0) 'neg', GT(X,9) 'big')      :S(RETURN)F(FRETURN)
A_END   OUTPUT = (A(5) 'A succeeded', 'every arm failed')
        DEFINE('H(N)K')                         :(H_END)
H       H = (LE(N,1) 1, N * H(N - 1))           :(RETURN)
H_END   OUTPUT = 'fact ' H(6)
        DEFINE('V(X)K,L')                       :(V_END)
V       L = 'l'
        V = L (EQ(X,1) (EQ(X,2) 'p', LGT('b','a') 'q' L, 'r'), 's') L :(RETURN)
V_END   OUTPUT = V(1) ' ' V(3)
        DEFINE('U(X)K')                         :(U_END)
U       U = ('first', 'never') X                :(RETURN)
U_END   OUTPUT = U(1)
        OUTPUT = 'nest ' (IDENT(1,1) (EQ(2,1) 'p', EQ(2,3) 'q', 'r'), 's') '.'
        OUTPUT = 'nest2 ' (IDENT(1,2) 'x', (EQ(2,1) 'p', 'q'), 's') '.'
END
EOF
cat > "$T/ctl.sno" <<'EOF'
        OUTPUT = 'three-last-succeeds  ' (IDENT('a') 5, IDENT('b') 6, 7)
        OUTPUT = 'four ' (IDENT('a') 1, IDENT('b') 2, IDENT('c') 3, 4) ' tail'
        DEFINE('P(X)')                          :(P_END)
P       EQ(X,0)                                 :S(RETURN)F(FRETURN)
P_END   OUTPUT = 'calls ' (P(1) 'a', P(2) 'b', P(0) 'c', 'd') '!'
        DEFINE('Q(X)K')                         :(Q_END)
Q       Q = 'q:' (P(X) 'zero', 'other')         :(RETURN)
Q_END   OUTPUT = Q(0) ' ' Q(1)
        OUTPUT = 'r ' (INPUT 'got', 'eof') '!'
        OUTPUT = 'match ' ('abc' ? 'x' 'X', 'abc' ? 'b' 'B', 'none') '!'
        OUTPUT = 'lgt ' (LGT('a','b') 1, LLT('a','b') 2, 3) '!'
        OUTPUT = 'fails ' (EQ(1,2) 'a', EQ(1,3) 'b', EQ(1,4) 'c')  :S(BAD)
        OUTPUT = 'all-fail ok'                  :(END)
BAD     OUTPUT = 'BAD'
END
EOF
python3 - "$T/mx.sno" <<'PY2' || refuse "could not write the matrix witness"
import sys
fd, bd = [], []
for k in range(2, 6):
    for s in range(0, k + 1):
        arms = ", ".join("IDENT(S,%d) 'v%d'" % (i, i) for i in range(1, k + 1)); tag = "k%ds%d" % (k, s); fn = "F" + tag
        bd += ["        S = %d" % s, "        OUTPUT = 'L%s ' (%s) ' R'   :S(N%s)" % (tag, arms, tag), "        OUTPUT = 'L%s fail'" % tag, "N" + tag]
        fd += ["        DEFINE('%s(S)K')     :(%s_END)" % (fn, fn), "%s     K = 'k'" % fn, "        %s = 'L' K (%s) K   :S(RETURN)F(FRETURN)" % (fn, arms), fn + "_END"]
        bd += ["        OUTPUT = '%s ' %s(%d)   :S(M%s)" % (fn, fn, s, tag), "        OUTPUT = '%s fail'" % fn, "M" + tag]
for s in range(0, 4):
    bd += ["        S = %d" % s, "        OUTPUT = 'nest%d ' (IDENT(S,1) 'a', IDENT(S,0) (IDENT(S,9) 'x', 'y', 'z'), IDENT(S,2) 'b' (IDENT(S,2) 'c', 'd'), 'e') '.'" % s]
    fd += ["        DEFINE('NF%d(S)K,J')     :(NF%d_END)" % (s, s), "NF%d    K = 'k' ; J = 'j'" % s,
           "        NF%d = J (IDENT(S,1) K, IDENT(S,0) (IDENT(S,9) 'x', K 'y' J, 'z'), IDENT(S,2) 'b' (IDENT(S,2) 'c' K, 'd'), 'e') K :(RETURN)" % s, "NF%d_END" % s]
    bd += ["        OUTPUT = 'nf%d ' NF%d(%d)" % (s, s, s)]
open(sys.argv[1], "w").write("\n".join(fd + bd + ["END"]) + "\n")
PY2
for w in vl mx ctl "$ARC_D"; do ( cd "$T" && timeout -k 5 20 "$SBL" -bf "$w.sno" < /dev/null > "$w.oracle" 2>&1 ) || refuse "sbl did not run $w cleanly"; done
grep -qx '5 one 7' "$T/vl.oracle" && grep -qx 'fact 720' "$T/vl.oracle" && grep -qx 'lqll lsl' "$T/vl.oracle" || refuse "sbl's answer moved: [$(tr '\n' '|' < "$T/vl.oracle")]"
[ "$(wc -l < "$T/mx.oracle")" = 44 ] && grep -qx 'Lk5s3 v3 R' "$T/mx.oracle" && grep -qx 'Fk4s0 fail' "$T/mx.oracle" || refuse "sbl's matrix answer moved: $(wc -l < "$T/mx.oracle") lines"
grep -qx 'three-last-succeeds  7' "$T/ctl.oracle" && grep -qx 'calls c!' "$T/ctl.oracle" || refuse "sbl's control answer moved: [$(tr '\n' '|' < "$T/ctl.oracle")]"
fail=0; n=0
arm() { n=$((n+1)); if [ "$2" = ok ]; then echo "  ok   arm $n  $1"; else echo "  FAIL arm $n  $1 -- $2"; fail=1; fi; }
same() { [ "$1" = 0 ] || { echo "rc=$1"; return; }; cmp -s "$T/$2" "$T/$3" && echo ok || echo "got [$(tr '\n' '|' < "$T/$2" | head -c 110)] want [$(tr '\n' '|' < "$T/$3" | head -c 110)]"; }
m3() { ( cd "$T" && timeout -k 5 20 "$SCRIP" "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
m3s() { ( cd "$T" && SCRIP_SNO_STMTKW=1 timeout -k 5 20 "$SCRIP" --stlimit "$1.sno" < /dev/null > "$1.m3" 2>&1; echo $? ); }
m4() { ( cd "$T" && timeout -k 5 30 "$SCRIP" --compile -o "$1.s" "$1.sno" < /dev/null > /dev/null 2>&1 && gcc "$1.s" -L"$RT_DIR" -lscrip_rt -Wl,-rpath,"$RT_DIR" -lm -o "$1.bin" > /dev/null 2>&1 && timeout -k 5 20 "./$1.bin" < /dev/null > "$1.m4" 2>&1; echo $? ); }
rc=$(m3 vl); arm "m3: lists in functions with locals, nested lists, operands around the list" "$(same "$rc" vl.m3 vl.oracle)"
rc=$(m4 vl); arm "m4: lists in functions with locals, nested lists, operands around the list" "$(same "$rc" vl.m4 vl.oracle)"
rc=$(m3s "$ARC_D"); arm "m3: Gimpel ARC through its driver (under --stlimit, as the graders run it)" "$(same "$rc" "$ARC_D.m3" "$ARC_D.oracle")"
rc=$(m3 mx); arm "MATRIX m3: 2-5 arms, every succeeding position and none, top level and in a function, nested" "$(same "$rc" mx.m3 mx.oracle)"
rc=$(m4 mx); arm "MATRIX m4: 2-5 arms, every succeeding position and none, top level and in a function, nested" "$(same "$rc" mx.m4 mx.oracle)"
rc=$( cd "$T" && SCRIP_GC_STRESS=5 timeout -k 5 60 "$SCRIP" mx.sno < /dev/null > mx.gc 2>&1; echo $? ); arm "MATRIX m3 under SCRIP_GC_STRESS=5" "$(same "$rc" mx.gc mx.oracle)"
rc=$(m3 ctl); arm "CONTROL m3: live operand before 3-4 arms, call/INPUT/match arms keep the disjunction" "$(same "$rc" ctl.m3 ctl.oracle)"
rc=$(m4 ctl); arm "CONTROL m4: live operand before 3-4 arms, call/INPUT/match arms keep the disjunction" "$(same "$rc" ctl.m4 ctl.oracle)"
[ "$fail" = 0 ] && { echo "PASS [$NAME]: $n arms"; exit 0; }
echo "FAIL [$NAME]"; exit 1
